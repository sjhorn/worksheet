import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/data/data_change_event.dart';
import '../core/data/worksheet_data.dart';
import '../core/geometry/layout_solver.dart';
import '../core/geometry/span_list.dart';
import '../core/models/cell_coordinate.dart';
import '../core/models/cell_range.dart';
import '../interaction/clipboard/clipboard_handler.dart';
import '../interaction/clipboard/clipboard_serializer.dart';
import '../interaction/gesture_handler.dart';
import '../interaction/gestures/keyboard_handler.dart';
import '../interaction/hit_testing/hit_test_result.dart';
import '../interaction/hit_testing/hit_tester.dart';
import '../rendering/layers/header_layer.dart';
import '../rendering/layers/render_layer.dart';
import '../rendering/layers/selection_layer.dart';
import '../rendering/painters/header_renderer.dart';
import '../rendering/painters/selection_renderer.dart';
import '../rendering/tile/tile_config.dart';
import '../rendering/tile/tile_manager.dart';
import '../rendering/tile/tile_painter.dart';
import '../scrolling/worksheet_viewport.dart';
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

  /// The clipboard serializer for copy/cut/paste operations.
  ///
  /// Defaults to [TsvClipboardSerializer], which uses tab-separated values
  /// compatible with Excel and Google Sheets.
  final ClipboardSerializer clipboardSerializer;

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

  const Worksheet({
    super.key,
    required this.data,
    this.controller,
    this.rowCount = 1000,
    this.columnCount = 26,
    this.onEditCell,
    this.onCellTap,
    this.onResizeRow,
    this.onResizeColumn,
    this.customRowHeights,
    this.customColumnWidths,
    this.readOnly = false,
    this.clipboardSerializer = const TsvClipboardSerializer(),
    this.diagonalDragBehavior = DiagonalDragBehavior.free,
    this.scrollbarConfig,
  });

  @override
  State<Worksheet> createState() => _WorksheetState();
}

class _WorksheetState extends State<Worksheet> {
  late WorksheetController _controller;
  bool _ownsController = false;

  late LayoutSolver _layoutSolver;
  late TileManager _tileManager;
  late TilePainter _tilePainter;
  late WorksheetHitTester _hitTester;
  late WorksheetGestureHandler _gestureHandler;
  late KeyboardHandler _keyboardHandler;
  late ClipboardHandler _clipboardHandler;

  late SelectionRenderer _selectionRenderer;
  late HeaderRenderer _headerRenderer;
  late SelectionLayer _selectionLayer;
  late HeaderLayer _headerLayer;

  bool _initialized = false;
  MouseCursor _currentCursor = SystemMouseCursors.basic;
  int _layoutVersion = 0;
  bool _pointerInScrollbarArea = false;

  // Data change subscription for external mutations
  StreamSubscription<DataChangeEvent>? _dataSubscription;

  // Auto-scroll during drag selection
  Timer? _autoScrollTimer;
  Offset? _lastPointerPosition;
  static const Duration _autoScrollInterval = Duration(milliseconds: 16);

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
    );

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

  void _initRendering(WorksheetThemeData theme) {
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
    );

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
      serializer: widget.clipboardSerializer,
    );

    // Subscribe to data change events for external mutations
    _dataSubscription?.cancel();
    _dataSubscription = widget.data.changes.listen(_onDataChanged);

    _keyboardHandler = KeyboardHandler(
      selectionController: _controller.selectionController,
      maxRow: widget.rowCount,
      maxColumn: widget.columnCount,
      onStartEdit: () {
        final cell = _controller.focusCell;
        if (cell != null) {
          widget.onEditCell?.call(cell);
        }
      },
      onEnsureVisible: _ensureSelectionVisible,
      onCopy: () => _clipboardHandler.copy(),
      onCut: widget.readOnly
          ? null
          : () async {
              await _clipboardHandler.cut();
              _tileManager.invalidateAll();
              _layoutVersion++;
              if (mounted) setState(() {});
            },
      onPaste: widget.readOnly
          ? null
          : () async {
              await _clipboardHandler.paste();
              _tileManager.invalidateAll();
              _layoutVersion++;
              if (mounted) setState(() {});
            },
      onDelete: widget.readOnly
          ? null
          : () {
              final range = _controller.selectionController.selectedRange;
              if (range == null) return;
              widget.data.clearRange(range);
              _tileManager.invalidateAll();
              _layoutVersion++;
              setState(() {});
            },
      onFillDown: widget.readOnly
          ? null
          : () {
              final range = _controller.selectionController.selectedRange;
              if (range == null || range.rowCount < 2) return;
              for (int col = range.startColumn; col <= range.endColumn; col++) {
                widget.data.fillRange(
                  CellCoordinate(range.startRow, col),
                  CellRange(range.startRow + 1, col, range.endRow, col),
                );
              }
              _tileManager.invalidateAll();
              _layoutVersion++;
              setState(() {});
            },
      onFillRight: widget.readOnly
          ? null
          : () {
              final range = _controller.selectionController.selectedRange;
              if (range == null || range.columnCount < 2) return;
              for (int row = range.startRow; row <= range.endRow; row++) {
                widget.data.fillRange(
                  CellCoordinate(row, range.startColumn),
                  CellRange(row, range.startColumn + 1, row, range.endColumn),
                );
              }
              _tileManager.invalidateAll();
              _layoutVersion++;
              setState(() {});
            },
    );
  }

  void _initLayers(WorksheetThemeData theme) {
    _selectionRenderer = SelectionRenderer(
      layoutSolver: _layoutSolver,
      style: theme.selectionStyle,
    );

    _headerRenderer = HeaderRenderer(
      layoutSolver: _layoutSolver,
      style: theme.headerStyle,
      rowHeaderWidth: theme.rowHeaderWidth,
      columnHeaderHeight: theme.columnHeaderHeight,
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

  void _ensureInitialized(WorksheetThemeData theme) {
    if (!_initialized) {
      _initLayout(theme);
      _initRendering(theme);
      _initLayers(theme);
      _initialized = true;
    }
  }

  /// Applies the resized row's height to all selected rows.
  void _applyResizeToSelectedRows(int resizedRow) {
    final selection = _controller.selectionController.selectedRange;
    if (selection == null) return;

    // Check if the resized row is within the selection
    if (resizedRow < selection.startRow || resizedRow > selection.endRow)
      return;

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
        resizedColumn > selection.endColumn)
      return;

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
  void _ensureSelectionVisible() {
    final cell = _controller.selectionController.focus;
    if (cell == null) return;

    final size = context.size;
    if (size == null) return;

    _controller.ensureCellVisible(cell, viewportSize: size);
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
          _tileManager.invalidateRange(CellRange(
            event.cell!.row,
            event.cell!.column,
            event.cell!.row,
            event.cell!.column,
          ));
        }
      case DataChangeType.range:
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
          serializer: widget.clipboardSerializer,
        );
        _keyboardHandler = KeyboardHandler(
          selectionController: _controller.selectionController,
          maxRow: widget.rowCount,
          maxColumn: widget.columnCount,
          onStartEdit: () {
            final cell = _controller.focusCell;
            if (cell != null) {
              widget.onEditCell?.call(cell);
            }
          },
          onEnsureVisible: _ensureSelectionVisible,
          onCopy: () => _clipboardHandler.copy(),
          onCut: widget.readOnly
              ? null
              : () async {
                  await _clipboardHandler.cut();
                  _tileManager.invalidateAll();
                  _layoutVersion++;
                  if (mounted) setState(() {});
                },
          onPaste: widget.readOnly
              ? null
              : () async {
                  await _clipboardHandler.paste();
                  _tileManager.invalidateAll();
                  _layoutVersion++;
                  if (mounted) setState(() {});
                },
          onDelete: widget.readOnly
              ? null
              : () {
                  final range = _controller.selectionController.selectedRange;
                  if (range == null) return;
                  widget.data.clearRange(range);
                  _tileManager.invalidateAll();
                  _layoutVersion++;
                  setState(() {});
                },
          onFillDown: widget.readOnly
              ? null
              : () {
                  final range = _controller.selectionController.selectedRange;
                  if (range == null || range.rowCount < 2) return;
                  for (
                    int col = range.startColumn;
                    col <= range.endColumn;
                    col++
                  ) {
                    widget.data.fillRange(
                      CellCoordinate(range.startRow, col),
                      CellRange(range.startRow + 1, col, range.endRow, col),
                    );
                  }
                  _tileManager.invalidateAll();
                  _layoutVersion++;
                  setState(() {});
                },
          onFillRight: widget.readOnly
              ? null
              : () {
                  final range = _controller.selectionController.selectedRange;
                  if (range == null || range.columnCount < 2) return;
                  for (int row = range.startRow; row <= range.endRow; row++) {
                    widget.data.fillRange(
                      CellCoordinate(row, range.startColumn),
                      CellRange(
                        row,
                        range.startColumn + 1,
                        row,
                        range.endColumn,
                      ),
                    );
                  }
                  _tileManager.invalidateAll();
                  _layoutVersion++;
                  setState(() {});
                },
        );
        _selectionLayer.dispose();
        _headerLayer.dispose();
        _initLayers(theme);
      }
    }

    if (widget.data != oldWidget.data && _initialized) {
      _dataSubscription?.cancel();
      final theme = WorksheetTheme.of(context);
      _tileManager.dispose();
      _selectionLayer.dispose();
      _headerLayer.dispose();
      _initRendering(theme);
      _initLayers(theme);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = WorksheetTheme.of(context);
    _ensureInitialized(theme);
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
    _dataSubscription?.cancel();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = WorksheetTheme.of(context);
    _ensureInitialized(theme);

    // Use Listener for low-level pointer events to handle:
    // - Left mouse button: tap and drag for selection
    // - Scroll wheel: handled by TwoDimensionalScrollable
    return Focus(
      autofocus: true,
      onKeyEvent: widget.readOnly
          ? null
          : (node, event) {
              if (_keyboardHandler.handleKeyEvent(event)) {
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
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
                  selectionRange: _controller.selectionController.selectedRange,
                );
                final newCursor = switch (hit.type) {
                  HitTestType.rowResizeHandle => SystemMouseCursors.resizeRow,
                  HitTestType.columnResizeHandle =>
                    SystemMouseCursors.resizeColumn,
                  HitTestType.fillHandle => SystemMouseCursors.precise,
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
                  // Only handle primary button (left click) for selection
                  if (event.buttons == kPrimaryButton) {
                    // Skip selection when pointer is on a scrollbar
                    if (_isInScrollbarArea(event.localPosition, theme)) {
                      _pointerInScrollbarArea = true;
                      return;
                    }
                    _pointerInScrollbarArea = false;
                    _gestureHandler.onTapDown(
                      position: event.localPosition,
                      scrollOffset: Offset(
                        _controller.scrollX,
                        _controller.scrollY,
                      ),
                      zoom: _controller.zoom,
                    );
                    widget.onCellTap?.call(
                      _controller.focusCell ?? const CellCoordinate(0, 0),
                    );
                    _gestureHandler.onDragStart(
                      position: event.localPosition,
                      scrollOffset: Offset(
                        _controller.scrollX,
                        _controller.scrollY,
                      ),
                      zoom: _controller.zoom,
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
            onDoubleTap: widget.readOnly || widget.onEditCell == null
                ? null
                : () {
                    // Use last tap position for double-tap edit
                    if (_controller.focusCell != null) {
                      widget.onEditCell?.call(_controller.focusCell!);
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
                            theme.columnHeaderHeight * _controller.zoom,
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
    return scrollOffset != oldDelegate.scrollOffset ||
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
    return scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        layoutVersion != oldDelegate.layoutVersion;
  }
}
