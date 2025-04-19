// example/notification_example/bin/src/handlers.dart
import 'dart:async';

import 'package:kyron/kyron.dart';
import 'models.dart'; // DataExportCompletedData now extends Notification

// --- Request Handlers (No Change Needed) ---

class ProcessDataExportJobCommandHandlerSequential
    extends RequestHandler<ProcessDataExportJobCommandSequential, String> {
  final KyronInterface _kyron;
  ProcessDataExportJobCommandHandlerSequential(this._kyron);

  @override
  Future<String> handle(ProcessDataExportJobCommandSequential request,
      PipelineContext context) async {
    print('  [CommandHandler Seq] START Export Job ${request.jobId}');
    await Future.delayed(const Duration(milliseconds: 500));
    final filePath = '/exports/${request.jobId}.csv';
    print(
        '  [CommandHandler Seq] END Export Job ${request.jobId}, Path: $filePath');

    final notification = DataExportCompletedNotificationSequential(
      jobId: request.jobId,
      userId: request.userId,
      filePath: filePath,
    );
    print('  [CommandHandler Seq] Publishing $notification');
    await _kyron.publish(notification);
    return 'Export Job ${request.jobId} Completed Successfully (Sequential Notification Triggered)';
  }
}

class ProcessDataExportJobCommandHandlerParallel
    extends RequestHandler<ProcessDataExportJobCommandParallel, String> {
  final KyronInterface _kyron;
  ProcessDataExportJobCommandHandlerParallel(this._kyron);

  @override
  Future<String> handle(ProcessDataExportJobCommandParallel request,
      PipelineContext context) async {
    print('  [CommandHandler Par] START Export Job ${request.jobId}');
    await Future.delayed(const Duration(milliseconds: 400));
    final filePath = '/exports/${request.jobId}.zip';
    print(
        '  [CommandHandler Par] END Export Job ${request.jobId}, Path: $filePath');

    final notification = DataExportCompletedNotificationParallel(
      jobId: request.jobId,
      userId: request.userId,
      filePath: filePath,
    );
    print('  [CommandHandler Par] Publishing $notification');
    await _kyron.publish(notification);
    return 'Export Job ${request.jobId} Completed Successfully (Parallel Notification Triggered)';
  }
}

// --- Notification Handlers (Generic Implementation) ---

// T must be a specific notification type that also has the DataExportCompletedData fields
class UpdateExportRecordHandler<T extends DataExportCompletedData>
    extends NotificationHandler<T> {
  @override
  Future<void> handle(T notification) async {
    // Receives the specific type T
    // No type check needed, notification IS-A DataExportCompletedData
    print(
        '    [NotificationHandler: UpdateDB] START updating Job: ${notification.jobId}');
    await Future.delayed(const Duration(milliseconds: 150));
    print(
        '    [NotificationHandler: UpdateDB] END updating Job: ${notification.jobId} to Completed, Link: ${notification.filePath}');
  }
}

class NotifyUserViaSignalRHandler<T extends DataExportCompletedData>
    extends NotificationHandler<T> {
  @override
  Future<void> handle(T notification) async {
    // Receives the specific type T
    print(
        '    [NotificationHandler: SignalR] START sending notification to User: ${notification.userId} for Job: ${notification.jobId}');
    await Future.delayed(const Duration(milliseconds: 50));
    print(
        '    [NotificationHandler: SignalR] END sending notification to User: ${notification.userId}');
  }
}

class SendExportReadyEmailHandler<T extends DataExportCompletedData>
    extends NotificationHandler<T> {
  @override
  Future<void> handle(T notification) async {
    // Receives the specific type T
    print(
        '    [NotificationHandler: Email] START sending email to User: ${notification.userId} for Job: ${notification.jobId}');
    await Future.delayed(const Duration(milliseconds: 300));
    print(
        '    [NotificationHandler: Email] END sending email to User: ${notification.userId}');
  }
}

class CleanupExportTempDataHandler<T extends DataExportCompletedData>
    extends NotificationHandler<T> {
  @override
  Future<void> handle(T notification) async {
    // Receives the specific type T
    print(
        '    [NotificationHandler: Cleanup] START cleaning temp data for Job: ${notification.jobId}');
    await Future.delayed(const Duration(milliseconds: 80));
    print(
        '    [NotificationHandler: Cleanup] END cleaning temp data for Job: ${notification.jobId}');
  }
}
