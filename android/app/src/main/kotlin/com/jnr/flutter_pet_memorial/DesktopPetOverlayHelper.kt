package com.jnr.flutter_pet_memorial

import android.content.Context
import android.content.Intent
import flutter.overlay.window.flutter_overlay_window.OverlayService

/// 从最近任务划掉 App 时关闭桌面悬浮宠物并清除开关
object DesktopPetOverlayHelper {

    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val PREFS_KEY = "flutter.desktop_pet_enabled"

    fun registerOverlayTaskRemovedListener(application: android.app.Application) {
        OverlayService.setOnTaskRemovedListener {
            clearEnabledPreference(application)
        }
    }

    fun disableOnAppRemoved(context: Context) {
        clearEnabledPreference(context.applicationContext)
        closeOverlay(context.applicationContext)
    }

    fun clearEnabledPreference(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(PREFS_KEY, false)
            .apply()
    }

    private fun closeOverlay(context: Context) {
        try {
            val intent = Intent(context, OverlayService::class.java).apply {
                putExtra(OverlayService.INTENT_EXTRA_IS_CLOSE_WINDOW, true)
            }
            context.startService(intent)
        } catch (_: Exception) {
            try {
                context.stopService(Intent(context, OverlayService::class.java))
            } catch (_: Exception) {
            }
        }
    }
}
