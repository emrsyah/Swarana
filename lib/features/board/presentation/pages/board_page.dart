import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../../../common/constant/assets.dart';
import '../../../../core/services/board_input_focus_service.dart';
import '../../../../core/services/volume_alert_service.dart';
import '../../domain/entities/word_item.dart';
import '../widgets/word_board.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  late final FlutterTts _flutterTts;
  late final VoidCallback _focusRequestListener;
  int _currentTemplateIndex = 0;

  // Template data - organized for easy extension
  final List<TemplateData> _templates = [
    // Umum Template
    TemplateData(
      type: TemplateType.umum,
      words: const [
        WordItem(text: 'Halo', iconPath: ImageAssets.halo, description: 'Greeting'),
        WordItem(text: 'Ya', iconPath: ImageAssets.ya, description: 'Yes'),
        WordItem(text: 'Tidak', iconPath: ImageAssets.tidak, description: 'No'),
        WordItem(text: 'Tolong', iconPath: ImageAssets.tolong, description: 'Please help'),
        WordItem(text: 'Terima kasih', iconPath: ImageAssets.terimaKasih, description: 'Thank you'),
        WordItem(text: 'Maaf', iconPath: ImageAssets.maaf, description: 'Sorry'),
        WordItem(text: 'Sebentar', iconPath: ImageAssets.sebentar, description: 'Wait a moment'),
        WordItem(text: 'Permisi', iconPath: ImageAssets.permisi, description: 'Excuse me'),
        WordItem(text: 'Saya paham', iconPath: ImageAssets.sayaPaham, description: 'I understand'),
        WordItem(text: 'Tidak paham', iconPath: ImageAssets.tidakPaham, description: 'Don\'t understand'),
        WordItem(text: 'Saya setuju', iconPath: ImageAssets.sayaSetuju, description: 'I agree'),
        WordItem(text: 'Tolong ulangi', iconPath: ImageAssets.tolongUlangi, description: 'Please repeat'),
      ],
      sentences: const [
        SentenceItem(text: 'Permisi, saya butuh bantuan', description: 'Asking for help politely'),
        SentenceItem(text: 'Apakah anda bisa bahasa isyarat?', description: 'Asking about sign language'),
        SentenceItem(text: 'Saya tidak mengerti', description: 'Expressing lack of understanding'),
        SentenceItem(
          text: 'Tolong ucapkan kalimat dengan pelan dan jelas',
          description: 'Asking to speak slowly and clearly',
        ),
        SentenceItem(text: 'Boleh saya bertanya sesuatu?', description: 'Asking permission to ask a question'),
        SentenceItem(text: 'Terima kasih atas bantuannya', description: 'Thanking for help'),
      ],
    ),

    // Rumah Sakit Template
    TemplateData(
      type: TemplateType.rumahSakit,
      words: const [
        WordItem(text: 'Janji Temu', iconPath: ImageAssets.janjiTemu, description: 'Appointment'),
        WordItem(text: 'Hasil Periksa', iconPath: ImageAssets.hasilPeriksa, description: 'Examination Results'),
        WordItem(text: 'Obat & Resep', iconPath: ImageAssets.obatResep, description: 'Medicine & Prescription'),
        WordItem(text: 'Ruang Tunggu', iconPath: ImageAssets.ruangTunggu, description: 'Waiting Room'),
        WordItem(text: 'Asuransi', iconPath: ImageAssets.asuransi, description: 'Insurance'),
        WordItem(text: 'Panggil Dokter', iconPath: ImageAssets.panggilDokter, description: 'Call a Doctor'),
        WordItem(text: 'Panggil Perawat', iconPath: ImageAssets.panggilPerawat, description: 'Call a Nurse'),
        WordItem(text: 'Ruang Periksa', iconPath: ImageAssets.ruangPeriksa, description: 'Examination Room'),
        WordItem(text: 'Sakit Kepala', iconPath: ImageAssets.sakitKepala, description: 'Headache'),
        WordItem(text: 'Saya Mual', iconPath: ImageAssets.sayaMual, description: 'I Feel Nauseous'),
        WordItem(text: 'Sakit Perut', iconPath: ImageAssets.sakitPerut, description: 'Stomachache'),
        WordItem(text: 'Letih Lesu', iconPath: ImageAssets.letihLesu, description: 'Tired / Fatigued'),
      ],
      sentences: const [
        SentenceItem(text: 'Saya mau periksa hari ini', description: 'I want a check-up today'),
        SentenceItem(text: 'Saya harus ke ruangan mana?', description: 'Which room should I go to?'),
        SentenceItem(text: 'Saya mau periksa ke dokter umum', description: 'I want to see a general practitioner'),
        SentenceItem(text: 'Saya merasa tidak enak badan', description: 'I\'m not feeling well'),
        SentenceItem(text: 'Apakah saya perlu antri?', description: 'Do I need to queue?'),
        SentenceItem(text: 'Siapa dokter yang akan memeriksa saya?', description: 'Who is the doctor that will examine me?'),
      ],
    ),

    // Restoran/Cafe Template
    TemplateData(
      type: TemplateType.restoran,
      words: const [
        WordItem(text: 'Pesan Makan', iconPath: ImageAssets.pesanMakan, description: 'Order Food'),
        WordItem(text: 'Daftar Menu', iconPath: ImageAssets.daftarMenu, description: 'Menu List'),
        WordItem(text: 'Meja Tersedia', iconPath: ImageAssets.mejaTersedia, description: 'Table Available'),
        WordItem(text: 'Makan di Tempat', iconPath: ImageAssets.makanDiTempat, description: 'Dine In'),
        WordItem(text: 'Bawa Pulang', iconPath: ImageAssets.bawaPulang, description: 'Take Away'),
        WordItem(text: 'Bayar Tunai', iconPath: ImageAssets.bayarTunai, description: 'Pay with Cash'),
        WordItem(text: 'Bayar QRIS', iconPath: ImageAssets.bayarQRIS, description: 'Pay with QRIS'),
        WordItem(text: 'Nasi Putih', iconPath: ImageAssets.nasiPutih, description: 'White Rice'),
        WordItem(text: 'Es Teh', iconPath: ImageAssets.esTeh, description: 'Iced Tea'),
        WordItem(text: 'Kopi', iconPath: ImageAssets.kopi, description: 'Coffee'),
        WordItem(text: 'Air Putih', iconPath: ImageAssets.airPutih, description: 'Plain Water'),
        WordItem(text: 'Kasir', iconPath: ImageAssets.kasir, description: 'Cashier'),
      ],
      sentences: const [
        SentenceItem(text: 'Saya mau pesan makanan', description: 'I want to order food'),
        SentenceItem(text: 'Saya mau pesan minuman', description: 'I want to order a drink'),
        SentenceItem(text: 'Ada tempat duduk kosong?', description: 'Are there any available seats?'),
        SentenceItem(text: 'Boleh minta rekomendasi makanan?', description: 'Can I have a food recommendation?'),
        SentenceItem(text: 'Berapa lama saya harus menunggu?', description: 'How long do I have to wait?'),
        SentenceItem(text: 'Langsung bayar atau nanti saja?', description: 'Pay now or later?'),
      ],
    ),

    // Tempat Belanja Template
    TemplateData(
      type: TemplateType.tempatBelanja,
      words: const [
        WordItem(text: 'Harga Promo', iconPath: ImageAssets.hargaPromo, description: 'Promo Price'),
        WordItem(text: 'Coba Dulu', iconPath: ImageAssets.cobaDulu, description: 'Try First'),
        WordItem(text: 'Stok Barang', iconPath: ImageAssets.stokBarang, description: 'Stock of Goods'),
        WordItem(text: 'Ukuran Lain', iconPath: ImageAssets.ukuranLain, description: 'Other Sizes'),
        WordItem(text: 'Pilihan Varian', iconPath: ImageAssets.pilihVarian, description: 'Variant Options'),
        WordItem(text: 'Tambah item', iconPath: ImageAssets.tambahItem, description: 'Add Item'),
        WordItem(text: 'Tukar Barang', iconPath: ImageAssets.tukarBarang, description: 'Exchange Item'),
        WordItem(text: 'Diskon Khusus', iconPath: ImageAssets.diskonKhusus, description: 'Special Discount'),
        WordItem(text: 'Cek Harga', iconPath: ImageAssets.cekHarga, description: 'Check Price'),
        WordItem(text: 'Punya Member', iconPath: ImageAssets.punyaMember, description: 'Have a Membership'),
        WordItem(text: 'Total Bayar', iconPath: ImageAssets.totalBayar, description: 'Total Payment'),
        WordItem(text: 'Cara Bayar', iconPath: ImageAssets.caraBayar, description: 'Payment Method'),
      ],
      sentences: const [
        SentenceItem(text: 'Saya mau lihat-lihat dulu', description: 'I want to look around first'),
        SentenceItem(text: 'Boleh minta yang baru?', description: 'Can I have a new one?'),
        SentenceItem(text: 'Bisa ditukar kalau nggak cocok?', description: 'Can I exchange it if it doesn\'t fit?'),
        SentenceItem(text: 'Saya ambil yang ini', description: 'I\'ll take this one'),
        SentenceItem(text: 'Letak kasir di mana, ya?', description: 'Where is the cashier?'),
        SentenceItem(text: 'Bisa bayar pakai QRIS?', description: 'Can I pay using QRIS?'),
      ],
    ),

    // Layanan Publik Template
    TemplateData(
      type: TemplateType.layananPublik,
      words: const [
        WordItem(text: 'Ambil Antrean', iconPath: ImageAssets.ambilAntrean, description: 'Take a Queue Number'),
        WordItem(text: 'Cetak Tiket', iconPath: ImageAssets.cetakTiket, description: 'Print Ticket'),
        WordItem(text: 'Bawa Berkas', iconPath: ImageAssets.bawaBerkas, description: 'Bring Documents'),
        WordItem(text: 'Temui Petugas', iconPath: ImageAssets.temuiPetugas, description: 'Meet the Officer'),
        WordItem(text: 'Isi Formulir', iconPath: ImageAssets.isiFormulir, description: 'Fill the Form'),
        WordItem(text: 'Periksa Data', iconPath: ImageAssets.periksaData, description: 'Check Data'),
        WordItem(text: 'Cek Syarat', iconPath: ImageAssets.cekSyarat, description: 'Check Requirements'),
        WordItem(text: 'Ambil Berkas', iconPath: ImageAssets.ambilBerkas, description: 'Take Documents'),
        WordItem(text: 'Jam Operasi', iconPath: ImageAssets.jamOperasi, description: 'Operating Hours'),
        WordItem(text: 'Tanya Layanan', iconPath: ImageAssets.tanyaLayanan, description: 'Inquire about Services'),
        WordItem(text: 'Ubah Data', iconPath: ImageAssets.ubahData, description: 'Change Data'),
        WordItem(text: 'Periksa Status', iconPath: ImageAssets.periksaStatus, description: 'Check Status'),
      ],
      sentences: const [
        SentenceItem(text: 'Saya mau ubah data pribadi', description: 'I want to change my personal data'),
        SentenceItem(text: 'Saya ingin ambil hasil dokumen', description: 'I want to pick up the document results'),
        SentenceItem(text: 'Bagaimana alur pelayanannya?', description: 'What is the service flow?'),
        SentenceItem(text: 'Bagaimana prosedurnya?', description: 'What is the procedure?'),
        SentenceItem(text: 'Saya perlu info dokumen', description: 'I need information about the document'),
        SentenceItem(text: 'Saya ingin ajukan keluhan', description: 'I want to file a complaint'),
      ],
    ),

    // Sekolah/Kampus Template
    TemplateData(
      type: TemplateType.sekolahKampus,
      words: const [
        WordItem(text: 'Kelas', iconPath: ImageAssets.kelas, description: 'Class'),
        WordItem(text: 'Jadwal', iconPath: ImageAssets.jadwal, description: 'Schedule'),
        WordItem(text: 'Izin Keluar', iconPath: ImageAssets.izinKeluar, description: 'Permit to Leave'),
        WordItem(text: 'Mahasiswa', iconPath: ImageAssets.mahasiswa, description: 'University Student'),
        WordItem(text: 'Ruangan', iconPath: ImageAssets.ruangan, description: 'Room'),
        WordItem(text: 'Dosen', iconPath: ImageAssets.dosen, description: 'Lecturer'),
        WordItem(text: 'Guru', iconPath: ImageAssets.guru, description: 'Teacher'),
        WordItem(text: 'Mata Kuliah', iconPath: ImageAssets.mataKuliah, description: 'Course / Subject'),
        WordItem(text: 'Tugas', iconPath: ImageAssets.tugas, description: 'Assignment'),
        WordItem(text: 'Kelompok', iconPath: ImageAssets.kelompok, description: 'Group'),
        WordItem(text: 'Materi', iconPath: ImageAssets.materi, description: 'Material / Subject Matter'),
        WordItem(text: 'Nilai', iconPath: ImageAssets.nilai, description: 'Grade / Score'),
      ],
      sentences: const [
        SentenceItem(text: 'Saya mau masuk kelas', description: 'I want to enter the class'),
        SentenceItem(text: 'Kelas dimulai pukul berapa?', description: 'What time does the class start?'),
        SentenceItem(text: 'Saya mau mengumpulkan tugas', description: 'I want to submit the assignment'),
        SentenceItem(text: 'Apa kamu punya catatan mata pelajaran ini?', description: 'Do you have notes for this subject?'),
        SentenceItem(text: 'Saya butuh tandatangan dosen/guru', description: 'I need the lecturer\'s/teacher\'s signature'),
        SentenceItem(text: 'Tolong kirim materinya', description: 'Please send the material'),
      ],
    ),

    // Tempat Wisata Template
    TemplateData(
      type: TemplateType.tempatWisata,
      words: const [
        WordItem(text: 'Harga Tiket', iconPath: ImageAssets.hargaTiket, description: 'Ticket Price'),
        WordItem(text: 'Loket', iconPath: ImageAssets.loket, description: 'Ticket Counter'),
        WordItem(text: 'Jam Buka', iconPath: ImageAssets.jamBuka, description: 'Opening Hours'),
        WordItem(text: 'Tour Guide', iconPath: ImageAssets.tourGuide, description: 'Tour Guide'),
        WordItem(text: 'Area Foto', iconPath: ImageAssets.areaFoto, description: 'Photo Area'),
        WordItem(text: 'Toilet Umum', iconPath: ImageAssets.toiletUmum, description: 'Public Toilet'),
        WordItem(text: 'Arah', iconPath: ImageAssets.arah, description: 'Direction'),
        WordItem(text: 'Main', iconPath: ImageAssets.main, description: 'Play / Main Attraction'),
        WordItem(text: 'Denah', iconPath: ImageAssets.denah, description: 'Map / Floor Plan'),
        WordItem(text: 'Antre', iconPath: ImageAssets.antre, description: 'Queue'),
        WordItem(text: 'Tersesat', iconPath: ImageAssets.tersesat, description: 'Lost'),
        WordItem(text: 'Parkir', iconPath: ImageAssets.parkir, description: 'Parking'),
      ],
      sentences: const [
        SentenceItem(text: 'Loket ada di mana?', description: 'Where is the ticket counter?'),
        SentenceItem(text: 'Berapa harga tiket masuknya?', description: 'How much is the entrance ticket?'),
        SentenceItem(text: 'Tolong bantu saya mencari petugas', description: 'Please help me find an officer/staff'),
        SentenceItem(text: 'Saya butuh denah', description: 'I need a map'),
        SentenceItem(text: 'Di mana tempat makan?', description: 'Where is the dining area?'),
        SentenceItem(text: 'Tolong kirim materinya', description: 'Please send the material'),
      ],
    ),

    // Transportasi Umum Template
    TemplateData(
      type: TemplateType.transportasiUmum,
      words: const [
        WordItem(text: 'Cek Jadwal', iconPath: ImageAssets.cekJadwal, description: 'Check Schedule'),
        WordItem(text: 'Cari Rute', iconPath: ImageAssets.cariRute, description: 'Find Route'),
        WordItem(text: 'Turun di Sini', iconPath: ImageAssets.turunDiSini, description: 'Get off Here'),
        WordItem(text: 'Ganti Jalur', iconPath: ImageAssets.gantiJalur, description: 'Change Route/Line'),
        WordItem(text: 'Transit Dulu', iconPath: ImageAssets.transitDulu, description: 'Transit First'),
        WordItem(text: 'Lihat Tarif', iconPath: ImageAssets.lihatTarif, description: 'See the Fare'),
        WordItem(text: 'Pilih Kursi', iconPath: ImageAssets.pilihKursi, description: 'Choose a Seat'),
        WordItem(text: 'Naik', iconPath: ImageAssets.naik, description: 'Get On / Board'),
        WordItem(text: 'Sampai Tujuan', iconPath: ImageAssets.sampaiTujuan, description: 'Arrive at Destination'),
        WordItem(text: 'Waktu Tempuh', iconPath: ImageAssets.waktuTempuh, description: 'Travel Time'),
        WordItem(text: 'Info Halte', iconPath: ImageAssets.infoHalte, description: 'Stop Information'),
        WordItem(text: 'Tap Kartu', iconPath: ImageAssets.tapKartu, description: 'Tap the Card'),
      ],
      sentences: const [
        SentenceItem(text: 'Apakah ini kendaraan terakhir hari ini?', description: 'Is this the last service for today?'),
        SentenceItem(text: 'Apa pemberhentian setelah ini?', description: 'What is the next stop?'),
        SentenceItem(text: 'Saya butuh bantuan baca peta jalur', description: 'I need help reading the route map'),
        SentenceItem(text: 'Di mana papan informasi rute?', description: 'Where is the route information board?'),
        SentenceItem(text: 'Berapa lama perjalanannya?', description: 'How long is the journey?'),
        SentenceItem(text: 'Di mana beli tiketnya?', description: 'Where can I buy a ticket?'),
      ],
    ),
  ];

  TemplateData get _currentTemplate => _templates[_currentTemplateIndex];

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    unawaited(_configureTts());
    _focusRequestListener = _handleFocusRequest;
    BoardInputFocusService.requests.addListener(_focusRequestListener);
  }

  void _addTextToInput(String text) {
    final currentText = _textController.text;
    if (currentText.isEmpty) {
      _textController.text = text;
    } else {
      _textController.text = '$currentText $text';
    }
  }

  Future<void> _configureTts() async {
    await _flutterTts.setLanguage('id-ID');
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speakCurrentInput() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    await _flutterTts.stop();
    print('TEXT: $text');
    await _checkVolumeAndWarn();
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _textController.dispose();
    _inputFocusNode.dispose();
    BoardInputFocusService.requests.removeListener(_focusRequestListener);
    unawaited(_flutterTts.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //   title: const Text('Swarana'),
      //   automaticallyImplyLeading: false,
      // ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ketik atau pilih kata/kalimat di bawah untuk mulai bicara ✨💬',
                style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: _textController,
                  focusNode: _inputFocusNode,
                  style: TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Tulis lalu klik gambar untuk disuarakan',
                    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                    ),
                    suffixIcon: IconButton(
                      icon: SvgPicture.asset(IconAssets.userVoice, color: HexColor('#3C37AF'), height: 30),
                      onPressed: () async {
                        await _speakCurrentInput();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _TemplateSelector(
                templates: _templates,
                currentIndex: _currentTemplateIndex,
                onSelected: (index) {
                  if (index == _currentTemplateIndex) return;
                  setState(() {
                    _currentTemplateIndex = index;
                  });
                },
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: HexColor('#3C37AF').withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: WordBoard(templateData: _currentTemplate, onTextSelected: _addTextToInput),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFocusRequest() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_inputFocusNode);
    });
  }

  Future<void> _checkVolumeAndWarn() async {
    try {
      final volume = await VolumeController.instance.getVolume();
      if (volume <= 0.2 && mounted) {
        VolumeAlertService.showLowVolume(context);
      }
    } on MissingPluginException {
      print('ERROR CHECKING VOLUME MISSING PLUGIN');
      // Volume controller not registered for this platform.
    } catch (e) {
      print('ERROR CHECKING VOLUME $e');
      // ignore unsupported platform volume queries
    }
  }
}

class _TemplateSelector extends StatelessWidget {
  const _TemplateSelector({required this.templates, required this.currentIndex, required this.onSelected});

  final List<TemplateData> templates;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final HexColor primary = HexColor('#3C37AF');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: templates.asMap().entries.map((entry) {
          final index = entry.key;
          final template = entry.value;
          final bool isSelected = index == currentIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primary),
                ),
                child: Text(
                  template.type.displayName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
