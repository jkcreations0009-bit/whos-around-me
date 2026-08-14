import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/models/sharing_dashboard.dart';
import '../../domain/models/visibility_mode.dart';

final class FirebaseSharingDashboardGateway {
  FirebaseSharingDashboardGateway(this._functions);

  final FirebaseFunctions _functions;

  Future<SharingDashboard> getDashboard() async {
    final HttpsCallable callable = _functions.httpsCallable(
      'getSharingDashboard',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
        limitedUseAppCheckToken: true,
      ),
    );
    final HttpsCallableResult<Object?> result = await callable.call<Object?>();
    final Map<String, Object?> data = _asMap(result.data);
    return SharingDashboard(
      visibilityMode: _visibility(data['visibilityMode']),
      liveSharingEnabled: data['liveSharingEnabled'] == true,
      authorizedViewerCount: _nonNegativeInt(data, 'authorizedViewerCount'),
      selectedAuthorizedViewerCount:
          _nonNegativeInt(data, 'selectedAuthorizedViewerCount'),
      pendingViewerCount: _nonNegativeInt(data, 'pendingViewerCount'),
      blockedViewerCount: _nonNegativeInt(data, 'blockedViewerCount'),
      sessionExpiresAtMs: _nullableInt(data['sessionExpiresAtMs']),
    );
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Unexpected sharing dashboard response.');
    }
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  int _nonNegativeInt(Map<String, Object?> data, String field) {
    final int? value = _nullableInt(data[field]);
    if (value == null || value < 0) {
      throw FormatException('Missing or invalid $field.');
    }
    return value;
  }

  int? _nullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw const FormatException('Expected an integer value.');
  }

  VisibilityMode _visibility(Object? value) {
    return switch (value) {
      'VISIBLE_APPROVED' => VisibilityMode.visibleApproved,
      'VISIBLE_SELECTED' => VisibilityMode.visibleSelected,
      'HIDDEN' => VisibilityMode.hidden,
      'PRIVATE_LOCAL' => VisibilityMode.privateLocal,
      _ => throw const FormatException('Unknown visibility mode.'),
    };
  }
}
