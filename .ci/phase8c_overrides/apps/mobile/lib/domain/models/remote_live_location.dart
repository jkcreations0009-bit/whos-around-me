final class RemoteLiveLocation {
  const RemoteLiveLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAtMs,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final int capturedAtMs;
}
