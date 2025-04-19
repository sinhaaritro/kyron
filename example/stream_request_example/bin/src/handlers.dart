// example/stream_request_example/bin/src/handlers.dart
import 'dart:async';
import 'dart:math';

import 'package:kyron/kyron.dart'; // StreamRequestHandler, PipelineContext
import 'models.dart'; // Request/Response classes

class CreateClassStreamHandler extends StreamRequestHandler<CreateClassRequest,
    RegisterEnrollmentResponse> {
  final Random _random = Random(); // For unique IDs

  @override
  Stream<RegisterEnrollmentResponse> handle(
      CreateClassRequest request, PipelineContext context) async* {
    // The `async*` keyword makes this function return a Stream.
    print(
        '  [Stream Handler] CreateClassStreamHandler processing request for: ${request.name} (will yield ${request.numberOfEnrollment} items)');

    for (int i = 0; i < request.numberOfEnrollment; i++) {
      // Simulate work/delay between yielding items
      print(
          '    [Stream Handler ${request.name}] Waiting 2 seconds before yielding item ${i + 1}...');
      await Future.delayed(const Duration(seconds: 2));

      final dummyEnrollment = RegisterEnrollmentResponse(
        enrollmentId: 'STRM-ENR-${_random.nextInt(99999)}', // Unique dummy ID
        name: 'Student ${i + 1} for ${request.name}',
        address: 'Address ${i + 1}',
        dob: '2001-01-01',
        country: request.studentCountry, // Prefill country from request
      );

      print(
          '    [Stream Handler ${request.name}] Yielding item ${i + 1}: $dummyEnrollment');
      yield dummyEnrollment; // Use `yield` to emit an item into the stream
    }

    print(
        '  [Stream Handler] Finished processing request for: ${request.name}. Stream closing.');
    // The stream automatically closes when the async* function completes.
  }
}
