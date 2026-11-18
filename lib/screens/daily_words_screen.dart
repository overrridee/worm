import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../widgets/word_flashcard.dart';

/// Her gün sırayla belirlenen sayıda kelimeyi Instagram karuseli gibi sunan ana ekran.
class DailyWordsScreen extends StatefulWidget {
  const DailyWordsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DailyWordsScreen> createState() => _DailyWordsScreenState();
}

class _DailyWordsScreenState extends State<DailyWordsScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final words = widget.controller.dailyWords;

    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration_rounded,
                size: 72,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                widget.controller.allWordsMemorized
                    ? 'Tebrikler! Tüm kelimeleri ezberledin.'
                    : 'Gösterilecek kelime bulunamadı.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.controller.allWordsMemorized
                    ? 'Ezberlenenler veya Pratik sekmesinden kelimeleri tekrar edebilirsin.'
                    : 'Proje kök dizinindeki words.txt dosyasını kontrol et.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final safePage = _currentPage.clamp(0, words.length - 1);
    final memorizedToday = widget.controller.dailyMemorizedCount;

    return Column(
      children: [
        // Üst ilerleme çubuğu ve sayfa göstergesi
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Günün Kelimeleri',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Bugün $memorizedToday / ${words.length} ezberlendi • Toplam ${widget.controller.memorizedCount}/${widget.controller.totalWordCount}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swipe_rounded,
                      size: 16,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Kaydır',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Instagram tarzı sayfa noktaları
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(words.length, (i) {
              final isActive = i == safePage;
              final isDone = widget.controller.isMemorized(words[i].key);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                width: isActive ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isDone
                      ? Colors.green.shade600
                      : isActive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                ),
              );
            }),
          ),
        ),

        // Yatay kaydırılabilir kelime kartları
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: words.length,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
            },
            itemBuilder: (context, index) {
              final word = words[index];
              final isDone = widget.controller.isMemorized(word.key);

              return WordFlashcard(
                word: word,
                index: index,
                total: words.length,
                isActionDone: isDone,
                actionLabel: 'Ezberlendi',
                doneActionLabel: 'Ezberlendi ✓ (Geri Al)',
                onSpeakWord: () =>
                    widget.controller.tts.speakWord(word.foreignWord),
                onSpeakSentence: () => widget.controller.tts
                    .speakSentence(word.key, word.exampleSentence),
                onActionPressed: () async {
                  final wasDone = isDone;
                  await widget.controller.toggleMemorized(word.key);
                  // İlk kez ezberlendiyse ve sırada sonraki kart varsa nazikçe kaydır
                  if (!wasDone &&
                      index < words.length - 1 &&
                      _pageController.hasClients) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
