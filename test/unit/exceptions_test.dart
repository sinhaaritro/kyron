// test/unit/exceptions_test.dart

import 'package:test/test.dart';
import 'package:kyron/kyron.dart';

class SampleRequest extends Request<String> {}

class SampleBehavior extends PipelineBehavior<SampleRequest, String> {
  @override
  Future<String> handle(req, ctx, next) => next();
}

class SampleHandler extends RequestHandler<SampleRequest, String> {
  @override
  Future<String> handle(req, ctx) async => 'done';
}

class SampleShortCircuit extends ShortCircuitException<List<String>> {
  const SampleShortCircuit(super.data);
}

void main() {
  group('Kyron Exceptions', () {
    group('UnregisteredHandlerException', () {
      test('toString() provides informative message with request type', () {
        // Arrange
        final exception = UnregisteredHandlerException(SampleRequest);

        // Act
        final message = exception.toString();

        // Assert
        expect(
          message,
          contains('UnregisteredHandlerException'),
          reason: 'Should contain exception type',
        );
        expect(
          message,
          contains('SampleRequest'),
          reason: 'Should contain the request type name',
        );
        expect(
          message,
          contains('No handler registered'),
          reason: 'Should contain the core message',
        );
      });
    });

    group('MediatorConfigurationException', () {
      test('toString() includes the provided message', () {
        // Arrange
        const testMessage = 'Factory failed';
        const exception = MediatorConfigurationException(testMessage);

        // Act
        final message = exception.toString();

        // Assert
        expect(
          message,
          contains('MediatorConfigurationException'),
          reason: 'Should contain exception type',
        );
        expect(
          message,
          contains(testMessage),
          reason: 'Should contain the specific error detail',
        );
      });
    });

    group('PipelineExecutionException', () {
      test(
        'toString() includes inner exception, stack trace, component, request type, and correlation ID',
        () {
          // Arrange
          final innerError = Exception('Inner failure');
          final innerStackTrace = StackTrace.current; // Example stack trace
          const correlationId = 12345;
          final exception = PipelineExecutionException(
            innerError,
            innerStackTrace,
            SampleBehavior, // Originating component type
            SampleRequest, // Request type
            correlationId,
          );

          // Act
          final message = exception.toString();

          // Assert
          expect(
            message,
            contains('PipelineExecutionException'),
            reason: 'Should contain exception type',
          );
          expect(
            message,
            contains('Inner failure'),
            reason: 'Should contain inner exception message',
          );
          expect(
            message,
            contains('SampleBehavior'),
            reason: 'Should contain originating component type',
          );
          expect(
            message,
            contains('SampleRequest'),
            reason: 'Should contain request type',
          );
          expect(
            message,
            contains(correlationId.toString()),
            reason: 'Should contain correlation ID',
          );
          expect(
            message,
            contains('Inner stack trace:'),
            reason: 'Should indicate stack trace presence',
          );
          expect(
            message,
            contains(innerStackTrace.toString().split('\n').first),
            reason: 'Should contain part of the stack trace',
          );
        },
      );
    });

    group('ShortCircuitException', () {
      // Test a concrete implementation
      test('Can be instantiated with data', () {
        // Arrange
        final data = ['error1', 'error2'];
        var exception = SampleShortCircuit(data);

        // Act & Assert
        expect(exception.data, data, reason: 'Data should be stored');
      });

      test('Stores data correctly', () {
        // Arrange
        final data = ['info'];
        var exception = SampleShortCircuit(data);

        // Assert
        expect(
          exception.data,
          equals(data),
          reason: 'Should hold the provided data',
        );
      });
    });

    group('AggregateException', () {
      test('toString() lists all inner exceptions clearly', () {
        // Arrange
        final errors = [Exception('Error 1'), ArgumentError('Error 2')];
        final exception = AggregateException(errors);

        // Act
        final message = exception.toString();

        // Assert
        expect(
          message,
          contains('AggregateException: 2 exceptions occurred'),
          reason: 'Should state the count',
        );
        expect(
          message,
          contains('1: Exception: Error 1'),
          reason: 'Should list the first error',
        );
        expect(
          message,
          contains('2: Invalid argument(s): Error 2'),
          reason: 'Should list the second error',
        );
      });

      test('toString() handles empty list gracefully', () {
        // Arrange
        final errors = <Object>[];
        final exception = AggregateException(errors);

        // Act
        final message = exception.toString();

        // Assert
        expect(
          message,
          contains('AggregateException: 0 exceptions occurred'),
          reason: 'Should state zero count',
        );
        expect(
          message.endsWith(':\n'),
          isTrue,
          reason: 'Should not list any errors',
        );
      });

      test('innerExceptions list is unmodifiable', () {
        // Arrange
        final errors = [Exception('Error 1')];
        final exception = AggregateException(errors);

        // Act & Assert
        expect(
          () => exception.innerExceptions.add(Exception('another')),
          throwsUnsupportedError,
          reason: 'Should throw if trying to modify the list',
        );
      });
    });
  });
}
