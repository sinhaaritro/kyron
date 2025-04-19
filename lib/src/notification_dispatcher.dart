// lib/src/notification_dispatcher.dart

import 'dart:async';

import 'package:kyron/src/notification_order.dart';
import 'package:logging/logging.dart';

import 'exceptions.dart';
import 'notification.dart';
import 'notification_handler.dart';
import 'registry.dart';

/// Defines strategies for handling errors occurring within [NotificationHandler]s
/// during the dispatch process initiated by [Kyron.publish].
enum NotificationErrorStrategy {
  /// If a handler throws an exception, log the error and continue
  /// executing the remaining registered handlers for the notification.
  /// This is the default behavior.
  continueOnError,

  /// If a handler throws an exception, log the error and collect it. Continue
  /// executing remaining handlers. If any errors were collected after all
  /// handlers have been attempted, throw an [AggregateException] containing
  /// all collected errors.
  collectErrors,

  /// (Optional - Could be added) If a handler throws an exception, log the error
  /// and immediately stop processing further handlers for that notification,
  /// rethrowing the original exception (potentially wrapped).
  // failFast,
}

/// Responsible for dispatching a single [Notification] event to all of its
/// registered [NotificationHandler]s according to a specified error handling strategy.
///
/// Used internally by [Kyron].
class NotificationDispatcher {
  static final _log = Logger('Kyron.NotificationDispatcher');

  final NotificationErrorStrategy errorStrategy;

  /// Creates a NotificationDispatcher.
  ///
  /// - [errorStrategy]: Determines how errors from individual handlers are managed.
  ///   Defaults to [NotificationErrorStrategy.continueOnError].
  NotificationDispatcher({
    this.errorStrategy = NotificationErrorStrategy.continueOnError,
  });

  /// Dispatches a notification to registered handlers, supporting mixed parallel
  /// and sequential execution based on the handler's registered order.
  /// Handles errors based on the configured [errorStrategy].
  ///
  /// Execution Phases:
  /// 1. Early Parallel: Handlers with order [NotificationOrder.parallelEarly].
  /// 2. Sequential: Handlers with specific integer orders (excluding early/late parallel).
  /// 3. Late Parallel: Handlers with order [NotificationOrder.parallelLate].
  ///
  /// - [notification]: The notification object to dispatch.
  /// - [handlerRegistrations]: The list of ALL handler registrations for the notification type.
  /// - [correlationId]: An identifier for tracing (optional, used for logging).
  Future<void> dispatch(
    Notification notification,
    List<NotificationHandlerRegistration> handlerRegistrations, {
    int? correlationId,
  }) async {
    final notificationType = notification.runtimeType;
    final List<Object> collectedErrors = [];
    // Use hashCode if specific correlationId isn't provided for notifications
    final effectiveCorrelationId = correlationId ?? notification.hashCode;

    if (handlerRegistrations.isEmpty) {
      _log.finer(
        'No handler registrations found for $notificationType [$effectiveCorrelationId].',
      );
      return;
    }

    _log.info(
      'Dispatching notification $notificationType [$effectiveCorrelationId] to ${handlerRegistrations.length} handlers (Strategy: ${errorStrategy.name}).',
    );

    // 1. Partition Handlers
    final List<NotificationHandlerRegistration> earlyParallel = [];
    final List<NotificationHandlerRegistration> sequential = [];
    final List<NotificationHandlerRegistration> lateParallel = [];

    for (final reg in handlerRegistrations) {
      if (reg.order == NotificationOrder.parallelEarly) {
        earlyParallel.add(reg);
      } else if (reg.order == NotificationOrder.parallelLate) {
        lateParallel.add(reg);
      } else {
        sequential.add(reg);
      }
    }
    _log.fine(
      'Partitioned handlers for $notificationType [$effectiveCorrelationId]: Early Parallel (${earlyParallel.length}), Sequential (${sequential.length}), Late Parallel (${lateParallel.length}).',
    );

    // 2. Sort Sequential Handlers
    // Sequential list is already sorted as it's derived from the pre-sorted list passed by Kyron.

    // Execution Phases

    bool stopDispatch = false; // Needed if failFast strategy is added

    // Phase 1: Early Parallel Execution
    if (!stopDispatch && earlyParallel.isNotEmpty) {
      _log.finer(
        'Executing Early Parallel phase for $notificationType [$effectiveCorrelationId] (${earlyParallel.length} handlers).',
      );
      await _executeParallelBatch(
        earlyParallel,
        notification,
        effectiveCorrelationId,
        collectedErrors,
        'Early Parallel', // Phase name for logging
      );
      _log.finer(
        'Completed Early Parallel phase for $notificationType [$effectiveCorrelationId].',
      );
    }

    // Phase 2: Sequential Execution
    if (!stopDispatch && sequential.isNotEmpty) {
      _log.finer(
        'Executing Sequential phase for $notificationType [$effectiveCorrelationId] (${sequential.length} handlers).',
      );
      stopDispatch = await _executeSequentialBatch(
        // Update stopDispatch if failFast
        sequential,
        notification,
        effectiveCorrelationId,
        collectedErrors,
      );
      _log.finer(
        'Completed Sequential phase for $notificationType [$effectiveCorrelationId].',
      );
    }

    // Phase 3: Late Parallel Execution
    if (!stopDispatch && lateParallel.isNotEmpty) {
      _log.finer(
        'Executing Late Parallel phase for $notificationType [$effectiveCorrelationId] (${lateParallel.length} handlers).',
      );
      await _executeParallelBatch(
        lateParallel,
        notification,
        effectiveCorrelationId,
        collectedErrors,
        'Late Parallel', // Phase name for logging
      );
      _log.finer(
        'Completed Late Parallel phase for $notificationType [$effectiveCorrelationId].',
      );
    }

    // --- Final Error Handling ---
    if (errorStrategy == NotificationErrorStrategy.collectErrors &&
        collectedErrors.isNotEmpty) {
      _log.severe(
        'Finished dispatching notification $notificationType [$effectiveCorrelationId] with ${collectedErrors.length} errors. Throwing AggregateException.',
      );
      throw AggregateException(collectedErrors);
    }

    _log.info(
      'Finished dispatching notification $notificationType [$effectiveCorrelationId]. Errors collected: ${collectedErrors.length} (Strategy: ${errorStrategy.name}).',
    );
  }

  /// Executes a batch of notification handlers in parallel using Future.wait.
  Future<void> _executeParallelBatch(
    List<NotificationHandlerRegistration> batchRegistrations,
    Notification notification,
    int correlationId,
    List<Object> collectedErrors,
    String phaseName,
  ) async {
    final notificationType = notification.runtimeType;
    final List<Future> futures = [];

    for (final registration in batchRegistrations) {
      NotificationHandler? handlerInstance;
      try {
        handlerInstance = registration.factory() as NotificationHandler;
        final handlerType = handlerInstance.runtimeType;

        _log.finest(
          '[$phaseName] Kicking off handler: $handlerType for $notificationType [$correlationId]',
        );

        // Call handle() and get the Future
        final future =
            (handlerInstance as dynamic).handle(notification) as Future;

        // Wrap the future based on error strategy BEFORE adding to list
        final wrappedFuture = future.catchError((e, s) {
          final handlerTypeName = handlerInstance?.runtimeType ?? 'Unknown';
          _log.warning(
            '[$phaseName] Handler $handlerTypeName for $notificationType [$correlationId] failed. Error: $e',
            e,
            s,
          );
          if (errorStrategy == NotificationErrorStrategy.collectErrors) {
            // Collect the error for later aggregation
            collectedErrors.add(e);
          }
          // For both continueOnError and collectErrors, we return normally
          // from catchError so Future.wait doesn't fail immediately.
          // Return null or a marker if needed, but returning void is fine here.
        });

        futures.add(wrappedFuture);
      } catch (e, s) {
        // Catch errors during instantiation or initial call (less likely)
        final handlerTypeName =
            handlerInstance?.runtimeType ?? 'Unknown (Instantiation Failed)';
        _log.severe(
          '[$phaseName] Error preparing handler $handlerTypeName for $notificationType [$correlationId]. Error: $e',
          e,
          s,
        );
        if (errorStrategy == NotificationErrorStrategy.collectErrors) {
          collectedErrors.add(e);
        }
        // Don't add a future if instantiation failed.
      }
    }

    // Wait for all wrapped futures to complete
    if (futures.isNotEmpty) {
      try {
        await Future.wait(futures);
        _log.finest(
          '[$phaseName] Future.wait completed for $notificationType [$correlationId]',
        );
      } catch (e, s) {
        // This catch block should ideally not be hit often because individual
        // errors are handled by catchError above. However, Future.wait itself
        // could potentially throw under rare circumstances.
        _log.severe(
          '[$phaseName] Unexpected error during Future.wait for $notificationType [$correlationId]. This might indicate an issue in error wrapping. Error: $e',
          e,
          s,
        );
        if (errorStrategy == NotificationErrorStrategy.collectErrors) {
          // Add the Future.wait error itself if it happens
          collectedErrors.add(e);
        }
      }
    }
  }

  /// Executes a batch of notification handlers sequentially, respecting their order.
  /// Returns true if dispatch should stop (e.g., for failFast), false otherwise.
  Future<bool> _executeSequentialBatch(
    List<NotificationHandlerRegistration> batchRegistrations, // Assumed sorted
    Notification notification,
    int correlationId,
    List<Object> collectedErrors,
  ) async {
    final notificationType = notification.runtimeType;

    for (final registration in batchRegistrations) {
      NotificationHandler? handlerInstance;
      Type handlerType = dynamic;
      final order = registration.order;

      try {
        handlerInstance = registration.factory() as NotificationHandler;
        handlerType = handlerInstance.runtimeType;
        _log.finest(
          '[Sequential] Executing handler: $handlerType (Order: $order) for $notificationType [$correlationId]',
        );

        // Await the handler directly
        await (handlerInstance as dynamic).handle(notification);

        _log.finest(
          '[Sequential] Finished handler: $handlerType (Order: $order) for $notificationType [$correlationId]',
        );
      } catch (e, s) {
        final handlerTypeName =
            handlerInstance?.runtimeType ?? 'Unknown (Instantiation Failed)';
        switch (errorStrategy) {
          case NotificationErrorStrategy.collectErrors:
            _log.warning(
              '[Sequential] Error executing handler $handlerTypeName (Order: $order) for $notificationType [$correlationId]. Collecting error. Error: $e',
              e,
              s,
            );
            collectedErrors.add(e);
            break;
          case NotificationErrorStrategy.continueOnError:
            _log.severe(
              '[Sequential] Error executing handler $handlerTypeName (Order: $order) for $notificationType [$correlationId]. Continuing dispatch. Error: $e',
              e,
              s,
            );
            break;
          // case NotificationErrorStrategy.failFast: // Example if added later
          //   _log.severe('[Sequential] Error executing handler $handlerTypeName (Order: $order) for $notificationType [$correlationId]. Failing fast. Error: $e', e, s);
          //   return true; // Signal to stop dispatch
        }
      }
    }
    return false;
  }
}
