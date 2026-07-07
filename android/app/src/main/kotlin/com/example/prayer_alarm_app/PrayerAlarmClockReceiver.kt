package com.example.prayer_alarm_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class PrayerAlarmClockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra("alarmId", -1)
        if (alarmId != -1) {
            NativePrayerAlarmScheduler.removeTriggeredAlarm(context, alarmId)
        }
        val serviceIntent = Intent(context, PrayerAlarmRingService::class.java).apply {
            action = PrayerAlarmRingService.ACTION_TRIGGER
            putExtras(intent.extras ?: return)
        }
        ContextCompat.startForegroundService(context, serviceIntent)
    }
}
