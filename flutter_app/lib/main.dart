import 'package:flutter/material.dart';

void main() {
  runApp(const TaskwarriorFrontendApp());
}

class TaskwarriorFrontendApp extends StatelessWidget {
  const TaskwarriorFrontendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taskwarrior Frontend',
      home: Scaffold(
        appBar: AppBar(title: const Text('Taskwarrior Frontend')),
        body: const Center(child: Text('Compatibility spike scaffold')),
      ),
    );
  }
}
