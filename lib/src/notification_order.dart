// lib/src/notification_order.dart

/// Defines constants for specifying the execution order and behavior of
/// [NotificationHandler]s when registered with [Kyron.registerNotificationHandler].
///
/// This allows mixing parallel and sequential execution within a single
/// notification dispatch.
abstract final class NotificationOrder {
  /// Represents the minimum safe integer value for JavaScript environments (-(2^53 - 1)).
  /// Using this ensures compatibility across native and web platforms for ordering.
  static const int _minSafeInteger = -9007199254740991;

  /// Represents the maximum safe integer value for JavaScript environments (2^53 - 1).
  /// Using this ensures compatibility across native and web platforms for ordering.
  static const int _maxSafeInteger = 9007199254740991;

  /// **Execution Behavior:** Handlers registered with this order will be executed
  /// **in parallel** with other handlers also marked as [parallelEarly].
  /// This entire batch of parallel handlers runs *before* any handlers with
  /// specific sequential order numbers.
  ///
  /// **Use Case:** Ideal for tasks that can run concurrently and should start
  /// as soon as possible, like quick logging or non-critical UI updates.
  ///
  /// **Default:** If no [order] is specified during registration, this value
  /// ([_minSafeInteger]) will be used by default.
  static const int parallelEarly = _minSafeInteger;

  /// **Execution Behavior:** Handlers registered with specific integer values
  /// (that are neither [parallelEarly] nor [parallelLate]) will execute
  /// **sequentially** relative to each other, based on their numerical order
  /// (ascending, lower numbers first). This entire sequential block runs *after*
  /// the [parallelEarly] batch and *before* the [parallelLate] batch.
  ///
  /// **Use Case:** Essential for handlers where the order of execution matters,
  /// such as performing dependent actions or ensuring a specific workflow.
  ///
  /// **Example Values:** -10, 0, 5, 100, etc.
  /// Handlers with the same sequential order number maintain their relative
  /// registration sequence within that specific order group.
  ///
  /// [sequentialDefault] ([_minSafeInteger]) is provided as a common default
  /// for sequential tasks, but any integer other than [parallelEarly] or
  /// [parallelLate] works.
  static const int sequentialDefault = _minSafeInteger;

  /// **Execution Behavior:** Handlers registered with this order will be executed
  /// **in parallel** with other handlers also marked as [parallelLate].
  /// This entire batch of parallel handlers runs *after* all [parallelEarly]
  /// handlers and all sequentially ordered handlers have completed.
  ///
  /// **Use Case:** Suitable for background tasks, cleanup operations, or
  /// long-running processes that can run concurrently and don't need to block
  /// the completion of more critical sequential steps.
  static const int parallelLate = _maxSafeInteger;

  // Private constructor to prevent instantiation.
  NotificationOrder._();
}
