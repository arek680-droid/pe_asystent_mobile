package com.example.pe_asystent_mobile

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
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
        Log.d("TodoWidgetProvider", "onUpdate started for ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.todo_widget)

            val count = widgetData.getInt("todo_count", 0)
            Log.d("TodoWidgetProvider", "onUpdate count: $count")

            if (count == 0) {
                views.setViewVisibility(R.id.todo_empty_view, View.VISIBLE)
                views.setViewVisibility(R.id.todo_list_view, View.GONE)
            } else {
                views.setViewVisibility(R.id.todo_empty_view, View.GONE)
                views.setViewVisibility(R.id.todo_list_view, View.VISIBLE)

                // Set up RemoteViewsAdapter for ListView
                val serviceIntent = Intent(context, TodoWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                views.setRemoteAdapter(R.id.todo_list_view, serviceIntent)
                views.setEmptyView(R.id.todo_list_view, R.id.todo_empty_view)

                // Set pending intent template for item click
                val itemClickIntent = Intent(context, MainActivity::class.java)
                val itemPendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    itemClickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.todo_list_view, itemPendingIntent)
            }

            // Click pending intent for the entire widget header to launch MainActivity
            val activityIntent = Intent(context, MainActivity::class.java).apply {
                data = Uri.parse("homewidget://todo?action=open")
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                activityIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)

            // Click pending intent for "+ Dodaj" button to launch MainActivity
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

            // Notify ListView to refresh data
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.todo_list_view)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
