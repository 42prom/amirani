import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_strategy.dart';

/// Service responsible for polling the status of AI generation jobs.
class PlanPollingService {
  final Duration pollInterval;
  final int maxRetries;

  PlanPollingService({
    this.pollInterval = const Duration(seconds: 5),
    this.maxRetries = 24, // 2 minutes total by default
  });

  /// Polls the status of a job until it's COMPLETED or FAILED.
  /// Returns the job data if successful, null otherwise.
  Future<Map<String, dynamic>?> pollJobStatus(
    ApiGenerationStrategy strategy,
    String jobId,
    String type, {
    void Function(double)? onProgress,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        final statusData = await strategy.getJobStatus(jobId, type);
        if (statusData == null) return null;

        final status = statusData['status'] as String;
        final progress = (statusData['progress'] as num?)?.toDouble() ?? 0.0;
        
        if (onProgress != null) onProgress(progress);

        if (status == 'COMPLETED') {
          return statusData['result'] as Map<String, dynamic>?;
        }

        if (status == 'FAILED') {
          debugPrint('[POLL] Job $jobId failed: ${statusData['error']}');
          return null;
        }

        attempts++;
        await Future.delayed(pollInterval);
      } catch (e) {
        debugPrint('[POLL] Error polling job $jobId: $e');
        attempts++;
        await Future.delayed(pollInterval);
      }
    }
    debugPrint('[POLL] Job $jobId timed out after $attempts attempts');
    return null;
  }
}
