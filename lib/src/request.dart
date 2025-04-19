// lib/src/request.dart

/// Base marker interface for all request types handled by the mediator.
abstract class BaseRequest {
  const BaseRequest();
}

/// Base marker interface for all requests (Commands/Queries) expecting a single response.
/// Typed with the expected response type [TResponse].
abstract class Request<TResponse> extends BaseRequest {
  const Request();
}

/// Base marker interface for all requests expecting a stream of responses.
/// Typed with the type of items in the response stream [TResponse].
abstract class StreamRequest<TResponse> extends BaseRequest {
  const StreamRequest();
}
