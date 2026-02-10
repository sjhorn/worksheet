import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: DarkLightExample()));

class DarkLightExample extends StatefulWidget {
  const DarkLightExample({super.key});

  @override
  State<DarkLightExample> createState() => _DarkLightExampleState();
}

class _DarkLightExampleState extends State<DarkLightExample> {
  late final SparseWorksheetData _data;
  late final EditController _editController;
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 100,
      columnCount: 10,
      cells: {
        (0, 0): 'Name'.cell,
        (0, 1): 'Amount'.cell,
        (0, 2): 'Price'.cell,
        (1, 0): 'Apples'.cell,
        (1, 1): 42.cell,
        (1, 2): Cell.number(1.50, format: CellFormat.currency),
        (2, 0): 'Bananas'.cell,
        (2, 1): 28.cell,
        (2, 2): Cell.number(0.75, format: CellFormat.currency),
        (3, 0): 'Cherries'.cell,
        (3, 1): 100.cell,
        (3, 2): Cell.number(4.99, format: CellFormat.currency),
        (4, 0): 'Dates'.cell,
        (4, 1): 15.cell,
        (4, 2): Cell.number(8.25, format: CellFormat.currency),
      },
    );
    _editController = EditController();
  }

  @override
  void dispose() {
    _editController.dispose();
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            _isDark ? const Color(0xFF333333) : null,
        foregroundColor:
            _isDark ? const Color(0xFFD0D0D0) : null,
        title: Text(_isDark ? 'Dark Mode' : 'Light Mode'),
        actions: [
          IconButton(
            icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle dark/light mode',
            onPressed: () => setState(() => _isDark = !_isDark),
          ),
          const SizedBox(width: 48),
        ],
      ),
      body: WorksheetTheme(
        data: _isDark
            ? WorksheetThemeData.darkTheme
            : WorksheetThemeData.defaultTheme,
        child: Worksheet(
          data: _data,
          editController: _editController,
          rowCount: _data.rowCount,
          columnCount: _data.columnCount,
        ),
      ),
    );
  }
}
