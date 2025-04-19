// test/fixtures/mock_components.dart

import 'package:kyron/src/notification_dispatcher.dart';
import 'package:kyron/src/pipeline_executor.dart';
import 'package:kyron/src/registry.dart';
import 'package:mocktail/mocktail.dart';

class MockKyronRegistry extends Mock implements KyronRegistry {}

class MockPipelineExecutor extends Mock implements PipelineExecutor {}

class MockNotificationDispatcher extends Mock
    implements NotificationDispatcher {}
