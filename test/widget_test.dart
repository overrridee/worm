import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worm/controllers/app_controller.dart';
import 'package:worm/main.dart';
import 'package:worm/models/word_item.dart';
import 'package:worm/services/notification_service.dart';
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
  @override
  Future<void> init({void Function(String payload)? onNotificationTap}) async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleDailyWordsReminder({
    required bool enabled,
    required int hour,
    required int minute,
    required int dailyWordCount,
  }) async {}

  @override
  Future<void> schedulePracticeReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {}
}

String _sampleWordsTxt(int count) {
  return List.generate(
    count,
    (i) => 'word${i + 1},anlam${i + 1}a#anlam${i + 1}b,However, word${i + 1} is useful.',
  ).join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('WordParser virgüllü cümleleri ve çoklu anlamları doğru ayrıştırır', () {
    const raw =
        'resilient,dayanıklı#esnek#çabuk toparlanan,Even after setbacks, she stayed resilient.\n'
        '\n'
        'invalid_line_without_commas\n'
        'candid,samimi#dürüst,Please be candid, because trust matters.';

    final items = WordParser.parseContent(raw);
    expect(items.length, 2);

    expect(items[0].foreignWord, 'resilient');
    expect(items[0].meanings, ['dayanıklı', 'esnek', 'çabuk toparlanan']);
    expect(items[0].exampleSentence, 'Even after setbacks, she stayed resilient.');

    expect(items[1].foreignWord, 'candid');
    expect(items[1].meanings, ['samimi', 'dürüst']);
    expect(items[1].exampleSentence, 'Please be candid, because trust matters.');
  });

  test('Kök dizindeki words.txt 1124 kelime içerir ve eksiksiz parse edilir', () {
    final content = File('words.txt').readAsStringSync();
    final items = WordParser.parseContent(content);
    expect(items.length, 1124);
    for (final item in items) {
      expect(item.foreignWord, isNotEmpty);
      expect(item.meanings, isNotEmpty);
      expect(item.exampleSentence, isNotEmpty);

      final slug = TtsService.safeSlug(item.foreignWord);
      expect(
        File('assets/audio/words/$slug.mp3').existsSync(),
        isTrue,
        reason: 'Kelime sesi eksik: $slug',
      );
      expect(
        File('assets/audio/sentences/$slug.mp3').existsSync(),
        isTrue,
        reason: 'Cümle sesi eksik: $slug',
      );
      expect(
        File('assets/audio/tr/$slug.mp3').existsSync(),
        isTrue,
        reason: 'Türkçe anlam sesi eksik: $slug',
      );
    }
  });

  test('Ezberlenmeyen kelimeler sonraki güne sırası bozulmadan devreder', () async {
    var currentDate = DateTime(2026, 11, 17, 10, 0);
    final controller = AppController(
      ttsService: _FakeTtsService(),
      notificationService: _FakeNotificationService(),
      nowProvider: () => currentDate,
      wordsLoader: () async => _sampleWordsTxt(15),
      random: Random(42),
    );

    await controller.init();
    expect(
      controller.dailyWords.map((w) => w.foreignWord).toList(),
      ['word1', 'word2', 'word3', 'word4', 'word5'],
    );

    // 2. ve 4. kelime ezberlensin; gün içinde 5 kart korunmalı
    await controller.toggleMemorized('word2');
    await controller.toggleMemorized('word4');
    expect(
      controller.dailyWords.map((w) => w.foreignWord).toList(),
      ['word1', 'word2', 'word3', 'word4', 'word5'],
    );

    // Ertesi güne geçildiğinde ezberlenmeyenler sırayla başta kalır + yeniler eklenir
    currentDate = DateTime(2026, 11, 18, 10, 0);
    await controller.checkDayRolloverAndSync();
    expect(
      controller.dailyWords.map((w) => w.foreignWord).toList(),
      ['word1', 'word3', 'word5', 'word6', 'word7'],
    );
  });

  test('Pratik havuzu tükendiğinde kullanılan kelimeler tekrar havuza dahil edilir', () async {
    var currentDate = DateTime(2026, 11, 17, 10, 0);
    final controller = AppController(
      ttsService: _FakeTtsService(),
      notificationService: _FakeNotificationService(),
      nowProvider: () => currentDate,
      wordsLoader: () async => _sampleWordsTxt(20),
      random: Random(7),
    );

    await controller.init();

    // 12 kelime ezberle
    for (var i = 1; i <= 12; i++) {
      await controller.toggleMemorized('word$i');
    }

    // 1. gün 10 kelime seçilmiş olmalı
    final day1Practice = controller.practiceWords.map((w) => w.key).toSet();
    expect(day1Practice.length, 10);

    // 2. güne geç: kalan 2 kullanılmamış kelime mutlaka yeni sette olmalı + havuz yenilenip 10'a tamamlanmalı
    currentDate = DateTime(2026, 11, 18, 10, 0);
    await controller.checkDayRolloverAndSync();

    final day2Practice = controller.practiceWords.map((w) => w.key).toSet();
    expect(day2Practice.length, 10);

    final all12 = {for (var i = 1; i <= 12; i++) 'word$i'};
    final remainingFromDay1 = all12.difference(day1Practice);
    expect(remainingFromDay1.length, 2);
    expect(day2Practice.containsAll(remainingFromDay1), isTrue);
  });

  testWidgets('WormApp ana ekranı açar ve sekmeler arası geçiş yapar', (tester) async {
    final fakeTts = _FakeTtsService();
    final controller = AppController(
      ttsService: fakeTts,
      notificationService: _FakeNotificationService(),
      wordsLoader: () async => _sampleWordsTxt(15),
    );

    await tester.pumpWidget(WormApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Günün Kelimeleri'), findsOneWidget);
    expect(find.text('WORD1'), findsOneWidget);

    // Hızlı Pratik sekmesine geç
    await tester.tap(find.text('Hızlı Pratik'));
    await tester.pumpAndSettle();
    expect(find.text('Sesli Tekrar Et'), findsOneWidget);

    // Ezberlenenler sekmesine geç
    await tester.tap(find.text('Ezberlenen'));
    await tester.pumpAndSettle();
    expect(find.text('Henüz Ezberlenen Kelime Yok'), findsOneWidget);

    // Ayarlar sekmesine geç
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.text('Günlük Kelime Sayısı'), findsOneWidget);
  });
}
