package com.zephyr.reader

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

/// Zephyr Reader 主 Activity。
///
/// 使用 FlutterFragmentActivity 以兼容需要 FragmentManager 的插件
/// （如 flureadium/ReadiumReaderWidget）。
///
/// FlutterFragmentActivity 的 onSaveInstanceState 在特定场景可能触发
class MainActivity : FlutterFragmentActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
    }

    override fun onSaveInstanceState(outState: Bundle) {
        // FragmentActivity 在特定场景可能触发 Bundle NPE
        try {
            super.onSaveInstanceState(outState)
        } catch (_: Exception) {
            // 忽略可恢复的保存状态错误
        }
    }
}
