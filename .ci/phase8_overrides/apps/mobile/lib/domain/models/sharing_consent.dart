import 'relationship_state.dart';

final class SharingConsent {
  const SharingConsent({
    required this.ownerUserId,
    required this.viewerUserId,
    required this.relationship,
    required this.ownerApproved,
    required this.viewerApproved,
    required this.selectedByOwner,
    this.ownerApprovedAtUtc,
    this.viewerApprovedAtUtc,
    this.expiresAtUtc,
  });

  final String ownerUserId;
  final String viewerUserId;
  final RelationshipState relationship;
  final bool ownerApproved;
  final bool viewerApproved;
  final bool selectedByOwner;
  final DateTime? ownerApprovedAtUtc;
  final DateTime? viewerApprovedAtUtc;
  final DateTime? expiresAtUtc;

  bool isMutuallyConsentedAt(DateTime nowUtc) {
    if (relationship != RelationshipState.authorized) return false;
    if (!ownerApproved || !viewerApproved) return false;
    if (ownerApprovedAtUtc == null || viewerApprovedAtUtc == null) return false;
    if (expiresAtUtc != null && !expiresAtUtc!.isAfter(nowUtc)) return false;
    return true;
  }
}
