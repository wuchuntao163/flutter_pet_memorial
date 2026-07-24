package com.jnr.flutter_pet_memorial

import android.app.Application
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant

/// 为桌面悬浮窗引擎注册插件与 AppLauncher（overlay 引擎不会自动注册 GeneratedPluginRegistrant）
class PetMemorialApplication : Application() {
    private val handler = Handler(Looper.getMainLooper())
    private var pluginsRegistered = false

    override fun onCreate() {
        super.onCreate()
        AppForegroundTracker.register(this)
        DesktopPetOverlayHelper.registerOverlayTaskRemovedListener(this)
        scheduleOverlayEngineSetup()
    }

    private fun scheduleOverlayEngineSetup() {
        var attempts = 0
        val task = object : Runnable {
            override fun run() {
                if (prepareOverlayEngineIfNeeded()) return
                attempts++
                if (attempts < 120) {
                    handler.postDelayed(this, 250)
                }
            }
        }
        handler.post(task)
    }

    private fun prepareOverlayEngineIfNeeded(): Boolean {
        val engine = FlutterEngineCache.getInstance().get(OVERLAY_ENGINE_ID) ?: return false
        if (!pluginsRegistered) {
            GeneratedPluginRegistrant.registerWith(engine)
            pluginsRegistered = true
        }
        AppLauncher.register(engine.dartExecutor.binaryMessenger, applicationContext)
        return true
    }

    companion object {
        const val OVERLAY_ENGINE_ID = "myCachedEngine"
    }
}
