import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:swarana/variants/v3_board/features/transkrip/presentation/pages/transkrip_result.dart';

import '../../../../core/services/speech_service.dart';

class TranskripPage extends StatefulWidget {
  const TranskripPage({super.key});

  @override
  State<TranskripPage> createState() => _TranskripPageState();
}

class _TranskripPageState extends State<TranskripPage> {
  // 1. HAPUS INSTANCE LOKAL, GUNAKAN SERVICE SINGLETON
  final SpeechService _speechService = SpeechService();
  final _filenameController = TextEditingController();

  // 2. TAMBAHKAN FLAG UNTUK MENANDAI REKAMAN DARI HALAMAN INI
  // Ini penting agar dialog simpan hanya muncul jika rekaman dimulai dari sini.
  bool _isThisPageListening = false;

  final String _initialText =
      "Tekan untuk mulai rekam suara dari video atau berita. Kami akan ubah jadi teks secara otomatis 📄";

  @override
  void initState() {
    super.initState();
    // Inisialisasi service saat halaman pertama kali dibuka
    _speechService.initialize();

    // 3. DENGARKAN PERUBAHAN STATUS DARI SERVICE
    _speechService.statusNotifier.addListener(_onSpeechStatusChanged);
  }

  @override
  void dispose() {
    // 4. HAPUS LISTENER DI DISPOSE UNTUK MENCEGAH MEMORY LEAK
    _speechService.statusNotifier.removeListener(_onSpeechStatusChanged);
    _filenameController.dispose();
    super.dispose();
  }

  void _onSpeechStatusChanged() {
    final status = _speechService.statusNotifier.value;
    final recognizedText = _speechService.recognizedTextNotifier.value;

    // Cek apakah rekaman selesai DAN rekaman tersebut dimulai dari halaman ini
    if ((status == 'notListening' || status == 'done') && _isThisPageListening) {
      // Set flag kembali ke false
      _isThisPageListening = false;

      // Tampilkan dialog jika ada teks yang berhasil direkam
      if (recognizedText.isNotEmpty) {
        _showSaveDialog(recognizedText);
      }
    }
  }

  void _showSaveDialog(String content) {
    // Pastikan dialog tidak muncul ganda
    if (ModalRoute.of(context)?.isCurrent != true) {
      // Jika ada dialog/route lain di atasnya, jangan tampilkan
      return;
    }

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
                            final filename = _filenameController.text.trim();

                            // Ambil nama dan konten dari controller dan argumen
                            print("Simpan file '$filename' dengan isi: '$content'");

                            // Tutup dialog dulu SEBELUM navigasi
                            Navigator.of(context).pop();

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                settings: const RouteSettings(name: '/v3/transkrip/result'),
                                builder: (context) => TranskripResult(title: filename, content: content),
                              ),
                            );
                            _filenameController.clear();
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

  // 5. METODE START/STOP SEKARANG MEMANGGIL SERVICE
  void _startListening() {
    // Tandai bahwa rekaman dimulai dari halaman ini
    _isThisPageListening = true;
    _speechService.startListening(
      // Atur durasi sesuai kebutuhan halaman transkrip
      timeout: const Duration(minutes: 5),
    );
  }

  void _stopListening() {
    _speechService.stopListening();
    // Flag _isThisPageListening akan direset oleh _onSpeechStatusChanged
  }

  @override
  Widget build(BuildContext context) {
    // 6. GUNAKAN VALUELISTENABLEBUILDER UNTUK UI YANG REAKTIF
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: ValueListenableBuilder<bool>(
            valueListenable: _speechService.isListeningNotifier,
            builder: (context, isListening, child) {
              return ValueListenableBuilder<String>(
                valueListenable: _speechService.recognizedTextNotifier,
                builder: (context, recognizedWords, child) {
                  return Column(
                    children: [
                      const Center(child: Text("Transkrip", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 30),
                      _buildMainTextField(isListening, recognizedWords),
                      const Expanded(child: SizedBox.shrink()),
                      _buildMicButton(isListening),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMainTextField(bool isListening, String recognizedWords) {
    // Tampilkan teks yang sedang direkam hanya jika rekaman dimulai dari halaman ini
    final bool shouldShowLiveText = isListening && _isThisPageListening;

    if (shouldShowLiveText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mendengarkan ...", style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 10),
          Text(
            recognizedWords.isEmpty ? "..." : recognizedWords,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
          ),
        ],
      );
    }
    // Jika tidak sedang merekam TAPI ada hasil rekaman dari halaman ini
    else if (!isListening && recognizedWords.isNotEmpty && !_isThisPageListening) {
      return Text(
        recognizedWords,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        textAlign: TextAlign.left,
      );
    }
    // Kondisi Awal
    else {
      return Text(
        _initialText,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        textAlign: TextAlign.left,
      );
    }
  }

  Widget _buildMicButton(bool isListening) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          // Nonaktifkan tombol jika sedang merekam tapi bukan dari halaman ini
          onTap:
              (isListening && !_isThisPageListening)
                  ? null
                  : () {
                    isListening ? _stopListening() : _startListening();
                  },
          customBorder: const CircleBorder(),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              // Ubah warna jadi abu-abu jika dinonaktifkan
              color: (isListening && !_isThisPageListening) ? Colors.grey : HexColor('#3C37AF'),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(isListening ? Icons.stop_rounded : IconsaxPlusBold.microphone_2, color: Colors.white, size: 60),
            ),
          ),
        ),
        const SizedBox(height: 25),
        Text(
          isListening ? "Tekan untuk berhenti rekam" : "Tekan untuk mulai rekam",
          style: TextStyle(color: HexColor('#3C37AF'), fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
