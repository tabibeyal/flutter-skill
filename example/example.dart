/// Flutter Skill - Give your AI Agent eyes and hands inside your Flutter app.
///
/// This example shows how to integrate flutter_skill into your Flutter app.
/// Once integrated, AI agents can inspect, tap, scroll, enter text,
/// and take screenshots of your running app via the MCP protocol.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_skill/flutter_skill.dart';

void main() {
  // Initialize FlutterSkill only in debug mode.
  // This ensures it's stripped from release builds.
  if (kDebugMode) {
    FlutterSkillBinding.ensureInitialized();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Skill Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Use Key widgets so AI agents can find and interact with them
              ElevatedButton(
                key: const Key('my_button'),
                onPressed: () {},
                child: const Text('Tap Me'),
              ),
              const SizedBox(height: 20),
              const TextField(
                key: Key('my_input'),
                decoration: InputDecoration(
                  labelText: 'Enter text here',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
