/// API configuration for the MyKB app.
const String kBackendHost = String.fromEnvironment(
  'API_HOST',
  defaultValue: '127.0.0.1',
);

const int kBackendPort = int.fromEnvironment(
  'API_PORT',
  defaultValue: 8000,
);

const String kBackendBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String get effectiveBackendBaseUrl {
  if (kBackendBaseUrl.isNotEmpty) {
    return kBackendBaseUrl;
  }
  return 'http://$kBackendHost:$kBackendPort';
}
