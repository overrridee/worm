import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_item.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';

/// Uygulamanın tüm veri, günlük sıra, ezberleme, pratik havuzu ve ayar mantığını yönetir.
class AppController extends ChangeNotifier {
  AppController({
    TtsService? ttsService,
    NotificationService? notificationService,
    DateTime Function()? nowProvider,
    Future<String> Function()? wordsLoader,
    Random? random,
  })  : _tts = ttsService ?? TtsService(),
        _notifications = notificationService ?? NotificationService(),
        _nowProvider = nowProvider ?? DateTime.now,
        _wordsLoader = wordsLoader ?? (() => rootBundle.loadString('words.txt')),
        _random = random ?? Random();

  static const int practiceTargetCount = 10;

  static const String _kMemorizedWords = 'memorized_words';
  static const String _kDailyWordCount = 'daily_word_count';
  static const String _kDailyDate = 'daily_date';
  static const String _kDailyWordKeys = 'daily_word_keys';
  static const String _kPracticeDate = 'practice_date';
  static const String _kPracticeWordKeys = 'practice_word_keys';
  static const String _kPracticeCompletedKeys = 'practice_completed_keys';
  static const String _kUsedPracticePool = 'used_practice_pool';
  static const String _kDailyNotifEnabled = 'daily_notif_enabled';
  static const String _kDailyNotifHour = 'daily_notif_hour';
  static const String _kDailyNotifMinute = 'daily_notif_minute';
  static const String _kPracticeNotifEnabled = 'practice_notif_enabled';
  static const String _kPracticeNotifHour = 'practice_notif_hour';
  static const String _kPracticeNotifMinute = 'practice_notif_minute';
  static const String _kPracticeAutoSpeak = 'practice_auto_speak';
  static const String _kPracticeSpeakSentence = 'practice_speak_sentence';
  static const String _kTtsSpeechRate = 'tts_speech_rate';

  final TtsService _tts;
  final NotificationService _notifications;
  final DateTime Function() _nowProvider;
  final Future<String> Function() _wordsLoader;
  final Random _random;

  late SharedPreferences _prefs;

  bool _isLoading = true;
  String? _loadError;

  List<WordItem> _allWords = const [];
  final Map<String, WordItem> _wordMap = {};

  Set<String> _memorizedKeys = {};
  List<String> _dailyWordKeys = [];
  List<String> _practiceWordKeys = [];
  Set<String> _practiceCompletedKeys = {};
  Set<String> _usedPracticePool = {};

  int _dailyWordCount = 5;
  String _dailyDate = '';
  String _practiceDate = '';

  bool _dailyNotifEnabled = true;
  int _dailyNotifHour = 9;
  int _dailyNotifMinute = 0;

  bool _practiceNotifEnabled = true;
  int _practiceNotifHour = 20;
  int _practiceNotifMinute = 0;

  bool _practiceAutoSpeak = true;
  bool _practiceSpeakSentence = false;
  double _ttsSpeechRate = 0.48;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  List<WordItem> get allWords => _allWords;
  int get totalWordCount => _allWords.length;
  int get memorizedCount => _memorizedKeys.length;
  int get dailyWordCount => _dailyWordCount;

  bool get dailyNotifEnabled => _dailyNotifEnabled;
  int get dailyNotifHour => _dailyNotifHour;
  int get dailyNotifMinute => _dailyNotifMinute;

  bool get practiceNotifEnabled => _practiceNotifEnabled;
  int get practiceNotifHour => _practiceNotifHour;
  int get practiceNotifMinute => _practiceNotifMinute;

  bool get practiceAutoSpeak => _practiceAutoSpeak;
  bool get practiceSpeakSentence => _practiceSpeakSentence;
  double get ttsSpeechRate => _ttsSpeechRate;

  TtsService get tts => _tts;

  List<WordItem> get dailyWords => _dailyWordKeys
      .map((k) => _wordMap[k])
      .whereType<WordItem>()
      .toList(growable: false);

  List<WordItem> get practiceWords => _practiceWordKeys
      .map((k) => _wordMap[k])
      .whereType<WordItem>()
      .toList(growable: false);

  List<WordItem> get memorizedWords => _allWords
      .where((w) => _memorizedKeys.contains(w.key))
      .toList(growable: false);

  int get dailyMemorizedCount =>
      dailyWords.where((w) => _memorizedKeys.contains(w.key)).length;

  int get practiceCompletedCount =>
      practiceWords.where((w) => _practiceCompletedKeys.contains(w.key)).length;

  bool get allWordsMemorized =>
      _allWords.isNotEmpty && _memorizedKeys.length >= _allWords.length;

  bool isMemorized(String key) => _memorizedKeys.contains(key);
  bool isPracticeCompleted(String key) => _practiceCompletedKeys.contains(key);

  Future<void> init({void Function(String payload)? onNotificationTap}) async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      _prefs = await SharedPreferences.getInstance();
      final content = await _wordsLoader();
      _allWords = WordParser.parseContent(content);
      _wordMap
        ..clear()
        ..addEntries(_allWords.map((w) => MapEntry(w.key, w)));

      _loadPreferences();
      await checkDayRolloverAndSync(scheduleNotifications: false);
    } catch (e) {
      _loadError = 'Kelimeler yüklenirken bir hata oluştu: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Ses ve bildirim servisleri kelimelerin yüklenmesini engellememeli.
    try {
      await _tts.init(speechRate: _ttsSpeechRate);
    } catch (e) {
      debugPrint('TTS başlatma uyarısı: $e');
    }

    try {
      await _notifications.init(onNotificationTap: onNotificationTap);
      await _syncNotifications();
    } catch (e) {
      debugPrint('Bildirim başlatma uyarısı: $e');
    }
  }

  void _loadPreferences() {
    final validKeys = _wordMap.keys.toSet();

    _memorizedKeys = (_prefs.getStringList(_kMemorizedWords) ?? const [])
        .where(validKeys.contains)
        .toSet();

    _dailyWordCount = (_prefs.getInt(_kDailyWordCount) ?? 5).clamp(1, 20);
    _dailyDate = _prefs.getString(_kDailyDate) ?? '';
    _dailyWordKeys = (_prefs.getStringList(_kDailyWordKeys) ?? const [])
        .where(validKeys.contains)
        .toList();

    _practiceDate = _prefs.getString(_kPracticeDate) ?? '';
    _practiceWordKeys = (_prefs.getStringList(_kPracticeWordKeys) ?? const [])
        .where((k) => validKeys.contains(k) && _memorizedKeys.contains(k))
        .toList();
    _practiceCompletedKeys =
        (_prefs.getStringList(_kPracticeCompletedKeys) ?? const [])
            .where(_practiceWordKeys.contains)
            .toSet();
    _usedPracticePool = (_prefs.getStringList(_kUsedPracticePool) ?? const [])
        .where(_memorizedKeys.contains)
        .toSet();

    _dailyNotifEnabled = _prefs.getBool(_kDailyNotifEnabled) ?? true;
    _dailyNotifHour = _prefs.getInt(_kDailyNotifHour) ?? 9;
    _dailyNotifMinute = _prefs.getInt(_kDailyNotifMinute) ?? 0;

    _practiceNotifEnabled = _prefs.getBool(_kPracticeNotifEnabled) ?? true;
    _practiceNotifHour = _prefs.getInt(_kPracticeNotifHour) ?? 20;
    _practiceNotifMinute = _prefs.getInt(_kPracticeNotifMinute) ?? 0;

    _practiceAutoSpeak = _prefs.getBool(_kPracticeAutoSpeak) ?? true;
    _practiceSpeakSentence = _prefs.getBool(_kPracticeSpeakSentence) ?? false;
    _ttsSpeechRate =
        (_prefs.getDouble(_kTtsSpeechRate) ?? 0.48).clamp(0.25, 0.85);
  }

  String _todayString() {
    final now = _nowProvider();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Uygulama açıldığında veya ön plana geldiğinde gün değişimini kontrol eder.
  Future<void> checkDayRolloverAndSync({bool scheduleNotifications = false}) async {
    final today = _todayString();
    var changed = false;

    if (_dailyDate != today || _dailyWordKeys.isEmpty) {
      _buildDailyWordsForDate(today);
      changed = true;
    }

    if (_practiceDate != today ||
        (_practiceWordKeys.isEmpty && _memorizedKeys.isNotEmpty)) {
      _buildPracticeWordsForDate(today);
      changed = true;
    }

    if (changed) {
      await _persistState();
      notifyListeners();
    }

    if (scheduleNotifications) {
      await _syncNotifications();
    }
  }

  /// Sırayı bozmadan henüz ezberlenmemiş ilk [_dailyWordCount] kelimeyi seçer.
  /// Dün ezberlenmeyenler orijinal sırasıyla listenin başında kalır.
  void _buildDailyWordsForDate(String date) {
    _dailyDate = date;
    _dailyWordKeys = _allWords
        .where((w) => !_memorizedKeys.contains(w.key))
        .take(_dailyWordCount)
        .map((w) => w.key)
        .toList();
  }

  /// Ezberlenen kelimeler arasından daha önce pratikte çıkmamış rastgele 10 kelime seçer.
  /// Havuz tükendiğinde kullanılanlar tekrar havuza dahil edilir.
  void _buildPracticeWordsForDate(String date) {
    _practiceDate = date;
    _practiceCompletedKeys.clear();

    final memorizedList = memorizedWords.map((w) => w.key).toList();
    if (memorizedList.isEmpty) {
      _practiceWordKeys = [];
      return;
    }

    final target = min(practiceTargetCount, memorizedList.length);
    final unused = memorizedList
        .where((k) => !_usedPracticePool.contains(k))
        .toList()
      ..shuffle(_random);

    final selected = <String>[];
    if (unused.length >= target) {
      selected.addAll(unused.take(target));
    } else {
      selected.addAll(unused);
      // Kullanılanlar tükendiği için havuzu sıfırlayıp tekrar dahil et.
      _usedPracticePool.clear();

      final remainingCandidates = memorizedList
          .where((k) => !selected.contains(k))
          .toList()
        ..shuffle(_random);

      final needed = target - selected.length;
      selected.addAll(remainingCandidates.take(needed));
    }

    _usedPracticePool.addAll(selected);
    _practiceWordKeys = selected;
  }

  /// Kelimeyi ezberlendi / ezberlenmedi olarak işaretler.
  /// Gün içindeki kart akışını bozmamak için mevcut günlük kart yerinden kaldırılmaz;
  /// sonraki gün ezberlenmeyenler sıranın başında kalmaya devam eder.
  Future<void> toggleMemorized(String key) async {
    if (!_wordMap.containsKey(key)) return;

    if (_memorizedKeys.contains(key)) {
      _memorizedKeys.remove(key);
      _usedPracticePool.remove(key);
      _practiceWordKeys.remove(key);
      _practiceCompletedKeys.remove(key);
    } else {
      _memorizedKeys.add(key);
      if (_practiceWordKeys.length < practiceTargetCount &&
          !_practiceWordKeys.contains(key)) {
        _practiceWordKeys.add(key);
        _usedPracticePool.add(key);
      }
    }

    await _persistState();
    notifyListeners();
  }

  /// Pratik ekranında bir kelimeyi tekrar edildi olarak işaretler/kaldırır.
  Future<void> togglePracticeCompleted(String key) async {
    if (!_practiceWordKeys.contains(key)) return;

    if (_practiceCompletedKeys.contains(key)) {
      _practiceCompletedKeys.remove(key);
    } else {
      _practiceCompletedKeys.add(key);
    }

    await _prefs.setStringList(
      _kPracticeCompletedKeys,
      _practiceCompletedKeys.toList(),
    );
    notifyListeners();
  }

  /// Kullanıcının isteğiyle aynı gün içinde yeni bir 10'lu rastgele pratik seti oluşturur.
  Future<void> generateNextPracticeSet() async {
    _buildPracticeWordsForDate(_todayString());
    await _persistState();
    notifyListeners();
  }

  /// Ayarlardan günlük kelime sayısını günceller.
  Future<void> setDailyWordCount(int count) async {
    final clamped = count.clamp(1, 20);
    if (_dailyWordCount == clamped) return;

    _dailyWordCount = clamped;

    // Gün içindeki henüz ezberlenmemiş sırayı koruyarak yeni sayıya uyarla.
    final unmemorizedToday = _dailyWordKeys
        .where((k) => !_memorizedKeys.contains(k))
        .toList();
    final memorizedToday = _dailyWordKeys
        .where((k) => _memorizedKeys.contains(k))
        .toList();

    final rebuilt = <String>[
      ...memorizedToday,
      ...unmemorizedToday,
    ];

    if (rebuilt.length > _dailyWordCount) {
      // Önce ezberlenmemiş sondakileri kırp, gerekirse listeyi yeni sayıya indir.
      final trimmed = <String>[];
      for (final w in _allWords) {
        if (rebuilt.contains(w.key)) {
          trimmed.add(w.key);
          if (trimmed.length >= _dailyWordCount) break;
        }
      }
      _dailyWordKeys = trimmed;
    } else if (rebuilt.length < _dailyWordCount) {
      final existing = rebuilt.toSet();
      final extras = _allWords
          .where((w) => !_memorizedKeys.contains(w.key) && !existing.contains(w.key))
          .take(_dailyWordCount - rebuilt.length)
          .map((w) => w.key);
      _dailyWordKeys = [...rebuilt, ...extras];
    }

    await _prefs.setInt(_kDailyWordCount, _dailyWordCount);
    await _prefs.setStringList(_kDailyWordKeys, _dailyWordKeys);
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> updateDailyNotification({
    bool? enabled,
    int? hour,
    int? minute,
  }) async {
    _dailyNotifEnabled = enabled ?? _dailyNotifEnabled;
    _dailyNotifHour = hour ?? _dailyNotifHour;
    _dailyNotifMinute = minute ?? _dailyNotifMinute;

    await _prefs.setBool(_kDailyNotifEnabled, _dailyNotifEnabled);
    await _prefs.setInt(_kDailyNotifHour, _dailyNotifHour);
    await _prefs.setInt(_kDailyNotifMinute, _dailyNotifMinute);

    if (_dailyNotifEnabled) {
      await _notifications.requestPermissions();
    }
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> updatePracticeNotification({
    bool? enabled,
    int? hour,
    int? minute,
  }) async {
    _practiceNotifEnabled = enabled ?? _practiceNotifEnabled;
    _practiceNotifHour = hour ?? _practiceNotifHour;
    _practiceNotifMinute = minute ?? _practiceNotifMinute;

    await _prefs.setBool(_kPracticeNotifEnabled, _practiceNotifEnabled);
    await _prefs.setInt(_kPracticeNotifHour, _practiceNotifHour);
    await _prefs.setInt(_kPracticeNotifMinute, _practiceNotifMinute);

    if (_practiceNotifEnabled) {
      await _notifications.requestPermissions();
    }
    await _syncNotifications();
    notifyListeners();
  }

  Future<void> setPracticeAutoSpeak(bool value) async {
    _practiceAutoSpeak = value;
    await _prefs.setBool(_kPracticeAutoSpeak, value);
    if (!value) {
      await _tts.stop();
    }
    notifyListeners();
  }

  Future<void> setPracticeSpeakSentence(bool value) async {
    _practiceSpeakSentence = value;
    await _prefs.setBool(_kPracticeSpeakSentence, value);
    notifyListeners();
  }

  Future<void> setTtsSpeechRate(double rate) async {
    _ttsSpeechRate = rate.clamp(0.25, 0.85);
    await _tts.setSpeechRate(_ttsSpeechRate);
    await _prefs.setDouble(_kTtsSpeechRate, _ttsSpeechRate);
    notifyListeners();
  }

  Future<void> speakPracticeWord(WordItem word) async {
    if (_practiceSpeakSentence && word.exampleSentence.isNotEmpty) {
      await _tts.speakWordAndSentence(word.foreignWord, word.exampleSentence);
    } else {
      await _tts.speakWord(word.foreignWord);
    }
  }

  Future<void> _syncNotifications() async {
    await _notifications.scheduleDailyWordsReminder(
      enabled: _dailyNotifEnabled,
      hour: _dailyNotifHour,
      minute: _dailyNotifMinute,
      dailyWordCount: _dailyWordCount,
    );
    await _notifications.schedulePracticeReminder(
      enabled: _practiceNotifEnabled,
      hour: _practiceNotifHour,
      minute: _practiceNotifMinute,
    );
  }

  Future<void> _persistState() async {
    await _prefs.setStringList(_kMemorizedWords, _memorizedKeys.toList());
    await _prefs.setString(_kDailyDate, _dailyDate);
    await _prefs.setStringList(_kDailyWordKeys, _dailyWordKeys);
    await _prefs.setString(_kPracticeDate, _practiceDate);
    await _prefs.setStringList(_kPracticeWordKeys, _practiceWordKeys);
    await _prefs.setStringList(
      _kPracticeCompletedKeys,
      _practiceCompletedKeys.toList(),
    );
    await _prefs.setStringList(
      _kUsedPracticePool,
      _usedPracticePool.toList(),
    );
  }
}
