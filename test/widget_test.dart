import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worm/controllers/app_controller.dart';
import 'package:worm/main.dart';
import 'package:worm/models/word_item.dart';
import 'package:worm/services/notification_service.dart';
import 'package:worm/services/quick_practice_audio_handler.dart';
import 'package:worm/services/tts_service.dart';

class _FakeTtsService extends TtsService {
  final List<String> spokenTexts = [];

  @override
  Future<void> init({double speechRate = 0.48}) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> speakWord(String word) async {
    spokenTexts.add(word);
  }

  @override
  Future<void> speakSentence(String wordKey, String sentence) async {
    spokenTexts.add(sentence);
  }

  @override
  Future<bool> speakWordAndWait(String word) async {
    spokenTexts.add(word);
    return true;
  }

  @override
  Future<bool> speakTurkishAndWait(String wordKey, List<String> meanings) async {
    spokenTexts.add(meanings.join(', '));
    return true;
  }

  @override
  Future<void> stop() async {}
}

class _FakeNotificationService extends NotificationService {
  int dailyScheduleCount = 0;
  int practiceScheduleCount = 0;

  @override
  Future<void> init({void Function(String payload)? onNotificationTap}) async {}

  @override
  Future<bool> requestPermissions({bool requestExactAlarm = false}) async =>
      true;

  @override
  Future<DateTime?> scheduleDailyWordsReminder({
    required bool enabled,
    required int hour,
    required int minute,
    required int dailyWordCount,
  }) async {
    dailyScheduleCount++;
    if (!enabled) return null;
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  @override
  Future<DateTime?> schedulePracticeReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    practiceScheduleCount++;
    if (!enabled) return null;
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }
}

List<WordItem> _sampleWords(int count) {
  return List.generate(
    count,
    (i) => WordItem(
      key: 'word${i + 1}',
      foreignWord: 'word${i + 1}',
      meanings: ['anlam${i + 1}a', 'anlam${i + 1}b'],
      exampleSentence: 'However, word${i + 1} is useful.',
      partOfSpeech: i.isEven ? 'Fiil' : 'İsim',
      memoryHint: 'İpucu ${i + 1}: word${i + 1} çağrışımı.',
      orderIndex: i,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('WordItem.fromMap SQLite satırını tüm alanlarıyla doğru dönüştürür', () {
    final item = WordItem.fromMap({
      'word_key': 'abolish',
      'foreign_word': 'Abolish',
      'meanings': 'İptal Etmek#Kaldırmak',
      'example_sentence': 'They decided to abolish the old rule.',
      'part_of_speech': 'Fiil',
      'memory_hint': 'A-bol-iş: Eski yasayı abolish et.',
      'order_index': 0,
    });

    expect(item.key, 'abolish');
    expect(item.foreignWord, 'Abolish');
    expect(item.meanings, ['İptal Etmek', 'Kaldırmak']);
    expect(item.partOfSpeech, 'Fiil');
    expect(item.memoryHint, 'A-bol-iş: Eski yasayı abolish et.');
    expect(item.orderIndex, 0);
  });

  test('Standalone assets/worm.db veritabanı dosyası mevcuttur', () {
    final dbFile = File('assets/worm.db');
    expect(dbFile.existsSync(), isTrue);
    expect(dbFile.lengthSync(), greaterThan(100 * 1024));
  });

  test('Ezberlenmeyen kelimeler sonraki güne sırası bozulmadan devreder', () async {
    var currentDate = DateTime(2026, 11, 17, 10, 0);
    final fakeTts = _FakeTtsService();
    final controller = AppController(
      ttsService: fakeTts,
      notificationService: _FakeNotificationService(),
      quickAudioHandler: QuickPracticeAudioHandler(ttsService: fakeTts),
      nowProvider: () => currentDate,
      wordsProvider: () async => _sampleWords(15),
      random: Random(42),
    );

    await controller.init();
    expect(
      controller.dailyWords.map((w) => w.foreignWord).toList(),
      ['word1', 'word2', 'word3', 'word4', 'word5'],
    );

    await controller.toggleMemorized('word2');
    await controller.toggleMemorized('word4');
    expect(
      controller.dailyWords.map((w) => w.foreignWord).toList(),
      ['word1', 'word2', 'word3', 'word4', 'word5'],
    );

    currentDate = DateTime(2026, 11, 18, 10, 0);
    await controller.checkDayRolloverAndSync();
    expect(
      controller.dailyWords.map((w) => w.foreignWord).toList(),
      ['word1', 'word3', 'word5', 'word6', 'word7'],
    );
  });

  test('Pratik havuzu tükendiğinde kullanılan kelimeler tekrar havuza dahil edilir', () async {
    var currentDate = DateTime(2026, 11, 17, 10, 0);
    final fakeTts = _FakeTtsService();
    final controller = AppController(
      ttsService: fakeTts,
      notificationService: _FakeNotificationService(),
      quickAudioHandler: QuickPracticeAudioHandler(ttsService: fakeTts),
      nowProvider: () => currentDate,
      wordsProvider: () async => _sampleWords(20),
      random: Random(7),
    );

    await controller.init();

    for (var i = 1; i <= 12; i++) {
      await controller.toggleMemorized('word$i');
    }

    final day1Practice = controller.practiceWords.map((w) => w.key).toSet();
    expect(day1Practice.length, 10);

    currentDate = DateTime(2026, 11, 18, 10, 0);
    await controller.checkDayRolloverAndSync();

    final day2Practice = controller.practiceWords.map((w) => w.key).toSet();
    expect(day2Practice.length, 10);

    final all12 = {for (var i = 1; i <= 12; i++) 'word$i'};
    final remainingFromDay1 = all12.difference(day1Practice);
    expect(remainingFromDay1.length, 2);
    expect(day2Practice.containsAll(remainingFromDay1), isTrue);
  });

  testWidgets('WormApp ana ekranı tür ve ipucunu gösterir, sekmeler arası geçer', (tester) async {
    final fakeTts = _FakeTtsService();
    final controller = AppController(
      ttsService: fakeTts,
      notificationService: _FakeNotificationService(),
      quickAudioHandler: QuickPracticeAudioHandler(ttsService: fakeTts),
      wordsProvider: () async => _sampleWords(15),
    );

    await tester.pumpWidget(WormApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Günün Kelimeleri'), findsOneWidget);
    expect(find.text('WORD1'), findsOneWidget);
    expect(find.text('Fiil'), findsOneWidget);
    expect(find.text('İpucu 1: word1 çağrışımı.'), findsOneWidget);

    await tester.tap(find.text('Hızlı Pratik'));
    await tester.pumpAndSettle();
    expect(find.text('Sesli Tekrar Et'), findsOneWidget);
    expect(find.text('0.75x'), findsOneWidget);
    expect(find.text('1.5x'), findsOneWidget);

    await tester.tap(find.text('Ezberlenen'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz Ezberlenen Kelime Yok'), findsOneWidget);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Günlük Kelime Sayısı'), findsOneWidget);
  });

  test('Bildirim saati her değiştirildiğinde yeniden planlanır', () async {
    final fakeNotif = _FakeNotificationService();
    final fakeTts = _FakeTtsService();
    final controller = AppController(
      ttsService: fakeTts,
      notificationService: fakeNotif,
      quickAudioHandler: QuickPracticeAudioHandler(ttsService: fakeTts),
      wordsProvider: () async => _sampleWords(10),
    );

    await controller.init();
    expect(fakeNotif.dailyScheduleCount, 1);
    expect(fakeNotif.practiceScheduleCount, 1);

    await controller.updateDailyNotification(hour: 23, minute: 58);
    await controller.updateDailyNotification(hour: 23, minute: 59);
    expect(fakeNotif.dailyScheduleCount, 3);

    await controller.updatePracticeNotification(hour: 23, minute: 55);
    expect(fakeNotif.practiceScheduleCount, 2);
  });
}
