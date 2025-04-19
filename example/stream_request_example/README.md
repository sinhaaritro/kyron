# Kyron Example: Stream Request/Handler Communication

This example demonstrates how to use the Kyron mediator pattern library for requests that expect a stream of responses over time, rather than a single response.

## Scenario

1.  **Setup:**
    *   A `Kyron` mediator instance is created.
    *   A request (`CreateClassRequest`) that extends `StreamRequest<RegisterEnrollmentResponse>` is defined. The generic type indicates the type of *items* that will be yielded by the stream.
    *   A handler (`CreateClassStreamHandler`) that implements `StreamRequestHandler` is defined. Its `handle` method returns a `Stream` using `async*` and `yield`.
    *   The stream handler is registered with the `Kyron` instance using `kyron.registerStreamHandler()`.
2.  **Execution:**
    *   Two different `CreateClassRequest` objects are created (one requesting 3 enrollments, one requesting 2).
    *   `kyron.stream()` is called for *both* requests sequentially. This returns two separate `Stream` objects immediately. The handlers start their processing (including the initial delay) asynchronously.
    *   `StreamGroup.merge()` from the `package:async` library is used to combine the two streams into a single stream. This allows listening for items from *either* source stream as they become available.
    *   An `await for` loop iterates over the `mergedStream`. Each time a handler `yield`s an enrollment response (after its 2-second delay), it appears in the merged stream and is printed by the main function.
3.  **Goal:** To show that Kyron correctly dispatches stream requests to their handler, that the handler produces a stream of results over time, and how to consume multiple streams concurrently, demonstrating the interleaved nature of the output due to the delays within the handlers.

## How to Run

Navigate to the root directory of the `kyron` package and run:

```bash
dart run example/stream_request_example/bin/main.dart
```

## Expected Output

The output will show Kyron setup logs, followed by messages indicating the streams are being requested. Crucially, the output from the handlers and the "Received item" messages will be **interleaved**. Because each handler waits 2 seconds before yielding, you'll see items appear roughly every 2 seconds, originating alternately from the 'Dart 101' handler and the 'Flutter 201' handler until both streams are exhausted.

*(Note: Exact timestamps, hash codes, and random dummy enrollment IDs will vary. The exact interleaving order of the *first* item from each stream might vary slightly depending on scheduling, but subsequent items will respect the 2-second delay)*.

```text
--- Kyron Stream Request/Handler Example ---
CONFIG: [DateTime]: Kyron: Kyron instance created.
# ... Kyron setup logs ...

Kyron instance created.

Registering stream handler...
CONFIG: [DateTime]: Kyron.Registry: Registered stream handler factory for CreateClassRequest
Stream handler registered.

--- Scenario: Requesting Class Enrollment Streams Concurrently ---

Requesting stream for Class 1: CreateClassRequest(numberOfEnrollment: 3, studentCountry: USA, name: Dart 101, desc: Basics of Dart., endDate: 2024-12-31)
INFO: [DateTime]: Kyron: Received request (stream) [HASHCODE] of type CreateClassRequest.
FINE: [DateTime]: Kyron: Found stream handler factory for CreateClassRequest [HASHCODE].
# ... Kyron stream setup logs ...
FINE: [DateTime]: Kyron.PipelineExecutor: Initiating pipeline execution for Stream request CreateClassRequest [HASHCODE]...
FINE: [DateTime]: Kyron.PipelineExecutor: Starting async setup for stream request [HASHCODE]...
FINE: [DateTime]: Kyron.PipelineExecutor: Built pipeline delegate chain for Stream response [HASHCODE]. Returning controller stream.
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution initiated for Stream request CreateClassRequest [HASHCODE]. Returning stream.
FINER: [DateTime]: Kyron.PipelineExecutor: Executing core stream handler wrapper: CreateClassStreamHandler for request [HASHCODE]
  [Stream Handler] CreateClassStreamHandler processing request for: Dart 101 (will yield 3 items)
FINER: [DateTime]: Kyron.PipelineExecutor: Core stream handler CreateClassStreamHandler returned stream for request [HASHCODE]
FINE: [DateTime]: Kyron.PipelineExecutor: Async setup complete for CreateClassRequest [HASHCODE], piping source stream.

Requesting stream for Class 2: CreateClassRequest(numberOfEnrollment: 2, studentCountry: Canada, name: Flutter 201, desc: Advanced Flutter., endDate: 2025-03-31)
INFO: [DateTime]: Kyron: Received request (stream) [HASHCODE] of type CreateClassRequest.
# ... Kyron stream setup logs (similar for second request) ...
  [Stream Handler] CreateClassStreamHandler processing request for: Flutter 201 (will yield 2 items)

--- Listening to both streams concurrently (output will interleave) ---
    [Stream Handler Dart 101] Waiting 2 seconds before yielding item 1...
    [Stream Handler Flutter 201] Waiting 2 seconds before yielding item 1...
# (After ~2 seconds)
    [Stream Handler Dart 101] Yielding item 1: RegisterEnrollmentResponse(...)
  [Main] Received item #1 from merged stream: RegisterEnrollmentResponse(enrollmentId: STRM-ENR-[ID], name: Student 1 for Dart 101, address: Address 1, dob: 2001-01-01, country: USA)
    [Stream Handler Dart 101] Waiting 2 seconds before yielding item 2...
    [Stream Handler Flutter 201] Yielding item 1: RegisterEnrollmentResponse(...)
  [Main] Received item #2 from merged stream: RegisterEnrollmentResponse(enrollmentId: STRM-ENR-[ID], name: Student 1 for Flutter 201, address: Address 1, dob: 2001-01-01, country: Canada)
    [Stream Handler Flutter 201] Waiting 2 seconds before yielding item 2...
# (After another ~2 seconds)
    [Stream Handler Dart 101] Yielding item 2: RegisterEnrollmentResponse(...)
  [Main] Received item #3 from merged stream: RegisterEnrollmentResponse(enrollmentId: STRM-ENR-[ID], name: Student 2 for Dart 101, address: Address 2, dob: 2001-01-01, country: USA)
    [Stream Handler Dart 101] Waiting 2 seconds before yielding item 3...
    [Stream Handler Flutter 201] Yielding item 2: RegisterEnrollmentResponse(...)
  [Main] Received item #4 from merged stream: RegisterEnrollmentResponse(enrollmentId: STRM-ENR-[ID], name: Student 2 for Flutter 201, address: Address 2, dob: 2001-01-01, country: Canada)
  [Stream Handler] Finished processing request for: Flutter 201. Stream closing.
# (After another ~2 seconds)
    [Stream Handler Dart 101] Yielding item 3: RegisterEnrollmentResponse(...)
  [Main] Received item #5 from merged stream: RegisterEnrollmentResponse(enrollmentId: STRM-ENR-[ID], name: Student 3 for Dart 101, address: Address 3, dob: 2001-01-01, country: USA)
  [Stream Handler] Finished processing request for: Dart 101. Stream closing.
FINE: [DateTime]: Kyron.PipelineExecutor: Source stream piping finished for CreateClassRequest [HASHCODE_STREAM2].
FINE: [DateTime]: Kyron.PipelineExecutor: Source stream piping finished for CreateClassRequest [HASHCODE_STREAM1].


--- Merged stream complete. Total items received: 5 ---
--- Example Complete ---