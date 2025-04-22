// lib/src/kyron_interface.dart

import 'dart:async';

import 'package:kyron/src/pipeline_component_info.dart';

import 'request.dart';

/// Defines the contract for the Mediator.
abstract class KyronInterface {
  /// Sends a request object expecting a single response through the
  /// registered pipeline behaviors (if any) to its corresponding handler.
  ///
  /// - [request]: The request object implementing [Request<TResponse>].
  /// - Returns: A Future containing the response object [TResponse].
  Future<TResponse> send<TResponse>(Request<TResponse> request);

  /// Sends a request object expecting a stream of responses through the
  /// registered pipeline behaviors (if any) to its corresponding handler.
  ///
  /// - [request]: The request object implementing [StreamRequest<TResponse>].
  /// - Returns: A Stream emitting response objects [TResponse].
  Stream<TResponse> stream<TResponse>(StreamRequest<TResponse> request);

  /// Publishes an event/message object to all registered handlers for that
  /// specific object type. Execution order depends on registration order
  /// (if specified) and the dispatcher implementation.
  ///
  /// - [notification]: The event/message object of type [TNotification] to publish.
  /// - Returns: A Future that completes when all handlers have been invoked
  ///   (subject to the configured error strategy).
  Future<void> publish<TNotification>(TNotification notification);

  /// Calculates the planned execution pipeline for a given request,
  /// showing the sequence of behaviors and the final handler.
  /// Useful for debugging registration and ordering.
  /// Note: May involve temporary instantiation and carries performance overhead.
  List<PipelineComponentInfo> getPipelinePlan<TResponse>(
    Request<TResponse> request,
  );
}
