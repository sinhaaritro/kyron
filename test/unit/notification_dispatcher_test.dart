// test/unit/notification_dispatcher_test.dart

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kyron/kyron.dart';
import 'package:kyron/src/notification_dispatcher.dart';
import 'package:kyron/src/registry.dart';

import '../fixtures/test_data.dart';

// Mocks
class MockHandlerA extends Mock
    implements NotificationHandler<SimpleNotification> {}

class MockHandlerB extends Mock
    implements NotificationHandler<SimpleNotification> {}

class MockHandlerC extends Mock
    implements NotificationHandler<SimpleNotification> {}

void main() {
  late NotificationDispatcher dispatcher;
  // Declare mocks at this level
  late MockHandlerA handlerA;
  late MockHandlerB handlerB;
  late MockHandlerC handlerC;
  late SimpleNotification notification;
  const correlationId = 111;

  // These now depend on handlerA, handlerB, handlerC being initialized
  MockHandlerA handlerAFactory() => handlerA;
  MockHandlerB handlerBFactory() => handlerB;
  MockHandlerC handlerCFactory() => handlerC;

  // Helper to create registrations easily
  List<NotificationHandlerRegistration> createRegs(
    List<({NotificationHandlerFactory factory, int order})> handlers,
  ) {
    // Cast to the specific tuple type expected by the dispatcher
    return handlers.map((h) => (factory: h.factory, order: h.order)).toList();
  }

  setUp(() {
    // Initialize mocks here
    handlerA = MockHandlerA();
    handlerB = MockHandlerB();
    handlerC = MockHandlerC();
    notification = const SimpleNotification('Test');

    // Default stubs for successful handling on THESE instances
    when(() => handlerA.handle(notification)).thenAnswer((_) async {});
    when(() => handlerB.handle(notification)).thenAnswer((_) async {});
    when(() => handlerC.handle(notification)).thenAnswer((_) async {});

    // Default dispatcher (ContinueOnError)
    dispatcher = NotificationDispatcher();

    // Common fallback needed if notification object itself is checked with any() etc.
    registerFallbackValue(notification);
    registerFallbackValue(() => MockHandlerA());
  });

  group('NotificationDispatcher', () {
    group('dispatch (Strategy: continueOnError - Default)', () {
      test(
        'should complete normally when no handlers are registered',
        () async {
          // Arrange
          final registrations = createRegs([]);
          const notification = SimpleNotification('Test');

          // Act & Assert
          await expectLater(
            dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
          );
        },
      );

      test('should execute a single registered handler successfully', () async {
        // Arrange
        const notification = SimpleNotification('Test');
        final registrations = createRegs([
          (factory: handlerAFactory, order: 0),
        ]);

        // Act
        await dispatcher.dispatch<SimpleNotification>(
          notification,
          registrations,
          correlationId: correlationId,
        );

        // Assert
        verify(() => handlerA.handle(notification)).called(1);
      });

      test(
        'should execute multiple registered handlers successfully in specified order',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final registrations = createRegs([
            (factory: handlerBFactory, order: 10), // B runs first
            (factory: handlerAFactory, order: 20), // A runs second
          ]);

          // Act
          await dispatcher.dispatch<SimpleNotification>(
            notification,
            registrations,
            correlationId: correlationId,
          );

          // Assert
          verifyInOrder([
            () => handlerB.handle(notification),
            () => handlerA.handle(notification),
          ]);
        },
      );

      test(
        'should execute remaining handlers if one handler throws an exception',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final error = Exception('Handler A Failed');
          when(() => handlerA.handle(notification)).thenThrow(error);
          final registrations = createRegs([
            (factory: handlerAFactory, order: 10), // Throws
            (factory: handlerBFactory, order: 20), // Should still run
          ]);

          // Act
          await expectLater(
            dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
          );

          // Assert
          verify(() => handlerA.handle(notification)).called(1);
          verify(() => handlerB.handle(notification)).called(1);
        },
      );

      test(
        'should execute remaining handlers if multiple handlers throw exceptions',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final errorA = Exception('Handler A Failed');
          final errorC = Exception('Handler C Failed');
          when(() => handlerA.handle(notification)).thenThrow(errorA);
          when(() => handlerC.handle(notification)).thenThrow(errorC);

          final registrations = createRegs([
            (factory: handlerAFactory, order: 10), // Throws
            (factory: handlerBFactory, order: 20), // Runs
            (factory: handlerCFactory, order: 30), // Throws
          ]);

          // Act
          await expectLater(
            dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
          );

          // Assert
          verify(() => handlerA.handle(notification)).called(1);
          verify(() => handlerB.handle(notification)).called(1);
          verify(() => handlerC.handle(notification)).called(1);
        },
      );

      test(
        'should complete normally even if handlers throw exceptions',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final errorA = Exception('Handler A Failed');
          when(() => handlerA.handle(notification)).thenThrow(errorA);
          final registrations = createRegs([
            (factory: handlerAFactory, order: 10),
          ]);

          // Act & Assert
          await expectLater(
            dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
            reason:
                'dispatch should complete successfully with continueOnError strategy',
          );
        },
      );

      test(
        'should handle error during handler instantiation gracefully and continue',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          NotificationHandler<SimpleNotification> failingFactoryA() {
            throw Exception('Factory A Boom!');
          }

          final registrations = createRegs([
            (factory: failingFactoryA, order: 10), // Fails instantiation
            (factory: handlerBFactory, order: 20), // Should still run
          ]);

          // Act
          await expectLater(
            dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
          );

          // Assert
          verifyNever(() => handlerA.handle(notification));
          verify(() => handlerB.handle(notification)).called(1);
        },
      );
    });

    group('dispatch (Strategy: collectErrors)', () {
      setUp(() {
        dispatcher = NotificationDispatcher(
          errorStrategy: NotificationErrorStrategy.collectErrors,
        );
      });

      test(
        'should complete normally when no handlers are registered',
        () async {
          // Arrange
          final registrations = createRegs([]);

          // Arrange
          await expectLater(
            dispatcher.dispatch(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
          );
        },
      );

      test(
        'should execute a single handler successfully and complete normally',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final registrations = createRegs([
            (factory: handlerAFactory, order: 0),
          ]);

          // Act & Assert
          await expectLater(
            dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
          );
          verify(() => handlerA.handle(notification)).called(1);
        },
      );

      test(
        'should execute multiple handlers successfully and complete normally',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final registrations = createRegs([
            (factory: handlerBFactory, order: 10),
            (factory: handlerAFactory, order: 20),
          ]);

          // Act & Assert
          await expectLater(
            dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            completes,
          );
          verifyInOrder([
            () => handlerB.handle(notification),
            () => handlerA.handle(notification),
          ]);
        },
      );

      test(
        'should execute all handlers even if one throws, then throw AggregateException',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final errorA = Exception('Handler A Failed');
          when(() => handlerA.handle(notification)).thenThrow(errorA);
          final registrations = createRegs([
            (factory: handlerAFactory, order: 10), // Throws
            (factory: handlerBFactory, order: 20), // Should still run
          ]);

          // Act & Assert
          await expectLater(
            () => dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            throwsA(
              isA<AggregateException>().having(
                (e) => e.innerExceptions,
                'innerExceptions',
                [same(errorA)],
              ),
            ),
            reason: 'Should throw AggregateException with the error from A',
          );

          verify(() => handlerA.handle(notification)).called(1);
          verify(() => handlerB.handle(notification)).called(1);
        },
      );

      test(
        'should execute all handlers even if multiple throw, then throw AggregateException with all errors',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final errorA = Exception('Handler A Failed');
          final errorC = Exception('Handler C Failed');
          when(() => handlerA.handle(notification)).thenThrow(errorA);
          when(() => handlerC.handle(notification)).thenThrow(errorC);
          final registrations = createRegs([
            (factory: handlerAFactory, order: 10), // Throws
            (factory: handlerBFactory, order: 20), // Runs
            (factory: handlerCFactory, order: 30), // Throws
          ]);

          // Act & Assert
          await expectLater(
            () => dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            throwsA(
              isA<AggregateException>().having(
                (e) => e.innerExceptions,
                'innerExceptions',
                [same(errorA), same(errorC)],
              ),
            ),
            reason: 'Should throw AggregateException with errors from A and C',
          );

          verify(() => handlerA.handle(notification)).called(1);
          verify(() => handlerB.handle(notification)).called(1);
          verify(() => handlerC.handle(notification)).called(1);
        },
      );

      test(
        'should throw AggregateException if handler instantiation fails',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final errorFactoryA = Exception('Factory A Boom!');
          NotificationHandler<SimpleNotification> factoryA() {
            throw errorFactoryA;
          }

          final registrations = createRegs([
            (factory: factoryA, order: 10), // Fails instantiation
            (factory: handlerBFactory, order: 20), // Should still run
          ]);

          // Act & Assert
          await expectLater(
            () => dispatcher.dispatch<SimpleNotification>(
              notification,
              registrations,
              correlationId: correlationId,
            ),
            throwsA(
              isA<AggregateException>().having(
                (e) => e.innerExceptions,
                'innerExceptions',
                [same(errorFactoryA)],
              ),
            ),
            reason: 'Should throw AggregateException with the factory error',
          );

          verifyNever(() => handlerA.handle(notification));
          verify(() => handlerB.handle(notification)).called(1);
        },
      );

      test(
        'should ensure handlers are executed in specified order before collecting errors',
        () async {
          // Arrange
          const notification = SimpleNotification('Test'); // Use plain class
          final errorB = Exception('Handler B Failed');
          when(() => handlerB.handle(notification)).thenThrow(errorB);
          final registrations = createRegs([
            (factory: handlerBFactory, order: 10), // Throws first
            (factory: handlerAFactory, order: 20), // Runs second
          ]);

          // Act & Assert
          await expectLater(
            () => dispatcher.dispatch<SimpleNotification>(
              // Call with type argument
              notification,
              registrations,
              correlationId: correlationId,
            ),
            throwsA(
              isA<AggregateException>().having(
                (e) => e.innerExceptions,
                'innerExceptions',
                [same(errorB)],
              ),
            ),
            reason:
                'Should throw AggregateException containing only B\'s error',
          );

          verifyInOrder([
            () => handlerB.handle(notification), // Attempted first
            () => handlerA.handle(notification), // Attempted second
          ]);
        },
      );
    });

    group('General Behavior', () {
      test(
        'should pass the correct notification object to each handler',
        () async {
          // Arrange
          const notification = SimpleNotification('Test');
          final registrations = createRegs([
            (factory: handlerAFactory, order: 0),
            (factory: handlerBFactory, order: 0),
          ]);

          // Act
          await dispatcher.dispatch<SimpleNotification>(
            notification,
            registrations,
            correlationId: correlationId,
          );

          // Assert
          verify(() => handlerA.handle(notification)).called(1);
          verify(() => handlerB.handle(notification)).called(1);
        },
      );
    });
  });
}
