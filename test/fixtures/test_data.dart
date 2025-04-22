// test/fixtures/test_data.dart

import 'package:kyron/kyron.dart';

// Requests

class SimpleRequest extends Request<String> {
  final String payload;
  const SimpleRequest(this.payload);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SimpleRequest &&
          runtimeType == other.runtimeType &&
          payload == other.payload;

  @override
  int get hashCode => payload.hashCode;
}

class OtherRequest extends Request<int> {
  final int value;
  const OtherRequest(this.value);
}

class VoidRequest extends Request<void> {
  const VoidRequest();
}

class ErrorRequest extends Request<String> {
  const ErrorRequest();
}

class ContextRequest extends Request<String> {
  const ContextRequest();
}

class ShortCircuitRequest extends Request<String> {
  final bool shouldShortCircuit;
  const ShortCircuitRequest(this.shouldShortCircuit);
}

// Stream Requests

class SimpleStreamRequest extends StreamRequest<int> {
  final int count;
  const SimpleStreamRequest(this.count);
}

class ErrorStreamRequest extends StreamRequest<int> {
  const ErrorStreamRequest();
}

class ShortCircuitStreamRequest extends StreamRequest<int> {
  final bool shouldShortCircuit;
  const ShortCircuitStreamRequest(this.shouldShortCircuit);
}

// Notifications

class SimpleNotification {
  final String message;
  const SimpleNotification(this.message);
}

class OrderedNotification {
  const OrderedNotification();
}

class ErrorNotification {
  const ErrorNotification();
}

class CustomPlainObject {
  final int id;
  final String value;

  const CustomPlainObject(this.id, this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomPlainObject &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          value == other.value;

  @override
  int get hashCode => id.hashCode ^ value.hashCode;

  @override
  String toString() => 'CustomPlainObject(id: $id, value: $value)';
}

// Used for testing publishing when no handler is registered
class UnhandledObject {
  final String description;
  const UnhandledObject(this.description);
}

// Custom Exceptions

class MyCustomShortCircuit extends ShortCircuitException<String> {
  const MyCustomShortCircuit(super.data);
  String get reason => data;
}

class AnotherShortCircuit extends ShortCircuitException<int> {
  const AnotherShortCircuit(super.data);
  int get code => data;
}

class MyTestException implements Exception {
  final String message;
  MyTestException(this.message);
  @override
  String toString() => 'MyTestException: $message';
}

// Pipeline Context Extension

const Symbol testDataKey = #testDataKey;
const Symbol behaviorOrderKey = #behaviorOrderKey;

extension TestPipelineContextExtensions on PipelineContext {
  String? get testData => items[testDataKey] as String?;
  set testData(String? value) => items[testDataKey] = value;

  List<String>? get behaviorOrder => items[behaviorOrderKey] as List<String>?;
  set behaviorOrder(List<String>? value) => items[behaviorOrderKey] = value;
}
