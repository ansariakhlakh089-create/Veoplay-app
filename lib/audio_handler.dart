part of 'main.dart';

// ==================== Music Notification / Lock-screen (audio_service) ====================
// globalAudioPlayer को wrap करता है. Notification और lock-screen में
// ❤️ Favorite और 🔁 Loop/Shuffle button दिखाता है.
class VeoAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player;
  Set<String> _favIds = {};

  VeoAudioHandler(this._player) {
    _player.playbackEventStream.listen(
      (_) => _broadcast(),
      onError: (Object e, StackTrace st) {},
    );
    _player.playingStream.listen((_) => _broadcast());
    _player.loopModeStream.listen((_) => _broadcast());
    _player.shuffleModeEnabledStream.listen((_) => _broadcast());
    _player.sequenceStateStream.listen(_onSequence);
    _player.durationStream.listen(_onDuration);
    // Favorite बदला (app से या notification से) तो icon अपडेट करो
    musicDataNotifier.addListener(_reloadFavs);
    _reloadFavs();
  }

  void _onSequence(SequenceState? s) {
    final tag = s?.currentSource?.tag;
    if (tag is MediaItem) {
      mediaItem.add(tag.copyWith(duration: _player.duration ?? tag.duration));
    }
    _broadcast();
  }

  void _onDuration(Duration? d) {
    final cur = mediaItem.value;
    if (cur != null && d != null && cur.duration != d) {
      mediaItem.add(cur.copyWith(duration: d));
    }
  }

  Future<void> _reloadFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      _favIds = (p.getStringList('favorite_songs') ?? <String>[]).toSet();
    } catch (_) {}
    _broadcast();
  }

  int get _loopState => _player.loopMode == LoopMode.one
      ? 1
      : (_player.shuffleModeEnabled ? 2 : 0);

  void _broadcast() {
    final playing = _player.playing;
    final cur = mediaItem.value;
    // सिर्फ़ असली गानों में Favorite दिखाओ (video का audio-mode नहीं)
    final isSong = cur != null && int.tryParse(cur.id) != null;
    final fav = cur != null && isSong && _favIds.contains(cur.id);

    final loopState = _loopState;
    const loopIcons = [
      'drawable/ic_loop_off',
      'drawable/ic_loop_one',
      'drawable/ic_loop_shuffle',
    ];
    const loopLabels = ['Repeat off', 'Repeat one', 'Shuffle'];

    final controls = <MediaControl>[
      if (isSong)
        MediaControl.custom(
          androidIcon: fav ? 'drawable/ic_fav_on' : 'drawable/ic_fav_off',
          label: fav ? 'Remove favorite' : 'Favorite',
          name: 'favorite',
        ),
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.skipToNext,
      MediaControl.custom(
        androidIcon: loopIcons[loopState],
        label: loopLabels[loopState],
        name: 'loop',
      ),
    ];
    final base = isSong ? 1 : 0;

    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: [base, base + 1, base + 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));
  }

  Future<void> _toggleFavorite() async {
    final cur = mediaItem.value;
    if (cur == null || int.tryParse(cur.id) == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList('favorite_songs') ?? <String>[];
      if (!list.remove(cur.id)) list.add(cur.id);
      await p.setStringList('favorite_songs', list);
      _favIds = list.toSet();
      musicDataNotifier.value++; // app की screens भी refresh हो जाएँगी
    } catch (e) {
      debugPrint('Notification favorite error: $e');
    }
    _broadcast();
  }

  // app के Loop button जैसा ही चक्र: Off → Repeat one → Shuffle → Off
  Future<void> _cycleLoop() async {
    final next = (_loopState + 1) % 3;
    try {
      if (next == 0) {
        await _player.setShuffleModeEnabled(false);
        await _player.setLoopMode(LoopMode.off);
      } else if (next == 1) {
        await _player.setShuffleModeEnabled(false);
        await _player.setLoopMode(LoopMode.one);
      } else {
        await _player.setLoopMode(LoopMode.all);
        await _player.setShuffleModeEnabled(true);
      }
    } catch (e) {
      debugPrint('Notification loop error: $e');
    }
    _broadcast();
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    if (name == 'favorite') {
      await _toggleFavorite();
    } else if (name == 'loop') {
      await _cycleLoop();
    }
    return super.customAction(name, extras);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}
