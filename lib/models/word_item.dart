/// Tek bir yabancı kelime kaydını, türünü, ipucunu ve Türkçe anlamlarını temsil eder.
class WordItem {
  const WordItem({
    required this.key,
    required this.foreignWord,
    required this.meanings,
    required this.exampleSentence,
    required this.orderIndex,
    this.partOfSpeech = '',
    this.memoryHint = '',
  });

  /// SQLite `words` tablosu satırından [WordItem] oluşturur.
  factory WordItem.fromMap(Map<String, Object?> map) {
    final rawMeanings = (map['meanings'] as String? ?? '').trim();
    final meanings = rawMeanings
        .split('#')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList(growable: false);

    return WordItem(
      key: (map['word_key'] as String? ?? '').trim(),
      foreignWord: (map['foreign_word'] as String? ?? '').trim(),
      meanings: meanings,
      exampleSentence: (map['example_sentence'] as String? ?? '').trim(),
      partOfSpeech: (map['part_of_speech'] as String? ?? '').trim(),
      memoryHint: (map['memory_hint'] as String? ?? '').trim(),
      orderIndex: (map['order_index'] as int?) ?? 0,
    );
  }

  /// Kelimeyi benzersiz tanımlayan küçük harfli anahtar.
  final String key;

  /// Yabancı kelime (orijinal yazımı).
  final String foreignWord;

  /// `#` ile ayrılmış Türkçe anlamlar listesi.
  final List<String> meanings;

  /// Örnek yabancı cümle.
  final String exampleSentence;

  /// Kelimenin türü (Fiil, İsim, Sıfat, Zarf vb.).
  final String partOfSpeech;

  /// Akılda kalıcılığı artıran Türkçe-İngilizce karışık çağrışım ipucu.
  final String memoryHint;

  /// Veritabanındaki orijinal sıra numarası.
  final int orderIndex;
}
