package com.example.prayer_alarm_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerTimesWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.prayer_times_widget).apply {
                setTextViewText(R.id.fajr_time, widgetData.getString("fajr", "--:--"))
                setTextViewText(R.id.dhuhr_time, widgetData.getString("dhuhr", "--:--"))
                setTextViewText(R.id.asr_time, widgetData.getString("asr", "--:--"))
                setTextViewText(R.id.maghrib_time, widgetData.getString("maghrib", "--:--"))
                setTextViewText(R.id.isha_time, widgetData.getString("isha", "--:--"))
                setTextViewText(R.id.widget_date, widgetData.getString("date", ""))
                setTextViewText(
                    R.id.next_prayer_label,
                    "Berikutnya: ${widgetData.getString("next_prayer", "")}"
                )
                setTextViewText(
                    R.id.next_prayer_countdown,
                    widgetData.getString("countdown", "")
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}