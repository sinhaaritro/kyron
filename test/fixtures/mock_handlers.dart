// test/fixtures/mock_handlers.dart

import 'dart:async';
import 'package:kyron/kyron.dart';
import 'package:mocktail/mocktail.dart';
import 'test_data.dart';

// Mock Classes

class MockSimpleRequestHandler extends Mock
    implements RequestHandler<SimpleRequest, String> {}

class MockOtherRequestHandler extends Mock
    implements RequestHandler<OtherRequest, int> {}

class MockVoidRequestHandler extends Mock
    implements RequestHandler<VoidRequest, void> {}

class MockErrorRequestHandler extends Mock
    implements RequestHandler<ErrorRequest, String> {}

class MockSimpleStreamRequestHandler extends Mock
    implements StreamRequestHandler<SimpleStreamRequest, int> {}

class MockErrorStreamRequestHandler extends Mock
    implements StreamRequestHandler<ErrorStreamRequest, int> {}

class MockSimpleNotificationHandler extends Mock
    implements NotificationHandler<SimpleNotification> {}

class MockOrderedNotificationHandler extends Mock
    implements NotificationHandler<OrderedNotification> {}

class MockErrorNotificationHandler extends Mock
    implements NotificationHandler<ErrorNotification> {}

// Concrete Handlers for Integration Tests

class ConcreteSimpleRequestHandler
    implements RequestHandler<SimpleRequest, String> {
  int instanceId =
      DateTime.now().microsecondsSinceEpoch; // To check instance uniqueness
  @override
  Future<String> handle(SimpleRequest request, PipelineContext context) async {
    await Future.delayed(Duration.zero); // Simulate async work
    return 'Processed: ${request.payload} by instance $instanceId';
  }
}

class ConcreteOtherRequestHandler implements RequestHandler<OtherRequest, int> {
  @override
  Future<int> handle(OtherRequest request, PipelineContext context) async {
    return request.value * 2;
  }
}

class ConcreteVoidRequestHandler implements RequestHandler<VoidRequest, void> {
  bool wasCalled = false;
  @override
  Future<void> handle(VoidRequest request, PipelineContext context) async {
    wasCalled = true;
    await Future.delayed(Duration.zero);
    // no return
  }
}

class ConcreteErrorRequestHandler
    implements RequestHandler<ErrorRequest, String> {
  @override
  Future<String> handle(ErrorRequest request, PipelineContext context) async {
    await Future.delayed(Duration.zero);
    throw MyTestException('Handler failed');
  }
}

class ConcreteContextRequestHandler
    implements RequestHandler<ContextRequest, String> {
  @override
  Future<String> handle(ContextRequest request, PipelineContext context) async {
    final data = context.testData; // Using extension
    final order = context.behaviorOrder?.join(', ') ?? 'none';
    return 'Handler got context data: $data, behavior order: $order';
  }
}

class ConcreteSimpleStreamRequestHandler
    implements StreamRequestHandler<SimpleStreamRequest, int> {
  int instanceId =
      DateTime.now().microsecondsSinceEpoch; // To check instance uniqueness

  @override
  Stream<int> handle(
    SimpleStreamRequest request,
    PipelineContext context,
  ) async* {
    for (int i = 0; i < request.count; i++) {
      yield i;
      await Future.delayed(const Duration(milliseconds: 1)); // simulate work
    }
  }
}

class ConcreteErrorStreamRequestHandler
    implements StreamRequestHandler<ErrorStreamRequest, int> {
  @override
  Stream<int> handle(
    ErrorStreamRequest request,
    PipelineContext context,
  ) async* {
    yield 1;
    await Future.delayed(const Duration(milliseconds: 1));
    throw MyTestException('Stream handler failed');
  }
}

class ConcreteSimpleNotificationHandler
    implements NotificationHandler<SimpleNotification> {
  final List<String> receivedMessages;
  final Duration delay;

  ConcreteSimpleNotificationHandler(
    this.receivedMessages, {
    this.delay = Duration.zero,
  });

  @override
  Future<void> handle(SimpleNotification notification) async {
    await Future.delayed(delay);
    receivedMessages.add(notification.message);
    print(
      'Notification Handler (${identityHashCode(this)}): Received ${notification.message}',
    );
  }
}

class ConcreteOrderedNotificationHandler
    implements NotificationHandler<OrderedNotification> {
  final List<String> executionLog;
  final String id;
  final Duration delay;

  ConcreteOrderedNotificationHandler(
    this.executionLog,
    this.id, {
    this.delay = Duration.zero,
  });

  @override
  Future<void> handle(OrderedNotification notification) async {
    executionLog.add('$id:START');
    await Future.delayed(delay);
    executionLog.add('$id:END');
    print('Ordered Handler $id finished');
  }
}

class ConcreteErrorNotificationHandler
    implements NotificationHandler<ErrorNotification> {
  final List<String> executionLog;
  final String id;
  final bool shouldThrow;

  ConcreteErrorNotificationHandler(
    this.executionLog,
    this.id, {
    this.shouldThrow = false,
  });

  @override
  Future<void> handle(ErrorNotification notification) async {
    executionLog.add('$id:CALLED');
    await Future.delayed(Duration.zero);
    if (shouldThrow) {
      executionLog.add('$id:THROWING');
      throw MyTestException('Notification handler $id failed');
    }
    executionLog.add('$id:SUCCESS');
  }
}

// Helper to create factories easily
RequestHandler<TRequest, TResponse> Function() factoryFor<
  TRequest extends Request<TResponse>,
  TResponse
>(RequestHandler<TRequest, TResponse> instance) {
  return () => instance;
}

StreamRequestHandler<TRequest, TResponse> Function() streamFactoryFor<
  TRequest extends StreamRequest<TResponse>,
  TResponse
>(StreamRequestHandler<TRequest, TResponse> instance) {
  return () => instance;
}

NotificationHandler<TNotification> Function() notificationFactoryFor<
  TNotification extends Notification
>(NotificationHandler<TNotification> instance) {
  return () => instance;
}
