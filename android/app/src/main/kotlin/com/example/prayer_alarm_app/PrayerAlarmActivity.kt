package com.example.prayer_alarm_app

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView

class PrayerAlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }

        setContentView(R.layout.activity_prayer_alarm)

        val prayerName = intent.getStringExtra("prayerName") ?: "Waktu Sholat"
        val arabicName = intent.getStringExtra("arabicName") ?: prayerName
        val timeLabel = intent.getStringExtra("timeLabel") ?: ""
        val alarmId = intent.getIntExtra("alarmId", 910001)

        findViewById<TextView>(R.id.alarmPrayerName).text = prayerName
        findViewById<TextView>(R.id.alarmArabicName).text = arabicName
        findViewById<TextView>(R.id.alarmTime).text = timeLabel

        findViewById<Button>(R.id.stopButton).setOnClickListener {
            startService(
                Intent(this, PrayerAlarmRingService::class.java).apply {
                    action = PrayerAlarmRingService.ACTION_STOP
                },
            )
            finishAndRemoveTask()
        }

        findViewById<Button>(R.id.snoozeButton).setOnClickListener {
            startService(
                Intent(this, PrayerAlarmRingService::class.java).apply {
                    action = PrayerAlarmRingService.ACTION_SNOOZE
                    putExtra("alarmId", alarmId)
                    putExtra("prayerName", prayerName)
                    putExtra("arabicName", arabicName)
                },
            )
            finishAndRemoveTask()
        }
    }
}
