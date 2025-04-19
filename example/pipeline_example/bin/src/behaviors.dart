// example/pipeline_example/bin/src/behaviors.dart
import 'dart:async';
import 'package:kyron/kyron.dart';
import 'models.dart'; // For request types and custom exception

// --- Define Context Extension ---
const Symbol startTimeKey = #startTime;
const Symbol endTimeKey = #endTime;
const Symbol isValidKey = #isValidKey; // For direct map access example

extension TimingContextExtensions on PipelineContext {
  // Type-safe accessors for start/end times
  DateTime? get startTime => items[startTimeKey] as DateTime?;
  set startTime(DateTime? value) => items[startTimeKey] = value;

  DateTime? get endTime => items[endTimeKey] as DateTime?;
  set endTime(DateTime? value) => items[endTimeKey] = value;
}

// --- Pipeline Behaviors ---

// 1. Logging Behavior (Generic)
class LoggingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  @override
  int get order => -100; // Runs first and last

  @override
  Future handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate next,
  ) async {
    print('  [Pipeline:Logging] START Processing ${request.runtimeType}');
    try {
      // Execute the rest of the pipeline
      final response = await next();

      // Post-processing log
      final startTime = context.startTime; // Use extension
      final endTime = context.endTime; // Use extension
      final duration = endTime != null && startTime != null
          ? endTime.difference(startTime)
          : null;
      final isValid = context.items[isValidKey] as bool?; // Direct map access

      print('  [Pipeline:Logging] END Processing ${request.runtimeType}.');
      print(
          '    > Timing: Start=$startTime, End=$endTime, Duration=${duration?.inMilliseconds}ms');
      print('    > Validation Result (if applicable): $isValid');
      print('    > Final Response (or short-circuit result): $response');

      return response; // Return the final result
    } catch (e) {
      print(
          '  [Pipeline:Logging] ERROR during processing ${request.runtimeType}: $e');
      rethrow; // Propagate the error
    }
  }
}

// 2. Timing Behavior (Generic)
class TimingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  @override
  int get order => -50; // Runs after logger start, before validator

  @override
  Future handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate next,
  ) async {
    print('    [Pipeline:Timing] START Timer');
    context.startTime = DateTime.now(); // Set start time using extension

    final response = await next(); // Execute inner pipeline/handler

    context.endTime = DateTime.now(); // Set end time using extension
    print('    [Pipeline:Timing] END Timer');
    return response;
  }
}

// 3. Validation Behavior (Specific to CreateClassRequest)
class ValidationBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  @override
  int get order => 0; // Runs after timer, before handler

  @override
  Future handle(
    BaseRequest request, // Keep generic here for broad compatibility
    PipelineContext context,
    RequestHandlerDelegate next,
  ) async {
    // This behavior only *logically* applies to CreateClassRequest,
    // enforced by the `appliesTo` predicate during registration.
    // We still perform a type check for safety and clarity.
    if (request is CreateClassRequest) {
      print(
          '      [Pipeline:Validation] START Validation for ${request.runtimeType}');

      // Validation Logic
      final bool isValid =
          request.studentCountry == 'USA' || request.studentCountry == 'Canada';

      // Store result in context using direct map access
      context.items[isValidKey] = isValid;

      if (isValid) {
        print(
            '      [Pipeline:Validation] PASSED (Country: ${request.studentCountry})');
        return await next(); // Proceed to the next step (handler)
      } else {
        print(
            '      [Pipeline:Validation] FAILED (Country: ${request.studentCountry}) - Short-circuiting!');
        // Throw specific exception to stop the pipeline
        throw ValidationFailedException(
            'Invalid country: ${request.studentCountry}. Only USA or Canada allowed for this class.');
      }
    } else {
      // Should not happen if registered correctly with appliesTo, but safe fallback
      print('      [Pipeline:Validation] SKIPPED for ${request.runtimeType}');
      return await next();
    }
  }
}
