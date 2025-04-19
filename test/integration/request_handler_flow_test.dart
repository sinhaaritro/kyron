// test/integration/request_handler_flow_test.dart

import 'dart:async';

import 'package:test/test.dart';
import 'package:kyron/kyron.dart';

// Import concrete implementations and test data
import '../fixtures/test_data.dart';
import '../fixtures/mock_handlers.dart';

// Helper Classes Defined Outside Tests

// Define a simple handler with state to test instance uniqueness
class StatefulHandler extends RequestHandler<SimpleRequest, String> {
  int callCount = 0;
  @override
  Future<String> handle(SimpleRequest request, PipelineContext context) async {
    callCount++;
    return 'Call $callCount processed: ${request.payload}';
  }
}

// Classes needed for 'Handler Registration and Discovery' tests
class UnregisteredReq extends Request<String> {
  const UnregisteredReq();
}

class UnregisteredStreamReq extends StreamRequest<String> {
  const UnregisteredStreamReq();
}

// Classes needed for 'different request classes' test
class SpecificReqA extends Request<String> {
  final String val;
  const SpecificReqA(this.val);
}

class SpecificReqB extends Request<String> {
  final String val;
  const SpecificReqB(this.val);
}

class HandlerA extends RequestHandler<SpecificReqA, String> {
  @override
  Future<String> handle(SpecificReqA req, PipelineContext ctx) async =>
      'Handled A: ${req.val}';
}

class HandlerB extends RequestHandler<SpecificReqB, String> {
  @override
  Future<String> handle(SpecificReqB req, PipelineContext ctx) async =>
      'Handled B: ${req.val}';
}

// Classes needed for 'different response types' test
class CustomResponse {
  final String result;
  const CustomResponse(this.result);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomResponse &&
          runtimeType == other.runtimeType &&
          result == other.result;
  @override
  int get hashCode => result.hashCode;
}

class CustomRequest extends Request<CustomResponse> {
  const CustomRequest();
}

class CustomHandler extends RequestHandler<CustomRequest, CustomResponse> {
  @override
  Future<CustomResponse> handle(CustomRequest req, PipelineContext ctx) async =>
      const CustomResponse('Custom OK');
}

void main() {
  late Kyron kyron;

  setUp(() {
    kyron = Kyron();
    // Register handlers needed for these tests
    kyron.registerHandler<SimpleRequest, String>(
      () => ConcreteSimpleRequestHandler(),
    );
    kyron.registerHandler<OtherRequest, int>(
      () => ConcreteOtherRequestHandler(),
    );
    kyron.registerHandler<VoidRequest, void>(
      () => ConcreteVoidRequestHandler(),
    );
    kyron.registerHandler<ErrorRequest, String>(
      () => ConcreteErrorRequestHandler(),
    );
    kyron.registerStreamHandler<SimpleStreamRequest, int>(
      () => ConcreteSimpleStreamRequestHandler(),
    );
    kyron.registerStreamHandler<ErrorStreamRequest, int>(
      () => ConcreteErrorStreamRequestHandler(),
    );
    // Register the stateful handler
    kyron.registerHandler<SimpleRequest, String>(
      () => StatefulHandler(),
    ); // Overwrites previous SimpleRequest registration
  });

  group('Integration: Request/Handler Flow', () {
    group('Handler Registration and Discovery', () {
      test(
        'send throws UnregisteredHandlerException for non-registered request',
        () async {
          // Arrange
          const request = UnregisteredReq();

          // Act & Assert
          await expectLater(
            () => kyron.send(request),
            throwsA(
              isA<UnregisteredHandlerException>().having(
                (e) => e.requestType,
                'requestType',
                UnregisteredReq,
              ),
            ),
            reason:
                'Sending unregistered request should throw specific exception',
          );
        },
      );

      test(
        'stream throws UnregisteredHandlerException (via Stream.error) for non-registered stream request',
        () async {
          // Arrange
          const request = UnregisteredStreamReq();

          // Act
          final stream = kyron.stream(request);

          // Assert
          await expectLater(
            stream,
            emitsError(
              isA<UnregisteredHandlerException>().having(
                (e) => e.requestType,
                'requestType',
                UnregisteredStreamReq,
              ),
            ),
            reason:
                'Streaming unregistered request should yield specific error',
          );
        },
      );
    });

    group('Basic Request Handling (send)', () {
      test('should connect a simple Request to its registered Handler', () async {
        // Arrange
        const request = SimpleRequest('hello');

        // Act
        final response = await kyron.send(request);

        // Assert
        // Since StatefulHandler overwrites ConcreteSimpleRequestHandler in setUp:
        expect(
          response,
          startsWith('Call 1 processed: hello'),
          reason: 'Should execute the correct (Stateful) handler',
        );
      });

      test('should return the value produced by the Handler', () async {
        // Arrange
        const request = OtherRequest(10);

        // Act
        final response = await kyron.send(request);

        // Assert
        expect(
          response,
          equals(20),
          reason: 'Handler should compute and return value',
        );
      });

      test(
        'should return the Future value produced by an async Handler',
        () async {
          // Arrange (StatefulHandler is async)
          const request = SimpleRequest('async test');

          // Act
          final response = await kyron.send(request);

          // Assert
          expect(
            response,
            startsWith('Call 1 processed: async test'),
            reason: 'Should await and return result from async handler',
          );
        },
      );

      test(
        'should correctly handle Handlers returning void/null (Future<void>)',
        () async {
          // Arrange
          const request = VoidRequest();
          // Need to get the handler instance to check its state
          final handler = ConcreteVoidRequestHandler();
          // Re-register the specific instance for this test
          kyron.registerHandler<VoidRequest, void>(() => handler);

          // Act & Assert - Check for successful completion instead of void value
          await expectLater(
            kyron.send(request),
            completes, // Asserts the Future<void> completes without error
            reason: 'Sending a VoidRequest should complete successfully',
          );

          // Assert - Handler execution check remains the same
          expect(
            handler.wasCalled,
            isTrue,
            reason: 'Void handler handle method should have been executed',
          );
        },
      );

      test(
        'should propagate errors thrown by the Handler, wrapped in PipelineExecutionException',
        () async {
          // Arrange
          const request = ErrorRequest();

          // Act & Assert
          await expectLater(
            () => kyron.send(request),
            throwsA(
              isA<PipelineExecutionException>()
                  .having(
                    (e) => e.innerException,
                    'innerException',
                    isA<MyTestException>().having(
                      (ie) => ie.message,
                      'message',
                      'Handler failed',
                    ),
                  )
                  .having(
                    (e) => e.originatingComponentType,
                    'originatingComponentType',
                    ConcreteErrorRequestHandler,
                  )
                  .having((e) => e.requestType, 'requestType', ErrorRequest),
            ),
            reason: 'Error from handler should be wrapped and propagated',
          );
        },
      );

      test(
        'should use a new handler instance per request (if factory creates new instances)',
        () async {
          // Arrange
          const request1 = SimpleRequest('req1');
          const request2 = SimpleRequest('req2');
          // StatefulHandler is registered in setUp, factory creates new instances

          // Act
          final response1 = await kyron.send(request1);
          final response2 = await kyron.send(request2);

          // Assert
          // StatefulHandler increments callCount per instance
          expect(
            response1,
            equals('Call 1 processed: req1'),
            reason: 'First call to factory should create instance with count 1',
          );
          expect(
            response2,
            equals('Call 1 processed: req2'),
            reason:
                'Second call to factory should create *new* instance with count 1',
          );
        },
      );

      test(
        'should handle different request classes implementing the same Request<TResponse> structure correctly (if handlers registered for specific types)',
        () async {
          // Arrange
          kyron.registerHandler<SpecificReqA, String>(() => HandlerA());
          kyron.registerHandler<SpecificReqB, String>(() => HandlerB());

          const requestA = SpecificReqA('valA'); // Use const
          const requestB = SpecificReqB('valB'); // Use const

          // Act
          final responseA = await kyron.send(requestA);
          final responseB = await kyron.send(requestB);

          // Assert
          expect(
            responseA,
            equals('Handled A: valA'),
            reason: 'Should dispatch SpecificReqA to HandlerA',
          );
          expect(
            responseB,
            equals('Handled B: valB'),
            reason: 'Should dispatch SpecificReqB to HandlerB',
          );
        },
      );

      test(
        'should handle requests with different response types (String, int, custom object)',
        () async {
          // Arrange
          kyron.registerHandler<CustomRequest, CustomResponse>(
            () => CustomHandler(),
          );

          const reqString = SimpleRequest('str');
          const reqInt = OtherRequest(5);
          const reqCustom = CustomRequest(); // Use const

          // Act
          final resString = await kyron.send(
            reqString,
          ); // Will use StatefulHandler now
          final resInt = await kyron.send(reqInt);
          final resCustom = await kyron.send(reqCustom);

          // Assert
          expect(
            resString,
            startsWith('Call 1 processed: str'),
            reason: 'Should handle String response (via StatefulHandler)',
          );
          expect(resInt, equals(10), reason: 'Should handle int response');
          expect(
            resCustom,
            equals(const CustomResponse('Custom OK')),
            reason: 'Should handle custom object response',
          );
        },
      );
    });

    group('Basic Stream Request Handling (stream)', () {
      test(
        'should connect a simple StreamRequest to its registered StreamRequestHandler',
        () async {
          // Arrange
          const request = SimpleStreamRequest(2);

          // Act
          final stream = kyron.stream(request);
          final results = await stream.toList();

          // Assert
          expect(
            results,
            orderedEquals([0, 1]),
            reason: 'Should execute the correct stream handler',
          );
        },
      );

      test(
        'should return a Stream that yields values produced by the handler',
        () async {
          // Arrange
          const request = SimpleStreamRequest(3);

          // Act
          final stream = kyron.stream(request);

          // Assert
          await expectLater(
            stream,
            emitsInOrder([0, 1, 2, emitsDone]),
            reason: 'Stream should emit values from handler',
          );
        },
      );

      test(
        'should return a Stream that completes when the handler stream completes',
        () async {
          // Arrange
          const request = SimpleStreamRequest(1); // Only one item

          // Act
          final stream = kyron.stream(request);

          // Assert
          await expectLater(
            stream,
            emitsInOrder([0, emitsDone]),
            reason: 'Stream should complete after handler finishes',
          );
        },
      );

      test(
        'should return a Stream that emits errors thrown by the handler stream',
        () async {
          // Arrange
          const request = ErrorStreamRequest();

          // Act
          final stream = kyron.stream(request);

          // Assert
          await expectLater(
            stream,
            emitsInOrder([
              1, // Handler yields 1 first
              emitsError(
                isA<MyTestException>().having(
                  (e) => e.message,
                  'message',
                  'Stream handler failed',
                ),
              ), // Then emits error
              emitsDone,
            ]),
            reason:
                'Stream should emit handler error after yielding previous items then complete',
          );
        },
      );

      test(
        'should use a new stream handler instance per request (if factory creates new instances)',
        () async {
          // Arrange
          const request1 = SimpleStreamRequest(1);
          const request2 = SimpleStreamRequest(1);

          // Act
          final stream1 = kyron.stream(request1);
          final stream2 = kyron.stream(request2);
          final result1 = await stream1.toList(); // Consume fully
          final result2 = await stream2.toList(); // Consume fully

          // Assert
          expect(result1, orderedEquals([0]));
          expect(result2, orderedEquals([0]));
          print(
            "Stream handler instance test relies on factory providing new instances.",
          );
        },
      );
    });
  });
}
