// test/fixtures/mock_behaviors.dart

import 'dart:async';
import 'package:kyron/kyron.dart';
import 'package:mocktail/mocktail.dart';
import 'test_data.dart';

// Mock Class

class MockBehavior extends Mock
    implements PipelineBehavior<BaseRequest, dynamic> {}

class MockPipelineBehavior extends Mock
    implements PipelineBehavior<BaseRequest, dynamic> {}

// Concrete Behaviors for Integration Tests

class GlobalLoggingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  final List<String> log;
  @override
  final int order; // Allow setting order for tests

  GlobalLoggingBehavior(this.log, {this.order = -100});

  @override
  Future<dynamic> handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate<dynamic> next,
  ) async {
    final behaviorId = runtimeType.toString();
    log.add('$behaviorId:START:${request.runtimeType}');
    context.behaviorOrder =
        (context.behaviorOrder ?? [])..add(behaviorId); // Use extension

    try {
      final response = await next();
      log.add('$behaviorId:END:${request.runtimeType}');
      return response;
    } catch (e) {
      log.add('$behaviorId:ERROR:${request.runtimeType}:$e');
      rethrow;
    }
  }
}

class SpecificBehaviorForSimpleRequest
    extends PipelineBehavior<SimpleRequest, String> {
  final List<String> log;
  @override
  final int order;

  SpecificBehaviorForSimpleRequest(this.log, {this.order = 0});

  @override
  Future<String> handle(
    SimpleRequest request,
    PipelineContext context,
    RequestHandlerDelegate<String> next,
  ) async {
    final behaviorId = runtimeType.toString();
    log.add('$behaviorId:START');
    context.behaviorOrder = (context.behaviorOrder ?? [])..add(behaviorId);
    context.testData = (context.testData ?? '') + behaviorId; // Use extension
    final response = await next();
    log.add('$behaviorId:END');
    return "SpecificPrefix:$response";
  }
}

class PredicateBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  final List<String> log;
  final String marker;
  @override
  final int order;

  PredicateBehavior(this.log, this.marker, {this.order = 10});

  @override
  Future<dynamic> handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate<dynamic> next,
  ) async {
    final behaviorId = '$runtimeType($marker)';
    log.add('$behaviorId:START');
    context.behaviorOrder = (context.behaviorOrder ?? [])..add(behaviorId);
    context.testData = (context.testData ?? '') + marker;
    final response = await next();
    log.add('$behaviorId:END');
    return response;
  }

  // Predicate defined outside for registration clarity
  static bool appliesIfSimpleRequest(BaseRequest request) =>
      request is SimpleRequest;
}

class ContextModifyingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  final String dataToAdd;
  @override
  final int order;

  ContextModifyingBehavior(this.dataToAdd, {this.order = -50});

  @override
  Future<dynamic> handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate<dynamic> next,
  ) async {
    context.testData = dataToAdd; // Use extension setter
    (context.behaviorOrder ??= []).add(runtimeType.toString());
    return await next();
  }
}

class ShortCircuitingBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  @override
  final int order;
  final bool throwException;
  final dynamic valueToReturn; // Only used if throwException is false
  final ShortCircuitException?
  exceptionToThrow; // Only used if throwException is true

  ShortCircuitingBehavior({
    this.order = -10,
    this.throwException = true, // Default to throwing exception
    this.valueToReturn = 'ShortCircuitedValue',
    this.exceptionToThrow = const MyCustomShortCircuit(
      'ShortCircuitedViaException',
    ),
  });

  @override
  Future<dynamic> handle(
    BaseRequest request,
    PipelineContext context,
    RequestHandlerDelegate<dynamic> next,
  ) async {
    bool shouldShortCircuitLogic = false;
    if (request is ShortCircuitRequest) {
      shouldShortCircuitLogic = request.shouldShortCircuit;
    } else if (request is ShortCircuitStreamRequest) {
      shouldShortCircuitLogic = request.shouldShortCircuit;
    }

    (context.behaviorOrder ??= []).add(runtimeType.toString());

    if (shouldShortCircuitLogic) {
      context.testData = 'ShortCircuited';
      if (throwException) {
        if (exceptionToThrow != null) {
          throw exceptionToThrow!;
        } else {
          // Fallback if specific exception wasn't provided
          throw const MyCustomShortCircuit('DefaultShortCircuit');
        }
      } else {
        // Short-circuit by returning directly (less common pattern now)
        return valueToReturn;
      }
    } else {
      // Proceed normally
      return await next();
    }
  }
}

// Helper to create factories easily
PipelineBehavior<dynamic, dynamic> Function() behaviorFactoryFor(
  PipelineBehavior<dynamic, dynamic> instance,
) {
  return () => instance;
}

class PlanTestBehavior extends PipelineBehavior<BaseRequest, dynamic> {
  @override
  final int order;
  final String id; // To distinguish instances if needed
  PlanTestBehavior({required this.order, this.id = 'B'});
  @override
  Future handle(
    BaseRequest req,
    PipelineContext ctx,
    RequestHandlerDelegate next,
  ) => next(); // Simple pass-through
  @override
  String toString() => 'PlanTestBehavior(id: $id, order: $order)'; // Helpful for debugging plan descriptions
}

class PlanTestHandler extends RequestHandler<SimpleRequest, String> {
  @override
  Future<String> handle(SimpleRequest req, PipelineContext ctx) async =>
      'ok_plan_handler';
  @override
  String toString() => 'PlanTestHandler';
}

class PlanTestStreamHandler
    extends StreamRequestHandler<SimpleStreamRequest, int> {
  @override
  Stream<int> handle(SimpleStreamRequest req, PipelineContext ctx) async* {
    yield 1;
  }

  @override
  String toString() => 'PlanTestStreamHandler';
}
