# Kyron Example: Notification Handling (Sequential vs. Parallel)

This example demonstrates how to use `Kyron.publish()` to send notifications and how different notification handlers react based on their registration order, showcasing both sequential and potentially parallel execution patterns using Kyron's `NotificationOrder` system.

## Scenario

1.  **Setup:**
    *   A `Kyron` mediator instance is created.
    *   Two command/handler pairs are defined:
        *   `ProcessDataExportJobCommandSequential` -> `ProcessDataExportJobCommandHandlerSequential`: Simulates an export job and publishes a `DataExportCompletedNotificationSequential`.
        *   `ProcessDataExportJobCommandParallel` -> `ProcessDataExportJobCommandHandlerParallel`: Simulates an export job and publishes a `DataExportCompletedNotificationParallel`.
    *   Two distinct notification types are defined: `DataExportCompletedNotificationSequential` and `DataExportCompletedNotificationParallel`. They both implement a common interface (`DataExportCompletedData`) to share the required data fields (jobId, userId, filePath).
    *   Four notification handlers are defined generically (`Handler<T extends DataExportCompletedData>`) to handle the common data structure, representing post-export tasks: `UpdateExportRecordHandler`, `NotifyUserViaSignalRHandler`, `SendExportReadyEmailHandler`, `CleanupExportTempDataHandler`. Each handler simulates work with a `Future.delayed` and prints start/end logs.
2.  **Registration:**
    *   The command handlers are registered. They require the `Kyron` instance to be injected so they can call `publish`.
    *   **Sequential Flow:** All four notification handlers are registered (instantiated with the specific `DataExportCompletedNotificationSequential` type) to listen for **`DataExportCompletedNotificationSequential`**. They are given distinct, positive `order` values (10, 20, 30, 40) during registration. This instructs Kyron's dispatcher to execute them **sequentially** in that specific order.
    *   **Parallel Flow:** All four notification handlers are *also* registered (instantiated with the specific `DataExportCompletedNotificationParallel` type) to listen for **`DataExportCompletedNotificationParallel`**. This time, they are registered with the **default order** (`NotificationOrder.parallelEarly`). This instructs Kyron's dispatcher to attempt to execute them **concurrently** using `Future.wait`.
3.  **Execution:**
    *   The `ProcessDataExportJobCommandSequential` is sent using `kyron.send()`. Its handler executes, simulates work, and then publishes the `DataExportCompletedNotificationSequential`. The registered handlers for this notification type run one after another in the specified order.
    *   The `ProcessDataExportJobCommandParallel` is sent using `kyron.send()`. Its handler executes, simulates work, and then publishes the `DataExportCompletedNotificationParallel`. The registered handlers for this notification type are attempted to run concurrently by the dispatcher.
4.  **Goal:** To observe the distinct execution patterns of the *same set* of notification handler logic when triggered by different notifications registered with different ordering strategies (sequential vs. parallel).

## How to Run

Navigate to the root directory of the `kyron` package and run:

```bash
dart run example/notification_example/bin/main.dart
```

## Expected Output

The output will show Kyron setup logs, followed by the execution logs for each scenario.

*   **Scenario 1 (Sequential):** You will see the sequential command handler logs, then the "Publishing DataExportCompletedNotificationSequential" log. After this, the logs from the four notification handlers (`UpdateDB`, `SignalR`, `Email`, `Cleanup`) will appear **strictly in the order they were registered (10, 20, 30, 40)**. The `START` log of one handler will appear, followed by its `END` log (after its delay), before the next handler's `START` log appears, demonstrating sequential execution.
*   **Scenario 2 (Parallel):** You will see the parallel command handler logs, then the "Publishing DataExportCompletedNotificationParallel" log. After this, the `START` logs from the four notification handlers might appear in a **less predictable order**, potentially interleaved and very close together, as `Future.wait` starts them concurrently. The `END` logs will appear as each handler's simulated delay completes (SignalR likely finishes first, then Cleanup, then UpdateDB, then Email). The overall time for this block should be roughly determined by the *longest* running handler (Email: 300ms), not the sum of all delays.

*(Note: Exact timestamps and hash codes will vary. The exact interleaving of START logs in the parallel scenario can vary slightly based on event loop scheduling.)*

```text
--- Kyron Notification Handling Example ---
CONFIG: [DateTime]: Kyron: Kyron instance created.
# ... Kyron setup logs ...

Kyron instance created.

Registering command handlers...
CONFIG: [DateTime]: Kyron.Registry: Registered handler factory for ProcessDataExportJobCommandSequential
CONFIG: [DateTime]: Kyron.Registry: Registered handler factory for ProcessDataExportJobCommandParallel
Command handlers registered.

Registering notification handlers...
  Registering handlers for DataExportCompletedNotificationSequential (Sequential Order)...
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationSequential (Execution: Sequential (10))
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationSequential (Execution: Sequential (20))
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationSequential (Execution: Sequential (30))
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationSequential (Execution: Sequential (40))
  Registering handlers for DataExportCompletedNotificationParallel (Parallel Execution)...
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationParallel (Execution: Parallel Early)
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationParallel (Execution: Parallel Early)
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationParallel (Execution: Parallel Early)
CONFIG: [DateTime]: Kyron.Registry: Registered notification handler factory for DataExportCompletedNotificationParallel (Execution: Parallel Early)
Notification handlers registered.

--- Scenario 1: Sending Command to Trigger SEQUENTIAL Notifications ---
Sending command: ProcessDataExportJobCommandSequential(jobId: SEQ-JOB-123, userId: user-A)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type ProcessDataExportJobCommandSequential.
# ... Kyron internal logs ...
FINE: [DateTime]: Kyron.PipelineExecutor: Starting pipeline execution for Future [HASHCODE]...
FINER: [DateTime]: Kyron.PipelineExecutor: Executing core handler: ProcessDataExportJobCommandHandlerSequential for request [HASHCODE]
  [CommandHandler Seq] START Export Job SEQ-JOB-123
  [CommandHandler Seq] END Export Job SEQ-JOB-123, Path: /exports/SEQ-JOB-123.csv
  [CommandHandler Seq] Publishing DataExportCompletedNotificationSequential(jobId: SEQ-JOB-123, userId: user-A, filePath: /exports/SEQ-JOB-123.csv)
INFO: [DateTime]: Kyron: Publishing notification [HASHCODE] of type DataExportCompletedNotificationSequential.
FINER: [DateTime]: Kyron.Registry: Found 4 notification handlers for DataExportCompletedNotificationSequential [HASHCODE]. Sorted by order.
INFO: [DateTime]: Kyron.NotificationDispatcher: Dispatching notification DataExportCompletedNotificationSequential [HASHCODE] to 4 handlers (Strategy: continueOnError).
FINE: [DateTime]: Kyron.NotificationDispatcher: Partitioned handlers for DataExportCompletedNotificationSequential [HASHCODE]: Early Parallel (0), Sequential (4), Late Parallel (0).
FINER: [DateTime]: Kyron.NotificationDispatcher: Executing Sequential phase for DataExportCompletedNotificationSequential [HASHCODE] (4 handlers).
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Executing handler: UpdateExportRecordHandler<DataExportCompletedNotificationSequential> (Order: 10) for DataExportCompletedNotificationSequential [HASHCODE]
    [NotificationHandler: UpdateDB] START updating Job: SEQ-JOB-123
    [NotificationHandler: UpdateDB] END updating Job: SEQ-JOB-123 to Completed, Link: /exports/SEQ-JOB-123.csv
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Finished handler: UpdateExportRecordHandler<DataExportCompletedNotificationSequential> (Order: 10) for DataExportCompletedNotificationSequential [HASHCODE]
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Executing handler: NotifyUserViaSignalRHandler<DataExportCompletedNotificationSequential> (Order: 20) for DataExportCompletedNotificationSequential [HASHCODE]
    [NotificationHandler: SignalR] START sending notification to User: user-A for Job: SEQ-JOB-123
    [NotificationHandler: SignalR] END sending notification to User: user-A
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Finished handler: NotifyUserViaSignalRHandler<DataExportCompletedNotificationSequential> (Order: 20) for DataExportCompletedNotificationSequential [HASHCODE]
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Executing handler: SendExportReadyEmailHandler<DataExportCompletedNotificationSequential> (Order: 30) for DataExportCompletedNotificationSequential [HASHCODE]
    [NotificationHandler: Email] START sending email to User: user-A for Job: SEQ-JOB-123
    [NotificationHandler: Email] END sending email to User: user-A
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Finished handler: SendExportReadyEmailHandler<DataExportCompletedNotificationSequential> (Order: 30) for DataExportCompletedNotificationSequential [HASHCODE]
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Executing handler: CleanupExportTempDataHandler<DataExportCompletedNotificationSequential> (Order: 40) for DataExportCompletedNotificationSequential [HASHCODE]
    [NotificationHandler: Cleanup] START cleaning temp data for Job: SEQ-JOB-123
    [NotificationHandler: Cleanup] END cleaning temp data for Job: SEQ-JOB-123
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Sequential] Finished handler: CleanupExportTempDataHandler<DataExportCompletedNotificationSequential> (Order: 40) for DataExportCompletedNotificationSequential [HASHCODE]
FINER: [DateTime]: Kyron.NotificationDispatcher: Completed Sequential phase for DataExportCompletedNotificationSequential [HASHCODE].
INFO: [DateTime]: Kyron.NotificationDispatcher: Finished dispatching notification DataExportCompletedNotificationSequential [HASHCODE]. Errors collected: 0 (Strategy: continueOnError).
FINER: [DateTime]: Kyron.PipelineExecutor: Core handler ProcessDataExportJobCommandHandlerSequential completed for request [HASHCODE]
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received response from command handler: Export Job SEQ-JOB-123 Completed Successfully (Sequential Notification Triggered)
--- Scenario 1 Complete (Observe Sequential Handler Logs Above) ---

--- Scenario 2: Sending Command to Trigger PARALLEL Notifications ---
Sending command: ProcessDataExportJobCommandParallel(jobId: PAR-JOB-456, userId: user-B)
INFO: [DateTime]: Kyron: Received request (send) [HASHCODE] of type ProcessDataExportJobCommandParallel.
# ... Kyron internal logs ...
FINE: [DateTime]: Kyron.PipelineExecutor: Starting pipeline execution for Future [HASHCODE]...
FINER: [DateTime]: Kyron.PipelineExecutor: Executing core handler: ProcessDataExportJobCommandHandlerParallel for request [HASHCODE]
  [CommandHandler Par] START Export Job PAR-JOB-456
  [CommandHandler Par] END Export Job PAR-JOB-456, Path: /exports/PAR-JOB-456.zip
  [CommandHandler Par] Publishing DataExportCompletedNotificationParallel(jobId: PAR-JOB-456, userId: user-B, filePath: /exports/PAR-JOB-456.zip)
INFO: [DateTime]: Kyron: Publishing notification [HASHCODE] of type DataExportCompletedNotificationParallel.
FINER: [DateTime]: Kyron.Registry: Found 4 notification handlers for DataExportCompletedNotificationParallel [HASHCODE]. Sorted by order.
INFO: [DateTime]: Kyron.NotificationDispatcher: Dispatching notification DataExportCompletedNotificationParallel [HASHCODE] to 4 handlers (Strategy: continueOnError).
FINE: [DateTime]: Kyron.NotificationDispatcher: Partitioned handlers for DataExportCompletedNotificationParallel [HASHCODE]: Early Parallel (4), Sequential (0), Late Parallel (0).
FINER: [DateTime]: Kyron.NotificationDispatcher: Executing Early Parallel phase for DataExportCompletedNotificationParallel [HASHCODE] (4 handlers).
# (START logs might appear slightly interleaved here)
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Early Parallel] Kicking off handler: UpdateExportRecordHandler<DataExportCompletedNotificationParallel> for DataExportCompletedNotificationParallel [HASHCODE]
    [NotificationHandler: UpdateDB] START updating Job: PAR-JOB-456
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Early Parallel] Kicking off handler: NotifyUserViaSignalRHandler<DataExportCompletedNotificationParallel> for DataExportCompletedNotificationParallel [HASHCODE]
    [NotificationHandler: SignalR] START sending notification to User: user-B for Job: PAR-JOB-456
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Early Parallel] Kicking off handler: SendExportReadyEmailHandler<DataExportCompletedNotificationParallel> for DataExportCompletedNotificationParallel [HASHCODE]
    [NotificationHandler: Email] START sending email to User: user-B for Job: PAR-JOB-456
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Early Parallel] Kicking off handler: CleanupExportTempDataHandler<DataExportCompletedNotificationParallel> for DataExportCompletedNotificationParallel [HASHCODE]
    [NotificationHandler: Cleanup] START cleaning temp data for Job: PAR-JOB-456
# (END logs appear as delays complete, order depends on delay length - SignalR likely first, then Cleanup, UpdateDB, Email)
    [NotificationHandler: SignalR] END sending notification to User: user-B
    [NotificationHandler: Cleanup] END cleaning temp data for Job: PAR-JOB-456
    [NotificationHandler: UpdateDB] END updating Job: PAR-JOB-456 to Completed, Link: /exports/PAR-JOB-456.zip
    [NotificationHandler: Email] END sending email to User: user-B
FINEST: [DateTime]: Kyron.NotificationDispatcher: [Early Parallel] Future.wait completed for DataExportCompletedNotificationParallel [HASHCODE]
FINER: [DateTime]: Kyron.NotificationDispatcher: Completed Early Parallel phase for DataExportCompletedNotificationParallel [HASHCODE].
INFO: [DateTime]: Kyron.NotificationDispatcher: Finished dispatching notification DataExportCompletedNotificationParallel [HASHCODE]. Errors collected: 0 (Strategy: continueOnError).
FINER: [DateTime]: Kyron.PipelineExecutor: Core handler ProcessDataExportJobCommandHandlerParallel completed for request [HASHCODE]
FINE: [DateTime]: Kyron.PipelineExecutor: Pipeline execution completed successfully for Future [HASHCODE].
Received response from command handler: Export Job PAR-JOB-456 Completed Successfully (Parallel Notification Triggered)
--- Scenario 2 Complete (Observe Potentially Interleaved Handler Logs Above) ---

--- Example Complete ---