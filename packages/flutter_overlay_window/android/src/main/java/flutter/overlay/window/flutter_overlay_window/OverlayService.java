package flutter.overlay.window.flutter_overlay_window;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.app.PendingIntent;
import android.graphics.Point;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.provider.Settings;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Display;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import io.flutter.embedding.android.FlutterTextureView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterEngineGroup;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.JSONMessageCodec;
import io.flutter.plugin.common.MethodChannel;

public class OverlayService extends Service implements View.OnTouchListener {
    private final int DEFAULT_NAV_BAR_HEIGHT_DP = 48;
    private final int DEFAULT_STATUS_BAR_HEIGHT_DP = 25;

    private Integer mStatusBarHeight = -1;
    private Integer mNavigationBarHeight = -1;
    private Resources mResources;

    public static final String INTENT_EXTRA_IS_CLOSE_WINDOW = "IsCloseWindow";

    private static OverlayService instance;
    public static boolean isRunning = false;
    private static volatile boolean mainAppInForeground = false;
    private static Runnable onTaskRemovedListener;
    private WindowManager windowManager = null;
    private FlutterView flutterView;
    private MethodChannel flutterChannel;
    private BasicMessageChannel<Object> overlayMessageChannel;
    private int clickableFlag = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;

    private Handler mAnimationHandler = new Handler();
    private float lastX, lastY;
    private int lastYPosition;
    private boolean dragging;
    private static final float MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER = 0.8f;
    private Point szWindow = new Point();
    private Timer mTrayAnimationTimer;
    private TrayAnimationTimerTask mTrayTimerTask;

    private final Handler walkHandler = new Handler(Looper.getMainLooper());
    private boolean autoWalkEnabled = false;
    private boolean walkPaused = false;
    private boolean walkingLeft = true;
    private boolean walkSummonDelay = false;
    private long walkSummonDelayUntil = 0;
    private float walkSpeedDpPerSec = 22f;
    private float petWidthDp = 250f;
    private long lastWalkFrameAt = 0;
    private static final long WALK_FRAME_MS = 33;

    private final Runnable resumeWalkRunnable = new Runnable() {
        @Override
        public void run() {
            if (flutterView == null) return;
            WindowManager.LayoutParams params =
                    (WindowManager.LayoutParams) flutterView.getLayoutParams();
            syncWalkDirectionFromPosition(params.x);
            resumeAutoWalk();
        }
    };

    /** 主 App 在最近任务中被划掉时回调（由宿主 Application 注册） */
    public static void setOnTaskRemovedListener(Runnable listener) {
        onTaskRemovedListener = listener;
    }

    /** 记录主 App 是否在前台（用于点击悬浮窗时是否拉起 App） */
    public static void setMainAppInForeground(boolean inForeground) {
        mainAppInForeground = inForeground;
    }

    private static void syncOverlayEngineLifecycleOnStart() {
        FlutterEngine engine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);
        if (engine == null) return;
        engine.getLifecycleChannel().appIsResumed();
    }

    private void refreshScreenSize() {
        if (windowManager == null) return;
        DisplayMetrics dm = new DisplayMetrics();
        windowManager.getDefaultDisplay().getRealMetrics(dm);
        szWindow.set(dm.widthPixels, dm.heightPixels);
    }

    private int getPetWidthPx() {
        if (flutterView != null && flutterView.getWidth() > 0) {
            return flutterView.getWidth();
        }
        return dpToPx(Math.round(petWidthDp));
    }

    private int getMaxWalkXPx() {
        return Math.max(0, szWindow.x - getPetWidthPx());
    }

    private void syncWalkDirectionFromPosition(int xPx) {
        int maxX = getMaxWalkXPx();
        if (maxX <= 0) {
            walkingLeft = false;
            return;
        }
        if (xPx <= 0) {
            walkingLeft = false;
        } else if (xPx >= maxX) {
            walkingLeft = true;
        } else if (xPx < maxX / 4) {
            walkingLeft = false;
        } else if (xPx > maxX * 3 / 4) {
            walkingLeft = true;
        }
        notifyWalkDirection(walkingLeft);
    }

    private final Runnable walkRunnable = new Runnable() {
        @Override
        public void run() {
            if (!autoWalkEnabled || walkPaused || windowManager == null || flutterView == null) {
                if (autoWalkEnabled) {
                    walkHandler.postDelayed(this, WALK_FRAME_MS);
                }
                return;
            }
            if (walkSummonDelay) {
                if (System.currentTimeMillis() < walkSummonDelayUntil) {
                    walkHandler.postDelayed(this, WALK_FRAME_MS);
                    return;
                }
                walkSummonDelay = false;
            }

            WindowManager.LayoutParams params =
                    (WindowManager.LayoutParams) flutterView.getLayoutParams();
            long now = System.currentTimeMillis();
            if (lastWalkFrameAt == 0) {
                lastWalkFrameAt = now;
            }
            float dt = (now - lastWalkFrameAt) / 1000f;
            lastWalkFrameAt = now;

            int maxX = getMaxWalkXPx();
            float density = mResources.getDisplayMetrics().density;
            int stepPx = Math.max(1, Math.round(walkSpeedDpPerSec * density * dt));
            int newX = params.x + (walkingLeft ? -stepPx : stepPx);

            boolean newLeft = walkingLeft;
            if (newX <= 0) {
                newX = 0;
                newLeft = false;
            } else if (newX >= maxX) {
                newX = maxX;
                newLeft = true;
            }

            if (newLeft != walkingLeft) {
                walkingLeft = newLeft;
                notifyWalkDirection(walkingLeft);
            }

            if (newX != params.x) {
                params.x = newX;
                windowManager.updateViewLayout(flutterView, params);
            }
            walkHandler.postDelayed(this, WALK_FRAME_MS);
        }
    };

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void onDestroy() {
        Log.d("OverLay", "Destroying the overlay window service");
        if (windowManager != null) {
            windowManager.removeView(flutterView);
            windowManager = null;
            flutterView.detachFromFlutterEngine();
            flutterView = null;
        }
        isRunning = false;
        stopAutoWalk();
        NotificationManager notificationManager = (NotificationManager) getApplicationContext().getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancel(OverlayConstants.NOTIFICATION_ID);
        instance = null;
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        if (onTaskRemovedListener != null) {
            onTaskRemovedListener.run();
        }
        stopSelf();
        super.onTaskRemoved(rootIntent);
    }

    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        mResources = getApplicationContext().getResources();
        int startX = intent.getIntExtra("startX", OverlayConstants.DEFAULT_XY);
        int startY = intent.getIntExtra("startY", OverlayConstants.DEFAULT_XY);
        boolean isCloseWindow = intent.getBooleanExtra(INTENT_EXTRA_IS_CLOSE_WINDOW, false);
        if (isCloseWindow) {
            if (windowManager != null) {
                windowManager.removeView(flutterView);
                windowManager = null;
                flutterView.detachFromFlutterEngine();
                stopSelf();
            }
            isRunning = false;
            return START_STICKY;
        }
        if (windowManager != null) {
            windowManager.removeView(flutterView);
            windowManager = null;
            flutterView.detachFromFlutterEngine();
            stopSelf();
        }
        isRunning = true;
        Log.d("onStartCommand", "Service started");
        flutterView = new FlutterView(getApplicationContext(), new FlutterTextureView(getApplicationContext()));
        flutterView.attachToFlutterEngine(FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG));
        flutterView.setFitsSystemWindows(true);
        // 不抢主 App 焦点，保证前台可输入、返回键可用
        flutterView.setFocusable(false);
        flutterView.setFocusableInTouchMode(false);
        flutterView.setBackgroundColor(Color.TRANSPARENT);
        flutterChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("updateFlag")) {
                String flag = call.argument("flag").toString();
                updateOverlayFlag(result, flag);
            } else if (call.method.equals("updateOverlayPosition")) {
                int x = call.<Integer>argument("x");
                int y = call.<Integer>argument("y");
                moveOverlay(x, y, result);
            } else if (call.method.equals("resizeOverlay")) {
                int width = call.argument("width");
                int height = call.argument("height");
                boolean enableDrag = call.argument("enableDrag");
                resizeOverlay(width, height, enableDrag, result);
            } else if (call.method.equals("setAutoWalk")) {
                // 自动游走已暂时关闭
                stopAutoWalk();
                result.success(true);
                /*
                boolean enabled = Boolean.TRUE.equals(call.argument("enabled"));
                double screenW = call.argument("screenW") != null
                        ? ((Number) call.argument("screenW")).doubleValue() : 400d;
                double petW = call.argument("petW") != null
                        ? ((Number) call.argument("petW")).doubleValue() : 250d;
                if (enabled) {
                    startAutoWalk((float) screenW, (float) petW);
                } else {
                    stopAutoWalk();
                }
                result.success(true);
                */
            }
        });
        overlayMessageChannel.setMessageHandler((message, reply) -> {
            WindowSetup.messenger.send(message);
        });
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        refreshScreenSize();
        int dx = startX == OverlayConstants.DEFAULT_XY ? 0 : startX;
        int dy = startY == OverlayConstants.DEFAULT_XY ? -statusBarHeightPx() : startY;
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowSetup.width == -1999 ? -1 : WindowSetup.width,
                WindowSetup.height != -1999 ? WindowSetup.height : screenHeight(),
                0,
                -statusBarHeightPx(),
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE,
                WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR
                        | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
        );
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
            params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
        }
        params.gravity = WindowSetup.gravity;
        params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_STATE_UNCHANGED
                | WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING;
        flutterView.setOnTouchListener(this);
        windowManager.addView(flutterView, params);
        if (startX == OverlayConstants.POSITION_BOTTOM_RIGHT
                && startY == OverlayConstants.POSITION_BOTTOM_RIGHT) {
            final int marginDp = intent.getIntExtra("positionMarginDp", 16);
            flutterView.post(() -> positionOverlayBottomRight(marginDp));
        } else {
            moveOverlay(dx, dy, null);
        }
        flutterView.post(() -> syncOverlayEngineLifecycleOnStart());
        return START_STICKY;
    }

    private void positionOverlayBottomRight(int marginDp) {
        if (windowManager == null || flutterView == null) return;
        refreshScreenSize();
        WindowManager.LayoutParams params =
                (WindowManager.LayoutParams) flutterView.getLayoutParams();
        int rightMarginPx = dpToPx(marginDp);
        // 避开底部导航栏/手势条，再额外上移一段，避免贴底
        int bottomMarginPx = navigationBarHeightPx() + dpToPx(marginDp + 56);
        int w = params.width > 0 ? params.width : getPetWidthPx();
        int h = params.height > 0 ? params.height : w;
        params.x = Math.max(0, szWindow.x - w - rightMarginPx);
        params.y = Math.max(0, szWindow.y - h - bottomMarginPx);
        windowManager.updateViewLayout(flutterView, params);
        syncWalkDirectionFromPosition(params.x);
    }


    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    private int screenHeight() {
        Display display = windowManager.getDefaultDisplay();
        DisplayMetrics dm = new DisplayMetrics();
        display.getRealMetrics(dm);
        return inPortrait() ?
                dm.heightPixels + statusBarHeightPx() + navigationBarHeightPx()
                :
                dm.heightPixels + statusBarHeightPx();
    }

    private int statusBarHeightPx() {
        if (mStatusBarHeight == -1) {
            int statusBarHeightId = mResources.getIdentifier("status_bar_height", "dimen", "android");

            if (statusBarHeightId > 0) {
                mStatusBarHeight = mResources.getDimensionPixelSize(statusBarHeightId);
            } else {
                mStatusBarHeight = dpToPx(DEFAULT_STATUS_BAR_HEIGHT_DP);
            }
        }

        return mStatusBarHeight;
    }

    int navigationBarHeightPx() {
        if (mNavigationBarHeight == -1) {
            int navBarHeightId = mResources.getIdentifier("navigation_bar_height", "dimen", "android");

            if (navBarHeightId > 0) {
                mNavigationBarHeight = mResources.getDimensionPixelSize(navBarHeightId);
            } else {
                mNavigationBarHeight = dpToPx(DEFAULT_NAV_BAR_HEIGHT_DP);
            }
        }

        return mNavigationBarHeight;
    }


    private void updateOverlayFlag(MethodChannel.Result result, String flag) {
        if (windowManager != null) {
            WindowSetup.setFlag(flag);
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.flags = WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS |
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
                params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
            } else {
                params.alpha = 1;
            }
            windowManager.updateViewLayout(flutterView, params);
            result.success(true);
        } else {
            result.success(false);
        }
    }

    private void resizeOverlay(int width, int height, boolean enableDrag, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.width = (width == -1999 || width == -1) ? -1 : width;
            params.height = (height != 1999 || height != -1) ? height : height;
            WindowSetup.enableDrag = enableDrag;
            windowManager.updateViewLayout(flutterView, params);
            result.success(true);
        } else {
            result.success(false);
        }
    }

    private void moveOverlay(int x, int y, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.x = (x == -1999 || x == -1) ? -1 : dpToPx(x);
            params.y = dpToPx(y);
            windowManager.updateViewLayout(flutterView, params);
            if (result != null)
                result.success(true);
        } else {
            if (result != null)
                result.success(false);
        }
    }


    public static Map<String, Double> getCurrentPosition() {
        if (instance != null && instance.flutterView != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
            Map<String, Double> position = new HashMap<>();
            position.put("x", instance.pxToDp(params.x));
            position.put("y", instance.pxToDp(params.y));
            return position;
        }
        return null;
    }

    public static boolean moveOverlay(int x, int y) {
        if (instance != null && instance.flutterView != null) {
            if (instance.windowManager != null) {
                WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
                params.x = (x == -1999 || x == -1) ? -1 : instance.dpToPx(x);
                params.y = instance.dpToPx(y);
                instance.windowManager.updateViewLayout(instance.flutterView, params);
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }


    @Override
    public void onCreate() {
        // Get the cached FlutterEngine
        FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);

        if (flutterEngine == null) {
            // Handle the error if engine is not found
            Log.e("OverlayService", "Flutter engine not found, hence creating new flutter engine");
            FlutterEngineGroup engineGroup = new FlutterEngineGroup(this);
            DartExecutor.DartEntrypoint entryPoint = new DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "overlayMain"
            );  // "overlayMain" is custom entry point

            flutterEngine = engineGroup.createAndRunEngine(this, entryPoint);

            // Cache the created FlutterEngine for future use
            FlutterEngineCache.getInstance().put(OverlayConstants.CACHED_TAG, flutterEngine);
        }

        // Create the MethodChannel with the properly initialized FlutterEngine
        if (flutterEngine != null) {
            flutterChannel = new MethodChannel(flutterEngine.getDartExecutor(), OverlayConstants.OVERLAY_TAG);
            overlayMessageChannel = new BasicMessageChannel(flutterEngine.getDartExecutor(), OverlayConstants.MESSENGER_TAG, JSONMessageCodec.INSTANCE);
        }

        createNotificationChannel();
        Intent notificationIntent;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationIntent = new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION);
            notificationIntent.setData(Uri.parse("package:" + getPackageName()));
        } else {
            notificationIntent = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
            notificationIntent.setData(Uri.parse("package:" + getPackageName()));
        }
        notificationIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        int pendingFlags;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            pendingFlags = PendingIntent.FLAG_IMMUTABLE;
        } else {
            pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        }
        PendingIntent pendingIntent = PendingIntent.getActivity(this,
                0, notificationIntent, pendingFlags);
        final int notifyIcon = getDrawableResourceId("mipmap", "launcher");
        Notification notification = new NotificationCompat.Builder(this, OverlayConstants.CHANNEL_ID)
                .setContentTitle(WindowSetup.overlayTitle)
                .setContentText(WindowSetup.overlayContent)
                .setSmallIcon(notifyIcon == 0 ? R.drawable.notification_icon : notifyIcon)
                .setContentIntent(pendingIntent)
                .setVisibility(WindowSetup.notificationVisibility)
                .build();
        startForeground(OverlayConstants.NOTIFICATION_ID, notification);
        instance = this;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                    OverlayConstants.CHANNEL_ID,
                    "Foreground Service Channel",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            assert manager != null;
            manager.createNotificationChannel(serviceChannel);
        }
    }

    private int getDrawableResourceId(String resType, String name) {
        return getApplicationContext().getResources().getIdentifier(String.format("ic_%s", name), resType, getApplicationContext().getPackageName());
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP,
                Float.parseFloat(dp + ""), mResources.getDisplayMetrics());
    }

    private double pxToDp(int px) {
        return (double) px / mResources.getDisplayMetrics().density;
    }

    private boolean inPortrait() {
        return mResources.getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
    }

    private void notifyOverlayTouch(String event, WindowManager.LayoutParams params) {
        if (overlayMessageChannel == null) return;
        if (params == null) {
            overlayMessageChannel.send("{\"event\":\"" + event + "\"}", reply -> {});
            return;
        }
        overlayMessageChannel.send(
                "{\"event\":\"" + event + "\",\"x\":" + pxToDp(params.x) + ",\"y\":" + pxToDp(params.y) + "}",
                reply -> {}
        );
    }

    private void notifyWalkDirection(boolean toLeft) {
        if (overlayMessageChannel == null) return;
        overlayMessageChannel.send(
                "{\"event\":\"walk_dir\",\"left\":" + toLeft + "}",
                reply -> {}
        );
    }

    private void startAutoWalk(float screenW, float petW) {
        petWidthDp = petW;
        refreshScreenSize();
        autoWalkEnabled = true;
        walkPaused = false;
        walkSummonDelay = true;
        walkSummonDelayUntil = System.currentTimeMillis() + 500;
        lastWalkFrameAt = 0;
        walkHandler.removeCallbacks(walkRunnable);
        walkHandler.removeCallbacks(resumeWalkRunnable);
        if (flutterView != null) {
            syncWalkDirectionFromPosition(
                    ((WindowManager.LayoutParams) flutterView.getLayoutParams()).x);
        }
        walkHandler.post(walkRunnable);
    }

    private void stopAutoWalk() {
        autoWalkEnabled = false;
        walkHandler.removeCallbacks(walkRunnable);
        walkHandler.removeCallbacks(resumeWalkRunnable);
    }

    private void pauseAutoWalk() {
        walkPaused = true;
        lastWalkFrameAt = 0;
        walkHandler.removeCallbacks(resumeWalkRunnable);
    }

    private void resumeAutoWalk() {
        if (!autoWalkEnabled) return;
        walkPaused = false;
        lastWalkFrameAt = 0;
    }

    private void resumeAutoWalkAfterDrag() {
        walkHandler.removeCallbacks(resumeWalkRunnable);
        walkHandler.postDelayed(resumeWalkRunnable, 400);
    }

    private void launchMainApp(boolean openProfile) {
        if (mainAppInForeground) return;
        try {
            Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
            if (launch == null) {
                launch = new Intent(getApplicationContext(), Class.forName("com.jnr.flutter_pet_memorial.MainActivity"));
            }
            if (openProfile) {
                launch.putExtra("open_route", "/page/profile");
            }
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            getApplicationContext().startActivity(launch);
        } catch (Exception e) {
            Log.e("OverlayService", "Failed to launch main app", e);
        }
    }

    @Override
    public boolean onTouch(View view, MotionEvent event) {
        if (windowManager != null && WindowSetup.enableDrag) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    dragging = false;
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    pauseAutoWalk();
                    notifyOverlayTouch("touch_down", params);
                    break;
                case MotionEvent.ACTION_MOVE:
                    float dx = event.getRawX() - lastX;
                    float dy = event.getRawY() - lastY;
                    if (!dragging && dx * dx + dy * dy < 25) {
                        return false;
                    }
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    boolean invertX = WindowSetup.gravity == (Gravity.TOP | Gravity.RIGHT)
                            || WindowSetup.gravity == (Gravity.CENTER | Gravity.RIGHT)
                            || WindowSetup.gravity == (Gravity.BOTTOM | Gravity.RIGHT);
                    boolean invertY = WindowSetup.gravity == (Gravity.BOTTOM | Gravity.LEFT)
                            || WindowSetup.gravity == Gravity.BOTTOM
                            || WindowSetup.gravity == (Gravity.BOTTOM | Gravity.RIGHT);
                    int xx = params.x + ((int) dx * (invertX ? -1 : 1));
                    int yy = params.y + ((int) dy * (invertY ? -1 : 1));
                    xx = Math.max(0, Math.min(xx, getMaxWalkXPx()));
                    params.x = xx;
                    params.y = yy;
                    if (windowManager != null) {
                        windowManager.updateViewLayout(flutterView, params);
                    }
                    dragging = true;
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    lastYPosition = params.y;
                    notifyOverlayTouch("touch_up", params);
                    if (!dragging) {
                        launchMainApp(false);
                        resumeAutoWalk();
                    } else {
                        resumeAutoWalkAfterDrag();
                    }
                    if (!WindowSetup.positionGravity.equals("none")) {
                        if (windowManager == null) return false;
                        windowManager.updateViewLayout(flutterView, params);
                        mTrayTimerTask = new TrayAnimationTimerTask();
                        mTrayAnimationTimer = new Timer();
                        mTrayAnimationTimer.schedule(mTrayTimerTask, 0, 25);
                    }
                    return false;
                default:
                    return false;
            }
            return false;
        }
        return false;
    }

    private class TrayAnimationTimerTask extends TimerTask {
        int mDestX;
        int mDestY;
        WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();

        public TrayAnimationTimerTask() {
            super();
            mDestY = lastYPosition;
            switch (WindowSetup.positionGravity) {
                case "auto":
                    mDestX = (params.x + (flutterView.getWidth() / 2)) <= szWindow.x / 2 ? 0 : szWindow.x - flutterView.getWidth();
                    return;
                case "left":
                    mDestX = 0;
                    return;
                case "right":
                    mDestX = szWindow.x - flutterView.getWidth();
                    return;
                default:
                    mDestX = params.x;
                    mDestY = params.y;
                    break;
            }
        }

        @Override
        public void run() {
            mAnimationHandler.post(() -> {
                params.x = (2 * (params.x - mDestX)) / 3 + mDestX;
                params.y = (2 * (params.y - mDestY)) / 3 + mDestY;
                if (windowManager != null) {
                    windowManager.updateViewLayout(flutterView, params);
                }
                if (Math.abs(params.x - mDestX) < 2 && Math.abs(params.y - mDestY) < 2) {
                    TrayAnimationTimerTask.this.cancel();
                    mTrayAnimationTimer.cancel();
                }
            });
        }
    }


}