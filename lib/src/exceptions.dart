// lib/src/exceptions.dart

/// Thrown when attempting to send a request for which no handler has been registered.
class UnregisteredHandlerException implements Exception {
  final Type requestType;
  const UnregisteredHandlerException(this.requestType);
  @override
  String toString() =>
      'UnregisteredHandlerException: No handler registered for $requestType';
}

/// Thrown when there is an issue with the mediator's configuration,
/// such as failing to instantiate a behavior or handler factory.
class MediatorConfigurationException implements Exception {
  final String message;
  const MediatorConfigurationException(this.message);
  @override
  String toString() => 'MediatorConfigurationException: $message';
}

/// Wraps an unexpected error that occurred within a pipeline behavior or request handler
/// during execution, providing context about the originating component and request.
///
/// This exception is thrown by the Kyron pipeline executor when an underlying
/// behavior or handler throws an exception that is not a [ShortCircuitException].
/// It helps distinguish internal pipeline execution failures from controlled
/// short-circuiting or configuration issues.
class PipelineExecutionException implements Exception {
  /// The original exception thrown by the handler or behavior.
  final Object innerException;

  /// The stack trace associated with the [innerException].
  final StackTrace innerStackTrace;

  /// The runtime type of the specific [RequestHandler] or [PipelineBehavior]
  /// where the original exception occurred. Helps pinpoint the source of the error.
  final Type originatingComponentType;

  /// The runtime type of the [Request] or [StreamRequest] being processed
  /// when the exception occurred.
  final Type requestType;

  /// The correlation identifier associated with the specific request invocation,
  /// useful for tracing logs.
  final int correlationId;

  PipelineExecutionException(
    this.innerException,
    this.innerStackTrace,
    this.originatingComponentType,
    this.requestType,
    this.correlationId,
  );

  @override
  String toString() {
    return 'PipelineExecutionException: Exception [$innerException] occurred in component [$originatingComponentType] while processing request type [$requestType] with correlationId [$correlationId].\nInner stack trace:\n$innerStackTrace';
  }
}

/// Base class for exceptions used to signal **intentional, non-error** short-circuiting
/// of the request pipeline by a [PipelineBehavior].
///
/// **Purpose:**
/// This exception type allows a behavior (e.g., validation, caching, authorization)
/// to stop the processing of subsequent behaviors and the main request handler in a
/// controlled and predictable way. It distinguishes these controlled flow interruptions
/// from unexpected runtime errors (which should throw standard Exceptions or be wrapped
/// in [PipelineExecutionException]).
///
/// **Usage:**
/// Consumers implementing custom [PipelineBehavior]s should define their own specific
/// exception classes that **extend** [ShortCircuitException]. Throwing an instance of
/// such a derived exception from within a behavior's [handle] method will stop the
/// pipeline execution for that request.
///
/// **Using Generics ([<TData>]):**
/// The optional generic type parameter [TData] allows derived exceptions to carry
/// specific, type-safe data related to the short-circuit reason (e.g., validation
/// errors, cached data, authorization details). This data can then be accessed
/// type-safely in the corresponding [catch] block where [Kyron.send] or [Kyron.stream]
/// was called. If no specific data is needed, use [ShortCircuitException<void>] or
/// simply derive from [ShortCircuitException] directly (which defaults [TData] to [dynamic]).
///
/// **Example Custom Derived Exceptions:**
/// ```dart
/// // In user code:
///
/// // Carries validation errors
/// class MyValidationFailureException extends ShortCircuitException<Map<String, String>> {
///   MyValidationFailureException(Map<String, String> errors) : super(errors);
///   Map<String, String> get errors => data; // data is now typed
/// }
///
/// // Carries authorization details
/// class MyAuthorizationDeniedException extends ShortCircuitException<String> {
///   MyAuthorizationDeniedException(String reason) : super(reason);
///   String get reason => data; // data is now typed
/// }
///
/// // Carries a cached result (generic cache exception)
/// class MyCacheHitException<TCached> extends ShortCircuitException<TCached> {
///   MyCacheHitException(TCached cachedData) : super(cachedData);
///   TCached get cachedData => data; // data is now typed
/// }
///
/// // No specific data needed, just signals an event
/// class MyOperationCancelledException extends ShortCircuitException<void> {
///   MyOperationCancelledException() : super(null);
/// }
/// ```
///
/// **Catching Derived Exceptions:**
/// The application code calling [Kyron.send] or [Kyron.stream] can then use specific
/// [catch] blocks for these custom derived exceptions:
/// ```dart
/// try {
///   final result = await kyron.send(MyRequest());
/// } on MyValidationFailureException catch (e) {
///   print("Validation failed: ${e.errors}");
///   // Handle validation failure...
/// } on MyAuthorizationDeniedException catch (e) {
///   print("Authorization denied: ${e.reason}");
///   // Handle authorization failure...
/// } on MyCacheHitException<MyExpectedType> catch (e) { // Can specify type here too
///  print("Cache hit: ${e.cachedData}");
///  // Use cached data...
/// } on PipelineExecutionException catch (e) {
///  print("An unexpected error occurred in the pipeline: ${e.innerException}");
///  // Log and handle unexpected failures...
/// } catch (e) {
///   print("An unknown error occurred: $e");
///   // Catch any other errors...
/// }
/// ```
abstract class ShortCircuitException<TData> implements Exception {
  /// Optional data associated with the short-circuit event.
  /// Its type is determined by the generic parameter `TData`.
  final TData data;
  const ShortCircuitException(this.data);
}

/// Thrown by [Kyron.publish] when the configured [NotificationErrorStrategy]
/// is [collectErrors] and one or more notification handlers encounter errors
/// during dispatch.
class AggregateException implements Exception {
  /// A read-only list of the exceptions caught from individual notification handlers.
  final List<Object> innerExceptions;

  AggregateException(List<Object> exceptions)
    : innerExceptions = List.unmodifiable(exceptions);

  @override
  String toString() {
    final buffer = StringBuffer('AggregateException: ')..writeln(
      '${innerExceptions.length} exceptions occurred during notification dispatch:',
    );
    for (int i = 0; i < innerExceptions.length; i++) {
      buffer.writeln('  ${i + 1}: ${innerExceptions[i]}');
      // Optionally include stack traces if captured and stored
    }
    return buffer.toString();
  }
}
