import 'package:flutter/foundation.dart' show kIsWeb;

// @MX:ANCHOR: [AUTO] PlatformUtils — platform branch contract for audio/STT/storage.
// @MX:REASON: VoiceStateNotifier, RecordVoice, and SyncService depend on these
//             getters for codec selection (REQ-WM-005/006) and remote store routing
//             (REQ-WM-009). Changing the contract breaks all callers.

/// Runtime platform detection utilities.
///
/// Wraps [kIsWeb] as a single source of truth for web-vs-native branching.
/// REQ-WM-007: Runtime platform detection.
class PlatformUtils {
  PlatformUtils._();

  // @MX:NOTE: [AUTO] kIsWeb is a compile-time constant in Flutter's foundation
  //           library. In unit tests running on the VM, it is always false.
  //           Widget tests and integration tests also run on VM, so isWeb == false
  //           in all test environments. The logical contract is verified via
  //           useRemoteStore == isWeb equivalence test.

  /// Returns true when the app is running in a web browser.
  /// REQ-WM-007: kIsWeb runtime check.
  static bool get isWeb => kIsWeb;

  // @MX:WARN: [AUTO] Raw HTML is disabled in MarkdownBody to prevent injection.
  // @MX:REASON: flutter_markdown renders user-supplied content; enabling htmlBlockSyntax
  //             would allow script injection via memo content (REQ security constraint).

  /// Returns true when remote (FastAPI) backend should be used for memo storage.
  /// On web, Hive local storage is replaced by backend datasource (REQ-WM-009).
  static bool get useRemoteStore => kIsWeb;
}
