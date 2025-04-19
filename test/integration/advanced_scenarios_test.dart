// test/integration/advanced_scenarios_test.dart

import 'dart:async';

import 'package:test/test.dart';
import 'package:kyron/kyron.dart';
import 'package:mocktail/mocktail.dart';

// Import concrete implementations and test data
import '../fixtures/test_data.dart';
import '../fixtures/mock_handlers.dart';
import '../fixtures/mock_behaviors.dart';

// Additional Components for Advanced Scenarios

// Request -> Notification Publisher Handler
class PublishingRequestHandler extends RequestHandler<SimpleRequest, String> {
  final KyronInterface kyron;
  PublishingRequestHandler(this.kyron);

  @override
  Future<String> handle(SimpleRequest request, PipelineContext context) async {
    final message = 'Notification from ${request.payload}';
    await kyron.publish(SimpleNotification(message));
    return 'Published: $message';
  }
}

// For the existing test 'Behavior short-circuiting combined...', we need a handler for ShortCircuitRequest
class ConcreteShortCircuitRequestHandlerForAdvanced
    extends RequestHandler<ShortCircuitRequest, String> {
  @override
  Future<String> handle(
    ShortCircuitRequest request,
    PipelineContext context,
  ) async {
    // This handler shouldn't actually be called if the behavior short-circuits,
    // but we need a valid registration.
    return "ShortCircuit Handler Reached (Should not happen in test)";
  }
}

// Notification -> Request Sender Handler
class RequestingNotificationHandler
    extends NotificationHandler<SimpleNotification> {
  final KyronInterface kyron;
  final List<String> log;
  RequestingNotificationHandler(this.kyron, this.log);

  @override
  Future<void> handle(SimpleNotification notification) async {
    log.add(
      'Notification handler starting request for: ${notification.message}',
    );
    try {
      final response = await kyron.send(
        OtherRequest(notification.message.length),
      ); // Send based on notification
      log.add('Notification handler got response: $response');
    } catch (e) {
      log.add('Notification handler request failed: $e');
    }
  }
}

// Behavior to check context data
class ContextCheckingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  final String expectedData;
  final List<String> log;
  @override
  final int order; // Made final and required

  ContextCheckingBehavior(this.expectedData, this.log, {required this.order});

  @override
  Future handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate next,
  ) async {
    final actualData = context.testData; // Use extension
    log.add('ContextCheck: Expected="$expectedData", Actual="$actualData"');
    if (actualData != expectedData) {
      log.add('ContextCheck: MISMATCH!');
    }
    return await next();
  }
}

class CallbackBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  final Function(PipelineContext) callback;
  @override
  final int order; // Add order if needed, or default

  CallbackBehavior(this.callback, {this.order = 0}); // Add order

  @override
  Future handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate next,
  ) async {
    callback(context);
    return await next();
  }
}

void main() {
  late Kyron kyron;
  late List<String> log; // General purpose log

  setUp(() {
    kyron = Kyron();
    log = [];

    // Register common handlers
    kyron.registerHandler<SimpleRequest, String>(
      () => ConcreteSimpleRequestHandler(),
    );
    kyron.registerHandler<OtherRequest, int>(
      () => ConcreteOtherRequestHandler(),
    );
    kyron.registerHandler<ContextRequest, String>(
      () => ConcreteContextRequestHandler(),
    );
    kyron.registerStreamHandler<SimpleStreamRequest, int>(
      () => ConcreteSimpleStreamRequestHandler(),
    );
    kyron.registerNotificationHandler<SimpleNotification>(
      () => ConcreteSimpleNotificationHandler(log),
    );
    // Register handler needed for short-circuit test
    kyron.registerHandler<ShortCircuitRequest, String>(
      () => ConcreteShortCircuitRequestHandlerForAdvanced(),
    );

    registerFallbackValue(PipelineContext(0));
  });

  group('Integration: Advanced Scenarios', () {
    test(
      'Request with multi-step pipeline (e.g., Logging -> Validation -> Auth -> Handler)',
      () async {
        // Arrange
        kyron = Kyron(); // Reset for clean pipeline
        kyron.registerHandler<ContextRequest, String>(
          () => ConcreteContextRequestHandler(),
        );

        // Register behaviors in order
        kyron.registerBehavior(
          behaviorFactoryFor(GlobalLoggingBehavior(log, order: -20)),
        ); // 1st
        kyron.registerBehavior(
          behaviorFactoryFor(ContextModifyingBehavior('Validated', order: -10)),
        ); // 2nd (Simulates validation)
        kyron.registerBehavior(
          behaviorFactoryFor(
            ContextModifyingBehavior('Authenticated:Validated', order: 0),
          ),
        ); // 3rd (Simulates Auth reading previous state)

        const req = ContextRequest();

        // Act
        final response = await kyron.send(req);

        // Assert
        expect(
          log,
          contains(startsWith('GlobalLoggingBehavior:START')),
          reason: 'Logger should run',
        );
        expect(
          response,
          contains('Handler got context data: Authenticated:Validated'),
          reason: 'Handler should get final context state',
        );
        expect(
          response,
          contains(
            'behavior order: GlobalLoggingBehavior, ContextModifyingBehavior, ContextModifyingBehavior',
          ),
          reason: 'Handler should see correct order',
        );
      },
    );

    test(
      'Stream request with setup pipeline behaviors (e.g., Logging -> Handler)',
      () async {
        // Arrange
        kyron = Kyron(); // Reset
        kyron.registerStreamHandler<SimpleStreamRequest, int>(
          () => ConcreteSimpleStreamRequestHandler(),
        );
        kyron.registerBehavior(
          behaviorFactoryFor(GlobalLoggingBehavior(log, order: -10)),
        );

        const req = SimpleStreamRequest(2);

        // Act
        final stream = kyron.stream(req);
        final results = await stream.toList(); // Consume stream

        // Assert
        expect(
          log,
          contains(
            startsWith('GlobalLoggingBehavior:START:SimpleStreamRequest'),
          ),
          reason: 'Logging behavior should run during setup',
        );
        expect(
          log,
          contains(startsWith('GlobalLoggingBehavior:END:SimpleStreamRequest')),
          reason: 'Logging behavior should complete after setup returns stream',
        );
        expect(
          results,
          orderedEquals([0, 1]),
          reason: 'Stream should still produce correct results',
        );
      },
    );

    test(
      'Request handler successfully publishes a notification during its execution',
      () async {
        // Arrange
        kyron = Kyron(); // Reset
        final notificationMessages = <String>[];
        kyron.registerHandler<SimpleRequest, String>(
          () => PublishingRequestHandler(kyron),
        );
        kyron.registerNotificationHandler<SimpleNotification>(
          () => ConcreteSimpleNotificationHandler(notificationMessages),
        );

        const req = SimpleRequest('trigger');

        // Act
        final reqResponse = await kyron.send(req);

        // Assert
        await Future.delayed(Duration.zero);
        expect(
          reqResponse,
          equals('Published: Notification from trigger'),
          reason: 'Request handler should complete',
        );
        expect(
          notificationMessages,
          equals(['Notification from trigger']),
          reason:
              'Notification handler should have received the published message',
        );
      },
    );

    test('Multiple concurrent requests maintain PipelineContext isolation', () async {
      // Arrange
      kyron = Kyron(); // Reset
      kyron.registerHandler<ContextRequest, String>(
        () => ConcreteContextRequestHandler(),
      );

      // Behavior factory (using the defined CallbackBehavior)
      PipelineBehavior<BaseRequest, dynamic> isolatingBehaviorFactory() {
        return CallbackBehavior((context) {
          // Get some unique identifier for the request (hashCode is simple)
          final requestId =
              context.correlationId; // Or use request properties if needed
          final dataToSet = 'DataFor_$requestId';

          log.add('Request($requestId): Context before = ${context.testData}');
          // Check if data from a *previous* request leaked (it shouldn't)
          expect(
            context.testData,
            isNull,
            reason: 'Context should be null at start of request $requestId',
          );

          context.testData = dataToSet; // Add data specific to this request
          log.add('Request($requestId): Context after = ${context.testData}');
        }, order: -10); // Assign order
      }

      kyron.registerBehavior(isolatingBehaviorFactory);

      const reqA = ContextRequest();
      const reqB = ContextRequest(); // Create two separate request instances

      // Act - Run concurrently
      // Use Future.wait to ensure both complete
      final results = await Future.wait([kyron.send(reqA), kyron.send(reqB)]);
      final responseA = results[0];
      final responseB = results[1];

      // Assert
      // Check that each handler got the data set *during its own pipeline*
      expect(
        responseA,
        contains('Handler got context data: DataFor_${reqA.hashCode}'),
        reason: 'Request A should have its own data',
      );
      expect(
        responseB,
        contains('Handler got context data: DataFor_${reqB.hashCode}'),
        reason: 'Request B should have its own data',
      );

      // Log verification (optional, confirms the expect inside behavior passed)
      print("Concurrency Log: $log");
      expect(
        log,
        contains(
          startsWith('Request(${reqA.hashCode}): Context before = null'),
        ),
      );
      expect(
        log,
        contains(
          startsWith('Request(${reqB.hashCode}): Context before = null'),
        ),
      );
      // Verify data was set correctly
      expect(
        log,
        contains(
          startsWith(
            'Request(${reqA.hashCode}): Context after = DataFor_${reqA.hashCode}',
          ),
        ),
      );
      expect(
        log,
        contains(
          startsWith(
            'Request(${reqB.hashCode}): Context after = DataFor_${reqB.hashCode}',
          ),
        ),
      );
    });

    test(
      'Behavior short-circuiting combined with subsequent notification publishing',
      () async {
        // Arrange
        kyron = Kyron(); // Reset
        final notificationMessages = <String>[];

        kyron.registerHandler<ShortCircuitRequest, String>(
          () => ConcreteShortCircuitRequestHandlerForAdvanced(),
        );
        kyron.registerNotificationHandler<SimpleNotification>(
          () => ConcreteSimpleNotificationHandler(notificationMessages),
        );
        kyron.registerBehavior(
          behaviorFactoryFor(
            ShortCircuitingBehavior(
              order: -10,
              exceptionToThrow: MyCustomShortCircuit('Stopped'),
            ),
          ),
        );

        const req = ShortCircuitRequest(true);

        // Act
        MyCustomShortCircuit? caughtException;
        try {
          await kyron.send(req);
        } on MyCustomShortCircuit catch (e) {
          caughtException = e;
        }

        // Assert
        expect(
          caughtException,
          isNotNull,
          reason: 'Short circuit exception should be caught',
        );
        expect(caughtException?.reason, equals('Stopped'));
        await Future.delayed(Duration.zero);
        expect(
          notificationMessages,
          isEmpty,
          reason:
              'Notification should NOT have been published as handler was skipped',
        );
      },
    );

    test('Notification handler triggers a new request via kyron.send', () async {
      // Arrange
      kyron = Kyron(); // Reset
      final notificationHandlerLog = <String>[];
      kyron.registerHandler<OtherRequest, int>(
        () => ConcreteOtherRequestHandler(),
      );
      kyron.registerNotificationHandler<SimpleNotification>(
        () => RequestingNotificationHandler(kyron, notificationHandlerLog),
      );

      const initialNotification = SimpleNotification('Trigger Request');

      // Act
      await kyron.publish(initialNotification);

      // Assert
      await Future.delayed(Duration.zero);
      expect(
        notificationHandlerLog,
        contains('Notification handler starting request for: Trigger Request'),
        reason: 'Notification handler should start',
      );
      expect(
        notificationHandlerLog,
        contains('Notification handler got response: 30'),
        reason:
            'Notification handler should receive response from kyron.send (15 * 2)',
      );
    });

    test(
      'Using custom ShortCircuitException with data and verifying data in catch block',
      () async {
        // Arrange
        kyron = Kyron(); // Reset

        kyron.registerHandler<ShortCircuitRequest, String>(
          () => ConcreteShortCircuitRequestHandlerForAdvanced(),
        );
        final exceptionData = 403;
        final exceptionToThrow = AnotherShortCircuit(exceptionData);
        kyron.registerBehavior(
          behaviorFactoryFor(
            ShortCircuitingBehavior(exceptionToThrow: exceptionToThrow),
          ),
        );

        const req = ShortCircuitRequest(true);

        // Act
        AnotherShortCircuit? caughtException;
        try {
          await kyron.send(req);
        } on AnotherShortCircuit catch (e) {
          caughtException = e;
        }

        // Assert
        expect(
          caughtException,
          isNotNull,
          reason: 'Should catch the specific exception type',
        );
        expect(
          caughtException?.data,
          equals(exceptionData),
          reason: 'Should be able to access data from caught exception',
        );
        expect(
          caughtException?.code,
          equals(exceptionData),
          reason: 'Custom getter should work',
        );
      },
    );

    test(
      'Complex ordering with multiple behaviors having same order number (relies on registration sequence)',
      () async {
        // Arrange
        kyron = Kyron(); // Reset
        kyron.registerHandler<ContextRequest, String>(
          () => ConcreteContextRequestHandler(),
        );

        kyron.registerBehavior(
          behaviorFactoryFor(ContextModifyingBehavior('A', order: 0)),
        ); // Registered first
        kyron.registerBehavior(
          behaviorFactoryFor(ContextModifyingBehavior('B', order: 0)),
        ); // Registered second
        kyron.registerBehavior(
          behaviorFactoryFor(ContextModifyingBehavior('C', order: 0)),
        ); // Registered third
        kyron.registerBehavior(
          behaviorFactoryFor(GlobalLoggingBehavior(log, order: -10)),
        );

        const req = ContextRequest();

        // Act
        final response = await kyron.send(req);

        // Assert
        expect(
          response,
          contains(
            'behavior order: GlobalLoggingBehavior, ContextModifyingBehavior, ContextModifyingBehavior, ContextModifyingBehavior',
          ),
          reason:
              'Order recorded in context should reflect registration sequence for same-order behaviors',
        );
        expect(
          response,
          contains('Handler got context data: C'),
          reason:
              'Final context data should be from the last registered behavior with order 0',
        );
      },
    );

    test(
      'Registering and triggering handlers for different notification types sequentially',
      () async {
        // Arrange
        kyron = Kyron(); // Reset
        final logA = <String>[];
        final logB = <String>[];
        kyron.registerNotificationHandler<SimpleNotification>(
          () => ConcreteSimpleNotificationHandler(logA),
        );
        kyron.registerNotificationHandler<OrderedNotification>(
          () => ConcreteOrderedNotificationHandler(logB, 'OrderHandler'),
        );

        const notificationA = SimpleNotification('First Type');
        const notificationB = OrderedNotification();

        // Act
        await kyron.publish(notificationA);
        await kyron.publish(notificationB);

        // Assert
        expect(
          logA,
          equals(['First Type']),
          reason: 'Handler for SimpleNotification should have run',
        );
        expect(
          logB,
          equals(['OrderHandler:START', 'OrderHandler:END']),
          reason: 'Handler for OrderedNotification should have run',
        );
      },
    );
  });
}
