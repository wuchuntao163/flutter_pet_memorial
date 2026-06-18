package com.example.flutter_pet_memorial

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object AppLauncher {
    private const val CHANNEL = "com.example.flutter_pet_memorial/launcher"
    private val registered = mutableSetOf<BinaryMessenger>()

    fun register(messenger: BinaryMessenger, context: Context) {
        registered.add(messenger)
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchMainApp" -> result.success(launchMainApp(context))
                else -> result.notImplemented()
            }
        }
    }

    private fun launchMainApp(context: Context): Boolean {
        return try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                )
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            val fallback = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: return false
            fallback.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
            )
            context.startActivity(fallback)
            true
        }
    }
}
