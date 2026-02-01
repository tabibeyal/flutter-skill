package com.aidashboad.flutterskill

import com.intellij.execution.ExecutionListener
import com.intellij.execution.process.ProcessHandler
import com.intellij.execution.runners.ExecutionEnvironment
import com.intellij.openapi.diagnostic.Logger
import com.intellij.openapi.project.Project
import java.io.File

/**
 * Listens to Flutter process output and automatically extracts VM Service URI
 * This enables zero-configuration detection - no need for --vm-service-port flag!
 */
class FlutterProcessListener : ExecutionListener {
    private val logger = Logger.getInstance(FlutterProcessListener::class.java)

    // Regex patterns to match VM Service URI in Flutter output
    private val vmServicePatterns = listOf(
        // Flutter 3.x format: "An Observatory debugger and profiler on ... is available at: http://..."
        Regex("Observatory.*?available at[: ]+(https?://[\\w.:]+/\\w+)"),
        // Alternative format: "The Dart VM service is listening on http://..."
        Regex("VM service is listening on (https?://[\\w.:]+/\\w+)"),
        // WebSocket format: "ws://127.0.0.1:xxxxx/ws"
        Regex("(ws://[\\w.:]+/\\w+)")
    )

    override fun processStarted(executorId: String, env: ExecutionEnvironment, handler: ProcessHandler) {
        val project = env.project

        // Only handle Flutter run configurations
        if (!isFlutterRunConfiguration(env)) {
            return
        }

        logger.info("Flutter process started, monitoring for VM Service URI...")

        // Add listener to capture process output
        handler.addProcessListener(object : com.intellij.execution.process.ProcessAdapter() {
            override fun onTextAvailable(event: com.intellij.execution.process.ProcessEvent, outputType: com.intellij.openapi.util.Key<*>) {
                val text = event.text

                // Try to extract VM Service URI from output
                for (pattern in vmServicePatterns) {
                    val match = pattern.find(text)
                    if (match != null) {
                        val uri = match.groupValues[1]
                        logger.info("Auto-detected VM Service URI: $uri")
                        saveVmServiceUri(project, uri)
                        return
                    }
                }
            }
        })
    }

    /**
     * Check if this is a Flutter run configuration
     */
    private fun isFlutterRunConfiguration(env: ExecutionEnvironment): Boolean {
        val runProfile = env.runProfile
        val name = runProfile.name.lowercase()
        val configClass = runProfile.javaClass.name.lowercase()

        // Check if configuration name or class contains "flutter"
        return name.contains("flutter") || configClass.contains("flutter")
    }

    /**
     * Connect to VM Service URI directly (in-memory, no file needed!)
     */
    private fun saveVmServiceUri(project: Project, uri: String) {
        try {
            // Convert HTTP URI to WebSocket if needed
            val wsUri = if (uri.startsWith("http")) {
                uri.replace("http://", "ws://").replace("https://", "wss://")
                    .let { if (!it.endsWith("/ws")) "$it/ws" else it }
            } else {
                uri
            }

            logger.info("Auto-detected VM Service URI: $wsUri - connecting directly...")

            // Direct in-memory connection - no file I/O needed!
            VmServiceScanner.getInstance(project).connectToUri(wsUri)

            // Optional: Also save to file for compatibility with external tools (MCP server, CLI)
            val basePath = project.basePath
            if (basePath != null) {
                try {
                    val uriFile = File("$basePath/.flutter_skill_uri")
                    uriFile.writeText(wsUri)
                    logger.info("Also saved to ${uriFile.absolutePath} for external tools")
                } catch (e: Exception) {
                    logger.warn("Could not save to file (not critical): ${e.message}")
                }
            }
        } catch (e: Exception) {
            logger.error("Failed to connect to VM Service: ${e.message}", e)
        }
    }
}
