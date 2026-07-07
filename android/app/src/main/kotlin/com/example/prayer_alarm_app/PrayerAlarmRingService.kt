package com.example.prayer_alarm_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class PrayerAlarmRingService : Service() {
    companion object {
        const val ACTION_TRIGGER = "com.example.prayer_alarm_app.ACTION_TRIGGER"
        const val ACTION_STOP = "com.example.prayer_alarm_app.ACTION_STOP"
        const val ACTION_SNOOZE = "com.example.prayer_alarm_app.ACTION_SNOOZE"

        private const val CHANNEL_ID = "native_prayer_alarm_firing"
        private const val NOTIFICATION_ID = 920001
    }

    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopAlarm()
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_SNOOZE -> {
                val alarmId = intent.getIntExtra("alarmId", 910001)
                val prayerName = intent.getStringExtra("prayerName") ?: "Alarm"
                val arabicName = intent.getStringExtra("arabicName") ?: prayerName
                NativePrayerAlarmScheduler.scheduleSnooze(
                    context = this,
                    prayerName = prayerName,
                    arabicName = arabicName,
                    requestId = alarmId,
                    triggerAtMillis = System.currentTimeMillis() + 10 * 60 * 1000L,
                )
                stopAlarm()
                stopSelf()
                return START_NOT_STICKY
            }

            else -> {
                val triggerIntent = intent ?: Intent()
                val notification = buildNotification(triggerIntent)
                startForeground(NOTIFICATION_ID, notification)
                startAlarm()
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }

    private fun buildNotification(intent: Intent): Notification {
        createChannel()

        val prayerName = intent.getStringExtra("prayerName") ?: "Waktu Sholat"
        val arabicName = intent.getStringExtra("arabicName") ?: prayerName
        val timeLabel = intent.getStringExtra("timeLabel") ?: ""
        val alarmId = intent.getIntExtra("alarmId", 910001)

        val activityIntent = Intent(this, PrayerAlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            intent.extras?.let { putExtras(it) }
        }
        val fullScreenIntent = PendingIntent.getActivity(
            this,
            alarmId,
            activityIntent,
            pendingIntentFlags(mutable = false),
        )

        val stopIntent = PendingIntent.getService(
            this,
            alarmId + 10000,
            Intent(this, PrayerAlarmRingService::class.java).apply {
                action = ACTION_STOP
            },
            pendingIntentFlags(mutable = false),
        )

        val snoozeIntent = PendingIntent.getService(
            this,
            alarmId + 20000,
            Intent(this, PrayerAlarmRingService::class.java).apply {
                action = ACTION_SNOOZE
                intent.extras?.let { putExtras(it) }
            },
            pendingIntentFlags(mutable = false),
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("🕌 $prayerName")
            .setContentText("Masuk pukul $timeLabel • $arabicName")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)
            .setOngoing(true)
            .setFullScreenIntent(fullScreenIntent, true)
            .setContentIntent(fullScreenIntent)
            .addAction(0, "Tunda 10 Menit", snoozeIntent)
            .addAction(0, "Matikan", stopIntent)
            .build()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Alarm Sholat Native",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Alarm utama gaya Android untuk waktu sholat"
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun startAlarm() {
        stopAlarm()

        if (isSoundEnabled()) {
            val customAlarmUri = resolveCustomAlarmUri()
            val defaultAlarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            val started = when {
                customAlarmUri != null -> playAlarm(customAlarmUri) || (defaultAlarmUri != null && playAlarm(defaultAlarmUri))
                defaultAlarmUri != null -> playAlarm(defaultAlarmUri)
                else -> false
            }

            if (!started) {
                mediaPlayer = null
            }
        }

        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                it.vibrate(
                    VibrationEffect.createWaveform(
                        longArrayOf(0, 700, 500, 700),
                        0,
                    ),
                )
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(longArrayOf(0, 700, 500, 700), 0)
            }
        }
    }

    private fun stopAlarm() {
        mediaPlayer?.runCatching {
            if (isPlaying) stop()
            reset()
            release()
        }
        mediaPlayer = null

        vibrator?.cancel()
        vibrator = null
    }

    private fun isSoundEnabled(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.sound_enabled", true)
    }

    private fun resolveCustomAlarmUri(): Uri? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val mode = prefs.getString("flutter.alarm_sound_mode", "default")
        val uriString = prefs.getString("flutter.alarm_sound_uri", null)
        if (mode != "custom" || uriString.isNullOrBlank()) {
            return null
        }
        return Uri.parse(uriString)
    }

    private fun playAlarm(uri: Uri): Boolean {
        return runCatching {
            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                setDataSource(applicationContext, uri)
                isLooping = true
                prepare()
                start()
            }
            true
        }.getOrElse {
            mediaPlayer?.runCatching {
                reset()
                release()
            }
            mediaPlayer = null
            false
        }
    }

    private fun pendingIntentFlags(mutable: Boolean): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
