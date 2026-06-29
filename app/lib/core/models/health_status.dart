class HealthStatus {
  final bool healthy;
  final String message;

  HealthStatus({required this.healthy, required this.message});

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    final statusValue = json['status']?.toString().toLowerCase();
    final healthy = statusValue == 'ok' || statusValue == 'healthy' || statusValue == 'true';
    return HealthStatus(
      healthy: healthy,
      message: healthy ? 'Connected' : json['message']?.toString() ?? 'Offline',
    );
  }
}
