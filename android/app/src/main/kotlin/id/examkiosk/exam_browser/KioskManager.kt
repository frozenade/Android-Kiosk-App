package id.examkiosk.exam_browser

import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.UserManager

/**
 * Kiosk control without root.
 *
 * - Device Owner (provisioned via `adb shell dpm set-device-owner` / QR / MDM):
 *   the app whitelists itself for Lock Task Mode, so `startLockTask()` gives a
 *   full lock — no Home, Recents, status bar, notifications or exit gesture.
 * - Ordinary install: `startLockTask()` falls back to Screen Pinning. Android
 *   asks the user to confirm, and the user can unpin with Back + Recents.
 *   Dart polls [status] and treats an unpin as a violation.
 */
class KioskManager(private val context: Context) {
    private val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    private val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val admin = ComponentName(context, KioskAdminReceiver::class.java)

    private val restrictions = listOf(
        UserManager.DISALLOW_SAFE_BOOT,
        UserManager.DISALLOW_CREATE_WINDOWS,
        UserManager.DISALLOW_ADD_USER,
        UserManager.DISALLOW_FACTORY_RESET,
    )

    val isDeviceOwner: Boolean
        get() = dpm.isDeviceOwnerApp(context.packageName)

    fun status(message: String? = null): Map<String, Any?> {
        val state = am.lockTaskModeState
        val mode = when (state) {
            ActivityManager.LOCK_TASK_MODE_LOCKED -> "lock_task"
            ActivityManager.LOCK_TASK_MODE_PINNED -> "screen_pinning"
            else -> "none"
        }
        return mapOf(
            "platform" to "android",
            "active" to (state != ActivityManager.LOCK_TASK_MODE_NONE),
            "fullLock" to (state == ActivityManager.LOCK_TASK_MODE_LOCKED),
            "mode" to mode,
            "deviceOwner" to isDeviceOwner,
            "message" to message,
        )
    }

    fun start(activity: Activity): Map<String, Any?> {
        if (isDeviceOwner) applyDeviceOwnerPolicies(true)
        if (am.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
            try {
                activity.startLockTask()
            } catch (e: Exception) {
                return status("Gagal mengaktifkan mode kiosk: ${e.message}")
            }
        }
        return status()
    }

    fun stop(activity: Activity): Map<String, Any?> {
        if (am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE) {
            try {
                activity.stopLockTask()
            } catch (e: Exception) {
                // Not in lock task for this activity; nothing to stop.
            }
        }
        if (isDeviceOwner) applyDeviceOwnerPolicies(false)
        return status()
    }

    /** Gives up Device Owner so the phone can be used normally (or wiped) again. */
    @Suppress("DEPRECATION")
    fun releaseDeviceOwner(activity: Activity): Boolean {
        if (!isDeviceOwner) return false
        stop(activity)
        dpm.setLockTaskPackages(admin, emptyArray())
        dpm.clearDeviceOwnerApp(context.packageName)
        return true
    }

    private fun applyDeviceOwnerPolicies(enable: Boolean) {
        if (enable) {
            dpm.setLockTaskPackages(admin, arrayOf(context.packageName))
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // No Home, Recents, notifications, system info or global actions.
                dpm.setLockTaskFeatures(admin, DevicePolicyManager.LOCK_TASK_FEATURE_NONE)
            }
        }
        dpm.setStatusBarDisabled(admin, enable)
        for (r in restrictions) {
            if (enable) dpm.addUserRestriction(admin, r) else dpm.clearUserRestriction(admin, r)
        }
    }
}
