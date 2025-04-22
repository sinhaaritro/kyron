// lib/src/registry.dart

import 'dart:collection';

import 'package:kyron/src/notification_order.dart';
import 'package:logging/logging.dart';

import 'exceptions.dart';
import 'notification_handler.dart';
import 'pipeline_behavior.dart';
import 'request.dart';
import 'request_handler.dart';

// Type Aliases
typedef HandlerFactory = Function;
typedef StreamHandlerFactory = Function;
typedef BehaviorFactory = Function;
typedef NotificationHandlerFactory = Function;

typedef BehaviorPredicate = bool Function(BaseRequest request);

typedef BehaviorRegistration =
    ({
      int order,
      BehaviorFactory factory,
      BehaviorPredicate predicate,
      String description,
    });

typedef NotificationHandlerRegistration =
    ({NotificationHandlerFactory factory, int order});

/// Manages the registration of request handlers, stream handlers, pipeline behaviors,
/// and notification handlers.
///
/// This class acts as the central repository where the relationship between message types
/// (requests, notifications) and their corresponding processing logic (factories for
/// handlers and behaviors) is stored. It is used internally by [Kyron] to look up
/// the necessary components when a message needs to be processed.
///
/// **Key Responsibilities:**
///   - Storing mappings from [Request] types to their [RequestHandler] factories.
///   - Storing mappings from [StreamRequest] types to their [StreamRequestHandler] factories.
///   - Storing registrations for [PipelineBehavior] factories, including their execution
///     order and applicability predicates ([BehaviorPredicate]).
///   - Storing lists of [NotificationHandler] factory registrations for each [Notification]
///     type, including their execution order.
///   - Providing methods ([find...]) for retrieving these registered factories and
///     registrations based on the type of incoming message or request.
///   - Offering getter methods for introspection (e.g., [registeredHandlerFactories])
///     to examine the current registrations, primarily for debugging or diagnostics.
///
/// **Default Implementation:**
/// This [MediatorRegistry] class provides the default registration storage mechanism
/// used by [Kyron] if no custom registry is provided to its constructor. It uses
/// simple in-memory Maps and Lists.
///
/// **Customization:**
/// While this default implementation is suitable for most use cases, an application
/// could provide its own implementation of a registry (perhaps adhering to a similar
/// interface or abstract class if defined) to the [Kyron] constructor if different
/// storage mechanisms, registration policies (e.g., handling overwrites differently),
/// or registration sources (e.g., configuration files) are required.
class KyronRegistry {
  static final _log = Logger('Kyron.Registry');

  final Map<Type, HandlerFactory> _handlerFactories = {};
  final Map<Type, StreamHandlerFactory> _streamHandlerFactories = {};
  final List<BehaviorRegistration> _behaviorRegistrations = [];
  final Map<Type, List<NotificationHandlerRegistration>>
  _notificationHandlerRegistrations = {};

  // Registration Methods

  void registerHandler<TRequest extends Request<TResponse>, TResponse>(
    RequestHandler<TRequest, TResponse> Function() handlerFactory,
  ) {
    final requestType = TRequest;
    if (_handlerFactories.containsKey(requestType)) {
      _log.warning(
        'Handler factory for $requestType already registered. Overwriting.',
      );
    }
    _handlerFactories[requestType] = handlerFactory;
    _log.config('Registered handler factory for $requestType');
  }

  void registerStreamHandler<
    TRequest extends StreamRequest<TResponse>,
    TResponse
  >(StreamRequestHandler<TRequest, TResponse> Function() handlerFactory) {
    final requestType = TRequest;
    if (_streamHandlerFactories.containsKey(requestType)) {
      _log.warning(
        'Stream handler factory for $requestType already registered. Overwriting.',
      );
    }
    _streamHandlerFactories[requestType] = handlerFactory;
    _log.config('Registered stream handler factory for $requestType');
  }

  // Corrected bound for TRequest to Object for flexibility
  void registerBehavior<TRequest extends BaseRequest, TResponse>(
    PipelineBehavior<dynamic, dynamic> Function() behaviorFactory, {
    BehaviorPredicate? appliesTo,
    String? predicateDescription,
    int? orderOverride,
  }) {
    try {
      // Instantiate temporarily ONLY to get order/type if needed.
      // This is risky if factories have side effects.
      // TODO: Explore ways to register Type/order without instantiation.
      final tempBehavior = behaviorFactory();
      final behaviorType = tempBehavior.runtimeType;
      final actualOrder = orderOverride ?? tempBehavior.order;

      BehaviorPredicate predicate;
      String finalDescription;

      // Determine the default predicate if 'appliesTo' is not provided.
      // Use the TRequest type provided *at the call site*.
      final requestTypeAtCallSite = TRequest;

      if (appliesTo != null) {
        predicate = appliesTo;
        finalDescription =
            predicateDescription ??
            'Custom Predicate (${appliesTo.runtimeType})';
      }
      // Check if TRequest at call site represents a generic request type
      else if (requestTypeAtCallSite == Object || // Highest level, truly global
          requestTypeAtCallSite ==
              BaseRequest || // Global for all Kyron requests
          requestTypeAtCallSite == Request || // Global for standard Requests
          requestTypeAtCallSite == StreamRequest || // Global for StreamRequests
          // Also check dynamic variants which imply broad applicability
          requestTypeAtCallSite.toString() == 'Request<dynamic>' ||
          requestTypeAtCallSite.toString() == 'StreamRequest<dynamic>') {
        // Apply globally to all requests processed by the mediator.
        predicate = (BaseRequest req) => true; // Matches updated typedef
        finalDescription =
            predicateDescription ??
            'Global (Applies to all Requests/StreamRequests)';
      } else {
        // Assume user intended an exact type match for a specific request type
        // (e.g., GetUserQuery) when TRequest is concrete and specific.
        predicate =
            (BaseRequest req) =>
                req.runtimeType ==
                requestTypeAtCallSite; // Matches updated typedef
        finalDescription =
            predicateDescription ?? 'Exact Type Match ($requestTypeAtCallSite)';
      }

      final registration = (
        order: actualOrder,
        factory: behaviorFactory,
        predicate: predicate, // Use the determined predicate
        description: finalDescription,
      );
      _behaviorRegistrations.add(registration);
      _log.config(
        'Registered behavior factory for $behaviorType (Order: $actualOrder, Applies Via: "$finalDescription")',
      );
    } catch (e, s) {
      _log.severe('Error during registration of behavior factory: $e', e, s);
      throw MediatorConfigurationException(
        'Failed to register behavior factory. Ensure it creates a valid PipelineBehavior. Error: $e',
      );
    }
  }

  /// Registers a factory function responsible for creating or providing a handler
  /// for a specific message/event type ([TNotification]).
  ///
  /// Adds the handler factory and its associated execution order to the internal
  /// storage, keyed by the [TNotification] type.
  ///
  /// See [Kyron.registerNotificationHandler] for a more detailed explanation of
  /// handler factories, execution order ([NotificationOrder]), error handling,
  /// and usage examples.
  ///
  /// **Generics:**
  ///   - [TNotification]: The specific type of the message/event object.
  ///
  /// **Parameters:**
  ///   - [handlerFactory]: A function that returns an instance of [NotificationHandler<TNotification>].
  ///   - [order]: The execution order for this handler relative to others for the same type.
  void registerNotificationHandler<TNotification>(
    NotificationHandler<TNotification> Function() handlerFactory, {
    int order = NotificationOrder.parallelEarly,
  }) {
    final notificationType = TNotification;

    final handlerList = _notificationHandlerRegistrations.putIfAbsent(
      notificationType,
      () => <NotificationHandlerRegistration>[],
    );

    handlerList.add((factory: handlerFactory, order: order));

    // Clarify log based on order type
    String orderDesc;
    if (order == NotificationOrder.parallelEarly) {
      orderDesc = 'Parallel Early';
    } else if (order == NotificationOrder.parallelLate) {
      orderDesc = 'Parallel Late';
    } else {
      orderDesc = 'Sequential ($order)';
    }

    _log.config(
      'Registered notification handler factory for $notificationType (Execution: $orderDesc)',
    );
  }

  // Retrieval Methods

  HandlerFactory? findHandlerFactory(Type requestType) {
    return _handlerFactories[requestType];
  }

  StreamHandlerFactory? findStreamHandlerFactory(Type requestType) {
    return _streamHandlerFactories[requestType];
  }

  List<BehaviorRegistration> findApplicableBehaviorRegistrations(
    BaseRequest request,
  ) {
    final List<BehaviorRegistration> applicable = [];
    for (final reg in _behaviorRegistrations) {
      bool matchesRequest = false;
      try {
        // Predicate takes BaseRequest now
        matchesRequest = reg.predicate(request);
      } catch (e, s) {
        _log.warning(
          'Predicate execution failed for behavior registration "${reg.description}" while checking request ${request.runtimeType}. Behavior skipped. Error: $e',
          e,
          s,
        );
      }
      if (matchesRequest) {
        applicable.add(reg);
      }
    }
    // Log summary after loop if needed for debugging
    _log.finest(
      'Found ${applicable.length} applicable behaviors for request ${request.runtimeType}.',
    );
    return applicable;
  }

  /// Finds all registered handler factories and their associated orders for a
  /// given message/event type.
  ///
  /// Used by the [NotificationDispatcher] to retrieve the components needed to
  /// handle a published message/event object.
  ///
  /// - [notificationType]: The [Type] of the message/event object being published.
  /// - Returns: A list of [NotificationHandlerRegistration] tuples (containing the factory and order)
  ///   for the specified type, or an empty list if no handlers are registered for that type.
  List<NotificationHandlerRegistration> findNotificationHandlerRegistrations(
    Type notificationType,
  ) {
    return _notificationHandlerRegistrations[notificationType] ??
        <NotificationHandlerRegistration>[];
  }

  // Diagnostics / Introspection

  Map<Type, HandlerFactory> get registeredHandlerFactories =>
      UnmodifiableMapView(_handlerFactories);

  Map<Type, StreamHandlerFactory> get registeredStreamHandlerFactories =>
      UnmodifiableMapView(_streamHandlerFactories);

  List<BehaviorRegistration> get registeredBehaviorRegistrations =>
      UnmodifiableListView(_behaviorRegistrations);

  Map<Type, List<NotificationHandlerRegistration>>
  get registeredNotificationHandlerRegistrations => UnmodifiableMapView(
    _notificationHandlerRegistrations.map(
      (key, value) => MapEntry(key, UnmodifiableListView(value)),
    ),
  );

  Map<Type, List<NotificationHandlerFactory>>
  get registeredNotificationHandlersSimple => UnmodifiableMapView(
    _notificationHandlerRegistrations.map(
      (key, value) => MapEntry(
        key,
        UnmodifiableListView(value.map((reg) => reg.factory).toList()),
      ),
    ),
  );
}
