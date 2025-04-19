// lib/src/notification_handler.dart

import 'dart:async';

import 'notification.dart';

/// Defines the contract for a handler that processes a specific [Notification].
/// Multiple handlers can be registered for the same notification type.
/// Handlers perform actions in response to notifications but do not return data
/// back to the publisher through the mediator.
abstract class NotificationHandler<TNotification extends Notification> {
  /// Handles the incoming notification message asynchronously.
  ///
  /// - [notification]: The specific notification object to be processed.
  /// - Returns: A [Future] that completes when the handling logic is finished.
  Future<void> handle(TNotification notification);
}
