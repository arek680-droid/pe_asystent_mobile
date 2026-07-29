package com.example.pe_asystent_mobile

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class TodoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TodoRemoteViewsFactory(this.applicationContext, intent)
    }
}

class TodoRemoteViewsFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private var todoList = mutableListOf<String>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        todoList.clear()
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("todo_json", null)
        Log.d("TodoWidgetService", "onDataSetChanged read json: $jsonStr")
        if (!jsonStr.isNullOrEmpty()) {
            try {
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    todoList.add(array.getString(i))
                }
            } catch (e: Exception) {
                Log.e("TodoWidgetService", "Error parsing JSON", e)
            }
        }
    }

    override fun onDestroy() {
        todoList.clear()
    }

    override fun getCount(): Int = todoList.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.todo_widget_item)
        if (position in 0 until todoList.size) {
            views.setTextViewText(R.id.todo_item_text, todoList[position])

            // Fill-in intent to open MainActivity when clicking an item
            val fillInIntent = Intent().apply {
                data = Uri.parse("homewidget://todo?action=open")
            }
            views.setOnClickFillInIntent(R.id.todo_item_container, fillInIntent)
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
