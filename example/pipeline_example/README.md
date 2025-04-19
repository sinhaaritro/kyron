# Kyron Example: Pipeline Behaviors

This example demonstrates the pipeline behavior (middleware) capabilities of the Kyron mediator library. It showcases:

*   Registering multiple pipeline behaviors.
*   Controlling execution order using the `order` property.
*   Applying behaviors globally versus specifically to certain request types using `appliesTo`.
*   Sharing state between behaviors and handlers using `PipelineContext` (via extensions and direct map access).
*   Short-circuiting the pipeline from within a behavior (e.g., validation failure).

## Scenario

1.  **Setup:**
    *   A `Kyron` mediator instance is created.
    *   Two request/handler pairs are registered: `RegisterEnrollmentRequest` -> `RegisterEnrollmentHandler` and `CreateClassRequest` -> `CreateClassHandler`. Both handlers simulate a 2-second delay.
    *   Three pipeline behaviors are defined and registered:
        *   `LoggingBehavior`: Global, runs first (`order: -100`). Prints start/end messages and final timing/validation info read from the context.
        *   `TimingBehavior`: Global, runs second (`order: -50`). Records start and end timestamps in the `PipelineContext` using a custom extension (`context.startTime`, `context.endTime`).
        *   `ValidationBehavior`: Specific to `CreateClassRequest` (using `appliesTo`), runs third (`order: 0`). Checks if the `studentCountry` in the `CreateClassRequest` is 'USA' or 'Canada'.
            *   If valid, it writes `true` to `context.items[#isValidKey]` and proceeds.
            *   If invalid, it writes `false` to `context.items[#isValidKey]` and throws a `ValidationFailedException` (a custom `ShortCircuitException`) to stop the pipeline immediately.
2.  **Execution:**
    *   **Request 1:** A `RegisterEnrollmentRequest` is sent. Since `ValidationBehavior` is not applicable, the pipeline should execute: `LoggingBehavior` (Start) -> `TimingBehavior` (Start) -> `RegisterEnrollmentHandler` -> `TimingBehavior` (End) -> `LoggingBehavior` (End).
    *   **Request 2:** A `CreateClassRequest` with `studentCountry: 'USA'` is sent. All behaviors are applicable, and validation should pass. The pipeline should execute: `LoggingBehavior` (Start) -> `TimingBehavior` (Start) -> `ValidationBehavior` (Pass) -> `CreateClassHandler` -> `TimingBehavior` (End) -> `LoggingBehavior` (End).
    *   **Request 3:** A `CreateClassRequest` with `studentCountry: 'India'` is sent. Validation should fail. The pipeline should execute: `LoggingBehavior` (Start) -> `TimingBehavior` (Start) -> `ValidationBehavior` (Fail and throw `ValidationFailedException`). The handler and subsequent post-behavior logic (End timers/loggers) should *not* run. The `send` call will throw the exception.
3.  **Goal:** To observe the execution order, context modifications, conditional execution of the validator, and the short-circuit mechanism based on the request type and data.

## How to Run

Navigate to the root directory of the `kyron` package and run:

```bash
dart run example/pipeline_example/bin/main.dart
```

## Expected Output

The output will show Kyron setup logs, followed by detailed logs for each scenario, clearly indicating which behaviors are running, in what order, the validation outcome, handler execution (or skipping), context values (like timing), and the final response or caught exception.

*(Note: Exact timestamps, hash codes, and enrollment IDs will vary. Delays are simulated.)*

```text
--- Kyron Pipeline Behavior Example ---
CONFIG: [DateTime]: Kyron: Kyron instance created.
# ... Kyron setup logs ...

Kyron instance created.

Registering handlers...
CONFIG: [DateTime]: Kyron.Registry: Registered handler factory for RegisterEnrollmentRequest
CONFIG: [DateTime]: Kyron.Registry: Registered handler factory for CreateClassRequest
Handlers registered.

Registering pipeline behaviors...
CONFIG: [DateTime]: Kyron.Registry: Registered behavior factory for LoggingBehavior (Order: -100, Applies Via: "Global (Applies to all Requests/StreamRequests)")
CONFIG: [DateTime]: Kyron.Registry: Registered behavior factory for TimingBehavior (Order: -50, Applies Via: "Global (Applies to all Requests/StreamRequests)")
CONFIG: [DateTime]: Kyron.Registry: Registered behavior factory for ValidationBehavior (Order: 0, Applies Via: "Only for CreateClassRequest")
Pipeline behaviors registered.

--- Scenario 1: Sending RegisterEnrollmentRequest (Validation Skipped) ---
Sending request: RegisterEnrollmentRequest(name: Charlie Brown, country: UK)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type RegisterEnrollmentRequest.
# ... Kyron internal logs ...
FINE: [DateTime]: Kyron.PipelineExecutor: Starting pipeline execution for Future [HASHCODE]...
  [Pipeline:Logging] START Processing RegisterEnrollmentRequest
    [Pipeline:Timing] START Timer
      [Handler] RegisterEnrollmentHandler START processing: Charlie Brown
      [Handler] RegisterEnrollmentHandler working...
# (Waits ~2 seconds)
      [Handler] RegisterEnrollmentHandler END processing: Charlie Brown
    [Pipeline:Timing] END Timer
  [Pipeline:Logging] END Processing RegisterEnrollmentRequest.
    > Timing: Start=[START_TIME], End=[END_TIME], Duration=[~2000]ms
    > Validation Result (if applicable): null
    > Final Response (or short-circuit result): RegisterEnrollmentResponse(enrollmentId: ENR-[ID], name: Charlie Brown, country: UK)
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received response: RegisterEnrollmentResponse(enrollmentId: ENR-[ID], name: Charlie Brown, country: UK)

--- Scenario 2: Sending CreateClassRequest (USA - Validation Passes) ---
Sending request: CreateClassRequest(name: Valid Dart Class, studentCountry: USA)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type CreateClassRequest.
# ... Kyron internal logs ...
FINE: [DateTime]: Kyron.PipelineExecutor: Starting pipeline execution for Future [HASHCODE]...
  [Pipeline:Logging] START Processing CreateClassRequest
    [Pipeline:Timing] START Timer
      [Pipeline:Validation] START Validation for CreateClassRequest
      [Pipeline:Validation] PASSED (Country: USA)
      [Handler] CreateClassHandler START processing: Valid Dart Class
      [Handler] CreateClassHandler working...
# (Waits ~2 seconds)
      [Handler] CreateClassHandler END processing: Valid Dart Class
    [Pipeline:Timing] END Timer
  [Pipeline:Logging] END Processing CreateClassRequest.
    > Timing: Start=[START_TIME], End=[END_TIME], Duration=[~2000]ms
    > Validation Result (if applicable): true
    > Final Response (or short-circuit result): CreateClassResponse( ... )
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received response:
CreateClassResponse(
  classId: CLS-[ID],
  name: Valid Dart Class,
  desc: This class should be processed.,
  endDate: 2024-11-30,
  enrollments: [
    RegisterEnrollmentResponse(enrollmentId: DUMMY-ENR-[ID], name: Student 1, address: Address 1, dob: 2000-01-01, country: USA)
  ]
)

--- Scenario 3: Sending CreateClassRequest (India - Validation Fails) ---
Sending request: CreateClassRequest(name: Invalid Class, studentCountry: India)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type CreateClassRequest.
# ... Kyron internal logs ...
FINE: [DateTime]: Kyron.PipelineExecutor: Starting pipeline execution for Future [HASHCODE]...
  [Pipeline:Logging] START Processing CreateClassRequest
    [Pipeline:Timing] START Timer
      [Pipeline:Validation] START Validation for CreateClassRequest
      [Pipeline:Validation] FAILED (Country: India) - Short-circuiting!
INFO: [DateTime]: Kyron.PipelineExecutor: Behavior ValidationBehavior short-circuited request CreateClassRequest [HASHCODE] with ValidationFailedException.
INFO: [DateTime]: Kyron.PipelineExecutor: Pipeline execution short-circuited for Future request CreateClassRequest [HASHCODE] by ValidationFailedException.
Successfully caught expected short-circuit exception: ValidationFailedException: Invalid country: India. Only USA or Canada allowed for this class.

--- Example Complete ---