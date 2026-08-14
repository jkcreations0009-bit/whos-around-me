import '../models/live_share_session_ticket.dart';
import '../models/location_observation.dart';
import '../models/sharing_dashboard.dart';
import '../models/visibility_mode.dart';

abstract interface class RemoteSharingService {
  Future<SharingDashboard> getDashboard();
  Future<void> setPrivacyMode(VisibilityMode mode);
  Future<LiveShareSessionTicket> startLiveSharing();
  Future<void> stopLiveSharing();
  Future<void> publishObservation({
    required LiveShareSessionTicket ticket,
    required LocationObservation observation,
  });
}
