import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:swarana/common/utils/shared_code.dart';

class TranskripResult extends StatefulWidget {
  final String title;
  final String content;
  const TranskripResult({super.key, required this.title, required this.content});

  @override
  State<TranskripResult> createState() => _TranskripResultState();
}

class _TranskripResultState extends State<TranskripResult> {
  double _currentFontSize = 15.0;
  final double _initialFontSize = 15.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton.outlined(
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      side: BorderSide(color: HexColor('#E0E2E5')),
                      backgroundColor: Colors.grey[200],
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.black87,
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const Expanded(
                    child: Center(child: Text("Transkrip", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 25),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 15),
                      Text(SharedCode.formatWaktu(DateTime.now())),
                      const SizedBox(height: 25),
                      Text(
                        widget.content,
                        style: TextStyle(
                          fontSize: _currentFontSize,
                          // height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildFontSizeControl(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFontSizeControl() {
    return Column(
      children: [
        Row(
          children: [
            const Text("Aa", style: TextStyle(fontSize: 12)),
            Expanded(
              child: Slider(
                value: _currentFontSize,
                min: 12.0,
                max: 24.0,
                activeColor: HexColor('#3C37AF'),
                inactiveColor: HexColor('#E0E6FA'),
                onChanged: (newValue) {
                  setState(() {
                    _currentFontSize = newValue;
                  });
                },
              ),
            ),
            const Text("Aa", style: TextStyle(fontSize: 20)),
          ],
        ),
      ],
    );
  }
}
