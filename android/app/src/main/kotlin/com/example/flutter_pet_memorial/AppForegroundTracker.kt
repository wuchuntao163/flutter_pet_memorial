package com.example.flutter_pet_memorial

import android.app.Activity
import android.app.Application
import android.os.Bundle
import flutter.overlay.window.flutter_overlay_window.OverlayService

/// 跟踪主 Activity 是否在前台
object AppForegroundTracker {

    @Volatile
    var isMainActivityInForeground: Boolean = false
        private set

    fun register(application: Application) {
        application.registerActivityLifecycleCallbacks(object :
            Application.ActivityLifecycleCallbacks {
            override fun onActivityResumed(activity: Activity) {
                if (activity is MainActivity) {
                    isMainActivityInForeground = true
                    OverlayService.setMainAppInForeground(true)
                }
            }

            override fun onActivityPaused(activity: Activity) {
                if (activity is MainActivity) {
                    isMainActivityInForeground = false
                    OverlayService.setMainAppInForeground(false)
                }
            }

            override fun onActivityCreated(a: Activity, b: Bundle?) {}
            override fun onActivityStarted(a: Activity) {}
            override fun onActivityStopped(a: Activity) {}
            override fun onActivitySaveInstanceState(a: Activity, b: Bundle) {}
            override fun onActivityDestroyed(a: Activity) {}
        })
    }
}
