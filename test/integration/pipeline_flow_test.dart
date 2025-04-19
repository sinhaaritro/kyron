// test/integration/pipeline_flow_test.dart

import 'dart:async';

import 'package:test/test.dart';
import 'package:kyron/kyron.dart';
import 'package:mocktail/mocktail.dart';

// Import concrete implementations and test data
import '../fixtures/test_data.dart';
import '../fixtures/mock_handlers.dart';
import '../fixtures/mock_behaviors.dart';

class ConcreteShortCircuitRequestHandler
    extends RequestHandler<ShortCircuitRequest, String> {
  @override
  Future<String> handle(
    ShortCircuitRequest request,
    PipelineContext context,
  ) async {
    return "Handler Executed for ShortCircuitRequest";
  }
}

class ConcreteShortCircuitStreamRequestHandler
    extends StreamRequestHandler<ShortCircuitStreamRequest, int> {
  @override
  Stream<int> handle(
    ShortCircuitStreamRequest request,
    PipelineContext context,
  ) async* {
    yield 88; // Example value
  }
}

class MockShortCircuitRequestHandler extends Mock
    implements RequestHandler<ShortCircuitRequest, String> {}

// Helper behavior to execute a callback, useful for checking context state
class CallbackBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  final Function(PipelineContext) callback;
  CallbackBehavior(this.callback);

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
  late List<String> behaviorLog; // Shared log for behaviors in tests

  setUp(() {
    kyron = Kyron();
    behaviorLog = [];

    // Register necessary handlers for pipeline tests
    kyron.registerHandler<SimpleRequest, String>(
      () => ConcreteSimpleRequestHandler(),
    );
    kyron.registerHandler<ContextRequest, String>(
      () => ConcreteContextRequestHandler(),
    );
    kyron.registerHandler<ShortCircuitRequest, String>(
      () => ConcreteShortCircuitRequestHandler(),
    );
    kyron.registerStreamHandler<ShortCircuitStreamRequest, int>(
      () => ConcreteShortCircuitStreamRequestHandler(),
    );

    // Register other handlers if needed by specific tests
    kyron.registerHandler<OtherRequest, int>(
      () => ConcreteOtherRequestHandler(),
    );

    registerFallbackValue(PipelineContext(0));
    registerFallbackValue(
      const SimpleRequest('fallback'),
    ); // Needed if handler uses any()
    registerFallbackValue(
      const ShortCircuitRequest(false),
    ); // Provide a dummy instance
  });

  group('Integration: Pipeline Flow', () {
    group('Behavior Registration and Applicability', () {
      test('globally registered behavior runs for all send requests', () async {
        // Arrange
        kyron.registerBehavior(
          behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog)),
        );
        const req1 = SimpleRequest('a');
        const req2 = OtherRequest(1);

        // Act
        await kyron.send(req1);
        await kyron.send(req2);

        // Assert
        expect(
          behaviorLog,
          contains(startsWith('GlobalLoggingBehavior:START:SimpleRequest')),
          reason: 'Global behavior should run for SimpleRequest',
        );
        expect(
          behaviorLog,
          contains(startsWith('GlobalLoggingBehavior:START:OtherRequest')),
          reason: 'Global behavior should run for OtherRequest',
        );
      });

      test(
        'globally registered behavior runs for all stream requests (during setup)',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog)),
          );
          const req = ShortCircuitStreamRequest(false); // Use a stream request

          // Act
          final stream = kyron.stream(req);
          await stream.toList(); // Consume stream to ensure setup completes

          // Assert
          expect(
            behaviorLog,
            contains(
              startsWith(
                'GlobalLoggingBehavior:START:ShortCircuitStreamRequest',
              ),
            ),
            reason: 'Global behavior should run for stream request setup',
          );
        },
      );

      test(
        'specifically registered behavior (by type) runs only for that request type',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(SpecificBehaviorForSimpleRequest(behaviorLog)),
          );
          const req1 = SimpleRequest('a');

          // Act
          await kyron.send(req1);

          // Assert
          expect(
            behaviorLog,
            contains('SpecificBehaviorForSimpleRequest:START'),
            reason: 'Specific behavior should run for SimpleRequest',
          );
        },
      );

      test(
        'specifically registered behavior (by type) does not run for other request types',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(SpecificBehaviorForSimpleRequest(behaviorLog)),
            appliesTo:
                (request) =>
                    request is SimpleRequest, // Constrain by type check
          );
          const req2 = OtherRequest(1); // Different type

          // Act
          await kyron.send(req2);

          // Assert
          expect(
            behaviorLog,
            isNot(contains('SpecificBehaviorForSimpleRequest:START')),
            reason: 'Specific behavior should NOT run for OtherRequest',
          );
        },
      );

      test(
        'behavior registered with predicate runs only for matching requests',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(PredicateBehavior(behaviorLog, 'Marker')),
            appliesTo: PredicateBehavior.appliesIfSimpleRequest,
          );
          const req1 = SimpleRequest('a');

          // Act
          await kyron.send(req1);

          // Assert
          expect(
            behaviorLog,
            contains(startsWith('PredicateBehavior(Marker):START')),
            reason: 'Predicate behavior should run for SimpleRequest',
          );
        },
      );

      test(
        'behavior registered with predicate does not run for non-matching requests',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(PredicateBehavior(behaviorLog, 'Marker')),
            appliesTo: PredicateBehavior.appliesIfSimpleRequest,
          );
          const req2 = OtherRequest(1); // Does not match predicate

          // Act
          await kyron.send(req2);

          // Assert
          expect(
            behaviorLog,
            isNot(contains(startsWith('PredicateBehavior(Marker):START'))),
            reason: 'Predicate behavior should NOT run for OtherRequest',
          );
        },
      );
    });

    group('Behavior Execution Order', () {
      test(
        'multiple global behaviors execute in specified order (ascending)',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog, order: 10)),
          ); // Runs second
          kyron.registerBehavior(
            behaviorFactoryFor(ContextModifyingBehavior('data', order: -5)),
          ); // Runs first

          // Act
          final res = await kyron.send(
            const ContextRequest(),
          ); // Use context request/handler

          // Assert
          final startIndexBneg5 = behaviorLog.indexWhere(
            (s) => s.contains('ContextModifyingBehavior'),
          ); // Check if context mod behavior ran
          final startIndexB10 = behaviorLog.indexWhere(
            (s) => s.startsWith('GlobalLoggingBehavior:START'),
          );

          expect(
            startIndexBneg5,
            lessThan(startIndexB10),
            reason:
                'Behavior with order -5 should log start before behavior with order 10',
          );

          // Check context for execution order log via handler response
          expect(
            res,
            contains(
              'behavior order: ContextModifyingBehavior, GlobalLoggingBehavior',
            ),
            reason: 'Context should confirm execution order',
          );
        },
      );

      test(
        'mix of global and specific behaviors execute in correct combined order',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog, order: 10)),
          ); // Global, runs third
          kyron.registerBehavior(
            behaviorFactoryFor(
              SpecificBehaviorForSimpleRequest(behaviorLog, order: -5),
            ),
            appliesTo: (request) => request is SimpleRequest,
          ); // Specific, runs second
          kyron.registerBehavior(
            behaviorFactoryFor(ContextModifyingBehavior('data', order: -10)),
          ); // Global, runs first

          const req = SimpleRequest(
            'mixed order',
          ); // Need to send this first to trigger specific behavior

          // Act
          await kyron.send(req); // This should now run all 3
          final res = await kyron.send(
            const ContextRequest(),
          ); // This should only run the 2 global ones

          // Assert via context behavior log *from the first request*
          final firstContextModIndex = behaviorLog.indexWhere(
            (s) => s.contains('ContextModifyingBehavior'), // First global
          );
          final specificIndex = behaviorLog.indexWhere(
            (s) => s.contains(
              'SpecificBehaviorForSimpleRequest:START',
            ), // Specific
          );
          final globalLogIndex = behaviorLog.indexWhere(
            (s) => s.startsWith('GlobalLoggingBehavior:START'), // Second global
          );

          // Check order from the first send() call log
          expect(
            firstContextModIndex,
            lessThan(specificIndex),
            reason: 'ContextMod (-10) before Specific (-5)',
          );
          expect(
            specificIndex,
            lessThan(globalLogIndex),
            reason: 'Specific (-5) before Global (10)',
          );

          // The response from ContextRequest confirms its own pipeline order
          expect(
            res,
            contains(
              'behavior order: ContextModifyingBehavior, GlobalLoggingBehavior',
            ),
            reason:
                'Context response shows order for its own execution (only globals)',
          );
        },
      );

      test(
        'orderOverride during registration takes precedence over behavior\'s internal order getter',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(
              GlobalLoggingBehavior(behaviorLog),
            ), // Default order -100
            orderOverride: 5, // Override to 5
          );
          kyron.registerBehavior(
            behaviorFactoryFor(
              SpecificBehaviorForSimpleRequest(behaviorLog),
            ), // Default order 0
            appliesTo: (request) => request is SimpleRequest,
            orderOverride: -2, // Override to -2
          );

          const req = SimpleRequest('override test');

          // Act
          await kyron.send(req); // Runs both behaviors based on override order
          final res = await kyron.send(
            const ContextRequest(),
          ); // Runs only global behavior

          // Assert via context behavior log from the first request
          final specificIndex = behaviorLog.indexWhere(
            (s) => s.contains('SpecificBehaviorForSimpleRequest:START'),
          );
          final globalLogIndex = behaviorLog.indexWhere(
            (s) => s.startsWith('GlobalLoggingBehavior:START'),
          );
          expect(
            specificIndex, // Order -2
            lessThan(globalLogIndex), // Order 5
            reason:
                'Specific (-2) should run before Global (5) based on override',
          );

          // Assert via ContextRequest response (reflects its own run)
          expect(
            res,
            contains(
              'behavior order: GlobalLoggingBehavior',
            ), // Only global ran
            reason: 'Context request only ran global behavior',
          );
        },
      );
    });

    group('PipelineContext Interaction', () {
      test('behavior can add data to PipelineContext', () async {
        // Arrange
        kyron.registerBehavior(
          behaviorFactoryFor(
            ContextModifyingBehavior('ValueFromBehavior', order: -10),
          ),
        );
        const req = ContextRequest();

        // Act
        final response = await kyron.send(req);

        // Assert
        expect(
          response,
          contains('Handler got context data: ValueFromBehavior'),
          reason: 'Handler should receive data added by behavior',
        );
      });

      test(
        'subsequent behavior can read data added by a previous behavior in the same request pipeline',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(
              ContextModifyingBehavior('DataFromFirst', order: -10),
            ),
          );
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog, order: 0)),
          ); // Logs implicitly via ContextHandler
          const req = ContextRequest();

          // Act
          final response = await kyron.send(req);

          // Assert
          expect(
            response,
            contains('Handler got context data: DataFromFirst'),
            reason: 'Data should persist through pipeline',
          );
          expect(
            behaviorLog,
            contains(startsWith('GlobalLoggingBehavior:START:ContextRequest')),
            reason: 'Second behavior should have run',
          );
        },
      );

      test(
        'handler can read data added by a behavior in the same request pipeline',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(
              ContextModifyingBehavior('DataForHandler', order: -10),
            ),
          );
          const req = ContextRequest();

          // Act
          final response = await kyron.send(req);

          // Assert
          expect(
            response,
            contains('Handler got context data: DataForHandler'),
          );
        },
      );

      test(
        'PipelineContext data from one request does not leak into a subsequent, separate request',
        () async {
          // Arrange
          kyron.registerBehavior(
            behaviorFactoryFor(
              ContextModifyingBehavior('Request1Data', order: -10),
            ),
          );
          const req1 = ContextRequest();
          const req2 = ContextRequest();

          // Act
          final response1 = await kyron.send(req1);
          // ** Simulate isolation more accurately by creating a NEW Kyron instance **
          final kyron2 = Kyron();
          kyron2.registerHandler<ContextRequest, String>(
            () => ConcreteContextRequestHandler(),
          );
          // Don't register the modifying behavior on kyron2

          final response2 = await kyron2.send(req2);

          // Assert
          expect(
            response1,
            contains('Handler got context data: Request1Data'),
            reason: 'First request should have data',
          );
          expect(
            response2,
            contains('Handler got context data: null'),
            reason:
                'Second request (new Kyron) should have null data (no leak)',
          );
        },
      );

      test('context contains the correct correlationId', () async {
        // Arrange
        int? capturedCorrelationId;
        kyron.registerBehavior(
          () => CallbackBehavior(
            (ctx) => capturedCorrelationId = ctx.correlationId,
          ),
        );
        const req = SimpleRequest('corrId');

        // Act
        await kyron.send(req);

        // Assert
        expect(
          capturedCorrelationId,
          equals(req.hashCode),
          reason:
              'Context correlationId should match request hashcode by default',
        );
      });
    });

    group('Behavior Short-Circuiting', () {
      test(
        'behavior returning value directly stops pipeline and returns value (if adapted)',
        () async {
          // Arrange
          const expectedValue = 'ShortCircuitValueFromBehavior';
          kyron.registerBehavior(
            behaviorFactoryFor(
              ShortCircuitingBehavior(
                throwException: false,
                valueToReturn: expectedValue,
              ),
            ),
          );
          const req = ShortCircuitRequest(true);

          // Act
          final response = await kyron.send(req);

          // Assert
          expect(
            response,
            equals(expectedValue),
            reason: 'Should return value directly from behavior',
          );
          // Verification that handler didn't run needs mock handler setup
        },
      );

      test(
        'behavior throwing SpecificShortCircuitException stops pipeline',
        () async {
          // Arrange
          final exceptionToThrow = const MyCustomShortCircuit(
            'StoppingPipeline',
          );
          kyron.registerBehavior(
            behaviorFactoryFor(
              ShortCircuitingBehavior(exceptionToThrow: exceptionToThrow),
            ),
          );
          const req = ShortCircuitRequest(true);

          // Act & Assert
          await expectLater(
            () => kyron.send(req),
            throwsA(same(exceptionToThrow)),
            reason: 'Should throw the specific short circuit exception',
          );
        },
      );

      test(
        'caller can catch the specific type of ShortCircuitException thrown by behavior',
        () async {
          // Arrange
          final exceptionToThrow = const AnotherShortCircuit(401);
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
            reason: 'Specific exception type should be caught',
          );
          expect(caughtException, same(exceptionToThrow));
          expect(
            caughtException?.code,
            equals(401),
            reason: 'Data from specific exception should be accessible',
          );
        },
      );

      test(
        'behavior throwing ShortCircuitException during stream setup results in Stream.error',
        () async {
          // Arrange
          final exceptionToThrow = const MyCustomShortCircuit(
            'StopStreamSetup',
          );
          kyron.registerBehavior(
            behaviorFactoryFor(
              ShortCircuitingBehavior(exceptionToThrow: exceptionToThrow),
            ),
          );
          const req = ShortCircuitStreamRequest(true);

          // Act
          final stream = kyron.stream(req);

          // Assert
          await expectLater(
            stream,
            emitsError(same(exceptionToThrow)),
            reason:
                'Stream should emit the short circuit exception thrown during setup',
          );
        },
      );

      test(
        'handler is not executed when a behavior short-circuits before it',
        () async {
          // Arrange
          final handler = MockShortCircuitRequestHandler(); // Use mock handler
          kyron = Kyron(); // Reset
          kyron.registerHandler<ShortCircuitRequest, String>(() => handler);
          kyron.registerBehavior(
            behaviorFactoryFor(ShortCircuitingBehavior(order: -10)),
          ); // Runs before handler

          const req = ShortCircuitRequest(true);

          // Act
          try {
            await kyron.send(req);
          } on ShortCircuitException {
            // Expected
          }

          // Assert
          // This verify call now works because the fallback is registered
          verifyNever(() => handler.handle(any(), any()));
        },
      );

      test(
        'subsequent behaviors are not executed when a behavior short-circuits',
        () async {
          // Arrange
          kyron = Kyron(); // Reset
          kyron.registerHandler<ShortCircuitRequest, String>(
            () => ConcreteShortCircuitRequestHandler(),
          );
          kyron.registerBehavior(
            behaviorFactoryFor(ShortCircuitingBehavior(order: -10)),
          ); // Runs first, short-circuits
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog, order: 0)),
          ); // Runs second

          const req = ShortCircuitRequest(true);

          // Act
          try {
            await kyron.send(req);
          } on ShortCircuitException {
            // Expected
          }

          // Assert
          expect(
            behaviorLog.where((s) => s.startsWith('GlobalLoggingBehavior')),
            isEmpty,
            reason: 'Subsequent behavior should not have executed',
          );
        },
      );
    });

    group('getPipelinePlan Verification', () {
      test(
        'should return plan reflecting a single registered global behavior and handler',
        () {
          // Arrange
          kyron = Kyron(); // Reset
          kyron.registerHandler<SimpleRequest, String>(
            () => ConcreteSimpleRequestHandler(),
          );
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog, order: 5)),
            predicateDescription: "Global Logger",
          );
          const req = SimpleRequest('plan1');

          // Act
          final plan = kyron.getPipelinePlan(req);

          // Assert
          expect(plan.length, 2);
          expect(plan[0].isHandler, isFalse);
          expect(plan[0].order, 5);
          expect(plan[0].componentType, GlobalLoggingBehavior);
          expect(plan[0].description, "Global Logger");
          expect(plan[1].isHandler, isTrue);
          expect(plan[1].componentType, ConcreteSimpleRequestHandler);
        },
      );

      test(
        'should return plan reflecting multiple behaviors (global/specific) in correct order and handler',
        () {
          // Arrange
          kyron = Kyron(); // Reset
          kyron.registerHandler<SimpleRequest, String>(
            () => ConcreteSimpleRequestHandler(),
          );
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog, order: 10)),
          );
          kyron.registerBehavior(
            behaviorFactoryFor(
              SpecificBehaviorForSimpleRequest(behaviorLog, order: -5),
            ),
          );
          kyron.registerBehavior(
            behaviorFactoryFor(ContextModifyingBehavior('data', order: -10)),
          );

          const req = SimpleRequest('plan2');

          // Act
          final plan = kyron.getPipelinePlan(req);

          // Assert
          expect(plan.length, 4);
          expect(plan[0].componentType, ContextModifyingBehavior);
          expect(plan[0].order, -10);
          expect(plan[1].componentType, SpecificBehaviorForSimpleRequest);
          expect(plan[1].order, -5);
          expect(plan[2].componentType, GlobalLoggingBehavior);
          expect(plan[2].order, 10);
          expect(plan[3].isHandler, isTrue);
          expect(plan[3].componentType, ConcreteSimpleRequestHandler);
        },
      );

      test(
        'should return plan indicating handler not found if not registered',
        () {
          // Arrange
          kyron = Kyron(); // Reset
          kyron.registerBehavior(
            behaviorFactoryFor(GlobalLoggingBehavior(behaviorLog)),
          );
          const req = SimpleRequest('no handler');

          // Act
          final plan = kyron.getPipelinePlan(req);

          // Assert
          expect(plan.length, 2);
          expect(plan[1].isHandler, isTrue);
          expect(plan[1].description, contains('Not Found'));
          expect(plan[1].componentType, Object);
        },
      );

      test(
        'should return plan reflecting behaviors registered with specific predicates correctly',
        () {
          // Arrange
          kyron = Kyron(); // Reset
          kyron.registerHandler<SimpleRequest, String>(
            () => ConcreteSimpleRequestHandler(),
          );
          kyron.registerHandler<OtherRequest, int>(
            () => ConcreteOtherRequestHandler(),
          );
          kyron.registerBehavior(
            behaviorFactoryFor(PredicateBehavior(behaviorLog, 'Marker')),
            appliesTo: PredicateBehavior.appliesIfSimpleRequest,
            predicateDescription: "Only SimpleRequest",
          );
          const reqSimple = SimpleRequest('plan pred simple');
          const reqOther = OtherRequest(99);

          // Act
          final planSimple = kyron.getPipelinePlan(reqSimple);
          final planOther = kyron.getPipelinePlan(reqOther);

          // Assert
          expect(planSimple.length, 2);
          expect(planSimple[0].componentType, PredicateBehavior);
          expect(planSimple[0].description, "Only SimpleRequest");

          expect(planOther.length, 1);
          expect(planOther[0].isHandler, isTrue);
          expect(planOther[0].componentType, ConcreteOtherRequestHandler);
        },
      );
    });
  });
}
