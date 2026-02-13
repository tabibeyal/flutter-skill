const { app, BrowserWindow } = require('electron');
const path = require('path');

// Inject the flutter-skill-electron SDK
const { FlutterSkillElectron } = require('../../../sdks/electron/flutter-skill-electron');

let mainWindow;
let bridge;

app.whenReady().then(() => {
  mainWindow = new BrowserWindow({
    width: 800, height: 600,
    webPreferences: { nodeIntegration: false, contextIsolation: true }
  });

  mainWindow.loadFile(path.join(__dirname, 'index.html'));

  // Start flutter-skill bridge
  bridge = new FlutterSkillElectron({
    window: mainWindow,
    port: 18118,
    appName: 'ElectronTestApp',
  });
  bridge.start();
  console.log('[test] Flutter Skill Electron bridge started on port 18118');
});

app.on('window-all-closed', () => {
  if (bridge) bridge.stop();
  app.quit();
});
