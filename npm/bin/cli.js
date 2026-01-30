#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// Find the dart directory
const dartDir = path.join(__dirname, '..', 'dart');
const serverScript = path.join(dartDir, 'bin', 'server.dart');

// Check if Dart is installed
function checkDart() {
  try {
    require('child_process').execSync('dart --version', { stdio: 'ignore' });
    return true;
  } catch (e) {
    return false;
  }
}

// Check if Flutter is installed
function checkFlutter() {
  try {
    require('child_process').execSync('flutter --version', { stdio: 'ignore' });
    return true;
  } catch (e) {
    return false;
  }
}

if (!checkDart()) {
  console.error('Error: Dart SDK not found. Please install Flutter/Dart first.');
  console.error('  https://docs.flutter.dev/get-started/install');
  process.exit(1);
}

if (!checkFlutter()) {
  console.error('Warning: Flutter SDK not found. Some features may not work.');
}

// Check if server script exists
if (!fs.existsSync(serverScript)) {
  console.error('Error: Server script not found at:', serverScript);
  process.exit(1);
}

// Get dependencies first
const pubGet = spawn('dart', ['pub', 'get'], {
  cwd: dartDir,
  stdio: 'inherit'
});

pubGet.on('close', (code) => {
  if (code !== 0) {
    console.error('Failed to get dependencies');
    process.exit(1);
  }

  // Start the MCP server
  const server = spawn('dart', ['run', serverScript], {
    cwd: dartDir,
    stdio: 'inherit'
  });

  server.on('close', (code) => {
    process.exit(code || 0);
  });

  // Forward signals
  process.on('SIGINT', () => server.kill('SIGINT'));
  process.on('SIGTERM', () => server.kill('SIGTERM'));
});
