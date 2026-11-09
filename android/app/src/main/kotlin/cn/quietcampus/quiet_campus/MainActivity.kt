package cn.quietcampus.quiet_campus

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.CalendarContract

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.quietcampus/calendar")
            .setMethodCallHandler { call, result ->
                if (call.method != "addEvent") { result.notImplemented(); return@setMethodCallHandler }
                val start = call.argument<Number>("start")?.toLong()
                val end = call.argument<Number>("end")?.toLong()
                val title = call.argument<String>("title")
                if (start == null || end == null || end <= start || title == null) {
                    result.error("invalid_event", "日程时间无效", null)
                    return@setMethodCallHandler
                }
                val intent = Intent(Intent.ACTION_INSERT).setData(CalendarContract.Events.CONTENT_URI)
                    .putExtra(CalendarContract.Events.TITLE, title)
                    .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
                    .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
                try {
                    startActivity(intent)
                    // ACTION_INSERT opens the calendar editor; its save result is not guaranteed.
                    result.success(true)
                } catch (_: android.content.ActivityNotFoundException) {
                    result.error("calendar_unavailable", "请先安装系统日历应用", null)
                }
            }
    }
}
