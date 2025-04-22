// test/unit/kyron_base_test.dart

import 'dart:async';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kyron/kyron.dart';
import 'package:kyron/src/notification_dispatcher.dart';
import 'package:kyron/src/registry.dart';
import 'package:kyron/src/pipeline_component_info.dart';

// Import mocks and test data
import '../fixtures/mock_components.dart';
import '../fixtures/test_data.dart';
import '../fixtures/mock_handlers.dart';
import '../fixtures/mock_behaviors.dart';

// Type Aliases for Factories (Matching Kyron's expectations)
typedef TestReqHandlerFactory =
    RequestHandler<SimpleRequest, String> Function();
typedef TestStreamReqHandlerFactory =
    StreamRequestHandler<SimpleStreamRequest, int> Function();
typedef TestBehaviorFactory = PipelineBehavior<dynamic, dynamic> Function();
typedef TestNotificationHandlerFactory =
    NotificationHandler<SimpleNotification> Function();

void main() {
  late Kyron kyron;
  late MockKyronRegistry mockRegistry;
  late MockPipelineExecutor mockExecutor;
  late MockNotificationDispatcher mockDispatcher;

  // Mocks for Handlers/Behaviors used in tests
  late MockSimpleRequestHandler mockSimpleHandler;
  late MockSimpleStreamRequestHandler mockSimpleStreamHandler;
  late MockBehavior mockBehavior1;
  late MockBehavior mockBehavior2;
  late MockSimpleNotificationHandler mockNotificationHandler;
  late MockStringNotificationHandler mockStringHandler;
  late MockIntNotificationHandler mockIntHandler;
  late MockCustomObjectHandler mockCustomObjectHandler;

  // OUTER setUp: Initializes mocks and performs general setup
  setUp(() {
    // Initialize ALL mocks FIRST
    mockRegistry = MockKyronRegistry();
    mockExecutor = MockPipelineExecutor();
    mockDispatcher = MockNotificationDispatcher();
    mockSimpleHandler = MockSimpleRequestHandler();
    mockSimpleStreamHandler = MockSimpleStreamRequestHandler();
    mockBehavior1 = MockBehavior();
    mockBehavior2 = MockBehavior();
    mockNotificationHandler = MockSimpleNotificationHandler();
    mockStringHandler = MockStringNotificationHandler();
    mockIntHandler = MockIntNotificationHandler();
    mockCustomObjectHandler = MockCustomObjectHandler();

    // THEN Register Fallback Values using initialized mocks
    registerFallbackValue(SimpleRequest);
    registerFallbackValue(SimpleStreamRequest);
    registerFallbackValue(SimpleNotification);
    registerFallbackValue(const SimpleRequest('fallback'));
    registerFallbackValue(const SimpleStreamRequest(0));
    registerFallbackValue(const SimpleNotification('fallback'));
    registerFallbackValue('fallback_string');
    registerFallbackValue(0);
    registerFallbackValue(const CustomPlainObject(0, 'fallback'));
    registerFallbackValue(const UnhandledObject('fallback'));
    registerFallbackValue(mockStringHandler);
    registerFallbackValue(mockIntHandler);
    registerFallbackValue(mockCustomObjectHandler);
    registerFallbackValue(<List<NotificationHandlerRegistration>>[]);
    registerFallbackValue(<BehaviorRegistration>[]);
    registerFallbackValue(<NotificationHandlerRegistration>[]);
    registerFallbackValue(PipelineContext(0));
    registerFallbackValue(mockSimpleHandler);
    registerFallbackValue(mockSimpleStreamHandler);
    registerFallbackValue(mockBehavior1);
    registerFallbackValue(mockNotificationHandler);
    registerFallbackValue(<PipelineBehavior>[]);
    registerFallbackValue(() async => 'fallback_delegate');
    registerFallbackValue(() => Stream.value('fallback_stream_builder'));
    registerFallbackValue(NotificationErrorStrategy.continueOnError);
    registerFallbackValue(() => MockSimpleRequestHandler());
    registerFallbackValue(() => MockBehavior());
    registerFallbackValue(() => MockSimpleNotificationHandler());
    registerFallbackValue(() => mockStringHandler);
    registerFallbackValue(() => mockIntHandler);
    registerFallbackValue(() => mockCustomObjectHandler);

    // THEN Setup Kyron instance
    kyron = Kyron(
      registry: mockRegistry,
      executor: mockExecutor,
      dispatcher: mockDispatcher,
    );

    // THEN Setup Default Stubbing using initialized mocks
    when(() => mockRegistry.findHandlerFactory(any())).thenReturn(null);
    when(() => mockRegistry.findStreamHandlerFactory(any())).thenReturn(null);
    when(
      () => mockRegistry.findApplicableBehaviorRegistrations(any()),
    ).thenReturn([]);
    when(
      () => mockRegistry.findNotificationHandlerRegistrations(any()),
    ).thenReturn([]);
    when(
      () => mockExecutor.instantiateBehaviors(any(), any(), any()),
    ).thenReturn([]);
    when(
      () => mockExecutor.buildPipelineDelegate<dynamic>(
        any(),
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenReturn(() async => 'default_delegate_result');
    when(
      () => mockExecutor.buildStreamPipelineDelegate<dynamic>(
        any(),
        any(),
        any(),
        any(),
        any(),
      ),
    ).thenReturn(() => Stream.value('default_stream_delegate_result'));
    when(
      () => mockExecutor.executeFuture<dynamic>(any(), any(), any()),
    ).thenAnswer(
      (inv) async => await (inv.positionalArguments[0] as Function)(),
    );
    when(
      () => mockExecutor.executeStream<dynamic>(any(), any(), any()),
    ).thenAnswer((inv) => (inv.positionalArguments[0] as Function)());
    when(
      () => mockDispatcher.dispatch(
        any(),
        any(),
        correlationId: any(named: 'correlationId'),
      ),
    ).thenAnswer((_) async {});
  });

  group('Kyron Core (kyron_base.dart)', () {
    group('Constructor', () {
      test(
        'should use default registry, executor, and dispatcher if none provided',
        () {
          // Arrange & Act
          final defaultKyron = Kyron();
          // Assert
          expect(defaultKyron.registry, isA<KyronRegistry>());
        },
      );

      test('should use provided registry instance', () {
        // Arrange (Outer setUp)
        // Act (implicit in arrange)
        // Assert
        expect(kyron.registry, same(mockRegistry));
      });

      test('should use provided executor instance', () {
        // Arrange
        const request = SimpleRequest('test');
        factory() => mockSimpleHandler;
        when(
          () => mockRegistry.findHandlerFactory(SimpleRequest),
        ).thenReturn(factory);
        when(
          () => mockExecutor.instantiateBehaviors(any(), any(), any()),
        ).thenReturn([]);
        when(
          () => mockExecutor.buildPipelineDelegate<String>(
            any(),
            any(),
            any(),
            any(),
            any(),
          ),
        ).thenReturn(() async => 'ok');
        when(
          () => mockExecutor.executeFuture<String>(any(), any(), any()),
        ).thenAnswer((_) async => 'ok');

        // Act
        kyron.send(request);

        // Assert
        verify(
          () => mockExecutor.instantiateBehaviors(request, any(), any()),
        ).called(1);
      });

      test('should use provided dispatcher instance', () {
        // Arrange
        const notification = SimpleNotification('test');
        factory() => mockNotificationHandler;
        final regs = [
          (factory: factory, order: 0) as NotificationHandlerRegistration,
        ];
        when(
          () => mockRegistry.findNotificationHandlerRegistrations(
            SimpleNotification,
          ),
        ).thenReturn(regs);

        // Act
        kyron.publish(notification);

        // Assert
        verify(
          () => mockDispatcher.dispatch(
            notification,
            regs,
            correlationId: any(named: 'correlationId'),
          ),
        ).called(1);
      });

      test(
        'should configure dispatcher with specified NotificationErrorStrategy',
        () {
          // Arrange
          const strategy = NotificationErrorStrategy.collectErrors;
          final dispatcherUsed = NotificationDispatcher(
            errorStrategy: strategy,
          );
          final mockReg = MockKyronRegistry();
          final testKyron = Kyron(
            registry: mockReg,
            dispatcher: dispatcherUsed,
          );
          final handlerError = Exception('fail');
          failingFactory() {
            final handler = MockSimpleNotificationHandler();
            when(() => handler.handle(any())).thenThrow(handlerError);
            return handler;
          }

          final regs = [
            (factory: failingFactory, order: 0)
                as NotificationHandlerRegistration,
          ];
          when(
            () => mockReg.findNotificationHandlerRegistrations(
              SimpleNotification,
            ),
          ).thenReturn(regs);

          // Act & Assert
          expect(
            () => testKyron.publish(const SimpleNotification('go')),
            throwsA(isA<AggregateException>()),
          );
        },
      );

      test('registry getter should return the internal registry instance', () {
        // Arrange (Outer setUp)
        // Act
        final registryInstance = kyron.registry;
        // Assert
        expect(registryInstance, same(mockRegistry));
      });
    });

    group('Registration Methods', () {
      test('registerHandler should delegate to registry.registerHandler', () {
        // Arrange
        factory() => mockSimpleHandler;
        // Act
        kyron.registerHandler<SimpleRequest, String>(factory);
        // Assert
        verify(
          () => mockRegistry.registerHandler<SimpleRequest, String>(factory),
        ).called(1);
      });

      test(
        'registerHandler should wrap non-config registry errors in MediatorConfigurationException',
        () {
          // Arrange
          final registryError = Exception('Registry Boom!');
          factory() => mockSimpleHandler;
          when(
            () => mockRegistry.registerHandler<SimpleRequest, String>(factory),
          ).thenThrow(registryError);
          // Act & Assert
          expect(
            () => kyron.registerHandler<SimpleRequest, String>(factory),
            throwsA(
              isA<MediatorConfigurationException>().having(
                (e) => e.message,
                'message',
                contains('Registry Boom!'),
              ),
            ),
          );
        },
      );

      test(
        'registerStreamHandler should delegate to registry.registerStreamHandler',
        () {
          // Arrange
          factory() => mockSimpleStreamHandler;
          // Act
          kyron.registerStreamHandler<SimpleStreamRequest, int>(factory);
          // Assert
          verify(
            () => mockRegistry.registerStreamHandler<SimpleStreamRequest, int>(
              factory,
            ),
          ).called(1);
        },
      );

      test(
        'registerStreamHandler should wrap non-config registry errors in MediatorConfigurationException',
        () {
          // Arrange
          final registryError = Exception('Stream Registry Boom!');
          factory() => mockSimpleStreamHandler;
          when(
            () => mockRegistry.registerStreamHandler<SimpleStreamRequest, int>(
              factory,
            ),
          ).thenThrow(registryError);
          // Act & Assert
          expect(
            () =>
                kyron.registerStreamHandler<SimpleStreamRequest, int>(factory),
            throwsA(
              isA<MediatorConfigurationException>().having(
                (e) => e.message,
                'message',
                contains('Stream Registry Boom!'),
              ),
            ),
          );
        },
      );

      test('registerBehavior should delegate to registry.registerBehavior', () {
        // Arrange
        factory() => mockBehavior1;
        bool applies(BaseRequest r) => true;
        const desc = 'Test Desc';
        const order = 55;
        // Act
        kyron.registerBehavior(
          factory,
          appliesTo: applies,
          predicateDescription: desc,
          orderOverride: order,
        );
        // Assert
        verify(
          () => mockRegistry.registerBehavior<BaseRequest, dynamic>(
            factory,
            appliesTo: applies,
            predicateDescription: desc,
            orderOverride: order,
          ),
        ).called(1);
      });

      test(
        'registerBehavior should wrap non-config registry errors in MediatorConfigurationException',
        () {
          // Arrange
          final registryError = Exception('Behavior Registry Boom!');
          factory() => mockBehavior1;
          when(
            () => mockRegistry.registerBehavior<BaseRequest, dynamic>(
              factory,
              appliesTo: any(named: 'appliesTo'),
              predicateDescription: any(named: 'predicateDescription'),
              orderOverride: any(named: 'orderOverride'),
            ),
          ).thenThrow(registryError);
          // Act & Assert
          expect(
            () => kyron.registerBehavior(factory),
            throwsA(
              isA<MediatorConfigurationException>().having(
                (e) => e.message,
                'message',
                contains('Behavior Registry Boom!'),
              ),
            ),
          );
        },
      );

      test(
        'registerNotificationHandler should delegate to registry.registerNotificationHandler',
        () {
          // Arrange
          factory() => mockNotificationHandler;
          const order = 10;
          // Act
          kyron.registerNotificationHandler<SimpleNotification>(
            factory,
            order: order,
          );
          // Assert
          // Verify registry call with the correct type argument
          verify(
            () => mockRegistry.registerNotificationHandler<SimpleNotification>(
              factory,
              order: order,
            ),
          ).called(1);
        },
      );

      test(
        'registerNotificationHandler should wrap non-config registry errors in MediatorConfigurationException',
        () {
          // Arrange
          final registryError = Exception('Notification Registry Boom!');
          factory() => mockNotificationHandler;
          when(
            () => mockRegistry.registerNotificationHandler<SimpleNotification>(
              factory,
              order: any(named: 'order'),
            ),
          ).thenThrow(registryError);
          // Act & Assert
          expect(
            () =>
                kyron.registerNotificationHandler<SimpleNotification>(factory),
            throwsA(
              isA<MediatorConfigurationException>().having(
                (e) => e.message,
                'message',
                contains('Notification Registry Boom!'),
              ),
            ),
          );
        },
      );

      test(
        'should handle publishing plain String if handler registered',
        () async {
          // Arrange
          const message = 'Plain string event';
          stringFactory() => mockStringHandler;
          final regs = [
            (factory: stringFactory, order: 0)
                as NotificationHandlerRegistration,
          ];

          when(
            () => mockRegistry.findNotificationHandlerRegistrations(String),
          ).thenReturn(regs); // Stub registry for String type
          when(
            () => mockDispatcher.dispatch<String>(
              message,
              regs,
              correlationId: any(named: 'correlationId'),
            ),
          ).thenAnswer((_) async {}); // Stub dispatcher for String type

          // Act
          await kyron.publish<String>(message); // Explicit type for clarity

          // Assert
          verify(
            () => mockRegistry.findNotificationHandlerRegistrations(String),
          ).called(1);
          verify(
            () => mockDispatcher.dispatch<String>(
              message,
              regs,
              correlationId: any(named: 'correlationId'),
            ),
          ).called(1);
        },
      );

      test(
        'should handle publishing custom plain object if handler registered',
        () async {
          // Arrange
          const customObject = CustomPlainObject(42, 'data');
          customFactory() => mockCustomObjectHandler;
          final regs = [
            (factory: customFactory, order: 0)
                as NotificationHandlerRegistration,
          ];

          when(
            () => mockRegistry.findNotificationHandlerRegistrations(
              CustomPlainObject,
            ),
          ).thenReturn(regs); // Stub registry for CustomPlainObject type
          when(
            () => mockDispatcher.dispatch<CustomPlainObject>(
              customObject,
              regs,
              correlationId: any(named: 'correlationId'),
            ),
          ).thenAnswer(
            (_) async {},
          ); // Stub dispatcher for CustomPlainObject type

          // Act
          await kyron.publish(customObject); // Type inferred

          // Assert
          verify(
            () => mockRegistry.findNotificationHandlerRegistrations(
              CustomPlainObject,
            ),
          ).called(1);
          verify(
            () => mockDispatcher.dispatch<CustomPlainObject>(
              customObject,
              regs,
              correlationId: any(named: 'correlationId'),
            ),
          ).called(1);
        },
      );

      test(
        'should complete silently if publishing an object with no registered handlers',
        () async {
          // Arrange
          const unhandled = UnhandledObject('no handler for this');
          // Default registry stub returns []
          when(
            () => mockRegistry.findNotificationHandlerRegistrations(
              UnhandledObject,
            ),
          ).thenReturn([]); // Explicitly stub empty list

          // Act & Assert
          await expectLater(kyron.publish(unhandled), completes);

          // Assert registry was checked but dispatcher was not called
          verify(
            () => mockRegistry.findNotificationHandlerRegistrations(
              UnhandledObject,
            ),
          ).called(1);
          verifyNever(
            () => mockDispatcher.dispatch(
              any(),
              any(),
              correlationId: any(named: 'correlationId'),
            ),
          );
        },
      );
    });

    // ** GROUP: send<TResponse> **
    group('send<TResponse>', () {
      // Arrange (variables needed across tests)
      const request = SimpleRequest('data');
      const expectedResponse = 'Response Data';
      handlerFactory() => mockSimpleHandler;
      behaviorFactory() => mockBehavior1;
      late List<BehaviorRegistration> behaviorRegs;
      late List<PipelineBehavior> instantiatedBehaviors;
      late RequestHandlerDelegate<String> finalDelegate;

      setUp(() {
        // Arrange (specific to this group)
        behaviorRegs = [
          (
                order: 0,
                factory: behaviorFactory,
                predicate: (_) => true,
                description: 'B1',
              )
              as BehaviorRegistration,
        ];
        instantiatedBehaviors = [mockBehavior1];
        finalDelegate = () async => expectedResponse;

        when(
          () => mockRegistry.findHandlerFactory(SimpleRequest),
        ).thenReturn(handlerFactory);
        when(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).thenReturn(behaviorRegs);
        when(
          () => mockExecutor.instantiateBehaviors(request, behaviorRegs, any()),
        ).thenReturn(instantiatedBehaviors);
        when(
          () => mockExecutor.buildPipelineDelegate<String>(
            mockSimpleHandler,
            instantiatedBehaviors,
            request,
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).thenReturn(finalDelegate);
        when(
          () => mockExecutor.executeFuture<String>(
            finalDelegate,
            any(),
            SimpleRequest,
          ),
        ).thenAnswer((_) async => expectedResponse);
        when(() => mockBehavior1.order).thenReturn(0);
        when(
          () => mockBehavior1.handle(
            any(),
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).thenAnswer(
          (inv) async => await (inv.positionalArguments[2] as Function)(),
        );
      });

      test('should find handler factory using registry', () async {
        // Arrange (in setUp)
        // Act
        await kyron.send(request);
        // Assert
        verify(() => mockRegistry.findHandlerFactory(SimpleRequest)).called(1);
      });
      test(
        'should throw UnregisteredHandlerException if registry returns null factory',
        () async {
          // Arrange
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(null);
          // Act & Assert
          await expectLater(
            () => kyron.send(request),
            throwsA(isA<UnregisteredHandlerException>()),
          );
        },
      );
      test('should create PipelineContext', () async {
        // Arrange (in setUp)
        // Act
        await kyron.send(request);
        // Assert
        verify(
          () => mockExecutor.buildPipelineDelegate<String>(
            any(),
            any(),
            any(),
            any(
              that: isA<PipelineContext>().having(
                (c) => c.correlationId,
                'correlationId',
                request.hashCode,
              ),
            ),
            any(),
          ),
        ).called(1);
      });
      test('should find applicable behaviors using registry', () async {
        // Arrange (in setUp)
        // Act
        await kyron.send(request);
        // Assert
        verify(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).called(1);
      });

      test('should sort applicable behaviors by order', () async {
        // Arrange
        factory1() => mockBehavior1;
        factory2() => mockBehavior2;
        final regUnsorted = [
          (
                order: 10,
                factory: factory1,
                predicate: (_) => true,
                description: 'B10',
              )
              as BehaviorRegistration,
          (
                order: -5,
                factory: factory2,
                predicate: (_) => true,
                description: 'B-5',
              )
              as BehaviorRegistration,
        ];
        when(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).thenReturn(regUnsorted);
        when(() => mockBehavior1.order).thenReturn(10);
        when(() => mockBehavior1.handle(any(), any(), any())).thenAnswer(
          (inv) async => await (inv.positionalArguments[2] as Function)(),
        );
        when(() => mockBehavior2.order).thenReturn(-5);
        when(() => mockBehavior2.handle(any(), any(), any())).thenAnswer(
          (inv) async => await (inv.positionalArguments[2] as Function)(),
        );
        when(
          () => mockExecutor.instantiateBehaviors(
            request,
            any(that: isA<List<BehaviorRegistration>>()),
            any(),
          ),
        ).thenReturn([mockBehavior2, mockBehavior1]); // Return sorted instances
        when(
          () => mockExecutor.buildPipelineDelegate<String>(
            any(),
            [mockBehavior2, mockBehavior1],
            any(),
            any(),
            any(),
          ),
        ).thenReturn(finalDelegate); // Expect sorted instances

        // Act
        await kyron.send(request);

        // Assert
        verify(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).called(1);
        final captured =
            verify(
              () => mockExecutor.instantiateBehaviors(
                request,
                captureAny(),
                any(),
              ),
            ).captured;
        expect(captured.length, 1);
        final capturedList = captured.first as List<BehaviorRegistration>;
        expect(capturedList.length, 2);
        expect(capturedList[0].order, -5);
        expect(capturedList[1].order, 10);
      });

      test('should instantiate behaviors using executor', () async {
        // Arrange (in setUp)
        // Act
        await kyron.send(request);
        // Assert
        verify(
          () => mockExecutor.instantiateBehaviors(request, behaviorRegs, any()),
        ).called(1);
      });
      test(
        'should throw MediatorConfigurationException if behavior instantiation fails',
        () async {
          // Arrange
          final configError = MediatorConfigurationException(
            'Behavior Factory Failed',
          );
          when(
            () =>
                mockExecutor.instantiateBehaviors(request, behaviorRegs, any()),
          ).thenThrow(configError);
          // Act & Assert
          await expectLater(
            () => kyron.send(request),
            throwsA(same(configError)),
          );
        },
      );

      test('should instantiate handler using factory', () async {
        // Arrange
        bool factoryCalled = false;
        factoryWithCheck() {
          factoryCalled = true;
          return mockSimpleHandler;
        }

        when(
          () => mockRegistry.findHandlerFactory(SimpleRequest),
        ).thenReturn(factoryWithCheck);
        when(
          () => mockExecutor.buildPipelineDelegate<String>(
            mockSimpleHandler,
            instantiatedBehaviors,
            request,
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).thenReturn(finalDelegate); // Re-stub for specific handler instance

        // Act
        await kyron.send(request);

        // Assert
        expect(factoryCalled, isTrue);
        verify(
          () => mockExecutor.buildPipelineDelegate<String>(
            mockSimpleHandler,
            any(),
            any(),
            any(),
            any(),
          ),
        ).called(1);
      });

      test(
        'should throw MediatorConfigurationException if handler factory throws',
        () async {
          // Arrange
          final factoryError = Exception('Handler Factory Failed');
          failingFactory() {
            throw factoryError;
          }

          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(failingFactory);
          // Act & Assert
          await expectLater(
            () => kyron.send(request),
            throwsA(
              isA<MediatorConfigurationException>().having(
                (e) => e.message,
                'message',
                contains('Handler Factory Failed'),
              ),
            ),
          );
        },
      );
      test('should build pipeline delegate using executor', () async {
        // Arrange (in setUp)
        // Act
        await kyron.send(request);
        // Assert
        verify(
          () => mockExecutor.buildPipelineDelegate<String>(
            mockSimpleHandler,
            instantiatedBehaviors,
            request,
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).called(1);
      });
      test('should execute future pipeline using executor', () async {
        // Arrange (in setUp)
        // Act
        await kyron.send(request);
        // Assert
        verify(
          () => mockExecutor.executeFuture<String>(
            finalDelegate,
            any(),
            SimpleRequest,
          ),
        ).called(1);
      });
      test(
        'should return the result from executor executeFuture on success',
        () async {
          // Arrange (in setUp)
          // Act
          final result = await kyron.send(request);
          // Assert
          expect(result, equals(expectedResponse));
        },
      );
      test(
        'should rethrow UnregisteredHandlerException from registry lookup',
        () async {
          // Arrange
          final exception = UnregisteredHandlerException(SimpleRequest);
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenThrow(exception);
          // Act & Assert
          await expectLater(
            () => kyron.send(request),
            throwsA(same(exception)),
          );
        },
      );
      test(
        'should rethrow MediatorConfigurationException from instantiation',
        () async {
          // Arrange
          final exception = MediatorConfigurationException('Config Fail');
          when(
            () => mockExecutor.instantiateBehaviors(request, any(), any()),
          ).thenThrow(exception);
          // Act & Assert
          await expectLater(
            () => kyron.send(request),
            throwsA(same(exception)),
          );
        },
      );
      test('should rethrow PipelineExecutionException from executor', () async {
        // Arrange
        final exception = PipelineExecutionException(
          Exception(),
          StackTrace.current,
          MockBehavior,
          SimpleRequest,
          123,
        );
        when(
          () => mockExecutor.executeFuture<String>(any(), any(), any()),
        ).thenThrow(exception);
        // Act & Assert
        await expectLater(() => kyron.send(request), throwsA(same(exception)));
      });
      test('should rethrow ShortCircuitException from executor', () async {
        // Arrange
        final exception = MyCustomShortCircuit('stop');
        when(
          () => mockExecutor.executeFuture<String>(any(), any(), any()),
        ).thenThrow(exception);
        // Act & Assert
        await expectLater(() => kyron.send(request), throwsA(same(exception)));
      });
      test('should rethrow unexpected errors during orchestration', () async {
        // Arrange
        final error = StateError('Bad state');
        when(
          () => mockRegistry.findHandlerFactory(SimpleRequest),
        ).thenThrow(error);
        // Act & Assert
        await expectLater(() => kyron.send(request), throwsA(same(error)));
      });
    });

    // ** GROUP: stream<TResponse> **
    group('stream<TResponse>', () {
      // Arrange (variables needed across tests)
      const request = SimpleStreamRequest(3);
      final expectedStream = Stream.fromIterable([1, 2, 3]);
      handlerFactory() => mockSimpleStreamHandler;
      behaviorFactory() => mockBehavior1;
      late List<BehaviorRegistration> behaviorRegs;
      late List<PipelineBehavior> instantiatedBehaviors;
      late Stream<int> Function() streamBuilder;

      setUp(() {
        // Arrange (specific to this group)
        behaviorRegs = [
          (
                order: 0,
                factory: behaviorFactory,
                predicate: (_) => true,
                description: 'B1',
              )
              as BehaviorRegistration,
        ];
        instantiatedBehaviors = [mockBehavior1];
        streamBuilder = () => expectedStream;

        when(
          () => mockRegistry.findStreamHandlerFactory(SimpleStreamRequest),
        ).thenReturn(handlerFactory);
        when(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).thenReturn(behaviorRegs);
        when(
          () => mockExecutor.instantiateBehaviors(request, behaviorRegs, any()),
        ).thenReturn(instantiatedBehaviors);
        when(
          () => mockExecutor.buildStreamPipelineDelegate<int>(
            mockSimpleStreamHandler,
            instantiatedBehaviors,
            request,
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).thenReturn(streamBuilder);
        when(
          () => mockExecutor.executeStream<int>(
            streamBuilder,
            any(),
            SimpleStreamRequest,
          ),
        ).thenAnswer((inv) => streamBuilder());
        when(() => mockBehavior1.order).thenReturn(0);
        when(
          () => mockBehavior1.handle(
            any(),
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).thenAnswer(
          (inv) async =>
              await (inv.positionalArguments[2]
                  as Future<Stream<int>> Function())(),
        ); // Correct return type for stream handle stub
      });

      test('should find stream handler factory using registry', () {
        // Arrange (in setUp)
        // Act
        kyron.stream(request);
        // Assert
        verify(
          () => mockRegistry.findStreamHandlerFactory(SimpleStreamRequest),
        ).called(1);
      });
      test(
        'should return Stream.error with UnregisteredHandlerException if registry returns null factory',
        () {
          // Arrange
          when(
            () => mockRegistry.findStreamHandlerFactory(SimpleStreamRequest),
          ).thenReturn(null);
          // Act
          final stream = kyron.stream(request);
          // Assert
          expectLater(stream, emitsError(isA<UnregisteredHandlerException>()));
        },
      );
      test('should create PipelineContext', () {
        // Arrange (in setUp)
        // Act
        kyron.stream(request);
        // Assert
        verify(
          () => mockExecutor.buildStreamPipelineDelegate<int>(
            any(),
            any(),
            any(),
            any(
              that: isA<PipelineContext>().having(
                (c) => c.correlationId,
                'correlationId',
                request.hashCode,
              ),
            ),
            any(),
          ),
        ).called(1);
      });
      test('should find applicable behaviors using registry', () {
        // Arrange (in setUp)
        // Act
        kyron.stream(request);
        // Assert
        verify(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).called(1);
      });

      test('should sort applicable behaviors by order', () {
        // Arrange
        factory1() => mockBehavior1;
        factory2() => mockBehavior2;
        final regUnsorted = [
          (
                order: 10,
                factory: factory1,
                predicate: (_) => true,
                description: 'B10',
              )
              as BehaviorRegistration,
          (
                order: -5,
                factory: factory2,
                predicate: (_) => true,
                description: 'B-5',
              )
              as BehaviorRegistration,
        ];
        when(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).thenReturn(regUnsorted);
        when(() => mockBehavior1.order).thenReturn(10);
        when(() => mockBehavior1.handle(any(), any(), any())).thenAnswer(
          (inv) async =>
              await (inv.positionalArguments[2]
                  as Future<Stream<int>> Function())(),
        );
        when(() => mockBehavior2.order).thenReturn(-5);
        when(() => mockBehavior2.handle(any(), any(), any())).thenAnswer(
          (inv) async =>
              await (inv.positionalArguments[2]
                  as Future<Stream<int>> Function())(),
        );
        when(
          () => mockExecutor.instantiateBehaviors(
            request,
            any(that: isA<List<BehaviorRegistration>>()),
            any(),
          ),
        ).thenReturn([mockBehavior2, mockBehavior1]); // Return sorted instances
        when(
          () => mockExecutor.buildStreamPipelineDelegate<int>(
            any(),
            [mockBehavior2, mockBehavior1],
            any(),
            any(),
            any(),
          ),
        ).thenReturn(streamBuilder); // Expect sorted instances

        // Act
        kyron.stream(request);

        // Assert
        final captured =
            verify(
              () => mockExecutor.instantiateBehaviors(
                request,
                captureAny(),
                any(),
              ),
            ).captured;
        expect(captured.length, 1);
        final capturedList = captured.first as List<BehaviorRegistration>;
        expect(capturedList.length, 2);
        expect(capturedList[0].order, -5);
        expect(capturedList[1].order, 10);
      });

      test('should instantiate behaviors using executor', () {
        // Arrange (in setUp)
        // Act
        kyron.stream(request);
        // Assert
        verify(
          () => mockExecutor.instantiateBehaviors(request, behaviorRegs, any()),
        ).called(1);
      });
      test(
        'should return Stream.error with MediatorConfigurationException if behavior instantiation fails',
        () {
          // Arrange
          final configError = MediatorConfigurationException('Fail');
          when(
            () => mockExecutor.instantiateBehaviors(request, any(), any()),
          ).thenThrow(configError);
          // Act
          final stream = kyron.stream(request);
          // Assert
          expectLater(stream, emitsError(same(configError)));
        },
      );

      test('should instantiate stream handler using factory', () {
        // Arrange
        bool factoryCalled = false;
        factoryWithCheck() {
          factoryCalled = true;
          return mockSimpleStreamHandler;
        }

        when(
          () => mockRegistry.findStreamHandlerFactory(SimpleStreamRequest),
        ).thenReturn(factoryWithCheck);
        when(
          () => mockExecutor.buildStreamPipelineDelegate<int>(
            mockSimpleStreamHandler,
            instantiatedBehaviors,
            request,
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).thenReturn(streamBuilder);

        // Act
        kyron.stream(request);

        // Assert
        expect(factoryCalled, isTrue);
        verify(
          () => mockExecutor.buildStreamPipelineDelegate<int>(
            mockSimpleStreamHandler,
            any(),
            any(),
            any(),
            any(),
          ),
        ).called(1);
      });

      test(
        'should return Stream.error with MediatorConfigurationException if handler factory throws',
        () {
          // Arrange
          final factoryError = Exception('Fail');
          StreamRequestHandler<SimpleStreamRequest, int> failingFactory() {
            throw factoryError;
          }

          when(
            () => mockRegistry.findStreamHandlerFactory(SimpleStreamRequest),
          ).thenReturn(failingFactory);
          // Act
          final stream = kyron.stream(request);
          // Assert
          expectLater(
            stream,
            emitsError(isA<MediatorConfigurationException>()),
          );
        },
      );
      test('should build stream pipeline delegate builder using executor', () {
        // Arrange (in setUp)
        // Act
        kyron.stream(request);
        // Assert
        verify(
          () => mockExecutor.buildStreamPipelineDelegate<int>(
            mockSimpleStreamHandler,
            instantiatedBehaviors,
            request,
            any(that: isA<PipelineContext>()),
            any(),
          ),
        ).called(1);
      });
      test('should execute stream pipeline using executor', () {
        // Arrange (in setUp)
        // Act
        kyron.stream(request);
        // Assert
        verify(
          () => mockExecutor.executeStream<int>(
            streamBuilder,
            any(),
            SimpleStreamRequest,
          ),
        ).called(1);
      });
      test(
        'should return the stream from executor executeStream on success',
        () {
          // Arrange (in setUp)
          // Act
          final stream = kyron.stream(request);
          // Assert
          expect(stream, isA<Stream<int>>());
          expectLater(stream, emitsInOrder([1, 2, 3, emitsDone]));
        },
      );
      test(
        'should return Stream.error for synchronous UnregisteredHandlerException',
        () {
          // Arrange
          when(
            () => mockRegistry.findStreamHandlerFactory(SimpleStreamRequest),
          ).thenReturn(null);
          // Act
          final stream = kyron.stream(request);
          // Assert
          expectLater(stream, emitsError(isA<UnregisteredHandlerException>()));
        },
      );
      test(
        'should return Stream.error for synchronous MediatorConfigurationException',
        () {
          // Arrange
          final configError = MediatorConfigurationException('Fail');
          when(
            () => mockExecutor.instantiateBehaviors(request, any(), any()),
          ).thenThrow(configError);
          // Act
          final stream = kyron.stream(request);
          // Assert
          expectLater(stream, emitsError(same(configError)));
        },
      );
      test(
        'should return Stream.error for other synchronous orchestration errors',
        () {
          // Arrange
          final error = StateError('Fail');
          when(
            () => mockRegistry.findStreamHandlerFactory(SimpleStreamRequest),
          ).thenThrow(error);
          // Act
          final stream = kyron.stream(request);
          // Assert
          expectLater(stream, emitsError(same(error)));
        },
      );
    });

    // ** GROUP: publish **
    group('publish<TNotification>', () {
      // Arrange (variables needed across tests)
      const notification = SimpleNotification('Event');
      factory() => mockNotificationHandler;
      late List<NotificationHandlerRegistration> handlerRegs;

      setUp(() {
        // Arrange (specific to this group)
        handlerRegs = [
          (factory: factory, order: 0) as NotificationHandlerRegistration,
        ];
        when(
          () => mockRegistry.findNotificationHandlerRegistrations(
            SimpleNotification,
          ),
        ).thenReturn(handlerRegs);
        when(
          () => mockDispatcher.dispatch(
            notification,
            handlerRegs,
            correlationId: any(named: 'correlationId'),
          ),
        ).thenAnswer((_) async {});
      });

      test(
        'should find notification handler registrations using registry',
        () async {
          // Arrange
          const notification = SimpleNotification('Event');

          // Act
          await kyron.publish(notification);

          // Assert
          verify(
            () => mockRegistry.findNotificationHandlerRegistrations(
              SimpleNotification,
            ),
          ).called(1);
        },
      );

      test('should return early if no handlers are found', () async {
        // Arrange
        const notification = SimpleNotification('nothing');
        // Default registry stub returns []
        when(
          () => mockRegistry.findNotificationHandlerRegistrations(
            SimpleNotification,
          ),
        ).thenReturn([]);

        // Act
        await kyron.publish(notification);

        // Assert
        verifyNever(
          () => mockDispatcher.dispatch(
            // Use dispatch<dynamic> if type is unknown or not verifiable here
            any(), // Match any object
            any(),
            correlationId: any(named: 'correlationId'),
          ),
        );
      });

      test('should sort handler registrations by order', () async {
        // Arrange
        const notification = SimpleNotification('Sort test');
        factory1() => mockNotificationHandler;
        factory2() => mockNotificationHandler;
        final regUnsorted = [
          (factory: factory1, order: 10) as NotificationHandlerRegistration,
          (factory: factory2, order: -5) as NotificationHandlerRegistration,
        ];
        when(
          () => mockRegistry.findNotificationHandlerRegistrations(
            SimpleNotification,
          ),
        ).thenReturn(regUnsorted);
        // Stub the dispatch call with the specific type
        when(
          () => mockDispatcher.dispatch<SimpleNotification>(
            notification,
            any(that: isA<List<NotificationHandlerRegistration>>()),
            correlationId: any(named: 'correlationId'),
          ),
        ).thenAnswer((_) async {});

        // Act
        await kyron.publish(notification);

        // Assert
        // Capture the sorted list passed to the dispatcher
        final captured =
            verify(
              () => mockDispatcher.dispatch<SimpleNotification>(
                notification,
                captureAny(),
                correlationId: any(named: 'correlationId'),
              ),
            ).captured;
        expect(captured.length, 1);
        final capturedList =
            captured.first as List<NotificationHandlerRegistration>;
        expect(capturedList.length, 2);
        expect(
          capturedList[0].order,
          -5,
          reason: 'Should be sorted ascending by order',
        );
        expect(
          capturedList[1].order,
          10,
          reason: 'Should be sorted ascending by order',
        );
      });

      test(
        'should delegate dispatching to the NotificationDispatcher',
        () async {
          // Arrange
          const notification = SimpleNotification('Event');
          // handlerRegs already set up in outer setUp

          // Act
          await kyron.publish(notification);

          // Assert
          // Verify dispatch with the specific type
          verify(
            () => mockDispatcher.dispatch<SimpleNotification>(
              notification,
              handlerRegs,
              correlationId: any(named: 'correlationId'),
            ),
          ).called(1);
        },
      );

      test(
        'should pass notification and sorted registrations to dispatcher',
        () async {
          // Arrange
          const notification = SimpleNotification('Event');
          // handlerRegs already set up in outer setUp

          // Act
          await kyron.publish(notification);

          // Assert
          // Verify dispatch with the specific type and captured list
          final captured =
              verify(
                () => mockDispatcher.dispatch<SimpleNotification>(
                  notification, // Verify specific notification object
                  captureAny(), // Capture the list
                  correlationId: any(named: 'correlationId'),
                ),
              ).captured;
          expect(
            captured.single,
            equals(handlerRegs),
            reason: 'Should pass the correct registrations list',
          );
        },
      );

      test(
        'should rethrow AggregateException if dispatcher throws it',
        () async {
          // Arrange
          const notification = SimpleNotification('Error test');
          final exception = AggregateException([]);
          // Stub dispatch with the specific type
          when(
            () => mockDispatcher.dispatch<SimpleNotification>(
              any(that: isA<SimpleNotification>()),
              any(),
              correlationId: any(named: 'correlationId'),
            ),
          ).thenThrow(exception);

          // Act & Assert
          await expectLater(
            () => kyron.publish(notification),
            throwsA(same(exception)),
          );
        },
      );

      test('should handle other dispatcher errors gracefully', () async {
        // Arrange
        const notification = SimpleNotification('Other error test');
        final error = Exception('Dispatcher Fail');
        // Stub dispatch with the specific type
        when(
          () => mockDispatcher.dispatch<SimpleNotification>(
            any(that: isA<SimpleNotification>()),
            any(),
            correlationId: any(named: 'correlationId'),
          ),
        ).thenThrow(error);

        // Act & Assert
        await expectLater(kyron.publish(notification), completes);
        // Verify dispatch was still called
        verify(
          () => mockDispatcher.dispatch<SimpleNotification>(
            notification,
            handlerRegs,
            correlationId: any(named: 'correlationId'),
          ),
        ).called(1);
      });
    });

    // ** GROUP: getPipelinePlan **
    group('getPipelinePlan', () {
      // Arrange (variables needed across tests)
      const request = SimpleRequest('plan');

      // --- Define factories that return NEW concrete instances ---
      // Use the actual typedefs expected by the registry/kyron
      concreteHandlerFactory() => PlanTestHandler();
      // Factory function that takes parameters to create specific instances
      PipelineBehavior<dynamic, dynamic> Function() concreteBehaviorFactory(
        int order, {
        String id = 'B',
      }) => () => PlanTestBehavior(order: order, id: id);
      // Factory function that throws for error testing
      failingBehaviorFactory() {
        throw Exception('Behavior Factory Instantiation Fail');
      }

      failingHandlerFactory() {
        throw Exception('Handler Factory Instantiation Fail');
      }

      // No nested setUp for mocks needed here, tests will stub registry directly

      test('should find applicable behaviors using registry', () {
        // Arrange
        final behaviorReg =
            (
                  order: 10,
                  factory: concreteBehaviorFactory(10, id: 'B10'),
                  predicate: (BaseRequest r) => true,
                  description: 'Reg B10',
                )
                as BehaviorRegistration;
        when(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).thenReturn([behaviorReg]);
        when(() => mockRegistry.findHandlerFactory(SimpleRequest)).thenReturn(
          concreteHandlerFactory,
        ); // Need a handler for a complete plan
        when(
          () => mockRegistry.findStreamHandlerFactory(any()),
        ).thenReturn(null);
      });

      test('should find applicable behaviors using registry', () {
        // Arrange (in setUp)
        // Act
        kyron.getPipelinePlan(request);
        // Assert
        verify(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).called(1);
      });

      test(
        'should sort applicable behaviors by order in the returned plan',
        () {
          // Arrange
          final behaviorReg10 =
              (
                    order: 10,
                    factory: concreteBehaviorFactory(10, id: 'B10'),
                    predicate: (_) => true,
                    description: 'Reg B10',
                  )
                  as BehaviorRegistration;
          final behaviorRegNeg5 =
              (
                    order: -5,
                    factory: concreteBehaviorFactory(-5, id: 'B-5'),
                    predicate: (_) => true,
                    description: 'Reg B-5',
                  )
                  as BehaviorRegistration;
          when(
            () => mockRegistry.findApplicableBehaviorRegistrations(request),
          ).thenReturn([behaviorReg10, behaviorRegNeg5]);

          // Act
          final plan = kyron.getPipelinePlan(request);

          // Assert
          expect(
            plan.length,
            3,
            reason: 'Plan should include 2 behaviors and 1 handler',
          );
          // Check the order of the non-handler components in the plan
          expect(
            plan.where((p) => !p.isHandler).first.order,
            -5,
            reason: 'First behavior in plan should have order -5',
          );
          expect(
            plan.where((p) => !p.isHandler).last.order,
            10,
            reason: 'Second behavior in plan should have order 10',
          );
        },
      );

      test(
        'should attempt to instantiate behaviors to get type/description (handle errors)',
        () {
          // Arrange
          final successReg =
              (
                    order: 10,
                    factory: concreteBehaviorFactory(10, id: 'B10'),
                    predicate: (_) => true,
                    description: 'Reg B10',
                  )
                  as BehaviorRegistration;
          final failingReg =
              (
                    order: 5,
                    factory: failingBehaviorFactory,
                    predicate: (_) => true,
                    description: 'Failing',
                  )
                  as BehaviorRegistration;
          when(
            () => mockRegistry.findApplicableBehaviorRegistrations(request),
          ).thenReturn([successReg, failingReg]); // Mix success and failure
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(concreteHandlerFactory);
          when(
            () => mockRegistry.findStreamHandlerFactory(any()),
          ).thenReturn(null);

          // Act
          final plan = kyron.getPipelinePlan(request);

          // Assert
          final successfulPlanItem = plan.firstWhere((p) => p.order == 10);
          expect(
            successfulPlanItem.componentType,
            PlanTestBehavior,
            reason: 'Successful behavior type should be concrete type',
          );
          expect(
            successfulPlanItem.description,
            'Reg B10',
            reason:
                'Successful behavior description should be from registration',
          );

          final failingPlanItem = plan.firstWhere((p) => p.order == 5);
          expect(failingPlanItem.componentType, dynamic);
          expect(failingPlanItem.description, contains('Failing'));
          expect(plan.length, 3);
        },
      );

      test('should find handler factory (Request or Stream) using registry', () {
        // Arrange
        when(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).thenReturn([]); // No behaviors needed
        when(
          () => mockRegistry.findHandlerFactory(SimpleRequest),
        ).thenReturn(concreteHandlerFactory); // Stub findHandlerFactory
        // when(() => mockRegistry.findStreamHandlerFactory(any())).thenReturn(null);

        // Act
        kyron.getPipelinePlan(request);

        // Assert
        verify(() => mockRegistry.findHandlerFactory(SimpleRequest)).called(1);
        // verify(() => mockRegistry.findStreamHandlerFactory(SimpleRequest)).called(1);
      });

      test(
        'should attempt to instantiate handler to get type/description (handle errors)',
        () {
          // Arrange
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(failingHandlerFactory); // Use failing factory
          when(
            () => mockRegistry.findApplicableBehaviorRegistrations(request),
          ).thenReturn([]); // No behaviors

          // Act
          final plan = kyron.getPipelinePlan(request);

          // Assert
          expect(
            plan.length,
            1,
            reason: 'Plan should only contain the handler placeholder',
          );
          final handlerPlanItem = plan.first;
          expect(handlerPlanItem.isHandler, isTrue);
          expect(
            handlerPlanItem.componentType,
            dynamic,
            reason: 'Type should be dynamic on factory error',
          );
          expect(
            handlerPlanItem.description,
            contains('Instantiation Failed'),
            reason: 'Description should indicate factory error',
          );
        },
      );

      test(
        'should return list of PipelineComponentInfo for behaviors and handler',
        () {
          // Arrange
          final behaviorReg =
              (
                    order: 10,
                    factory: concreteBehaviorFactory(10, id: 'B10'),
                    predicate: (_) => true,
                    description: 'Reg B10',
                  )
                  as BehaviorRegistration;
          when(
            () => mockRegistry.findApplicableBehaviorRegistrations(request),
          ).thenReturn([behaviorReg]);
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(concreteHandlerFactory);
          when(
            () => mockRegistry.findStreamHandlerFactory(any()),
          ).thenReturn(null);

          // Act
          final plan = kyron.getPipelinePlan(request);
          // Assert
          expect(plan, isA<List<PipelineComponentInfo>>());
          expect(plan.length, 2, reason: 'Should have 1 behavior + 1 handler');
        },
      );

      test(
        'should include correct order, type, description, and isHandler flag',
        () {
          // Arrange
          final testOrder = 15;
          final testDesc = 'My Behavior Reg';
          final behaviorReg =
              (
                    order: testOrder,
                    factory: concreteBehaviorFactory(testOrder, id: 'B15'),
                    predicate: (_) => true,
                    description: testDesc,
                  )
                  as BehaviorRegistration;
          when(
            () => mockRegistry.findApplicableBehaviorRegistrations(request),
          ).thenReturn([behaviorReg]);
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(concreteHandlerFactory);
          when(
            () => mockRegistry.findStreamHandlerFactory(any()),
          ).thenReturn(null);

          // Act
          final plan = kyron.getPipelinePlan(request);

          // Assert
          expect(plan.length, 2);
          final behaviorPlan = plan.firstWhere((p) => !p.isHandler);
          final handlerPlan = plan.firstWhere((p) => p.isHandler);

          expect(
            behaviorPlan.order,
            testOrder,
            reason: 'Behavior order should match registration',
          );
          expect(
            behaviorPlan.componentType,
            PlanTestBehavior,
            reason: 'Behavior type should be concrete type',
          );
          expect(
            behaviorPlan.description,
            testDesc,
            reason: 'Behavior description should match registration',
          );
          expect(
            behaviorPlan.isHandler,
            isFalse,
            reason: 'Behavior isHandler flag should be false',
          );

          expect(
            handlerPlan.order,
            99999,
            reason: 'Handler order should be default',
          );
          expect(
            handlerPlan.componentType,
            PlanTestHandler,
            reason: 'Handler type should be concrete type',
          );
          expect(
            handlerPlan.description,
            equals('PlanTestHandler'),
            reason: 'Handler description should be type name',
          );
          expect(
            handlerPlan.isHandler,
            isTrue,
            reason: 'Handler isHandler flag should be true',
          );
        },
      );

      test('should handle case where no handler is found', () {
        // Arrange
        final behaviorReg =
            (
                  order: 10,
                  factory: concreteBehaviorFactory(10, id: 'B10'),
                  predicate: (_) => true,
                  description: 'Reg B10',
                )
                as BehaviorRegistration;
        when(
          () => mockRegistry.findApplicableBehaviorRegistrations(request),
        ).thenReturn([behaviorReg]);
        when(
          () => mockRegistry.findHandlerFactory(SimpleRequest),
        ).thenReturn(null); // No handler found
        when(
          () => mockRegistry.findStreamHandlerFactory(SimpleRequest),
        ).thenReturn(null); // No stream handler found

        // Act
        final plan = kyron.getPipelinePlan(request);

        // Assert
        expect(
          plan.length,
          2,
          reason: 'Plan should have behavior + handler placeholder',
        );
        final handlerPlanItem = plan.firstWhere((p) => p.isHandler);
        expect(
          handlerPlanItem.componentType,
          Object,
          reason: 'Placeholder type should be Object',
        );
        expect(
          handlerPlanItem.description,
          contains('Not Found'),
          reason: 'Placeholder description',
        );
      });

      test(
        'should handle errors during behavior finding/instantiation gracefully in plan',
        () {
          // Arrange
          final failingReg =
              (
                    order: 5,
                    factory: failingBehaviorFactory,
                    predicate: (_) => true,
                    description: 'Failing',
                  )
                  as BehaviorRegistration;
          when(
            () => mockRegistry.findApplicableBehaviorRegistrations(request),
          ).thenReturn([failingReg]); // Only the failing one
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(null); // No handler

          // Act
          final plan = kyron.getPipelinePlan(request);

          // Assert
          expect(
            plan.length,
            2,
            reason: 'Plan should have failing behavior + handler placeholder',
          );
          expect(
            plan.where((p) => !p.isHandler).length,
            1,
            reason: 'Should include one non-handler item',
          );
          expect(
            plan.firstWhere((p) => !p.isHandler).componentType,
            dynamic,
            reason: 'Failing behavior type should be dynamic',
          );
          expect(
            plan.firstWhere((p) => p.isHandler).description,
            contains('Not Found'),
          );
        },
      );

      test(
        'should handle errors during handler finding/instantiation gracefully in plan',
        () {
          // Arrange
          when(
            () => mockRegistry.findHandlerFactory(SimpleRequest),
          ).thenReturn(failingHandlerFactory); // Use failing factory
          when(
            () => mockRegistry.findApplicableBehaviorRegistrations(request),
          ).thenReturn([]); // No behaviors
          when(
            () => mockRegistry.findStreamHandlerFactory(any()),
          ).thenReturn(null);

          // Act
          final plan = kyron.getPipelinePlan(request);

          // Assert
          expect(
            plan.length,
            1,
            reason: 'Plan should only have the failing handler placeholder',
          );
          expect(
            plan.where((p) => p.isHandler).length,
            1,
            reason: 'The single item should be a handler placeholder',
          );
          expect(
            plan.firstWhere((p) => p.isHandler).componentType,
            dynamic,
            reason: 'Failing handler type should be dynamic',
          );
          expect(
            plan.firstWhere((p) => p.isHandler).description,
            contains('Instantiation Failed'),
          );
        },
      );
    });
  });
}
