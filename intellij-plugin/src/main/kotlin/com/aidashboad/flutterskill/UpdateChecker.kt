package com.aidashboad.flutterskill

import com.intellij.ide.BrowserUtil
import com.intellij.ide.util.PropertiesComponent
import com.intellij.notification.NotificationAction
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.application.ApplicationManager
import com.intellij.openapi.components.Service
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.project.Project
import com.google.gson.Gson
import com.google.gson.JsonObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

@Service(Service.Level.APP)
class UpdateChecker {
    private val logger = Logger.getInstance(UpdateChecker::class.java)
    private val gson = Gson()

    companion object {
        private const val CHECK_INTERVAL_HOURS = 24L
        private const val LAST_CHECK_KEY = "flutter-skill.lastUpdateCheck"
        private const val SKIPPED_VERSION_KEY = "flutter-skill.skippedVersion"
        private const val CURRENT_VERSION = NativeBinaryManager.VERSION

        @JvmStatic
        fun getInstance(): UpdateChecker {
            return ApplicationManager.getApplication().getService(UpdateChecker::class.java)
        }
    }

    fun checkForUpdatesAsync(project: Project) {
        ApplicationManager.getApplication().executeOnPooledThread {
            checkForUpdates(project)
        }
    }

    private fun checkForUpdates(project: Project) {
        val properties = PropertiesComponent.getInstance()

        // Check if we should check (once per 24 hours)
        val lastCheck = properties.getLong(LAST_CHECK_KEY, 0)
        val now = System.currentTimeMillis()
        val hoursSinceLastCheck = TimeUnit.MILLISECONDS.toHours(now - lastCheck)

        if (hoursSinceLastCheck < CHECK_INTERVAL_HOURS) {
            return
        }

        // Update last check time
        properties.setValue(LAST_CHECK_KEY, now.toString())

        logger.info("Checking for updates...")

        val latestVersion = getLatestVersion() ?: run {
            logger.info("Could not check for updates")
            return
        }

        logger.info("Current: $CURRENT_VERSION, Latest: $latestVersion")

        // Check if update available
        if (compareVersions(latestVersion, CURRENT_VERSION) <= 0) {
            logger.info("Already on latest version")
            return
        }

        // Check if user skipped this version
        val skippedVersion = properties.getValue(SKIPPED_VERSION_KEY)
        if (skippedVersion == latestVersion) {
            logger.info("User skipped this version")
            return
        }

        // Show update notification
        ApplicationManager.getApplication().invokeLater {
            NotificationGroupManager.getInstance()
                .getNotificationGroup("Flutter Skill")
                .createNotification(
                    "Update Available",
                    "Flutter Skill $latestVersion is available (current: $CURRENT_VERSION)",
                    NotificationType.INFORMATION
                )
                .addAction(NotificationAction.createSimple("Update Now") {
                    BrowserUtil.browse("https://plugins.jetbrains.com/plugin/PLUGIN_ID")
                })
                .addAction(NotificationAction.createSimple("View Changes") {
                    BrowserUtil.browse("https://github.com/ai-dashboad/flutter-skill/releases/tag/v$latestVersion")
                })
                .addAction(NotificationAction.createSimple("Skip This Version") {
                    properties.setValue(SKIPPED_VERSION_KEY, latestVersion)
                })
                .notify(project)
        }
    }

    private fun getLatestVersion(): String? {
        return try {
            val url = URL("https://registry.npmjs.org/flutter-skill-mcp")
            val connection = url.openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000

            if (connection.responseCode != 200) {
                return null
            }

            val response = connection.inputStream.bufferedReader().readText()
            val json = gson.fromJson(response, JsonObject::class.java)
            json.getAsJsonObject("dist-tags")?.get("latest")?.asString
        } catch (e: Exception) {
            logger.warn("Error checking for updates: ${e.message}")
            null
        }
    }

    private fun compareVersions(v1: String, v2: String): Int {
        val parts1 = v1.split(".").map { it.toIntOrNull() ?: 0 }
        val parts2 = v2.split(".").map { it.toIntOrNull() ?: 0 }

        for (i in 0 until maxOf(parts1.size, parts2.size)) {
            val p1 = parts1.getOrNull(i) ?: 0
            val p2 = parts2.getOrNull(i) ?: 0
            if (p1 > p2) return 1
            if (p1 < p2) return -1
        }
        return 0
    }
}
