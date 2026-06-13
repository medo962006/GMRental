// lib/services/update_checker_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_version.dart';

/// Result of an update check
class UpdateCheckResult {
  final bool isUpdateAvailable;
  final bool isForceUpdateRequired;
  final String? currentVersion;
  final String? minRequiredVersion;
  final int? latestPatchNumber;
  final String? errorMessage;

  const UpdateCheckResult({
    this.isUpdateAvailable = false,
    this.isForceUpdateRequired = false,
    this.currentVersion,
    this.minRequiredVersion,
    this.latestPatchNumber,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

/// Service that checks for OTA updates via Shorebird and
/// validates minimum version requirements against Supabase.
class UpdateCheckerService {
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Full startup check: Shorebird patch + Supabase min version.
  /// Non-blocking: errors are caught and returned in the result.
  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      // 1. Get local app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Check Shorebird for patch updates
      bool shorebirdUpdateAvailable = false;
      if (_updater.isAvailable) {
        final status = await _updater.checkForUpdate();
        shorebirdUpdateAvailable = status == UpdateStatus.outdated ||
            status == UpdateStatus.restartRequired;
      }

      // 3. Check Supabase for minimum required version
      final supabase = Supabase.instance.client;
      final result = await supabase
          .from('app_versions')
          .select()
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle();

      if (result == null) {
        return UpdateCheckResult(
          isUpdateAvailable: shorebirdUpdateAvailable,
          currentVersion: currentVersion,
        );
      }

      final appVersion = AppVersion.fromJson(result);
      final isBelowMinimum = _isVersionBelow(
        currentVersion,
        appVersion.minRequiredVersion,
      );

      return UpdateCheckResult(
        isUpdateAvailable: shorebirdUpdateAvailable,
        isForceUpdateRequired: isBelowMinimum || appVersion.forceUpdateRequired,
        currentVersion: currentVersion,
        minRequiredVersion: appVersion.minRequiredVersion,
        latestPatchNumber: appVersion.latestPatchNumber,
      );
    } catch (e) {
      return UpdateCheckResult(errorMessage: e.toString());
    }
  }

  /// Get current Shorebird patch number (for display).
  Future<int?> getCurrentPatch() async {
    try {
      if (!_updater.isAvailable) return null;
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }

  /// Check if Shorebird updater is available.
  bool isShorebirdAvailable() => _updater.isAvailable;

  /// Manually trigger a Shorebird update check.
  Future<UpdateCheckResult> manualCheck() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!_updater.isAvailable) {
        return const UpdateCheckResult(
          errorMessage: 'Shorebird updater is not available. '
              'This app must be built with "shorebird release" to support OTA updates.',
        );
      }

      final status = await _updater.checkForUpdate();
      final updateAvailable = status == UpdateStatus.outdated ||
          status == UpdateStatus.restartRequired;

      return UpdateCheckResult(
        isUpdateAvailable: updateAvailable,
        currentVersion: currentVersion,
      );
    } catch (e) {
      return UpdateCheckResult(errorMessage: e.toString());
    }
  }

  bool _isVersionBelow(String current, String minimum) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final minimumParts = minimum.split('.').map(int.parse).toList();
      while (currentParts.length < 3) currentParts.add(0);
      while (minimumParts.length < 3) minimumParts.add(0);
      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < minimumParts[i]) return true;
        if (currentParts[i] > minimumParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

final updateCheckerServiceProvider = Provider<UpdateCheckerService>((ref) {
  return UpdateCheckerService();
});

final startupUpdateCheckProvider = FutureProvider<UpdateCheckResult>((ref) async {
  final service = ref.watch(updateCheckerServiceProvider);
  return service.checkForUpdates();
});
