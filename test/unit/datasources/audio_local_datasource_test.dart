// Unit tests for AudioLocalDataSource (REQ-V-001, REQ-V-008)
//
// RED phase: These tests define the contract for audio file path
// storage and retrieval. Implementation does not exist yet.

import 'package:flutter_test/flutter_test.dart';
import 'package:memo_everywhere/data/datasources/local/audio_local_datasource.dart';

void main() {
  late AudioLocalDataSource dataSource;

  setUp(() {
    dataSource = AudioLocalDataSource();
  });

  group('AudioLocalDataSource', () {
    test('saveAudioPath stores and retrieves audio file path by id', () async {
      const id = 'memo-001';
      const path = '/tmp/audio/recording.m4a';

      await dataSource.saveAudioPath(id: id, path: path);
      final result = await dataSource.getAudioPath(id: id);

      expect(result, equals(path));
    });

    test('getAudioPath returns null when no audio saved for id', () async {
      final result = await dataSource.getAudioPath(id: 'nonexistent');

      expect(result, isNull);
    });

    test('saveAudioPath overwrites previous path for same id', () async {
      const id = 'memo-002';
      const firstPath = '/tmp/audio/first.m4a';
      const secondPath = '/tmp/audio/second.m4a';

      await dataSource.saveAudioPath(id: id, path: firstPath);
      await dataSource.saveAudioPath(id: id, path: secondPath);
      final result = await dataSource.getAudioPath(id: id);

      expect(result, equals(secondPath));
    });

    test('deleteAudioPath removes stored path', () async {
      const id = 'memo-003';
      const path = '/tmp/audio/delete_me.m4a';

      await dataSource.saveAudioPath(id: id, path: path);
      await dataSource.deleteAudioPath(id: id);
      final result = await dataSource.getAudioPath(id: id);

      expect(result, isNull);
    });
  });
}
