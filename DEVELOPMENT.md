# Development Guide

This document describes how to set up and contribute to the worksheet package.

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.10.7 or later)
- Dart SDK (included with Flutter)
- An IDE with Flutter support (VS Code, Android Studio, or IntelliJ)

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/shorn/worksheet.git
   cd worksheet
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the example app:
   ```bash
   cd example
   flutter run
   ```

## Running Tests

Run all tests:
```bash
flutter test
```

Run a specific test file:
```bash
flutter test test/core/models/cell_coordinate_test.dart
```

Run tests with coverage:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Code Style

This project follows the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style) and uses `flutter_lints` for linting.

Run the analyzer:
```bash
dart analyze lib/
```

Format code:
```bash
dart format lib/ test/
```

## Project Structure

```
lib/
├── worksheet.dart          # Public API exports
└── src/
    ├── core/               # Models, data structures, geometry
    │   ├── data/           # WorksheetData, SparseWorksheetData
    │   ├── geometry/       # LayoutSolver, SpanList, ZoomTransformer
    │   └── models/         # CellCoordinate, CellRange, CellValue, CellStyle
    ├── rendering/          # Tile-based rendering system
    │   ├── layers/         # SelectionLayer, HeaderLayer, FrozenLayer
    │   ├── painters/       # HeaderRenderer, SelectionRenderer
    │   └── tile/           # Tile, TileManager, TileCache, TilePainter
    ├── scrolling/          # Viewport and scroll management
    │   └── ...             # WorksheetViewport, ScrollPhysics
    ├── interaction/        # Gesture handling and controllers
    │   ├── controllers/    # SelectionController, ZoomController, EditController
    │   ├── gestures/       # KeyboardHandler, ScaleHandler
    │   └── hit_testing/    # HitTester, HitTestResult
    └── widgets/            # Public widget API
        └── ...             # Worksheet, WorksheetController, WorksheetTheme

test/
├── core/                   # Unit tests for core models
├── rendering/              # Tests for rendering components
├── scrolling/              # Tests for scroll behavior
├── interaction/            # Tests for gesture handling
├── widgets/                # Widget tests
├── integration/            # Integration tests
└── benchmarks/             # Performance benchmarks
```

## Development Workflow

### TDD (Test-Driven Development)

This project follows TDD principles:

1. **Write the test first** - Define expected behavior before implementation
2. **Red** - Run the test, verify it fails
3. **Green** - Write minimal code to make the test pass
4. **Refactor** - Improve the code while keeping tests green

### Adding a New Feature

1. Create or update tests in the appropriate `test/` directory
2. Implement the feature in `lib/src/`
3. Export public API from `lib/worksheet.dart`
4. Update documentation as needed
5. Run all tests to ensure nothing is broken

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test additions or changes
- `refactor:` - Code refactoring
- `chore:` - Maintenance tasks

Example:
```
feat: add pinch-to-zoom gesture support

- Implement ScaleHandler for pinch gestures
- Add zoom anchor point calculation
- Update ZoomController to handle animated zoom
```

## Performance Guidelines

When working on rendering code:

1. **Never allocate in paint()** - Pre-allocate Paint objects, Paths, etc.
2. **Batch draw calls** - Group operations (e.g., all gridlines in one Path)
3. **Use LOD rendering** - Skip details at low zoom levels
4. **Tile size = 256px** - Optimal GPU texture size
5. **LRU cache tiles** - Max 100 tiles in memory
6. **Prefetch visible + 1 ring** - Tiles beyond viewport edge

Run benchmarks to verify performance:
```bash
flutter test test/benchmarks/
```

## Publishing

Dry run to check for issues:
```bash
dart pub publish --dry-run
```

Publish to pub.dev:
```bash
dart pub publish
```

## Getting Help

- [File an issue](https://github.com/shorn/worksheet/issues) for bugs or feature requests
- See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
