// example/request_handler_communication/bin/src/handlers.dart
import 'dart:async';
import 'dart:math';

import 'package:kyron/kyron.dart'; // RequestHandler, PipelineContext
import 'models.dart'; // Request/Response classes

class RegisterEnrollmentHandler extends RequestHandler<
    RegisterEnrollmentRequest, RegisterEnrollmentResponse> {
  @override
  Future<RegisterEnrollmentResponse> handle(
      RegisterEnrollmentRequest request, PipelineContext context) async {
    print('  [Handler] RegisterEnrollmentHandler processing: ${request.name}');

    // Simulate generating an enrollment ID
    final enrollmentId = 'ENR-${request.hashCode % 10000}';

    // Simulate some async work (e.g., database save)
    await Future.delayed(Duration(milliseconds: 50));

    // Construct and return the response
    return RegisterEnrollmentResponse(
      enrollmentId: enrollmentId,
      name: request.name,
      address: request.address,
      dob: request.dob,
      country: request.country,
    );
  }
}

class CreateClassHandler
    extends RequestHandler<CreateClassRequest, CreateClassResponse> {
  final Random _random = Random(); // For unique IDs

  @override
  Future<CreateClassResponse> handle(
      CreateClassRequest request, PipelineContext context) async {
    print('  [Handler] CreateClassHandler processing: ${request.name}');

    // Simulate generating a class ID
    final classId = 'CLS-${request.hashCode % 10000}';

    // Simulate generating dummy enrollment data based on the request
    final List<RegisterEnrollmentResponse> dummyEnrollments = [];
    for (int i = 0; i < request.numberOfEnrollment; i++) {
      dummyEnrollments.add(
        RegisterEnrollmentResponse(
          enrollmentId:
              'DUMMY-ENR-${_random.nextInt(99999)}', // Unique dummy ID
          name: 'Student ${i + 1}',
          address: 'Address ${i + 1}',
          dob: '2000-01-01',
          country: request.studentCountry, // Prefill country from request
        ),
      );
    }

    // Simulate some async work
    await Future.delayed(Duration(milliseconds: 100));

    // Construct and return the response
    return CreateClassResponse(
      classId: classId,
      name: request.name,
      desc: request.desc,
      endDate: request.endDate,
      enrollments: dummyEnrollments,
    );
  }
}
