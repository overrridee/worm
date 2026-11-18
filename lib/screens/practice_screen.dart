import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../widgets/word_flashcard.dart';

/// Ezberlenen kelimelerden rastgele 10 kelimeyle otomatik seslendirmeli pratik ekranı.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.controller,
    required this.isActiveTab,
  });

  final AppController controller;
  final bool isActiveTab;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  String? _lastSpokenKey;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);
    if (widget.isActiveTab) {
      _scheduleInitialSpeak();
    }
  }

  @override
  void didUpdateWidget(covariant PracticeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActiveTab && !oldWidget.isActiveTab) {
      _scheduleInitialSpeak();
    }
  }

  void _scheduleInitialSpeak() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActiveTab) return;
      _speakCurrentIfEnabled();
    });
  }

  void _speakCurrentIfEnabled() {
    if (!widget.controller.practiceAutoSpeak) return;
    final words = widget.controller.practiceWords;
    if (words.isEmpty) return;

    final safeIndex = _currentPage.clamp(0, words.length - 1);
    final currentWord = words[safeIndex];
    if (_lastSpokenKey == currentWord.key) return;

    _lastSpokenKey = currentWord.key;
    widget.controller.speakPracticeWord(currentWord);
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
    final words = widget.controller.practiceWords;

    if (words.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.headphones_rounded,
                size: 72,
                color: colorScheme.tertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Henüz Pratik Yapılacak Kelime Yok',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ana ekrandan kelimeleri "Ezberlendi" olarak işaretlediğinde burada rastgele 10 kelimelik sesli pratik listesi oluşacaktır.',
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
    final completedCount = widget.controller.practiceCompletedCount;
    final allDone = completedCount == words.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Günlük Pratik',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$completedCount / ${words.length} tekrar edildi • Kaydırdıkça seslendirilir',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: widget.controller.practiceAutoSpeak
                    ? 'Otomatik seslendirme açık'
                    : 'Otomatik seslendirme kapalı',
                onPressed: () {
                  widget.controller.setPracticeAutoSpeak(
                    !widget.controller.practiceAutoSpeak,
                  );
                },
                icon: Icon(
                  widget.controller.practiceAutoSpeak
                      ? Icons.record_voice_over_rounded
                      : Icons.voice_over_off_rounded,
                  color: widget.controller.practiceAutoSpeak
                      ? colorScheme.tertiary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: 'Yeni rastgele set getir',
                onPressed: () async {
                  _lastSpokenKey = null;
                  await widget.controller.generateNextPracticeSet();
                  if (_pageController.hasClients) {
                    _pageController.jumpToPage(0);
                  }
                  setState(() => _currentPage = 0);
                  _speakCurrentIfEnabled();
                },
                icon: const Icon(Icons.shuffle_rounded),
              ),
            ],
          ),
        ),

        // Sayfa noktaları
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(words.length, (i) {
              final isActive = i == safePage;
              final isDone =
                  widget.controller.isPracticeCompleted(words[i].key);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isDone
                      ? Colors.green.shade600
                      : isActive
                          ? colorScheme.tertiary
                          : colorScheme.outlineVariant,
                ),
              );
            }),
          ),
        ),

        if (allDone)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Material(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, color: Colors.green.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Günün pratiğini tamamladın! Dolaşmaya devam edebilir veya yeni set başlatabilirsin.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: words.length,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              _lastSpokenKey = null;
              _speakCurrentIfEnabled();
            },
            itemBuilder: (context, index) {
              final word = words[index];
              final isDone = widget.controller.isPracticeCompleted(word.key);

              return WordFlashcard(
                word: word,
                index: index,
                total: words.length,
                isActionDone: isDone,
                actionLabel: 'Tekrar Edildi',
                doneActionLabel: 'Tekrar Edildi ✓ (Geri Al)',
                accentColor: colorScheme.tertiary,
                badgeText: 'Pratik ${index + 1} / ${words.length}',
                onSpeakWord: () =>
                    widget.controller.tts.speakWord(word.foreignWord),
                onSpeakSentence: () => widget.controller.tts
                    .speakSentence(word.key, word.exampleSentence),
                onActionPressed: () async {
                  final wasDone = isDone;
                  await widget.controller.togglePracticeCompleted(word.key);
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
