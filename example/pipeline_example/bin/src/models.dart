// example/pipeline_example/bin/src/models.dart
import 'package:kyron/kyron.dart'; // BaseRequest, Request, ShortCircuitException

// --- RegisterEnrollment (Same as previous example) ---

class RegisterEnrollmentRequest extends Request<RegisterEnrollmentResponse> {
  final String name;
  final String address;
  final String dob; // Date of Birth (String for simplicity)
  final String country;

  const RegisterEnrollmentRequest({
    required this.name,
    required this.address,
    required this.dob,
    required this.country,
  });

  @override
  String toString() {
    return 'RegisterEnrollmentRequest(name: $name, country: $country)';
  }
}

class RegisterEnrollmentResponse {
  final String enrollmentId;
  final String name;
  final String address;
  final String dob;
  final String country;

  const RegisterEnrollmentResponse({
    required this.enrollmentId,
    required this.name,
    required this.address,
    required this.dob,
    required this.country,
  });

  @override
  String toString() {
    return 'RegisterEnrollmentResponse(enrollmentId: $enrollmentId, name: $name, country: $country)';
  }
}

// --- CreateClass (Same as previous example) ---

class CreateClassRequest extends Request<CreateClassResponse> {
  final int numberOfEnrollment;
  final String studentCountry; // For validation
  final String name;
  final String desc;
  final String endDate; // String for simplicity

  const CreateClassRequest({
    required this.numberOfEnrollment,
    required this.studentCountry,
    required this.name,
    required this.desc,
    required this.endDate,
  });

  @override
  String toString() {
    return 'CreateClassRequest(name: $name, studentCountry: $studentCountry)';
  }
}

class CreateClassResponse {
  final String classId;
  final String name;
  final String desc;
  final String endDate;
  final List<RegisterEnrollmentResponse> enrollments; // List of enrollments

  const CreateClassResponse({
    required this.classId,
    required this.name,
    required this.desc,
    required this.endDate,
    required this.enrollments,
  });

  @override
  String toString() {
    // Format enrollments nicely for readability
    final enrollmentsString = enrollments.map((e) => '    $e').join('\n');
    return 'CreateClassResponse(\n  classId: $classId,\n  name: $name,\n  desc: $desc,\n  endDate: $endDate,\n  enrollments: [\n$enrollmentsString\n  ]\n)';
  }
}

// --- Custom Exception for Validation Failure ---
class ValidationFailedException extends ShortCircuitException<String> {
  const ValidationFailedException(String reason) : super(reason);

  String get reason => data;

  @override
  String toString() {
    return 'ValidationFailedException: $reason';
  }
}
