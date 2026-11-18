import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Günlük yeni kelime ve pratik bildirimlerini yöneten yerel bildirim servisi.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const int dailyWordsNotificationId = 1001;
  static const int practiceNotificationId = 1002;

  static const String payloadDaily = 'daily';
  static const String payloadPractice = 'practice';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  void Function(String payload)? _onTap;

  Future<void> init({void Function(String payload)? onNotificationTap}) async {
    _onTap = onNotificationTap;
    if (_initialized) return;

    _initTimezone();

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('ic_stat_worm');
    const settings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _onTap?.call(payload);
          }
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Bildirim initialize hatası: $e');
    }
  }

  void _initTimezone() {
    tzdata.initializeTimeZones();
    final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    tz.Location? matched;

    // Türkiye (+03:00) ve diğer yaygın saat dilimleri için öncelikli kontrol
    const preferredZones = <String>[
      'Europe/Istanbul',
      'Europe/London',
      'Europe/Berlin',
      'America/New_York',
      'UTC',
    ];
    for (final name in preferredZones) {
      final loc = tz.getLocation(name);
      if (loc.currentTimeZone.offset == offsetMs) {
        matched = loc;
        break;
      }
    }

    if (matched == null) {
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offsetMs) {
          matched = loc;
          break;
        }
      }
    }

    tz.setLocalLocation(matched ?? tz.UTC);
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;

    final notifGranted = await androidPlugin.requestNotificationsPermission();
    return notifGranted ?? true;
  }

  Future<void> scheduleDailyWordsReminder({
    required bool enabled,
    required int hour,
    required int minute,
    required int dailyWordCount,
  }) async {
    await _cancel(dailyWordsNotificationId);
    if (!enabled) return;

    await _scheduleDaily(
      id: dailyWordsNotificationId,
      hour: hour,
      minute: minute,
      title: 'Yeni ezberlenecek kelimeler var!',
      body: 'Bugünkü $dailyWordCount İngilizce kelimen seni bekliyor.',
      channelId: 'worm_daily_words',
      channelName: 'Günlük Kelimeler',
      channelDescription: 'Her gün yeni ezberlenecek kelimeler için hatırlatma',
      payload: payloadDaily,
    );
  }

  Future<void> schedulePracticeReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _cancel(practiceNotificationId);
    if (!enabled) return;

    await _scheduleDaily(
      id: practiceNotificationId,
      hour: hour,
      minute: minute,
      title: 'Pratik zamanı!',
      body: 'Ezberlediğin 10 rastgele kelimeyle hızlı tekrar yap.',
      channelId: 'worm_daily_practice',
      channelName: 'Günlük Pratik',
      channelDescription: 'Her gün ezberlenen kelimeleri tekrar etmek için hatırlatma',
      payload: payloadPractice,
    );
  }

  Future<void> _cancel(int id) async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('Bildirim iptal hatası ($id): $e');
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String payload,
  }) async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_worm',
        color: const Color(0xFF6366F1),
      ),
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
    } catch (e) {
      // Exact alarm izni verilmemişse inexact moda düşerek bildirimin yine de çalışmasını sağla.
      debugPrint('Exact bildirim hatası, inexact moda geçiliyor: $e');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } catch (innerError) {
        debugPrint('Bildirim planlama hatası ($id): $innerError');
      }
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
