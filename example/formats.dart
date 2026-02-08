// Demonstrates all CellFormat formatting capabilities.
//
// Run with: flutter run -t example/formats.dart
import 'package:flutter/material.dart';
import 'package:worksheet/worksheet.dart';

void main() => runApp(const MaterialApp(home: FormatsDemo()));

class FormatsDemo extends StatefulWidget {
  const FormatsDemo({super.key});

  @override
  State<FormatsDemo> createState() => _FormatsDemoState();
}

class _FormatsDemoState extends State<FormatsDemo> {
  late final SparseWorksheetData _data;
  late final EditController _editController;

  @override
  void initState() {
    super.initState();
    _data = SparseWorksheetData(
      rowCount: 60,
      columnCount: 6,
      cells: _buildCells(),
    );
    _editController = EditController();
  }

  Map<(int, int), Cell> _buildCells() {
    final cells = <(int, int), Cell>{};
    var row = 0;

    // --- General ---
    cells[(row, 0)] = 'GENERAL'.cell;
    cells[(row, 1)] = 'Format Code'.cell;
    cells[(row, 2)] = 'Input'.cell;
    cells[(row, 3)] = 'Output'.cell;
    row++;

    cells[(row, 0)] = 'General'.cell;
    cells[(row, 1)] = '(none)'.cell;
    cells[(row, 2)] = '42'.cell;
    cells[(row, 3)] = Cell.number(42, format: CellFormat.general);
    row++;

    cells[(row, 0)] = 'General'.cell;
    cells[(row, 1)] = '(none)'.cell;
    cells[(row, 2)] = '3.14'.cell;
    cells[(row, 3)] = Cell.number(3.14, format: CellFormat.general);
    row++;

    // --- Number ---
    row++;
    cells[(row, 0)] = 'NUMBER'.cell;
    row++;

    cells[(row, 0)] = 'Integer'.cell;
    cells[(row, 1)] = '#,##0'.cell;
    cells[(row, 2)] = '1234567'.cell;
    cells[(row, 3)] = Cell.number(1234567, format: CellFormat.integer);
    row++;

    cells[(row, 0)] = 'Decimal'.cell;
    cells[(row, 1)] = '0.00'.cell;
    cells[(row, 2)] = '3.1'.cell;
    cells[(row, 3)] = Cell.number(3.1, format: CellFormat.decimal);
    row++;

    cells[(row, 0)] = 'Number'.cell;
    cells[(row, 1)] = '#,##0.00'.cell;
    cells[(row, 2)] = '1234.5'.cell;
    cells[(row, 3)] = Cell.number(1234.5, format: CellFormat.number);
    row++;

    cells[(row, 0)] = 'Negative'.cell;
    cells[(row, 1)] = '#,##0.00'.cell;
    cells[(row, 2)] = '-1234.5'.cell;
    cells[(row, 3)] = Cell.number(-1234.5, format: CellFormat.number);
    row++;

    // --- Currency ---
    row++;
    cells[(row, 0)] = 'CURRENCY'.cell;
    row++;

    cells[(row, 0)] = 'Currency'.cell;
    cells[(row, 1)] = r'$#,##0.00'.cell;
    cells[(row, 2)] = '1234.5'.cell;
    cells[(row, 3)] = Cell.number(1234.5, format: CellFormat.currency);
    row++;

    cells[(row, 0)] = 'Negative'.cell;
    cells[(row, 1)] = r'$#,##0.00'.cell;
    cells[(row, 2)] = '-42'.cell;
    cells[(row, 3)] = Cell.number(-42, format: CellFormat.currency);
    row++;

    cells[(row, 0)] = 'Zero'.cell;
    cells[(row, 1)] = r'$#,##0.00'.cell;
    cells[(row, 2)] = '0'.cell;
    cells[(row, 3)] = Cell.number(0, format: CellFormat.currency);
    row++;

    // --- Financial (2-section) ---
    row++;
    cells[(row, 0)] = 'FINANCIAL'.cell;
    row++;

    const financialFmt = CellFormat(
      type: CellFormatType.number,
      formatCode: r'#,##0.00_);(#,##0.00)',
    );

    cells[(row, 0)] = 'Positive'.cell;
    cells[(row, 1)] = r'#,##0.00_);(#,##0.00)'.cell;
    cells[(row, 2)] = '1234.56'.cell;
    cells[(row, 3)] = Cell.number(1234.56, format: financialFmt);
    row++;

    cells[(row, 0)] = 'Negative'.cell;
    cells[(row, 1)] = r'#,##0.00_);(#,##0.00)'.cell;
    cells[(row, 2)] = '-1234.56'.cell;
    cells[(row, 3)] = Cell.number(-1234.56, format: financialFmt);
    row++;

    cells[(row, 0)] = 'Zero'.cell;
    cells[(row, 1)] = r'#,##0.00_);(#,##0.00)'.cell;
    cells[(row, 2)] = '0'.cell;
    cells[(row, 3)] = Cell.number(0, format: financialFmt);
    row++;

    // --- Accounting (4-section) ---
    row++;
    cells[(row, 0)] = 'ACCOUNTING'.cell;
    row++;

    const acctFmt = CellFormat(
      type: CellFormatType.accounting,
      formatCode:
          r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)',
    );

    const acctCode =
        r'_("$"* #,##0.00_);_("$"* \(#,##0.00\);_("$"* "-"??_);_(@_)';

    cells[(row, 0)] = 'Positive'.cell;
    cells[(row, 1)] = acctCode.cell;
    cells[(row, 2)] = '1234.56'.cell;
    cells[(row, 3)] = Cell.number(1234.56, format: acctFmt);
    row++;

    cells[(row, 0)] = 'Negative'.cell;
    cells[(row, 1)] = acctCode.cell;
    cells[(row, 2)] = '-1234.56'.cell;
    cells[(row, 3)] = Cell.number(-1234.56, format: acctFmt);
    row++;

    cells[(row, 0)] = 'Zero'.cell;
    cells[(row, 1)] = acctCode.cell;
    cells[(row, 2)] = '0'.cell;
    cells[(row, 3)] = Cell.number(0, format: acctFmt);
    row++;

    cells[(row, 0)] = 'Text'.cell;
    cells[(row, 1)] = acctCode.cell;
    cells[(row, 2)] = 'hello'.cell;
    cells[(row, 3)] = Cell.text('hello', format: acctFmt);
    row++;

    // --- Percentage ---
    row++;
    cells[(row, 0)] = 'PERCENTAGE'.cell;
    row++;

    cells[(row, 0)] = 'Percentage'.cell;
    cells[(row, 1)] = '0%'.cell;
    cells[(row, 2)] = '0.42'.cell;
    cells[(row, 3)] = Cell.number(0.42, format: CellFormat.percentage);
    row++;

    cells[(row, 0)] = 'With decimals'.cell;
    cells[(row, 1)] = '0.00%'.cell;
    cells[(row, 2)] = '0.4256'.cell;
    cells[(row, 3)] =
        Cell.number(0.4256, format: CellFormat.percentageDecimal);
    row++;

    cells[(row, 0)] = 'Over 100%'.cell;
    cells[(row, 1)] = '0%'.cell;
    cells[(row, 2)] = '1.5'.cell;
    cells[(row, 3)] = Cell.number(1.5, format: CellFormat.percentage);
    row++;

    // --- Scientific ---
    row++;
    cells[(row, 0)] = 'SCIENTIFIC'.cell;
    row++;

    cells[(row, 0)] = 'Large'.cell;
    cells[(row, 1)] = '0.00E+00'.cell;
    cells[(row, 2)] = '12345'.cell;
    cells[(row, 3)] = Cell.number(12345, format: CellFormat.scientific);
    row++;

    cells[(row, 0)] = 'Small'.cell;
    cells[(row, 1)] = '0.00E+00'.cell;
    cells[(row, 2)] = '0.00123'.cell;
    cells[(row, 3)] = Cell.number(0.00123, format: CellFormat.scientific);
    row++;

    // --- Fraction ---
    row++;
    cells[(row, 0)] = 'FRACTION'.cell;
    row++;

    cells[(row, 0)] = 'Mixed'.cell;
    cells[(row, 1)] = '# ?/?'.cell;
    cells[(row, 2)] = '3.5'.cell;
    cells[(row, 3)] = Cell.number(3.5, format: CellFormat.fraction);
    row++;

    cells[(row, 0)] = 'Simple'.cell;
    cells[(row, 1)] = '# ?/?'.cell;
    cells[(row, 2)] = '0.25'.cell;
    cells[(row, 3)] = Cell.number(0.25, format: CellFormat.fraction);
    row++;

    // --- Date ---
    row++;
    cells[(row, 0)] = 'DATE'.cell;
    row++;

    final date = DateTime(2024, 1, 15, 14, 30, 5);

    cells[(row, 0)] = 'ISO'.cell;
    cells[(row, 1)] = 'yyyy-MM-dd'.cell;
    cells[(row, 2)] = '2024-01-15'.cell;
    cells[(row, 3)] = Cell.date(date, format: CellFormat.dateIso);
    row++;

    cells[(row, 0)] = 'US'.cell;
    cells[(row, 1)] = 'm/d/yyyy'.cell;
    cells[(row, 2)] = '2024-01-15'.cell;
    cells[(row, 3)] = Cell.date(date, format: CellFormat.dateUs);
    row++;

    cells[(row, 0)] = 'Short'.cell;
    cells[(row, 1)] = 'd-mmm-yy'.cell;
    cells[(row, 2)] = '2024-01-15'.cell;
    cells[(row, 3)] = Cell.date(date, format: CellFormat.dateShort);
    row++;

    // --- Date + Time ---
    row++;
    cells[(row, 0)] = 'DATE + TIME'.cell;
    row++;

    const dateTimeFmt = CellFormat(
      type: CellFormatType.date,
      formatCode: 'm/d/yyyy H:mm:ss',
    );
    cells[(row, 0)] = 'Date + 24h'.cell;
    cells[(row, 1)] = 'm/d/yyyy H:mm:ss'.cell;
    cells[(row, 2)] = '2024-01-15 14:30:05'.cell;
    cells[(row, 3)] = Cell.date(date, format: dateTimeFmt);
    row++;

    const dateTime12Fmt = CellFormat(
      type: CellFormatType.date,
      formatCode: 'm/d/yyyy h:mm AM/PM',
    );
    cells[(row, 0)] = 'Date + 12h'.cell;
    cells[(row, 1)] = 'm/d/yyyy h:mm AM/PM'.cell;
    cells[(row, 2)] = '2024-01-15 14:30:05'.cell;
    cells[(row, 3)] = Cell.date(date, format: dateTime12Fmt);
    row++;

    // --- Time ---
    row++;
    cells[(row, 0)] = 'TIME'.cell;
    row++;

    cells[(row, 0)] = '24-hour'.cell;
    cells[(row, 1)] = 'H:mm'.cell;
    cells[(row, 2)] = '14:30'.cell;
    cells[(row, 3)] = Cell.date(date, format: CellFormat.time24);
    row++;

    cells[(row, 0)] = '12-hour'.cell;
    cells[(row, 1)] = 'h:mm AM/PM'.cell;
    cells[(row, 2)] = '14:30'.cell;
    cells[(row, 3)] = Cell.date(date, format: CellFormat.time12);
    row++;

    cells[(row, 0)] = 'With seconds'.cell;
    cells[(row, 1)] = 'H:mm:ss'.cell;
    cells[(row, 2)] = '14:30:05'.cell;
    cells[(row, 3)] = Cell.date(date, format: CellFormat.time24Seconds);
    row++;

    // --- Duration ---
    row++;
    cells[(row, 0)] = 'DURATION'.cell;
    row++;

    cells[(row, 0)] = 'H:M:S'.cell;
    cells[(row, 1)] = '[h]:mm:ss'.cell;
    cells[(row, 2)] = '1h 30m 5s'.cell;
    cells[(row, 3)] = Cell.duration(
      const Duration(hours: 1, minutes: 30, seconds: 5),
      format: CellFormat.duration,
    );
    row++;

    cells[(row, 0)] = 'H:M'.cell;
    cells[(row, 1)] = '[h]:mm'.cell;
    cells[(row, 2)] = '2h 45m'.cell;
    cells[(row, 3)] = Cell.duration(
      const Duration(hours: 2, minutes: 45),
      format: CellFormat.durationShort,
    );
    row++;

    cells[(row, 0)] = 'M:S'.cell;
    cells[(row, 1)] = '[m]:ss'.cell;
    cells[(row, 2)] = '1h 30m 5s'.cell;
    cells[(row, 3)] = Cell.duration(
      const Duration(hours: 1, minutes: 30, seconds: 5),
      format: CellFormat.durationMinSec,
    );
    row++;

    // --- Text ---
    row++;
    cells[(row, 0)] = 'TEXT'.cell;
    row++;

    cells[(row, 0)] = 'Plain text'.cell;
    cells[(row, 1)] = '@'.cell;
    cells[(row, 2)] = 'hello'.cell;
    cells[(row, 3)] = Cell.text('hello', format: CellFormat.text);
    row++;

    return cells;
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
      appBar: AppBar(title: const Text('CellFormat Gallery')),
      body: WorksheetTheme(
        data: const WorksheetThemeData(),
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
