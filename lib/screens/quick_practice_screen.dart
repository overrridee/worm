import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../models/word_item.dart';

enum _PlaybackState { idle, playing, paused }

/// Tüm kelimeleri sırasıyla yalnızca İngilizce + Türkçe anlamlarıyla listeleyen
/// ve seri sesli tekrar (İngilizce -> Türkçe) imkanı sunan Hızlı Pratik ekranı.
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

  _PlaybackState _playbackState = _PlaybackState.idle;
  int _currentIndex = 0;
  int _sessionToken = 0;
  String _speakingPhase = '';

  @override
  void didUpdateWidget(covariant QuickPracticeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActiveTab &&
        !widget.isActiveTab &&
        _playbackState == _PlaybackState.playing) {
      _pausePlayback();
    }
  }

  @override
  void dispose() {
    _sessionToken++;
    _scrollController.dispose();
    super.dispose();
  }

  void _startFromIndex(int index) {
    final words = widget.controller.allWords;
    if (words.isEmpty) return;

    final safeIndex = index.clamp(0, words.length - 1);
    final token = ++_sessionToken;

    setState(() {
      _currentIndex = safeIndex;
      _playbackState = _PlaybackState.playing;
      _speakingPhase = 'EN';
    });

    _runPlaybackLoop(safeIndex, token);
  }

  Future<void> _pausePlayback() async {
    if (_playbackState != _PlaybackState.playing) return;
    _sessionToken++;
    await widget.controller.tts.stop();
    if (!mounted) return;
    setState(() {
      _playbackState = _PlaybackState.paused;
      _speakingPhase = '';
    });
  }

  Future<void> _stopPlayback() async {
    _sessionToken++;
    await widget.controller.tts.stop();
    if (!mounted) return;
    setState(() {
      _playbackState = _PlaybackState.idle;
      _speakingPhase = '';
    });
  }

  Future<void> _runPlaybackLoop(int startIndex, int token) async {
    final words = widget.controller.allWords;

    for (var i = startIndex; i < words.length; i++) {
      if (!mounted || token != _sessionToken) return;

      final word = words[i];
      setState(() {
        _currentIndex = i;
        _speakingPhase = 'EN';
      });
      _scrollToIndexIfNeeded(i);

      final enCompleted =
          await widget.controller.tts.speakWordAndWait(word.foreignWord);
      if (!enCompleted || !mounted || token != _sessionToken) return;

      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted || token != _sessionToken) return;

      setState(() => _speakingPhase = 'TR');
      final trCompleted = await widget.controller.tts
          .speakTurkishAndWait(word.key, word.meanings);
      if (!trCompleted || !mounted || token != _sessionToken) return;

      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || token != _sessionToken) return;
    }

    if (mounted && token == _sessionToken) {
      setState(() {
        _playbackState = _PlaybackState.idle;
        _speakingPhase = '';
      });
    }
  }

  void _scrollToIndexIfNeeded(int index) {
    if (!_scrollController.hasClients) return;
    const estimatedItemHeight = 82.0;
    final targetOffset = (index * estimatedItemHeight) - 120.0;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxExtent);

    final currentOffset = _scrollController.offset;
    final viewport = _scrollController.position.viewportDimension;
    final itemTop = index * estimatedItemHeight;
    final itemBottom = itemTop + estimatedItemHeight;

    // Yalnızca aktif kelime görünür alanın dışındaysa yumuşakça kaydır.
    if (itemTop < currentOffset || itemBottom > currentOffset + viewport) {
      _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
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

    final safeCurrent = _currentIndex.clamp(0, words.length - 1);
    final currentWord = words[safeCurrent];
    final isActiveSession = _playbackState != _PlaybackState.idle;

    return Column(
      children: [
        // Üst başlık ve seri sesli tekrar kontrolleri
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
                        '${words.length} kelime • Sıralı liste • Dokunarak başlat',
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
              const SizedBox(height: 12),

              // Oynatma kontrol butonları
              Row(
                children: [
                  if (_playbackState == _PlaybackState.idle)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _startFromIndex(safeCurrent),
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
                        onPressed: _playbackState == _PlaybackState.playing
                            ? _pausePlayback
                            : () => _startFromIndex(safeCurrent),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor:
                              _playbackState == _PlaybackState.playing
                                  ? colorScheme.secondary
                                  : colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          _playbackState == _PlaybackState.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          _playbackState == _PlaybackState.playing
                              ? 'Duraklat'
                              : 'Devam Et',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _stopPlayback,
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
                        _playbackState == _PlaybackState.playing
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_circle_outline_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _playbackState == _PlaybackState.playing
                              ? 'Okunuyor: ${currentWord.foreignWord.toUpperCase()} (${_speakingPhase == 'TR' ? 'Türkçe' : 'İngilizce'})'
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
                    _playbackState == _PlaybackState.playing;

                return _QuickWordRow(
                  index: index,
                  word: word,
                  isHighlighted: isSelected,
                  isPlayingNow: isPlayingNow,
                  onTap: () => _startFromIndex(index),
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
