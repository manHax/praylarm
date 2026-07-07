package com.example.prayer_alarm_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

data class PrayerAlarmSpec(
    val id: Int,
    val prayerName: String,
    val arabicName: String,
    val scheduledTimeMillis: Long,
    val timeLabel: String,
)

object NativePrayerAlarmScheduler {
    private const val PREFS_NAME = "native_prayer_alarms"
    private const val KEY_ALARMS = "scheduled_alarms"

    fun schedulePrayerAlarms(context: Context, alarms: List<PrayerAlarmSpec>): Int {
        cancelAllPrayerAlarms(context)
        val futureAlarms = alarms.filter { it.scheduledTimeMillis > System.currentTimeMillis() }
        futureAlarms.forEach { alarm ->
            scheduleSingleAlarm(
                context = context,
                alarm = alarm,
                showIntentRequestCode = 700000 + alarm.id,
            )
        }

        persist(context, futureAlarms)
        return futureAlarms.size
    }

    fun scheduleSelfTestAlarm(context: Context): Long {
        val triggerAt = System.currentTimeMillis() + 60_000L
        val spec = PrayerAlarmSpec(
            id = 910000,
            prayerName = "Tes Alarm Native",
            arabicName = "اختبار المنبه",
            scheduledTimeMillis = triggerAt,
            timeLabel = "1 menit lagi",
        )
        scheduleSingleAlarm(
            context = context,
            alarm = spec,
            showIntentRequestCode = 700010,
        )
        return triggerAt
    }

    fun rescheduleStoredAlarms(context: Context) {
        val alarms = readPersisted(context)
        if (alarms.isEmpty()) return
        schedulePrayerAlarms(context, alarms)
    }

    fun scheduleSnooze(
        context: Context,
        prayerName: String,
        arabicName: String,
        requestId: Int,
        triggerAtMillis: Long,
    ) {
        scheduleSingleAlarm(
            context = context,
            alarm = PrayerAlarmSpec(
                id = requestId,
                prayerName = prayerName,
                arabicName = arabicName,
                scheduledTimeMillis = triggerAtMillis,
                timeLabel = "Snooze",
            ),
            showIntentRequestCode = 700001,
        )
    }

    fun cancelAllPrayerAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        readPersisted(context).forEach { alarm ->
            val operation = PendingIntent.getBroadcast(
                context,
                alarm.id,
                triggerIntent(context, alarm),
                pendingIntentFlags(mutable = true, updateCurrent = true),
            )
            alarmManager.cancel(operation)
            operation.cancel()
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().remove(KEY_ALARMS).apply()
        context.stopService(Intent(context, PrayerAlarmRingService::class.java))
    }

    private fun triggerIntent(context: Context, alarm: PrayerAlarmSpec): Intent {
        return Intent(context, PrayerAlarmClockReceiver::class.java).apply {
            putExtra("alarmId", alarm.id)
            putExtra("prayerName", alarm.prayerName)
            putExtra("arabicName", alarm.arabicName)
            putExtra("scheduledTimeMillis", alarm.scheduledTimeMillis)
            putExtra("timeLabel", alarm.timeLabel)
        }
    }

    fun removeTriggeredAlarm(context: Context, alarmId: Int) {
        val remaining = readPersisted(context).filterNot { it.id == alarmId }
        persist(context, remaining)
    }

    private fun persist(context: Context, alarms: List<PrayerAlarmSpec>) {
        val array = JSONArray()
        alarms.forEach { alarm ->
            array.put(
                JSONObject().apply {
                    put("id", alarm.id)
                    put("prayerName", alarm.prayerName)
                    put("arabicName", alarm.arabicName)
                    put("scheduledTimeMillis", alarm.scheduledTimeMillis)
                    put("timeLabel", alarm.timeLabel)
                },
            )
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putString(KEY_ALARMS, array.toString()).apply()
    }

    private fun readPersisted(context: Context): List<PrayerAlarmSpec> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_ALARMS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.getJSONObject(index)
                    add(
                        PrayerAlarmSpec(
                            id = item.getInt("id"),
                            prayerName = item.getString("prayerName"),
                            arabicName = item.getString("arabicName"),
                            scheduledTimeMillis = item.getLong("scheduledTimeMillis"),
                            timeLabel = item.getString("timeLabel"),
                        ),
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun pendingIntentFlags(mutable: Boolean, updateCurrent: Boolean): Int {
        var flags = if (updateCurrent) PendingIntent.FLAG_UPDATE_CURRENT else 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or if (mutable) PendingIntent.FLAG_MUTABLE else PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }

    private fun scheduleSingleAlarm(
        context: Context,
        alarm: PrayerAlarmSpec,
        showIntentRequestCode: Int,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val launchIntent = Intent(context, MainActivity::class.java)
        val showIntent = PendingIntent.getActivity(
            context,
            showIntentRequestCode,
            launchIntent,
            pendingIntentFlags(mutable = false, updateCurrent = true),
        )
        val operation = PendingIntent.getBroadcast(
            context,
            alarm.id,
            triggerIntent(context, alarm),
            pendingIntentFlags(mutable = true, updateCurrent = true),
        )
        val info = AlarmManager.AlarmClockInfo(alarm.scheduledTimeMillis, showIntent)
        alarmManager.setAlarmClock(info, operation)
    }
}
