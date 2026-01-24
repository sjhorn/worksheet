import 'package:flutter_test/flutter_test.dart';
import 'package:worksheet2/src/core/models/freeze_config.dart';

void main() {
  group('FreezeConfig', () {
    test('creates with default values (no freeze)', () {
      const config = FreezeConfig();

      expect(config.frozenRows, 0);
      expect(config.frozenColumns, 0);
      expect(config.hasFrozenRows, isFalse);
      expect(config.hasFrozenColumns, isFalse);
      expect(config.hasFrozenPanes, isFalse);
    });

    test('creates with frozen rows', () {
      const config = FreezeConfig(frozenRows: 2);

      expect(config.frozenRows, 2);
      expect(config.frozenColumns, 0);
      expect(config.hasFrozenRows, isTrue);
      expect(config.hasFrozenColumns, isFalse);
      expect(config.hasFrozenPanes, isTrue);
    });

    test('creates with frozen columns', () {
      const config = FreezeConfig(frozenColumns: 3);

      expect(config.frozenRows, 0);
      expect(config.frozenColumns, 3);
      expect(config.hasFrozenRows, isFalse);
      expect(config.hasFrozenColumns, isTrue);
      expect(config.hasFrozenPanes, isTrue);
    });

    test('creates with both frozen rows and columns', () {
      const config = FreezeConfig(frozenRows: 1, frozenColumns: 2);

      expect(config.frozenRows, 1);
      expect(config.frozenColumns, 2);
      expect(config.hasFrozenRows, isTrue);
      expect(config.hasFrozenColumns, isTrue);
      expect(config.hasFrozenPanes, isTrue);
    });

    test('equality', () {
      const config1 = FreezeConfig(frozenRows: 1, frozenColumns: 2);
      const config2 = FreezeConfig(frozenRows: 1, frozenColumns: 2);
      const config3 = FreezeConfig(frozenRows: 1, frozenColumns: 3);

      expect(config1, config2);
      expect(config1.hashCode, config2.hashCode);
      expect(config1, isNot(config3));
    });

    test('copyWith', () {
      const original = FreezeConfig(frozenRows: 1, frozenColumns: 2);

      final withNewRows = original.copyWith(frozenRows: 3);
      expect(withNewRows.frozenRows, 3);
      expect(withNewRows.frozenColumns, 2);

      final withNewColumns = original.copyWith(frozenColumns: 4);
      expect(withNewColumns.frozenRows, 1);
      expect(withNewColumns.frozenColumns, 4);

      final withBoth = original.copyWith(frozenRows: 5, frozenColumns: 6);
      expect(withBoth.frozenRows, 5);
      expect(withBoth.frozenColumns, 6);
    });

    test('none constant has no frozen panes', () {
      expect(FreezeConfig.none.frozenRows, 0);
      expect(FreezeConfig.none.frozenColumns, 0);
      expect(FreezeConfig.none.hasFrozenPanes, isFalse);
    });

    test('toString', () {
      const config = FreezeConfig(frozenRows: 2, frozenColumns: 3);
      expect(config.toString(), 'FreezeConfig(frozenRows: 2, frozenColumns: 3)');
    });

    group('isFrozenRow', () {
      test('returns true for rows within frozen range', () {
        const config = FreezeConfig(frozenRows: 3);

        expect(config.isFrozenRow(0), isTrue);
        expect(config.isFrozenRow(1), isTrue);
        expect(config.isFrozenRow(2), isTrue);
        expect(config.isFrozenRow(3), isFalse);
        expect(config.isFrozenRow(4), isFalse);
      });

      test('returns false when no frozen rows', () {
        const config = FreezeConfig();

        expect(config.isFrozenRow(0), isFalse);
        expect(config.isFrozenRow(1), isFalse);
      });
    });

    group('isFrozenColumn', () {
      test('returns true for columns within frozen range', () {
        const config = FreezeConfig(frozenColumns: 2);

        expect(config.isFrozenColumn(0), isTrue);
        expect(config.isFrozenColumn(1), isTrue);
        expect(config.isFrozenColumn(2), isFalse);
        expect(config.isFrozenColumn(3), isFalse);
      });

      test('returns false when no frozen columns', () {
        const config = FreezeConfig();

        expect(config.isFrozenColumn(0), isFalse);
        expect(config.isFrozenColumn(1), isFalse);
      });
    });

    group('isFrozenCell', () {
      test('returns true when row is frozen', () {
        const config = FreezeConfig(frozenRows: 1);

        expect(config.isFrozenCell(0, 5), isTrue);
        expect(config.isFrozenCell(1, 5), isFalse);
      });

      test('returns true when column is frozen', () {
        const config = FreezeConfig(frozenColumns: 1);

        expect(config.isFrozenCell(5, 0), isTrue);
        expect(config.isFrozenCell(5, 1), isFalse);
      });

      test('returns true for corner cell when both frozen', () {
        const config = FreezeConfig(frozenRows: 2, frozenColumns: 2);

        // Corner area
        expect(config.isFrozenCell(0, 0), isTrue);
        expect(config.isFrozenCell(1, 1), isTrue);

        // Frozen row only
        expect(config.isFrozenCell(0, 5), isTrue);
        expect(config.isFrozenCell(1, 5), isTrue);

        // Frozen column only
        expect(config.isFrozenCell(5, 0), isTrue);
        expect(config.isFrozenCell(5, 1), isTrue);

        // Neither
        expect(config.isFrozenCell(5, 5), isFalse);
      });
    });
  });
}
