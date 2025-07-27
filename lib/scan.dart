import 'package:flutter/material.dart';
import 'main.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
        backgroundColor: Colors.deepPurple.shade100,
        foregroundColor: Colors.deepPurple,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScannerPage()),
            );
          },
        ),
      ),
      body: const Center(
        child: Text('Scan Page Content', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}