package com.example.auto_ledger

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/// 抓取支付类通知：微信 / 支付宝 / 云闪付 / 常用银行 App
class LedgerNotificationService : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        val n = sbn?.notification ?: return
        val pkg = sbn.packageName ?: return
        if (!WATCHED_PACKAGES.contains(pkg)) return

        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString().orEmpty()

        val body = buildString {
            appendLine(title)
            if (subText.isNotBlank()) appendLine(subText)
            appendLine(if (bigText.isNotBlank()) bigText else text)
        }.trim()

        if (body.isBlank()) return
        // 只处理「看起来像一笔钱」的通知，避免聊天消息被误记
        if (!AMOUNT_LIKE.containsMatchIn(body)) return

        NotificationSink.emit(body, pkg)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) = Unit

    companion object {
        private val WATCHED_PACKAGES = setOf(
            "com.tencent.mm",          // 微信
            "com.eg.android.AlipayGphone", // 支付宝
            "com.unionpay",            // 云闪付
            "com.android.mms",         // 短信（含银行/运营商通知）
            "com.cmbchina.pb",         // 招商银行
            "com.icbc",                // 工商银行
            "com.ccb",                 // 建设银行
            "com.boc",                 // 中国银行
            "com.abchina",             // 农业银行
            "com.bocom",               // 交通银行
            "com.psbc",                // 邮储银行
        )

        private val AMOUNT_LIKE = Regex("""[¥￥]|[0-9]+\.[0-9]{2}|元""")
    }
}
