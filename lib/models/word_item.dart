/// Tek bir yabancı kelime kaydını ve Türkçe anlamlarını temsil eder.
class WordItem {
  const WordItem({
    required this.key,
    required this.foreignWord,
    required this.meanings,
    required this.exampleSentence,
    required this.orderIndex,
  });

  /// Kelimeyi benzersiz tanımlayan küçük harfli anahtar.
  final String key;

  /// Yabancı kelime (orijinal yazımı).
  final String foreignWord;

  /// `#` ile ayrılmış Türkçe anlamlar listesi.
  final List<String> meanings;

  /// Örnek yabancı cümle.
  final String exampleSentence;

  /// `words.txt` dosyasındaki orijinal sıra numarası.
  final int orderIndex;
}

/// `words.txt` dosyasını güvenli şekilde ayrıştıran yardımcı sınıf.
class WordParser {
  WordParser._();

  /// Tüm dosya içeriğini satır satır okuyup [WordItem] listesine dönüştürür.
  static List<WordItem> parseContent(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final items = <WordItem>[];
    final seenKeys = <String>{};

    for (final rawLine in lines) {
      final parsed = parseLine(rawLine, items.length);
      if (parsed == null) continue;
      if (seenKeys.add(parsed.key)) {
        items.add(parsed);
      }
    }
    return items;
  }

  /// Format: `yabancı_kelime,turkce_anlam1#turkce_anlam2#..,Örnek yabancı Cümle`
  /// Örnek cümle içinde virgül bulunabileceği için yalnızca ilk iki virgüle göre böler.
  static WordItem? parseLine(String rawLine, int orderIndex) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      return null;
    }

    final firstComma = line.indexOf(',');
    if (firstComma <= 0) return null;

    final secondComma = line.indexOf(',', firstComma + 1);
    if (secondComma <= firstComma + 1) return null;

    final foreignWord = line.substring(0, firstComma).trim();
    final meaningsRaw = line.substring(firstComma + 1, secondComma).trim();
    final exampleSentence = line.substring(secondComma + 1).trim();

    if (foreignWord.isEmpty || meaningsRaw.isEmpty) {
      return null;
    }

    final meanings = meaningsRaw
        .split('#')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);

    if (meanings.isEmpty) {
      return null;
    }

    return WordItem(
      key: foreignWord.toLowerCase(),
      foreignWord: foreignWord,
      meanings: meanings,
      exampleSentence: exampleSentence,
      orderIndex: orderIndex,
    );
  }
}
