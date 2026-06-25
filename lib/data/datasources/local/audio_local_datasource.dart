/// Local storage for audio file paths associated with memo IDs.
///
/// Uses an in-memory map for the current session. Audio paths are
/// associated by memo ID for STT failure recovery (REQ-V-008).
//
// @MX:NOTE: [AUTO] In-memory store — paths are not persisted across app
// restarts. A full persistent implementation would use Hive or SharedPreferences.
class AudioLocalDataSource {
  final Map<String, String> _store = {};

  /// Saves [path] keyed by [id].
  Future<void> saveAudioPath({required String id, required String path}) async {
    _store[id] = path;
  }

  /// Returns the stored path for [id], or null if not found.
  Future<String?> getAudioPath({required String id}) async {
    return _store[id];
  }

  /// Removes the stored path for [id].
  Future<void> deleteAudioPath({required String id}) async {
    _store.remove(id);
  }
}
