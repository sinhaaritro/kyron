# Kyron Mediator

<!-- [![pub package](https://img.shields.io/pub/v/kyron.svg)](https://pub.dev/packages/kyron) -->
<!-- [![pub points](https://img.shields.io/pub/points/kyron)](https://pub.dev/packages/kyron/score) -->
<!-- [![likes](https://img.shields.io/pub/likes/kyron)](https://pub.dev/packages/kyron/score) -->

<!-- Add build status, coverage etc. badges here once CI/CD is set up -->
<!-- e.g., [![Build Status](https://img.shields.io/github/actions/workflow/status/sinhaaritro/kyron/dart.yml?branch=main)](https://github.com/sinhaaritro/kyron/actions) -->
<!-- e.g., [![codecov](https://codecov.io/gh/sinhaaritro/kyron/branch/main/graph/badge.svg)](https://codecov.io/gh/sinhaaritro/kyron) -->

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL%202.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)

A flexible, extensible, and decoupled implementation of the Mediator pattern in
Dart, enhanced with a powerful pipeline behavior system for cross-cutting
concerns.

## Overview

Kyron helps you build cleaner, more maintainable applications by decoupling the
senders of requests and notifications from their handlers. It promotes adherence
to SOLID principles (especially SRP and OCP) and enables clean architecture
designs.

Kyron provides:

- **Request/Response Handling:** Send a request object and get a single response
  back asynchronously.
- **Stream Request Handling:** Send a request and get a stream of responses
  back.
- **Notification Publishing:** Publish events (notifications) to multiple
  handlers with configurable ordering (sequential/parallel phases) and error
  handling.
- **Pipeline Behaviors:** Intercept requests with middleware components
  (behaviors) to handle cross-cutting concerns like logging, validation,
  caching, authorization, timing, etc., without cluttering your core handler logic.
- **Logging Integration:** Uses the standard `package:logging` for internal operations, allowing easy integration with application logging frameworks.

## Features

- **Type-Safe Request/Handler Mapping:** Compile-time safety for
  request-to-handler resolution.
- **Flexible Pipeline Behavior System:** Add custom middleware easily. Control
  execution order (`order`, `orderOverride`). Apply behaviors conditionally
  (`appliesTo` predicate).
- **Short-Circuiting Pipelines:** Behaviors can stop processing and signal intent
  by throwing custom exceptions derived from `ShortCircuitException`.
- **Shared Pipeline Context:** Pass data between behaviors and handlers during a
  single request's lifecycle. Recommended usage via extension methods for type safety.
- **Stream Support:** Native handling for requests that produce multiple results
  over time (`StreamRequestHandler`).
- **Configurable Notification Handling:** Decoupled event publishing to multiple
  subscribers (handlers) with built-in support for sequential and parallel execution phases based on `NotificationOrder`. Configurable error handling (`NotificationErrorStrategy`, `AggregateException`).
- **Minimal Dependencies:** Relies only on the core Dart SDK, `meta`, and `logging`.
- **Testability:** Promotes handlers and behaviors that are easy to test in
  isolation.
- **Pipeline Planning:** Ability to inspect the intended execution plan for a request using `getPipelinePlan`.

## Getting Started

### Installation

Add Kyron to your `pubspec.yaml`:

```yaml
dependencies:
  kyron: ^latest # Or point to a specific version/path
  logging: ^1.3.0 # Recommended for seeing internal logs
```

Or add it using the command line:

```bash
dart pub add kyron
# or for Flutter projects
flutter pub add kyron
```

### Basic Usage (Request/Response)

Here's a simple example of sending a request and getting a response:

```dart
import 'package:kyron/kyron.dart';
import 'package:logging/logging.dart';

// 1. Define your Request and Response
class Ping extends Request<String> { // Request expects a String response
  final String message;
  const Ping(this.message);
}

// 2. Define your Handler
class PingHandler extends RequestHandler<Ping, String> {
  @override
  Future<String> handle(Ping request, PipelineContext context) async {
    print('  [Handler] Received Ping with message: "${request.message}"');
    // Simulate some work
    await Future.delayed(const Duration(milliseconds: 50));
    return 'Pong: ${request.message}'; // Return the response
  }
}

Future<void> main() async {
  // Optional: Configure logging to see Kyron's internal steps
  Logger.root.level = Level.INFO; // Adjust level as needed (CONFIG, FINE, FINER...)
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time.toIso8601String()}: ${record.loggerName}: ${record.message}');
  });

  // 3. Create a Kyron instance
  final kyron = Kyron();

  // 4. Register your handler factory
  //    The factory creates the handler when needed.
  kyron.registerHandler<Ping, String>(() => PingHandler());

  // 5. Create and send a request instance
  final request = Ping('Hello Kyron!');
  print('\nSending request: $request');

  try {
    final response = await kyron.send(request);

    // 6. Receive the response
    print('\nReceived response: "$response"'); // Output: "Pong: Hello Kyron!"
  } on UnregisteredHandlerException catch(e) {
    print('Error: Handler not registered for ${e.requestType}');
  } catch (e) {
    print('An unexpected error occurred: $e');
  }
}
```

## Core Concepts & Usage

### 1. Request/Response (`send`)

For commands (actions) and queries (data retrieval) expecting a single result.

- Define a class extending `Request<TResponse>`.
- Define a handler class extending `RequestHandler<TRequest, TResponse>` and implement `handle`.
- Register: `kyron.registerHandler<TRequest, TResponse>(() => YourHandler());`.
- Send: `await kyron.send(yourRequestInstance)`.
- Catches `UnregisteredHandlerException`, `MediatorConfigurationException`, `PipelineExecutionException`, and `ShortCircuitException` derivatives.

```dart
// Request / Response defined as in the basic example...
// Handler defined as in the basic example...

// Register
kyron.registerHandler<Ping, String>(() => PingHandler());

// Send
final response = await kyron.send(Ping("Test"));
```

### 2. Stream Request/Response (`stream`)

For requests producing multiple results over time.

- Define a class extending `StreamRequest<TResponse>` (where `TResponse` is the item type).
- Define a handler class extending `StreamRequestHandler<TRequest, TResponse>` and implement `handle` returning a `Stream<TResponse>` (usually `async*`).
- Register: `kyron.registerStreamHandler<TRequest, TResponse>(() => YourStreamHandler());`.
- Initiate: `final stream = kyron.stream(yourStreamRequestInstance)`.
- The returned stream emits setup errors (`UnregisteredHandlerException`, `MediatorConfigurationException`, `PipelineExecutionException` from setup, `ShortCircuitException` from setup) via `Stream.error`. Handler errors are emitted normally within the stream.

```dart
// Define Stream Request and item type
class Count extends StreamRequest<int> { final int upTo; const Count(this.upTo); }

// Define Stream Handler
class CountHandler extends StreamRequestHandler<Count, int> {
  @override
  Stream<int> handle(Count request, PipelineContext context) async* {
    for (int i = 1; i <= request.upTo; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      yield i;
    }
  }
}

// Register
kyron.registerStreamHandler<Count, int>(() => CountHandler());

// Initiate and Listen
final stream = kyron.stream(Count(5));
print('Listening to count stream...');
try {
  await for (final number in stream) {
    print('Received number: $number');
  }
  print('Stream finished.');
} catch (e) {
  print('Error during stream setup or handling: $e');
}
```

### 3. Notifications (`publish`)

For events where the publisher doesn't need a direct response. Multiple handlers can subscribe.

- Define a class extending `Notification`.
- Define handler classes extending `NotificationHandler<TNotification>`.
- Register: `kyron.registerNotificationHandler<TNotification>(() => YourNotificationHandler(), order: ...);`.
  - Use `NotificationOrder` constants (`parallelEarly`, `sequentialDefault`, `parallelLate`) or specific integers to control execution phase and sequence.
- Publish: `await kyron.publish(yourNotificationInstance)`.
- Error handling depends on the `NotificationErrorStrategy` configured in the `Kyron` constructor (default is `continueOnError`). `collectErrors` strategy throws `AggregateException`.

```dart
import 'package:kyron/kyron.dart';

// Define Notification
class TaskCompleted extends Notification { final String taskId; const TaskCompleted(this.taskId); }

// Define Handlers
class LogTaskCompletionHandler extends NotificationHandler<TaskCompleted> {
  @override Future<void> handle(TaskCompleted n) async { print('  Log: Task ${n.taskId} completed.'); }
}
class SendEmailHandler extends NotificationHandler<TaskCompleted> {
  @override Future<void> handle(TaskCompleted n) async { await Future.delayed(const Duration(milliseconds: 50)); print('  Email: Notifying about task ${n.taskId}.'); }
}
class CleanupHandler extends NotificationHandler<TaskCompleted> {
  @override Future<void> handle(TaskCompleted n) async { await Future.delayed(const Duration(milliseconds: 20)); print('  Cleanup: Task ${n.taskId} temp files.'); }
}

Future<void> main() async {
  final kyron = Kyron(); // Default: continueOnError

  // Register with specific orders for sequential execution
  print('Registering Sequential Handlers...');
  kyron.registerNotificationHandler<TaskCompleted>(() => LogTaskCompletionHandler(), order: 10); // First
  kyron.registerNotificationHandler<TaskCompleted>(() => SendEmailHandler(), order: 20);        // Second
  kyron.registerNotificationHandler<TaskCompleted>(() => CleanupHandler(), order: 30);      // Third

  print('\nPublishing TaskCompleted notification...');
  await kyron.publish(TaskCompleted('TASK-XYZ'));
  print('\nSequential publishing complete.');
}
```

### 4. Pipeline Behaviors

Intercept `send`/`stream` requests for cross-cutting concerns.

- Define a class extending `PipelineBehavior<TRequest, TResponse>`. Use `BaseRequest` and `dynamic` for generics if the behavior applies broadly.
- Implement `handle(request, context, next)`. Call `await next()` to execute the rest of the pipeline.
- Optionally override `int get order` (lower runs earlier).
- Register: `kyron.registerBehavior(() => YourBehavior(), appliesTo: (req) => ..., orderOverride: ...);`.
  - `appliesTo`: Predicate `bool Function(BaseRequest request)` for conditional execution. If null, applicability is inferred from the generic `TRequest` type used during registration (e.g., `BaseRequest` implies global).
  - `orderOverride`: Explicitly sets order during registration.
- **Short-circuiting:** Throw an exception extending `ShortCircuitException` from a behavior's `handle` method to stop the pipeline and propagate the exception to the original `kyron.send`/`kyron.stream` caller.

```dart
import 'package:kyron/kyron.dart';

// Define a generic logging behavior
class LoggingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  @override int get order => -100; // Run very early/late

  @override
  Future<dynamic> handle(BaseRequest request, PipelineContext context, RequestHandlerDelegate<dynamic> next) async {
    final stopwatch = Stopwatch()..start();
    print('[Behavior:Log] START ${request.runtimeType} [ID: ${context.correlationId}]');
    try {
      final response = await next(); // Execute inner pipeline + handler
      stopwatch.stop();
      print('[Behavior:Log] END ${request.runtimeType} [ID: ${context.correlationId}] Duration: ${stopwatch.elapsedMilliseconds}ms');
      return response;
    } catch (e) {
      stopwatch.stop();
      print('[Behavior:Log] FAILED ${request.runtimeType} [ID: ${context.correlationId}] Duration: ${stopwatch.elapsedMilliseconds}ms Error: $e');
      rethrow; // Let Kyron handle wrapping/rethrowing
    }
  }
}

// Define a validation behavior and exception
class ValidationFailed extends ShortCircuitException<String> { const ValidationFailed(super.data); }
class SimpleValidationBehavior extends PipelineBehavior<SimpleRequest, String> {
  @override int get order => 0; // Run after logging

  @override
  Future<String> handle(SimpleRequest request, PipelineContext context, RequestHandlerDelegate<String> next) async {
     print('[Behavior:Validate] Validating: ${request.message}');
     if (request.message.isEmpty) {
       print('[Behavior:Validate] Validation FAILED - short-circuiting!');
       throw const ValidationFailed('Message cannot be empty.');
     }
     print('[Behavior:Validate] Validation PASSED.');
     return await next();
  }
}

// Register globally or specifically
// kyron.registerBehavior(() => LoggingBehavior()); // Global
// kyron.registerBehavior<SimpleRequest, String>(() => SimpleValidationBehavior()); // Specific
```

### 5. Pipeline Context

`PipelineContext` is created per request (`send`/`stream`) and passed through behaviors and the handler to share transient state.

- Access the `items` map: `context.items[yourKey] = value;`. Use unique keys (`Symbol`s or `const String`s).
- **Recommended:** Define **extension methods** on `PipelineContext` for type-safe access.
- Access the request's `correlationId` via `context.correlationId`.

```dart
// 1. Define Keys
const Symbol userIdKey = #userId;

// 2. Define Extension
import 'package:kyron/kyron.dart';

extension UserContext on PipelineContext {
  int? get currentUserId => items[userIdKey] as int?;
  set currentUserId(int? value) => items[userIdKey] = value;
}

// 3. Use in Behaviors/Handlers
// In an Auth Behavior:
// context.currentUserId = fetchedUserId;

// In a later Behavior or Handler:
// final userId = context.currentUserId;
// if (userId != null) { ... }
```

## TODO

- [ ] Make `KyronRegistry`, `PipelineExecutor`, `NotificationDispatcher` public for other to modify. Or provide the interface
- [ ] Dependency Injection will be based on Decorators and with build_runner

## Examples

See the `/example` directory in the repository for more detailed, runnable examples:

- `request_handler_communication`: Basic `send` request/response flow.
- `stream_request_example`: `stream` request/response flow with concurrency.
- `pipeline_example`: Demonstrates multiple pipeline behaviors, context, ordering, applicability, and short-circuiting.
- `notification_example`: Shows command handlers publishing notifications, and sequential vs. parallel notification handler execution.
