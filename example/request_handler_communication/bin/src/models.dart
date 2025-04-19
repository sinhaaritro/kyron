// example/request_handler_communication/bin/src/models.dart
import 'package:kyron/kyron.dart'; // BaseRequest, Request

// --- RegisterEnrollment ---

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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterEnrollmentRequest &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          address == other.address &&
          dob == other.dob &&
          country == other.country;

  @override
  int get hashCode =>
      name.hashCode ^ address.hashCode ^ dob.hashCode ^ country.hashCode;

  @override
  String toString() {
    return 'RegisterEnrollmentRequest(name: $name, address: $address, dob: $dob, country: $country)';
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RegisterEnrollmentResponse &&
          runtimeType == other.runtimeType &&
          enrollmentId == other.enrollmentId &&
          name == other.name &&
          address == other.address &&
          dob == other.dob &&
          country == other.country;

  @override
  int get hashCode =>
      enrollmentId.hashCode ^
      name.hashCode ^
      address.hashCode ^
      dob.hashCode ^
      country.hashCode;

  @override
  String toString() {
    return 'RegisterEnrollmentResponse(enrollmentId: $enrollmentId, name: $name, address: $address, dob: $dob, country: $country)';
  }
}

// --- CreateClass ---

class CreateClassRequest extends Request<CreateClassResponse> {
  final int numberOfEnrollment;
  final String studentCountry; // For prefilling enrollments
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateClassRequest &&
          runtimeType == other.runtimeType &&
          numberOfEnrollment == other.numberOfEnrollment &&
          studentCountry == other.studentCountry &&
          name == other.name &&
          desc == other.desc &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      numberOfEnrollment.hashCode ^
      studentCountry.hashCode ^
      name.hashCode ^
      desc.hashCode ^
      endDate.hashCode;

  @override
  String toString() {
    return 'CreateClassRequest(numberOfEnrollment: $numberOfEnrollment, studentCountry: $studentCountry, name: $name, desc: $desc, endDate: $endDate)';
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
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateClassResponse &&
          runtimeType == other.runtimeType &&
          classId == other.classId &&
          name == other.name &&
          desc == other.desc &&
          endDate == other.endDate &&
          // Note: Comparing lists requires careful consideration (order, element equality)
          // For this example, a simple length check might suffice, or use collection equality.
          // Using a basic reference check or length check for simplicity here.
          enrollments.length == other.enrollments.length;

  @override
  int get hashCode =>
      classId.hashCode ^
      name.hashCode ^
      desc.hashCode ^
      endDate.hashCode ^
      enrollments.hashCode; // Simple list hashCode

  @override
  String toString() {
    // Format enrollments nicely for readability
    final enrollmentsString = enrollments.map((e) => '    $e').join('\n');
    return 'CreateClassResponse(\n  classId: $classId,\n  name: $name,\n  desc: $desc,\n  endDate: $endDate,\n  enrollments: [\n$enrollmentsString\n  ]\n)';
  }
}
