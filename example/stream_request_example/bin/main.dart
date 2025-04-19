// example/stream_request_example/bin/main.dart
import 'package:kyron/kyron.dart';
import 'package:logging/logging.dart';
import 'package:async/async.dart'; // Required for StreamGroup

import 'src/models.dart';
import 'src/handlers.dart';

void main() async {
  // Setup logging
  Logger.root.level = Level.CONFIG;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });

  print('--- Kyron Stream Request/Handler Example ---');

  // 1. Create Kyron Instance
  final kyron = Kyron();
  print('\nKyron instance created.');

  // 2. Register Stream Handler
  print('\nRegistering stream handler...');
  // Use registerStreamHandler for stream requests
  kyron.registerStreamHandler<CreateClassRequest, RegisterEnrollmentResponse>(
      () => CreateClassStreamHandler());
  print('Stream handler registered.');

  // 3. Scenario: Create Classes and listen to enrollment streams concurrently
  print('\n--- Scenario: Requesting Class Enrollment Streams Concurrently ---');

  final classRequest1 = CreateClassRequest(
    numberOfEnrollment: 3, // Will yield 3 items
    studentCountry: 'USA',
    name: 'Dart 101',
    desc: 'Basics of Dart.',
    endDate: '2024-12-31',
  );
  print('\nRequesting stream for Class 1: $classRequest1');
  // Call kyron.stream() - this returns the Stream immediately
  final stream1 = kyron.stream(classRequest1);

  final classRequest2 = CreateClassRequest(
    numberOfEnrollment: 2, // Will yield 2 items
    studentCountry: 'Canada',
    name: 'Flutter 201',
    desc: 'Advanced Flutter.',
    endDate: '2025-03-31',
  );
  print('Requesting stream for Class 2: $classRequest2');
  final stream2 = kyron.stream(classRequest2);

  print(
      '\n--- Listening to both streams concurrently (output will interleave) ---');

  // Use StreamGroup.merge to listen to both streams simultaneously
  final mergedStream = StreamGroup.merge([stream1, stream2]);
  int itemsReceived = 0;

  // Use await for to process items as they arrive from *either* stream
  await for (final enrollmentResponse in mergedStream) {
    itemsReceived++;
    print(
        '  [Main] Received item #$itemsReceived from merged stream: $enrollmentResponse');
  }

  print(
      '\n--- Merged stream complete. Total items received: $itemsReceived ---');
  print('--- Example Complete ---');
}
