import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';

/// Günlük kelime sayısı, bildirim saatleri ve seslendirme ayarları ekranı.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({
    required BuildContext context,
    required int initialHour,
    required int initialMinute,
    required Future<void> Function(int hour, int minute) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      await onPicked(picked.hour, picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            'Ayarlar',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Günlük Kelime Sayısı
        _SettingsSection(
          title: 'Öğrenme Hedefi',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Günlük Kelime Sayısı',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ana ekranda her gün gösterilecek kelime adedi',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        onPressed: controller.dailyWordCount > 1
                            ? () => controller.setDailyWordCount(
                                  controller.dailyWordCount - 1,
                                )
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${controller.dailyWordCount}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: controller.dailyWordCount < 20
                            ? () => controller.setDailyWordCount(
                                  controller.dailyWordCount + 1,
                                )
                            : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Bildirimler
        _SettingsSection(
          title: 'Günlük Bildirimler',
          children: [
            SwitchListTile(
              title: const Text(
                'Yeni Kelime Bildirimi',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Yeni ezberlenecek kelimeler için hatırlatma'),
              value: controller.dailyNotifEnabled,
              onChanged: (val) =>
                  controller.updateDailyNotification(enabled: val),
            ),
            ListTile(
              enabled: controller.dailyNotifEnabled,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Yeni Kelime Saati'),
              trailing: TextButton(
                onPressed: controller.dailyNotifEnabled
                    ? () => _pickTime(
                          context: context,
                          initialHour: controller.dailyNotifHour,
                          initialMinute: controller.dailyNotifMinute,
                          onPicked: (h, m) => controller.updateDailyNotification(
                            hour: h,
                            minute: m,
                          ),
                        )
                    : null,
                child: Text(
                  _formatTime(
                    controller.dailyNotifHour,
                    controller.dailyNotifMinute,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            SwitchListTile(
              title: const Text(
                'Pratik Bildirimi',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Ezberlenen 10 kelimeyle tekrar hatırlatması'),
              value: controller.practiceNotifEnabled,
              onChanged: (val) =>
                  controller.updatePracticeNotification(enabled: val),
            ),
            ListTile(
              enabled: controller.practiceNotifEnabled,
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Pratik Saati'),
              trailing: TextButton(
                onPressed: controller.practiceNotifEnabled
                    ? () => _pickTime(
                          context: context,
                          initialHour: controller.practiceNotifHour,
                          initialMinute: controller.practiceNotifMinute,
                          onPicked: (h, m) =>
                              controller.updatePracticeNotification(
                            hour: h,
                            minute: m,
                          ),
                        )
                    : null,
                child: Text(
                  _formatTime(
                    controller.practiceNotifHour,
                    controller.practiceNotifMinute,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Seslendirme Ayarları
        _SettingsSection(
          title: 'Seslendirme (İngilizce)',
          children: [
            SwitchListTile(
              title: const Text(
                'Pratikte Otomatik Seslendir',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Sonraki kelimeye geçince otomatik oku'),
              value: controller.practiceAutoSpeak,
              onChanged: controller.setPracticeAutoSpeak,
            ),
            SwitchListTile(
              title: const Text(
                'Pratikte Örnek Cümleyi de Oku',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Otomatik seslendirmede kelimeden sonra cümleyi okur',
              ),
              value: controller.practiceSpeakSentence,
              onChanged: controller.practiceAutoSpeak
                  ? controller.setPracticeSpeakSentence
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Okuma Hızı',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            controller.tts.speakWord('resilient'),
                        icon: const Icon(Icons.volume_up_rounded, size: 18),
                        label: const Text('Test Et'),
                      ),
                    ],
                  ),
                  Slider(
                    value: controller.ttsSpeechRate,
                    min: 0.25,
                    max: 0.75,
                    divisions: 10,
                    label: controller.ttsSpeechRate.toStringAsFixed(2),
                    onChanged: controller.setTtsSpeechRate,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // İstatistik Özeti
        _SettingsSection(
          title: 'Durum Özeti',
          children: [
            ListTile(
              leading: const Icon(Icons.library_books_outlined),
              title: const Text('Toplam Kaynak Kelime'),
              trailing: Text(
                '${controller.totalWordCount}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('Ezberlenen Kelime'),
              trailing: Text(
                '${controller.memorizedCount}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}
