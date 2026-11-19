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
  static const int testNotificationId = 1099;

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

      // Uygulama kapalıyken bildirime tıklanarak açıldıysa ilgili sekmeye yönlendir.
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      final launchPayload = launchDetails?.notificationResponse?.payload;
      if ((launchDetails?.didNotificationLaunchApp ?? false) &&
          launchPayload != null &&
          launchPayload.isNotEmpty) {
        _onTap?.call(launchPayload);
      }
    } catch (e) {
      debugPrint('Bildirim initialize hatası: $e');
    }
  }

  void _initTimezone() {
    tzdata.initializeTimeZones();
    final offsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    tz.Location? matched;

    const preferredZones = <String>[
      'Europe/Istanbul',
      'Europe/London',
      'Europe/Berlin',
      'America/New_York',
      'UTC',
    ];
    for (final name in preferredZones) {
      final loc = tz.getLocation(name);
      final liveOffsetMs = tz.TZDateTime.now(loc).timeZoneOffset.inMilliseconds;
      if (liveOffsetMs == offsetMs) {
        matched = loc;
        break;
      }
    }

    if (matched == null) {
      for (final loc in tz.timeZoneDatabase.locations.values) {
        final liveOffsetMs =
            tz.TZDateTime.now(loc).timeZoneOffset.inMilliseconds;
        if (liveOffsetMs == offsetMs) {
          matched = loc;
          break;
        }
      }
    }

    tz.setLocalLocation(matched ?? tz.UTC);
  }

  Future<bool> requestPermissions({bool requestExactAlarm = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;

    var notifGranted = true;
    try {
      notifGranted =
          (await androidPlugin.requestNotificationsPermission()) ?? true;
    } catch (e) {
      debugPrint('Bildirim izni isteme hatası: $e');
    }

    if (requestExactAlarm) {
      try {
        final canExact =
            (await androidPlugin.canScheduleExactNotifications()) ?? false;
        if (!canExact) {
          await androidPlugin.requestExactAlarmsPermission();
        }
      } catch (e) {
        debugPrint('Exact alarm izni isteme hatası: $e');
      }
    }

    return notifGranted;
  }

  /// Kurulan bir sonraki bildirim zamanını döndürür (devre dışıysa `null`).
  Future<DateTime?> scheduleDailyWordsReminder({
    required bool enabled,
    required int hour,
    required int minute,
    required int dailyWordCount,
  }) async {
    await _cancel(dailyWordsNotificationId);
    if (!enabled) return null;

    return _scheduleDaily(
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

  /// Kurulan bir sonraki bildirim zamanını döndürür (devre dışıysa `null`).
  Future<DateTime?> schedulePracticeReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    await _cancel(practiceNotificationId);
    if (!enabled) return null;

    return _scheduleDaily(
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

  /// Bildirimlerin cihazda anında çalıştığını doğrulamak için test bildirimi gönderir.
  Future<void> sendTestNotification() async {
    if (!_initialized || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await requestPermissions(requestExactAlarm: true);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'worm_daily_words',
        'Günlük Kelimeler',
        channelDescription: 'Her gün yeni ezberlenecek kelimeler için hatırlatma',
        importance: Importance.max,
        priority: Priority.max,
        icon: 'ic_stat_worm',
        color: Color(0xFF6366F1),
      ),
    );

    try {
      await _plugin.show(
        testNotificationId,
        'Worm Bildirim Testi',
        'Harika! Zamanlanmış bildirimler bu cihazda sorunsuz çalışıyor.',
        details,
        payload: payloadDaily,
      );
    } catch (e) {
      debugPrint('Test bildirimi hatası: $e');
    }
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

  Future<DateTime?> _scheduleDaily({
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
      return null;
    }

    final scheduledDate = _nextInstanceOfTime(hour, minute);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
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
      return scheduledDate;
    } catch (e) {
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
        return scheduledDate;
      } catch (innerError) {
        debugPrint('Bildirim planlama hatası ($id): $innerError');
        return null;
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
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
