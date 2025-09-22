import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:swarana/features/transkrip/presentation/pages/transkrip_result.dart';

class TranskripPage extends StatefulWidget {
  const TranskripPage({super.key});

  @override
  State<TranskripPage> createState() => _TranskripPageState();
}

class _TranskripPageState extends State<TranskripPage> {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _recognizedWords = "";
  final _filenameController = TextEditingController();
  bool _isDialogShowing = false;

  final String _initialText =
      "Tekan untuk mulai rekam suara dari video atau berita. Kami akan ubah jadi teks secara otomatis 📄";

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _filenameController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          setState(() {
            _isListening = false;
          });
          if (_recognizedWords.isNotEmpty && !_isDialogShowing) {
            _isDialogShowing = true;
            _showSaveDialog();
          }
        }
      },
      onError: (errorNotification) {
        print('Error: $errorNotification');
        setState(() {
          _isListening = false;
        });
      },
    );
    setState(() {});
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Center(
                child: Text("Simpan Hasil Transkrip", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              content: TextField(
                controller: _filenameController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Masukkan nama file transkrip...",
                  border: OutlineInputBorder(),
                  hintStyle: TextStyle(fontSize: 12),
                ),
                onChanged: (text) {
                  setStateDialog(() {});
                },
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: <Widget>[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Buang"),
                  onPressed: () {
                    _filenameController.clear();
                    Navigator.of(context).pop();
                    _isDialogShowing = false;
                  },
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HexColor('#49439D'),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed:
                      _filenameController.text.trim().isNotEmpty
                          ? () {
                            final filename = _filenameController.text;
                            final content = _recognizedWords;
                            print("Simpan file '$filename' dengan isi: '$content'");
                            _filenameController.clear();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TranskripResult(title: filename, content: content)),
                            );
                            _isDialogShowing = false;
                          }
                          : null,
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startListening() async {
    _isDialogShowing = false;
    setState(() {
      _recognizedWords = "";
    });
    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'id_ID',
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(listenMode: ListenMode.dictation),
    );
    setState(() {
      _isListening = true;
    });
  }

  void _stopListening() async {
    await _speechToText.stop();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _recognizedWords = result.recognizedWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              const Center(child: Text("Transkrip", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
              const SizedBox(height: 30),
              _buildMainTextField(),
              const Expanded(child: SizedBox.shrink()),
              _buildMicButton(),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainTextField() {
    if (_isListening) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mendengarkan ...", style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            _recognizedWords.isEmpty ? "..." : _recognizedWords,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
        ],
      );
    } else if (!_isListening && _recognizedWords.isNotEmpty) {
      return Text(
        _recognizedWords,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        textAlign: TextAlign.left,
      );
    } else {
      return Text(
        _initialText,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        textAlign: TextAlign.left,
      );
    }
  }

  Widget _buildMicButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            if (!_speechEnabled) {
              print("Speech recognition not available");
              return;
            }
            _isListening ? _stopListening() : _startListening();
          },
          customBorder: const CircleBorder(),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(color: HexColor('#3C37AF'), shape: BoxShape.circle),
            child: Center(
              child: Icon(_isListening ? Icons.stop_rounded : IconsaxPlusBold.microphone_2, color: Colors.white, size: 60),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Text(
          _isListening ? "Tekan untuk berhenti rekam" : "Tekan untuk mulai rekam",
          style: TextStyle(color: HexColor('#3C37AF'), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
