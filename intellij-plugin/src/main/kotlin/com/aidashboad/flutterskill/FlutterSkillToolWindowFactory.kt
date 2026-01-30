package com.aidashboad.flutterskill

import com.intellij.openapi.project.Project
import com.intellij.openapi.wm.ToolWindow
import com.intellij.openapi.wm.ToolWindowFactory
import com.intellij.ui.content.ContentFactory
import javax.swing.*
import java.awt.BorderLayout

class FlutterSkillToolWindowFactory : ToolWindowFactory {
    override fun createToolWindowContent(project: Project, toolWindow: ToolWindow) {
        val panel = FlutterSkillPanel(project)
        val content = ContentFactory.getInstance().createContent(panel, "", false)
        toolWindow.contentManager.addContent(content)
    }
}

class FlutterSkillPanel(private val project: Project) : JPanel(BorderLayout()) {
    init {
        val toolbar = JPanel()

        val launchBtn = JButton("Launch App")
        launchBtn.addActionListener {
            FlutterSkillService.getInstance(project).launchApp()
        }

        val inspectBtn = JButton("Inspect")
        inspectBtn.addActionListener {
            FlutterSkillService.getInstance(project).inspect()
        }

        val screenshotBtn = JButton("Screenshot")
        screenshotBtn.addActionListener {
            FlutterSkillService.getInstance(project).screenshot()
        }

        val mcpBtn = JButton("Start MCP")
        mcpBtn.addActionListener {
            FlutterSkillService.getInstance(project).startMcpServer()
        }

        toolbar.add(launchBtn)
        toolbar.add(inspectBtn)
        toolbar.add(screenshotBtn)
        toolbar.add(mcpBtn)

        add(toolbar, BorderLayout.NORTH)

        val infoPanel = JPanel()
        infoPanel.layout = BoxLayout(infoPanel, BoxLayout.Y_AXIS)
        infoPanel.add(JLabel("Flutter Skill - AI App Automation"))
        infoPanel.add(JLabel(""))
        infoPanel.add(JLabel("MCP Config:"))
        infoPanel.add(JLabel("{"))
        infoPanel.add(JLabel("  \"flutter-skill\": {"))
        infoPanel.add(JLabel("    \"command\": \"npx\","))
        infoPanel.add(JLabel("    \"args\": [\"flutter-skill-mcp\"]"))
        infoPanel.add(JLabel("  }"))
        infoPanel.add(JLabel("}"))

        add(infoPanel, BorderLayout.CENTER)
    }
}
