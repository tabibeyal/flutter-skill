package com.aidashboad.flutterskill

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.execution.process.OSProcessHandler
import com.intellij.execution.process.ProcessAdapter
import com.intellij.execution.process.ProcessEvent
import com.intellij.notification.NotificationGroupManager
import com.intellij.notification.NotificationType
import com.intellij.openapi.components.Service
import com.intellij.openapi.project.Project
import com.intellij.openapi.util.Key

@Service(Service.Level.PROJECT)
class FlutterSkillService(private val project: Project) {

    private var mcpProcess: OSProcessHandler? = null

    companion object {
        fun getInstance(project: Project): FlutterSkillService {
            return project.getService(FlutterSkillService::class.java)
        }
    }

    fun launchApp() {
        val basePath = project.basePath ?: return
        runCommand("dart", listOf("pub", "global", "run", "flutter_skill", "launch", "."), basePath)
        notify("Flutter app launching with Flutter Skill...")
    }

    fun inspect() {
        val basePath = project.basePath ?: return
        runCommand("dart", listOf("pub", "global", "run", "flutter_skill", "inspect"), basePath)
    }

    fun screenshot() {
        val basePath = project.basePath ?: return
        val outputPath = "$basePath/screenshot.png"
        runCommand("dart", listOf("pub", "global", "run", "flutter_skill", "screenshot", outputPath), basePath)
        notify("Screenshot saved to $outputPath")
    }

    fun startMcpServer() {
        if (mcpProcess != null && !mcpProcess!!.isProcessTerminated) {
            notify("MCP Server is already running", NotificationType.WARNING)
            return
        }

        val commandLine = GeneralCommandLine("dart", "pub", "global", "run", "flutter_skill", "server")
        mcpProcess = OSProcessHandler(commandLine)

        mcpProcess?.addProcessListener(object : ProcessAdapter() {
            override fun processTerminated(event: ProcessEvent) {
                notify("MCP Server stopped")
            }

            override fun onTextAvailable(event: ProcessEvent, outputType: Key<*>) {
                // Log output if needed
            }
        })

        mcpProcess?.startNotify()
        notify("MCP Server started")
    }

    fun stopMcpServer() {
        mcpProcess?.destroyProcess()
        mcpProcess = null
    }

    private fun runCommand(command: String, args: List<String>, workDir: String) {
        val commandLine = GeneralCommandLine(command)
        commandLine.addParameters(args)
        commandLine.workDirectory = java.io.File(workDir)

        val handler = OSProcessHandler(commandLine)
        handler.startNotify()
    }

    private fun notify(message: String, type: NotificationType = NotificationType.INFORMATION) {
        NotificationGroupManager.getInstance()
            .getNotificationGroup("Flutter Skill")
            .createNotification(message, type)
            .notify(project)
    }
}
