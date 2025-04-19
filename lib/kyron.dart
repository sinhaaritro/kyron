// lib/kyron.dart

library;

/// Exports the public API of the Kyron mediator library.

// Exceptions
export 'src/exceptions.dart';

// Core Mediator Interface & Implementation
export 'src/kyron_base.dart';
export 'src/kyron_interface.dart';

// Expose PipelineContext constructor if apps need to create mock contexts for testing
// export 'src/pipeline_context.dart';

// Notification Interfaces & Types
export 'src/notification.dart';
export 'src/notification_handler.dart';
export 'src/notification_order.dart';

// Pipeline Components
export 'src/pipeline_behavior.dart';
export 'src/pipeline_context.dart';

// Request/Response Interfaces & Types
export 'src/request.dart'; // Exports Request<T>, StreamRequest<T>, BaseRequest
export 'src/request_handler.dart'; // Exports RequestHandler<>, StreamRequestHandler<>

// Registry, Executor, Dispatcher are internal implementation details by default.
// Explicitly DO NOT export:
// - src/registry.dart
// - src/pipeline_executor.dart
// - src/notification_dispatcher.dart
