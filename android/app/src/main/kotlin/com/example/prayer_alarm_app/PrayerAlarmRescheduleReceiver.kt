package com.example.prayer_alarm_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class PrayerAlarmRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NativePrayerAlarmScheduler.rescheduleStoredAlarms(context)
    }
}
