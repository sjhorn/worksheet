import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:any_date/any_date.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/data/data_change_event.dart';
import '../core/data/worksheet_data.dart';
import '../core/geometry/editing_bounds_calculator.dart';
import '../core/geometry/layout_solver.dart';
import '../core/geometry/span_list.dart';
import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import '../core/models/cell_style.dart';
import '../core/models/cell_format.dart';
import '../core/models/cell_value.dart';
import '../interaction/clipboard/clipboard_handler.dart';
import '../interaction/clipboard/clipboard_serializer.dart';
import '../interaction/controllers/edit_controller.dart';
import '../interaction/controllers/selection_controller.dart';
import '../interaction/gesture_handler.dart';
import '../interaction/hit_testing/hit_test_result.dart';
import '../interaction/hit_testing/hit_tester.dart';
import '../shortcuts/default_worksheet_shortcuts.dart';
import '../shortcuts/worksheet_action_context.dart';
import '../shortcuts/worksheet_actions.dart';
import '../shortcuts/worksheet_intents.dart';
import '../rendering/layers/header_layer.dart';
import '../rendering/layers/render_layer.dart';
import '../rendering/layers/selection_layer.dart';
import '../rendering/painters/header_renderer.dart';
import '../rendering/painters/selection_renderer.dart';
import '../rendering/tile/tile_config.dart';
import '../rendering/tile/tile_manager.dart';
import '../rendering/tile/tile_painter.dart';
import '../scrolling/worksheet_viewport.dart';
import 'cell_editor_overlay.dart';
import 'worksheet_controller.dart';
import 'worksheet_scrollbar_config.dart';
import 'worksheet_theme.dart';

/// Callback for when a cell should enter edit mode.
typedef OnEditCellCallback = void Function(CellCoordinate cell);

/// Callback for when a cell is tapped.
typedef OnCellTapCallback = void Function(CellCoordinate cell);

/// Callback for when a row is resized.
typedef OnResizeRowCallback = void Function(int row, double newHeight);

/// Callback for when a column is resized.
typedef OnResizeColumnCallback = void Function(int column, double newWidth);

/// A high-performance worksheet widget with Excel-like functionality.
///
/// Supports:
/// - 10%-400% zoom with GPU-optimized tile-based rendering
/// - Selection (single cell, range, row, column)
/// - Row and column headers
/// - Configurable theming
/// - Programmatic control via [WorksheetController]
///
/// Example:
/// ```dart
/// Worksheet(
///   data: myWorksheetData,
///   controller: controller,
///   onEditCell: (cell) => startEditing(cell),
/// )
/// ```
class Worksheet extends StatefulWidget {
  /// The worksheet data source.
  final WorksheetData data;

  /// The controller for programmatic interaction.
  ///
  /// If not provided, a default controller is created internally.
  final WorksheetController? controller;

  /// The number of rows to display.
  final int rowCount;

  /// The number of columns to display.
  final int columnCount;

  /// Called when a cell should enter edit mode (double-tap).
  final OnEditCellCallback? onEditCell;

  /// Optional edit controller for integrated editing support.
  ///
  /// When provided, the Worksheet:
  /// - Renders [CellEditorOverlay] internally (no manual Stack needed)
  /// - Intercepts printable characters for type-to-edit
  /// - Handles post-commit navigation (Enter→down, Tab→right, etc.)
  /// - Starts editing on F2 and double-tap via the controller
  ///
  /// When null, behavior is identical to before. The existing external
  /// management approach continues to work.
  final EditController? editController;

  /// Called when a cell is tapped.
  final OnCellTapCallback? onCellTap;

  /// Called when a row is resized.
  final OnResizeRowCallback? onResizeRow;

  /// Called when a column is resized.
  final OnResizeColumnCallback? onResizeColumn;

  /// Custom row sizes. Map from row index to height.
  final Map<int, double>? customRowHeights;

  /// Custom column sizes. Map from column index to width.
  final Map<int, double>? customColumnWidths;

  /// Whether the worksheet is read-only (no selection or editing).
  final bool readOnly;

  /// Date format parser for type detection during editing and clipboard paste.
  ///
  /// Controls how text input is detected as dates. Uses [AnyDate] from the
  /// `any_date` package. When null, uses `const AnyDate()` (system defaults).
  ///
  /// Example: `AnyDate.fromLocale('en-US')` for US date format (month/day/year).
  final AnyDate? dateParser;

  /// Locale used for date format detection when committing cell edits.
  ///
  /// Controls whether ambiguous numeric dates (e.g., `01/02/2024`) are
  /// interpreted as month/day or day/month, and which month names to match.
  /// Defaults to [FormatLocale.enUs].
  final FormatLocale? formatLocale;

  /// The clipboard serializer for copy/cut/paste operations.
  ///
  /// Defaults to [TsvClipboardSerializer], which uses tab-separated values
  /// compatible with Excel and Google Sheets. When null, a default
  /// [TsvClipboardSerializer] is created using the [dateParser] configuration.
  final ClipboardSerializer? clipboardSerializer;

  /// Controls how diagonal drags are handled by the scroll view.
  ///
  /// Defaults to [DiagonalDragBehavior.free], which allows simultaneous
  /// horizontal and vertical scrolling.
  final DiagonalDragBehavior diagonalDragBehavior;

  /// Configuration for scrollbar appearance and behavior.
  ///
  /// If null, defaults to platform-appropriate behavior:
  /// - Desktop (macOS, Windows, Linux): scrollbars always visible
  /// - Mobile (iOS, Android): scrollbars shown on scroll, then fade out
  final WorksheetScrollbarConfig? scrollbarConfig;

  /// Custom keyboard shortcut bindings.
  ///
  /// These are merged on top of [DefaultWorksheetShortcuts.shortcuts].
  /// Pass an entry with [DoNothingIntent] to disable a default binding.
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// Custom action overrides.
  ///
  /// These are merged on top of the default worksheet actions.
  /// Each key is an Intent type (e.g., `ClearCellsIntent`) mapped to
  /// a custom [Action].
  final Map<Type, Action<Intent>>? actions;

  const Worksheet({
    super.key,
    required this.data,
    this.controller,
    this.rowCount = 1000,
    this.columnCount = 26,
    this.onEditCell,
    this.editController,
    this.onCellTap,
    this.onResizeRow,
    this.onResizeColumn,
    this.customRowHeights,
    this.customColumnWidths,
    this.readOnly = false,
    this.dateParser,
    this.formatLocale,
    this.clipboardSerializer,
    this.diagonalDragBehavior = DiagonalDragBehavior.free,
    this.scrollbarConfig,
    this.shortcuts,
    this.actions,
  });

  @override
  State<Worksheet> createState() => _WorksheetState();
}

class _WorksheetState extends State<Worksheet>
    implements WorksheetActionContext {
  late WorksheetController _controller;
  bool _ownsController = false;

  late LayoutSolver _layoutSolver;
  late TileManager _tileManager;
  late TilePainter _tilePainter;
  late WorksheetHitTester _hitTester;
  late WorksheetGestureHandler _gestureHandler;
  late ClipboardHandler _clipboardHandler;

  /// Focus node for keyboard navigation. Passed to the cell editor overlay
  /// so it can restore focus here when editing completes.
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'Worksheet');

  /// Offstage TextField focus node used as a keyboard trigger on iOS Safari.
  ///
  /// iOS Safari requires that `element.focus()` happens synchronously within
  /// a user gesture for the virtual keyboard to appear. This node is attached
  /// to a hidden [EditableText] that is always in the widget tree. When a
  /// double-tap starts editing, we call `requestFocus()` on this node
  /// synchronously inside the gesture handler, which satisfies Safari's
  /// requirement and shows the keyboard. The [CellEditorOverlay]'s own
  /// TextField then takes over focus in the next frame.
  final FocusNode _editorFocusNode = FocusNode(debugLabel: 'EditorTrigger');
  final TextEditingController _editorTriggerController =
      TextEditingController();

  late SelectionRenderer _selectionRenderer;
  late HeaderRenderer _headerRenderer;
  late SelectionLayer _selectionLayer;
  late HeaderLayer _headerLayer;

  bool _initialized = false;
  WorksheetThemeData? _lastTheme;
  double? _lastDevicePixelRatio;
  MouseCursor _currentCursor = SystemMouseCursors.basic;
  int _layoutVersion = 0;
  bool _pointerInScrollbarArea = false;

  // Track viewInsets for keyboard visibility changes
  EdgeInsets _lastViewInsets = EdgeInsets.zero;

  // Cached expansion state computed by _onEditTextChanged()
  Rect? _editingExpandedBounds; // worksheet coords
  Rect? _editingExpandedScreenBounds; // screen coords, header-adjusted
  double? _editingVerticalOffset; // fixed vertical offset for wrap-text cells
  double? _editingContentAreaWidth; // viewport width minus row header

  // Data change subscription for external mutations
  StreamSubscription<DataChangeEvent>? _dataSubscription;

  // Auto-scroll during drag selection
  Timer? _autoScrollTimer;
  Offset? _lastPointerPosition;
  PointerDeviceKind? _lastPointerKind;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);

  // Timer for keyboard scroll adjustment (cancellable for tests)
  Timer? _keyboardScrollTimer;

  // WorksheetActionContext implementation
  @override
  SelectionController get selectionController =>
      _controller.selectionController;
  @override
  int get maxRow => widget.rowCount;
  @override
  int get maxColumn => widget.columnCount;
  @override
  WorksheetData get worksheetData => widget.data;
  @override
  ClipboardHandler get clipboardHandler => _clipboardHandler;
  @override
  bool get readOnly => widget.readOnly;
  @override
  void Function(CellCoordinate)? get onEditCell => widget.onEditCell;

  @override
  EditController? get editController => widget.editController;

  @override
  void ensureSelectionVisible() => _ensureSelectionVisible();

  @override
  void invalidateAndRebuild() {
    _tileManager.invalidateAll();
    _layoutVersion++;
    if (mounted) setState(() {});
  }

  Map<Type, Action<Intent>> get _defaultActions => <Type, Action<Intent>>{
    MoveSelectionIntent: MoveSelectionAction(this),
    GoToCellIntent: GoToCellAction(this),
    GoToLastCellIntent: GoToLastCellAction(this),
    GoToRowBoundaryIntent: GoToRowBoundaryAction(this),
    SelectAllCellsIntent: SelectAllCellsAction(this),
    CancelSelectionIntent: CancelSelectionAction(this),
    EditCellIntent: _IntegratedEditCellAction(this),
    CopyCellsIntent: CopyCellsAction(this),
    CutCellsIntent: CutCellsAction(this),
    PasteCellsIntent: PasteCellsAction(this),
    ClearCellsIntent: ClearCellsAction(this),
    FillDownIntent: FillDownAction(this),
    FillRightIntent: FillRightAction(this),
    MergeCellsIntent: MergeCellsAction(this),
    MergeCellsHorizontallyIntent: MergeCellsHorizontallyAction(this),
    MergeCellsVerticallyIntent: MergeCellsVerticallyAction(this),
    UnmergeCellsIntent: UnmergeCellsAction(this),
  };

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = WorksheetController();
      _ownsController = true;
    }
    _controller.keepAnchorVisible = true;
    _controller.addListener(_onControllerChanged);
  }

  void _initLayout(WorksheetThemeData theme) {
    _layoutSolver = LayoutSolver(
      rows: SpanList(
        count: widget.rowCount,
        defaultSize: theme.defaultRowHeight,
        customSizes: widget.customRowHeights,
      ),
      columns: SpanList(
        count: widget.columnCount,
        defaultSize: theme.defaultColumnWidth,
        customSizes: widget.customColumnWidths,
      ),
      mergedCells: widget.data.mergedCells,
    );

    // Wire merged cells into the selection controller
    _controller.selectionController.mergedCells = widget.data.mergedCells;

    _hitTester = WorksheetHitTester(
      layoutSolver: _layoutSolver,
      headerWidth: theme.rowHeaderWidth,
      headerHeight: theme.columnHeaderHeight,
    );

    // Attach layout to controller for public API access
    _controller.attachLayout(
      _layoutSolver,
      headerWidth: theme.showHeaders ? theme.rowHeaderWidth : 0.0,
      headerHeight: theme.showHeaders ? theme.columnHeaderHeight : 0.0,
    );
  }

  void _initRendering(WorksheetThemeData theme, double devicePixelRatio) {
    _tilePainter = TilePainter(
      data: widget.data,
      layoutSolver: _layoutSolver,
      showGridlines: theme.showGridlines,
      gridlineColor: theme.gridlineColor,
      backgroundColor: theme.cellBackgroundColor,
      defaultTextColor: theme.textColor,
      defaultFontSize: theme.fontSize,
      defaultFontFamily: theme.fontFamily,
      cellPadding: theme.cellPadding,
      devicePixelRatio: devicePixelRatio,
    )..mergedCells = widget.data.mergedCells;

    _tileManager = TileManager(
      renderer: _tilePainter,
      layoutSolver: _layoutSolver,
      config: const TileConfig(),
    );

    // Create gesture handler after tile manager so resize callbacks can access it
    _gestureHandler = WorksheetGestureHandler(
      hitTester: _hitTester,
      selectionController: _controller.selectionController,
      onEditCell: widget.onEditCell,
      onResizeRow: (row, delta) {
        final currentHeight = _layoutSolver.getRowHeight(row);
        final newHeight = (currentHeight + delta).clamp(10.0, 500.0);
        _layoutSolver.setRowHeight(row, newHeight);
        _tileManager.invalidateAll();
        _layoutVersion++;
        widget.onResizeRow?.call(row, newHeight);
        setState(() {});
      },
      onResizeColumn: (column, delta) {
        final currentWidth = _layoutSolver.getColumnWidth(column);
        final newWidth = (currentWidth + delta).clamp(20.0, 1000.0);
        _layoutSolver.setColumnWidth(column, newWidth);
        _tileManager.invalidateAll();
        _layoutVersion++;
        widget.onResizeColumn?.call(column, newWidth);
        setState(() {});
      },
      onResizeRowEnd: (row) {
        _applyResizeToSelectedRows(row);
      },
      onResizeColumnEnd: (column) {
        _applyResizeToSelectedColumns(column);
      },
      onFillPreviewUpdate: widget.readOnly
          ? null
          : (previewRange) {
              _selectionLayer.fillPreviewRange = previewRange;
              setState(() {});
            },
      onFillComplete: widget.readOnly
          ? null
          : (sourceRange, destination) {
              widget.data.smartFill(sourceRange, destination);
              _controller.selectionController.selectRange(
                sourceRange.expand(destination),
              );
              _selectionLayer.fillPreviewRange = null;
              _tileManager.invalidateAll();
              _layoutVersion++;
              setState(() {});
            },
      onFillCancel: widget.readOnly
          ? null
          : () {
              _selectionLayer.fillPreviewRange = null;
              setState(() {});
            },
    );

    _clipboardHandler = ClipboardHandler(
      data: widget.data,
      selectionController: _controller.selectionController,
      serializer:
          widget.clipboardSerializer ??
          TsvClipboardSerializer(dateParser: widget.dateParser),
    );

    // Set dateParser and locale on editController
    widget.editController?.dateParser = widget.dateParser;
    if (widget.formatLocale != null) {
      widget.editController?.locale = widget.formatLocale!;
    }

    // Subscribe to data change events for external mutations
    _dataSubscription?.cancel();
    _dataSubscription = widget.data.changes.listen(_onDataChanged);

    // Listen to editController for expansion recomputation
    widget.editController?.addListener(_onEditTextChanged);
  }

  void _initLayers(WorksheetThemeData theme, double devicePixelRatio) {
    _selectionRenderer = SelectionRenderer(
      layoutSolver: _layoutSolver,
      style: theme.selectionStyle,
      devicePixelRatio: devicePixelRatio,
    );

    _headerRenderer = HeaderRenderer(
      layoutSolver: _layoutSolver,
      style: theme.headerStyle,
      rowHeaderWidth: theme.rowHeaderWidth,
      columnHeaderHeight: theme.columnHeaderHeight,
      devicePixelRatio: devicePixelRatio,
    );

    _selectionLayer = SelectionLayer(
      selectionController: _controller.selectionController,
      renderer: _selectionRenderer,
      onNeedsPaint: () => setState(() {}),
      showFillHandle: !widget.readOnly,
    );

    _headerLayer = HeaderLayer(
      renderer: _headerRenderer,
      selectionController: _controller.selectionController,
      getVisibleColumns: (scrollX, viewportWidth, zoom) {
        // scrollX is already in worksheet coordinates (divided by zoom in the painter)
        // viewportWidth is in screen pixels, so divide by zoom to get worksheet units
        return _layoutSolver.getVisibleColumns(scrollX, viewportWidth / zoom);
      },
      getVisibleRows: (scrollY, viewportHeight, zoom) {
        // scrollY is already in worksheet coordinates (divided by zoom in the painter)
        // viewportHeight is in screen pixels, so divide by zoom to get worksheet units
        return _layoutSolver.getVisibleRows(scrollY, viewportHeight / zoom);
      },
      onNeedsPaint: () => setState(() {}),
    );
  }

  void _ensureInitialized(WorksheetThemeData theme, double devicePixelRatio) {
    if (!_initialized) {
      _initLayout(theme);
      _initRendering(theme, devicePixelRatio);
      _initLayers(theme, devicePixelRatio);
      _initialized = true;
      _lastTheme = theme;
      _lastDevicePixelRatio = devicePixelRatio;
    }
  }

  /// Applies the resized row's height to all selected rows.
  void _applyResizeToSelectedRows(int resizedRow) {
    final selection = _controller.selectionController.selectedRange;
    if (selection == null) return;

    // Check if the resized row is within the selection
    if (resizedRow < selection.startRow || resizedRow > selection.endRow) {
      return;
    }

    // Check if this is a full-row selection (all columns selected)
    // For simplicity, we apply to all rows in the selection range
    final newHeight = _layoutSolver.getRowHeight(resizedRow);

    bool changed = false;
    for (int row = selection.startRow; row <= selection.endRow; row++) {
      if (row != resizedRow) {
        _layoutSolver.setRowHeight(row, newHeight);
        changed = true;
      }
    }

    if (changed) {
      _tileManager.invalidateAll();
      _layoutVersion++;
      setState(() {});
    }
  }

  /// Applies the resized column's width to all selected columns.
  void _applyResizeToSelectedColumns(int resizedColumn) {
    final selection = _controller.selectionController.selectedRange;
    if (selection == null) return;

    // Check if the resized column is within the selection
    if (resizedColumn < selection.startColumn ||
        resizedColumn > selection.endColumn) {
      return;
    }

    // Check if this is a full-column selection (all rows selected)
    // For simplicity, we apply to all columns in the selection range
    final newWidth = _layoutSolver.getColumnWidth(resizedColumn);

    bool changed = false;
    for (int col = selection.startColumn; col <= selection.endColumn; col++) {
      if (col != resizedColumn) {
        _layoutSolver.setColumnWidth(col, newWidth);
        changed = true;
      }
    }

    if (changed) {
      _tileManager.invalidateAll();
      _layoutVersion++;
      setState(() {});
    }
  }

  /// Smoothly scrolls to ensure the focused cell is visible.
  ///
  /// Accounts for the virtual keyboard by subtracting [viewInsets.bottom]
  /// from the viewport height, so cells behind the keyboard are not
  /// considered "visible".
  void _ensureSelectionVisible() {
    final cell = _controller.selectionController.focus;
    if (cell == null) return;

    final size = context.size;
    if (size == null) return;

    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final adjustedSize = Size(size.width, size.height - keyboardHeight);

    _controller.ensureCellVisible(cell, viewportSize: adjustedSize);
  }

  /// Scrolls to center the cell vertically in the visible area above the keyboard.
  void _scrollCellToCenter(CellCoordinate cell) {
    final size = context.size;
    if (size == null) return;
    final solver = _controller.layoutSolver;
    if (solver == null) return;

    final viewInsets = MediaQuery.of(context).viewInsets;
    final theme = WorksheetTheme.of(context);
    final zoom = _controller.zoom;

    // Calculate cell position in screen coordinates
    final cellTop = solver.getRowTop(cell.row) * zoom;
    final cellHeight = solver.getRowHeight(cell.row) * zoom;
    final headerHeight = theme.showHeaders
        ? theme.columnHeaderHeight * zoom
        : 0.0;

    // Available height above keyboard (minus headers)
    final availableHeight = size.height - viewInsets.bottom - headerHeight;

    // Target: center the cell vertically in the available space
    final cellCenterY = cellTop + cellHeight / 2;
    final targetScrollY = cellCenterY - availableHeight / 2;

    // Clamp to valid scroll range
    final vController = _controller.verticalScrollController;
    if (!vController.hasClients) return;
    final maxScroll = vController.position.maxScrollExtent;
    final clampedY = targetScrollY.clamp(0.0, maxScroll);

    vController.animateTo(
      clampedY,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  // --- Integrated editing support ---

  /// Starts editing via the integrated editController.
  void _startIntegratedEdit({
    required CellCoordinate cell,
    required EditTrigger trigger,
    String? initialText,
  }) {
    final ec = widget.editController;
    if (ec == null) return;

    final currentValue = widget.data.getCell(cell);
    ec.startEdit(
      cell: cell,
      currentValue: currentValue,
      trigger: trigger,
      initialText: initialText,
    );

    // Tell the tile painter to skip rendering text for this cell
    // (the overlay TextField renders it instead) and re-render the tile.
    _tilePainter.editingRange = CellRange(cell.row, cell.column, cell.row, cell.column);
    _tileManager.invalidateRange(
      CellRange(cell.row, cell.column, cell.row, cell.column),
    );
    _layoutVersion++;
    setState(() {});

    // Scroll strategy depends on whether a virtual keyboard is expected.
    // Touch input → virtual keyboard will appear, so center the cell after
    // a short delay (viewInsets.bottom is unreliable on iOS Safari).
    // Mouse/keyboard input → no virtual keyboard, just ensure visibility.
    final isTouch = _lastPointerKind == PointerDeviceKind.touch;
    if (isTouch && trigger == EditTrigger.doubleTap) {
      _keyboardScrollTimer?.cancel();
      _keyboardScrollTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final ec = widget.editController;
        if (ec == null || !ec.isEditing) return;
        _scrollCellToCenter(cell);
      });
    } else {
      _ensureSelectionVisible();
    }
  }

  /// Clears the editing cell from the tile painter so tile text re-appears.
  void _clearEditingCell() {
    final prev = _tilePainter.editingRange;
    if (prev != null) {
      _tilePainter.editingRange = null;
      _tileManager.invalidateRange(prev);
      _layoutVersion++;
    }
    _selectionRenderer.editingFocusBounds = null;
    _editingExpandedBounds = null;
    _editingExpandedScreenBounds = null;
    _editingVerticalOffset = null;
    _editingContentAreaWidth = null;
  }

  /// Recomputes expanded editing bounds when the edit text changes.
  ///
  /// Listens to [editController] at the state level so that [setState]
  /// propagates the updated [_layoutVersion] and [editingFocusBounds]
  /// to the selection painter and viewport in the same frame.
  void _onEditTextChanged() {
    final ec = widget.editController;
    if (ec == null || !ec.isEditing) {
      if (_editingExpandedBounds != null) {
        _editingExpandedBounds = null;
        _editingExpandedScreenBounds = null;
      }
      _editingVerticalOffset = null;
      _editingContentAreaWidth = null;
      return;
    }

    final cell = ec.editingCell;
    if (cell == null) return;

    final theme = _lastTheme;
    if (theme == null) return;

    // Resolve per-cell style the same way tile_painter does
    final cellStyle = CellStyle.defaultStyle.merge(
      widget.data.getStyle(cell),
    );
    final isWrap = cellStyle.wrapText == true;
    final fontFamily = cellStyle.fontFamily ?? theme.fontFamily;

    // Build TextStyle matching the tile painter's rendering
    final editorTextStyle = TextStyle(
      fontSize: cellStyle.fontSize ?? theme.fontSize,
      fontFamily: fontFamily,
      fontWeight: cellStyle.fontWeight ?? FontWeight.normal,
      fontStyle: cellStyle.fontStyle ?? FontStyle.normal,
      color: cellStyle.textColor ?? theme.textColor,
      package: WorksheetThemeData.resolveFontPackage(fontFamily),
    );

    // For wrap-text cells with middle/bottom alignment, compute the
    // fixed vertical offset once (on the first notification after edit
    // start) using the original cell value. This matches the offset
    // that CellEditorOverlay._computeInitialWrapVerticalOffset() pins.
    if (isWrap && _editingVerticalOffset == null) {
      final vAlign = cellStyle.verticalAlignment ??
          CellVerticalAlignment.middle;
      if (vAlign != CellVerticalAlignment.top) {
        final cellBounds = _layoutSolver.getCellBounds(cell);
        final initialText = ec.originalValue?.displayValue ?? '';
        if (initialText.isNotEmpty) {
          final availWidth = cellBounds.width - 2 * theme.cellPadding;
          final mp = TextPainter(
            text: TextSpan(text: initialText, style: editorTextStyle),
            textDirection: TextDirection.ltr,
          )..layout(
              maxWidth: availWidth > 0 ? availWidth : 0,
            );
          final contentH = mp.height;
          mp.dispose();
          switch (vAlign) {
            case CellVerticalAlignment.middle:
              _editingVerticalOffset =
                  ((cellBounds.height - contentH) / 2)
                      .clamp(0.0, double.infinity);
            case CellVerticalAlignment.bottom:
              _editingVerticalOffset =
                  (cellBounds.height - theme.cellPadding - contentH)
                      .clamp(0.0, double.infinity);
            case CellVerticalAlignment.top:
              break; // unreachable
          }
        }
      }
    }

    // Compute expanded editing bounds
    final editText = ec.currentText;
    final ExpandedEditingBounds expanded;
    if (isWrap) {
      expanded = EditingBoundsCalculator.computeVertical(
        cell: cell,
        text: editText,
        layoutSolver: _layoutSolver,
        textStyle: editorTextStyle,
        cellPadding: theme.cellPadding,
        maxRow: widget.rowCount - 1,
        mergedCells: widget.data.mergedCells,
        verticalOffset: _editingVerticalOffset,
      );
    } else {
      expanded = EditingBoundsCalculator.computeHorizontal(
        cell: cell,
        text: editText,
        layoutSolver: _layoutSolver,
        textStyle: editorTextStyle,
        cellPadding: theme.cellPadding,
        maxColumn: widget.columnCount - 1,
        mergedCells: widget.data.mergedCells,
      );
    }

    // Update tile painter editing range
    final newEditingRange = CellRange(
      cell.row, cell.column,
      expanded.endRow, expanded.endColumn,
    );
    if (_tilePainter.editingRange != newEditingRange) {
      final oldRange = _tilePainter.editingRange;
      if (oldRange != null) {
        _tileManager.invalidateRange(oldRange);
      }
      _tilePainter.editingRange = newEditingRange;
      _tileManager.invalidateRange(newEditingRange);
      _layoutVersion++;
    }

    // Update selection renderer
    final boundsChanged =
        _selectionRenderer.editingFocusBounds != expanded.bounds;
    _selectionRenderer.editingFocusBounds = expanded.bounds;

    // Convert expanded bounds to screen coordinates
    final zoom = _controller.zoom;
    final headerLeft = theme.showHeaders
        ? theme.rowHeaderWidth * zoom
        : 0.0;
    final headerTop = theme.showHeaders
        ? theme.columnHeaderHeight * zoom
        : 0.0;
    final expandedScreenBounds = Rect.fromLTWH(
      expanded.bounds.left * zoom - _controller.scrollX + headerLeft,
      expanded.bounds.top * zoom - _controller.scrollY + headerTop,
      expanded.bounds.width * zoom,
      expanded.bounds.height * zoom,
    );
    final adjustedExpandedBounds = expandedScreenBounds.shift(
      Offset(-headerLeft, -headerTop),
    );

    // Auto-scroll when wrap-text editor bottom extends below the viewport.
    if (isWrap && boundsChanged) {
      final size = context.size;
      if (size != null) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final viewportBottom = size.height - keyboardHeight;
        final overflow = expandedScreenBounds.bottom - viewportBottom;
        if (overflow > 0) {
          final vController = _controller.verticalScrollController;
          if (vController.hasClients) {
            final newOffset = (vController.offset + overflow)
                .clamp(0.0, vController.position.maxScrollExtent);
            vController.jumpTo(newOffset);
          }
        }
      }
    }

    _editingExpandedBounds = expanded.bounds;
    _editingExpandedScreenBounds = adjustedExpandedBounds;

    // Cache content area width for the overlay's right-edge clamping.
    final size = context.size;
    if (size != null) {
      _editingContentAreaWidth = size.width -
          (theme.showHeaders ? theme.rowHeaderWidth * zoom : 0.0);
    }

    if (boundsChanged) {
      setState(() {});
    }
  }

  /// Handles commit from the internal CellEditorOverlay.
  void _onInternalCommit(
    CellCoordinate cell,
    CellValue? value, {
    CellFormat? detectedFormat,
    List<TextSpan>? richText,
  }) {
    _clearEditingCell();
    widget.data.setCell(cell, value);
    if (detectedFormat != null && widget.data.getFormat(cell) == null) {
      widget.data.setFormat(cell, detectedFormat);
    }
    widget.data.setRichText(cell, richText);
    invalidateAndRebuild();
  }

  /// Converts CellTextAlignment to Flutter TextAlign.
  static TextAlign _toTextAlign(CellTextAlignment? alignment) {
    switch (alignment) {
      case CellTextAlignment.center:
        return TextAlign.center;
      case CellTextAlignment.right:
        return TextAlign.right;
      case CellTextAlignment.left:
      case null:
        return TextAlign.left;
    }
  }

  /// Handles cancel from the internal CellEditorOverlay.
  void _onInternalCancel() {
    _clearEditingCell();
    // Focus restores automatically via CellEditorOverlay._previousFocus
  }

  /// Handles commit-and-navigate from the internal CellEditorOverlay.
  void _onInternalCommitAndNavigate(
    CellCoordinate cell,
    CellValue? value,
    int rowDelta,
    int colDelta, {
    CellFormat? detectedFormat,
    List<TextSpan>? richText,
  }) {
    _clearEditingCell();
    widget.data.setCell(cell, value);
    if (detectedFormat != null && widget.data.getFormat(cell) == null) {
      widget.data.setFormat(cell, detectedFormat);
    }
    widget.data.setRichText(cell, richText);
    selectionController.moveFocus(
      rowDelta: rowDelta,
      columnDelta: colDelta,
      extend: false,
      maxRow: widget.rowCount,
      maxColumn: widget.columnCount,
    );
    invalidateAndRebuild();
    _ensureSelectionVisible();
  }

  /// Handles printable key events for type-to-edit.
  ///
  /// Placed on the inner Focus widget so it fires before the Shortcuts widget.
  /// Returns [KeyEventResult.handled] to prevent the character from also
  /// triggering a shortcut.
  KeyEventResult _handleTypeToEdit(FocusNode node, KeyEvent event) {
    final ec = widget.editController;
    if (ec == null || widget.readOnly || ec.isEditing) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Only intercept printable characters (0x20–0x7E and above 0x7F).
    // Exclude C0 control chars (0x00–0x1F) and DEL (0x7F, sent by
    // Backspace on macOS) so they propagate to the Shortcuts widget.
    // Ignore if Ctrl, Meta, or Alt are held (those are shortcuts).
    final char = event.character;
    if (char == null || char.isEmpty) return KeyEventResult.ignored;
    final code = char.codeUnitAt(0);
    if (code < 0x20 || code == 0x7F) return KeyEventResult.ignored;

    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return KeyEventResult.ignored;
    }

    final focus = _controller.selectionController.focus;
    if (focus == null) return KeyEventResult.ignored;

    _startIntegratedEdit(
      cell: focus,
      trigger: EditTrigger.typing,
      initialText: char,
    );
    return KeyEventResult.handled;
  }

  // Auto-scroll helpers

  Rect _getContentArea(WorksheetThemeData theme) {
    final size = context.size!;
    final zoom = _controller.zoom;
    final left = theme.showHeaders ? theme.rowHeaderWidth * zoom : 0.0;
    final top = theme.showHeaders ? theme.columnHeaderHeight * zoom : 0.0;
    return Rect.fromLTRB(left, top, size.width, size.height);
  }

  void _onAutoScrollTick() {
    final position = _lastPointerPosition;
    if (position == null ||
        (!_gestureHandler.isSelectingRange && !_gestureHandler.isFilling)) {
      _stopAutoScroll();
      return;
    }

    final theme = WorksheetTheme.of(context);
    final contentArea = _getContentArea(theme);

    final dx = calcAutoScrollDelta(
      position.dx,
      contentArea.left,
      contentArea.right,
    );
    final dy = calcAutoScrollDelta(
      position.dy,
      contentArea.top,
      contentArea.bottom,
    );

    if (dx == 0.0 && dy == 0.0) return;

    final hController = _controller.horizontalScrollController;
    final vController = _controller.verticalScrollController;

    if (dx != 0.0 && hController.hasClients) {
      final maxH = hController.position.maxScrollExtent;
      final newX = (hController.offset + dx).clamp(0.0, maxH);
      hController.jumpTo(newX);
    }

    if (dy != 0.0 && vController.hasClients) {
      final maxV = vController.position.maxScrollExtent;
      final newY = (vController.offset + dy).clamp(0.0, maxV);
      vController.jumpTo(newY);
    }

    // Clamp position to content area so the hit test resolves to a cell
    // at the viewport edge, not a header or none result.
    final clampedPosition = Offset(
      position.dx.clamp(contentArea.left + 1, contentArea.right - 1),
      position.dy.clamp(contentArea.top + 1, contentArea.bottom - 1),
    );

    _gestureHandler.onDragUpdate(
      position: clampedPosition,
      scrollOffset: Offset(_controller.scrollX, _controller.scrollY),
      zoom: _controller.zoom,
    );
  }

  void _startAutoScroll() {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(
      _autoScrollInterval,
      (_) => _onAutoScrollTick(),
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastPointerPosition = null;
  }

  void _onControllerChanged() {
    setState(() {});
  }

  void _onDataChanged(DataChangeEvent event) {
    if (!_initialized) return;
    switch (event.type) {
      case DataChangeType.cellValue:
      case DataChangeType.cellStyle:
      case DataChangeType.cellFormat:
        if (event.cell != null) {
          _tileManager.invalidateRange(
            CellRange(
              event.cell!.row,
              event.cell!.column,
              event.cell!.row,
              event.cell!.column,
            ),
          );
        }
      case DataChangeType.range:
        if (event.range != null) {
          _tileManager.invalidateRange(event.range!);
        }
      case DataChangeType.merge:
      case DataChangeType.unmerge:
        if (event.range != null) {
          _tileManager.invalidateRange(event.range!);
        }
      case DataChangeType.reset:
      case DataChangeType.rowInserted:
      case DataChangeType.rowDeleted:
      case DataChangeType.columnInserted:
      case DataChangeType.columnDeleted:
        _tileManager.invalidateAll();
    }
    _layoutVersion++;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(Worksheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _controller.detachLayout();
      if (_ownsController) {
        _controller.removeListener(_onControllerChanged);
        _controller.dispose();
      } else {
        _controller.removeListener(_onControllerChanged);
      }

      _initController();
      if (_initialized) {
        // Re-attach layout to the new controller
        final theme = WorksheetTheme.of(context);
        _controller.attachLayout(
          _layoutSolver,
          headerWidth: theme.showHeaders ? theme.rowHeaderWidth : 0.0,
          headerHeight: theme.showHeaders ? theme.columnHeaderHeight : 0.0,
        );
        _gestureHandler = WorksheetGestureHandler(
          hitTester: _hitTester,
          selectionController: _controller.selectionController,
          onEditCell: widget.onEditCell,
          onResizeRow: (row, delta) {
            final currentHeight = _layoutSolver.getRowHeight(row);
            final newHeight = (currentHeight + delta).clamp(10.0, 500.0);
            _layoutSolver.setRowHeight(row, newHeight);
            _tileManager.invalidateAll();
            _layoutVersion++;
            widget.onResizeRow?.call(row, newHeight);
            setState(() {});
          },
          onResizeColumn: (column, delta) {
            final currentWidth = _layoutSolver.getColumnWidth(column);
            final newWidth = (currentWidth + delta).clamp(20.0, 1000.0);
            _layoutSolver.setColumnWidth(column, newWidth);
            _tileManager.invalidateAll();
            _layoutVersion++;
            widget.onResizeColumn?.call(column, newWidth);
            setState(() {});
          },
          onResizeRowEnd: (row) {
            _applyResizeToSelectedRows(row);
          },
          onResizeColumnEnd: (column) {
            _applyResizeToSelectedColumns(column);
          },
          onFillPreviewUpdate: widget.readOnly
              ? null
              : (previewRange) {
                  _selectionLayer.fillPreviewRange = previewRange;
                  setState(() {});
                },
          onFillComplete: widget.readOnly
              ? null
              : (sourceRange, destination) {
                  widget.data.smartFill(sourceRange, destination);
                  _controller.selectionController.selectRange(
                    sourceRange.expand(destination),
                  );
                  _selectionLayer.fillPreviewRange = null;
                  _tileManager.invalidateAll();
                  _layoutVersion++;
                  setState(() {});
                },
          onFillCancel: widget.readOnly
              ? null
              : () {
                  _selectionLayer.fillPreviewRange = null;
                  setState(() {});
                },
        );
        _clipboardHandler = ClipboardHandler(
          data: widget.data,
          selectionController: _controller.selectionController,
          serializer:
              widget.clipboardSerializer ??
              TsvClipboardSerializer(dateParser: widget.dateParser),
        );
        widget.editController?.dateParser = widget.dateParser;
        if (widget.formatLocale != null) {
          widget.editController?.locale = widget.formatLocale!;
        }
        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
        _selectionLayer.dispose();
        _headerLayer.dispose();
        _initLayers(theme, devicePixelRatio);
      }
    }

    if (widget.editController != oldWidget.editController) {
      oldWidget.editController?.removeListener(_onEditTextChanged);
      widget.editController?.addListener(_onEditTextChanged);
    }

    if (widget.data != oldWidget.data && _initialized) {
      _dataSubscription?.cancel();
      // Remove listener before re-init (which adds it again)
      widget.editController?.removeListener(_onEditTextChanged);
      final theme = WorksheetTheme.of(context);
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      _tileManager.dispose();
      _selectionLayer.dispose();
      _headerLayer.dispose();
      _initRendering(theme, devicePixelRatio);
      _initLayers(theme, devicePixelRatio);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = WorksheetTheme.of(context);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    _ensureInitialized(theme, devicePixelRatio);

    // Re-init layers when theme or devicePixelRatio changes
    if (_initialized &&
        (_lastTheme != theme || _lastDevicePixelRatio != devicePixelRatio)) {
      if (_lastTheme != null) {
        _selectionLayer.dispose();
        _headerLayer.dispose();
        _tileManager.dispose();
        _initRendering(theme, devicePixelRatio);
        _initLayers(theme, devicePixelRatio);
      }
      _lastTheme = theme;
      _lastDevicePixelRatio = devicePixelRatio;
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_initialized) {
      _selectionLayer.dispose();
      _headerLayer.dispose();
      _tileManager.dispose();
      _initialized = false;
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _keyboardScrollTimer?.cancel();
    _dataSubscription?.cancel();
    widget.editController?.removeListener(_onEditTextChanged);
    _controller.detachLayout();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_initialized) {
      _selectionLayer.dispose();
      _headerLayer.dispose();
      _tileManager.dispose();
    }
    _editorTriggerController.dispose();
    _editorFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = WorksheetTheme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    _ensureInitialized(theme, devicePixelRatio);

    // Detect keyboard appearance and scroll to keep editing cell visible
    final viewInsets = mediaQuery.viewInsets;
    if (viewInsets.bottom > _lastViewInsets.bottom) {
      // Keyboard appeared or grew — scroll editing cell into view
      final ec = widget.editController;
      if (ec != null && ec.isEditing) {
        final cell = ec.editingCell;
        if (cell != null) {
          // Cancel any pending scroll timer and start a new one.
          // Delay slightly to let keyboard animation settle.
          _keyboardScrollTimer?.cancel();
          _keyboardScrollTimer = Timer(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            final ec2 = widget.editController;
            if (ec2 == null || !ec2.isEditing) return;
            _scrollCellToCenter(cell);
          });
        }
      }
    }
    _lastViewInsets = viewInsets;

    // Use Listener for low-level pointer events to handle:
    // - Left mouse button: tap and drag for selection
    // - Scroll wheel: handled by TwoDimensionalScrollable

    // Merge default shortcuts with consumer overrides.
    final effectiveShortcuts = widget.readOnly
        ? <ShortcutActivator, Intent>{}
        : <ShortcutActivator, Intent>{
            ...DefaultWorksheetShortcuts.shortcuts,
            ...?widget.shortcuts,
          };

    // Merge default actions with consumer overrides.
    final effectiveActions = widget.readOnly
        ? <Type, Action<Intent>>{}
        : <Type, Action<Intent>>{..._defaultActions, ...?widget.actions};

    return Shortcuts(
      shortcuts: effectiveShortcuts,
      child: Actions(
        actions: effectiveActions,
        child: Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: widget.editController != null ? _handleTypeToEdit : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: _currentCursor,
                  onHover: widget.readOnly
                      ? null
                      : (event) {
                          final hit = _hitTester.hitTest(
                            position: event.localPosition,
                            scrollOffset: Offset(
                              _controller.scrollX,
                              _controller.scrollY,
                            ),
                            zoom: _controller.zoom,
                            selectionRange:
                                _controller.selectionController.selectedRange,
                          );
                          final newCursor = switch (hit.type) {
                            HitTestType.rowResizeHandle =>
                              SystemMouseCursors.resizeRow,
                            HitTestType.columnResizeHandle =>
                              SystemMouseCursors.resizeColumn,
                            HitTestType.fillHandle =>
                              SystemMouseCursors.precise,
                            _ => SystemMouseCursors.basic,
                          };
                          if (_currentCursor != newCursor) {
                            setState(() {
                              _currentCursor = newCursor;
                            });
                          }
                        },
                  child: Listener(
                    onPointerDown: widget.readOnly
                        ? null
                        : (event) {
                            _lastPointerKind = event.kind;
                            // Only handle primary button (left click) for selection
                            if (event.buttons == kPrimaryButton) {
                              // Skip selection when pointer is on a scrollbar
                              if (_isInScrollbarArea(
                                event.localPosition,
                                theme,
                              )) {
                                _pointerInScrollbarArea = true;
                                return;
                              }
                              _pointerInScrollbarArea = false;

                              // If editing, check whether the tap is inside the
                              // editing area (which may be expanded beyond the
                              // original cell).  If so, let it reach the TextField
                              // for cursor positioning / text selection.  If outside,
                              // commit the edit and proceed with normal selection.
                              final ec = widget.editController;
                              if (ec != null && ec.isEditing) {
                                final editingCell = ec.editingCell;
                                if (editingCell != null) {
                                  // Use expanded editing bounds (in worksheet
                                  // coords) converted to screen coords for hit
                                  // testing, so taps inside the expanded area
                                  // don't commit the edit.
                                  final editBounds = _selectionRenderer.editingFocusBounds;
                                  final Rect? hitRect;
                                  if (editBounds != null) {
                                    final zoom = _controller.zoom;
                                    final hdrLeft = theme.showHeaders
                                        ? theme.rowHeaderWidth * zoom
                                        : 0.0;
                                    final hdrTop = theme.showHeaders
                                        ? theme.columnHeaderHeight * zoom
                                        : 0.0;
                                    hitRect = Rect.fromLTWH(
                                      editBounds.left * zoom - _controller.scrollX + hdrLeft,
                                      editBounds.top * zoom - _controller.scrollY + hdrTop,
                                      editBounds.width * zoom,
                                      editBounds.height * zoom,
                                    );
                                  } else {
                                    hitRect = _controller
                                        .getCellScreenBounds(editingCell);
                                  }
                                  if (hitRect != null &&
                                      hitRect.contains(
                                        event.localPosition,
                                      )) {
                                    return; // tap inside editing area — hand off to TextField
                                  }
                                }
                                ec.commitEdit(onCommit: _onInternalCommit);
                              }

                              _gestureHandler.onTapDown(
                                position: event.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                                isShiftPressed: HardwareKeyboard
                                    .instance.isShiftPressed,
                              );
                              widget.onCellTap?.call(
                                _controller.focusCell ??
                                    const CellCoordinate(0, 0),
                              );
                              _gestureHandler.onDragStart(
                                position: event.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                                isShiftPressed: HardwareKeyboard
                                    .instance.isShiftPressed,
                              );
                            }
                          },
                    onPointerMove: widget.readOnly
                        ? null
                        : (event) {
                            // Only handle drag when primary button is held
                            if (event.buttons == kPrimaryButton &&
                                !_pointerInScrollbarArea) {
                              _gestureHandler.onDragUpdate(
                                position: event.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                              );

                              // Auto-scroll when dragging outside the content area
                              _lastPointerPosition = event.localPosition;
                              if (_gestureHandler.isSelectingRange ||
                                  _gestureHandler.isFilling) {
                                final contentArea = _getContentArea(theme);
                                final pos = event.localPosition;
                                if (pos.dx < contentArea.left ||
                                    pos.dx > contentArea.right ||
                                    pos.dy < contentArea.top ||
                                    pos.dy > contentArea.bottom) {
                                  _startAutoScroll();
                                }
                              }
                            }
                          },
                    onPointerUp: widget.readOnly
                        ? null
                        : (event) {
                            _stopAutoScroll();
                            _pointerInScrollbarArea = false;
                            _gestureHandler.onDragEnd();
                          },
                    child: GestureDetector(
                      // Use onDoubleTapDown (fires on second pointer-down)
                      // instead of onDoubleTap (fires after second pointer-up)
                      // so that editing starts while iOS is still processing
                      // the touch event, allowing the keyboard to appear.
                      onDoubleTapDown: widget.readOnly
                          ? null
                          : (widget.onEditCell == null &&
                                widget.editController == null)
                          ? null
                          // When already editing, don't register a double-tap
                          // handler so the TextField's double-tap (word select)
                          // wins the gesture arena.
                          : (widget.editController?.isEditing == true)
                          ? null
                          : (TapDownDetails details) {
                              final cell = _controller.focusCell;
                              if (cell == null) return;
                              // Fire external callback
                              widget.onEditCell?.call(cell);
                              // Also start integrated editing if available
                              if (widget.editController != null) {
                                // Focus the offstage trigger TextField
                                // synchronously within this gesture handler.
                                // iOS Safari requires focus() to happen
                                // synchronously with a user gesture for the
                                // virtual keyboard to appear.
                                _editorFocusNode.requestFocus();
                                _startIntegratedEdit(
                                  cell: cell,
                                  trigger: EditTrigger.doubleTap,
                                );
                              }
                            },
                      child: Stack(
                        children: [
                          // Transparent hit target for the entire area (including headers)
                          // This ensures pointer events are captured everywhere
                          Positioned.fill(
                            child: Container(color: const Color(0x00000000)),
                          ),

                          // Content area (offset by headers, scaled by zoom)
                          Positioned(
                            left: theme.showHeaders
                                ? theme.rowHeaderWidth * _controller.zoom
                                : 0,
                            top: theme.showHeaders
                                ? theme.columnHeaderHeight * _controller.zoom
                                : 0,
                            right: 0,
                            bottom: 0,
                            child: _buildScrollableContent(theme),
                          ),

                          // Selection layer (painted on top of content)
                          if (theme.showHeaders && _controller.hasSelection)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _SelectionPainter(
                                    layer: _selectionLayer,
                                    scrollOffset: Offset(
                                      _controller.scrollX / _controller.zoom,
                                      _controller.scrollY / _controller.zoom,
                                    ),
                                    zoom: _controller.zoom,
                                    headerOffset: Offset(
                                      theme.rowHeaderWidth * _controller.zoom,
                                      theme.columnHeaderHeight *
                                          _controller.zoom,
                                    ),
                                    layoutVersion: _layoutVersion,
                                  ),
                                ),
                              ),
                            ),

                          // Headers layer (fixed position)
                          if (theme.showHeaders)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _HeaderPainter(
                                    layer: _headerLayer,
                                    scrollOffset: Offset(
                                      _controller.scrollX / _controller.zoom,
                                      _controller.scrollY / _controller.zoom,
                                    ),
                                    zoom: _controller.zoom,
                                    layoutVersion: _layoutVersion,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Cell editor overlay placed OUTSIDE Listener/GestureDetector
              // so touch events (especially on iOS) reach the TextField
              // directly, ensuring the software keyboard appears.
              // Wrapped in a clipped Stack covering only the content area
              // (below and right of headers) so the overlay scrolls behind
              // headers instead of floating over them.
              if (widget.editController != null)
                Positioned(
                  left: theme.showHeaders
                      ? theme.rowHeaderWidth * _controller.zoom
                      : 0,
                  top: theme.showHeaders
                      ? theme.columnHeaderHeight * _controller.zoom
                      : 0,
                  right: 0,
                  bottom: 0,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      ListenableBuilder(
                        listenable: widget.editController!,
                        builder: (context, _) {
                          final headerLeft = theme.showHeaders
                              ? theme.rowHeaderWidth * _controller.zoom
                              : 0.0;
                          final headerTop = theme.showHeaders
                              ? theme.columnHeaderHeight * _controller.zoom
                              : 0.0;
                          if (!widget.editController!.isEditing) {
                            return const Positioned(
                              left: 0,
                              top: 0,
                              child: SizedBox.shrink(),
                            );
                          }
                          final cell = widget.editController!.editingCell;
                          if (cell == null) {
                            return const Positioned(
                              left: 0,
                              top: 0,
                              child: SizedBox.shrink(),
                            );
                          }
                          final bounds = _controller.getCellScreenBounds(cell);
                          if (bounds == null) {
                            return const Positioned(
                              left: 0,
                              top: 0,
                              child: SizedBox.shrink(),
                            );
                          }
                          // Shift bounds to be relative to the content area
                          // origin so the clipped Stack hides overflow behind
                          // headers.
                          final adjustedBounds = bounds.shift(
                            Offset(-headerLeft, -headerTop),
                          );
                          // Resolve per-cell style the same way tile_painter does
                          final cellStyle = CellStyle.defaultStyle.merge(
                            widget.data.getStyle(cell),
                          );
                          final isWrap = cellStyle.wrapText == true;
                          final fontFamily = cellStyle.fontFamily ?? theme.fontFamily;

                          // Use precomputed expanded bounds from _onEditTextChanged
                          final adjustedExpandedBounds = _editingExpandedScreenBounds;

                          return CellEditorOverlay(
                            editController: widget.editController!,
                            cellBounds: adjustedBounds,
                            expandedBounds: adjustedExpandedBounds,
                            onCommit: _onInternalCommit,
                            onCancel: _onInternalCancel,
                            onCommitAndNavigate: _onInternalCommitAndNavigate,
                            zoom: _controller.zoom,
                            fontSize: cellStyle.fontSize ?? theme.fontSize,
                            fontFamily: fontFamily,
                            fontWeight:
                                cellStyle.fontWeight ?? FontWeight.normal,
                            fontStyle: cellStyle.fontStyle ?? FontStyle.normal,
                            textColor: cellStyle.textColor ?? theme.textColor,
                            textAlign: _toTextAlign(
                              cellStyle.textAlignment ??
                                  (widget.data.getCell(cell) != null
                                      ? CellStyle.implicitAlignment(
                                          widget.data.getCell(cell)!.type)
                                      : null),
                            ),
                            cellPadding: theme.cellPadding,
                            richText: widget.data.getRichText(cell),
                            verticalAlignment: cellStyle.verticalAlignment ??
                                CellVerticalAlignment.middle,
                            wrapText: isWrap,
                            restoreFocusTo: _keyboardFocusNode,
                            contentAreaWidth: _editingContentAreaWidth,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              // Hidden TextField that acts as a keyboard trigger on iOS Safari.
              // iOS Safari requires focus() to be synchronous with a user
              // gesture for the virtual keyboard to appear. This offstage
              // EditableText provides the text input connection that can be
              // focused synchronously in the double-tap handler. The visible
              // CellEditorOverlay's TextField then takes over focus.
              if (widget.editController != null)
                Positioned(
                  left: 0,
                  top: 0,
                  width: 1,
                  height: 1,
                  child: Offstage(
                    child: EditableText(
                      controller: _editorTriggerController,
                      focusNode: _editorFocusNode,
                      style: const TextStyle(fontSize: 1),
                      cursorColor: const Color(0x00000000),
                      backgroundCursorColor: const Color(0x00000000),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Checks if a pointer position is within the scrollbar track area.
  bool _isInScrollbarArea(Offset position, WorksheetThemeData theme) {
    final config = _resolveScrollbarConfig();
    final size = context.size;
    if (size == null) return false;

    final scrollbarThickness = config.thickness ?? 8.0;
    final headerLeft = theme.showHeaders
        ? theme.rowHeaderWidth * _controller.zoom
        : 0.0;
    final headerTop = theme.showHeaders
        ? theme.columnHeaderHeight * _controller.zoom
        : 0.0;

    // Vertical scrollbar area (right edge of content area)
    if (config.verticalVisibility != ScrollbarVisibility.never &&
        position.dx > headerLeft &&
        position.dx > size.width - scrollbarThickness) {
      return true;
    }

    // Horizontal scrollbar area (bottom edge of content area)
    if (config.horizontalVisibility != ScrollbarVisibility.never &&
        position.dy > headerTop &&
        position.dy > size.height - scrollbarThickness) {
      return true;
    }

    return false;
  }

  WorksheetScrollbarConfig _resolveScrollbarConfig() {
    if (widget.scrollbarConfig != null) return widget.scrollbarConfig!;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return WorksheetScrollbarConfig.desktop;
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return WorksheetScrollbarConfig.mobile;
    }
  }

  Widget _buildScrollableContent(WorksheetThemeData theme) {
    final config = _resolveScrollbarConfig();

    // Use TwoDimensionalScrollable for proper 2D scrolling.
    // TwoDimensionalScrollable does not build scrollbars (Flutter #122348),
    // so we wrap with explicit RawScrollbar widgets below.
    Widget content = TwoDimensionalScrollable(
      diagonalDragBehavior: widget.diagonalDragBehavior,
      horizontalDetails: ScrollableDetails.horizontal(
        controller: _controller.horizontalScrollController,
        physics: const BouncingScrollPhysics(),
      ),
      verticalDetails: ScrollableDetails.vertical(
        controller: _controller.verticalScrollController,
        physics: const BouncingScrollPhysics(),
      ),
      viewportBuilder: (context, verticalPosition, horizontalPosition) {
        return WorksheetViewport(
          horizontalPosition: horizontalPosition,
          verticalPosition: verticalPosition,
          tileManager: _tileManager,
          layoutSolver: _layoutSolver,
          zoom: _controller.zoom,
          layoutVersion: _layoutVersion,
        );
      },
    );

    // Wrap with scrollbar widgets.
    // TwoDimensionalScrollable does not build scrollbars (Flutter #122348),
    // so we add them explicitly. Uses Material Scrollbar for platform-native
    // appearance (macOS fade, Windows always-visible, etc.) and to avoid
    // Flutter #57920 (horizontal scrollbar skipped by MaterialScrollBehavior).
    if (config.horizontalVisibility != ScrollbarVisibility.never) {
      content = Scrollbar(
        controller: _controller.horizontalScrollController,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        thumbVisibility:
            config.horizontalVisibility == ScrollbarVisibility.always,
        interactive: config.interactive,
        thickness: config.thickness,
        radius: config.radius,
        notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
        child: content,
      );
    }

    if (config.verticalVisibility != ScrollbarVisibility.never) {
      content = Scrollbar(
        controller: _controller.verticalScrollController,
        scrollbarOrientation: ScrollbarOrientation.right,
        thumbVisibility:
            config.verticalVisibility == ScrollbarVisibility.always,
        interactive: config.interactive,
        thickness: config.thickness,
        radius: config.radius,
        notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
        child: content,
      );
    }

    return content;
  }
}

/// Enters edit mode on the currently focused cell.
///
/// When an integrated [EditController] is available, starts editing
/// via the controller (F2 trigger). Also fires the external [onEditCell]
/// callback for backward compatibility.
class _IntegratedEditCellAction extends Action<EditCellIntent> {
  final _WorksheetState _state;

  _IntegratedEditCellAction(this._state);

  @override
  Object? invoke(EditCellIntent intent) {
    final focus = _state.selectionController.focus;
    if (focus == null) return null;

    // Fire external callback
    _state.onEditCell?.call(focus);

    // Also start integrated editing if available
    final ec = _state.widget.editController;
    if (ec != null) {
      _state._startIntegratedEdit(cell: focus, trigger: EditTrigger.f2Key);
    }
    return null;
  }
}

/// Calculates the auto-scroll speed delta for one axis.
///
/// Returns a negative value to scroll toward [start], positive toward [end],
/// or 0 if [pos] is inside [start]..[end].
///
/// Speed ramps linearly from [baseSpeed] to [maxSpeed] over [rampDistance]
/// pixels past the edge.
@visibleForTesting
double calcAutoScrollDelta(
  double pos,
  double start,
  double end, {
  double baseSpeed = 5.0,
  double maxSpeed = 40.0,
  double rampDistance = 100.0,
}) {
  if (pos < start) {
    final t = ((start - pos) / rampDistance).clamp(0.0, 1.0);
    return -(lerpDouble(baseSpeed, maxSpeed, t)!);
  } else if (pos > end) {
    final t = ((pos - end) / rampDistance).clamp(0.0, 1.0);
    return lerpDouble(baseSpeed, maxSpeed, t)!;
  }
  return 0.0;
}

/// Custom painter for selection layer.
class _SelectionPainter extends CustomPainter {
  final SelectionLayer layer;
  final Offset scrollOffset;
  final double zoom;
  final Offset headerOffset;
  final int layoutVersion;
  final CellRange? fillPreviewRange;

  _SelectionPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
    required this.headerOffset,
    required this.layoutVersion,
  }) : fillPreviewRange = layer.fillPreviewRange,
       super(repaint: layer.selectionController);

  @override
  void paint(Canvas canvas, Size size) {
    // Offset for headers
    canvas.save();
    canvas.translate(headerOffset.dx, headerOffset.dy);
    canvas.clipRect(
      Rect.fromLTWH(
        0,
        0,
        size.width - headerOffset.dx,
        size.height - headerOffset.dy,
      ),
    );

    layer.paint(
      LayerPaintContext(
        canvas: canvas,
        viewportSize: size,
        scrollOffset: scrollOffset,
        zoom: zoom,
      ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) {
    return layer != oldDelegate.layer ||
        scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        headerOffset != oldDelegate.headerOffset ||
        layoutVersion != oldDelegate.layoutVersion ||
        fillPreviewRange != oldDelegate.fillPreviewRange;
  }
}

/// Custom painter for header layer.
class _HeaderPainter extends CustomPainter {
  final HeaderLayer layer;
  final Offset scrollOffset;
  final double zoom;
  final int layoutVersion;

  _HeaderPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
    required this.layoutVersion,
  }) : super(repaint: layer.selectionController);

  @override
  void paint(Canvas canvas, Size size) {
    layer.paint(
      LayerPaintContext(
        canvas: canvas,
        viewportSize: size,
        scrollOffset: scrollOffset,
        zoom: zoom,
      ),
    );
  }

  @override
  bool shouldRepaint(_HeaderPainter oldDelegate) {
    return layer != oldDelegate.layer ||
        scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        layoutVersion != oldDelegate.layoutVersion;
  }
}
