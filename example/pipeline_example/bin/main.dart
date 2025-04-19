// example/pipeline_example/bin/main.dart
import 'package:kyron/kyron.dart';
import 'package:logging/logging.dart';

import 'src/models.dart';
import 'src/handlers.dart';
import 'src/behaviors.dart';

void main() async {
  // Setup logging
  Logger.root.level = Level.CONFIG;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });

  print('--- Kyron Pipeline Behavior Example ---');

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

  // 3. Register Pipeline Behaviors
  print('\nRegistering pipeline behaviors...');
  // Register Logger (Global, Order -100)
  kyron.registerBehavior(() => LoggingBehavior());
  // Register Timer (Global, Order -50)
  kyron.registerBehavior(() => TimingBehavior());
  // Register Validator (Specific to CreateClassRequest, Order 0)
  kyron.registerBehavior(
    () => ValidationBehavior(),
    // Crucial: Define the predicate to make it specific
    appliesTo: (request) => request is CreateClassRequest,
    predicateDescription: 'Only for CreateClassRequest', // Optional description
  );
  print('Pipeline behaviors registered.');

  // --- Scenario Execution ---

  // Scenario 1: Register Enrollment (Should run Logger, Timer, Handler)
  print(
      '\n--- Scenario 1: Sending RegisterEnrollmentRequest (Validation Skipped) ---');
  final enrollmentRequest = RegisterEnrollmentRequest(
    name: 'Charlie Brown',
    address: '789 Pine St',
    dob: '2002-02-28',
    country: 'UK', // Country doesn't matter here
  );
  print('Sending request: $enrollmentRequest');
  try {
    final enrollmentResponse = await kyron.send(enrollmentRequest);
    print('Received response: $enrollmentResponse');
  } catch (e) {
    print('Caught unexpected error for enrollment: $e');
  }

  // Scenario 2: Create Class (USA - Should run Logger, Timer, Validator (Pass), Handler)
  print(
      '\n--- Scenario 2: Sending CreateClassRequest (USA - Validation Passes) ---');
  final classRequestUSA = CreateClassRequest(
    numberOfEnrollment: 1,
    studentCountry: 'USA',
    name: 'Valid Dart Class',
    desc: 'This class should be processed.',
    endDate: '2024-11-30',
  );
  print('Sending request: $classRequestUSA');
  try {
    final classResponseUSA = await kyron.send(classRequestUSA);
    print('Received response:\n$classResponseUSA');
  } catch (e) {
    print('Caught unexpected error for USA class: $e');
  }

  // Scenario 3: Create Class (India - Should run Logger, Timer, Validator (Fail & Short-Circuit))
  print(
      '\n--- Scenario 3: Sending CreateClassRequest (India - Validation Fails) ---');
  final classRequestIndia = CreateClassRequest(
    numberOfEnrollment: 5,
    studentCountry: 'India',
    name: 'Invalid Class',
    desc: 'This class should be short-circuited by validation.',
    endDate: '2025-01-15',
  );
  print('Sending request: $classRequestIndia');
  try {
    await kyron.send(classRequestIndia);
    print(
        'ERROR: Request for India should have thrown ValidationFailedException!');
  } on ValidationFailedException catch (e) {
    print('Successfully caught expected short-circuit exception: $e');
    // Optionally inspect context if the exception carried it (not in this case)
  } catch (e) {
    print('Caught unexpected error type for India class: $e');
  }

  print('\n--- Example Complete ---');
}
