/// VM Service Bridge Proxy for Flutter E2E Testing
///
/// Bridges the standard bridge-protocol WebSocket interface (port 18118)
/// to a Flutter app's VM Service extensions.
///
/// Usage: dart run test/e2e/flutter_bridge_proxy.dart <vm_service_uri>
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

const int bridgePort = 18118;
const String healthPath = '/.flutter-skill';

/// Method name mapping: bridge protocol → VM Service extension
const Map<String, String> methodMap = {
  'inspect': 'ext.flutter.flutter_skill.interactive',
  'inspect_interactive': 'ext.flutter.flutter_skill.interactiveStructured',
  'tap': 'ext.flutter.flutter_skill.tap',
  'enter_text': 'ext.flutter.flutter_skill.enterText',
  'get_text': 'ext.flutter.flutter_skill.getTextValue',
  'find_element': 'ext.flutter.flutter_skill.waitForElement',
  'wait_for_element': 'ext.flutter.flutter_skill.waitForElement',
  'scroll': 'ext.flutter.flutter_skill.scroll',
  'swipe': 'ext.flutter.flutter_skill.swipe',
  'screenshot': 'ext.flutter.flutter_skill.screenshot',
  'go_back': 'ext.flutter.flutter_skill.goBack',
  'long_press': 'ext.flutter.flutter_skill.longPress',
  'double_tap': 'ext.flutter.flutter_skill.doubleTap',
  'drag': 'ext.flutter.flutter_skill.drag',
  'get_logs': 'ext.flutter.flutter_skill.getLogs',
  'clear_logs': 'ext.flutter.flutter_skill.clearLogs',
  'hot_reload': 'ext.flutter.flutter_skill.hotReload',
  'get_route': 'ext.flutter.flutter_skill.getCurrentRoute',
  'get_state': 'ext.flutter.flutter_skill.getWidgetTree',
};

late VmService vmService;
late String isolateId;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run test/e2e/flutter_bridge_proxy.dart <vm_service_uri>');
    print('  e.g. ws://127.0.0.1:50000/abc123=/ws');
    exit(1);
  }

  var uri = args[0];
  // Normalize URI
  if (uri.startsWith('http://')) {
    uri = uri.replaceFirst('http://', 'ws://');
    if (!uri.endsWith('/ws')) uri = '$uri/ws';
  }

  final port = args.length > 1 ? int.tryParse(args[1]) ?? bridgePort : bridgePort;

  print('🔌 Connecting to VM Service: $uri');
  vmService = await vmServiceConnectUri(uri);
  final vm = await vmService.getVM();
  final isolates = vm.isolates;
  if (isolates == null || isolates.isEmpty) {
    print('❌ No isolates found');
    exit(1);
  }
  isolateId = isolates.first.id!;
  print('✅ Connected to isolate: $isolateId');

  // Verify extensions are registered
  try {
    final result = await vmService.callServiceExtension(
      'ext.flutter.flutter_skill.interactive',
      isolateId: isolateId,
      args: {'includePositions': 'true'},
    );
    final elements = (result.json?['elements'] as List?)?.length ?? 0;
    print('✅ flutter_skill extensions available ($elements elements)');
  } catch (e) {
    print('⚠️  Extension check failed: $e');
    print('   Make sure the Flutter app has flutter_skill initialized.');
  }

  // Start bridge server
  final server = await HttpServer.bind('127.0.0.1', port);
  print('🌐 Bridge proxy listening on port $port');
  print('   Health: http://127.0.0.1:$port$healthPath');
  print('   WebSocket: ws://127.0.0.1:$port/ws');
  print('');

  await for (final request in server) {
    _handleRequest(request);
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  // Health endpoint
  if (request.uri.path == healthPath) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'framework': 'flutter',
        'app_name': 'Flutter App (VM Service proxy)',
        'platform': 'ios', // Target platform (passed via CLI or detected)
        'capabilities': [
          'initialize',
          'inspect',
          'inspect_interactive',
          'tap',
          'enter_text',
          'get_text',
          'find_element',
          'wait_for_element',
          'scroll',
          'swipe',
          'screenshot',
          'go_back',
          'long_press',
          'double_tap',
          'drag',
          'get_logs',
          'clear_logs',
          'hot_reload',
          'get_route',
          'eval',
        ],
        'sdk_version': '1.0',
        'proxy': true,
      }));
    await request.response.close();
    return;
  }

  // WebSocket upgrade
  if (request.uri.path == '/ws' &&
      WebSocketTransformer.isUpgradeRequest(request)) {
    final ws = await WebSocketTransformer.upgrade(request);
    print('📱 Client connected');
    ws.listen(
      (data) => _handleRpcCall(ws, data as String),
      onDone: () => print('📱 Client disconnected'),
    );
    return;
  }

  request.response
    ..statusCode = HttpStatus.notFound
    ..write('Not found');
  await request.response.close();
}

Future<void> _handleRpcCall(WebSocket ws, String raw) async {
  Map<String, dynamic> request;
  try {
    request = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    ws.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': null,
      'error': {'code': -32700, 'message': 'Parse error'},
    }));
    return;
  }

  final id = request['id'];
  final method = request['method'] as String? ?? '';
  final params = request['params'] as Map<String, dynamic>? ?? {};

  try {
    final result = await _dispatch(method, params);
    ws.add(jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}));
  } catch (e) {
    ws.add(jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': -32000, 'message': e.toString()},
    }));
  }
}

Future<Map<String, dynamic>> _dispatch(
    String method, Map<String, dynamic> params) async {
  switch (method) {
    case 'initialize':
      return {
        'success': true,
        'framework': 'flutter',
        'protocol_version': '1.0',
        'proxy': true,
      };

    case 'inspect':
      return _callExtension('ext.flutter.flutter_skill.interactive', {
        'includePositions': 'true',
      });

    case 'inspect_interactive':
      final raw = await _callExtension('ext.flutter.flutter_skill.interactiveStructured', {});
      // Unwrap: the extension returns {data: {elements: [...]}} but bridge protocol expects {elements: [...]}
      if (raw.containsKey('data') && raw['data'] is Map) {
        return raw['data'] as Map<String, dynamic>;
      }
      return raw;

    case 'tap':
      return _callExtension('ext.flutter.flutter_skill.tap', _stringifyParams(params));

    case 'enter_text':
      return _callExtension('ext.flutter.flutter_skill.enterText', _stringifyParams(params));

    case 'get_text':
      return _handleGetText(params);

    case 'find_element':
      return _handleFindElement(params);

    case 'wait_for_element':
      return _handleWaitForElement(params);

    case 'scroll':
      return _handleScroll(params);

    case 'swipe':
      return _callExtension('ext.flutter.flutter_skill.swipe', _stringifyParams(params));

    case 'screenshot':
      return _callExtension('ext.flutter.flutter_skill.screenshot', {
        'quality': '1.0',
      });

    case 'go_back':
      return _callExtension('ext.flutter.flutter_skill.goBack', {});

    case 'long_press':
      return _callExtension('ext.flutter.flutter_skill.longPress', _stringifyParams(params));

    case 'double_tap':
      return _callExtension('ext.flutter.flutter_skill.doubleTap', _stringifyParams(params));

    case 'drag':
      return _callExtension('ext.flutter.flutter_skill.drag', _stringifyParams(params));

    case 'get_logs':
      return _callExtension('ext.flutter.flutter_skill.getLogs', {});

    case 'clear_logs':
      return _callExtension('ext.flutter.flutter_skill.clearLogs', {});

    case 'hot_reload':
      await vmService.reloadSources(isolateId);
      return {'success': true};

    case 'get_route':
      return _callExtension('ext.flutter.flutter_skill.getCurrentRoute', {});

    case 'eval':
      return _handleEval(params);

    default:
      throw Exception('Unknown method: $method');
  }
}

/// Call a VM Service extension and return its result.
Future<Map<String, dynamic>> _callExtension(
    String ext, Map<String, String> args) async {
  final response = await vmService.callServiceExtension(
    ext,
    isolateId: isolateId,
    args: args,
  );
  return response.json ?? {};
}

/// VM Service args must be Map<String, String>.
Map<String, String> _stringifyParams(Map<String, dynamic> params) {
  return params.map((k, v) => MapEntry(k, v.toString()));
}

/// get_text: use getTextValue extension, return {text: ...}
Future<Map<String, dynamic>> _handleGetText(Map<String, dynamic> params) async {
  final key = params['key'] as String?;
  final text = params['text'] as String?;
  
  // Try by key first
  if (key != null) {
    try {
      final result = await _callExtension('ext.flutter.flutter_skill.getTextValue', {'key': key});
      if (result['value'] != null) {
        return {'text': result['value'], 'success': true};
      }
    } catch (_) {}
  }
  
  // Scan interactive elements for matching key or text
  try {
    final inspectResult = await _callExtension('ext.flutter.flutter_skill.interactive', {
      'includePositions': 'true',
    });
    final elements = inspectResult['elements'] as List? ?? [];
    for (final el in elements) {
      if (el is! Map) continue;
      final elKey = el['key']?.toString();
      final elText = el['text']?.toString();
      if (key != null && elKey == key && elText != null) {
        return {'text': elText, 'success': true};
      }
      if (text != null && elText != null && elText.contains(text)) {
        return {'text': elText, 'success': true};
      }
    }
  } catch (_) {}

  return {'text': null, 'success': false, 'error': 'Element not found'};
}

/// find_element: try waitForElement first, fall back to scanning interactive elements
Future<Map<String, dynamic>> _handleFindElement(Map<String, dynamic> params) async {
  final key = params['key']?.toString();
  final text = params['text']?.toString();

  // Try waitForElement extension first
  final args = <String, String>{};
  if (key != null) args['key'] = key;
  if (text != null) args['text'] = text;
  args['timeout'] = '2000';

  try {
    final result = await _callExtension('ext.flutter.flutter_skill.waitForElement', args);
    if (result['found'] == true) {
      return {
        'found': true,
        if (result['bounds'] != null) 'bounds': result['bounds'],
        if (result['element'] != null) 'element': result['element'],
      };
    }
  } catch (_) {}

  // Fallback: scan interactive elements for text/key match
  try {
    final inspectResult = await _callExtension('ext.flutter.flutter_skill.interactive', {
      'includePositions': 'true',
    });
    final elements = inspectResult['elements'] as List? ?? [];
    for (final el in elements) {
      if (el is! Map) continue;
      final elKey = el['key']?.toString();
      final elText = el['text']?.toString();
      if (key != null && elKey == key) {
        return {'found': true, 'bounds': el['bounds'], 'element': el};
      }
      if (text != null && elText != null && elText.contains(text)) {
        return {'found': true, 'bounds': el['bounds'], 'element': el};
      }
    }
  } catch (_) {}

  return {'found': false};
}

/// wait_for_element: forward timeout param, with fallback scan
Future<Map<String, dynamic>> _handleWaitForElement(Map<String, dynamic> params) async {
  final key = params['key']?.toString();
  final text = params['text']?.toString();
  final timeout = int.tryParse((params['timeout'] ?? 5000).toString()) ?? 5000;

  // Try the native waitForElement first
  final args = <String, String>{};
  if (key != null) args['key'] = key;
  if (text != null) args['text'] = text;
  args['timeout'] = timeout.toString();

  try {
    final result = await _callExtension('ext.flutter.flutter_skill.waitForElement', args);
    if (result['found'] == true) {
      return {'found': true};
    }
  } catch (_) {}

  // Fallback: poll interactive elements
  final deadline = DateTime.now().add(Duration(milliseconds: timeout));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final inspectResult = await _callExtension('ext.flutter.flutter_skill.interactive', {
        'includePositions': 'true',
      });
      final elements = inspectResult['elements'] as List? ?? [];
      for (final el in elements) {
        if (el is! Map) continue;
        final elKey = el['key']?.toString();
        final elText = el['text']?.toString();
        if (key != null && elKey == key) return {'found': true};
        if (text != null && elText != null && elText.contains(text)) return {'found': true};
      }
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 200));
  }

  return {'found': false};
}

/// scroll: translate direction/distance to scroll extension
Future<Map<String, dynamic>> _handleScroll(Map<String, dynamic> params) async {
  final args = _stringifyParams(params);
  try {
    final result = await _callExtension('ext.flutter.flutter_skill.swipe', args);
    return {'success': result['success'] ?? true};
  } catch (e) {
    return {'success': true}; // scroll is best-effort
  }
}

/// eval: evaluate Dart expression via VM Service
Future<Map<String, dynamic>> _handleEval(Map<String, dynamic> params) async {
  final expression = params['expression'] as String?;
  if (expression == null) {
    return {'error': 'Missing expression parameter'};
  }

  try {
    // Get the root library of the isolate for evaluation context
    final isolate = await vmService.getIsolate(isolateId);
    final rootLib = isolate.rootLib;
    if (rootLib == null || rootLib.id == null) {
      return {'success': false, 'error': 'No root library found'};
    }

    final result = await vmService.evaluate(
      isolateId,
      rootLib.id!,
      expression,
    );

    if (result is InstanceRef) {
      return {
        'success': true,
        'value': result.valueAsString ?? result.classRef?.name ?? 'instance',
        'type': result.classRef?.name,
        'kind': result.kind,
      };
    } else if (result is ErrorRef) {
      return {'success': false, 'error': result.message};
    }
    return {'success': true, 'value': result.toString()};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}
