import 'package:flutter/material.dart';
import 'youtube_player_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Custom YouTube Player Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const YoutubeDemoScreen(),
    );
  }
}

class YoutubeDemoScreen extends StatelessWidget {
  const YoutubeDemoScreen({super.key});

  // Demo Video URL
  static const String videoUrl =
      'https://www.youtube.com/watch?v=hlWiI4xVXKY&list=RDhlWiI4xVXKY&start_radio=1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom YouTube Player'),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Video Player Card
            Card(
              elevation: 4,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: YoutubePlayerWidget(url: videoUrl),
            ),
          ],
        ),
      ),
    );
  }
}
