// lib/src/pipeline_behavior.dart

import 'dart:async';

import 'pipeline_context.dart';
import 'request.dart';

/// Represents the next action in the pipeline (invokes the next behavior or the handler).
typedef RequestHandlerDelegate<TResponse> = Future<TResponse> Function();

/// Defines the contract for a pipeline behavior (middleware).
/// Implementations handle cross-cutting concerns.
abstract class PipelineBehavior<TRequest extends BaseRequest, TResponse> {
  /// Optional: The order in which this behavior should execute relative to others.
  /// Lower numbers execute earlier. Defaults to 0 if not overridden.
  int get order => 0;

  /// Processes the request, potentially performing actions before and/or
  /// after invoking the next step in the pipeline via the [next] delegate.
  Future<TResponse> handle(
    TRequest request,
    PipelineContext context,
    RequestHandlerDelegate<TResponse> next,
  );
}
