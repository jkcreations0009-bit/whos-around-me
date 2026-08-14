import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/models/visibility_mode.dart';

final class FirebasePrivacyConsentGateway {
  FirebasePrivacyConsentGateway(this._functions);

  final FirebaseFunctions _functions;

  HttpsCallable _criticalCallable(String name) {
    return _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
        limitedUseAppCheckToken: true,
      ),
    );
  }

  Future<void> setPrivacyMode(VisibilityMode mode) async {
    await _criticalCallable('setPrivacyMode').call<Map<String, dynamic>>(
      <String, Object?>{
        'visibilityMode': _visibilityName(mode),
      },
    );
  }

  Future<void> requestSharing(String viewerUserId) async {
    await _criticalCallable('requestLocationSharing').call<Map<String, dynamic>>(
      <String, Object?>{
        'viewerUserId': viewerUserId,
      },
    );
  }

  Future<void> respondToSharing({
    required String ownerUserId,
    required bool approved,
  }) async {
    await _criticalCallable('respondToLocationSharing')
        .call<Map<String, dynamic>>(<String, Object?>{
      'ownerUserId': ownerUserId,
      'approved': approved,
    });
  }

  Future<void> revokeSharing({
    required String ownerUserId,
    required String viewerUserId,
  }) async {
    await _criticalCallable('revokeLocationSharing')
        .call<Map<String, dynamic>>(<String, Object?>{
      'ownerUserId': ownerUserId,
      'viewerUserId': viewerUserId,
    });
  }

  Future<void> setSelectedViewer({
    required String viewerUserId,
    required bool selected,
  }) async {
    await _criticalCallable('setSelectedViewer')
        .call<Map<String, dynamic>>(<String, Object?>{
      'viewerUserId': viewerUserId,
      'selected': selected,
    });
  }

  Future<void> blockUser(String viewerUserId) async {
    await _criticalCallable('blockUser').call<Map<String, dynamic>>(
      <String, Object?>{
        'viewerUserId': viewerUserId,
      },
    );
  }

  String _visibilityName(VisibilityMode mode) {
    return switch (mode) {
      VisibilityMode.privateLocal => 'PRIVATE_LOCAL',
      VisibilityMode.visibleApproved => 'VISIBLE_APPROVED',
      VisibilityMode.visibleSelected => 'VISIBLE_SELECTED',
      VisibilityMode.hidden => 'HIDDEN',
    };
  }
}
