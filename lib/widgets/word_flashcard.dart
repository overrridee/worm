import 'package:flutter/material.dart';

import '../models/word_item.dart';

/// Instagram karuseli hissiyatında tam kart kelime görünümü.
/// Hem Günlük Kelimeler ekranında hem de Pratik ekranında ortak kullanılır.
class WordFlashcard extends StatelessWidget {
  const WordFlashcard({
    super.key,
    required this.word,
    required this.index,
    required this.total,
    required this.isActionDone,
    required this.actionLabel,
    required this.doneActionLabel,
    required this.onSpeakWord,
    required this.onSpeakSentence,
    required this.onActionPressed,
    this.accentColor,
    this.badgeText,
  });

  final WordItem word;
  final int index;
  final int total;
  final bool isActionDone;
  final String actionLabel;
  final String doneActionLabel;
  final VoidCallback onSpeakWord;
  final VoidCallback onSpeakSentence;
  final VoidCallback onActionPressed;
  final Color? accentColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = accentColor ?? colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActionDone
              ? Colors.green.shade600.withValues(alpha: 0.55)
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: isActionDone ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Üst bilgi satırı: Sayfa sayacı ve durum rozeti
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText ?? '${index + 1} / $total',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isActionDone)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tamamlandı',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const Spacer(flex: 2),

            // Yabancı Kelime (Büyük Harflerle) + Hoparlör
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    word.foreignWord.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: colorScheme.onSurface,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _SpeakerButton(
                  tooltip: 'Kelimeyi seslendir',
                  color: primary,
                  onPressed: onSpeakWord,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Türkçe Anlamlar
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: word.meanings.map((meaning) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      meaning,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const Spacer(flex: 3),

            // Örnek Yabancı Cümle + Hoparlör
            if (word.exampleSentence.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ÖRNEK CÜMLE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        _SpeakerButton(
                          tooltip: 'Cümleyi seslendir',
                          color: primary,
                          size: 36,
                          iconSize: 20,
                          onPressed: onSpeakSentence,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _HighlightedSentence(
                      sentence: word.exampleSentence,
                      targetWord: word.foreignWord,
                      highlightColor: primary,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.45,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 18),

            // Alt Ezberlendi / Pratik İşaretleme Butonu
            FilledButton.icon(
              onPressed: onActionPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor:
                    isActionDone ? Colors.green.shade600 : primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(
                isActionDone
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
              ),
              label: Text(
                isActionDone ? doneActionLabel : actionLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerButton extends StatelessWidget {
  const _SpeakerButton({
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 24,
  });

  final String tooltip;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.volume_up_rounded,
              color: color,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightedSentence extends StatelessWidget {
  const _HighlightedSentence({
    required this.sentence,
    required this.targetWord,
    required this.highlightColor,
    required this.style,
  });

  final String sentence;
  final String targetWord;
  final Color highlightColor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final regex = RegExp(
      '\\b${RegExp.escape(targetWord)}\\w*',
      caseSensitive: false,
    );
    final matches = regex.allMatches(sentence).toList();
    if (matches.isEmpty) {
      return Text(sentence, style: style);
    }

    final spans = <TextSpan>[];
    var lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: sentence.substring(lastIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: sentence.substring(match.start, match.end),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: highlightColor,
          ),
        ),
      );
      lastIndex = match.end;
    }
    if (lastIndex < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(lastIndex)));
    }

    return Text.rich(
      TextSpan(style: style, children: spans),
    );
  }
}
