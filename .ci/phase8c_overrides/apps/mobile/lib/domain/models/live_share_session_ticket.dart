final class LiveShareSessionTicket {
  const LiveShareSessionTicket({
    required this.sessionId,
    required this.privacyEpoch,
    required this.expiresAtMs,
  });

  final String sessionId;
  final int privacyEpoch;
  final int expiresAtMs;

  bool isExpiredAt(int nowMs) => expiresAtMs <= nowMs;
}
