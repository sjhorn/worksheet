import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:any_date/any_date.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide UndoManager;

import '../core/core.dart';
import '../interaction/interaction.dart';
import '../rendering/rendering.dart';
import '../scrolling/worksheet_viewport.dart';
import '../shortcuts/shortcuts.dart';
import 'autocomplete_dropdown.dart';
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

  /// Optional raw data source for editing.
  ///
  /// When provided, the cell editor shows values from [rawData] instead of
  /// [data]. This lets a consuming app wrap [data] to evaluate formulas
  /// (e.g., replacing `CellValue.formula("=SUM(A1:A5)")` with
  /// `CellValue.number(15)`) while still editing the original formula text.
  ///
  /// Only affects cell editing — tile rendering, styling, clipboard, and
  /// formatting all continue to use [data].
  final WorksheetData? rawData;

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

	/// Enables drag-and-drop move of selected cells (selection border / long-press).
	///
	/// When `false`, cell move gestures are disabled while selection/editing stay available.
	final bool enableMove;


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

  /// Adjusts cell references in formulas during fill operations.
  ///
  /// When non-null, fill down (Ctrl+D), fill right (Ctrl+R), and drag-to-fill
  /// adjust relative references by the fill offset. For example, `=A1+B1`
  /// filled down one row becomes `=A2+B2`.
  ///
  /// Set to `null` to copy formulas verbatim (legacy behavior).
  /// Defaults to [defaultFormulaReferenceAdjuster].
  final FormulaReferenceAdjuster? formulaReferenceAdjuster;

  /// Configuration for formula cell reference editing.
  ///
  /// When non-null, enables Excel-style formula reference editing:
  /// clicking cells inserts A1 references, dragging inserts ranges,
  /// F4 cycles absolute/relative modes, and colored borders highlight
  /// referenced cells.
  ///
  /// Set to `null` to disable formula reference editing.
  /// Defaults to `const FormulaReferenceConfig()`.
  final FormulaReferenceConfig? formulaReferenceConfig;

  /// Configuration for formula function autocomplete.
  ///
  /// When non-null, enables autocomplete suggestions when typing function
  /// names in formula mode (cells starting with `=`). Users provide their
  /// own function list; the package does not bundle built-in functions.
  ///
  /// Set to `null` (default) to disable formula autocomplete.
  final FormulaAutocompleteConfig? formulaAutocompleteConfig;

  /// Called when an autocomplete suggestion is accepted.
  ///
  /// Receives the accepted [FormulaFunction]. Use this to show an argument
  /// tooltip, log analytics, or perform any custom action when the user
  /// selects a function from the dropdown.
  ///
  /// The function name and opening parenthesis are inserted into the formula
  /// automatically — this callback is for additional side effects.
  final void Function(FormulaFunction fn)? onAutocompleteAccept;

  /// Controls whether mobile interaction mode is enabled.
  ///
  /// When `true`, enables touch-friendly interactions:
  /// - One-finger drag scrolls (instead of selecting)
  /// - Selection handles at corners for extending selection
  /// - Long-press to move selected cells
  /// - Pinch-to-zoom
  /// - Larger hit targets for resize and selection handles
  /// - No hover cursor changes
  ///
  /// When `false`, uses desktop interaction mode (mouse cursors,
  /// click-drag selection, hover states, small hit targets).
  ///
  /// When `null` (default), auto-detects based on platform:
  /// iOS and Android use mobile mode, all others use desktop mode.
  final bool? mobileMode;

  /// Configuration for frozen (pinned) rows and columns.
  ///
  /// Frozen rows stay fixed at the top of the viewport while scrolling
  /// vertically. Frozen columns stay fixed at the left while scrolling
  /// horizontally. The frozen layer is painted on top of tile content.
  ///
  /// Defaults to [FreezeConfig.none] (no frozen panes).
  final FreezeConfig freezeConfig;

  const Worksheet({
    super.key,
    required this.data,
    this.rawData,
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
    this.enableMove = true,
    this.dateParser,
    this.formatLocale,
    this.clipboardSerializer,
    this.diagonalDragBehavior = DiagonalDragBehavior.free,
    this.scrollbarConfig,
    this.shortcuts,
    this.actions,
    this.formulaReferenceAdjuster = defaultFormulaReferenceAdjuster,
    this.formulaReferenceConfig = const FormulaReferenceConfig(),
    this.formulaAutocompleteConfig,
    this.onAutocompleteAccept,
    this.mobileMode,
    this.freezeConfig = FreezeConfig.none,
  });

  @override
  State<Worksheet> createState() => _WorksheetState();
}

class _WorksheetState extends State<Worksheet>
    with TickerProviderStateMixin, WorksheetActionContext {
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
  FrozenLayer? _frozenLayer;

  bool _initialized = false;

  /// Cached effective actions map, rebuilt every build().
  /// Used by [_dispatchAction] and [_isActionEnabled] so the controller
  /// can invoke any registered worksheet action.
  Map<Type, Action<Intent>> _effectiveActions = const {};

  /// Controller for formula autocomplete, created when config is non-null.
  AutocompleteController? _autocompleteController;

  /// Whether mobile interaction mode is active.
  ///
  /// Resolved from [Worksheet.mobileMode]: explicit override if set,
  /// otherwise auto-detects based on [defaultTargetPlatform].
  bool get _isMobileMode {
    if (widget.mobileMode != null) return widget.mobileMode!;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  WorksheetThemeData? _lastTheme;
  double? _lastDevicePixelRatio;
  MouseCursor _currentCursor = SystemMouseCursors.basic;
  int _layoutVersion = 0;
  bool _pointerInScrollbarArea = false;

  /// Set by onDoubleTapDown when it handles a non-cell double-tap (resize
  /// handle, selection border).  Checked by Listener.onPointerDown to skip
  /// the tap-down + drag-start that would otherwise run on the same pointer
  /// event — by then the layout may have changed (e.g. auto-fit resized a
  /// column), so a fresh hit-test at the original position would give a
  /// wrong result (e.g. columnHeader instead of columnResizeHandle).
  bool _doubleTapHandledPointerDown = false;

  // Track viewInsets for keyboard visibility changes
  EdgeInsets _lastViewInsets = EdgeInsets.zero;

  // Cached expansion state computed by _onEditTextChanged()
  Rect? _editingExpandedBounds; // worksheet coords
  double? _editingVerticalOffset; // fixed vertical offset for wrap-text cells
  double? _editingContentAreaWidth; // viewport width minus row header
  double? _editingContentAreaHeight; // viewport height minus col header

  // Cut indicator state (deferred cut with marching ants)
  CutIndicatorLayer? _cutIndicatorLayer;
  AnimationController? _cutAntsController;
  CellRange? _cutRange;

  // Formula reference editing state
  FormulaReferenceLayer? _formulaRefLayer;
  AnimationController? _marchingAntsController;
  bool _formulaDragging = false;
  CellCoordinate? _formulaDragStart;

  // Cached CellEditorOverlay widget to prevent force-rebuilds on every
  // keystroke. Returning the identical widget instance from the
  // ListenableBuilder's builder prevents StatefulElement.update from calling
  // rebuild(force: true), so the overlay's EditableText only rebuilds from
  // its own setState (text input changes). The cache is invalidated when
  // layout-relevant props change (bounds, zoom, expanded bounds).
  Widget? _cachedEditorOverlay;
  CellCoordinate? _cachedEditorCell;
  Rect? _cachedEditorCellBounds;
  Rect? _cachedEditorExpandedBounds;
  double? _cachedEditorZoom;
  double? _cachedEditorContentAreaWidth;

  // Data change subscription for external mutations
  StreamSubscription<DataChangeEvent>? _dataSubscription;

  // Microtask coalescing for data change events.
  // Null means no microtask is scheduled; non-null buffers events until
  // the next microtask processes them in a single pass.
  List<DataChangeEvent>? _pendingDataChanges;

  // Merged listenable for the editor overlay's ListenableBuilder.
  // Combines editController (for text/edit changes) with both scroll
  // controllers so the overlay repositions on every scroll frame.
  Listenable? _editorOverlayListenable;

  // Pinch-to-zoom
  ScaleHandler? _scaleHandler;
  final Map<int, Offset> _activePointers = {};
  double _pinchStartDistance = 0;

  // Trackpad pinch-to-zoom (macOS/Linux: PointerPanZoom events)
  double _lastTrackpadScale = 1.0;

  // Shared flag checked by _scrollPhysics on every drag update.
  // Setting suppress = true immediately blocks user-initiated scrolling.
  final ScrollSuppressor _scrollSuppressor = ScrollSuppressor();
  late final SuppressibleBouncingPhysics _scrollPhysics =
      SuppressibleBouncingPhysics(suppressor: _scrollSuppressor);

  // Track original size for resize cancel (Escape key)
  double? _resizeDragOriginalSize;
  int? _resizeDragIndex;
  bool _resizeDragIsRow = false;

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
  FormulaReferenceAdjuster? get formulaReferenceAdjuster =>
      widget.formulaReferenceAdjuster;

  @override
  LayoutSolver? get layoutSolver => _layoutSolver;

  @override
  UndoManager? get undoManager => _controller.undoManager;

  @override
  CellRange? get pendingCutRange => _cutRange;

  @override
  void setPendingCutRange(CellRange? range) {
    if (_cutRange == range) return;
    _cutRange = range;
    _cutIndicatorLayer?.range = range;
    if (range != null) {
      _cutAntsController?.repeat();
    } else {
      _cutAntsController?.stop();
      _cutAntsController?.reset();
    }
    invalidateAndRebuild();
  }

  @override
  void ensureSelectionVisible() => _ensureSelectionVisible();

  @override
  void invalidateAndRebuild() {
    _cachedEditorOverlay = null;
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
    SetCellStyleIntent: SetCellStyleAction(this),
    UndoIntent: UndoAction(this),
    RedoIntent: RedoAction(this),
    ToggleBoldIntent: ToggleBoldAction(this),
    ToggleItalicIntent: ToggleItalicAction(this),
    ToggleUnderlineIntent: ToggleUnderlineAction(this),
    ToggleStrikethroughIntent: ToggleStrikethroughAction(this),
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
      freezeConfig: widget.freezeConfig,
    );

    // Attach layout to controller for public API access
    _controller.attachLayout(
      _layoutSolver,
      headerWidth: theme.showHeaders ? theme.rowHeaderWidth : 0.0,
      headerHeight: theme.showHeaders ? theme.columnHeaderHeight : 0.0,
    );
    _controller.freezeConfig = widget.freezeConfig;
    _scrollSuppressor.freezeConfig = widget.freezeConfig;

    // Attach action dispatcher so controller.invokeAction() works
    _controller.attachActionDispatcher(
      dispatcher: _dispatchAction,
      enabledChecker: _isActionEnabled,
    );
  }

  /// Dispatches an [Intent] by looking up the action in [_effectiveActions].
  ///
  /// Returns the action result, or null if no action is registered or the
  /// action is disabled.
  Object? _dispatchAction(Intent intent) {
    final action = _effectiveActions[intent.runtimeType];
    if (action == null) return null;
    if (!action.isEnabled(intent)) return null;
    // ignore: invalid_use_of_protected_member — we act as the dispatch layer
    return action.invoke(intent);
  }

  /// Whether the action for [intent] is registered and enabled.
  bool _isActionEnabled(Intent intent) {
    final action = _effectiveActions[intent.runtimeType];
    if (action == null) return false;
    return action.isEnabled(intent);
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
    _gestureHandler = _createGestureHandler();

    // Create scale handler for pinch-to-zoom
    _scaleHandler = ScaleHandler(zoomController: _controller.zoomController);

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

    // Create autocomplete controller when config is provided
    _autocompleteController?.dispose();
    _autocompleteController = widget.formulaAutocompleteConfig != null
        ? AutocompleteController(config: widget.formulaAutocompleteConfig!)
        : null;

    // Subscribe to data change events for external mutations
    _dataSubscription?.cancel();
    _dataSubscription = widget.data.changes.listen(_onDataChanged);

    // Listen to editController for expansion recomputation
    widget.editController?.addListener(_onEditTextChanged);

    // Build merged listenable so the editor overlay rebuilds on scroll
    _updateEditorOverlayListenable();
  }

  void _updateEditorOverlayListenable() {
    if (widget.editController != null) {
      _editorOverlayListenable = Listenable.merge([
        widget.editController!,
        _controller.horizontalScrollController,
        _controller.verticalScrollController,
      ]);
    } else {
      _editorOverlayListenable = null;
    }
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
      showFillHandle: !widget.readOnly && !_isMobileMode,
      showSelectionHandles: _isMobileMode,
    );

    _initFormulaRefLayer();
    _initCutIndicatorLayer();

    _headerLayer = HeaderLayer(
      renderer: _headerRenderer,
      selectionController: _controller.selectionController,
      freezeConfig: widget.freezeConfig,
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

    // Frozen layer (painted on top of tiles, below headers)
    _frozenLayer?.dispose();
    _frozenLayer = widget.freezeConfig.hasFrozenPanes
        ? (FrozenLayer(
            freezeConfig: widget.freezeConfig,
            data: widget.data,
            layoutSolver: _layoutSolver,
            onNeedsPaint: () => setState(() {}),
            backgroundColor: theme.cellBackgroundColor,
            gridlineColor: theme.gridlineColor,
            defaultTextColor: theme.textColor,
            defaultFontSize: theme.fontSize,
            defaultFontFamily: theme.fontFamily,
            cellPadding: theme.cellPadding,
            devicePixelRatio: devicePixelRatio,
          )..mergedCells = widget.data.mergedCells)
        : null;
  }

  void _initFormulaRefLayer() {
    _formulaRefLayer?.dispose();
    _marchingAntsController?.dispose();
    _marchingAntsController = null;
    _formulaRefLayer = null;

    if (widget.formulaReferenceConfig != null) {
      _formulaRefLayer = FormulaReferenceLayer(
        layoutSolver: _layoutSolver,
        onNeedsPaint: () => setState(() {}),
      );

      _marchingAntsController =
          AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1000),
          )..addListener(() {
            final layer = _formulaRefLayer;
            if (layer != null && layer.activeIndex >= 0) {
              layer.animationValue = _marchingAntsController!.value;
              layer.markNeedsPaint();
            }
          });
    }
  }

  void _initCutIndicatorLayer() {
    _cutIndicatorLayer?.dispose();
    _cutAntsController?.dispose();
    _cutAntsController = null;
    _cutIndicatorLayer = null;

    _cutIndicatorLayer = CutIndicatorLayer(
      layoutSolver: _layoutSolver,
      onNeedsPaint: () => setState(() {}),
    );

    _cutAntsController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1000),
        )..addListener(() {
          final layer = _cutIndicatorLayer;
          if (layer != null && layer.range != null) {
            layer.animationValue = _cutAntsController!.value;
            // Repaint is driven by CustomPaint(repaint: _cutAntsController),
            // so no setState needed here.
          }
        });

    // Restore pending cut state if re-initializing.
    if (_cutRange != null) {
      _cutIndicatorLayer!.range = _cutRange;
      _cutAntsController!.repeat();
    }
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

  /// Records an undo entry for a resize operation at drag end.
  ///
  /// Captures the original size (from [_resizeDragOriginalSize]) and the
  /// current size for all affected indices (the dragged row/column plus
  /// any selected peers that were resized to match).
  void _recordResizeUndo() {
    final um = undoManager;
    if (um == null) return;
    if (_resizeDragOriginalSize == null || _resizeDragIndex == null) return;

    final index = _resizeDragIndex!;
    final originalSize = _resizeDragOriginalSize!;
    final isRow = _resizeDragIsRow;

    // Collect all affected indices (dragged + selected peers).
    final affectedIndices = <int>[index];
    final selection = _controller.selectionController.selectedRange;
    if (selection != null) {
      if (isRow && index >= selection.startRow && index <= selection.endRow) {
        for (var r = selection.startRow; r <= selection.endRow; r++) {
          if (r != index) affectedIndices.add(r);
        }
      } else if (!isRow &&
          index >= selection.startColumn &&
          index <= selection.endColumn) {
        for (var c = selection.startColumn; c <= selection.endColumn; c++) {
          if (c != index) affectedIndices.add(c);
        }
      }
    }

    // Build before/after maps.
    if (isRow) {
      final before = {for (final r in affectedIndices) r: originalSize};
      final after = {
        for (final r in affectedIndices) r: _layoutSolver.getRowHeight(r),
      };
      if (mapEquals(before, after)) return;
      final sel = (selectionController.anchor, selectionController.focus);
      um.push(
        UndoEntry(
          label: 'Resize row',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          rowSizesBefore: before,
          rowSizesAfter: after,
        ),
      );
    } else {
      final before = {for (final c in affectedIndices) c: originalSize};
      final after = {
        for (final c in affectedIndices) c: _layoutSolver.getColumnWidth(c),
      };
      if (mapEquals(before, after)) return;
      final sel = (selectionController.anchor, selectionController.focus);
      um.push(
        UndoEntry(
          label: 'Resize column',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          columnSizesBefore: before,
          columnSizesAfter: after,
        ),
      );
    }
  }

  /// Creates the gesture handler with all callbacks wired.
  WorksheetGestureHandler _createGestureHandler() {
    return WorksheetGestureHandler(
      hitTester: _hitTester,
      selectionController: _controller.selectionController,
      onEditCell: widget.onEditCell,
      onResizeRow: (row, delta) {
        final currentHeight = _layoutSolver.getRowHeight(row);
        // Capture original size on first resize callback for cancel support.
        if (_resizeDragOriginalSize == null) {
          _resizeDragOriginalSize = currentHeight;
          _resizeDragIndex = row;
          _resizeDragIsRow = true;
        }
        final newHeight = (currentHeight + delta).clamp(10.0, 500.0);
        _layoutSolver.setRowHeight(row, newHeight);
        _tileManager.invalidateAll();
        _layoutVersion++;
        widget.onResizeRow?.call(row, newHeight);
        setState(() {});
      },
      onResizeColumn: (column, delta) {
        final currentWidth = _layoutSolver.getColumnWidth(column);
        // Capture original size on first resize callback for cancel support.
        if (_resizeDragOriginalSize == null) {
          _resizeDragOriginalSize = currentWidth;
          _resizeDragIndex = column;
          _resizeDragIsRow = false;
        }
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
              // Estimate the fill range for undo capture.
              // smartFill may expand the range, so use a generous union.
              final destRow = destination.row;
              final destCol = destination.column;
              final preUndoRange = sourceRange.union(
                CellRange(
                  sourceRange.startRow < destRow
                      ? sourceRange.startRow
                      : destRow,
                  sourceRange.startColumn < destCol
                      ? sourceRange.startColumn
                      : destCol,
                  sourceRange.endRow > destRow ? sourceRange.endRow : destRow,
                  sourceRange.endColumn > destCol
                      ? sourceRange.endColumn
                      : destCol,
                ),
              );
              CellRange? filledRange;
              recordUndo('Fill', preUndoRange, () {
                filledRange = widget.data.smartFill(sourceRange, destination);
                if (filledRange != null) {
                  _adjustSmartFillFormulas(sourceRange, filledRange!);
                  _controller.selectionController.selectRange(filledRange!);
                }
              });
              // If smartFill expanded beyond preUndoRange, re-capture the
              // entry with the actual range. For simplicity we accept the
              // pre-estimated range which covers the source+destination.
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
      onMovePreviewUpdate: (widget.readOnly || !widget.enableMove)
          ? null
          : (previewRange) {
              _selectionLayer.movePreviewRange = previewRange;
              setState(() {});
            },
      onMoveComplete: (widget.readOnly || !widget.enableMove)
          ? null
          : (sourceRange, destination) {
              _performMove(sourceRange, destination);
            },
      onMoveCancel: (widget.readOnly || !widget.enableMove)
          ? null
          : () {
              _selectionLayer.movePreviewRange = null;
              setState(() {});
            },
      onAutoFitColumn: widget.readOnly
          ? null
          : (column) {
              _autoFitColumn(column);
            },
      onAutoFitRow: widget.readOnly
          ? null
          : (row) {
              _autoFitRow(row);
            },
      onJumpToEdge: widget.readOnly
          ? null
          : (from, rowDelta, colDelta) {
              _jumpToDataEdge(from, rowDelta, colDelta);
            },
      onSelectAll: () {
        if (widget.editController?.isEditing == true) return;
        _controller.selectionController.selectRange(
          CellRange(0, 0, maxRow - 1, maxColumn - 1),
        );
      },
    );
  }

  /// Adjusts formula references in cells filled by smartFill.
  void _adjustSmartFillFormulas(CellRange sourceRange, CellRange filledRange) {
    final adjuster = widget.formulaReferenceAdjuster;
    if (adjuster == null) return;

    // Determine fill direction and compute the target-only area
    final bool vertical =
        filledRange.startRow != sourceRange.startRow ||
        filledRange.endRow != sourceRange.endRow;

    widget.data.batchUpdate((batch) {
      if (vertical) {
        final sourceHeight = sourceRange.rowCount;
        for (int row = filledRange.startRow; row <= filledRange.endRow; row++) {
          if (row >= sourceRange.startRow && row <= sourceRange.endRow) {
            continue;
          }
          for (
            int col = filledRange.startColumn;
            col <= filledRange.endColumn;
            col++
          ) {
            final coord = CellCoordinate(row, col);
            final value = widget.data.getCell(coord);
            if (value == null || !value.isFormula) continue;
            // Find the cyclic source row
            final offset = row < sourceRange.startRow
                ? sourceRange.endRow - row
                : row - sourceRange.startRow;
            final sourceRow = sourceRange.startRow + (offset % sourceHeight);
            final rowDelta = row - sourceRow;
            final adjusted = adjuster(value.rawValue as String, rowDelta, 0);
            batch.setCell(coord, CellValue.formula(adjusted));
          }
        }
      } else {
        final sourceWidth = sourceRange.columnCount;
        for (
          int col = filledRange.startColumn;
          col <= filledRange.endColumn;
          col++
        ) {
          if (col >= sourceRange.startColumn && col <= sourceRange.endColumn) {
            continue;
          }
          for (
            int row = filledRange.startRow;
            row <= filledRange.endRow;
            row++
          ) {
            final coord = CellCoordinate(row, col);
            final value = widget.data.getCell(coord);
            if (value == null || !value.isFormula) continue;
            final offset = col < sourceRange.startColumn
                ? sourceRange.endColumn - col
                : col - sourceRange.startColumn;
            final sourceCol = sourceRange.startColumn + (offset % sourceWidth);
            final colDelta = col - sourceCol;
            final adjusted = adjuster(value.rawValue as String, 0, colDelta);
            batch.setCell(coord, CellValue.formula(adjusted));
          }
        }
      }
    });
  }

  /// Performs a move operation: copies source cells to destination, clears source.
  void _performMove(CellRange sourceRange, CellCoordinate destination) {
    final destRange = CellRange(
      destination.row,
      destination.column,
      destination.row + sourceRange.endRow - sourceRange.startRow,
      destination.column + sourceRange.endColumn - sourceRange.startColumn,
    );
    final undoRange = sourceRange.union(destRange);
    recordUndo('Move', undoRange, () {
      widget.data.batchUpdate((batch) {
        batch.copyRange(sourceRange, destination);
        batch.clearRange(sourceRange);
      });
      widget.data.moveMerges(sourceRange, destination);
      _controller.selectionController.selectRange(destRange);
    });
    _selectionLayer.movePreviewRange = null;
    _tileManager.invalidateAll();
    _layoutVersion++;
    setState(() {});
  }

  /// Builds a [TextSpan] for auto-fit measurement that matches the renderer's
  /// logic in [TilePainter._renderCellContent].
  ///
  /// Handles cell-level rich text styles (single empty [TextSpan] with a style)
  /// and [CellFormat] (e.g. currency formatting).
  TextSpan _buildMeasurementSpan(
    CellCoordinate coord,
    CellValue value,
    TextStyle baseTextStyle,
  ) {
    // Use formatted text when a format exists (matches tile_painter)
    final format = widget.data.getFormat(coord);
    final String text;
    if (format != null) {
      text = format.formatRich(value).text;
    } else {
      text = value.displayValue;
    }

    final richText = widget.data.getRichText(coord);
    if (richText != null && richText.isNotEmpty) {
      // Cell-level style: single empty TextSpan → merge style into display text
      if (richText.length == 1 &&
          (richText.first.text == null || richText.first.text!.isEmpty)) {
        return TextSpan(
          text: text,
          style: baseTextStyle.merge(richText.first.style),
        );
      }
      // Per-character spans: text is already embedded in children
      return TextSpan(style: baseTextStyle, children: richText);
    }
    return TextSpan(text: text, style: baseTextStyle);
  }

  /// Auto-fits a column to the widest content.
  ///
  /// Uses display-value deduplication and character-length filtering to avoid
  /// O(N) TextPainter allocations. For a 50K-row column with 16 unique
  /// customer names, this reduces measurements from 50K to ~16.
  void _autoFitColumn(int column) {
    final theme = _lastTheme;
    if (theme == null) return;

    final baseTextStyle = TextStyle(
      fontSize: theme.fontSize,
      fontFamily: theme.fontFamily,
      package: WorksheetThemeData.resolveFontPackage(theme.fontFamily),
    );

    // Collect measurement candidates. Plain text is filtered to only the
    // longest strings (by character count) since shorter strings are virtually
    // always narrower in proportional fonts. Rich text with per-character spans
    // is deduped by display value. Cell-level styled cells (single empty
    // TextSpan with a style) are tracked by coord for individual measurement.
    int maxCharLen = 0;
    final plainCandidates = <String>{};
    final richCandidates = <String, List<TextSpan>>{};
    final styledCandidates = <CellCoordinate, CellValue>{};

    final range = CellRange(0, column, widget.rowCount - 1, column);
    for (final entry in widget.data.getCellsInRange(range)) {
      final coord = entry.key;
      final value = entry.value;

      // Use formatted text when a format exists (matches renderer)
      final format = widget.data.getFormat(coord);
      final effectiveText = format != null
          ? format.formatRich(value).text
          : value.displayValue;
      if (effectiveText.isEmpty) continue;

      final richText = widget.data.getRichText(coord);
      if (richText != null && richText.isNotEmpty) {
        if (richText.length == 1 &&
            (richText.first.text == null || richText.first.text!.isEmpty)) {
          // Cell-level style: style affects width, track individually
          styledCandidates[coord] = value;
        } else {
          richCandidates.putIfAbsent(effectiveText, () => richText);
        }
        continue;
      }

      if (effectiveText.length > maxCharLen) {
        maxCharLen = effectiveText.length;
        plainCandidates.clear();
        plainCandidates.add(effectiveText);
      } else if (effectiveText.length == maxCharLen) {
        plainCandidates.add(effectiveText);
      }
    }

    // Measure candidates
    double maxWidth = 0.0;

    // Plain text: measure unique values at max character length
    int measured = 0;
    for (final text in plainCandidates) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: baseTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxWidth) maxWidth = tp.width;
      tp.dispose();
      if (++measured >= 1000) break;
    }

    // Rich text: measure each unique display value (per-character spans)
    for (final entry in richCandidates.entries) {
      final tp = TextPainter(
        text: TextSpan(style: baseTextStyle, children: entry.value),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width > maxWidth) maxWidth = tp.width;
      tp.dispose();
    }

    // Styled candidates: cell-level rich text style merged into display text
    for (final entry in styledCandidates.entries) {
      final span = _buildMeasurementSpan(entry.key, entry.value, baseTextStyle);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();
      if (tp.width > maxWidth) maxWidth = tp.width;
      tp.dispose();
    }

    // Second pass: consider merged cells spanning this column
    final fullColumnRange = CellRange(0, column, widget.rowCount - 1, column);
    for (final region in widget.data.mergedCells.regionsInRange(
      fullColumnRange,
    )) {
      final anchor = region.anchor;
      final cellValue = widget.data.getCell(anchor);
      if (cellValue == null) continue;

      final textSpan = _buildMeasurementSpan(anchor, cellValue, baseTextStyle);
      // Skip if the measurement span has no text content
      final hasText =
          textSpan.text != null && textSpan.text!.isNotEmpty ||
          textSpan.children != null && textSpan.children!.isNotEmpty;
      if (!hasText) continue;

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();
      final totalNeeded = tp.width + 2 * theme.cellPadding;
      tp.dispose();

      // Subtract widths of other columns in the merge
      double otherColumnsWidth = 0.0;
      for (var c = region.range.startColumn; c <= region.range.endColumn; c++) {
        if (c != column) {
          otherColumnsWidth += _layoutSolver.getColumnWidth(c);
        }
      }
      final remainder = (totalNeeded - otherColumnsWidth).clamp(
        0.0,
        double.infinity,
      );
      if (remainder > maxWidth + 2 * theme.cellPadding) {
        maxWidth = remainder - 2 * theme.cellPadding;
      }
    }

    // Add padding and clamp
    final newWidth = (maxWidth + 2 * theme.cellPadding).clamp(20.0, 1000.0);
    final oldWidth = _layoutSolver.getColumnWidth(column);
    _layoutSolver.setColumnWidth(column, newWidth);
    _tileManager.invalidateAll();
    _layoutVersion++;
    widget.onResizeColumn?.call(column, newWidth);

    // Record undo for auto-fit
    final um = undoManager;
    if (um != null && oldWidth != newWidth) {
      final sel = (selectionController.anchor, selectionController.focus);
      um.push(
        UndoEntry(
          label: 'Auto-fit column',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          columnSizesBefore: {column: oldWidth},
          columnSizesAfter: {column: newWidth},
        ),
      );
    }

    setState(() {});
  }

  /// Auto-fits a row to the tallest content.
  void _autoFitRow(int row) {
    final theme = _lastTheme;
    if (theme == null) return;

    final baseTextStyle = TextStyle(
      fontSize: theme.fontSize,
      fontFamily: theme.fontFamily,
      package: WorksheetThemeData.resolveFontPackage(theme.fontFamily),
    );

    double maxHeight = 0.0;
    final range = CellRange(row, 0, row, widget.columnCount - 1);
    for (final entry in widget.data.getCellsInRange(range)) {
      final coord = entry.key;
      final value = entry.value;

      final cellStyle = CellStyle.defaultStyle.merge(
        widget.data.getStyle(coord),
      );
      final wraps = cellStyle.wrapText ?? false;
      final double layoutWidth;
      if (wraps) {
        final colWidth = _layoutSolver.getColumnWidth(coord.column);
        final availWidth = colWidth - 2 * theme.cellPadding;
        layoutWidth = availWidth > 0 ? availWidth : double.infinity;
      } else {
        // Non-wrapping: measure single-line height only.
        layoutWidth = double.infinity;
      }

      final textSpan = _buildMeasurementSpan(coord, value, baseTextStyle);
      // Skip if the measurement span has no text content
      final hasText =
          textSpan.text != null && textSpan.text!.isNotEmpty ||
          textSpan.children != null && textSpan.children!.isNotEmpty;
      if (!hasText) continue;

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout(maxWidth: layoutWidth);
      if (tp.height > maxHeight) {
        maxHeight = tp.height;
      }
      tp.dispose();
    }

    // Second pass: consider merged cells spanning this row
    final fullRowRange = CellRange(row, 0, row, widget.columnCount - 1);
    for (final region in widget.data.mergedCells.regionsInRange(fullRowRange)) {
      final anchor = region.anchor;
      final cellValue = widget.data.getCell(anchor);
      if (cellValue == null) continue;

      final cellStyle = CellStyle.defaultStyle.merge(
        widget.data.getStyle(anchor),
      );
      final wraps = cellStyle.wrapText ?? false;
      final double layoutWidth;
      if (wraps) {
        // Use full merged width (all spanned columns) as layout constraint
        double mergedWidth = 0.0;
        for (
          var c = region.range.startColumn;
          c <= region.range.endColumn;
          c++
        ) {
          mergedWidth += _layoutSolver.getColumnWidth(c);
        }
        final availWidth = mergedWidth - 2 * theme.cellPadding;
        layoutWidth = availWidth > 0 ? availWidth : double.infinity;
      } else {
        layoutWidth = double.infinity;
      }

      final textSpan = _buildMeasurementSpan(anchor, cellValue, baseTextStyle);
      // Skip if the measurement span has no text content
      final hasText =
          textSpan.text != null && textSpan.text!.isNotEmpty ||
          textSpan.children != null && textSpan.children!.isNotEmpty;
      if (!hasText) continue;

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout(maxWidth: layoutWidth);
      final totalNeeded = tp.height + 2 * theme.cellPadding;
      tp.dispose();

      // Subtract heights of other rows in the merge
      double otherRowsHeight = 0.0;
      for (var r = region.range.startRow; r <= region.range.endRow; r++) {
        if (r != row) {
          otherRowsHeight += _layoutSolver.getRowHeight(r);
        }
      }
      final remainder = (totalNeeded - otherRowsHeight).clamp(
        0.0,
        double.infinity,
      );
      if (remainder > maxHeight + 2 * theme.cellPadding) {
        maxHeight = remainder - 2 * theme.cellPadding;
      }
    }

    // Add padding and clamp
    final newHeight = (maxHeight + 2 * theme.cellPadding).clamp(10.0, 500.0);
    final oldHeight = _layoutSolver.getRowHeight(row);
    _layoutSolver.setRowHeight(row, newHeight);
    _tileManager.invalidateAll();
    _layoutVersion++;
    widget.onResizeRow?.call(row, newHeight);

    // Record undo for auto-fit
    final um = undoManager;
    if (um != null && oldHeight != newHeight) {
      final sel = (selectionController.anchor, selectionController.focus);
      um.push(
        UndoEntry(
          label: 'Auto-fit row',
          affectedRange: const CellRange(0, 0, 0, 0),
          cellsBefore: const {},
          mergesBefore: const [],
          selectionBefore: sel,
          cellsAfter: const {},
          mergesAfter: const [],
          selectionAfter: sel,
          rowSizesBefore: {row: oldHeight},
          rowSizesAfter: {row: newHeight},
        ),
      );
    }

    setState(() {});
  }

  /// Jumps to the data edge from [from] in the given direction.
  ///
  /// Matches Ctrl+Arrow behavior:
  /// - If the adjacent cell is non-empty, scan to last non-empty
  /// - If the adjacent cell is empty, scan to next non-empty
  /// - Clamp to worksheet bounds
  void _jumpToDataEdge(CellCoordinate from, int rowDelta, int colDelta) {
    final maxRow = widget.rowCount - 1;
    final maxCol = widget.columnCount - 1;

    var row = from.row + rowDelta;
    var col = from.column + colDelta;

    // Check bounds
    if (row < 0 || row > maxRow || col < 0 || col > maxCol) {
      return; // Can't move in that direction
    }

    final adjacentHasValue = widget.data.hasValue(CellCoordinate(row, col));

    if (adjacentHasValue) {
      // Scan forward to the last non-empty cell
      while (true) {
        final nextRow = row + rowDelta;
        final nextCol = col + colDelta;
        if (nextRow < 0 ||
            nextRow > maxRow ||
            nextCol < 0 ||
            nextCol > maxCol) {
          break;
        }
        if (!widget.data.hasValue(CellCoordinate(nextRow, nextCol))) {
          break;
        }
        row = nextRow;
        col = nextCol;
      }
    } else {
      // Jump to next populated cell using sparse lookup (avoids O(N) cell-by-cell scan)
      if (rowDelta != 0) {
        final nextRow = rowDelta > 0
            ? widget.data.findNextPopulatedRow(col, row)
            : widget.data.findPrevPopulatedRow(col, row);
        if (nextRow != null) {
          row = nextRow;
        } else {
          row = rowDelta > 0 ? maxRow : 0;
        }
      } else if (colDelta != 0) {
        final nextCol = colDelta > 0
            ? widget.data.findNextPopulatedColumn(row, col)
            : widget.data.findPrevPopulatedColumn(row, col);
        if (nextCol != null) {
          col = nextCol;
        } else {
          col = colDelta > 0 ? maxCol : 0;
        }
      }
    }

    final destination = CellCoordinate(row, col);
    _controller.selectionController.selectCell(destination);
    _ensureSelectionVisible();
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

  /// Applies a zoom factor anchored at [anchor] and adjusts scroll to keep
  /// the anchor point stationary (used by both web and native trackpad zoom).
  void _applyTrackpadZoom({required double factor, required Offset anchor}) {
    final adj = _scaleHandler!.zoomBy(
      factor: factor,
      anchor: anchor,
      scrollOffset: Offset(_controller.scrollX, _controller.scrollY),
    );
    if (adj != Offset.zero) {
      final hc = _controller.horizontalScrollController;
      final vc = _controller.verticalScrollController;
      if (hc.hasClients) {
        hc.jumpTo((hc.offset + adj.dx).clamp(0.0, hc.position.maxScrollExtent));
      }
      if (vc.hasClients) {
        vc.jumpTo((vc.offset + adj.dy).clamp(0.0, vc.position.maxScrollExtent));
      }
    }
    setState(() {});
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
    Offset? tapPosition,
  }) {
    final ec = widget.editController;
    if (ec == null) return;

    final currentValue = (widget.rawData ?? widget.data).getCell(cell);
    ec.startEdit(
      cell: cell,
      currentValue: currentValue,
      trigger: trigger,
      initialText: initialText,
      tapPosition: tapPosition,
    );

    // Tell the tile painter to skip rendering text for this cell
    // (the overlay TextField renders it instead) and re-render the tile.
    _tilePainter.editingRange = CellRange(
      cell.row,
      cell.column,
      cell.row,
      cell.column,
    );
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
    _editingVerticalOffset = null;
    _editingContentAreaWidth = null;
    _editingContentAreaHeight = null;
    _cachedEditorOverlay = null;
    // Dismiss autocomplete dropdown when editing ends.
    _autocompleteController?.dismiss();
    // Clear formula reference highlights when editing ends.
    if (_formulaRefLayer != null) {
      _formulaRefLayer!.references = [];
      _formulaRefLayer!.activeIndex = -1;
      _formulaRefLayer!.markNeedsPaint();
    }
    _formulaDragging = false;
    _formulaDragStart = null;
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
      }
      _editingVerticalOffset = null;
      _editingContentAreaWidth = null;
      _editingContentAreaHeight = null;
      return;
    }

    final cell = ec.editingCell;
    if (cell == null) return;

    final theme = _lastTheme;
    if (theme == null) return;

    // Resolve per-cell style the same way tile_painter does
    final cellStyle = CellStyle.defaultStyle.merge(widget.data.getStyle(cell));
    final isWrap = cellStyle.wrapText == true;

    // Derive text style from rich text spans + theme defaults
    final richText = widget.data.getRichText(cell);
    final firstSpanStyle = richText?.firstOrNull?.style;
    final fontFamily = firstSpanStyle?.fontFamily ?? theme.fontFamily;

    // Build TextStyle matching the tile painter's rendering.
    // Always use theme.textColor as the base — per-character colors are
    // carried by rich text spans and must not bleed into the base style.
    final editorTextStyle = TextStyle(
      fontSize: firstSpanStyle?.fontSize ?? theme.fontSize,
      fontFamily: fontFamily,
      color: theme.textColor,
      package: WorksheetThemeData.resolveFontPackage(fontFamily),
    );

    // For wrap-text cells with middle/bottom alignment, compute the
    // fixed vertical offset once (on the first notification after edit
    // start) using the original cell value. This matches the offset
    // that CellEditorOverlay._computeInitialWrapVerticalOffset() pins.
    if (isWrap && _editingVerticalOffset == null) {
      final vAlign =
          cellStyle.verticalAlignment ?? CellVerticalAlignment.middle;
      if (vAlign != CellVerticalAlignment.top) {
        final cellBounds = _layoutSolver.getCellBounds(cell);
        final initialText = ec.originalValue?.displayValue ?? '';
        if (initialText.isNotEmpty) {
          final availWidth = cellBounds.width - 2 * theme.cellPadding;
          final mp = TextPainter(
            text: TextSpan(text: initialText, style: editorTextStyle),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: availWidth > 0 ? availWidth : 0);
          final contentH = mp.height;
          mp.dispose();
          switch (vAlign) {
            case CellVerticalAlignment.middle:
              _editingVerticalOffset = ((cellBounds.height - contentH) / 2)
                  .clamp(0.0, double.infinity);
            case CellVerticalAlignment.bottom:
              _editingVerticalOffset =
                  (cellBounds.height - theme.cellPadding - contentH).clamp(
                    0.0,
                    double.infinity,
                  );
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
      cell.row,
      cell.column,
      expanded.endRow,
      expanded.endColumn,
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
    final headerLeft = theme.showHeaders ? theme.rowHeaderWidth * zoom : 0.0;
    final headerTop = theme.showHeaders ? theme.columnHeaderHeight * zoom : 0.0;
    // Auto-scroll when wrap-text editor bottom extends below the viewport.
    if (isWrap && boundsChanged) {
      final expandedScreenBounds = Rect.fromLTWH(
        expanded.bounds.left * zoom - _controller.scrollX + headerLeft,
        expanded.bounds.top * zoom - _controller.scrollY + headerTop,
        expanded.bounds.width * zoom,
        expanded.bounds.height * zoom,
      );
      final size = context.size;
      if (size != null) {
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final viewportBottom = size.height - keyboardHeight;
        final overflow = expandedScreenBounds.bottom - viewportBottom;
        if (overflow > 0) {
          final vController = _controller.verticalScrollController;
          if (vController.hasClients) {
            final newOffset = (vController.offset + overflow).clamp(
              0.0,
              vController.position.maxScrollExtent,
            );
            vController.jumpTo(newOffset);
          }
        }
      }
    }

    _editingExpandedBounds = expanded.bounds;

    // Cache content area dimensions for the overlay's right-edge clamping
    // and autocomplete dropdown flip-above logic.
    final size = context.size;
    if (size != null) {
      _editingContentAreaWidth =
          size.width - (theme.showHeaders ? theme.rowHeaderWidth * zoom : 0.0);
      _editingContentAreaHeight =
          size.height -
          (theme.showHeaders ? theme.columnHeaderHeight * zoom : 0.0);
    }

    // Update formula reference layer tokens.
    _updateFormulaReferences(ec);

    if (boundsChanged) {
      setState(() {});
    }
  }

  /// Updates the formula reference layer with current formula tokens.
  void _updateFormulaReferences(EditController ec) {
    final layer = _formulaRefLayer;
    if (layer == null) return;

    final frc = widget.formulaReferenceConfig;
    if (frc != null && ec.isFormulaMode(frc)) {
      final tokens = frc.tokenize(ec.currentText);
      layer.references = tokens;
      layer.activeIndex = ec.activeReferenceIndex;

      // Start marching ants if there's an active reference.
      if (ec.activeReferenceIndex >= 0) {
        _marchingAntsController?.repeat();
      } else {
        _marchingAntsController?.stop();
        layer.animationValue = 0;
      }

      layer.markNeedsPaint();
    } else {
      if (layer.references.isNotEmpty) {
        layer.references = [];
        layer.activeIndex = -1;
        _marchingAntsController?.stop();
        layer.markNeedsPaint();
      }
    }
  }

  /// Inserts a single cell reference into the formula being edited.
  void _insertFormulaRef(
    EditController ec,
    FormulaReferenceConfig frc,
    CellCoordinate cell,
  ) {
    final controller = ec.richTextController;
    if (controller == null) return;

    final formula = controller.text;
    final cursorOffset = controller.selection.baseOffset;
    final tokens = frc.tokenize(formula);

    final result = FormulaReferenceInserter.insertCellRef(
      formula: formula,
      cursorOffset: cursorOffset,
      cell: cell,
      tokens: tokens,
      cellToRef: frc.cellToRef,
    );

    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursorOffset),
    );
    ec.updateText(result.text);
  }

  /// Inserts a range reference into the formula being edited.
  void _insertFormulaRangeRef(
    EditController ec,
    FormulaReferenceConfig frc,
    CellCoordinate start,
    CellCoordinate end,
  ) {
    final controller = ec.richTextController;
    if (controller == null) return;

    final formula = controller.text;
    final cursorOffset = controller.selection.baseOffset;
    final tokens = frc.tokenize(formula);

    final result = FormulaReferenceInserter.insertRangeRef(
      formula: formula,
      cursorOffset: cursorOffset,
      start: start,
      end: end,
      tokens: tokens,
      rangeToRef: frc.rangeToRef,
    );

    controller.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.cursorOffset),
    );
    ec.updateText(result.text);
  }

  /// Handles arrow key press in formula mode by inserting a cell reference
  /// for the cell adjacent to the current selection anchor in the arrow
  /// direction.
  void _onFormulaArrowKey(LogicalKeyboardKey key, bool shift) {
    final ec = widget.editController;
    final frc = widget.formulaReferenceConfig;
    if (ec == null || frc == null) return;

    final anchor = _controller.selectionController.anchor;
    if (anchor == null) return;

    int rowDelta = 0;
    int colDelta = 0;
    if (key == LogicalKeyboardKey.arrowUp) rowDelta = -1;
    if (key == LogicalKeyboardKey.arrowDown) rowDelta = 1;
    if (key == LogicalKeyboardKey.arrowLeft) colDelta = -1;
    if (key == LogicalKeyboardKey.arrowRight) colDelta = 1;

    final targetCell = anchor.offset(rowDelta, colDelta);
    _insertFormulaRef(ec, frc, targetCell);
  }

  /// Handles autocomplete acceptance: replaces the current token with
  /// the function name and opening parenthesis, then updates the editor.
  void _onAutocompleteAccept(FormulaFunction fn, AutocompleteToken token) {
    final ec = widget.editController;
    if (ec == null) return;

    final formula = ec.currentText;
    final before = formula.substring(0, token.start);
    final after = formula.substring(token.end);
    final newText = '$before${fn.name}($after';
    final newCursor = token.start + fn.name.length + 1;

    ec.updateText(newText);
    // Notify the rich text controller to update text + cursor.
    ec.richTextController?.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    // Notify consumer if a callback is provided.
    widget.onAutocompleteAccept?.call(fn);
  }

  /// Handles commit from the internal CellEditorOverlay.
  void _onInternalCommit(
    CellCoordinate cell,
    CellValue? value, {
    CellFormat? detectedFormat,
    List<TextSpan>? richText,
  }) {
    _clearEditingCell();
    recordUndo('Edit cell', CellRange.single(cell), () {
      widget.data.batchUpdate((batch) {
        batch.setCell(cell, value);
        if (detectedFormat != null && widget.data.getFormat(cell) == null) {
          batch.setFormat(cell, detectedFormat);
        }
        batch.setRichText(cell, richText);
      });
    });
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
    recordUndo('Edit cell', CellRange.single(cell), () {
      widget.data.batchUpdate((batch) {
        batch.setCell(cell, value);
        if (detectedFormat != null && widget.data.getFormat(cell) == null) {
          batch.setFormat(cell, detectedFormat);
        }
        batch.setRichText(cell, richText);
      });
    });
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

  /// Handles key events that must fire before the Shortcuts widget.
  ///
  /// Placed on the inner Focus widget. Handles:
  /// - Escape during active drag → cancels drag without completing
  /// - Printable characters → type-to-edit
  KeyEventResult _handleKeyBeforeShortcuts(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Escape cancels any active drag operation (fill, move, resize,
    // selection) without completing it, unlike mouse-up which completes.
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _gestureHandler.isDragging) {
      _cancelActiveDrag();
      return KeyEventResult.handled;
    }

    // Type-to-edit: printable characters start editing the focused cell.
    final ec = widget.editController;
    if (ec == null || widget.readOnly || ec.isEditing) {
      return KeyEventResult.ignored;
    }

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

  /// Resets resize tracking fields when a resize drag begins.
  ///
  /// The actual original size is captured lazily on the first
  /// `onResizeRow`/`onResizeColumn` callback, before any delta is applied.
  void _saveResizeOriginalSize() {
    _resizeDragOriginalSize = null;
    _resizeDragIndex = null;
    _resizeDragIsRow = false;
  }

  /// Cancels the active drag operation (Escape key).
  ///
  /// Returns true if a drag was actually cancelled.
  bool _cancelActiveDrag() {
    if (!_gestureHandler.isDragging) return false;

    final wasResizing = _gestureHandler.isResizing;
    final wasMoving = _gestureHandler.isMoving;

    // Restore original column/row size if we were resizing
    if (wasResizing &&
        _resizeDragOriginalSize != null &&
        _resizeDragIndex != null) {
      if (_resizeDragIsRow) {
        _layoutSolver.setRowHeight(_resizeDragIndex!, _resizeDragOriginalSize!);
      } else {
        _layoutSolver.setColumnWidth(
          _resizeDragIndex!,
          _resizeDragOriginalSize!,
        );
      }
      _tileManager.invalidateAll();
      _layoutVersion++;
    }

    // Cancel the drag (restores selection, calls cancel callbacks)
    _gestureHandler.cancelDrag();

    // Clean up widget-level state
    _stopAutoScroll();
    _scrollSuppressor.suppress = false;
    _selectionLayer.fillPreviewRange = null;
    _selectionLayer.movePreviewRange = null;
    _resizeDragOriginalSize = null;
    _resizeDragIndex = null;

    if (wasMoving) {
      _currentCursor = SystemMouseCursors.basic;
    }

    setState(() {});
    return true;
  }

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
        (!_gestureHandler.isSelectingRange &&
            !_gestureHandler.isFilling &&
            !_gestureHandler.isMoving)) {
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
    final isFirst = _pendingDataChanges == null;
    (_pendingDataChanges ??= []).add(event);
    if (isFirst) {
      scheduleMicrotask(_processPendingDataChanges);
    }
  }

  /// Processes all buffered data change events in a single pass.
  ///
  /// Coalesces multiple events that arrive in the same microtask frame
  /// (e.g. individual setCell + setFormat + setRichText calls) into one
  /// invalidation + setState cycle instead of N separate ones.
  void _processPendingDataChanges() {
    final events = _pendingDataChanges;
    _pendingDataChanges = null;
    if (events == null || !_initialized || !mounted) return;

    _cachedEditorOverlay = null;
    var didInvalidateAll = false;

    for (final event in events) {
      if (didInvalidateAll) break;
      switch (event.type) {
        case DataChangeType.cellValue:
        case DataChangeType.cellStyle:
        case DataChangeType.cellFormat:
          if (event.cell != null) {
            final region = widget.data.mergedCells.getRegion(event.cell!);
            final range =
                region?.range ??
                CellRange(
                  event.cell!.row,
                  event.cell!.column,
                  event.cell!.row,
                  event.cell!.column,
                );
            _tileManager.invalidateRange(range);
          }
        case DataChangeType.range:
          if (event.range != null) {
            _tileManager.invalidateRange(_expandRangeForMerges(event.range!));
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
          didInvalidateAll = true;
      }
    }
    _layoutVersion++;
    setState(() {});
  }

  /// Expands a range to include full merge regions that overlap with it.
  CellRange _expandRangeForMerges(CellRange range) {
    var expanded = range;
    for (final region in widget.data.mergedCells.regionsInRange(range)) {
      expanded = expanded.union(region.range);
    }
    return expanded;
  }

  @override
  void didUpdateWidget(Worksheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _controller.detachActionDispatcher();
      _controller.detachLayout();
      if (_ownsController) {
        _controller.removeListener(_onControllerChanged);
        _controller.dispose();
      } else {
        _controller.removeListener(_onControllerChanged);
      }

      _initController();
      if (_initialized) {
        // Re-attach layout and action dispatcher to the new controller
        final theme = WorksheetTheme.of(context);
        _controller.attachLayout(
          _layoutSolver,
          headerWidth: theme.showHeaders ? theme.rowHeaderWidth : 0.0,
          headerHeight: theme.showHeaders ? theme.columnHeaderHeight : 0.0,
        );
        _controller.attachActionDispatcher(
          dispatcher: _dispatchAction,
          enabledChecker: _isActionEnabled,
        );
        _gestureHandler = _createGestureHandler();
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
        _frozenLayer?.dispose();
        _initLayers(theme, devicePixelRatio);
      }
    }

    if (widget.editController != oldWidget.editController) {
      oldWidget.editController?.removeListener(_onEditTextChanged);
      widget.editController?.addListener(_onEditTextChanged);
      _updateEditorOverlayListenable();
    }

    if (widget.controller != oldWidget.controller) {
      _updateEditorOverlayListenable();
    }

    // Recreate autocomplete controller when config changes
    if (widget.formulaAutocompleteConfig !=
        oldWidget.formulaAutocompleteConfig) {
      _autocompleteController?.dispose();
      _autocompleteController = widget.formulaAutocompleteConfig != null
          ? AutocompleteController(config: widget.formulaAutocompleteConfig!)
          : null;
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
      _frozenLayer?.dispose();
      _initRendering(theme, devicePixelRatio);
      _initLayers(theme, devicePixelRatio);
    } else if (widget.freezeConfig != oldWidget.freezeConfig && _initialized) {
      // Freeze config changed without data change — recreate frozen layer
      final theme = WorksheetTheme.of(context);
      final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      _frozenLayer?.dispose();
      _frozenLayer = widget.freezeConfig.hasFrozenPanes
          ? (FrozenLayer(
              freezeConfig: widget.freezeConfig,
              data: widget.data,
              layoutSolver: _layoutSolver,
              onNeedsPaint: () => setState(() {}),
              backgroundColor: theme.cellBackgroundColor,
              gridlineColor: theme.gridlineColor,
              defaultTextColor: theme.textColor,
              defaultFontSize: theme.fontSize,
              defaultFontFamily: theme.fontFamily,
              cellPadding: theme.cellPadding,
              devicePixelRatio: devicePixelRatio,
            )..mergedCells = widget.data.mergedCells)
          : null;
      _hitTester.freezeConfig = widget.freezeConfig;
      _controller.freezeConfig = widget.freezeConfig;
      _scrollSuppressor.freezeConfig = widget.freezeConfig;
      _headerLayer.freezeConfig = widget.freezeConfig;
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
        _frozenLayer?.dispose();
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
      _frozenLayer?.dispose();
      _cutIndicatorLayer?.dispose();
      _cutAntsController?.dispose();
      _cutIndicatorLayer = null;
      _cutAntsController = null;
      _tileManager.dispose();
      _initialized = false;
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _keyboardScrollTimer?.cancel();
    _pendingDataChanges = null;
    _dataSubscription?.cancel();
    widget.editController?.removeListener(_onEditTextChanged);
    _controller.detachActionDispatcher();
    _controller.detachLayout();
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    if (_initialized) {
      _selectionLayer.dispose();
      _headerLayer.dispose();
      _frozenLayer?.dispose();
      _tileManager.dispose();
    }
    _formulaRefLayer?.dispose();
    _marchingAntsController?.dispose();
    _cutIndicatorLayer?.dispose();
    _cutAntsController?.dispose();
    _autocompleteController?.dispose();
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

    // Sync mobile-mode-dependent layer flags so toggling mobileMode
    // at runtime (e.g. via a Switch) takes effect immediately.
    _selectionLayer.showFillHandle = !widget.readOnly && !_isMobileMode;
    _selectionLayer.showSelectionHandles = _isMobileMode;

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
    // Stored in a field so _dispatchAction / _isActionEnabled (used by the
    // controller's invokeAction) always reference the latest merged map.
    _effectiveActions = widget.readOnly
        ? <Type, Action<Intent>>{}
        : <Type, Action<Intent>>{..._defaultActions, ...?widget.actions};

    return Shortcuts(
      shortcuts: effectiveShortcuts,
      child: Actions(
        actions: _effectiveActions,
        child: Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyBeforeShortcuts,
          child: Stack(
            children: [
              Positioned.fill(
                child: MouseRegion(
                  cursor: _currentCursor,
                  onHover: (widget.readOnly || _isMobileMode)
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
                             HitTestType.selectionBorder => widget.enableMove
                                 ? SystemMouseCursors.grab
                                 : SystemMouseCursors.basic,
                            HitTestType.cell => SystemMouseCursors.cell,
                            HitTestType.rowHeader => SystemMouseCursors.click,
                            HitTestType.columnHeader =>
                              SystemMouseCursors.click,
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
                            // Track pointers for pinch-to-zoom
                            if (_isMobileMode &&
                                event.kind == PointerDeviceKind.touch) {
                              _activePointers[event.pointer] =
                                  event.localPosition;
                              if (_activePointers.length == 2) {
                                // Start pinch zoom
                                final points = _activePointers.values.toList();
                                final focal = Offset(
                                  (points[0].dx + points[1].dx) / 2,
                                  (points[0].dy + points[1].dy) / 2,
                                );
                                _pinchStartDistance =
                                    (points[0] - points[1]).distance;
                                _scaleHandler?.onScaleStart(
                                  scale: 1.0,
                                  focalPoint: focal,
                                  scrollOffset: Offset(
                                    _controller.scrollX,
                                    _controller.scrollY,
                                  ),
                                );
                                return; // Don't process selection
                              }
                            }
                            // Only handle primary button (left click) for selection
                            if (event.buttons == kPrimaryButton) {
                              // GestureDetector.onDoubleTapDown fires before
                              // Listener.onPointerDown (child dispatches first).
                              // If a double-tap already handled this event
                              // (e.g. auto-fit), skip tap-down / drag-start —
                              // the layout may have changed and the same
                              // position would now hit-test differently.
                              if (_doubleTapHandledPointerDown) {
                                _doubleTapHandledPointerDown = false;
                                return;
                              }
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
                                  final editBounds =
                                      _selectionRenderer.editingFocusBounds;
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
                                      editBounds.left * zoom -
                                          _controller.scrollX +
                                          hdrLeft,
                                      editBounds.top * zoom -
                                          _controller.scrollY +
                                          hdrTop,
                                      editBounds.width * zoom,
                                      editBounds.height * zoom,
                                    );
                                  } else {
                                    hitRect = _controller.getCellScreenBounds(
                                      editingCell,
                                    );
                                  }
                                  if (hitRect != null &&
                                      hitRect.contains(event.localPosition)) {
                                    return; // tap inside editing area — hand off to TextField
                                  }
                                }

                                // Formula mode: insert cell reference instead
                                // of committing.
                                final frc = widget.formulaReferenceConfig;
                                if (frc != null && ec.isFormulaMode(frc)) {
                                  final hit = _hitTester.hitTest(
                                    position: event.localPosition,
                                    scrollOffset: Offset(
                                      _controller.scrollX,
                                      _controller.scrollY,
                                    ),
                                    zoom: _controller.zoom,
                                    selectionRange: null,
                                  );
                                  if (hit.type == HitTestType.cell &&
                                      hit.cell != null) {
                                    _insertFormulaRef(ec, frc, hit.cell!);
                                    ec.requestEditorFocus();
                                    _formulaDragging = true;
                                    _formulaDragStart = hit.cell;
                                    return;
                                  }
                                }

                                final richText = ec.richTextExtractor?.call();
                                ec.commitEdit(
                                  onCommit:
                                      (
                                        cell,
                                        value, {
                                        CellFormat? detectedFormat,
                                      }) {
                                        _onInternalCommit(
                                          cell,
                                          value,
                                          detectedFormat: detectedFormat,
                                          richText: richText,
                                        );
                                      },
                                );
                              }

                              // In mobile mode, skip cell/selectionBorder
                              // drag-start so one-finger scroll works.
                              // Still handle selection handles, resize handles,
                              // and headers.
                              if (_isMobileMode &&
                                  event.kind == PointerDeviceKind.touch) {
                                final hit = _hitTester.hitTest(
                                  position: event.localPosition,
                                  scrollOffset: Offset(
                                    _controller.scrollX,
                                    _controller.scrollY,
                                  ),
                                  zoom: _controller.zoom,
                                  selectionRange: _controller
                                      .selectionController
                                      .selectedRange,
                                  selectionHandleSize: 12.0,
                                  resizeHandleTolerance: 12.0,
                                  selectionBorderTolerance: 12.0,
                                );
                                // Only start drag for handles and headers
                                if (hit.isSelectionHandle ||
                                    hit.isResizeHandle ||
                                    hit.isHeader) {
                                  // For handle/resize drags, suppress scroll
                                  // so the TwoDimensionalScrollable doesn't
                                  // fight with the drag gesture.
                                  if (hit.isSelectionHandle ||
                                      hit.isResizeHandle) {
                                    _activePointers.remove(event.pointer);
                                    _scrollSuppressor.suppress = true;
                                  }
                                  _gestureHandler.onTapDown(
                                    position: event.localPosition,
                                    scrollOffset: Offset(
                                      _controller.scrollX,
                                      _controller.scrollY,
                                    ),
                                    zoom: _controller.zoom,
                                    selectionHandleSize: 12.0,
                                    resizeHandleTolerance: 12.0,
                                    selectionBorderTolerance: 12.0,
                                  );
                                  _gestureHandler.onDragStart(
                                    position: event.localPosition,
                                    scrollOffset: Offset(
                                      _controller.scrollX,
                                      _controller.scrollY,
                                    ),
                                    zoom: _controller.zoom,
                                    selectionHandleSize: 12.0,
                                    resizeHandleTolerance: 12.0,
                                    selectionBorderTolerance: 12.0,
                                  );
                                  _saveResizeOriginalSize();
                                }
                                // Cell tap/selection is handled via
                                // GestureDetector.onTapUp in mobile mode.
                                return;
                              }

                              _gestureHandler.onTapDown(
                                position: event.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                                isShiftPressed:
                                    HardwareKeyboard.instance.isShiftPressed,
                                selectionHandleSize: _isMobileMode ? 12.0 : 0,
                                resizeHandleTolerance: _isMobileMode
                                    ? 12.0
                                    : 4.0,
                                selectionBorderTolerance: _isMobileMode
                                    ? 12.0
                                    : 4.0,
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
                                isShiftPressed:
                                    HardwareKeyboard.instance.isShiftPressed,
                                selectionHandleSize: _isMobileMode ? 12.0 : 0,
                                resizeHandleTolerance: _isMobileMode
                                    ? 12.0
                                    : 4.0,
                                selectionBorderTolerance: _isMobileMode
                                    ? 12.0
                                    : 4.0,
                              );
                              // Switch to grabbing cursor during move drag.
                              if (_gestureHandler.isMoving) {
                                setState(() {
                                  _currentCursor = SystemMouseCursors.grabbing;
                                });
                              }
                              // Save original size for resize cancel.
                              _saveResizeOriginalSize();
                            }
                          },
                    onPointerMove: widget.readOnly
                        ? null
                        : (event) {
                            // Track pointer positions for pinch-to-zoom
                            if (_isMobileMode &&
                                event.kind == PointerDeviceKind.touch &&
                                _activePointers.containsKey(event.pointer)) {
                              _activePointers[event.pointer] =
                                  event.localPosition;
                              if (_activePointers.length >= 2 &&
                                  _scaleHandler?.isScaling == true) {
                                final points = _activePointers.values.toList();
                                final focal = Offset(
                                  (points[0].dx + points[1].dx) / 2,
                                  (points[0].dy + points[1].dy) / 2,
                                );
                                final distance =
                                    (points[0] - points[1]).distance;
                                final scale = _pinchStartDistance > 0
                                    ? distance / _pinchStartDistance
                                    : 1.0;
                                _scaleHandler!.onScaleUpdate(
                                  scale: scale,
                                  focalPoint: focal,
                                );
                                // Apply scroll adjustment to maintain focal
                                final adj = _scaleHandler!.scrollAdjustment;
                                if (adj != Offset.zero) {
                                  final hc =
                                      _controller.horizontalScrollController;
                                  final vc =
                                      _controller.verticalScrollController;
                                  if (hc.hasClients) {
                                    hc.jumpTo(
                                      (hc.offset + adj.dx).clamp(
                                        0.0,
                                        hc.position.maxScrollExtent,
                                      ),
                                    );
                                  }
                                  if (vc.hasClients) {
                                    vc.jumpTo(
                                      (vc.offset + adj.dy).clamp(
                                        0.0,
                                        vc.position.maxScrollExtent,
                                      ),
                                    );
                                  }
                                }
                                setState(() {});
                                return; // Don't process as drag
                              }
                            }
                            // Formula drag-to-reference
                            if (_formulaDragging &&
                                event.buttons == kPrimaryButton) {
                              final hit = _hitTester.hitTest(
                                position: event.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                                selectionRange: null,
                              );
                              if (hit.type == HitTestType.cell &&
                                  hit.cell != null &&
                                  _formulaDragStart != null) {
                                final ec = widget.editController;
                                final frc = widget.formulaReferenceConfig;
                                if (ec != null && frc != null) {
                                  _insertFormulaRangeRef(
                                    ec,
                                    frc,
                                    _formulaDragStart!,
                                    hit.cell!,
                                  );
                                }
                              }
                              return;
                            }
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
                                  _gestureHandler.isFilling ||
                                  _gestureHandler.isMoving) {
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
                            // End formula drag-to-reference
                            if (_formulaDragging) {
                              _formulaDragging = false;
                              _formulaDragStart = null;
                              return;
                            }
                            // Clean up pointer tracking for pinch-to-zoom
                            if (_isMobileMode) {
                              _activePointers.remove(event.pointer);
                              if (_scaleHandler?.isScaling == true &&
                                  _activePointers.length < 2) {
                                _scaleHandler!.onScaleEnd();
                              }
                            }
                            _stopAutoScroll();
                            _pointerInScrollbarArea = false;
                            final wasMoving = _gestureHandler.isMoving;
                            _gestureHandler.onDragEnd();
                            // Re-enable scroll after handle/resize drag.
                            _scrollSuppressor.suppress = false;
                            // Record undo before clearing resize tracking.
                            _recordResizeUndo();
                            // Clear resize tracking after normal completion.
                            _resizeDragOriginalSize = null;
                            _resizeDragIndex = null;
                            // Restore cursor after move drag ends.
                            if (wasMoving) {
                              setState(() {
                                _currentCursor = SystemMouseCursors.basic;
                              });
                            }
                          },
                    onPointerCancel: _isMobileMode
                        ? (event) {
                            _activePointers.remove(event.pointer);
                            if (_scaleHandler?.isScaling == true &&
                                _activePointers.length < 2) {
                              _scaleHandler!.onScaleEnd();
                            }
                            _scrollSuppressor.suppress = false;
                          }
                        : null,
                    // Web: trackpad/browser pinch-to-zoom fires
                    // PointerScaleEvent (a PointerSignalEvent).
                    onPointerSignal: (event) {
                      if (event is PointerScaleEvent) {
                        _applyTrackpadZoom(
                          factor: event.scale,
                          anchor: event.localPosition,
                        );
                      }
                    },
                    // macOS/Linux: trackpad pinch-to-zoom fires
                    // PointerPanZoom events with a scale field.
                    onPointerPanZoomStart: (event) {
                      _lastTrackpadScale = 1.0;
                    },
                    onPointerPanZoomUpdate: (event) {
                      if (event.scale != _lastTrackpadScale) {
                        final factor = event.scale / _lastTrackpadScale;
                        _lastTrackpadScale = event.scale;
                        _applyTrackpadZoom(
                          factor: factor,
                          anchor: event.localPosition,
                        );
                      }
                    },
                    onPointerPanZoomEnd: (event) {
                      _lastTrackpadScale = 1.0;
                    },
                    child: GestureDetector(
                      // Mobile mode: tap on cell selects it (since
                      // onPointerDown skips cells for touch to allow scroll).
                      onTapUp: (!_isMobileMode || widget.readOnly)
                          ? null
                          : (TapUpDetails details) {
                              final ec = widget.editController;
                              if (ec != null && ec.isEditing) {
                                // If editing, check if tap is inside editing
                                // area — if so, let TextField handle it.
                                final editBounds =
                                    _selectionRenderer.editingFocusBounds;
                                final editingCell = ec.editingCell;
                                if (editingCell != null) {
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
                                      editBounds.left * zoom -
                                          _controller.scrollX +
                                          hdrLeft,
                                      editBounds.top * zoom -
                                          _controller.scrollY +
                                          hdrTop,
                                      editBounds.width * zoom,
                                      editBounds.height * zoom,
                                    );
                                  } else {
                                    hitRect = _controller.getCellScreenBounds(
                                      editingCell,
                                    );
                                  }
                                  if (hitRect != null &&
                                      hitRect.contains(details.localPosition)) {
                                    return;
                                  }
                                }
                                // In formula mode, cell taps insert references
                                // (handled by Listener.onPointerDown) — don't
                                // commit.
                                final frc = widget.formulaReferenceConfig;
                                if (frc != null && ec.isFormulaMode(frc)) {
                                  return;
                                }
                                final richText = ec.richTextExtractor?.call();
                                ec.commitEdit(
                                  onCommit:
                                      (
                                        cell,
                                        value, {
                                        CellFormat? detectedFormat,
                                      }) {
                                        _onInternalCommit(
                                          cell,
                                          value,
                                          detectedFormat: detectedFormat,
                                          richText: richText,
                                        );
                                      },
                                );
                              }
                              final hit = _hitTester.hitTest(
                                position: details.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                                selectionRange: _controller
                                    .selectionController
                                    .selectedRange,
                                selectionHandleSize: 12.0,
                              );
                              if (hit.isCell) {
                                selectionController.selectCell(hit.cell!);
                                widget.onCellTap?.call(hit.cell!);
                              }
                            },
                      // Mobile mode: long-press on selected cell to move.
                      onLongPressStart: (!_isMobileMode || widget.readOnly)
                          ? null
                          : (LongPressStartDetails details) {
                              _gestureHandler.onLongPressStart(
                                position: details.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                              );
                            },
                      onLongPressMoveUpdate: (!_isMobileMode || widget.readOnly)
                          ? null
                          : (LongPressMoveUpdateDetails details) {
                              _gestureHandler.onLongPressMoveUpdate(
                                position: details.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                              );
                            },
                      onLongPressEnd: (!_isMobileMode || widget.readOnly)
                          ? null
                          : (LongPressEndDetails details) {
                              _gestureHandler.onLongPressEnd();
                            },
                      // Use onDoubleTapDown (fires on second pointer-down)
                      // instead of onDoubleTap (fires after second pointer-up)
                      // so that editing starts while iOS is still processing
                      // the touch event, allowing the keyboard to appear.
                      onDoubleTapDown: widget.readOnly
                          ? null
                          // When already editing, don't register a double-tap
                          // handler so the TextField's double-tap (word select)
                          // wins the gesture arena.
                          : (widget.editController?.isEditing == true)
                          ? null
                          : (TapDownDetails details) {
                              // Hit-test BEFORE calling onDoubleTap, because
                              // auto-fit / jump may change the layout — a
                              // re-hit-test afterwards would give a stale
                              // result at the original pointer position.
                              final hit = _hitTester.hitTest(
                                position: details.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                                selectionRange: _controller
                                    .selectionController
                                    .selectedRange,
                                resizeHandleTolerance: _isMobileMode
                                    ? 12.0
                                    : 4.0,
                                selectionBorderTolerance: _isMobileMode
                                    ? 12.0
                                    : 4.0,
                                selectionHandleSize: _isMobileMode ? 12.0 : 0,
                              );

                              // In mobile mode, selection border / handle
                              // double-taps should enter edit mode (not jump
                              // to edge).  The 12px border tolerance can cover
                              // the entire cell area, so treat border/handle
                              // hits the same as cell hits for editing.
                              if (_isMobileMode &&
                                  (hit.isSelectionBorder ||
                                      hit.isSelectionHandle)) {
                                // Resolve the underlying cell and edit it.
                                final cell = hit.cell ?? _controller.focusCell;
                                if (cell != null) {
                                  selectionController.selectCell(cell);
                                  _doubleTapHandledPointerDown = true;
                                  if (widget.onEditCell != null ||
                                      widget.editController != null) {
                                    widget.onEditCell?.call(cell);
                                    if (widget.editController != null) {
                                      if (_lastPointerKind ==
                                          PointerDeviceKind.touch) {
                                        _editorFocusNode.requestFocus();
                                      }
                                      _startIntegratedEdit(
                                        cell: cell,
                                        trigger: EditTrigger.doubleTap,
                                        tapPosition:
                                            details.localPosition -
                                            Offset(
                                              theme.showHeaders
                                                  ? theme.rowHeaderWidth *
                                                        _controller.zoom
                                                  : 0.0,
                                              theme.showHeaders
                                                  ? theme.columnHeaderHeight *
                                                        _controller.zoom
                                                  : 0.0,
                                            ),
                                      );
                                    }
                                  }
                                }
                                return;
                              }

                              // Route double-taps through the gesture handler
                              // for resize handles, selection border, and cells.
                              _gestureHandler.onDoubleTap(
                                position: details.localPosition,
                                scrollOffset: Offset(
                                  _controller.scrollX,
                                  _controller.scrollY,
                                ),
                                zoom: _controller.zoom,
                              );

                              // For non-cell hits, the gesture handler already
                              // handled the action (auto-fit or jump).  Flag
                              // the event so Listener.onPointerDown (which
                              // fires after this) skips its tap-down / drag-
                              // start — the layout has changed and the same
                              // position would hit-test differently now.
                              if (hit.isResizeHandle || hit.isSelectionBorder) {
                                _doubleTapHandledPointerDown = true;
                                return;
                              }

                              // In mobile mode, ensure cell is selected before
                              // entering edit mode (onPointerDown skips cells).
                              if (_isMobileMode && hit.isCell) {
                                selectionController.selectCell(hit.cell!);
                              }

                              // Cell edit handling
                              final cell = _controller.focusCell;
                              if (cell == null) return;
                              if (widget.onEditCell == null &&
                                  widget.editController == null) {
                                return;
                              }
                              // Fire external callback
                              widget.onEditCell?.call(cell);
                              // Also start integrated editing if available
                              if (widget.editController != null) {
                                // Focus the offstage trigger TextField
                                // synchronously within this gesture handler,
                                // but ONLY for touch input. iOS Safari requires
                                // focus() to happen synchronously with a user
                                // gesture for the virtual keyboard to appear.
                                // For mouse input, skip this — the offstage
                                // field would steal the browser's text input
                                // connection from the real editor overlay.
                                if (_lastPointerKind ==
                                    PointerDeviceKind.touch) {
                                  _editorFocusNode.requestFocus();
                                }
                                _startIntegratedEdit(
                                  cell: cell,
                                  trigger: EditTrigger.doubleTap,
                                  tapPosition:
                                      details.localPosition -
                                      Offset(
                                        theme.showHeaders
                                            ? theme.rowHeaderWidth *
                                                  _controller.zoom
                                            : 0.0,
                                        theme.showHeaders
                                            ? theme.columnHeaderHeight *
                                                  _controller.zoom
                                            : 0.0,
                                      ),
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

                          // Formula reference layer (colored borders on
                          // referenced cells, below selection layer).
                          if (_formulaRefLayer != null &&
                              _formulaRefLayer!.references.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _FormulaRefPainter(
                                    layer: _formulaRefLayer!,
                                    scrollOffset: Offset(
                                      _controller.scrollX,
                                      _controller.scrollY,
                                    ),
                                    zoom: _controller.zoom,
                                    headerOffset: Offset(
                                      theme.showHeaders
                                          ? theme.rowHeaderWidth *
                                                _controller.zoom
                                          : 0.0,
                                      theme.showHeaders
                                          ? theme.columnHeaderHeight *
                                                _controller.zoom
                                          : 0.0,
                                    ),
                                    layoutVersion: _layoutVersion,
                                  ),
                                ),
                              ),
                            ),

                          // Cut indicator layer (marching ants on cut range,
                          // between formula refs and selection).
                          if (_cutIndicatorLayer != null && _cutRange != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _CutIndicatorPainter(
                                    layer: _cutIndicatorLayer!,
                                    scrollOffset: Offset(
                                      _controller.scrollX,
                                      _controller.scrollY,
                                    ),
                                    zoom: _controller.zoom,
                                    headerOffset: Offset(
                                      theme.showHeaders
                                          ? theme.rowHeaderWidth *
                                                _controller.zoom
                                          : 0.0,
                                      theme.showHeaders
                                          ? theme.columnHeaderHeight *
                                                _controller.zoom
                                          : 0.0,
                                    ),
                                    layoutVersion: _layoutVersion,
                                    repaint: _cutAntsController,
                                  ),
                                ),
                              ),
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

                          // Frozen panes layer (on top of selection, below headers)
                          if (_frozenLayer != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _FrozenLayerPainter(
                                    layer: _frozenLayer!,
                                    scrollOffset: Offset(
                                      _controller.scrollX / _controller.zoom,
                                      _controller.scrollY / _controller.zoom,
                                    ),
                                    zoom: _controller.zoom,
                                    headerOffset: Offset(
                                      theme.showHeaders
                                          ? theme.rowHeaderWidth *
                                                _controller.zoom
                                          : 0.0,
                                      theme.showHeaders
                                          ? theme.columnHeaderHeight *
                                                _controller.zoom
                                          : 0.0,
                                    ),
                                    layoutVersion: _layoutVersion,
                                  ),
                                ),
                              ),
                            ),

                          // Selection on frozen cells (on top of frozen layer)
                          if (_frozenLayer != null && _controller.hasSelection)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _FrozenSelectionPainter(
                                    renderer: _selectionRenderer,
                                    selectionController:
                                        _controller.selectionController,
                                    frozenLayer: _frozenLayer!,
                                    scrollOffset: Offset(
                                      _controller.scrollX / _controller.zoom,
                                      _controller.scrollY / _controller.zoom,
                                    ),
                                    zoom: _controller.zoom,
                                    headerOffset: Offset(
                                      theme.showHeaders
                                          ? theme.rowHeaderWidth *
                                                _controller.zoom
                                          : 0.0,
                                      theme.showHeaders
                                          ? theme.columnHeaderHeight *
                                                _controller.zoom
                                          : 0.0,
                                    ),
                                    layoutVersion: _layoutVersion,
                                    showFillHandle:
                                        !widget.readOnly && !_isMobileMode,
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
                        listenable: _editorOverlayListenable!,
                        builder: (context, _) {
                          final headerLeft = theme.showHeaders
                              ? theme.rowHeaderWidth * _controller.zoom
                              : 0.0;
                          final headerTop = theme.showHeaders
                              ? theme.columnHeaderHeight * _controller.zoom
                              : 0.0;
                          if (!widget.editController!.isEditing) {
                            _cachedEditorOverlay = null;
                            return const Positioned(
                              left: 0,
                              top: 0,
                              child: SizedBox.shrink(),
                            );
                          }
                          final cell = widget.editController!.editingCell;
                          if (cell == null) {
                            _cachedEditorOverlay = null;
                            return const Positioned(
                              left: 0,
                              top: 0,
                              child: SizedBox.shrink(),
                            );
                          }
                          final bounds = _controller.getCellScreenBounds(cell);
                          if (bounds == null) {
                            _cachedEditorOverlay = null;
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
                          // Compute expanded screen bounds fresh from
                          // worksheet-coord _editingExpandedBounds so
                          // the overlay tracks the cell during scroll.
                          Rect? adjustedExpandedBounds;
                          if (_editingExpandedBounds != null) {
                            adjustedExpandedBounds = Rect.fromLTWH(
                              _editingExpandedBounds!.left * _controller.zoom -
                                  _controller.scrollX,
                              _editingExpandedBounds!.top * _controller.zoom -
                                  _controller.scrollY,
                              _editingExpandedBounds!.width * _controller.zoom,
                              _editingExpandedBounds!.height * _controller.zoom,
                            );
                          }
                          final currentZoom = _controller.zoom;
                          final contentAreaWidth = _editingContentAreaWidth;

                          // Return the cached widget when layout-relevant props
                          // haven't changed. Returning the identical instance
                          // prevents StatefulElement.update from force-rebuilding
                          // the overlay on every keystroke, which would recreate
                          // the gesture detector and interfere with the
                          // EditableText's text input connection.
                          if (_cachedEditorOverlay != null &&
                              _cachedEditorCell == cell &&
                              _cachedEditorCellBounds == adjustedBounds &&
                              _cachedEditorExpandedBounds ==
                                  adjustedExpandedBounds &&
                              _cachedEditorZoom == currentZoom &&
                              _cachedEditorContentAreaWidth ==
                                  contentAreaWidth) {
                            return _cachedEditorOverlay!;
                          }

                          // Resolve per-cell style the same way tile_painter does
                          final cellStyle = CellStyle.defaultStyle.merge(
                            widget.data.getStyle(cell),
                          );
                          final isWrap = cellStyle.wrapText == true;

                          // Extract effective style from rich text spans for the editor
                          final richText = widget.data.getRichText(cell);
                          final firstSpanStyle = richText?.firstOrNull?.style;

                          _cachedEditorCell = cell;
                          _cachedEditorCellBounds = adjustedBounds;
                          _cachedEditorExpandedBounds = adjustedExpandedBounds;
                          _cachedEditorZoom = currentZoom;
                          _cachedEditorContentAreaWidth = contentAreaWidth;
                          _cachedEditorOverlay = CellEditorOverlay(
                            editController: widget.editController!,
                            cellBounds: adjustedBounds,
                            expandedBounds: adjustedExpandedBounds,
                            onCommit: _onInternalCommit,
                            onCancel: _onInternalCancel,
                            onCommitAndNavigate: _onInternalCommitAndNavigate,
                            zoom: currentZoom,
                            fontSize:
                                firstSpanStyle?.fontSize ?? theme.fontSize,
                            fontFamily:
                                firstSpanStyle?.fontFamily ?? theme.fontFamily,
                            textColor: theme.textColor,
                            backgroundColor: cellStyle.backgroundColor,
                            textAlign: _toTextAlign(
                              cellStyle.textAlignment ??
                                  (widget.data.getCell(cell) != null
                                      ? CellStyle.implicitAlignment(
                                          widget.data.getCell(cell)!.type,
                                        )
                                      : null),
                            ),
                            cellPadding: theme.cellPadding,
                            richText: richText,
                            verticalAlignment:
                                cellStyle.verticalAlignment ??
                                CellVerticalAlignment.middle,
                            wrapText: isWrap,
                            restoreFocusTo: _keyboardFocusNode,
                            contentAreaWidth: contentAreaWidth,
                            formulaReferenceConfig:
                                widget.formulaReferenceConfig,
                            onFormulaArrowKey:
                                widget.formulaReferenceConfig != null
                                ? _onFormulaArrowKey
                                : null,
                            autocompleteController: _autocompleteController,
                            onAutocompleteAccept:
                                _autocompleteController != null
                                ? _onAutocompleteAccept
                                : null,
                          );
                          return _cachedEditorOverlay!;
                        },
                      ),
                      // Autocomplete dropdown positioned below the editing cell.
                      if (_autocompleteController != null)
                        ListenableBuilder(
                          listenable: _autocompleteController!,
                          builder: (context, _) {
                            final ac = _autocompleteController!;
                            if (!ac.isVisible ||
                                !widget.editController!.isEditing) {
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

                            final bounds = _controller.getCellScreenBounds(
                              cell,
                            );
                            if (bounds == null) {
                              return const Positioned(
                                left: 0,
                                top: 0,
                                child: SizedBox.shrink(),
                              );
                            }

                            final headerLeft = theme.showHeaders
                                ? theme.rowHeaderWidth * _controller.zoom
                                : 0.0;
                            final headerTop = theme.showHeaders
                                ? theme.columnHeaderHeight * _controller.zoom
                                : 0.0;

                            final adjustedBounds = bounds.shift(
                              Offset(-headerLeft, -headerTop),
                            );

                            // Use cached content area height from
                            // _onEditTextChanged for flip-above logic.
                            final stackHeight =
                                _editingContentAreaHeight ?? double.infinity;
                            final dropdownHeight =
                                (ac.matches.length < ac.config.maxVisibleItems
                                    ? ac.matches.length
                                    : ac.config.maxVisibleItems) *
                                AutocompleteDropdown.itemHeight;
                            final spaceBelow =
                                stackHeight - adjustedBounds.bottom;
                            final flipAbove = spaceBelow < dropdownHeight + 4;

                            final top = flipAbove
                                ? null
                                : adjustedBounds.bottom + 2;
                            final bottom = flipAbove
                                ? stackHeight - adjustedBounds.top + 2
                                : null;

                            return Positioned(
                              left: adjustedBounds.left,
                              top: top,
                              bottom: bottom,
                              child: AutocompleteDropdown(
                                matches: ac.matches,
                                selectedIndex: ac.selectedIndex,
                                prefix: ac.currentToken?.text ?? '',
                                maxVisibleItems: ac.config.maxVisibleItems,
                                onSelect: (fn) {
                                  final result = ac.accept();
                                  if (result != null) {
                                    _onAutocompleteAccept(
                                      result.function,
                                      result.token,
                                    );
                                  }
                                },
                              ),
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
        physics: _scrollPhysics,
      ),
      verticalDetails: ScrollableDetails.vertical(
        controller: _controller.verticalScrollController,
        physics: _scrollPhysics,
      ),
      viewportBuilder: (context, verticalPosition, horizontalPosition) {
        return WorksheetViewport(
          horizontalPosition: horizontalPosition,
          verticalPosition: verticalPosition,
          tileManager: _tileManager,
          layoutSolver: _layoutSolver,
          zoom: _controller.zoom,
          devicePixelRatio: MediaQuery.of(context).devicePixelRatio,
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

/// Custom painter for formula reference layer.
class _FormulaRefPainter extends CustomPainter {
  final FormulaReferenceLayer layer;
  final Offset scrollOffset;
  final double zoom;
  final Offset headerOffset;
  final int layoutVersion;

  _FormulaRefPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
    required this.headerOffset,
    required this.layoutVersion,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_FormulaRefPainter oldDelegate) {
    return layer != oldDelegate.layer ||
        scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        headerOffset != oldDelegate.headerOffset ||
        layoutVersion != oldDelegate.layoutVersion;
  }
}

/// Custom painter for cut indicator (marching ants) layer.
///
/// Uses [repaint] (an [AnimationController]) so the marching ants animate
/// without needing a full widget rebuild per frame.
class _CutIndicatorPainter extends CustomPainter {
  final CutIndicatorLayer layer;
  final Offset scrollOffset;
  final double zoom;
  final Offset headerOffset;
  final int layoutVersion;

  _CutIndicatorPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
    required this.headerOffset,
    required this.layoutVersion,
    super.repaint,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(_CutIndicatorPainter oldDelegate) {
    return layer != oldDelegate.layer ||
        scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        headerOffset != oldDelegate.headerOffset ||
        layoutVersion != oldDelegate.layoutVersion;
  }
}

/// Custom painter for selection layer.
class _SelectionPainter extends CustomPainter {
  final SelectionLayer layer;
  final Offset scrollOffset;
  final double zoom;
  final Offset headerOffset;
  final int layoutVersion;
  final CellRange? fillPreviewRange;
  final CellRange? movePreviewRange;

  _SelectionPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
    required this.headerOffset,
    required this.layoutVersion,
  }) : fillPreviewRange = layer.fillPreviewRange,
       movePreviewRange = layer.movePreviewRange,
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
        fillPreviewRange != oldDelegate.fillPreviewRange ||
        movePreviewRange != oldDelegate.movePreviewRange;
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

/// Custom painter for frozen panes layer.
class _FrozenLayerPainter extends CustomPainter {
  final FrozenLayer layer;
  final Offset scrollOffset;
  final double zoom;
  final Offset headerOffset;
  final int layoutVersion;

  _FrozenLayerPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
    required this.headerOffset,
    required this.layoutVersion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final contentW = size.width - headerOffset.dx;
    final contentH = size.height - headerOffset.dy;

    canvas.save();
    canvas.translate(headerOffset.dx, headerOffset.dy);
    canvas.clipRect(Rect.fromLTWH(0, 0, contentW, contentH));

    layer.paint(
      LayerPaintContext(
        canvas: canvas,
        viewportSize: Size(contentW, contentH),
        scrollOffset: scrollOffset,
        zoom: zoom,
      ),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FrozenLayerPainter oldDelegate) {
    return layer != oldDelegate.layer ||
        scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        headerOffset != oldDelegate.headerOffset ||
        layoutVersion != oldDelegate.layoutVersion;
  }
}

/// Paints selection indicators on top of the frozen layer.
///
/// The frozen layer covers the normal selection layer, so this painter
/// re-renders selection in the 3 frozen regions (corner, frozen rows,
/// frozen columns) with adjusted scroll offsets so the selection appears
/// at the correct fixed position.
class _FrozenSelectionPainter extends CustomPainter {
  final SelectionRenderer renderer;
  final SelectionController selectionController;
  final FrozenLayer frozenLayer;
  final Offset scrollOffset; // worksheet coordinates
  final double zoom;
  final Offset headerOffset;
  final int layoutVersion;
  final bool showFillHandle;

  _FrozenSelectionPainter({
    required this.renderer,
    required this.selectionController,
    required this.frozenLayer,
    required this.scrollOffset,
    required this.zoom,
    required this.headerOffset,
    required this.layoutVersion,
    required this.showFillHandle,
  }) : super(repaint: selectionController);

  @override
  void paint(Canvas canvas, Size size) {
    final range = selectionController.selectedRange;
    if (range == null) return;

    final freezeConfig = frozenLayer.freezeConfig;
    if (!freezeConfig.hasFrozenPanes) return;

    final contentW = size.width - headerOffset.dx;
    final contentH = size.height - headerOffset.dy;
    final frozenColsW = frozenLayer.frozenColumnsWidth * zoom;
    final frozenRowsH = frozenLayer.frozenRowsHeight * zoom;

    canvas.save();
    canvas.translate(headerOffset.dx, headerOffset.dy);

    // Corner region: no scroll on either axis
    if (freezeConfig.hasFrozenRows && freezeConfig.hasFrozenColumns) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, frozenColsW, frozenRowsH));
      _paintSelection(canvas, Offset.zero);
      canvas.restore();
    }

    // Frozen rows strip: scrollX applied, no scrollY
    if (freezeConfig.hasFrozenRows) {
      final left = freezeConfig.hasFrozenColumns ? frozenColsW : 0.0;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(left, 0, contentW - left, frozenRowsH));
      _paintSelection(canvas, Offset(scrollOffset.dx, 0));
      canvas.restore();
    }

    // Frozen columns strip: no scrollX, scrollY applied
    if (freezeConfig.hasFrozenColumns) {
      final top = freezeConfig.hasFrozenRows ? frozenRowsH : 0.0;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, top, frozenColsW, contentH - top));
      _paintSelection(canvas, Offset(0, scrollOffset.dy));
      canvas.restore();
    }

    canvas.restore();
  }

  void _paintSelection(Canvas canvas, Offset viewportOffset) {
    final range = selectionController.selectedRange!;
    final anchor = selectionController.anchor;

    if (range.cellCount == 1 && anchor != null) {
      renderer.paintSingleCell(
        canvas: canvas,
        viewportOffset: viewportOffset,
        zoom: zoom,
        cell: anchor,
      );
    } else {
      renderer.paintSelection(
        canvas: canvas,
        viewportOffset: viewportOffset,
        zoom: zoom,
        range: range,
        anchorCell: anchor,
      );
    }

    if (showFillHandle) {
      renderer.paintFillHandle(
        canvas: canvas,
        viewportOffset: viewportOffset,
        zoom: zoom,
        range: range,
      );
    }
  }

  @override
  bool shouldRepaint(_FrozenSelectionPainter oldDelegate) {
    return renderer != oldDelegate.renderer ||
        selectionController != oldDelegate.selectionController ||
        frozenLayer != oldDelegate.frozenLayer ||
        scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        headerOffset != oldDelegate.headerOffset ||
        layoutVersion != oldDelegate.layoutVersion ||
        showFillHandle != oldDelegate.showFillHandle;
  }
}

/// Mutable flags shared between the widget state and
/// [SuppressibleBouncingPhysics].
///
/// When [suppress] is `true`, the physics returns zero user-offset and no
/// ballistic simulation, effectively freezing scroll position for user
/// gestures while still allowing programmatic [ScrollController.jumpTo].
///
/// When [freezeConfig] has frozen panes, overscroll at the min extent is
/// prevented on the frozen axis so that frozen rows/columns stay flush
/// with the non-frozen content (no elastic gap at the frozen boundary).
class ScrollSuppressor {
  /// Whether to suppress user-initiated scrolling.
  bool suppress = false;

  /// Current freeze configuration. When frozen panes exist, overscroll at
  /// the start (min extent) is clamped on the corresponding axis.
  FreezeConfig freezeConfig = FreezeConfig.none;
}

/// [BouncingScrollPhysics] variant that can be temporarily suppressed via a
/// shared [ScrollSuppressor].
///
/// This is used during selection-handle and resize-handle touch drags to
/// prevent the [TwoDimensionalScrollable] from scrolling in response to the
/// same pointer, while still allowing auto-scroll via [ScrollController.jumpTo].
///
/// When frozen panes are active, overscroll at the min extent (start) is
/// prevented on the frozen axis so frozen rows/columns stay anchored.
class SuppressibleBouncingPhysics extends BouncingScrollPhysics {
  /// Creates physics that delegates to [BouncingScrollPhysics] unless
  /// [suppressor.suppress] is `true`.
  // ignore: prefer_const_constructors_in_immutables — suppressor is mutable
  SuppressibleBouncingPhysics({required this.suppressor, super.parent});

  /// Shared flag that controls whether scrolling is suppressed.
  final ScrollSuppressor suppressor;

  @override
  SuppressibleBouncingPhysics applyTo(ScrollPhysics? ancestor) {
    return SuppressibleBouncingPhysics(
      suppressor: suppressor,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // When frozen panes exist, prevent overscroll at the start (min extent)
    // on the frozen axis. This keeps frozen rows/columns flush with non-
    // frozen content — no elastic gap at the frozen boundary.
    final freeze = suppressor.freezeConfig;
    if (freeze.hasFrozenPanes) {
      final hasFreezeOnAxis = position.axis == Axis.vertical
          ? freeze.hasFrozenRows
          : freeze.hasFrozenColumns;
      if (hasFreezeOnAxis && value < position.minScrollExtent) {
        return value - position.minScrollExtent;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (suppressor.suppress) return 0.0;
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (suppressor.suppress) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}
