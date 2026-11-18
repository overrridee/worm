import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Öncelikli olarak `assets/audio/` içindeki Amerikan İngilizcesi MP3 kayıtlarını
/// çalar; ses dosyası bulunmayan yeni kelimelerde cihazın `flutter_tts` motoruna düşer.
class TtsService {
  TtsService({FlutterTts? tts, AudioPlayer? player})
      : _tts = tts ?? FlutterTts() {
    _player = player;
  }

  final FlutterTts _tts;
  AudioPlayer? _player;
  bool _ttsInitialized = false;
  double _speechRate = 0.48;
  int _playbackToken = 0;

  final Map<String, bool> _assetExistsCache = {};

  double get speechRate => _speechRate;

  AudioPlayer get _audioPlayer => _player ??= AudioPlayer();

  double get _audioPlaybackRate => (0.52 + _speechRate).clamp(0.7, 1.35);

  static String safeSlug(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  Future<void> init({double speechRate = 0.48}) async {
    _speechRate = speechRate.clamp(0.25, 0.85);
    await _initTtsOnly();
  }

  Future<void> _initTtsOnly() async {
    if (_ttsInitialized) {
      await _tts.setSpeechRate(_speechRate);
      return;
    }

    try {
      await _tts.setLanguage('en-US');
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(_speechRate);
      await _tts.awaitSpeakCompletion(false);
      _ttsInitialized = true;
    } catch (e) {
      debugPrint('TTS init hatası: $e');
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.25, 0.85);
    try {
      if (_player != null) {
        await _audioPlayer.setPlaybackRate(_audioPlaybackRate);
      }
      if (_ttsInitialized) {
        await _tts.setSpeechRate(_speechRate);
      }
    } catch (e) {
      debugPrint('Ses hızı ayarlama hatası: $e');
    }
  }

  Future<bool> _assetExists(String fullAssetPath) async {
    final cached = _assetExistsCache[fullAssetPath];
    if (cached != null) return cached;

    try {
      await rootBundle.load(fullAssetPath);
      _assetExistsCache[fullAssetPath] = true;
      return true;
    } catch (_) {
      _assetExistsCache[fullAssetPath] = false;
      return false;
    }
  }

  Future<bool> _playAsset(String relativeAssetPath, int token) async {
    final fullPath = 'assets/$relativeAssetPath';
    if (!await _assetExists(fullPath)) return false;
    if (token != _playbackToken) return true;

    try {
      final player = _audioPlayer;
      await player.stop();
      await player.setPlaybackRate(_audioPlaybackRate);
      await player.play(AssetSource(relativeAssetPath));
      return true;
    } catch (e) {
      debugPrint('Asset ses çalma hatası ($relativeAssetPath): $e');
      return false;
    }
  }

  Future<void> _speakWithTts(String text) async {
    try {
      if (!_ttsInitialized) {
        await _initTtsOnly();
      }
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS fallback hatası: $e');
    }
  }

  /// Kelimeyi seslendirir (önce `assets/audio/words/<slug>.mp3`, yoksa TTS).
  Future<void> speakWord(String word) async {
    final cleaned = word.trim();
    if (cleaned.isEmpty) return;

    final token = ++_playbackToken;
    await _stopEngines();

    final slug = safeSlug(cleaned);
    final played = await _playAsset('audio/words/$slug.mp3', token);
    if (!played && token == _playbackToken) {
      await _speakWithTts(cleaned);
    }
  }

  /// Örnek cümleyi seslendirir (önce `assets/audio/sentences/<slug>.mp3`, yoksa TTS).
  Future<void> speakSentence(String wordKey, String sentence) async {
    final cleanedSentence = sentence.trim();
    if (cleanedSentence.isEmpty) return;

    final token = ++_playbackToken;
    await _stopEngines();

    final slug = safeSlug(wordKey);
    final played = await _playAsset('audio/sentences/$slug.mp3', token);
    if (!played && token == _playbackToken) {
      await _speakWithTts(cleanedSentence);
    }
  }

  /// Genel metin seslendirme (örn. Ayarlar ekranındaki hız testi).
  Future<void> speak(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    final token = ++_playbackToken;
    await _stopEngines();

    final slug = safeSlug(cleaned);
    final played = await _playAsset('audio/words/$slug.mp3', token);
    if (!played && token == _playbackToken) {
      await _speakWithTts(cleaned);
    }
  }

  /// Önce kelimeyi, bitince örnek cümleyi peş peşe seslendirir.
  Future<void> speakWordAndSentence(String word, String sentence) async {
    final w = word.trim();
    final s = sentence.trim();
    if (w.isEmpty && s.isEmpty) return;
    if (s.isEmpty) {
      await speakWord(w);
      return;
    }

    final token = ++_playbackToken;
    await _stopEngines();

    final slug = safeSlug(w);
    final wordPlayed = await _playAsset('audio/words/$slug.mp3', token);

    if (!wordPlayed) {
      if (token == _playbackToken) {
        await _speakWithTts('$w. $s');
      }
      return;
    }

    // Kelime MP3'ü bitene kadar bekle, iptal edilmediyse cümleyi çal.
    try {
      await _audioPlayer.onPlayerComplete.first.timeout(
        const Duration(seconds: 6),
      );
    } catch (_) {}

    if (token != _playbackToken) return;

    final sentencePlayed =
        await _playAsset('audio/sentences/$slug.mp3', token);
    if (!sentencePlayed && token == _playbackToken) {
      await _speakWithTts(s);
    }
  }

  Future<bool> _playAssetAndWait(
    String relativeAssetPath,
    int token, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final played = await _playAsset(relativeAssetPath, token);
    if (!played || token != _playbackToken) return false;

    try {
      await Future.any<void>([
        _audioPlayer.onPlayerComplete.first,
        _audioPlayer.onPlayerStateChanged
            .firstWhere((state) => state == PlayerState.stopped),
      ]).timeout(timeout);
    } catch (_) {}

    return token == _playbackToken;
  }

  /// İngilizce kelimeyi seslendirir ve bitmesini bekler. İptal edilirse `false` döner.
  Future<bool> speakWordAndWait(String word) async {
    final cleaned = word.trim();
    if (cleaned.isEmpty) return true;

    final token = ++_playbackToken;
    await _stopEngines();

    final slug = safeSlug(cleaned);
    final fullPath = 'assets/audio/words/$slug.mp3';
    if (await _assetExists(fullPath)) {
      return _playAssetAndWait('audio/words/$slug.mp3', token);
    }

    if (token != _playbackToken) return false;
    await _speakWithTts(cleaned);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    return token == _playbackToken;
  }

  /// Türkçe anlamları seslendirir ve bitmesini bekler. İptal edilirse `false` döner.
  Future<bool> speakTurkishAndWait(String wordKey, List<String> meanings) async {
    final text = meanings.join(', ').trim();
    if (text.isEmpty) return true;

    final token = ++_playbackToken;
    await _stopEngines();

    final slug = safeSlug(wordKey);
    final fullPath = 'assets/audio/tr/$slug.mp3';
    if (await _assetExists(fullPath)) {
      return _playAssetAndWait(
        'audio/tr/$slug.mp3',
        token,
        timeout: const Duration(seconds: 12),
      );
    }

    if (token != _playbackToken) return false;
    try {
      if (!_ttsInitialized) await _initTtsOnly();
      await _tts.setLanguage('tr-TR');
      await _tts.stop();
      await _tts.speak(text);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      await _tts.setLanguage('en-US');
    } catch (e) {
      debugPrint('Türkçe TTS fallback hatası: $e');
    }
    return token == _playbackToken;
  }

  Future<void> _stopEngines() async {
    try {
      if (_player != null) {
        await _audioPlayer.stop();
      }
      if (_ttsInitialized) {
        await _tts.stop();
      }
    } catch (e) {
      debugPrint('Ses durdurma hatası: $e');
    }
  }

  Future<void> stop() async {
    _playbackToken++;
    await _stopEngines();
  }
}
