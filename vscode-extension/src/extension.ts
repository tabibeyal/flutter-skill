import * as vscode from 'vscode';
import * as child_process from 'child_process';
import * as path from 'path';
import * as fs from 'fs';

let mcpServerProcess: child_process.ChildProcess | undefined;
let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
    outputChannel = vscode.window.createOutputChannel('Flutter Skill');

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('flutter-skill.launch', launchApp),
        vscode.commands.registerCommand('flutter-skill.inspect', inspectUI),
        vscode.commands.registerCommand('flutter-skill.screenshot', takeScreenshot),
        vscode.commands.registerCommand('flutter-skill.startMcpServer', startMcpServer)
    );

    // Auto-start MCP server if configured
    const config = vscode.workspace.getConfiguration('flutter-skill');
    if (config.get('autoConnect')) {
        // Check if there's a .flutter_skill_uri file in workspace
        const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
        if (workspaceFolder) {
            const uriFile = path.join(workspaceFolder.uri.fsPath, '.flutter_skill_uri');
            if (fs.existsSync(uriFile)) {
                outputChannel.appendLine('Found existing Flutter app connection');
            }
        }
    }

    outputChannel.appendLine('Flutter Skill extension activated');
}

export function deactivate() {
    if (mcpServerProcess) {
        mcpServerProcess.kill();
    }
}

async function launchApp() {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    const config = vscode.workspace.getConfiguration('flutter-skill');
    const dartPath = config.get<string>('dartPath') || 'dart';

    // Check for pubspec.yaml
    const pubspecPath = path.join(workspaceFolder.uri.fsPath, 'pubspec.yaml');
    if (!fs.existsSync(pubspecPath)) {
        vscode.window.showErrorMessage('No pubspec.yaml found. Is this a Flutter project?');
        return;
    }

    // Run flutter_skill launch
    const terminal = vscode.window.createTerminal('Flutter Skill');
    terminal.show();
    terminal.sendText(`${dartPath} pub global run flutter_skill launch .`);

    vscode.window.showInformationMessage('Launching Flutter app with Flutter Skill...');
}

async function inspectUI() {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    const config = vscode.workspace.getConfiguration('flutter-skill');
    const dartPath = config.get<string>('dartPath') || 'dart';

    // Check for .flutter_skill_uri
    const uriFile = path.join(workspaceFolder.uri.fsPath, '.flutter_skill_uri');
    if (!fs.existsSync(uriFile)) {
        vscode.window.showErrorMessage('No running Flutter app found. Launch an app first.');
        return;
    }

    // Run inspect command
    const terminal = vscode.window.createTerminal('Flutter Skill Inspect');
    terminal.show();
    terminal.sendText(`${dartPath} pub global run flutter_skill inspect`);
}

async function takeScreenshot() {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
        vscode.window.showErrorMessage('No workspace folder open');
        return;
    }

    const config = vscode.workspace.getConfiguration('flutter-skill');
    const dartPath = config.get<string>('dartPath') || 'dart';

    // Check for .flutter_skill_uri
    const uriFile = path.join(workspaceFolder.uri.fsPath, '.flutter_skill_uri');
    if (!fs.existsSync(uriFile)) {
        vscode.window.showErrorMessage('No running Flutter app found. Launch an app first.');
        return;
    }

    // Get save location
    const saveUri = await vscode.window.showSaveDialog({
        defaultUri: vscode.Uri.file(path.join(workspaceFolder.uri.fsPath, 'screenshot.png')),
        filters: { 'Images': ['png'] }
    });

    if (!saveUri) return;

    // Run screenshot command
    const terminal = vscode.window.createTerminal('Flutter Skill Screenshot');
    terminal.show();
    terminal.sendText(`${dartPath} pub global run flutter_skill screenshot "${saveUri.fsPath}"`);

    vscode.window.showInformationMessage(`Screenshot will be saved to ${saveUri.fsPath}`);
}

async function startMcpServer() {
    if (mcpServerProcess) {
        vscode.window.showInformationMessage('MCP Server is already running');
        return;
    }

    const config = vscode.workspace.getConfiguration('flutter-skill');
    const dartPath = config.get<string>('dartPath') || 'dart';

    mcpServerProcess = child_process.spawn(dartPath, ['pub', 'global', 'run', 'flutter_skill', 'server'], {
        stdio: ['pipe', 'pipe', 'pipe']
    });

    mcpServerProcess.stdout?.on('data', (data) => {
        outputChannel.appendLine(`[MCP] ${data}`);
    });

    mcpServerProcess.stderr?.on('data', (data) => {
        outputChannel.appendLine(`[MCP Error] ${data}`);
    });

    mcpServerProcess.on('close', (code) => {
        outputChannel.appendLine(`MCP Server exited with code ${code}`);
        mcpServerProcess = undefined;
    });

    vscode.window.showInformationMessage('Flutter Skill MCP Server started');
    outputChannel.show();
}
