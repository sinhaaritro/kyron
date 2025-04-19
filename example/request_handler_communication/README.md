# Kyron Example: Basic Request/Handler Communication

This example demonstrates the fundamental usage of the Kyron mediator pattern library: sending different request objects and having Kyron route them to their corresponding registered handler.

## Scenario

1.  **Setup:**
    *   A `Kyron` mediator instance is created.
    *   Two distinct request/response pairs and their handlers are defined:
        *   `RegisterEnrollmentRequest` -> `RegisterEnrollmentHandler` -> `RegisterEnrollmentResponse`
        *   `CreateClassRequest` -> `CreateClassHandler` -> `CreateClassResponse`
    *   The handlers are registered with the `Kyron` instance. `CreateClassHandler` simulates generating dummy enrollment data based on the request.
2.  **Execution:**
    *   Two different `CreateClassRequest` objects are created and sent sequentially using `kyron.send()`.
    *   The responses returned by the `CreateClassHandler` are printed.
    *   Two different `RegisterEnrollmentRequest` objects are created and sent sequentially using `kyron.send()`.
    *   The responses returned by the `RegisterEnrollmentHandler` are printed.
3.  **Goal:** To show that Kyron correctly dispatches each request type to its specifically registered handler and that the handlers process the request data to produce the expected response type.

## How to Run

Navigate to the root directory of the `kyron` package and run:

```bash
dart run example/request_handler_communication/bin/main.dart
```

## Expected Output

The output will show log messages from Kyron confirming its creation and handler registration, followed by messages indicating which request is being sent, the corresponding handler processing it, and the final response object printed to the console.

*(Note: Exact timestamps, hash codes, and random dummy enrollment IDs will vary on each run)*

```text
--- Kyron Basic Request/Handler Communication Example ---
CONFIG: [DateTime]: Kyron: Kyron instance created.
CONFIG: [DateTime]: Kyron: Using Registry: KyronRegistry
CONFIG: [DateTime]: Kyron: Using Executor: PipelineExecutor
CONFIG: [DateTime]: Kyron: Using Dispatcher: NotificationDispatcher
CONFIG: [DateTime]: Kyron: Notification Error Strategy: continueOnError

Kyron instance created.

Registering handlers...
CONFIG: [DateTime]: Kyron.Registry: Registered handler factory for RegisterEnrollmentRequest
CONFIG: [DateTime]: Kyron.Registry: Registered handler factory for CreateClassRequest
Handlers registered.

--- Scenario: Creating Classes ---

Sending CreateClassRequest 1: CreateClassRequest(numberOfEnrollment: 2, studentCountry: USA, name: Introduction to Dart, desc: Learn the basics of Dart programming., endDate: 2024-12-31)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type CreateClassRequest.
FINE: [DateTime]: Kyron: Found handler factory for CreateClassRequest [HASHCODE].
FINE: [DateTime]: Kyron: Created PipelineContext instance [HASHCODE].
FINER: [DateTime]: Kyron.Registry: Found 0 applicable behaviors for request CreateClassRequest.
FINER: [DateTime]: Kyron: Found 0 applicable behavior registrations for CreateClassRequest [HASHCODE]. Sorted by order.
FINE: [DateTime]: Kyron.PipelineExecutor: Instantiated 0 behaviors successfully for request CreateClassRequest [HASHCODE].
FINE: [DateTime]: Kyron: Instantiated handler: CreateClassHandler for CreateClassRequest [HASHCODE].
FINE: [DateTime]: Kyron.PipelineExecutor: Built pipeline delegate chain for Future response [HASHCODE].
FINE: [DateTime]: Kyron.PipelineExecutor: Starting pipeline execution for Future [HASHCODE]...
FINER: [DateTime]: Kyron.PipelineExecutor: Executing core handler: CreateClassHandler for request [HASHCODE]
  [Handler] CreateClassHandler processing: Introduction to Dart
FINER: [DateTime]: Kyron.PipelineExecutor: Core handler CreateClassHandler completed for request [HASHCODE]
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received CreateClassResponse 1:
CreateClassResponse(
  classId: CLS-[ID],
  name: Introduction to Dart,
  desc: Learn the basics of Dart programming.,
  endDate: 2024-12-31,
  enrollments: [
    RegisterEnrollmentResponse(enrollmentId: DUMMY-ENR-[ID], name: Student 1, address: Address 1, dob: 2000-01-01, country: USA)
    RegisterEnrollmentResponse(enrollmentId: DUMMY-ENR-[ID], name: Student 2, address: Address 2, dob: 2000-01-01, country: USA)
  ]
)

Sending CreateClassRequest 2: CreateClassRequest(numberOfEnrollment: 1, studentCountry: Canada, name: Advanced Flutter Widgets, desc: Deep dive into complex Flutter UI., endDate: 2025-03-31)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type CreateClassRequest.
FINE: [DateTime]: Kyron: Found handler factory for CreateClassRequest [HASHCODE].
# ... (Kyron internal logs similar to above) ...
FINER: [DateTime]: Kyron.PipelineExecutor: Executing core handler: CreateClassHandler for request [HASHCODE]
  [Handler] CreateClassHandler processing: Advanced Flutter Widgets
FINER: [DateTime]: Kyron.PipelineExecutor: Core handler CreateClassHandler completed for request [HASHCODE]
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received CreateClassResponse 2:
CreateClassResponse(
  classId: CLS-[ID],
  name: Advanced Flutter Widgets,
  desc: Deep dive into complex Flutter UI.,
  endDate: 2025-03-31,
  enrollments: [
    RegisterEnrollmentResponse(enrollmentId: DUMMY-ENR-[ID], name: Student 1, address: Address 1, dob: 2000-01-01, country: Canada)
  ]
)

--- Scenario: Registering Enrollments ---

Sending RegisterEnrollmentRequest 1: RegisterEnrollmentRequest(name: Alice Smith, address: 123 Main St, dob: 1995-05-15, country: USA)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type RegisterEnrollmentRequest.
FINE: [DateTime]: Kyron: Found handler factory for RegisterEnrollmentRequest [HASHCODE].
# ... (Kyron internal logs similar to above) ...
FINER: [DateTime]: Kyron.PipelineExecutor: Executing core handler: RegisterEnrollmentHandler for request [HASHCODE]
  [Handler] RegisterEnrollmentHandler processing: Alice Smith
FINER: [DateTime]: Kyron.PipelineExecutor: Core handler RegisterEnrollmentHandler completed for request [HASHCODE]
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received RegisterEnrollmentResponse 1: RegisterEnrollmentResponse(enrollmentId: ENR-[ID], name: Alice Smith, address: 123 Main St, dob: 1995-05-15, country: USA)

Sending RegisterEnrollmentRequest 2: RegisterEnrollmentRequest(name: Bob Johnson, address: 456 Oak Ave, dob: 1998-11-20, country: Canada)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type RegisterEnrollmentRequest.
FINE: [DateTime]: Kyron: Found handler factory for RegisterEnrollmentRequest [HASHCODE].
# ... (Kyron internal logs similar to above) ...
FINER: [DateTime]: Kyron.PipelineExecutor: Executing core handler: RegisterEnrollmentHandler for request [HASHCODE]
  [Handler] RegisterEnrollmentHandler processing: Bob Johnson
FINER: [DateTime]: Kyron.PipelineExecutor: Core handler RegisterEnrollmentHandler completed for request [HASHCODE]
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received RegisterEnrollmentResponse 2: RegisterEnrollmentResponse(enrollmentId: ENR-[ID], name: Bob Johnson, address: 456 Oak Ave, dob: 1998-11-20, country: Canada)

--- Example Complete ---