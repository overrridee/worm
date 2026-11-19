import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/word_item.dart';
import '../services/quick_practice_audio_handler.dart';

/// Tüm kelimeleri sırasıyla yalnızca İngilizce + Türkçe anlamlarıyla listeleyen,
/// arka planda / kilit ekranında da seri sesli tekrar (İngilizce -> Türkçe)
/// yapabilen ve hız seçimi sunan Hızlı Pratik ekranı.
class QuickPracticeScreen extends StatefulWidget {
  const QuickPracticeScreen({
    super.key,
    required this.controller,
    required this.isActiveTab,
  });

  final AppController controller;
  final bool isActiveTab;

  @override
  State<QuickPracticeScreen> createState() => _QuickPracticeScreenState();
}

class _QuickPracticeScreenState extends State<QuickPracticeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrolledIndex = -1;

  static const _speedPresets = <({String label, double rate})>[
    (label: '0.75x', rate: 0.23),
    (label: '1.0x', rate: 0.48),
    (label: '1.25x', rate: 0.73),
    (label: '1.5x', rate: 0.98),
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToIndexIfNeeded(int index) {
    if (!widget.isActiveTab || !_scrollController.hasClients) return;
    if (_lastScrolledIndex == index) return;
    _lastScrolledIndex = index;

    const estimatedItemHeight = 82.0;
    final targetOffset = (index * estimatedItemHeight) - 120.0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxExtent);

    final currentOffset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;
    final itemTop = index * estimatedItemHeight;
    final itemBottom = itemTop + estimatedItemHeight;

    if (itemTop < currentOffset || itemBottom > currentOffset + viewport) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _selectedSpeedLabel(double currentRate) {
    var best = _speedPresets[1];
    var minDiff = (currentRate - best.rate).abs();
    for (final preset in _speedPresets) {
      final diff = (currentRate - preset.rate).abs();
      if (diff < minDiff) {
        minDiff = diff;
        best = preset;
      }
    }
    return best.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final words = widget.controller.allWords;

    if (words.isEmpty) {
      return const Center(
        child: Text('Gösterilecek kelime bulunamadı.'),
      );
    }

    final status = widget.controller.quickPlaybackStatus;
    final safeCurrent =
        widget.controller.quickPlaybackIndex.clamp(0, words.length - 1);
    final speakingPhase = widget.controller.quickSpeakingPhase;
    final currentWord = words[safeCurrent];
    final isActiveSession = status != QuickPlaybackStatus.idle;
    final activeSpeedLabel =
        _selectedSpeedLabel(widget.controller.ttsSpeechRate);

    if (status == QuickPlaybackStatus.playing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndexIfNeeded(safeCurrent);
      });
    }

    return Column(
      children: [
        // Üst başlık, okuma hızı ve seri sesli tekrar kontrolleri
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hızlı Pratik',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${words.length} kelime • Arka planda ve kilit ekranında çalışır',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (isActiveSession)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '${safeCurrent + 1} / ${words.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Hız seçici satırı
              Row(
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Hız:',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _speedPresets.map((preset) {
                          final selected = preset.label == activeSpeedLabel;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(preset.label),
                              selected: selected,
                              visualDensity: VisualDensity.compact,
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: selected
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onSurfaceVariant,
                              ),
                              onSelected: (_) => widget.controller
                                  .setTtsSpeechRate(preset.rate),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Oynatma kontrol butonları
              Row(
                children: [
                  if (status == QuickPlaybackStatus.idle)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            widget.controller.startQuickPracticeFrom(safeCurrent),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          safeCurrent > 0
                              ? 'Sesli Tekrar Et (${safeCurrent + 1}. Kelimeden)'
                              : 'Sesli Tekrar Et',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    )
                  else ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: status == QuickPlaybackStatus.playing
                            ? widget.controller.pauseQuickPractice
                            : widget.controller.resumeQuickPractice,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: status == QuickPlaybackStatus.playing
                              ? colorScheme.secondary
                              : colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          status == QuickPlaybackStatus.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          status == QuickPlaybackStatus.playing
                              ? 'Duraklat'
                              : 'Devam Et',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: widget.controller.stopQuickPractice,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(110, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text(
                        'Durdur',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),

              if (isActiveSession) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status == QuickPlaybackStatus.playing
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_circle_outline_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status == QuickPlaybackStatus.playing
                              ? 'Okunuyor: ${currentWord.foreignWord.toUpperCase()} (${speakingPhase == 'TR' ? 'Türkçe' : 'İngilizce'})'
                              : 'Duraklatıldı: ${currentWord.foreignWord.toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Tüm kelimelerin sıralı sade listesi (İngilizce + Türkçe anlam)
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: words.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final word = words[index];
                final isSelected =
                    index == safeCurrent && (isActiveSession || index > 0);
                final isPlayingNow = index == safeCurrent &&
                    status == QuickPlaybackStatus.playing;

                return _QuickWordRow(
                  index: index,
                  word: word,
                  isHighlighted: isSelected,
                  isPlayingNow: isPlayingNow,
                  onTap: () => widget.controller.startQuickPracticeFrom(index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickWordRow extends StatelessWidget {
  const _QuickWordRow({
    required this.index,
    required this.word,
    required this.isHighlighted,
    required this.isPlayingNow,
    required this.onTap,
  });

  final int index;
  final WordItem word;
  final bool isHighlighted;
  final bool isPlayingNow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: isHighlighted
          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHighlighted
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.55),
              width: isHighlighted ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  '${index + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isHighlighted
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.foreignWord,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isHighlighted
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      word.meanings.join(' • '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isPlayingNow
                    ? Icons.volume_up_rounded
                    : Icons.play_circle_outline_rounded,
                color: isHighlighted
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
