package com.example.prayer_alarm_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    companion object {
        private const val REQUEST_CODE_PICK_ALARM_SOUND = 4107
    }

    private var pendingAlarmSoundResult: Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "prayer_alarm_app/timezone",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getLocalTimezone") {
                result.success(TimeZone.getDefault().id)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "prayer_alarm_app/native_alarm",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedulePrayerAlarms" -> {
                    val rawAlarms = call.argument<List<Map<String, Any?>>>("alarms").orEmpty()
                    val alarms = rawAlarms.mapNotNull { raw ->
                        val id = (raw["id"] as? Number)?.toInt() ?: return@mapNotNull null
                        val prayerName = raw["prayerName"] as? String ?: return@mapNotNull null
                        val arabicName = raw["arabicName"] as? String ?: prayerName
                        val scheduledTimeMillis =
                            (raw["scheduledTimeMillis"] as? Number)?.toLong() ?: return@mapNotNull null
                        val timeLabel = raw["timeLabel"] as? String ?: ""
                        PrayerAlarmSpec(
                            id = id,
                            prayerName = prayerName,
                            arabicName = arabicName,
                            scheduledTimeMillis = scheduledTimeMillis,
                            timeLabel = timeLabel,
                        )
                    }
                    val count = NativePrayerAlarmScheduler.schedulePrayerAlarms(applicationContext, alarms)
                    result.success(count)
                }

                "cancelAllPrayerAlarms" -> {
                    NativePrayerAlarmScheduler.cancelAllPrayerAlarms(applicationContext)
                    result.success(null)
                }

                "scheduleSelfTestAlarm" -> {
                    val triggerAt = NativePrayerAlarmScheduler.scheduleSelfTestAlarm(applicationContext)
                    result.success(triggerAt)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "prayer_alarm_app/alarm_sound",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAlarmSound" -> {
                    if (pendingAlarmSoundResult != null) {
                        result.error(
                            "picker_active",
                            "Pemilih file audio masih terbuka",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    pendingAlarmSoundResult = result
                    val intent =
                        Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/*"
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }
                    startActivityForResult(intent, REQUEST_CODE_PICK_ALARM_SOUND)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != REQUEST_CODE_PICK_ALARM_SOUND) {
            return
        }

        val result = pendingAlarmSoundResult
        pendingAlarmSoundResult = null

        if (result == null) {
            return
        }

        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        runCatching {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }

        result.success(
            mapOf(
                "uri" to uri.toString(),
                "label" to resolveDisplayName(uri),
            ),
        )
    }

    private fun resolveDisplayName(uri: Uri): String {
        val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
        contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (nameIndex >= 0 && cursor.moveToFirst()) {
                val value = cursor.getString(nameIndex)
                if (!value.isNullOrBlank()) {
                    return value
                }
            }
        }
        return uri.lastPathSegment ?: uri.toString()
    }
}
