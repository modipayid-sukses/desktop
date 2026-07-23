package com.modipay.company

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	private val securityChannel = "modipay/security"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"isDeveloperModeEnabled" -> result.success(isDeveloperModeEnabled())
					else -> result.notImplemented()
				}
			}
	}

	private fun isDeveloperModeEnabled(): Boolean {
		return try {
			val resolver = applicationContext.contentResolver
			val devOptions = Settings.Global.getInt(
				resolver,
				Settings.Global.DEVELOPMENT_SETTINGS_ENABLED,
				0
			) == 1
			val usbDebugging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
				Settings.Global.getInt(resolver, Settings.Global.ADB_ENABLED, 0) == 1
			} else {
				Settings.Secure.getInt(resolver, Settings.Secure.ADB_ENABLED, 0) == 1
			}

			devOptions || usbDebugging
		} catch (_: Exception) {
			false
		}
	}
}
