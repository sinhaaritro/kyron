// example/request_handler_communication/bin/main.dart
import 'package:kyron/kyron.dart';
import 'package:logging/logging.dart';

import 'src/models.dart';
import 'src/handlers.dart';

void main() async {
  // Setup logging to see Kyron output
  Logger.root.level = Level.CONFIG; // Show registration logs
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });

  print('--- Kyron Basic Request/Handler Communication Example ---');

  // 1. Create Kyron Instance
  final kyron = Kyron();
  print('\nKyron instance created.');

  // 2. Register Handlers
  print('\nRegistering handlers...');
  kyron.registerHandler<RegisterEnrollmentRequest, RegisterEnrollmentResponse>(
      () => RegisterEnrollmentHandler());
  kyron.registerHandler<CreateClassRequest, CreateClassResponse>(
      () => CreateClassHandler());
  print('Handlers registered.');

  // 3. Scenario: Create Classes
  print('\n--- Scenario: Creating Classes ---');

  final classRequest1 = CreateClassRequest(
    numberOfEnrollment: 2,
    studentCountry: 'USA',
    name: 'Introduction to Dart',
    desc: 'Learn the basics of Dart programming.',
    endDate: '2024-12-31',
  );
  print('\nSending CreateClassRequest 1: $classRequest1');
  final classResponse1 = await kyron.send(classRequest1);
  print('Received CreateClassResponse 1:\n$classResponse1');

  final classRequest2 = CreateClassRequest(
    numberOfEnrollment: 1,
    studentCountry: 'Canada',
    name: 'Advanced Flutter Widgets',
    desc: 'Deep dive into complex Flutter UI.',
    endDate: '2025-03-31',
  );
  print('\nSending CreateClassRequest 2: $classRequest2');
  final classResponse2 = await kyron.send(classRequest2);
  print('Received CreateClassResponse 2:\n$classResponse2');

  // 4. Scenario: Register Enrollments
  print('\n--- Scenario: Registering Enrollments ---');

  final enrollmentRequest1 = RegisterEnrollmentRequest(
    name: 'Alice Smith',
    address: '123 Main St',
    dob: '1995-05-15',
    country: 'USA',
  );
  print('\nSending RegisterEnrollmentRequest 1: $enrollmentRequest1');
  final enrollmentResponse1 = await kyron.send(enrollmentRequest1);
  print('Received RegisterEnrollmentResponse 1: $enrollmentResponse1');

  final enrollmentRequest2 = RegisterEnrollmentRequest(
    name: 'Bob Johnson',
    address: '456 Oak Ave',
    dob: '1998-11-20',
    country: 'Canada',
  );
  print('\nSending RegisterEnrollmentRequest 2: $enrollmentRequest2');
  final enrollmentResponse2 = await kyron.send(enrollmentRequest2);
  print('Received RegisterEnrollmentResponse 2: $enrollmentResponse2');

  print('\n--- Example Complete ---');
}
