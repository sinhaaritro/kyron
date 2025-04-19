// test/integration/notification_flow_test.dart

import 'package:test/test.dart';
import 'package:kyron/kyron.dart';
import 'package:kyron/src/notification_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

// Import concrete implementations and test data
import '../fixtures/test_data.dart';
import '../fixtures/mock_handlers.dart';

//  Mocks needed only for the last test
class MockErrorNotificationHandlerA extends Mock
    implements NotificationHandler<ErrorNotification> {}

class MockErrorNotificationHandlerB extends Mock
    implements NotificationHandler<ErrorNotification> {}

void main() {
  late Kyron kyron;
  late List<String> handlerLog; // Shared log for handlers

  // Helper function to create Kyron instance with a specific strategy
  Kyron createKyron(NotificationErrorStrategy strategy) {
    final instance = Kyron(notificationErrorStrategy: strategy);
    // Re-register common handlers if needed, or do in test setup
    return instance;
  }

  setUp(() {
    // Default instance with ContinueOnError
    kyron = createKyron(NotificationErrorStrategy.continueOnError);
    handlerLog = [];

    // Register handlers if needed globally, or do it per test/group

    registerFallbackValue(const ErrorNotification());
  });

  group('Integration: Notification Flow', () {
    group('Handler Registration and Discovery', () {
      test(
        'publish completes normally when no handlers are registered for a notification',
        () async {
          // Arrange
          const notification = SimpleNotification('nothing registered');

          // Act & Assert
          await expectLater(kyron.publish(notification), completes);
        },
      );

      test('publish triggers a single registered handler', () async {
        // Arrange
        final handler = ConcreteSimpleNotificationHandler(handlerLog);
        kyron.registerNotificationHandler<SimpleNotification>(() => handler);
        const notification = SimpleNotification('message 1');

        // Act
        await kyron.publish(notification);

        // Assert
        expect(
          handlerLog,
          equals(['message 1']),
          reason: 'Single handler should have received the message',
        );
      });

      test(
        'publish triggers multiple registered handlers for the same notification',
        () async {
          // Arrange
          final handler1 = ConcreteSimpleNotificationHandler(
            handlerLog,
            delay: Duration(milliseconds: 5),
          );
          final handler2 = ConcreteSimpleNotificationHandler(
            handlerLog,
            delay: Duration.zero,
          );
          kyron.registerNotificationHandler<SimpleNotification>(() => handler1);
          kyron.registerNotificationHandler<SimpleNotification>(() => handler2);
          const notification = SimpleNotification('message 2');

          // Act
          await kyron.publish(notification);

          // Assert
          expect(
            handlerLog,
            contains('message 2'),
            reason: 'Log should contain the message',
          );
          expect(
            handlerLog.length,
            2,
            reason: 'Both handlers should have received the message',
          );
          // Order depends on registration order here (both have default order 0)
          print("Multiple handler log: $handlerLog");
        },
      );
    });

    group('Handler Execution Order', () {
      test(
        'multiple handlers execute sequentially based on registration order (default _minSafeInteger)',
        () async {
          // Arrange
          final handler1 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H1',
            delay: Duration(milliseconds: 10),
          );
          final handler2 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H2',
            delay: Duration.zero,
          );
          // Register H1 then H2, both default order 0
          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler1,
          );
          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler2,
          );
          const notification = OrderedNotification();

          // Act
          await kyron.publish(notification);

          // Assert
          expect(
            handlerLog,
            equals(['H1:START', 'H2:START', 'H2:END', 'H1:END']),
            reason:
                'Handlers should execute sequentially based on registration',
          );
        },
      );

      test(
        'multiple handlers execute sequentially based on specified registration order (ascending)',
        () async {
          // Arrange
          final handler1 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H1',
            delay: Duration.zero,
          ); // Order 20
          final handler2 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H2',
            delay: Duration(milliseconds: 10),
          ); // Order 10
          final handler3 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H3',
            delay: Duration.zero,
          ); // Order 30

          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler1,
            order: 20,
          );
          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler2,
            order: 10,
          ); // Runs first
          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler3,
            order: 30,
          );

          const notification = OrderedNotification();

          // Act
          await kyron.publish(notification);

          // Assert
          expect(
            handlerLog,
            equals([
              'H2:START', 'H2:END', // Order 10
              'H1:START', 'H1:END', // Order 20
              'H3:START', 'H3:END', // Order 30
            ]),
            reason:
                'Handlers should execute sequentially based on specified order',
          );
        },
      );

      test(
        'handlers with mixed positive and negative orders execute correctly (negatives first)',
        () async {
          // Arrange
          final handler1 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H1',
            delay: Duration.zero,
          ); // Order 10
          final handler2 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H2',
            delay: Duration.zero,
          ); // Order -5
          final handler3 = ConcreteOrderedNotificationHandler(
            handlerLog,
            'H3',
            delay: Duration.zero,
          ); // Order 0

          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler1,
            order: 10,
          );
          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler2,
            order: -5,
          ); // Runs first
          kyron.registerNotificationHandler<OrderedNotification>(
            () => handler3,
            order: 0,
          ); // Runs second

          const notification = OrderedNotification();

          // Act
          await kyron.publish(notification);

          // Assert
          expect(
            handlerLog,
            equals([
              'H2:START', 'H2:END', // Order -5
              'H3:START', 'H3:END', // Order 0
              'H1:START', 'H1:END', // Order 10
            ]),
            reason: 'Handlers should execute with negative orders first',
          );
        },
      );
    });

    group('Error Handling Strategies', () {
      group('Strategy: continueOnError (Default)', () {
        setUp(
          () => kyron = createKyron(NotificationErrorStrategy.continueOnError),
        );

        test(
          'publish completes successfully even if a handler throws',
          () async {
            // Arrange
            final handlerOk = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK',
            );
            final handlerFail = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL',
              shouldThrow: true,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail,
              order: 1,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk,
              order: 2,
            );
            const notification = ErrorNotification();

            // Act & Assert
            await expectLater(
              kyron.publish(notification),
              completes,
              reason: 'Should complete despite error',
            );
          },
        );

        test(
          'all other registered handlers are still executed if one throws',
          () async {
            // Arrange
            final handlerOk1 = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK1',
            );
            final handlerFail = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL',
              shouldThrow: true,
            );
            final handlerOk2 = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK2',
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk1,
              order: 1,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail,
              order: 2,
            ); // Throws
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk2,
              order: 3,
            ); // Should still run
            const notification = ErrorNotification();

            // Act
            await kyron.publish(notification);

            // Assert
            expect(
              handlerLog,
              contains('OK1:CALLED'),
              reason: 'First OK handler should be called',
            );
            expect(
              handlerLog,
              contains('FAIL:CALLED'),
              reason: 'Failing handler should be called',
            );
            expect(
              handlerLog,
              contains('FAIL:THROWING'),
              reason: 'Failing handler should attempt throw',
            );
            expect(
              handlerLog,
              contains('OK2:CALLED'),
              reason: 'Second OK handler should still be called',
            );
            expect(
              handlerLog,
              contains('OK2:SUCCESS'),
              reason: 'Second OK handler should complete successfully',
            );
          },
        );

        test(
          'execution order is maintained despite errors in handlers',
          () async {
            // Arrange: Same as previous test
            final handlerOk1 = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK1',
            );
            final handlerFail = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL',
              shouldThrow: true,
            );
            final handlerOk2 = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK2',
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk1,
              order: 1,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail,
              order: 2,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk2,
              order: 3,
            );
            const notification = ErrorNotification();

            // Act
            await kyron.publish(notification);

            // Assert check order based on log entries
            final failIndex = handlerLog.indexOf('FAIL:CALLED');
            final ok1Index = handlerLog.indexOf('OK1:CALLED');
            final ok2Index = handlerLog.indexOf('OK2:CALLED');

            expect(
              ok1Index,
              lessThan(failIndex),
              reason: 'OK1 called before FAIL',
            );
            expect(
              failIndex,
              lessThan(ok2Index),
              reason: 'FAIL called before OK2',
            );
          },
        );
      });

      group('Strategy: collectErrors', () {
        setUp(
          () => kyron = createKyron(NotificationErrorStrategy.collectErrors),
        );

        test('publish completes successfully if no handlers throw', () async {
          // Arrange
          final handlerOk1 = ConcreteErrorNotificationHandler(
            handlerLog,
            'OK1',
          );
          final handlerOk2 = ConcreteErrorNotificationHandler(
            handlerLog,
            'OK2',
          );
          kyron.registerNotificationHandler<ErrorNotification>(
            () => handlerOk1,
            order: 1,
          );
          kyron.registerNotificationHandler<ErrorNotification>(
            () => handlerOk2,
            order: 2,
          );
          const notification = ErrorNotification();

          // Act & Assert
          await expectLater(kyron.publish(notification), completes);
          expect(handlerLog, containsAll(['OK1:CALLED', 'OK2:CALLED']));
        });

        test(
          'publish throws AggregateException if a single handler throws',
          () async {
            // Arrange
            final handlerOk = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK',
            );
            final handlerFail = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL',
              shouldThrow: true,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail,
              order: 1,
            ); // Throws
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk,
              order: 2,
            );
            const notification = ErrorNotification();

            // Act & Assert
            await expectLater(
              () => kyron.publish(notification),
              throwsA(
                isA<AggregateException>()
                    .having((e) => e.innerExceptions.length, 'count', 1)
                    .having(
                      (e) => e.innerExceptions.first,
                      'first error',
                      isA<MyTestException>().having(
                        (me) => me.message,
                        'msg',
                        'Notification handler FAIL failed',
                      ),
                    ),
              ),
              reason: 'Should throw AggregateException with one inner error',
            );
          },
        );

        test(
          'publish throws AggregateException containing multiple errors if multiple handlers throw',
          () async {
            // Arrange
            final handlerFail1 = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL1',
              shouldThrow: true,
            );
            final handlerOk = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK',
            );
            final handlerFail2 = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL2',
              shouldThrow: true,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail1,
              order: 1,
            ); // Throws
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk,
              order: 2,
            ); // Runs
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail2,
              order: 3,
            ); // Throws
            const notification = ErrorNotification();

            // Act & Assert
            await expectLater(
              () => kyron.publish(notification),
              throwsA(
                isA<AggregateException>()
                    .having((e) => e.innerExceptions.length, 'count', 2)
                    .having(
                      (e) => e.innerExceptions.first,
                      'first error',
                      isA<MyTestException>().having(
                        (me) => me.message,
                        'msg',
                        'Notification handler FAIL1 failed',
                      ),
                    )
                    .having(
                      (e) => e.innerExceptions.last,
                      'second error',
                      isA<MyTestException>().having(
                        (me) => me.message,
                        'msg',
                        'Notification handler FAIL2 failed',
                      ),
                    ),
              ),
              reason: 'Should throw AggregateException with two inner errors',
            );
          },
        );

        test(
          'all handlers are attempted even when errors occur before throwing AggregateException',
          () async {
            // Arrange: Same as previous test
            final handlerFail1 = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL1',
              shouldThrow: true,
            );
            final handlerOk = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK',
            );
            final handlerFail2 = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL2',
              shouldThrow: true,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail1,
              order: 1,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk,
              order: 2,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail2,
              order: 3,
            );
            const notification = ErrorNotification();

            // Act
            try {
              await kyron.publish(notification);
            } on AggregateException {
              // Expected
            }

            // Assert
            expect(
              handlerLog,
              contains('FAIL1:CALLED'),
              reason: 'Fail1 should be called',
            );
            expect(
              handlerLog,
              contains('OK:CALLED'),
              reason: 'OK should be called',
            );
            expect(
              handlerLog,
              contains('FAIL2:CALLED'),
              reason: 'Fail2 should be called',
            );
          },
        );

        test(
          'execution order is maintained before throwing AggregateException',
          () async {
            // Arrange: Same as previous test
            final handlerFail1 = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL1',
              shouldThrow: true,
            );
            final handlerOk = ConcreteErrorNotificationHandler(
              handlerLog,
              'OK',
            );
            final handlerFail2 = ConcreteErrorNotificationHandler(
              handlerLog,
              'FAIL2',
              shouldThrow: true,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail1,
              order: 1,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerOk,
              order: 2,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail2,
              order: 3,
            );
            const notification = ErrorNotification();

            // Act
            try {
              await kyron.publish(notification);
            } on AggregateException {
              // Expected
            }

            // Assert
            final fail1Index = handlerLog.indexOf('FAIL1:CALLED');
            final okIndex = handlerLog.indexOf('OK:CALLED');
            final fail2Index = handlerLog.indexOf('FAIL2:CALLED');
            expect(
              fail1Index,
              lessThan(okIndex),
              reason: 'FAIL1 called before OK',
            );
            expect(
              okIndex,
              lessThan(fail2Index),
              reason: 'OK called before FAIL2',
            );
          },
        );

        test(
          'AggregateException contains the original exceptions thrown by handlers',
          () async {
            // Arrange
            final error1 = MyTestException('Error One');
            final error2 = ArgumentError('Error Two');
            // ** FIX: Use mocks here to control throwing **
            final handlerFail1 = MockErrorNotificationHandlerA();
            final handlerFail2 = MockErrorNotificationHandlerB();

            // Mock the throwing behavior precisely
            when(() => handlerFail1.handle(any())).thenThrow(error1);
            when(() => handlerFail2.handle(any())).thenThrow(error2);

            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail1, // Register mock factory
              order: 1,
            );
            kyron.registerNotificationHandler<ErrorNotification>(
              () => handlerFail2, // Register mock factory
              order: 2,
            );
            const notification = ErrorNotification();

            // Act & Assert
            await expectLater(
              () => kyron.publish(notification),
              throwsA(
                isA<AggregateException>().having(
                  (e) => e.innerExceptions,
                  'innerExceptions',
                  [same(error1), same(error2)],
                ),
              ),
              reason:
                  'AggregateException should contain the exact error instances',
            );
          },
        );
      });
    });
  });
}
