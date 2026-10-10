import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transkrip'), backgroundColor: HexColor('#3C37AF'), foregroundColor: Colors.white),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.subtitles, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text('Halaman Setting', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('Fitur setting akan segera hadir', style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
