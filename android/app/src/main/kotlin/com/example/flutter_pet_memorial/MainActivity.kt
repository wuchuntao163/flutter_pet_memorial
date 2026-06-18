package com.example.flutter_pet_memorial

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.flutter_pet_memorial/share"
    private val navChannelName = "com.example.flutter_pet_memorial/navigation"

    private var pendingRoute: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        applyTransparentSystemBars()
        captureLaunchRoute(intent)
    }

    private fun applyTransparentSystemBars() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.navigationBarColor = Color.TRANSPARENT
            window.statusBarColor = Color.TRANSPARENT
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchRoute(intent)
        deliverPendingRoute()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppLauncher.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, navChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPendingRoute" -> {
                        result.success(pendingRoute)
                        pendingRoute = null
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAppInstalled" -> {
                        val packageName = call.argument<String>("package")
                        if (packageName.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(isPackageInstalled(packageName))
                        }
                    }

                    "shareImageToPackage" -> {
                        val path = call.argument<String>("path")
                        val packageName = call.argument<String>("package")
                        if (path.isNullOrBlank() || packageName.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(
                                shareImage(path, packageName, timeline = false),
                            )
                        }
                    }

                    "shareImageToWeChatTimeline" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(
                                shareImage(
                                    path,
                                    "com.tencent.mm",
                                    timeline = true,
                                ),
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        scheduleOverlayLauncherRegistration()
        deliverPendingRoute()
    }

    private fun captureLaunchRoute(intent: Intent?) {
        val route = intent?.getStringExtra(EXTRA_OPEN_ROUTE)
        if (!route.isNullOrBlank()) {
            pendingRoute = route
        }
    }

    private fun deliverPendingRoute() {
        val route = pendingRoute ?: return
        val engine = flutterEngine ?: return
        MethodChannel(engine.dartExecutor.binaryMessenger, navChannelName)
            .invokeMethod("navigate", route)
        pendingRoute = null
        intent?.removeExtra(EXTRA_OPEN_ROUTE)
    }

    private fun scheduleOverlayLauncherRegistration() {
        val handler = Handler(Looper.getMainLooper())
        for (delay in longArrayOf(0, 500, 1500, 3000)) {
            handler.postDelayed({ registerOverlayEngineLauncher() }, delay)
        }
    }

    private fun registerOverlayEngineLauncher() {
        FlutterEngineCache.getInstance().get(PetMemorialApplication.OVERLAY_ENGINE_ID)?.let { engine ->
            AppLauncher.register(engine.dartExecutor.binaryMessenger, applicationContext)
        }
    }

    override fun onResume() {
        super.onResume()
        flutterEngine?.lifecycleChannel?.appIsResumed()
        window?.decorView?.requestFocus()
        registerOverlayEngineLauncher()
        deliverPendingRoute()
    }

    override fun onPause() {
        flutterEngine?.lifecycleChannel?.appIsPaused()
        super.onPause()
    }

    override fun onDestroy() {
        if (isFinishing && !isChangingConfigurations) {
            DesktopPetOverlayHelper.disableOnAppRemoved(this)
        }
        super.onDestroy()
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun shareImage(
        path: String,
        packageName: String,
        timeline: Boolean,
    ): Boolean {
        if (!isPackageInstalled(packageName)) return false

        val file = File(path)
        if (!file.exists()) return false

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            file,
        )

        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/*"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (timeline && packageName == "com.tencent.mm") {
                component = android.content.ComponentName(
                    packageName,
                    "com.tencent.mm.ui.tools.ShareToTimeLineUI",
                )
            } else {
                setPackage(packageName)
            }
        }

        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            if (!timeline) return false
            return try {
                val fallback = Intent(Intent.ACTION_SEND).apply {
                    type = "image/*"
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    setPackage(packageName)
                }
                startActivity(fallback)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    companion object {
        const val EXTRA_OPEN_ROUTE = "open_route"
    }
}
