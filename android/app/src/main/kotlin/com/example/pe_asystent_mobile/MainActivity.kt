package com.example.pe_asystent_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onPause() {
        super.onPause()
        intent?.data = null
        intent?.removeExtra("es.antonborri.home_widget.uri")
    }
}
