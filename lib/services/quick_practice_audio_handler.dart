import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import '../models/word_item.dart';
import 'tts_service.dart';

enum QuickPlaybackStatus { idle, playing, paused }

/// Hızlı Pratik seri sesli okumasını arka planda (ekran kilitliyken / uygulama
/// alttayken) yöneten ve Android kilit ekranı medya kontrollerini sağlayan handler.
class QuickPracticeAudioHandler extends BaseAudioHandler {
  QuickPracticeAudioHandler({required TtsService ttsService})
      : _tts = ttsService;

  final TtsService _tts;

  List<WordItem> _words = const [];
  QuickPlaybackStatus _status = QuickPlaybackStatus.idle;
  int _currentIndex = 0;
  int _sessionToken = 0;
  String _speakingPhase = '';

  VoidCallback? onStateChanged;

  QuickPlaybackStatus get status => _status;
  int get currentIndex => _currentIndex;
  String get speakingPhase => _speakingPhase;
  bool get isPlaying => _status == QuickPlaybackStatus.playing;
  bool get isPaused => _status == QuickPlaybackStatus.paused;
  bool get isIdle => _status == QuickPlaybackStatus.idle;

  void setWords(List<WordItem> words) {
    _words = words;
    if (_words.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= _words.length) {
      _currentIndex = 0;
    }
  }

  Future<void> startFromIndex(int index, {List<WordItem>? words}) async {
    if (words != null) {
      _words = words;
    }
    if (_words.isEmpty) return;

    final safeIndex = index.clamp(0, _words.length - 1);
    final token = ++_sessionToken;

    _currentIndex = safeIndex;
    _status = QuickPlaybackStatus.playing;
    _speakingPhase = 'EN';
    _emitUi();

    _runLoop(safeIndex, token);
  }

  @override
  Future<void> play() async {
    if (_words.isEmpty) return;
    if (_status == QuickPlaybackStatus.playing) return;
    await startFromIndex(_currentIndex);
  }

  @override
  Future<void> pause() async {
    if (_status != QuickPlaybackStatus.playing) return;
    _sessionToken++;
    await _tts.stop();
    _status = QuickPlaybackStatus.paused;
    _speakingPhase = '';
    _updateMediaState(playing: false, idle: false);
    _emitUi();
  }

  @override
  Future<void> stop() async {
    _sessionToken++;
    await _tts.stop();
    _status = QuickPlaybackStatus.idle;
    _speakingPhase = '';
    _updateMediaState(playing: false, idle: true);
    _emitUi();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    if (_words.isEmpty) return;
    final nextIndex = (_currentIndex + 1).clamp(0, _words.length - 1);
    await startFromIndex(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    if (_words.isEmpty) return;
    final prevIndex = (_currentIndex - 1).clamp(0, _words.length - 1);
    await startFromIndex(prevIndex);
  }

  Future<void> _runLoop(int startIndex, int token) async {
    for (var i = startIndex; i < _words.length; i++) {
      if (token != _sessionToken) return;

      final word = _words[i];
      _currentIndex = i;
      _speakingPhase = 'EN';
      _updateMediaItem(word, i, _words.length);
      _updateMediaState(playing: true, idle: false);
      _emitUi();

      final enCompleted = await _tts.speakWordAndWait(word.foreignWord);
      if (!enCompleted || token != _sessionToken) return;

      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (token != _sessionToken) return;

      _speakingPhase = 'TR';
      _emitUi();

      final trCompleted =
          await _tts.speakTurkishAndWait(word.key, word.meanings);
      if (!trCompleted || token != _sessionToken) return;

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (token != _sessionToken) return;
    }

    if (token == _sessionToken) {
      _status = QuickPlaybackStatus.idle;
      _speakingPhase = '';
      _updateMediaState(playing: false, idle: true);
      _emitUi();
    }
  }

  void _updateMediaItem(WordItem word, int index, int total) {
    mediaItem.add(
      MediaItem(
        id: word.key,
        album: 'Hızlı Pratik (${index + 1}/$total)',
        title: word.foreignWord,
        artist: word.meanings.join(' • '),
      ),
    );
  }

  void _updateMediaState({required bool playing, required bool idle}) {
    if (idle) {
      playbackState.add(
        playbackState.value.copyWith(
          controls: const [],
          playing: false,
          processingState: AudioProcessingState.idle,
        ),
      );
      return;
    }

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const [0, 1, 2],
        playing: playing,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  void _emitUi() {
    onStateChanged?.call();
  }
}
