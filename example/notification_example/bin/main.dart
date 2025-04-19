// example/notification_example/bin/main.dart
import 'package:kyron/kyron.dart';
import 'package:logging/logging.dart';

import 'src/models.dart';
import 'src/handlers.dart';

void main() async {
  // Setup logging
  Logger.root.level = Level.CONFIG;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });

  print('--- Kyron Notification Handling Example ---');

  // 1. Create Kyron Instance
  final kyron = Kyron(); // Default is continueOnError strategy
  print('\nKyron instance created.');

  // 2. Register Command Handlers (Injecting Kyron for publishing)
  print('\nRegistering command handlers...');
  kyron.registerHandler<ProcessDataExportJobCommandSequential, String>(
      () => ProcessDataExportJobCommandHandlerSequential(kyron));
  kyron.registerHandler<ProcessDataExportJobCommandParallel, String>(
      () => ProcessDataExportJobCommandHandlerParallel(kyron));
  print('Command handlers registered.');

  // 3. Register Notification Handlers
  print('\nRegistering notification handlers...');

  // == Register for SEQUENTIAL Notification ==
  // Use distinct integer orders for sequential execution
  print(
      '  Registering handlers for DataExportCompletedNotificationSequential (Sequential Order)...');
  // *** FIX: Instantiate generic handler with the SPECIFIC notification type ***
  kyron.registerNotificationHandler<DataExportCompletedNotificationSequential>(
    () =>
        UpdateExportRecordHandler<DataExportCompletedNotificationSequential>(),
    order: 10, // First
  );
  kyron.registerNotificationHandler<DataExportCompletedNotificationSequential>(
    () => NotifyUserViaSignalRHandler<
        DataExportCompletedNotificationSequential>(),
    order: 20, // Second
  );
  kyron.registerNotificationHandler<DataExportCompletedNotificationSequential>(
    () => SendExportReadyEmailHandler<
        DataExportCompletedNotificationSequential>(),
    order: 30, // Third
  );
  kyron.registerNotificationHandler<DataExportCompletedNotificationSequential>(
    () => CleanupExportTempDataHandler<
        DataExportCompletedNotificationSequential>(),
    order: 40, // Fourth
  );

  // == Register for PARALLEL Notification ==
  // Use default order (NotificationOrder.parallelEarly) for all handlers
  print(
      '  Registering handlers for DataExportCompletedNotificationParallel (Parallel Execution)...');
  // *** FIX: Instantiate generic handler with the SPECIFIC notification type ***
  kyron.registerNotificationHandler<DataExportCompletedNotificationParallel>(
    () => UpdateExportRecordHandler<DataExportCompletedNotificationParallel>(),
    // order: NotificationOrder.parallelEarly // Default
  );
  kyron.registerNotificationHandler<DataExportCompletedNotificationParallel>(
    () =>
        NotifyUserViaSignalRHandler<DataExportCompletedNotificationParallel>(),
    // order: NotificationOrder.parallelEarly // Default
  );
  kyron.registerNotificationHandler<DataExportCompletedNotificationParallel>(
    () =>
        SendExportReadyEmailHandler<DataExportCompletedNotificationParallel>(),
    // order: NotificationOrder.parallelEarly // Default
  );
  kyron.registerNotificationHandler<DataExportCompletedNotificationParallel>(
    () =>
        CleanupExportTempDataHandler<DataExportCompletedNotificationParallel>(),
    // order: NotificationOrder.parallelEarly // Default
  );

  print('Notification handlers registered.');

  // --- Scenario Execution ---

  // Scenario 1: Trigger Sequential Notification Flow
  print(
      '\n--- Scenario 1: Sending Command to Trigger SEQUENTIAL Notifications ---');
  final seqCommand =
      ProcessDataExportJobCommandSequential('SEQ-JOB-123', 'user-A');
  print('Sending command: $seqCommand');
  final seqResponse = await kyron.send(seqCommand);
  print('Received response from command handler: $seqResponse');
  print('--- Scenario 1 Complete (Observe Sequential Handler Logs Above) ---');

  // Scenario 2: Trigger Parallel Notification Flow
  print(
      '\n--- Scenario 2: Sending Command to Trigger PARALLEL Notifications ---');
  final parCommand =
      ProcessDataExportJobCommandParallel('PAR-JOB-456', 'user-B');
  print('Sending command: $parCommand');
  final parResponse = await kyron.send(parCommand);
  print('Received response from command handler: $parResponse');
  print(
      '--- Scenario 2 Complete (Observe Potentially Interleaved Handler Logs Above) ---');

  print('\n--- Example Complete ---');
}
