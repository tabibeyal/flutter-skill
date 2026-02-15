#!/usr/bin/env node
/**
 * Test script for v0.8.1 new features:
 * - Auth tools (auth_inject_session, auth_biometric, auth_otp, auth_deeplink)
 * - Code generation (record_start, record_stop, record_export)
 * - Video recording (video_start, video_stop)
 * - Smart snapshot (mode: text/vision/smart)
 * - Parallel execution (parallel_snapshot, parallel_tap)
 * 
 * Usage: node new_features_test.mjs [platform] [port]
 *   platform: electron (default), android, ios
 *   port: 18118 (default)
 */

import WebSocket from 'ws';

const PLATFORM = process.argv[2] || 'electron';
const PORT = parseInt(process.argv[3] || '18118');
const WS_URL = `ws://127.0.0.1:${PORT}`;

let ws;
let reqId = 1;
let pass = 0, fail = 0, skip = 0;

function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = reqId++;
    const timeout = setTimeout(() => reject(new Error(`Timeout: ${method}`)), 10000);
    const handler = (data) => {
      const msg = JSON.parse(data.toString());
      if (msg.id === id) {
        clearTimeout(timeout);
        ws.removeListener('message', handler);
        if (msg.error) reject(new Error(msg.error.message || JSON.stringify(msg.error)));
        else resolve(msg.result);
      }
    };
    ws.on('message', handler);
    ws.send(JSON.stringify({ jsonrpc: '2.0', method, params, id }));
  });
}

async function test(name, fn) {
  try {
    await fn();
    console.log(`  ✅ ${name}`);
    pass++;
  } catch (e) {
    if (e.message?.startsWith('SKIP')) {
      console.log(`  ⏭️  ${name} (${e.message})`);
      skip++;
    } else {
      console.log(`  ❌ ${name}: ${e.message}`);
      fail++;
    }
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || 'Assertion failed');
}

async function run() {
  ws = new WebSocket(WS_URL);
  await new Promise((resolve, reject) => {
    ws.on('open', resolve);
    ws.on('error', reject);
  });

  console.log(`\n🧪 New Features Test — ${PLATFORM} (port ${PORT})\n`);

  // Initialize
  await send('initialize');

  // ==================== AUTH TOOLS ====================
  console.log('--- Auth Tools ---');

  await test('auth_otp: generate TOTP code', async () => {
    const result = await send('auth_otp', { secret: 'JBSWY3DPEHPK3PXP' });
    assert(result.code, 'Should return OTP code');
    assert(result.code.length === 6, `Code should be 6 digits, got: ${result.code}`);
    assert(result.valid_for_seconds > 0, 'Should have valid_for_seconds');
    console.log(`    Code: ${result.code}, valid for ${result.valid_for_seconds}s`);
  });

  await test('auth_inject_session: inject token', async () => {
    const result = await send('auth_inject_session', { 
      token: 'test-session-token-123',
      key: 'auth_token',
      storage_type: 'local_storage'
    });
    assert(result.success, 'Should succeed');
  });

  await test('auth_deeplink: open URL', async () => {
    if (PLATFORM === 'electron') throw new Error('SKIP: deeplink N/A for Electron');
    const result = await send('auth_deeplink', { url: 'https://example.com/callback?code=test123' });
    assert(result.success, 'Should succeed');
  });

  await test('auth_biometric: enroll', async () => {
    if (PLATFORM === 'electron') throw new Error('SKIP: biometric N/A for Electron');
    const result = await send('auth_biometric', { action: 'enroll' });
    assert(result.success, 'Should succeed');
  });

  await test('auth_biometric: match', async () => {
    if (PLATFORM === 'electron') throw new Error('SKIP: biometric N/A for Electron');
    const result = await send('auth_biometric', { action: 'match' });
    assert(result.success, 'Should succeed');
  });

  await test('auth_biometric: fail', async () => {
    if (PLATFORM === 'electron') throw new Error('SKIP: biometric N/A for Electron');
    const result = await send('auth_biometric', { action: 'fail' });
    assert(result.success, 'Should succeed');
  });

  // ==================== CODE GENERATION ====================
  console.log('\n--- Code Generation ---');

  await test('record_start: begin recording', async () => {
    const result = await send('record_start');
    assert(result.recording === true, 'Should be recording');
  });

  // Perform some actions to record
  await test('record: perform actions', async () => {
    await send('tap', { key: 'increment-btn' }).catch(() => {});
    await send('tap', { key: 'increment-btn' }).catch(() => {});
    await send('screenshot');
  });

  await test('record_stop: stop and get steps', async () => {
    const result = await send('record_stop');
    assert(result.steps, 'Should have steps array');
    assert(result.steps.length >= 2, `Should have at least 2 steps, got ${result.steps.length}`);
    assert(result.step_count > 0, 'Should have step_count');
    console.log(`    Recorded ${result.step_count} steps`);
  });

  await test('record_export: jest format', async () => {
    const result = await send('record_export', { format: 'jest' });
    assert(result.code, 'Should have generated code');
    assert(result.format === 'jest', 'Format should be jest');
    console.log(`    Generated ${result.code.length} chars of Jest code`);
  });

  await test('record_export: json format', async () => {
    const result = await send('record_export', { format: 'json' });
    assert(result.code, 'Should have JSON output');
  });

  await test('record_export: pytest format', async () => {
    const result = await send('record_export', { format: 'pytest' });
    assert(result.code, 'Should have Python code');
    assert(result.format === 'pytest', 'Format should be pytest');
  });

  // ==================== SMART SNAPSHOT ====================
  console.log('\n--- Smart Snapshot ---');

  await test('snapshot: text mode (default)', async () => {
    const result = await send('snapshot', { mode: 'text' });
    assert(result.snapshot, 'Should have snapshot text');
    assert(result.tokenEstimate, 'Should have token estimate');
    console.log(`    ${result.interactiveCount} elements, ~${result.tokenEstimate} tokens`);
  });

  await test('snapshot: vision mode', async () => {
    const result = await send('snapshot', { mode: 'vision' });
    assert(result.screenshot || result.image, 'Should have image data');
    const imgSize = (result.screenshot || result.image || '').length;
    console.log(`    Image: ${imgSize} chars`);
  });

  await test('snapshot: smart mode', async () => {
    const result = await send('snapshot', { mode: 'smart' });
    assert(result.snapshot, 'Should have snapshot text');
    assert('has_visual_content' in result, 'Should indicate visual content');
    console.log(`    Smart mode: ${result.interactiveCount} elements, visual=${result.has_visual_content}`);
  });

  await test('snapshot: token comparison', async () => {
    const text = await send('snapshot', { mode: 'text' });
    const vision = await send('snapshot', { mode: 'vision' });
    const textSize = text.snapshot?.length || 0;
    const visionSize = (vision.screenshot || vision.image || '').length;
    const savings = Math.round((1 - textSize / visionSize) * 100);
    console.log(`    Text: ${textSize} chars vs Vision: ${visionSize} chars (${savings}% savings)`);
    assert(savings > 80, `Should save >80% tokens, got ${savings}%`);
  });

  // ==================== VIDEO RECORDING ====================
  console.log('\n--- Video Recording ---');

  await test('video_start: begin recording', async () => {
    if (PLATFORM === 'electron') throw new Error('SKIP: video N/A for Electron');
    const result = await send('video_start', {});
    assert(result.recording === true, 'Should be recording');
  });

  await test('video_stop: stop recording', async () => {
    if (PLATFORM === 'electron') throw new Error('SKIP: video N/A for Electron');
    // Wait a bit for some frames
    await new Promise(r => setTimeout(r, 2000));
    const result = await send('video_stop');
    assert(result.success, 'Should succeed');
    console.log(`    Video saved to: ${result.path}`);
  });

  // ==================== SUMMARY ====================
  console.log(`\n${'='.repeat(50)}`);
  console.log(`Results: ${pass} passed, ${fail} failed, ${skip} skipped`);
  console.log(`Total: ${pass + fail + skip} tests`);
  console.log(`${'='.repeat(50)}\n`);

  ws.close();
  process.exit(fail > 0 ? 1 : 0);
}

run().catch(e => {
  console.error('Fatal:', e);
  process.exit(1);
});
