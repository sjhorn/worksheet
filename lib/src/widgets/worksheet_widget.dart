import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../core/data/worksheet_data.dart';
import '../interaction/hit_testing/hit_test_result.dart';
import '../core/geometry/layout_solver.dart';
import '../core/geometry/span_list.dart';
import '../core/models/cell_coordinate.dart';
import '../interaction/gesture_handler.dart';
import '../interaction/gestures/keyboard_handler.dart';
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

  late SelectionRenderer _selectionRenderer;
  late HeaderRenderer _headerRenderer;
  late SelectionLayer _selectionLayer;
  late HeaderLayer _headerLayer;

  bool _initialized = false;
  MouseCursor _currentCursor = SystemMouseCursors.basic;
  int _layoutVersion = 0;

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
    if (resizedRow < selection.startRow || resizedRow > selection.endRow) return;

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
    if (resizedColumn < selection.startColumn || resizedColumn > selection.endColumn) return;

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

  void _onControllerChanged() {
    setState(() {});
  }

  @override
  void didUpdateWidget(Worksheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.removeListener(_onControllerChanged);
        _controller.dispose();
      } else {
        _controller.removeListener(_onControllerChanged);
      }

      _initController();
      if (_initialized) {
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
        );
        final theme = WorksheetTheme.of(context);
        _selectionLayer.dispose();
        _headerLayer.dispose();
        _initLayers(theme);
      }
    }

    if (widget.data != oldWidget.data && _initialized) {
      _tileManager.invalidateAll();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = WorksheetTheme.of(context);
    _ensureInitialized(theme);
  }

  @override
  void dispose() {
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
                scrollOffset: Offset(_controller.scrollX, _controller.scrollY),
                zoom: _controller.zoom,
              );
              final newCursor = switch (hit.type) {
                HitTestType.rowResizeHandle => SystemMouseCursors.resizeRow,
                HitTestType.columnResizeHandle => SystemMouseCursors.resizeColumn,
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
                  if (event.buttons == kPrimaryButton) {
                    _gestureHandler.onDragUpdate(
                      position: event.localPosition,
                      scrollOffset: Offset(
                        _controller.scrollX,
                        _controller.scrollY,
                      ),
                      zoom: _controller.zoom,
                    );
                  }
                },
          onPointerUp: widget.readOnly
              ? null
              : (event) {
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
                  left: theme.showHeaders ? theme.rowHeaderWidth * _controller.zoom : 0,
                  top: theme.showHeaders ? theme.columnHeaderHeight * _controller.zoom : 0,
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

  Widget _buildScrollableContent(WorksheetThemeData theme) {
    // Use TwoDimensionalScrollable for proper 2D scrolling
    // Note: viewportBuilder receives (context, verticalOffset, horizontalOffset)
    return TwoDimensionalScrollable(
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
  }
}

/// Custom painter for selection layer.
class _SelectionPainter extends CustomPainter {
  final SelectionLayer layer;
  final Offset scrollOffset;
  final double zoom;
  final Offset headerOffset;

  _SelectionPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
    required this.headerOffset,
  }) : super(repaint: layer.selectionController);

  @override
  void paint(Canvas canvas, Size size) {
    // Offset for headers
    canvas.save();
    canvas.translate(headerOffset.dx, headerOffset.dy);
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width - headerOffset.dx, size.height - headerOffset.dy));

    layer.paint(LayerPaintContext(
      canvas: canvas,
      viewportSize: size,
      scrollOffset: scrollOffset,
      zoom: zoom,
    ));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) {
    return scrollOffset != oldDelegate.scrollOffset ||
        zoom != oldDelegate.zoom ||
        headerOffset != oldDelegate.headerOffset;
  }
}

/// Custom painter for header layer.
class _HeaderPainter extends CustomPainter {
  final HeaderLayer layer;
  final Offset scrollOffset;
  final double zoom;

  _HeaderPainter({
    required this.layer,
    required this.scrollOffset,
    required this.zoom,
  }) : super(repaint: layer.selectionController);

  @override
  void paint(Canvas canvas, Size size) {
    layer.paint(LayerPaintContext(
      canvas: canvas,
      viewportSize: size,
      scrollOffset: scrollOffset,
      zoom: zoom,
    ));
  }

  @override
  bool shouldRepaint(_HeaderPainter oldDelegate) {
    return scrollOffset != oldDelegate.scrollOffset || zoom != oldDelegate.zoom;
  }
}
