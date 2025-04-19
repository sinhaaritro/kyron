// lib/src/pipeline_context.dart

/// Holds shared, mutable state accessible by different pipeline behaviors and the
/// request handler during the processing of a single request invocation
/// (via [Kyron.send] or [Kyron.stream]).
///
/// An instance of this class is created automatically by the [Kyron] mediator
/// for each request being processed. The *same* instance is then passed sequentially
/// through all applicable [PipelineBehavior]s and finally to the corresponding
/// [RequestHandler] or [StreamRequestHandler] for that specific request. It allows
/// components earlier in the pipeline (like an authentication behavior) to pass
/// data or state to components later in the pipeline (like the handler or a
/// logging behavior).
///
/// **Key Concepts:**
///   - **Transient:** The context exists only for the duration of a single request's
///     processing pipeline. It is not persisted.
///   - **Mutable:** Behaviors and handlers can add, modify, or remove items from
///     the context's `items` map.
///   - **Shared:** It's the common ground for communication between pipeline components
///     within a single request flow.
///
/// **How to Use:**
///
/// **1. Direct Usage (Basic - Using the [items] Map):**
///    The core mechanism is the [items] map. You can store any data using a unique
///    key. It's crucial to use well-defined keys (preferably [Symbol]s or [const String]s
///    defined centrally) to avoid collisions between different behaviors.
///
///    {@tool snippet}
///    **Example: Storing and Retrieving Directly**
///
///    ```dart
///    // Define keys (e.g., in a separate constants file)
///    const Symbol userIdKey = #userId;
///    const Symbol transactionIdKey = #transactionId;
///
///    // In an Authentication Behavior:
///    class AuthBehavior extends PipelineBehavior<BaseRequest, dynamic> {
///      @override Future handle(request, context, next) async {
///        // ... authentication logic ...
///        final userId = 123; // Assume fetched user ID
///        context.items[userIdKey] = userId; // Store user ID
///        print('AuthBehavior: Added userId to context.');
///        return await next();
///      }
///      @override int get order => -5; // Run early
///    }
///
///    // In a Logging Behavior or Handler:
///    class SomeLaterBehavior extends PipelineBehavior<BaseRequest, dynamic> {
///       @override Future handle(request, context, next) async {
///         // Retrieve user ID - requires casting and null check!
///         final userId = context.items[userIdKey] as int?;
///         if (userId != null) {
///           print('SomeLaterBehavior: Found userId $userId in context.');
///         } else {
///           print('SomeLaterBehavior: userId not found in context.');
///         }
///         // Attempting to retrieve with wrong type or non-existent key requires care
///         // final wrongType = context.items[userIdKey] as String?; // Runtime error if key exists!
///
///         return await next();
///       }
///       @override int get order => 10; // Run later
///    }
///    ```
///    * **Pros:** Simple, fundamental mechanism.
///    * **Cons:** Requires manual type casting, susceptible to runtime errors if keys
///      are missing or types don't match, requires knowing the exact keys (risk of typos).
///    {@end-tool}
///
/// **2. Recommended Usage (Type-Safe Access via Extension Methods):**
///    To achieve better type safety and code clarity (simulating a "custom context"
///    without requiring a different class), define extension methods on [PipelineContext]
///    within your application or example code. These extensions provide named getters
///    and setters that encapsulate the map access and type casting.
///
///    {@tool snippet}
///    **Example: Using Extension Methods**
///
///    ```dart
///    // 1. Define keys (as before)
///    const Symbol startTimeKey = #startTime;
///    const Symbol isValidKey = #isValid;
///
///    // 2. Define extension methods (e.g., in context_extensions.dart)
///    import 'package:kyron/kyron.dart'; // Import the library's context
///    // import 'context_keys.dart'; // Assuming keys are defined here
///
///    extension PipelineContextExtensions on PipelineContext {
///      // Getter and Setter for startTime
///      DateTime? get startTime => items[startTimeKey] as DateTime?;
///      set startTime(DateTime? value) => items[startTimeKey] = value;
///
///      // Getter and Setter for isValid
///      bool? get isValid => items[isValidKey] as bool?;
///      set isValid(bool? value) => items[isValidKey] = value;
///    }
///
///    // 3. Use the extensions in Behaviors/Handlers
///    // (Import the file containing the extension methods)
///    // import 'context_extensions.dart';
///
///    // In a Timer Behavior:
///    class TimerBehavior extends PipelineBehavior<BaseRequest, dynamic> {
///       @override Future handle(request, context, next) async {
///         context.startTime = DateTime.now(); // Use extension setter (type-safe)
///         print('TimerBehavior: Set start time.');
///         // ... call next() ...
///       }
///       @override int get order => 0;
///    }
///
///    // In a Logging Behavior:
///    class LoggingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
///       @override Future handle(request, context, next) async {
///         // ... call next() ...
///         final start = context.startTime; // Use extension getter (type-safe)
///         final valid = context.isValid;   // Use extension getter (type-safe)
///         if (start != null) {
///           print('LoggingBehavior: Request started at $start.');
///         }
///         print('LoggingBehavior: Request validity was ${valid ?? 'not set'}.');
///       }
///        @override int get order => 10;
///    }
///    ```
///    * **Pros:** Compile-time type safety, improved readability, encapsulates map access logic,
///      reduces risk of key typos and casting errors.
///    * **Cons:** Requires defining extension methods (a one-time setup per property).
///    {@end-tool}
///
/// Consumers of the library generally **do not** create instances of [PipelineContext]
/// directly; they receive it as a parameter in their behavior or handler [handle] methods.
final class PipelineContext {
  /// A general-purpose property bag for behaviors and handlers to store and retrieve
  /// custom data associated with the current request pipeline.
  ///
  /// Use unique keys (preferably [Symbol]s or constants defined by the consumer/behavior)
  /// to avoid collisions. Accessing data requires type casting. Consider using
  /// **extension methods** on [PipelineContext] for type-safe access (see class documentation).
  final Map<Object, Object?> items = {};

  /// A simple correlation identifier for tracing a single request through logs.
  /// Inherited from the request's hash code by default in [Kyron].
  final int correlationId;

  /// Constructor used internally by the Kyron library's Mediator.
  /// Consumers generally don't need to call this directly.
  PipelineContext(this.correlationId);
}
