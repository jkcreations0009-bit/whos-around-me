import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/models/live_share_session_ticket.dart';
import '../../domain/models/remote_live_location.dart';

final class FirebaseLiveLocationGateway {
  FirebaseLiveLocationGateway(this._functions);

  final FirebaseFunctions _functions;

  HttpsCallable _strictCallable(String name) {
    return _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
        limitedUseAppCheckToken: true,
      ),
    );
  }

  Future<LiveShareSessionTicket> startLiveSharing() async {
    final HttpsCallableResult<Object?> result =
        await _strictCallable('startLiveSharing').call<Object?>();
    final Map<String, Object?> data = _asMap(result.data);
    return LiveShareSessionTicket(
      sessionId: _requiredString(data, 'sessionId'),
      privacyEpoch: _requiredInt(data, 'privacyEpoch'),
      expiresAtMs: _requiredInt(data, 'expiresAtMs'),
    );
  }

  Future<void> stopLiveSharing() async {
    await _strictCallable('stopLiveSharing').call<Object?>();
  }

  Future<void> publishLiveLocation({
    required LiveShareSessionTicket ticket,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required int capturedAtMs,
  }) async {
    await _strictCallable('publishLiveLocation').call<Object?>(
      <String, Object?>{
        'sessionId': ticket.sessionId,
        'privacyEpoch': ticket.privacyEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'capturedAtMs': capturedAtMs,
      },
    );
  }

  Future<RemoteLiveLocation?> getLiveLocation(String ownerUserId) async {
    final HttpsCallableResult<Object?> result =
        await _strictCallable('getLiveLocation').call<Object?>(
      <String, Object?>{'ownerUserId': ownerUserId},
    );
    final Map<String, Object?> data = _asMap(result.data);
    if (data['available'] != true) return null;
    return RemoteLiveLocation(
      latitude: _requiredDouble(data, 'latitude'),
      longitude: _requiredDouble(data, 'longitude'),
      accuracyMeters: _requiredDouble(data, 'accuracyMeters'),
      capturedAtMs: _requiredInt(data, 'capturedAtMs'),
    );
  }

  Map<String, Object?> _asMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Unexpected callable response.');
    }
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }

  String _requiredString(Map<String, Object?> data, String field) {
    final Object? value = data[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid $field.');
    }
    return value;
  }

  int _requiredInt(Map<String, Object?> data, String field) {
    final Object? value = data[field];
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException('Missing or invalid $field.');
  }

  double _requiredDouble(Map<String, Object?> data, String field) {
    final Object? value = data[field];
    if (value is num && value.isFinite) return value.toDouble();
    throw FormatException('Missing or invalid $field.');
  }
}
