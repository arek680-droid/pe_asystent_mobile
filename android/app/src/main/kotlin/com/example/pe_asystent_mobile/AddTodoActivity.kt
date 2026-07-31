package com.example.pe_asystent_mobile

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * Invisible helper activity that:
 * 1. Sets a "pending_add_todo" flag in SharedPreferences
 * 2. Launches the main Flutter app (MainActivity)
 * 3. Finishes itself immediately (no UI)
 *
 * This avoids all URI-scheme / intent-filter complexity
 * that was causing the app to crash-loop.
 */
class AddTodoActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set the flag
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        prefs.edit().putString("pending_add_todo", "true").apply()

        // Launch main app
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(launchIntent)

        // Close this invisible activity immediately
        finish()
    }
}
