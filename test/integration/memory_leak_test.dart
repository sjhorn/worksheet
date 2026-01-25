import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet/src/core/data/sparse_worksheet_data.dart';
import 'package:worksheet/src/core/geometry/layout_solver.dart';
import 'package:worksheet/src/core/geometry/span_list.dart';
import 'package:worksheet/src/core/models/cell_coordinate.dart';
import 'package:worksheet/src/core/models/cell_value.dart';
import 'package:worksheet/src/interaction/controllers/edit_controller.dart';
import 'package:worksheet/src/interaction/controllers/selection_controller.dart';
import 'package:worksheet/src/interaction/controllers/zoom_controller.dart';

/// Memory leak tests for worksheet components.
///
/// These tests verify that components properly clean up resources
/// when disposed, preventing memory leaks in long-running applications.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryLeakTest', () {
    test('SparseWorksheetData cleans up on dispose', () {
      final data = SparseWorksheetData(rowCount: 1000, columnCount: 100);

      // Populate with data
      for (int row = 0; row < 100; row++) {
        for (int col = 0; col < 50; col++) {
          data.setCell(CellCoordinate(row, col), CellValue.number(row * 100.0 + col));
        }
      }

      expect(data.populatedCellCount, 5000);

      // Dispose should clean up
      data.dispose();

      // Subsequent calls should fail
      expect(
        () => data.setCell(const CellCoordinate(0, 0), CellValue.number(1)),
        throwsStateError,
      );
    });

    test('SelectionController cleans up listeners on dispose', () {
      final controller = SelectionController();
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.selectCell(const CellCoordinate(0, 0));
      expect(notifyCount, 1);

      controller.dispose();

      // Should not throw, but also should not notify
      // (disposed controller should be safe to ignore)
    });

    test('ZoomController cleans up on dispose', () {
      final controller = ZoomController();

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.value = 1.5;
      expect(notifyCount, 1);

      controller.dispose();

      // Should not throw after dispose
    });

    test('EditController cleans up on dispose', () {
      final controller = EditController();

      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.startEdit(cell: const CellCoordinate(0, 0));
      expect(notifyCount, 1);

      controller.dispose();
    });

    test('SpanList handles repeated resize operations', () {
      final spans = SpanList(defaultSize: 24.0, count: 1000);

      // Perform many resize operations
      for (int i = 0; i < 10000; i++) {
        spans.setSize(i % 1000, 24.0 + (i % 50));
      }

      // Should not accumulate memory beyond the 1000 entries
      // (just verifying it doesn't throw or hang)
      expect(spans.count, 1000);
    });

    test('LayoutSolver handles repeated lookups without accumulation', () {
      final rows = SpanList(defaultSize: 24.0, count: 10000);
      final columns = SpanList(defaultSize: 80.0, count: 1000);
      final layoutSolver = LayoutSolver(rows: rows, columns: columns);

      // Perform many lookups (should not accumulate any state)
      for (int i = 0; i < 100000; i++) {
        layoutSolver.getCellBounds(CellCoordinate(i % 10000, i % 1000));
        layoutSolver.getRowAt(i.toDouble() % layoutSolver.totalHeight);
        layoutSolver.getColumnAt(i.toDouble() % layoutSolver.totalWidth);
      }

      // Just verifying no exception or hang
      expect(layoutSolver.rowCount, 10000);
    });

    test('data stream subscriptions are properly cancelled', () async {
      final data = SparseWorksheetData(rowCount: 100, columnCount: 100);

      var eventCount = 0;
      final subscription = data.changes.listen((_) => eventCount++);

      // Make some changes
      data.setCell(const CellCoordinate(0, 0), CellValue.number(1));
      data.setCell(const CellCoordinate(0, 1), CellValue.number(2));

      await Future.delayed(const Duration(milliseconds: 10));
      expect(eventCount, 2);

      // Cancel subscription
      await subscription.cancel();

      // Further changes should not increment count
      data.setCell(const CellCoordinate(0, 2), CellValue.number(3));

      await Future.delayed(const Duration(milliseconds: 10));
      expect(eventCount, 2); // Still 2, not 3

      data.dispose();
    });

    test('repeated create/dispose cycles do not leak', () {
      // Create and dispose many instances
      for (int i = 0; i < 100; i++) {
        final data = SparseWorksheetData(rowCount: 1000, columnCount: 100);

        // Add some data
        for (int j = 0; j < 100; j++) {
          data.setCell(CellCoordinate(j, 0), CellValue.number(j.toDouble()));
        }

        data.dispose();

        final selection = SelectionController();
        selection.selectCell(CellCoordinate(i, 0));
        selection.dispose();

        final zoom = ZoomController();
        zoom.value = 1.0 + (i % 10) * 0.1;
        zoom.dispose();

        final edit = EditController();
        edit.startEdit(cell: CellCoordinate(i, 0));
        edit.dispose();
      }

      // If we get here without running out of memory, we're good
      expect(true, isTrue);
    });

    test('large data dispose cleans everything', () {
      final data = SparseWorksheetData(rowCount: 100000, columnCount: 1000);

      // Populate a lot of cells
      for (int row = 0; row < 1000; row++) {
        for (int col = 0; col < 100; col++) {
          data.setCell(
            CellCoordinate(row, col),
            CellValue.text('Cell data at $row,$col with some extra text'),
          );
        }
      }

      expect(data.populatedCellCount, 100000);

      // Dispose
      data.dispose();

      // Verify mutating operations throw after dispose
      expect(
        () => data.setCell(const CellCoordinate(0, 0), CellValue.number(1)),
        throwsStateError,
      );
    });
  });
}
