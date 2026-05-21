import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NfcHceService {
  static const _channel = MethodChannel('ses_coin/hce');

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isSupported => isAndroid;

  /// Activates HCE and stores [token] so readers can fetch it.
  static Future<void> startEmitting(String token) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('startEmitting', {'token': token});
  }

  /// Deactivates HCE — clears the stored token.
  static Future<void> stopEmitting() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('stopEmitting');
  }

  /// Returns true if a token is currently being emitted.
  static Future<bool> isEmitting() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('isEmitting') ?? false;
  }

  /// Ouvre les paramètres NFC Android pour que l'utilisateur puisse l'activer.
  static Future<void> openNfcSettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('openNfcSettings');
  }

  /// Interroge directement l'adaptateur NFC Android.
  /// Retourne : "enabled" | "disabled" | "not_supported"
  static Future<String> getNfcState() async {
    if (!isSupported) return 'not_supported';
    return await _channel.invokeMethod<String>('getNfcState') ??
        'not_supported';
  }
}
