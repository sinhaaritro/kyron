// lib/src/request_handler.dart

import 'dart:async';

import 'pipeline_context.dart';
import 'request.dart';

/// Defines the contract for a handler that processes a specific [Request]
/// expecting a single asynchronous response.
abstract class RequestHandler<TRequest extends Request<TResponse>, TResponse> {
  /// Handles the incoming request asynchronously.
  ///
  /// - [request]: The specific request object to be processed.
  /// - [context]: The shared context for this specific request pipeline execution.
  /// - Returns: A [Future] containing the single response.
  Future<TResponse> handle(TRequest request, PipelineContext context);
}

/// Defines the contract for a handler that processes a specific [StreamRequest]
/// expecting multiple responses over time via a [Stream].
abstract class StreamRequestHandler<
  TRequest extends StreamRequest<TResponse>,
  TResponse
> {
  /// Handles the incoming stream request.
  ///
  /// - [request]: The specific stream request object to be processed.
  /// - [context]: The shared context for this specific request pipeline execution.
  /// - Returns: A [Stream] emitting response items.
  Stream<TResponse> handle(TRequest request, PipelineContext context);
}
