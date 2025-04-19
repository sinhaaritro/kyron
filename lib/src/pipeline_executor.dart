// lib/src/pipeline_executor.dart

import 'dart:async';

import 'package:logging/logging.dart';

import 'exceptions.dart';
import 'pipeline_behavior.dart';
import 'pipeline_context.dart';
import 'registry.dart';
import 'request.dart';
import 'request_handler.dart';

typedef _StreamPipelineDelegate<T> = Future<Stream<T>> Function();

/// Responsible for orchestrating and executing the request processing pipeline,
/// which consists of registered [PipelineBehavior]s followed by the core
/// [RequestHandler] or [StreamRequestHandler].
///
/// This class takes the components relevant to a specific request (retrieved from
/// the [KyronRegistry] by [Kyron]) and manages the flow of control through them.
///
/// **Key Responsibilities:**
///   - **Behavior Instantiation:** Takes the applicable [BehaviorRegistration]s,
///     sorts them according to their specified order, and invokes their factories
///     to create the actual [PipelineBehavior] instances for the current request.
///     Handles errors during instantiation.
///   - **Pipeline Construction:** Builds the execution chain (delegate chain).
///     - For standard [Request]s ([buildPipelineDelegate]): Creates a nested structure
///       of [RequestHandlerDelegate] functions where each behavior wraps the call to
///       the [next] delegate, ultimately culminating in the execution of the core
///       [RequestHandler].
///     - For [StreamRequest]s ([buildStreamPipelineDelegate]): Builds a similar chain
///       for the *setup phase* (behaviors run before the stream is returned). This
///       chain results in a [Future<Stream<TResponse>>]. It returns a function that,
///       when called, executes this setup phase asynchronously and returns the
///       resulting [Stream].
///   - **Pipeline Execution:** Provides methods to invoke the constructed pipeline.
///     - [executeFuture]: Executes the delegate chain for a standard [Request],
///       returning the [Future<TResponse>] from the handler (or a behavior that
///       short-circuited).
///     - [executeStream]: Executes the setup function for a [StreamRequest],
///       handling the asynchronous setup and returning the [Stream<TResponse>]
///       that will eventually receive data from the [StreamRequestHandler].
///   - **Error Handling:** Manages exceptions that occur during behavior/handler
///     instantiation or execution, typically allowing them to propagate up to the
///     caller of [Kyron.send] or [Kyron.stream].
///
/// **Default Implementation:**
/// This [PipelineExecutor] class provides the default pipeline execution logic used
/// by [Kyron] if no custom executor is provided. It implements the standard
/// "onion layer" middleware pattern where behaviors wrap inner behaviors and the handler.
///
/// **Customization:**
/// An application could provide its own implementation of a pipeline executor to the
/// [Kyron] constructor to implement different execution strategies (e.g., alternative
/// ways of handling async flow, different error management within the pipeline,
/// or integrating specific context propagation mechanisms).
class PipelineExecutor {
  static final _log = Logger('Kyron.PipelineExecutor');

  /// Sorts applicable behavior registrations and instantiates the behaviors.
  /// Logs and throws MediatorConfigurationException on factory errors.
  List<PipelineBehavior> instantiateBehaviors(
    BaseRequest request,
    List<BehaviorRegistration> applicableRegistrations,
    int correlationId,
  ) {
    // Sorting is now handled by the caller (Kyron.send/stream)

    final List<PipelineBehavior> behaviors = [];
    for (final reg in applicableRegistrations) {
      try {
        final behaviorInstanceUntyped = reg.factory();

        // Ensure the factory returns a valid PipelineBehavior
        if (behaviorInstanceUntyped is! PipelineBehavior) {
          throw MediatorConfigurationException(
            'Behavior factory for registration "${reg.description}" did not return an instance of PipelineBehavior for request type ${request.runtimeType} [$correlationId]. Returned type: ${behaviorInstanceUntyped.runtimeType}',
          );
        }

        final behaviorInstance = behaviorInstanceUntyped;
        _log.finer(
          'Instantiated behavior: ${behaviorInstance.runtimeType} (Order: ${reg.order}, Applies Via: "${reg.description}") for request [$correlationId].',
        );
        behaviors.add(behaviorInstance);
      } catch (e, s) {
        _log.severe(
          'Error instantiating behavior from factory for registration "${reg.description}" for request [$correlationId]. Error: $e',
          e,
          s,
        );
        // Wrap in configuration exception to provide context
        if (e is MediatorConfigurationException) {
          rethrow;
        } else {
          throw MediatorConfigurationException(
            'Failed to instantiate behavior for request type ${request.runtimeType} [$correlationId] matching registration "${reg.description}". Inner Error: $e',
          );
        }
      }
    }
    _log.fine(
      'Instantiated ${behaviors.length} behaviors successfully for request ${request.runtimeType} [$correlationId].',
    );
    return behaviors;
  }

  /// Builds the delegate chain for a [Request] expecting a single [Future] response.
  /// Wraps behavior/handler execution with error handling and logging.
  RequestHandlerDelegate<TResponse> buildPipelineDelegate<TResponse>(
    RequestHandler<Request<TResponse>, TResponse> handler,
    List<PipelineBehavior> behaviors,
    Request<TResponse> request,
    PipelineContext context,
    int correlationId,
  ) {
    final requestType = request.runtimeType;

    // Innermost action: execute the Future-returning handler
    Future<TResponse> nextCoreAction() async {
      final handlerType = handler.runtimeType;
      _log.finer(
        'Executing core handler: $handlerType for request [$correlationId]',
      );
      try {
        // Ensure correct types are passed. The cast to dynamic might be unnecessary
        // if types align perfectly, but can prevent compiler errors if variance issues arise.
        final result =
            await (handler as dynamic).handle(request, context) as TResponse;
        _log.finer(
          'Core handler $handlerType completed for request [$correlationId]',
        );
        // Ensure response type matches TResponse
        return result;
      } catch (e, s) {
        _log.severe(
          'Error executing handler $handlerType for request [$correlationId]: $e',
          e,
          s,
        );
        // Wrap and rethrow with context
        throw PipelineExecutionException(
          e,
          s,
          handlerType,
          requestType,
          correlationId,
        );
      }
    }

    // Assign initial delegate
    RequestHandlerDelegate<TResponse> next = nextCoreAction;

    // Wrap with behaviors
    for (final behavior in behaviors.reversed) {
      final currentNext = next;
      final behaviorType = behavior.runtimeType;
      // Define the wrapping function
      Future<TResponse> wrappedAction() async {
        _log.finer(
          'Executing behavior: $behaviorType (Order: ${behavior.order}) for request [$correlationId]',
        );
        try {
          // Dynamic dispatch for behavior handle.
          // Ensure TRequest/TResponse match within the behavior implementation.
          final resultFuture =
              (behavior as dynamic).handle(request, context, currentNext)
                  as Future; // Cast to Future needed

          final resultValue = await resultFuture as TResponse;
          _log.finer(
            'Behavior $behaviorType completed for request [$correlationId]',
          );
          // Ensure behavior result type matches TResponse
          return resultValue;
        } catch (e, s) {
          // Check if it's a known short-circuit exception, log differently
          if (e is ShortCircuitException) {
            _log.info(
              'Behavior $behaviorType short-circuited request $requestType [$correlationId] with ${e.runtimeType}.',
              e, // Log the exception itself which might have useful data/toString()
              // s, // Stack trace usually not needed for intentional short-circuit
            );
            rethrow; // Rethrow directly, do not wrap
          } else if (e is PipelineExecutionException) {
            // If already wrapped (e.g., error in deeper 'next()' call), just rethrow
            _log.warning(
              'Rethrowing already wrapped exception from behavior $behaviorType for request $requestType [$correlationId]. Original source: ${e.originatingComponentType}',
              e,
              s, // Log stacktrace here as it might be the first point it surfaces
            );
            rethrow;
          } else {
            // This is an unexpected error originating *directly* in this behavior's code
            _log.severe(
              'Error executing behavior $behaviorType for request $requestType [$correlationId]. Error: $e',
              e,
              s,
            );
            // Wrap with context
            throw PipelineExecutionException(
              e,
              s,
              behaviorType,
              requestType,
              correlationId,
            );
          }
        }
      }

      // Update next to the new wrapper
      next = wrappedAction;
    }
    _log.fine(
      'Built pipeline delegate chain for Future response [$correlationId].',
    );
    return next;
  }

  /// Builds the delegate chain for a [StreamRequest].
  /// Returns a function that, when called, executes the setup pipeline (behaviors)
  /// and returns the handler's stream, managing errors during setup.
  Stream<TResponse> Function() buildStreamPipelineDelegate<TResponse>(
    StreamRequestHandler<StreamRequest<TResponse>, TResponse> handler,
    List<PipelineBehavior> behaviors,
    StreamRequest<TResponse> request,
    PipelineContext context,
    int correlationId,
  ) {
    final requestType = request.runtimeType;

    // Define the innermost async action that gets the stream from the handler
    Future<Stream<TResponse>> getStreamFromHandler() async {
      final handlerType = handler.runtimeType;
      _log.finer(
        'Executing core stream handler wrapper: $handlerType for request [$correlationId]',
      );
      try {
        // Dynamic dispatch, result needs casting
        final stream = (handler as dynamic).handle(request, context) as Stream;
        _log.finer(
          'Core stream handler $handlerType returned stream for request [$correlationId]',
        );
        return stream.cast<TResponse>();
      } catch (e, s) {
        _log.severe(
          'Error executing stream handler $handlerType for request [$correlationId]: $e',
          e,
          s,
        );
        throw PipelineExecutionException(
          e,
          s,
          handlerType,
          requestType,
          correlationId,
        );
      }
    }

    // Build the delegate chain for the setup phase (returns Future<Stream>)
    // Use the top-level typedef _StreamPipelineDelegate
    _StreamPipelineDelegate<TResponse> nextSetupAction = getStreamFromHandler;

    // Wrap with behaviors using the Future<Stream> delegate
    for (final behavior in behaviors.reversed) {
      final currentAsyncNext = nextSetupAction;
      final behaviorType = behavior.runtimeType;

      // Define the wrapping setup function
      Future<Stream<TResponse>> wrappedSetupAction() async {
        _log.finer(
          'Executing behavior: $behaviorType (Order: ${behavior.order}) for Stream Setup [$correlationId]',
        );
        try {
          // Behavior's handle conceptually returns Future<Stream<TResponse>> here
          final resultFuture =
              (behavior as dynamic).handle(request, context, currentAsyncNext)
                  as Future;
          final resultValue = await resultFuture;

          if (resultValue is! Stream) {
            // This indicates a programming error in the behavior implementation
            _log.severe(
              'Behavior $behaviorType did not return a Stream when handling StreamRequest setup for $requestType [$correlationId]. Returned: ${resultValue?.runtimeType}',
            );
            throw PipelineExecutionException(
              MediatorConfigurationException(
                // Use a specific exception type
                'Behavior $behaviorType incorrectly returned type ${resultValue?.runtimeType} instead of a Stream during StreamRequest setup.',
              ),
              StackTrace.current,
              behaviorType,
              requestType,
              correlationId,
            );
          }

          _log.finer(
            'Behavior $behaviorType completed for Stream Setup [$correlationId]',
          );
          return (resultValue).cast<TResponse>();
        } catch (e, s) {
          if (e is ShortCircuitException) {
            _log.fine(
              'Behavior $behaviorType short-circuited stream setup [$correlationId] with ${e.runtimeType}.',
              e,
            );
            // TODO: How to handle? Maybe return Stream.error or Stream.value(e.data)? Depends on exception type.
            // For now, rethrow and let the setup fail.
            rethrow;
          } else if (e is PipelineExecutionException) {
            _log.warning(
              'Rethrowing already wrapped exception from behavior $behaviorType during stream setup for $requestType [$correlationId]. Original source: ${e.originatingComponentType}',
              e,
              s,
            );
            rethrow;
          } else {
            _log.severe(
              'Error executing behavior $behaviorType during stream setup for $requestType [$correlationId]: $e',
              e,
              s,
            );
            throw PipelineExecutionException(
              e,
              s,
              behaviorType,
              requestType,
              correlationId,
            );
          }
        }
      }

      // Update the setup action delegate
      nextSetupAction = wrappedSetupAction;
    }

    // Return the final function that executes the setup and returns the stream
    return () {
      // Use StreamController to bridge the async setup and the sync stream return
      // Make it synchronous: false so it doesn't deliver events immediately within the setup phase
      final streamController = StreamController<TResponse>(sync: false);

      // Execute the async setup pipeline
      Future<void> runSetup() async {
        try {
          _log.fine(
            'Starting async setup for stream request [$correlationId]...',
          );
          final sourceStream = await nextSetupAction();
          _log.fine(
            'Async setup complete for $requestType [$correlationId], piping source stream.',
          );

          // Once the setup is done and we have the stream, forward events
          // Use addStream to handle completion and errors from the source stream
          await streamController.addStream(sourceStream, cancelOnError: true);

          // Close our controller when the source stream is done (handled by addStream)
          if (!streamController.isClosed) {
            await streamController.close();
          }
          _log.fine(
            'Source stream piping finished for $requestType [$correlationId].',
          );
        } catch (e, s) {
          _log.severe(
            'Async setup failed for stream request [$correlationId]. Adding error to stream.',
            e,
            s,
          );
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            // Close after adding error if not already closed by addStream
            await streamController.close();
          }
        }
      }

      // Start the async setup without awaiting here
      runSetup();

      _log.fine(
        'Built pipeline delegate chain for Stream response [$correlationId]. Returning controller stream.',
      );
      // Return the controller's stream immediately. Events will flow once setup completes.
      return streamController.stream;
    };
  }

  /// Executes the fully constructed pipeline delegate for a [Future] response.
  /// Logs final success/failure.
  Future<TResponse> executeFuture<TResponse>(
    RequestHandlerDelegate<TResponse> pipelineDelegate,
    int correlationId,
    Type requestType,
  ) async {
    try {
      _log.fine('Starting pipeline execution for Future [$correlationId]...');
      final result = await pipelineDelegate();
      _log.fine(
        'Pipeline execution completed successfully for Future [$correlationId].',
      );
      return result;
    } catch (e, s) {
      // Logging is handled deeper where exceptions are caught/wrapped.
      // Log final failure outcome here.
      if (e is ShortCircuitException) {
        // Already logged where it occurred
        _log.info(
          'Pipeline execution short-circuited for Future request $requestType [$correlationId] by ${e.runtimeType}.',
        );
      } else {
        _log.severe(
          'Pipeline execution failed for Future request $requestType [$correlationId].',
          e,
          s,
        );
      }
      rethrow;
    }
  }

  /// Executes the fully constructed pipeline delegate for a [Stream] response.
  /// Logs initiation and catches synchronous builder errors.
  ///
  /// [pipelineDelegateBuilder] Function that returns the stream
  Stream<TResponse> executeStream<TResponse>(
    Stream<TResponse> Function() pipelineDelegateBuilder,
    int correlationId,
    Type requestType,
  ) {
    try {
      _log.fine(
        'Initiating pipeline execution for Stream request $requestType [$correlationId]...',
      );
      // Call the builder, which runs the async setup and returns the stream
      final stream = pipelineDelegateBuilder();
      _log.fine(
        'Pipeline execution initiated for Stream request $requestType [$correlationId]. Returning stream.',
      );
      return stream;
    } catch (e, s) {
      // Catch synchronous errors during the builder function itself, before async setup starts
      _log.severe(
        'Synchronous error during pipeline execution setup for Stream request $requestType [$correlationId]. Error: $e',
        e,
        s,
      );
      // Return an error stream immediately
      return Stream.error(e, s);
    }
  }
}
