import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'worksheet.dart';

void main() {
  runApp(const WorksheetDemoApp());
}

class WorksheetDemoApp extends StatelessWidget {
  const WorksheetDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worksheet Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WorksheetDemo(),
    );
  }
}

class WorksheetDemo extends StatefulWidget {
  const WorksheetDemo({super.key});

  @override
  State<WorksheetDemo> createState() => _WorksheetDemoState();
}

class _WorksheetDemoState extends State<WorksheetDemo> {
  static const int _rowCount = 1000;
  static const int _columnCount = 26;

  late final SparseWorksheetData _data;
  late final WorksheetController _controller;
  late final EditController _editController;
  late final LayoutSolver _layoutSolver;

  Rect? _editingCellBounds;

  @override
  void initState() {
    super.initState();

    _data = SparseWorksheetData(rowCount: _rowCount, columnCount: _columnCount);
    _populateSampleData();

    _controller = WorksheetController();
    _editController = EditController();

    _layoutSolver = LayoutSolver(
      rows: SpanList(count: _rowCount, defaultSize: 24.0),
      columns: SpanList(count: _columnCount, defaultSize: 100.0),
    );
  }

  void _populateSampleData() {
    // Header row
    _data.setCell(const CellCoordinate(0, 0), CellValue.text('Name'));
    _data.setCell(const CellCoordinate(0, 1), CellValue.text('Value'));
    _data.setCell(const CellCoordinate(0, 2), CellValue.text('Notes'));
    for (int col = 0; col < 3; col++) {
      _data.setStyle(
        CellCoordinate(0, col),
        const CellStyle(
          backgroundColor: Color(0xFFE8E8E8),
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Sample data
    _data.setCell(const CellCoordinate(1, 0), CellValue.text('Alpha'));
    _data.setCell(const CellCoordinate(1, 1), CellValue.number(42));
    _data.setCell(const CellCoordinate(1, 2), CellValue.text('First entry'));

    _data.setCell(const CellCoordinate(2, 0), CellValue.text('Beta'));
    _data.setCell(const CellCoordinate(2, 1), CellValue.number(3.14159));
    _data.setCell(const CellCoordinate(2, 2), CellValue.text('Pi value'));

    _data.setCell(const CellCoordinate(3, 0), CellValue.text('Gamma'));
    _data.setCell(const CellCoordinate(3, 1), CellValue.boolean(true));
    _data.setCell(const CellCoordinate(3, 2), CellValue.text('Boolean'));

    _data.setCell(const CellCoordinate(4, 0), CellValue.text('Delta'));
    _data.setCell(const CellCoordinate(4, 1), CellValue.formula('=B2+B3'));
    _data.setCell(const CellCoordinate(4, 2), CellValue.text('Formula'));

    // Styled cells
    _data.setCell(const CellCoordinate(6, 0), CellValue.text('Styled:'));
    _data.setStyle(const CellCoordinate(6, 0), const CellStyle(fontWeight: FontWeight.bold));

    _data.setCell(const CellCoordinate(7, 0), CellValue.text('Red BG'));
    _data.setStyle(const CellCoordinate(7, 0), const CellStyle(backgroundColor: Color(0xFFFFCCCC)));

    _data.setCell(const CellCoordinate(8, 0), CellValue.text('Blue Text'));
    _data.setStyle(const CellCoordinate(8, 0), const CellStyle(textColor: Color(0xFF0000FF)));
  }

  void _onEditCell(CellCoordinate cell) {
    const headerWidth = 50.0;
    const headerHeight = 24.0;

    final cellLeft = _layoutSolver.getColumnLeft(cell.column) * _controller.zoom;
    final cellTop = _layoutSolver.getRowTop(cell.row) * _controller.zoom;
    final cellWidth = _layoutSolver.getColumnWidth(cell.column) * _controller.zoom;
    final cellHeight = _layoutSolver.getRowHeight(cell.row) * _controller.zoom;

    final adjustedLeft = cellLeft - _controller.scrollX + headerWidth;
    final adjustedTop = cellTop - _controller.scrollY + headerHeight;

    setState(() {
      _editingCellBounds = Rect.fromLTWH(adjustedLeft, adjustedTop, cellWidth, cellHeight);
    });

    final currentValue = _data.getCell(cell);
    _editController.startEdit(
      cell: cell,
      currentValue: currentValue,
      trigger: EditTrigger.doubleTap,
    );
  }

  void _onCommit(CellCoordinate cell, CellValue? value) {
    setState(() {
      _data.setCell(cell, value);
      _editingCellBounds = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved ${cell.toNotation()}: ${value?.displayValue ?? "(empty)"}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onCancel() {
    setState(() {
      _editingCellBounds = null;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worksheet Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _controller.zoomOut();
              setState(() {});
            },
          ),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(child: Text('${(_controller.zoom * 100).round()}%')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _controller.zoomIn();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.resetZoom();
              setState(() {});
            },
            tooltip: 'Reset zoom',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSelectionInfo(),
          _buildInstructions(),
          Expanded(
            child: Stack(
              children: [
                Focus(
                  autofocus: true,
                  onKeyEvent: _handleKeyEvent,
                  child: WorksheetTheme(
                    data: const WorksheetThemeData(
                      showHeaders: true,
                      showGridlines: true,
                    ),
                    child: Worksheet(
                      data: _data,
                      controller: _controller,
                      rowCount: _rowCount,
                      columnCount: _columnCount,
                      onEditCell: _onEditCell,
                      onCellTap: (cell) {
                        if (_editController.isEditing && _editController.editingCell != cell) {
                          _editController.commitEdit(onCommit: _onCommit);
                        }
                      },
                    ),
                  ),
                ),
                if (_editController.isEditing && _editingCellBounds != null)
                  CellEditorOverlay(
                    editController: _editController,
                    cellBounds: _editingCellBounds!,
                    onCommit: _onCommit,
                    onCancel: _onCancel,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.f2) {
      final cell = _controller.focusCell;
      if (cell != null && !_editController.isEditing) {
        _onEditCell(cell);
        return KeyEventResult.handled;
      }
    }

    if (!_editController.isEditing) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _controller.moveFocus(rowDelta: -1, columnDelta: 0, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _controller.moveFocus(rowDelta: 1, columnDelta: 0, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _controller.moveFocus(rowDelta: 0, columnDelta: -1, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _controller.moveFocus(rowDelta: 0, columnDelta: 1, extend: isShift, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        _controller.moveFocus(rowDelta: 0, columnDelta: isShift ? -1 : 1, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        _controller.moveFocus(rowDelta: isShift ? -1 : 1, columnDelta: 0, maxRow: _rowCount - 1, maxColumn: _columnCount - 1);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildSelectionInfo() {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final selection = _controller.selectedRange;
        final focus = _controller.focusCell;
        final cellValue = focus != null ? _data.getCell(focus) : null;

        String text;
        if (selection != null) {
          final start = CellCoordinate(selection.startRow, selection.startColumn);
          final end = CellCoordinate(selection.endRow, selection.endColumn);
          text = start == end
              ? 'Selected: ${start.toNotation()}'
              : 'Selected: ${start.toNotation()}:${end.toNotation()}';
          if (cellValue != null) {
            text += ' = ${cellValue.displayValue}';
          }
        } else {
          text = 'No selection - click a cell to select';
        }

        return Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[200],
          width: double.infinity,
          child: Text(text),
        );
      },
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Colors.blue[50],
      width: double.infinity,
      child: const Text(
        'Double-click or F2 to edit | Enter to save | Escape to cancel | Arrow keys to navigate',
        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
      ),
    );
  }
}
