// example/notification_example/bin/src/models.dart
import 'package:kyron/kyron.dart'; // BaseRequest, Request, Notification

// --- Commands (Requests) ---

// Command to trigger sequential notification flow
class ProcessDataExportJobCommandSequential extends Request<String> {
  final String jobId;
  final String userId;
  const ProcessDataExportJobCommandSequential(this.jobId, this.userId);

  @override
  String toString() =>
      'ProcessDataExportJobCommandSequential(jobId: $jobId, userId: $userId)';
}

// Command to trigger parallel notification flow
class ProcessDataExportJobCommandParallel extends Request<String> {
  final String jobId;
  final String userId;
  const ProcessDataExportJobCommandParallel(this.jobId, this.userId);

  @override
  String toString() =>
      'ProcessDataExportJobCommandParallel(jobId: $jobId, userId: $userId)';
}

// --- Notifications ---

// Base class for data to avoid repetition (optional)
abstract class DataExportCompletedData extends Notification {
  final String jobId;
  final String userId;
  final String filePath; // Path to the exported file

  const DataExportCompletedData(
      {required this.jobId, required this.userId, required this.filePath});
}

// Notification for sequential handlers
class DataExportCompletedNotificationSequential extends Notification
    implements DataExportCompletedData {
  @override
  final String jobId;
  @override
  final String userId;
  @override
  final String filePath;

  const DataExportCompletedNotificationSequential({
    required this.jobId,
    required this.userId,
    required this.filePath,
  });

  @override
  String toString() =>
      'DataExportCompletedNotificationSequential(jobId: $jobId, userId: $userId, filePath: $filePath)';
}

// Notification for parallel handlers
class DataExportCompletedNotificationParallel extends Notification
    implements DataExportCompletedData {
  @override
  final String jobId;
  @override
  final String userId;
  @override
  final String filePath;

  const DataExportCompletedNotificationParallel({
    required this.jobId,
    required this.userId,
    required this.filePath,
  });

  @override
  String toString() =>
      'DataExportCompletedNotificationParallel(jobId: $jobId, userId: $userId, filePath: $filePath)';
}
