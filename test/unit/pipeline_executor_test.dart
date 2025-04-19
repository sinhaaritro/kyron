// test/unit/pipeline_executor_test.dart

import 'dart:async';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kyron/kyron.dart';
import 'package:kyron/src/pipeline_executor.dart';
import 'package:kyron/src/registry.dart';

import '../fixtures/test_data.dart';

// Mocks
class MockRequestHandler extends Mock
    implements RequestHandler<SimpleRequest, String> {}

class MockStreamRequestHandler extends Mock
    implements StreamRequestHandler<SimpleStreamRequest, int> {}

class MockBehavior extends Mock
    implements PipelineBehavior<BaseRequest, dynamic> {}

// Helper Functions
// Factory ONLY creates the mock instance. Stubbing is done in tests.
MockBehavior mockBehaviorFactory() {
  final behavior = MockBehavior();
  return behavior;
}

// Need to define BehaviorRegistration type locally if not exporting from registry.dart
typedef TestBehaviorRegistration =
    ({
      int order,
      BehaviorFactory factory,
      BehaviorPredicate predicate,
      String description,
    });

void main() {
  late PipelineExecutor executor;
  const int correlationId = 999;

  setUp(() {
    executor = PipelineExecutor();

    // Common stubs for mocks
    registerFallbackValue(const SimpleRequest('fallback'));
    registerFallbackValue(const SimpleStreamRequest(0));
    // Register fallback for REAL PipelineContext
    registerFallbackValue(PipelineContext(0));
    // Fallback for delegates/builders
    registerFallbackValue(() async => 'fallback_delegate_result');
    registerFallbackValue(() => Stream.value(1)); // Stream builder
    registerFallbackValue(
      () async* {
            yield 1;
          }
          as Stream<dynamic> Function(),
    ); // Async* function for stream handle (less common)
    registerFallbackValue(Stream.value(1)); // Stream instance
  });

  group('PipelineExecutor', () {
    group('instantiateBehaviors', () {
      // These tests focus only on instantiation and don't execute the delegate,
      // so no extra stubbing needed beyond the factory returning an instance.
      test(
        'should return an empty list when no registrations are provided',
        () {
          const request = SimpleRequest('test');
          final List<BehaviorRegistration> registrations = [];
          final behaviors = executor.instantiateBehaviors(
            request,
            registrations,
            correlationId,
          );
          expect(behaviors, isEmpty);
        },
      );

      test(
        'should instantiate a single behavior from its registration factory',
        () {
          const request = SimpleRequest('test');
          final mockBehaviorInstance = mockBehaviorFactory();
          factory() =>
              mockBehaviorInstance; // Factory returns the specific instance
          final registrations = [
            (
                  order: 10,
                  factory: factory,
                  predicate: (r) => true,
                  description: 'B1',
                )
                as BehaviorRegistration,
          ];
          final behaviors = executor.instantiateBehaviors(
            request,
            registrations,
            correlationId,
          );
          expect(behaviors.length, 1);
          expect(behaviors.first, same(mockBehaviorInstance));
        },
      );

      test(
        'should instantiate multiple behaviors from their registration factories',
        () {
          const request = SimpleRequest('test');
          // Create instances first ONLY if you need to check identity with same() later
          final mock1 = mockBehaviorFactory();
          final mock2 = mockBehaviorFactory();
          factory1() => mock1;
          factory2() => mock2;
          final registrations = [
            (
                  order: 10,
                  factory: factory1,
                  predicate: (r) => true,
                  description: 'B1',
                )
                as BehaviorRegistration,
            (
                  order: -5,
                  factory: factory2,
                  predicate: (r) => true,
                  description: 'B2',
                )
                as BehaviorRegistration,
          ];
          final behaviors = executor.instantiateBehaviors(
            request,
            registrations,
            correlationId,
          );
          expect(behaviors.length, 2);
          expect(behaviors, everyElement(isA<MockBehavior>()));
          // Optional: Check if specific instances were returned if needed
          // expect(behaviors, contains(same(mock1)));
          // expect(behaviors, contains(same(mock2)));
        },
      );

      test(
        'should throw MediatorConfigurationException if a behavior factory throws during instantiation',
        () {
          const request = SimpleRequest('test');
          factory() {
            throw Exception('Factory Boom!');
          }

          final registrations = [
            (
                  order: 0,
                  factory: factory,
                  predicate: (r) => true,
                  description: 'Failing',
                )
                as BehaviorRegistration,
          ];
          expect(
            () => executor.instantiateBehaviors(
              request,
              registrations,
              correlationId,
            ),
            throwsA(
              isA<MediatorConfigurationException>().having(
                (e) => e.message,
                'message',
                contains('Factory Boom!'),
              ),
            ),
            reason: 'Should wrap factory error in config exception',
          );
        },
      );

      test(
        'should throw MediatorConfigurationException if a behavior factory returns a non-PipelineBehavior object',
        () {
          const request = SimpleRequest('test');
          factory() => 'Not a behavior';
          final registrations = [
            (
                  order: 0,
                  factory: factory as BehaviorFactory,
                  predicate: (r) => true,
                  description: 'WrongType',
                )
                as BehaviorRegistration,
          ];
          expect(
            () => executor.instantiateBehaviors(
              request,
              registrations,
              correlationId,
            ),
            throwsA(
              isA<MediatorConfigurationException>().having(
                (e) => e.message,
                'message',
                contains('did not return an instance of PipelineBehavior'),
              ),
            ),
            reason: 'Should throw specific config error for wrong type',
          );
        },
      );
    });

    group('buildPipelineDelegate (for Future responses)', () {
      late MockRequestHandler mockHandler;
      const request = SimpleRequest('test');
      const expectedResult = 'Success';
      late PipelineContext testContext;

      setUp(() {
        mockHandler = MockRequestHandler();
        testContext = PipelineContext(correlationId);
        // Default handler stub
        when(
          () => mockHandler.handle(request, any(that: isA<PipelineContext>())),
        ).thenAnswer((_) async => expectedResult);
      });

      // This test doesn't execute the delegate, just builds it. No stubbing needed.
      test(
        'should return a delegate that executes only the handler when no behaviors exist',
        () async {
          final List<PipelineBehavior> behaviors = [];
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          // Act - Execute delegate
          final result = await delegate();
          // Assert
          expect(result, equals(expectedResult));
          verify(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).called(1);
        },
      );

      test(
        'should return a delegate that executes a single behavior wrapping the handler',
        () async {
          // Arrange
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final next =
                invocation.positionalArguments[2]
                    as RequestHandlerDelegate<String>;
            final result = await next();
            return 'Wrapped($result)';
          });
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final result = await delegate(); // Execute

          // Assert
          expect(result, equals('Wrapped($expectedResult)'));
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).called(1);
        },
      );

      test(
        'should return a delegate that executes multiple behaviors in reverse registration order (wrapping inward)',
        () async {
          // Arrange
          final behaviorOuter = mockBehaviorFactory();
          final behaviorInner = mockBehaviorFactory();
          when(() => behaviorOuter.order).thenReturn(-10);
          when(() => behaviorInner.order).thenReturn(10);
          when(
            () => behaviorOuter.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final next =
                invocation.positionalArguments[2]
                    as RequestHandlerDelegate<String>;
            final result = await next();
            return 'Outer($result)';
          });
          when(
            () => behaviorInner.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final next =
                invocation.positionalArguments[2]
                    as RequestHandlerDelegate<String>;
            final result = await next();
            return 'Inner($result)';
          });

          final List<PipelineBehavior> behaviors = [
            behaviorOuter,
            behaviorInner,
          ]; // Assumed sorted

          // Act
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final result = await delegate(); // Execute

          // Assert
          expect(result, equals('Outer(Inner($expectedResult))'));
          verify(
            () => behaviorOuter.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () => behaviorInner.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).called(1);
        },
      );

      test(
        'should correctly pass request and context to behaviors and handler',
        () async {
          // Arrange
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              any(),
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final nextDelegate =
                invocation.positionalArguments[2]
                    as RequestHandlerDelegate<String>;
            return await nextDelegate();
          });
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          await delegate(); // Execute

          // Assert
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).called(1);
        },
      );

      test(
        'delegate should return the handler\'s response when successful',
        () async {
          // Arrange
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            [],
            request,
            testContext,
            correlationId,
          );
          // Act
          final result = await delegate(); // Execute
          // Assert
          expect(result, equals(expectedResult));
        },
      );

      test(
        'delegate should return a behavior\'s response if it short-circuits by not calling next()',
        () async {
          // Arrange
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          const shortCircuitValue = 'ShortCircuitValue';
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((_) async => shortCircuitValue); // Doesn't call next
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final result = await delegate(); // Execute

          // Assert
          expect(result, equals(shortCircuitValue));
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verifyNever(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          );
        },
      );

      test(
        'delegate should throw PipelineExecutionException wrapping handler error',
        () async {
          // Arrange
          final handlerError = Exception('Handler Failed');
          when(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).thenThrow(handlerError);
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            [],
            request,
            testContext,
            correlationId,
          );

          // Act & Assert
          await expectLater(
            delegate(),
            throwsA(
              isA<PipelineExecutionException>().having(
                (e) => e.innerException,
                'innerException',
                handlerError,
              ),
              // ... other checks ...
            ),
            reason: 'Should wrap handler error in PipelineExecutionException',
          );
          verify(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).called(1);
        },
      );

      test(
        'delegate should throw PipelineExecutionException wrapping unexpected behavior error',
        () async {
          // Arrange
          final behaviorError = Exception('Behavior Failed');
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenThrow(behaviorError); // Throws directly
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );

          // Assert
          await expectLater(
            delegate(),
            throwsA(
              isA<PipelineExecutionException>()
                  .having(
                    (e) => e.innerException,
                    'innerException',
                    behaviorError,
                  )
                  .having(
                    (e) => e.originatingComponentType,
                    'originatingComponentType',
                    behavior.runtimeType,
                  ),
            ),
            reason: 'Should wrap behavior error in PipelineExecutionException',
          );
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verifyNever(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          );
        },
      );

      test(
        'delegate should rethrow ShortCircuitException thrown by a behavior',
        () async {
          // Arrange
          final shortCircuitError = MyCustomShortCircuit('Stop!');
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenThrow(shortCircuitError);
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );

          // Assert
          await expectLater(
            delegate(),
            throwsA(same(shortCircuitError)),
            reason: 'Should rethrow the exact ShortCircuitException instance',
          );
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verifyNever(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          );
        },
      );

      test(
        'delegate should rethrow PipelineExecutionException thrown by inner next() call',
        () async {
          // Arrange
          final handlerError = Exception('Handler Failed');
          final innerException = PipelineExecutionException(
            handlerError,
            StackTrace.current,
            mockHandler.runtimeType,
            request.runtimeType,
            correlationId,
          );
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final next =
                invocation.positionalArguments[2]
                    as RequestHandlerDelegate<String>;
            try {
              await next();
            } catch (e) {
              throw innerException;
            } // Rethrow simulated wrapped exception
            fail('Should have thrown');
          });
          final List<PipelineBehavior> behaviors = [behavior];
          when(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).thenThrow(handlerError);

          // Act
          final delegate = executor.buildPipelineDelegate<String>(
            mockHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );

          // Assert
          await expectLater(
            delegate(),
            throwsA(same(innerException)),
            reason:
                'Should rethrow the already wrapped exception from inner call',
          );
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () =>
                mockHandler.handle(request, any(that: isA<PipelineContext>())),
          ).called(1);
        },
      );
    });

    group('buildStreamPipelineDelegate (for Stream responses)', () {
      late MockStreamRequestHandler mockStreamHandler;
      const request = SimpleStreamRequest(3);
      final Stream<int> expectedStream = Stream.fromIterable([1, 2, 3]);
      late PipelineContext testContext;

      setUp(() {
        mockStreamHandler = MockStreamRequestHandler();
        testContext = PipelineContext(correlationId);
        // Default handler stub
        when(
          () => mockStreamHandler.handle(
            request,
            any(that: isA<PipelineContext>()),
          ),
        ).thenAnswer((_) => expectedStream);
      });

      // This test doesn't execute the delegate setup, just builds it. No stubbing needed.
      test(
        'should return a function that, when called, executes only the stream handler setup when no behaviors exist',
        () async {
          final List<PipelineBehavior> behaviors = [];
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          // Act
          final stream = builder(); // Execute setup
          // Assert
          await expectLater(stream, emitsInOrder([1, 2, 3, emitsDone]));
          await Future.delayed(Duration.zero);
          verify(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).called(1);
        },
      );

      test(
        'should return a function that executes setup of a single behavior wrapping the stream handler setup',
        () async {
          // Arrange
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final next =
                invocation.positionalArguments[2]
                    as Future<Stream<int>> Function();
            print("Behavior running before stream setup");
            return await next();
          });
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(stream, emitsInOrder([1, 2, 3, emitsDone]));
          await Future.delayed(Duration.zero);
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).called(1);
        },
      );

      test(
        'should return a function that executes setup of multiple behaviors wrapping the stream handler setup',
        () async {
          // Arrange
          final behaviorOuter = mockBehaviorFactory();
          final behaviorInner = mockBehaviorFactory();
          when(() => behaviorOuter.order).thenReturn(-10);
          when(() => behaviorInner.order).thenReturn(10);
          when(
            () => behaviorOuter.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            print("Outer behavior running");
            final next =
                invocation.positionalArguments[2]
                    as Future<Stream<int>> Function();
            return await next();
          });
          when(
            () => behaviorInner.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            print("Inner behavior running");
            final next =
                invocation.positionalArguments[2]
                    as Future<Stream<int>> Function();
            return await next();
          });

          final List<PipelineBehavior> behaviors = [
            behaviorOuter,
            behaviorInner,
          ]; // Assumed sorted

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(stream, emitsInOrder([1, 2, 3, emitsDone]));
          await Future.delayed(Duration.zero);
          verify(
            () => behaviorOuter.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () => behaviorInner.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).called(1);
        },
      );

      test(
        'function should correctly pass request and context to behaviors and handler during setup',
        () async {
          // Arrange
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              any(),
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final nextDelegate =
                invocation.positionalArguments[2]
                    as Future<Stream<int>> Function();
            return await nextDelegate();
          });
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup
          await stream.toList(); // Consume

          // Assert
          await Future.delayed(Duration.zero);
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).called(1);
        },
      );

      test(
        'function call should return the handler\'s stream when setup is successful',
        () async {
          // Arrange
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            [],
            request,
            testContext,
            correlationId,
          );
          // Act
          final stream = builder(); // Execute setup
          // Assert
          await expectLater(stream, emitsInOrder([1, 2, 3, emitsDone]));
        },
      );

      test(
        'function call should return a stream from a behavior if it short-circuits setup (returning stream)',
        () async {
          // Arrange
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          final shortCircuitStream = Stream.fromIterable([99, 98]);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer(
            (_) async => shortCircuitStream,
          ); // Return stream directly
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(
            stream,
            emitsInOrder([99, 98, emitsDone]),
            reason: 'Should emit the stream returned by the behavior',
          );
          await Future.delayed(Duration.zero);
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verifyNever(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          );
        },
      );

      test(
        'function call should return Stream.error if handler setup throws',
        () async {
          // Arrange
          final handlerError = Exception('Handler Stream Setup Failed');
          when(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).thenThrow(handlerError);
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            [],
            request,
            testContext,
            correlationId,
          );

          // Act
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(
            stream,
            emitsError(
              isA<PipelineExecutionException>().having(
                (e) => e.innerException,
                'innerException',
                handlerError,
              ),
            ),
            reason: 'Stream should emit wrapped handler error',
          );
          await Future.delayed(Duration.zero);
          verify(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).called(1);
        },
      );

      test(
        'function call should return Stream.error if unexpected behavior error occurs during setup',
        () async {
          // Arrange
          final behaviorError = Exception('Behavior Setup Failed');
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenThrow(behaviorError); // Throws directly
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(
            stream,
            emitsError(
              isA<PipelineExecutionException>().having(
                (e) => e.innerException,
                'innerException',
                behaviorError,
              ),
            ),
            reason: 'Stream should emit wrapped behavior error',
          );
          await Future.delayed(Duration.zero);
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verifyNever(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          );
        },
      );

      test(
        'function call should return Stream.error if behavior throws ShortCircuitException during setup',
        () async {
          // Arrange
          final shortCircuitError = MyCustomShortCircuit('Stop Stream Setup!');
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenThrow(shortCircuitError);
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(
            stream,
            emitsError(same(shortCircuitError)),
            reason: 'Stream should emit the ShortCircuitException',
          );
          await Future.delayed(Duration.zero);
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verifyNever(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          );
        },
      );

      test(
        'function call should return Stream.error if behavior returns non-Stream during setup',
        () async {
          // Arrange
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((_) async => 'Not a Stream'); // Return wrong type
          final List<PipelineBehavior> behaviors = [behavior];

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(
            stream,
            emitsError(
              isA<PipelineExecutionException>().having(
                (e) => e.innerException,
                'innerException',
                isA<MediatorConfigurationException>(),
              ),
            ), // Check inner exception type
            reason:
                'Stream should emit error indicating behavior returned wrong type',
          );
          await Future.delayed(Duration.zero);
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verifyNever(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          );
        },
      );

      test(
        'function call should return Stream.error if inner next() call fails during setup',
        () async {
          // Arrange
          final handlerError = Exception('Handler Setup Failed');
          final innerException = PipelineExecutionException(
            handlerError,
            StackTrace.current,
            mockStreamHandler.runtimeType,
            request.runtimeType,
            correlationId,
          );
          final behavior = mockBehaviorFactory();
          when(() => behavior.order).thenReturn(0);
          when(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).thenAnswer((invocation) async {
            final next =
                invocation.positionalArguments[2]
                    as Future<Stream<int>> Function();
            try {
              await next();
            } catch (e) {
              throw innerException;
            }
            fail('Should have thrown');
          });
          final List<PipelineBehavior> behaviors = [behavior];
          when(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).thenThrow(handlerError);

          // Act
          final builder = executor.buildStreamPipelineDelegate<int>(
            mockStreamHandler,
            behaviors,
            request,
            testContext,
            correlationId,
          );
          final stream = builder(); // Execute setup

          // Assert
          await expectLater(
            stream,
            emitsError(same(innerException)),
            reason:
                'Stream should emit the already wrapped exception from inner call',
          );
          await Future.delayed(Duration.zero);
          verify(
            () => behavior.handle(
              request,
              any(that: isA<PipelineContext>()),
              any(),
            ),
          ).called(1);
          verify(
            () => mockStreamHandler.handle(
              request,
              any(that: isA<PipelineContext>()),
            ),
          ).called(1);
        },
      );
    });

    // Groups for executeFuture and executeStream don't need behavior stubbing
    // as they test the execution wrappers, not the delegate building itself.
    group('executeFuture', () {
      test(
        'should execute the delegate and return its result on success',
        () async {
          const expected = 'Delegate Result';
          Future<String> mockDelegate() async => expected;
          final result = await executor.executeFuture<String>(
            mockDelegate,
            correlationId,
            SimpleRequest,
          );
          expect(result, equals(expected));
        },
      );

      test(
        'should rethrow PipelineExecutionException from the delegate',
        () async {
          final exception = PipelineExecutionException(
            Exception(),
            StackTrace.current,
            MockBehavior,
            SimpleRequest,
            correlationId,
          );
          Future<String> mockDelegate() async => throw exception;
          await expectLater(
            () => executor.executeFuture<String>(
              mockDelegate,
              correlationId,
              SimpleRequest,
            ),
            throwsA(same(exception)),
          );
        },
      );

      test('should rethrow ShortCircuitException from the delegate', () async {
        final exception = MyCustomShortCircuit('Stop!');
        Future<String> mockDelegate() async => throw exception;
        await expectLater(
          () => executor.executeFuture<String>(
            mockDelegate,
            correlationId,
            SimpleRequest,
          ),
          throwsA(same(exception)),
        );
      });

      test('should rethrow other exceptions from the delegate', () async {
        final exception = ArgumentError('Bad arg');
        Future<String> mockDelegate() async => throw exception;
        await expectLater(
          () => executor.executeFuture<String>(
            mockDelegate,
            correlationId,
            SimpleRequest,
          ),
          throwsA(same(exception)),
        );
      });
    });

    group('executeStream', () {
      test(
        'should call the builder function and return its stream on success',
        () {
          final expectedStream = Stream.value(1);
          Stream<int> mockBuilder() => expectedStream;
          final stream = executor.executeStream<int>(
            mockBuilder,
            correlationId,
            SimpleStreamRequest,
          );
          expect(stream, same(expectedStream));
        },
      );

      test(
        'should return Stream.error if the builder function throws synchronously',
        () {
          final exception = Exception('Builder Failed Sync');
          Stream<int> mockBuilder() {
            throw exception;
          }

          final stream = executor.executeStream<int>(
            mockBuilder,
            correlationId,
            SimpleStreamRequest,
          );
          expectLater(stream, emitsError(same(exception)));
        },
      );
    });
  });
}
