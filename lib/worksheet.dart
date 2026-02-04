/// High-performance Flutter worksheet widget with Excel-like functionality.
///
/// Supports 10%-400% zoom with GPU-optimized tile-based rendering.
library;

// Date parsing (re-exported so consumers don't need a direct any_date dependency)
export 'package:any_date/any_date.dart' show AnyDate, DateParserInfo;

// Core Models
export 'src/core/models/cell.dart';
export 'src/core/models/cell_coordinate.dart';
export 'src/core/models/cell_format.dart';
export 'src/core/models/cell_range.dart';
export 'src/core/models/cell_style.dart';
export 'src/core/models/cell_value.dart';
export 'src/core/models/freeze_config.dart';

// Core Geometry
export 'src/core/geometry/span_list.dart';
export 'src/core/geometry/layout_solver.dart';
export 'src/core/geometry/visible_range_calculator.dart';
export 'src/core/geometry/zoom_transformer.dart';

// Core Data
export 'src/core/data/data_change_event.dart';
export 'src/core/data/fill_pattern_detector.dart';
export 'src/core/data/worksheet_data.dart';
export 'src/core/data/sparse_worksheet_data.dart';

// Rendering - Tile System
export 'src/rendering/tile/tile.dart';
export 'src/rendering/tile/tile_cache.dart';
export 'src/rendering/tile/tile_config.dart';
export 'src/rendering/tile/tile_coordinate.dart';
export 'src/rendering/tile/tile_manager.dart';
export 'src/rendering/tile/tile_painter.dart';

// Scrolling
export 'src/scrolling/scroll_anchor.dart';
export 'src/scrolling/scroll_physics.dart';
export 'src/scrolling/viewport_delegate.dart';
export 'src/scrolling/worksheet_viewport.dart';
export 'src/scrolling/worksheet_scroll_delegate.dart';

// Interaction - Controllers
export 'src/interaction/controllers/zoom_controller.dart';
export 'src/interaction/controllers/selection_controller.dart';
export 'src/interaction/controllers/edit_controller.dart';

// Interaction - Hit Testing
export 'src/interaction/hit_testing/hit_test_result.dart';
export 'src/interaction/hit_testing/hit_tester.dart';

// Interaction - Clipboard
export 'src/interaction/clipboard/clipboard_handler.dart';
export 'src/interaction/clipboard/clipboard_serializer.dart';

// Interaction - Gestures
export 'src/interaction/gesture_handler.dart';

// Rendering - Painters
export 'src/rendering/painters/selection_renderer.dart';
export 'src/rendering/painters/header_renderer.dart';

// Rendering - Layers
export 'src/rendering/layers/render_layer.dart';
export 'src/rendering/layers/selection_layer.dart';
export 'src/rendering/layers/header_layer.dart';
export 'src/rendering/layers/frozen_layer.dart';

// Widgets
export 'src/widgets/worksheet_widget.dart';
export 'src/widgets/worksheet_controller.dart';
export 'src/widgets/worksheet_scrollbar_config.dart';
export 'src/widgets/worksheet_theme.dart';
export 'src/widgets/cell_editor_overlay.dart';

// Shortcuts / Actions
export 'src/shortcuts/worksheet_intents.dart';
export 'src/shortcuts/worksheet_action_context.dart';
export 'src/shortcuts/worksheet_actions.dart';
export 'src/shortcuts/default_worksheet_shortcuts.dart';

// Gesture Handlers
export 'src/interaction/gestures/scale_handler.dart';
@Deprecated('Use the Shortcuts/Actions pattern. See worksheet_intents.dart.')
export 'src/interaction/gestures/keyboard_handler.dart';
