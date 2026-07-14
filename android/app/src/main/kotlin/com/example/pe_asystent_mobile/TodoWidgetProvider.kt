package com.example.pe_asystent_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TodoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.todo_widget)

            // Get ToDo data saved from Flutter
            val count = widgetData.getInt("todo_count", 0)
            val todo1 = widgetData.getString("todo_1", null)
            val todo2 = widgetData.getString("todo_2", null)
            val todo3 = widgetData.getString("todo_3", null)
            val todo4 = widgetData.getString("todo_4", null)

            // Setup row data and visibility
            if (count == 0) {
                views.setViewVisibility(R.id.todo_empty_view, View.VISIBLE)
                views.setViewVisibility(R.id.todo_row_1, View.GONE)
                views.setViewVisibility(R.id.todo_row_2, View.GONE)
                views.setViewVisibility(R.id.todo_row_3, View.GONE)
                views.setViewVisibility(R.id.todo_row_4, View.GONE)
            } else {
                views.setViewVisibility(R.id.todo_empty_view, View.GONE)
                
                // Row 1
                if (todo1 != null) {
                    views.setViewVisibility(R.id.todo_row_1, View.VISIBLE)
                    views.setTextViewText(R.id.todo_text_1, todo1)
                } else {
                    views.setViewVisibility(R.id.todo_row_1, View.GONE)
                }

                // Row 2
                if (todo2 != null) {
                    views.setViewVisibility(R.id.todo_row_2, View.VISIBLE)
                    views.setTextViewText(R.id.todo_text_2, todo2)
                } else {
                    views.setViewVisibility(R.id.todo_row_2, View.GONE)
                }

                // Row 3
                if (todo3 != null) {
                    views.setViewVisibility(R.id.todo_row_3, View.VISIBLE)
                    views.setTextViewText(R.id.todo_text_3, todo3)
                } else {
                    views.setViewVisibility(R.id.todo_row_3, View.GONE)
                }

                // Row 4
                if (todo4 != null) {
                    views.setViewVisibility(R.id.todo_row_4, View.VISIBLE)
                    views.setTextViewText(R.id.todo_text_4, todo4)
                } else {
                    views.setViewVisibility(R.id.todo_row_4, View.GONE)
                }
            }

            // Click pending intent for the entire widget to launch MainActivity
            val activityIntent = Intent(context, MainActivity::class.java).apply {
                data = Uri.parse("homewidget://todo?action=open")
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                activityIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            // Click pending intent for the "+ Dodaj" button to launch MainActivity
            val addIntent = Intent(context, MainActivity::class.java).apply {
                data = Uri.parse("homewidget://todo?action=add")
            }
            val pendingAddIntent = PendingIntent.getActivity(
                context, 
                1, 
                addIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_add_button, pendingAddIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
