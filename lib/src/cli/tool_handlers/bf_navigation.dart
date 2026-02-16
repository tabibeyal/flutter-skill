part of '../server.dart';

extension _BfNavigation on FlutterMcpServer {
  Future<dynamic> _handleNavigationTool(String name, Map<String, dynamic> args, AppDriver? client) async {
    switch (name) {
      case 'get_current_route':
        if (client is BridgeDriver) {
          final route = await client.getRoute();
          return {"route": route};
        }
        final fc = _asFlutterClient(client!, 'get_current_route');
        return await fc.getCurrentRoute();
      case 'go_back':
        if (client is BridgeDriver) {
          final success = await client.goBack();
          return success ? "Navigated back" : "Cannot go back";
        }
        final fc = _asFlutterClient(client!, 'go_back');
        final success = await fc.goBack();
        return success ? "Navigated back" : "Cannot go back";
      case 'get_navigation_stack':
        if (client is BridgeDriver) {
          return await client.callMethod('get_navigation_stack');
        }
        final fc = _asFlutterClient(client!, 'get_navigation_stack');
        return await fc.getNavigationStack();

      // Debug & Logs
      default:
        return null;
    }
  }
}
