import '../../domain/models/live_share_session_ticket.dart';
import '../../domain/models/location_observation.dart';
import '../../domain/models/sharing_dashboard.dart';
import '../../domain/models/visibility_mode.dart';
import '../../domain/repositories/remote_sharing_service.dart';
import 'firebase_live_location_gateway.dart';
import 'firebase_privacy_consent_gateway.dart';
import 'firebase_sharing_dashboard_gateway.dart';

final class FirebaseRemoteSharingService implements RemoteSharingService {
  FirebaseRemoteSharingService({
    required FirebasePrivacyConsentGateway privacy,
    required FirebaseLiveLocationGateway liveLocation,
    required FirebaseSharingDashboardGateway dashboard,
  })  : _privacy = privacy,
        _liveLocation = liveLocation,
        _dashboard = dashboard;

  final FirebasePrivacyConsentGateway _privacy;
  final FirebaseLiveLocationGateway _liveLocation;
  final FirebaseSharingDashboardGateway _dashboard;

  @override
  Future<SharingDashboard> getDashboard() => _dashboard.getDashboard();

  @override
  Future<void> setPrivacyMode(VisibilityMode mode) =>
      _privacy.setPrivacyMode(mode);

  @override
  Future<LiveShareSessionTicket> startLiveSharing() =>
      _liveLocation.startLiveSharing();

  @override
  Future<void> stopLiveSharing() => _liveLocation.stopLiveSharing();

  @override
  Future<void> publishObservation({
    required LiveShareSessionTicket ticket,
    required LocationObservation observation,
  }) async {
    final double? accuracyMeters = observation.accuracy?.meters;
    if (accuracyMeters == null) {
      throw const FormatException(
        'Remote sharing requires an explicit location accuracy estimate.',
      );
    }
    await _liveLocation.publishLiveLocation(
      ticket: ticket,
      latitude: observation.coordinate.latitude,
      longitude: observation.coordinate.longitude,
      accuracyMeters: accuracyMeters,
      capturedAtMs: observation.observedAtUtc.toUtc().millisecondsSinceEpoch,
    );
  }
}
