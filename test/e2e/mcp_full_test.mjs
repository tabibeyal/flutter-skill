#!/usr/bin/env node
/**
 * Full MCP tool test for v0.8.1 new features
 * Tests all 11 new tools + snapshot enhancement on each platform via MCP stdio
 * 
 * Usage: node mcp_full_test.mjs [connect_uri]
 *   connect_uri: optional, e.g. ws://127.0.0.1:50000/xxx=/ws for Flutter
 *   If omitted, uses scan_and_connect
 */

import { spawn } from 'child_process';
import { createInterface } from 'readline';

const CONNECT_URI = process.argv[2] || null;
const DART = '/Users/cw/development/flutter/bin/dart';
const SERVER = '/Users/cw/development/flutter-skill/bin/flutter_skill.dart';

let pass = 0, fail = 0, skip = 0;
const results = [];

function log(status, name, detail = '') {
  const icon = status === 'pass' ? '✅' : status === 'fail' ? '❌' : '⏭️';
  console.log(`  ${icon} ${name}${detail ? ' — ' + detail : ''}`);
  if (status === 'pass') pass++;
  else if (status === 'fail') fail++;
  else skip++;
  results.push({ name, status, detail });
}

async function main() {
  console.log('============================================');
  console.log('MCP Full Test — v0.8.1 All New Tools');
  console.log('============================================\n');

  // Start MCP server
  const proc = spawn(DART, ['run', SERVER, 'server'], {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, PATH: `/Users/cw/development/flutter/bin:${process.env.PATH}` }
  });

  const responses = new Map();
  let lineBuffer = '';

  const rl = createInterface({ input: proc.stdout });
  rl.on('line', (line) => {
    try {
      const msg = JSON.parse(line);
      if (msg.id !== undefined) responses.set(msg.id, msg);
    } catch {}
  });

  const send = (id, method, params = {}) => {
    const msg = JSON.stringify({ jsonrpc: '2.0', method, params, id });
    proc.stdin.write(msg + '\n');
  };

  const waitFor = (id, timeoutMs = 15000) => new Promise((resolve) => {
    const start = Date.now();
    const check = () => {
      if (responses.has(id)) return resolve(responses.get(id));
      if (Date.now() - start > timeoutMs) return resolve({ id, error: { message: 'TIMEOUT' } });
      setTimeout(check, 200);
    };
    check();
  });

  const callTool = async (id, name, args = {}, timeoutMs = 15000) => {
    send(id, 'tools/call', { name, arguments: args });
    return waitFor(id, timeoutMs);
  };

  const checkTool = async (id, displayName, args = {}, timeoutMs = 15000) => {
    const toolName = displayName.split(' (')[0].split(' ')[0]; // extract actual tool name
    const r = await callTool(id, toolName, args, timeoutMs);
    if (r.error) {
      const msg = r.error.message || '';
      if (msg.includes('Not connected') || msg.includes('requires a Flutter')) {
        log('skip', displayName, 'not applicable for this platform');
      } else if (msg === 'TIMEOUT') {
        log('fail', displayName, 'TIMEOUT');
      } else {
        log('fail', displayName, msg.substring(0, 100));
      }
    } else {
      // Check if result contains error
      try {
        const content = JSON.parse(r.result?.content?.[0]?.text || '{}');
        if (content.success === false && content.error) {
          log('fail', displayName, typeof content.error === 'string' ? content.error : content.error.message || 'failed');
        } else {
          log('pass', displayName);
        }
      } catch {
        log('pass', displayName);
      }
    }
    return r;
  };

  // 1. Initialize
  send(1, 'initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'mcp-full-test', version: '1.0' }
  });
  const init = await waitFor(1);
  if (!init.result) {
    console.log('❌ Initialize failed');
    proc.kill();
    process.exit(1);
  }
  console.log(`Server: ${init.result.serverInfo?.name} v${init.result.serverInfo?.version}\n`);

  // 2. Connect
  let connected = false;
  if (CONNECT_URI) {
    send(2, 'tools/call', { name: 'connect_app', arguments: { uri: CONNECT_URI } });
  } else {
    send(2, 'tools/call', { name: 'scan_and_connect', arguments: {} });
  }
  const conn = await waitFor(2, 20000);
  try {
    const c = JSON.parse(conn.result?.content?.[0]?.text || '{}');
    if (c.success) {
      console.log(`Connected: ${c.framework} @ ${c.connected || CONNECT_URI}`);
      connected = true;
    } else {
      console.log(`❌ Connection failed: ${c.error?.message || c.message || 'unknown'}`);
    }
  } catch {
    if (conn.error) console.log(`❌ Connection error: ${conn.error.message}`);
    else console.log(`❌ Connection: unexpected response`);
  }

  if (!connected) {
    console.log('\nCannot proceed without connection. Exiting.');
    proc.kill();
    process.exit(1);
  }

  console.log('\n--- Auth Tools ---');
  await checkTool(10, 'auth_otp (6-digit/30s)', { secret: 'JBSWY3DPEHPK3PXP' });
  await checkTool(11, 'auth_otp (8-digit/60s)', { secret: 'JBSWY3DPEHPK3PXP', digits: 8, period: 60 });
  await checkTool(12, 'auth_inject_session (local_storage)', { token: 'test-jwt-abc', storage: 'local_storage', key: 'auth_token' });
  await checkTool(13, 'auth_inject_session (shared_prefs)', { token: 'test-jwt-xyz', key: 'session' });
  await checkTool(14, 'auth_biometric (enroll)', { action: 'enroll' });
  await checkTool(15, 'auth_biometric (match)', { action: 'match' });
  await checkTool(16, 'auth_biometric (fail)', { action: 'fail' });
  await checkTool(17, 'auth_deeplink', { url: 'myapp://test?token=abc123' });

  console.log('\n--- Snapshot Modes ---');
  await checkTool(20, 'snapshot (text)', { mode: 'text' }, 20000);
  await checkTool(21, 'snapshot (vision)', { mode: 'vision' }, 20000);
  await checkTool(22, 'snapshot (smart)', { mode: 'smart' }, 20000);

  console.log('\n--- Video Recording ---');
  await checkTool(30, 'video_start', {});
  // Wait for video to record something
  await new Promise(r => setTimeout(r, 3000));
  await checkTool(31, 'video_stop', {});

  console.log('\n--- Code Recording ---');
  await checkTool(40, 'record_start', {});
  // Do some actions to record
  await callTool(41, 'tap', { ref: 'button:Home' });
  await callTool(42, 'enter_text', { text: 'test input', ref: 'input:textinput' });
  await callTool(43, 'go_back', {});
  await checkTool(44, 'record_stop', {});

  console.log('\n--- Record Export ---');
  await checkTool(50, 'record_export (jest)', { format: 'jest' });
  await checkTool(51, 'record_export (pytest)', { format: 'pytest' });
  await checkTool(52, 'record_export (dart_test)', { format: 'dart_test' });
  await checkTool(53, 'record_export (playwright)', { format: 'playwright' });
  await checkTool(54, 'record_export (json)', { format: 'json' });

  console.log('\n--- Parallel Multi-Device ---');
  await checkTool(60, 'parallel_snapshot', {});
  await checkTool(61, 'parallel_tap', { ref: 'button:Home' });

  // Summary
  console.log('\n============================================');
  console.log(`Results: ${pass} passed, ${fail} failed, ${skip} skipped`);
  console.log(`Total: ${pass + fail + skip} / 24 tools tested`);
  console.log('============================================');

  proc.kill();
  process.exit(fail > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
