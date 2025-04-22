// lib/src/notification_handler.dart

import 'dart:async';

/// Defines the contract for a handler that processes a specific message/event object [TNotification].
/// Multiple handlers can be registered for the same object type.
/// Handlers perform actions in response to published messages/events but do not return data
/// back to the publisher through the mediator.
abstract class NotificationHandler<TNotification> {
  /// Handles the incoming message/event object asynchronously.
  ///
  /// - [notification]: The specific message/event object to be processed.
  /// - Returns: A [Future] that completes when the handling logic is finished.
  Future<void> handle(TNotification notification);
}
