// test/unit/registry_test.dart

import 'dart:collection';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:kyron/kyron.dart';
import 'package:kyron/src/registry.dart';

import '../fixtures/test_data.dart';
import '../fixtures/mock_handlers.dart';

const int _minSafeInteger = -9007199254740991;
const int sequentialDefault = _minSafeInteger;

// Mocks Specific to Registry Tests
class MockSimpleHandler extends Mock
    implements RequestHandler<SimpleRequest, String> {}

class MockOtherHandler extends Mock
    implements RequestHandler<OtherRequest, int> {}

class MockSimpleStreamHandler extends Mock
    implements StreamRequestHandler<SimpleStreamRequest, int> {}

class MockSimpleNotificationHandlerForTest extends Mock
    implements NotificationHandler<SimpleNotification> {}

class MockBehaviorA extends Mock
    implements PipelineBehavior<BaseRequest, dynamic> {
  @override
  int get order => 10;
}

class MockBehaviorB extends Mock
    implements PipelineBehavior<BaseRequest, dynamic> {
  @override
  int get order => -10;
}

class MockSpecificBehavior extends Mock
    implements PipelineBehavior<SimpleRequest, String> {
  @override
  int get order => 5;
}

// Helper Factories
MockSimpleHandler _simpleHandlerFactory() => MockSimpleHandler();
MockOtherHandler _otherHandlerFactory() => MockOtherHandler();
MockSimpleStreamHandler _simpleStreamHandlerFactory() =>
    MockSimpleStreamHandler();
MockBehaviorA _behaviorAFactory() => MockBehaviorA();
MockBehaviorB _behaviorBFactory() => MockBehaviorB();
MockSpecificBehavior _specificBehaviorFactory() => MockSpecificBehavior();
MockSimpleNotificationHandlerForTest _simpleNotificationHandlerFactory() =>
    MockSimpleNotificationHandlerForTest();

void main() {
  late KyronRegistry registry;

  setUp(() {
    registry = KyronRegistry();
    // Suppress logging output during tests if desired
    // Logger.root.level = Level.OFF;
  });

  group('KyronRegistry', () {
    group('Handler Registration & Retrieval', () {
      group('registerHandler', () {
        test('should store a handler factory for a new request type', () {
          // Arrange
          const requestType = SimpleRequest;
          const factory = _simpleHandlerFactory;

          // Act
          registry.registerHandler<SimpleRequest, String>(factory);

          // Assert
          final retrievedFactory = registry.findHandlerFactory(requestType);
          expect(
            retrievedFactory,
            equals(factory),
            reason: 'Should store the exact factory provided',
          );
          expect(
            registry.registeredHandlerFactories,
            containsPair(requestType, factory),
            reason: 'Introspection getter should reflect registration',
          );
        });

        test(
          'should overwrite an existing handler factory for the same request type',
          () {
            // Arrange
            const requestType = SimpleRequest;
            final factory1 = _simpleHandlerFactory;
            factory2() => MockSimpleHandler(); // Different factory instance

            // Act
            registry.registerHandler<SimpleRequest, String>(factory1);
            registry.registerHandler<SimpleRequest, String>(
              factory2,
            ); // Overwrite

            // Assert
            final retrievedFactory = registry.findHandlerFactory(requestType);
            expect(
              retrievedFactory,
              equals(factory2),
              reason: 'Should store the latest factory',
            );
            expect(
              retrievedFactory,
              isNot(equals(factory1)),
              reason: 'Should not store the original factory',
            );
            expect(
              registry.registeredHandlerFactories.length,
              1,
              reason: 'Should only have one entry for the type',
            );
          },
        );
      });

      group('findHandlerFactory', () {
        test(
          'should return the registered factory for a known request type',
          () {
            // Arrange
            registry.registerHandler<SimpleRequest, String>(
              _simpleHandlerFactory,
            );
            registry.registerHandler<OtherRequest, int>(_otherHandlerFactory);

            // Act
            final factory = registry.findHandlerFactory(SimpleRequest);

            // Assert
            expect(
              factory,
              equals(_simpleHandlerFactory),
              reason: 'Should retrieve the correct factory',
            );
          },
        );

        test('should return null for an unknown request type', () {
          // Arrange
          registry.registerHandler<SimpleRequest, String>(
            _simpleHandlerFactory,
          );

          // Act
          final factory = registry.findHandlerFactory(
            OtherRequest,
          ); // Not registered

          // Assert
          expect(
            factory,
            isNull,
            reason: 'Should return null if type not registered',
          );
        });
      });
    });

    group('Stream Handler Registration & Retrieval', () {
      group('registerStreamHandler', () {
        test(
          'should store a stream handler factory for a new stream request type',
          () {
            // Arrange
            const requestType = SimpleStreamRequest;
            const factory = _simpleStreamHandlerFactory;

            // Act
            registry.registerStreamHandler<SimpleStreamRequest, int>(factory);

            // Assert
            final retrievedFactory = registry.findStreamHandlerFactory(
              requestType,
            );
            expect(
              retrievedFactory,
              equals(factory),
              reason: 'Should store the exact stream factory',
            );
            expect(
              registry.registeredStreamHandlerFactories,
              containsPair(requestType, factory),
              reason: 'Introspection getter should reflect registration',
            );
          },
        );

        test(
          'should overwrite an existing stream handler factory for the same stream request type',
          () {
            // Arrange
            const requestType = SimpleStreamRequest;
            final factory1 = _simpleStreamHandlerFactory;
            factory2() => MockSimpleStreamHandler(); // Different factory

            // Act
            registry.registerStreamHandler<SimpleStreamRequest, int>(factory1);
            registry.registerStreamHandler<SimpleStreamRequest, int>(factory2);

            // Assert
            final retrievedFactory = registry.findStreamHandlerFactory(
              requestType,
            );
            expect(
              retrievedFactory,
              equals(factory2),
              reason: 'Should store the latest stream factory',
            );
            expect(
              registry.registeredStreamHandlerFactories.length,
              1,
              reason: 'Should only have one entry for the type',
            );
          },
        );
      });

      group('findStreamHandlerFactory', () {
        test(
          'should return the registered factory for a known stream request type',
          () {
            // Arrange
            registry.registerStreamHandler<SimpleStreamRequest, int>(
              _simpleStreamHandlerFactory,
            );

            // Act
            final factory = registry.findStreamHandlerFactory(
              SimpleStreamRequest,
            );

            // Assert
            expect(
              factory,
              equals(_simpleStreamHandlerFactory),
              reason: 'Should retrieve the correct stream factory',
            );
          },
        );

        test('should return null for an unknown stream request type', () {
          // Arrange
          registry.registerStreamHandler<SimpleStreamRequest, int>(
            _simpleStreamHandlerFactory,
          );

          // Act
          final factory = registry.findStreamHandlerFactory(
            OtherRequest,
          ); // Not a stream request type or not registered

          // Assert
          expect(
            factory,
            isNull,
            reason: 'Should return null for unregistered stream type',
          );
        });
      });
    });

    group('Pipeline Behavior Registration & Retrieval', () {
      group('registerBehavior', () {
        setUp(() {
          // Reset mocks before each test in this group if needed
          reset(MockBehaviorA());
          reset(MockBehaviorB());
          reset(MockSpecificBehavior());
        });

        test(
          'should register a behavior with default order and inferred global predicate when appliesTo is null and TRequest is BaseRequest',
          () {
            // Arrange
            final factory = _behaviorAFactory;

            // Act
            registry.registerBehavior<BaseRequest, dynamic>(
              factory,
            ); // Explicitly BaseRequest

            // Assert
            final regs = registry.registeredBehaviorRegistrations;
            expect(regs.length, 1, reason: 'Should have one registration');
            final reg = regs.first;
            expect(reg.factory, equals(factory));
            expect(
              reg.order,
              equals(10),
              reason: 'Order should come from MockBehaviorA',
            ); // Default order from mock
            expect(
              reg.description,
              contains('Global'),
              reason: 'Description should indicate global',
            );
            expect(
              reg.predicate(const SimpleRequest('test')),
              isTrue,
              reason: 'Predicate should match any BaseRequest',
            );
            expect(
              reg.predicate(const OtherRequest(1)),
              isTrue,
              reason: 'Predicate should match any BaseRequest',
            );
          },
        );

        test(
          'should register a behavior with default order and inferred exact type predicate when appliesTo is null and TRequest is specific',
          () {
            // Arrange
            final factory = _specificBehaviorFactory;

            // Act
            registry.registerBehavior<SimpleRequest, String>(
              factory,
            ); // Specific type

            // Assert
            final regs = registry.registeredBehaviorRegistrations;
            expect(regs.length, 1);
            final reg = regs.first;
            expect(reg.factory, equals(factory));
            expect(reg.order, equals(5)); // Order from MockSpecificBehavior
            expect(
              reg.description,
              contains('Exact Type Match (SimpleRequest)'),
            );
            expect(
              reg.predicate(const SimpleRequest('test')),
              isTrue,
              reason: 'Predicate should match SimpleRequest',
            );
            expect(
              reg.predicate(const OtherRequest(1)),
              isFalse,
              reason: 'Predicate should not match OtherRequest',
            );
          },
        );

        test(
          'should register a behavior with a custom appliesTo predicate',
          () {
            // Arrange
            final factory = _behaviorAFactory;
            bool customPredicate(BaseRequest r) => r is OtherRequest;

            // Act
            registry.registerBehavior<BaseRequest, dynamic>(
              factory,
              appliesTo: customPredicate,
            );

            // Assert
            final reg = registry.registeredBehaviorRegistrations.first;
            expect(reg.predicate, equals(customPredicate));
            expect(reg.description, contains('Custom Predicate'));
            expect(reg.predicate(const SimpleRequest('test')), isFalse);
            expect(reg.predicate(const OtherRequest(1)), isTrue);
          },
        );

        test('should register a behavior with an orderOverride', () {
          // Arrange
          final factory = _behaviorAFactory; // Mock has order 10

          // Act
          registry.registerBehavior<BaseRequest, dynamic>(
            factory,
            orderOverride: 99,
          );

          // Assert
          final reg = registry.registeredBehaviorRegistrations.first;
          expect(
            reg.order,
            equals(99),
            reason: 'Override should take precedence',
          );
        });

        test('should use predicateDescription when provided', () {
          // Arrange
          final factory = _behaviorAFactory;
          const description = 'My Custom Rule';

          // Act
          registry.registerBehavior<BaseRequest, dynamic>(
            factory,
            appliesTo: (_) => true,
            predicateDescription: description,
          );

          // Assert
          final reg = registry.registeredBehaviorRegistrations.first;
          expect(reg.description, equals(description));
        });

        test(
          'should default description when predicateDescription is null',
          () {
            // Arrange
            final factory = _behaviorAFactory;

            // Act
            registry.registerBehavior<BaseRequest, dynamic>(
              factory,
              appliesTo: (_) => true,
            ); // Custom predicate, no description

            // Assert
            final reg = registry.registeredBehaviorRegistrations.first;
            expect(
              reg.description,
              contains('Custom Predicate'),
            ); // Default for custom
          },
        );

        test(
          'should throw MediatorConfigurationException if behavior factory fails during registration check',
          () {
            // Arrange
            factory() {
              throw Exception('Factory Boom!');
            }

            // Act & Assert
            expect(
              () => registry.registerBehavior<BaseRequest, dynamic>(factory),
              throwsA(
                isA<MediatorConfigurationException>().having(
                  (e) => e.message,
                  'message',
                  contains('Factory Boom!'),
                ),
              ),
              reason:
                  'Should throw config exception wrapping the factory error',
            );
          },
        );

        test('should register multiple behaviors', () {
          // Arrange & Act
          registry.registerBehavior<BaseRequest, dynamic>(_behaviorAFactory);
          registry.registerBehavior<SimpleRequest, String>(
            _specificBehaviorFactory,
          );

          // Assert
          expect(
            registry.registeredBehaviorRegistrations.length,
            2,
            reason: 'Should have registered two behaviors',
          );
        });
      });

      group('findApplicableBehaviorRegistrations', () {
        test(
          'should return an empty list when no behaviors are registered',
          () {
            // Arrange
            const request = SimpleRequest('test');

            // Act
            final applicable = registry.findApplicableBehaviorRegistrations(
              request,
            );

            // Assert
            expect(
              applicable,
              isEmpty,
              reason: 'Should return empty list if nothing registered',
            );
          },
        );

        test('should return globally registered behaviors for any request', () {
          // Arrange
          registry.registerBehavior<BaseRequest, dynamic>(
            _behaviorAFactory,
          ); // Global
          const request1 = SimpleRequest('test');
          const request2 = OtherRequest(1);

          // Act
          final applicable1 = registry.findApplicableBehaviorRegistrations(
            request1,
          );
          final applicable2 = registry.findApplicableBehaviorRegistrations(
            request2,
          );

          // Assert
          expect(
            applicable1.length,
            1,
            reason: 'Global should apply to SimpleRequest',
          );
          expect(applicable1.first.factory, equals(_behaviorAFactory));
          expect(
            applicable2.length,
            1,
            reason: 'Global should apply to OtherRequest',
          );
          expect(applicable2.first.factory, equals(_behaviorAFactory));
        });

        test(
          'should return specifically registered behaviors only for matching request types (exact type predicate)',
          () {
            // Arrange
            registry.registerBehavior<SimpleRequest, String>(
              _specificBehaviorFactory,
            ); // Specific
            const request1 = SimpleRequest('test');
            const request2 = OtherRequest(1);

            // Act
            final applicable1 = registry.findApplicableBehaviorRegistrations(
              request1,
            );
            final applicable2 = registry.findApplicableBehaviorRegistrations(
              request2,
            );

            // Assert
            expect(
              applicable1.length,
              1,
              reason: 'Specific should apply to SimpleRequest',
            );
            expect(applicable1.first.factory, equals(_specificBehaviorFactory));
            expect(
              applicable2,
              isEmpty,
              reason: 'Specific should NOT apply to OtherRequest',
            );
          },
        );

        test('should return behaviors matching a custom predicate', () {
          // Arrange
          bool customPredicate(BaseRequest r) => r is OtherRequest;
          registry.registerBehavior<BaseRequest, dynamic>(
            _behaviorAFactory,
            appliesTo: customPredicate,
          );
          const request1 = SimpleRequest('test');
          const request2 = OtherRequest(1);

          // Act
          final applicable1 = registry.findApplicableBehaviorRegistrations(
            request1,
          );
          final applicable2 = registry.findApplicableBehaviorRegistrations(
            request2,
          );

          // Assert
          expect(
            applicable1,
            isEmpty,
            reason: 'Custom predicate should not match SimpleRequest',
          );
          expect(
            applicable2.length,
            1,
            reason: 'Custom predicate should match OtherRequest',
          );
          expect(applicable2.first.factory, equals(_behaviorAFactory));
        });

        test(
          'should not return behaviors whose custom predicate returns false',
          () {
            // Arrange
            bool customPredicate(BaseRequest r) => false; // Always false
            registry.registerBehavior<BaseRequest, dynamic>(
              _behaviorAFactory,
              appliesTo: customPredicate,
            );
            const request = SimpleRequest('test');

            // Act
            final applicable = registry.findApplicableBehaviorRegistrations(
              request,
            );

            // Assert
            expect(
              applicable,
              isEmpty,
              reason: 'Should not return behavior if predicate is false',
            );
          },
        );

        test(
          'should return multiple applicable behaviors (global, specific, predicate)',
          () {
            // Arrange
            registry.registerBehavior<BaseRequest, dynamic>(
              _behaviorAFactory,
            ); // Global
            registry.registerBehavior<SimpleRequest, String>(
              _specificBehaviorFactory,
            ); // Specific to SimpleRequest
            bool customPredicate(BaseRequest r) => r is SimpleRequest;
            registry.registerBehavior<BaseRequest, dynamic>(
              _behaviorBFactory,
              appliesTo: customPredicate,
            ); // Custom predicate for SimpleRequest

            const requestSimple = SimpleRequest('test');
            const requestOther = OtherRequest(1);

            // Act
            final applicableSimple = registry
                .findApplicableBehaviorRegistrations(requestSimple);
            final applicableOther = registry
                .findApplicableBehaviorRegistrations(requestOther);

            // Assert
            expect(
              applicableSimple.length,
              3,
              reason: 'SimpleRequest should match global, specific, and custom',
            );
            expect(
              applicableSimple.map((r) => r.factory),
              contains(_behaviorAFactory),
            );
            expect(
              applicableSimple.map((r) => r.factory),
              contains(_specificBehaviorFactory),
            );
            expect(
              applicableSimple.map((r) => r.factory),
              contains(_behaviorBFactory),
            );

            expect(
              applicableOther.length,
              1,
              reason: 'OtherRequest should only match global',
            );
            expect(applicableOther.first.factory, equals(_behaviorAFactory));
          },
        );

        test(
          'should skip behavior and log warning if predicate execution fails',
          () {
            // Arrange
            bool failingPredicate(BaseRequest r) {
              throw Exception('Predicate Boom!');
            }

            registry.registerBehavior<BaseRequest, dynamic>(
              _behaviorAFactory,
              appliesTo: failingPredicate,
            );
            registry.registerBehavior<BaseRequest, dynamic>(
              _behaviorBFactory,
            ); // Add a normal global one too

            const request = SimpleRequest('test');

            // Act
            final applicable = registry.findApplicableBehaviorRegistrations(
              request,
            );

            // Assert
            expect(
              applicable.length,
              1,
              reason: 'Only the non-failing behavior should be returned',
            );
            expect(
              applicable.first.factory,
              equals(_behaviorBFactory),
              reason: 'Should be the working behavior',
            );
            // Verification of logging is complex in unit tests without a mock logger setup. Assume log happens.
          },
        );
      });
    });

    group('Notification Handler Registration & Retrieval', () {
      group('registerNotificationHandler', () {
        test(
          'should register a single handler factory for a message/event type with default order (parallelEarly)',
          () {
            // Arrange
            const notificationType = SimpleNotification;
            const factory = _simpleNotificationHandlerFactory;

            // Act
            registry.registerNotificationHandler<SimpleNotification>(factory);

            // Assert
            final regs = registry.findNotificationHandlerRegistrations(
              notificationType,
            );
            expect(regs.length, 1, reason: 'Should have one registration');
            expect(regs.first.factory, equals(factory));
            expect(
              regs.first.order,
              equals(
                NotificationOrder.parallelEarly,
              ), // Check against the actual default
              reason:
                  'Order should default to parallelEarly (${NotificationOrder.parallelEarly})',
            );
            expect(
              registry.registeredNotificationHandlerRegistrations,
              containsPair(notificationType, regs),
            );
          },
        );

        test(
          'should register multiple handler factories for the same message/event type',
          () {
            // Arrange
            const notificationType = SimpleNotification;
            final factory1 = _simpleNotificationHandlerFactory;
            factory2() => MockSimpleNotificationHandlerForTest();

            // Act
            registry.registerNotificationHandler<SimpleNotification>(factory1);
            registry.registerNotificationHandler<SimpleNotification>(factory2);

            // Assert
            final regs = registry.findNotificationHandlerRegistrations(
              notificationType,
            );
            expect(regs.length, 2, reason: 'Should have two registrations');
            expect(regs.map((r) => r.factory), contains(factory1));
            expect(regs.map((r) => r.factory), contains(factory2));
          },
        );

        test('should register handlers with specific orders', () {
          // Arrange
          const notificationType = SimpleNotification;
          final factory1 = _simpleNotificationHandlerFactory;
          factory2() => MockSimpleNotificationHandlerForTest();

          // Act
          registry.registerNotificationHandler<SimpleNotification>(
            factory1,
            order: 10,
          );
          registry.registerNotificationHandler<SimpleNotification>(
            factory2,
            order: -5,
          );

          // Assert
          final regs = registry.findNotificationHandlerRegistrations(
            notificationType,
          );
          expect(
            regs.firstWhere((r) => r.factory == factory1).order,
            equals(10),
          );
          expect(
            regs.firstWhere((r) => r.factory == factory2).order,
            equals(-5),
          );
        });

        test('should allow registering the same factory multiple times', () {
          // Arrange
          const notificationType = SimpleNotification;
          final factory = _simpleNotificationHandlerFactory;

          // Act
          registry.registerNotificationHandler<SimpleNotification>(
            factory,
            order: 1,
          );
          registry.registerNotificationHandler<SimpleNotification>(
            factory,
            order: 2,
          );

          // Assert
          final regs = registry.findNotificationHandlerRegistrations(
            notificationType,
          );
          expect(regs.length, 2, reason: 'Should register the factory twice');
          expect(regs[0].factory, equals(factory));
          expect(regs[1].factory, equals(factory));
          expect(regs.map((r) => r.order), containsAll([1, 2]));
          // Verification of logging is complex in unit tests without a mock logger setup.
        });
      });

      group('findNotificationHandlerRegistrations', () {
        test(
          'should return an empty list for a message/event type with no registered handlers',
          () {
            // Arrange
            const notificationType = SimpleNotification;

            // Act
            final regs = registry.findNotificationHandlerRegistrations(
              notificationType,
            );

            // Assert
            expect(
              regs,
              isEmpty,
              reason: 'Should be empty if nothing registered',
            );
          },
        );

        test(
          'should return a list containing the single registered handler',
          () {
            // Arrange
            registry.registerNotificationHandler<SimpleNotification>(
              _simpleNotificationHandlerFactory,
              order: 5,
            );

            // Act
            final regs = registry.findNotificationHandlerRegistrations(
              SimpleNotification,
            );

            // Assert
            expect(regs.length, 1);
            expect(
              regs.first.factory,
              equals(_simpleNotificationHandlerFactory),
            );
            expect(regs.first.order, equals(5));
          },
        );

        test(
          'should return a list containing all registered handlers for a type',
          () {
            // Arrange
            final factory1 = _simpleNotificationHandlerFactory;
            factory2() => MockSimpleNotificationHandlerForTest();
            registry.registerNotificationHandler<SimpleNotification>(
              factory1,
              order: 10,
            );
            registry.registerNotificationHandler<SimpleNotification>(
              factory2,
              order: -5,
            );
            // Register for another type (now also a plain class) to ensure isolation
            registry.registerNotificationHandler<OrderedNotification>(
              () => MockOrderedNotificationHandler(),
            );

            // Act
            final regs = registry.findNotificationHandlerRegistrations(
              SimpleNotification,
            );

            // Assert
            expect(regs.length, 2);
            expect(
              regs.map((r) => r.factory),
              containsAll([factory1, factory2]),
            );
            expect(regs.map((r) => r.order), containsAll([10, -5]));
          },
        );

        test('should return registrations with correct factory and order', () {
          // Arrange
          final factory1 = _simpleNotificationHandlerFactory;
          factory2() => MockSimpleNotificationHandlerForTest();
          registry.registerNotificationHandler<SimpleNotification>(
            factory1,
            order: 10,
          );
          registry.registerNotificationHandler<SimpleNotification>(
            factory2,
            order: -5,
          );

          // Act
          final regs = registry.findNotificationHandlerRegistrations(
            SimpleNotification,
          );

          // Assert
          final reg1 = regs.firstWhere((r) => r.order == 10);
          final reg2 = regs.firstWhere((r) => r.order == -5);
          expect(reg1.factory, equals(factory1));
          expect(reg2.factory, equals(factory2));
        });
      });
    });

    group('Introspection Getters', () {
      test('registeredHandlerFactories returns an unmodifiable view', () {
        registry.registerHandler<SimpleRequest, String>(_simpleHandlerFactory);
        expect(
          () =>
              registry.registeredHandlerFactories[SimpleRequest] =
                  _otherHandlerFactory,
          throwsUnsupportedError,
        );
        expect(
          () => registry.registeredHandlerFactories.clear(),
          throwsUnsupportedError,
        );
      });

      test('registeredStreamHandlerFactories returns an unmodifiable view', () {
        registry.registerStreamHandler<SimpleStreamRequest, int>(
          _simpleStreamHandlerFactory,
        );
        expect(
          () =>
              registry.registeredStreamHandlerFactories[SimpleStreamRequest] =
                  () => MockSimpleStreamHandler(),
          throwsUnsupportedError,
        );
        expect(
          () => registry.registeredStreamHandlerFactories.clear(),
          throwsUnsupportedError,
        );
      });

      test('registeredBehaviorRegistrations returns an unmodifiable view', () {
        registry.registerBehavior<BaseRequest, dynamic>(_behaviorAFactory);
        final regs = registry.registeredBehaviorRegistrations;
        expect(() => regs.add(regs.first), throwsUnsupportedError);
        expect(() => regs.clear(), throwsUnsupportedError);
        // Check if the inner tuple items are mutable (they shouldn't be based on definition)
        // Modifying order, factory, predicate, description directly isn't possible via list access.
      });

      test(
        'registeredNotificationHandlerRegistrations returns an unmodifiable view of lists',
        () {
          registry.registerNotificationHandler<SimpleNotification>(
            _simpleNotificationHandlerFactory,
          );
          final regsMap = registry.registeredNotificationHandlerRegistrations;

          expect(
            () => regsMap[SimpleNotification] = [],
            throwsUnsupportedError,
            reason: "Cannot replace list",
          );
          expect(
            () => regsMap.clear(),
            throwsUnsupportedError,
            reason: "Cannot clear map",
          );

          final list = regsMap[SimpleNotification];
          expect(
            list,
            isA<UnmodifiableListView>(),
            reason: "List itself should be unmodifiable",
          );
          expect(
            () => list!.add(list.first),
            throwsUnsupportedError,
            reason: "Cannot add to list",
          );
        },
      );

      test(
        'registeredNotificationHandlersSimple returns an unmodifiable view of factory lists',
        () {
          registry.registerNotificationHandler<SimpleNotification>(
            _simpleNotificationHandlerFactory,
          );
          final simpleMap = registry.registeredNotificationHandlersSimple;

          expect(
            () => simpleMap[SimpleNotification] = [],
            throwsUnsupportedError,
            reason: "Cannot replace list",
          );
          expect(
            () => simpleMap.clear(),
            throwsUnsupportedError,
            reason: "Cannot clear map",
          );

          final list = simpleMap[SimpleNotification];
          expect(
            list,
            isA<UnmodifiableListView>(),
            reason: "List itself should be unmodifiable",
          );
          expect(
            () => list!.add(_simpleNotificationHandlerFactory),
            throwsUnsupportedError,
            reason: "Cannot add to list",
          );
        },
      );
    });
  });
}
