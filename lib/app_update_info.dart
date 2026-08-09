enum AppUpdateStatus {
  notStarted,
  checking,
  updateAvailable,
  upToDate,
  unavailable,
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.status,
    this.currentVersion,
    this.currentBuildNumber,
    this.latestVersion,
    this.latestVersionCode,
    this.downloadUrl,
    this.checkedAt,
    this.errorType,
  });

  final AppUpdateStatus status;
  final String? currentVersion;
  final String? currentBuildNumber;
  final String? latestVersion;
  final int? latestVersionCode;
  final String? downloadUrl;
  final DateTime? checkedAt;
  final String? errorType;
}
