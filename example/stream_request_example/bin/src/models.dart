// example/stream_request_example/bin/src/models.dart
import 'package:kyron/kyron.dart'; // BaseRequest, StreamRequest

// --- Data structures ---

// This class represents the ITEMS yielded by the stream
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

// This is the request object, now extending StreamRequest
// The TResponse type indicates the type of items IN the stream.
class CreateClassRequest extends StreamRequest<RegisterEnrollmentResponse> {
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
