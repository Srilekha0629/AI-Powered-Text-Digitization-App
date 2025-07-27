import 'package:flutter/material.dart';
import 'main.dart';

class EMRScreen extends StatelessWidget {
  const EMRScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Records'),
        backgroundColor: Colors.deepPurple.shade100,
        foregroundColor: Colors.deepPurple,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EMRRecordsPage()),
            );
          },
        ),
      ),
      body: const Center(
        child: Text('EMR Records Page Content', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}