import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../widgets/word_board.dart';
import '../../domain/entities/word_item.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final TextEditingController _textController = TextEditingController();
  int _currentTemplateIndex = 0;

  // Template data - organized for easy extension
  final List<TemplateData> _templates = [
    // Umum Template
    TemplateData(
      type: TemplateType.umum,
      words: const [
        WordItem(text: 'Halo', iconPath: '👋', description: 'Greeting'),
        WordItem(text: 'Ya', iconPath: '✅', description: 'Yes'),
        WordItem(text: 'Tidak', iconPath: '❌', description: 'No'),
        WordItem(text: 'Tolong', iconPath: '🙏', description: 'Please help'),
        WordItem(text: 'Terima kasih', iconPath: '🙏', description: 'Thank you'),
        WordItem(text: 'Maaf', iconPath: '😔', description: 'Sorry'),
        WordItem(text: 'Sebentar', iconPath: '⏰', description: 'Wait a moment'),
        WordItem(text: 'Permisi', iconPath: '👤', description: 'Excuse me'),
        WordItem(text: 'Saya paham', iconPath: '🧠', description: 'I understand'),
        WordItem(text: 'Tidak paham', iconPath: '🤔', description: 'Don\'t understand'),
        WordItem(text: 'Saya setuju', iconPath: '✅', description: 'I agree'),
        WordItem(text: 'Tolong ulangi', iconPath: '🔄', description: 'Please repeat'),
        WordItem(text: 'Baik', iconPath: '👍', description: 'Good/Okay'),
        WordItem(text: 'Sampai jumpa', iconPath: '👋', description: 'Goodbye'),
        WordItem(text: 'Saya lapar', iconPath: '🍽️', description: 'I am hungry'),
        WordItem(text: 'Dimana?', iconPath: '🔍', description: 'Where?'),
      ],
      sentences: const [
        SentenceItem(
          text: 'Permisi, saya butuh bantuan',
          description: 'Asking for help politely',
        ),
        SentenceItem(
          text: 'Apakah anda bisa bahasa isyarat?',
          description: 'Asking about sign language',
        ),
        SentenceItem(
          text: 'Saya tidak mengerti',
          description: 'Expressing lack of understanding',
        ),
        SentenceItem(
          text: 'Tolong ucapkan kalimat dengan pelan dan jelas',
          description: 'Asking to speak slowly and clearly',
        ),
        SentenceItem(
          text: 'Boleh saya bertanya sesuatu?',
          description: 'Asking permission to ask a question',
        ),
        SentenceItem(
          text: 'Terima kasih atas bantuannya',
          description: 'Thanking for help',
        ),
      ],
    ),
    
    // Rumah Sakit Template
    TemplateData(
      type: TemplateType.rumahSakit,
      words: const [
        WordItem(text: 'Sakit', iconPath: '🤒', description: 'Sick/Pain'),
        WordItem(text: 'Dokter', iconPath: '👨‍⚕️', description: 'Doctor'),
        WordItem(text: 'Perawat', iconPath: '👩‍⚕️', description: 'Nurse'),
        WordItem(text: 'Obat', iconPath: '💊', description: 'Medicine'),
        WordItem(text: 'Rumah Sakit', iconPath: '🏥', description: 'Hospital'),
        WordItem(text: 'Darurat', iconPath: '🚨', description: 'Emergency'),
        WordItem(text: 'Pusing', iconPath: '😵', description: 'Headache'),
        WordItem(text: 'Demam', iconPath: '🌡️', description: 'Fever'),
        WordItem(text: 'Mual', iconPath: '🤢', description: 'Nausea'),
        WordItem(text: 'Batuk', iconPath: '😷', description: 'Cough'),
        WordItem(text: 'Perut', iconPath: '🫄', description: 'Stomach'),
        WordItem(text: 'Kepala', iconPath: '🧠', description: 'Head'),
        WordItem(text: 'Dada', iconPath: '🫁', description: 'Chest'),
        WordItem(text: 'Tangan', iconPath: '🤚', description: 'Hand'),
        WordItem(text: 'Kaki', iconPath: '🦵', description: 'Leg/Foot'),
        WordItem(text: 'Bantuan', iconPath: '🆘', description: 'Help'),
      ],
      sentences: const [
        SentenceItem(
          text: 'Saya merasa sakit',
          description: 'I feel sick',
        ),
        SentenceItem(
          text: 'Saya butuh bantuan dokter',
          description: 'I need a doctor\'s help',
        ),
        SentenceItem(
          text: 'Kepala saya sakit',
          description: 'I have a headache',
        ),
        SentenceItem(
          text: 'Saya demam tinggi',
          description: 'I have a high fever',
        ),
        SentenceItem(
          text: 'Perut saya sakit sekali',
          description: 'My stomach hurts a lot',
        ),
        SentenceItem(
          text: 'Ini darurat, tolong cepat',
          description: 'This is an emergency, please hurry',
        ),
        SentenceItem(
          text: 'Saya alergi terhadap obat ini',
          description: 'I\'m allergic to this medicine',
        ),
        SentenceItem(
          text: 'Dimana ruang dokter?',
          description: 'Where is the doctor\'s room?',
        ),
      ],
    ),
    
    // Restoran/Cafe Template
    TemplateData(
      type: TemplateType.restoran,
      words: const [
        WordItem(text: 'Menu', iconPath: '📋', description: 'Menu'),
        WordItem(text: 'Makan', iconPath: '🍽️', description: 'Eat'),
        WordItem(text: 'Minum', iconPath: '🥤', description: 'Drink'),
        WordItem(text: 'Kopi', iconPath: '☕', description: 'Coffee'),
        WordItem(text: 'Teh', iconPath: '🍵', description: 'Tea'),
        WordItem(text: 'Air', iconPath: '💧', description: 'Water'),
        WordItem(text: 'Nasi', iconPath: '🍚', description: 'Rice'),
        WordItem(text: 'Ayam', iconPath: '🍗', description: 'Chicken'),
        WordItem(text: 'Ikan', iconPath: '🐟', description: 'Fish'),
        WordItem(text: 'Sayur', iconPath: '🥬', description: 'Vegetables'),
        WordItem(text: 'Buah', iconPath: '🍎', description: 'Fruit'),
        WordItem(text: 'Roti', iconPath: '🍞', description: 'Bread'),
        WordItem(text: 'Bayar', iconPath: '💳', description: 'Pay'),
        WordItem(text: 'Bon', iconPath: '🧾', description: 'Receipt'),
        WordItem(text: 'Panas', iconPath: '🔥', description: 'Hot'),
        WordItem(text: 'Dingin', iconPath: '🧊', description: 'Cold'),
      ],
      sentences: const [
        SentenceItem(
          text: 'Saya mau pesan makanan',
          description: 'I want to order food',
        ),
        SentenceItem(
          text: 'Boleh lihat menu?',
          description: 'Can I see the menu?',
        ),
        SentenceItem(
          text: 'Saya mau kopi panas',
          description: 'I want hot coffee',
        ),
        SentenceItem(
          text: 'Ada makanan vegetarian?',
          description: 'Do you have vegetarian food?',
        ),
        SentenceItem(
          text: 'Berapa harga ini?',
          description: 'How much does this cost?',
        ),
        SentenceItem(
          text: 'Saya mau bayar sekarang',
          description: 'I want to pay now',
        ),
        SentenceItem(
          text: 'Makanan ini terlalu pedas',
          description: 'This food is too spicy',
        ),
        SentenceItem(
          text: 'Terima kasih, makanannya enak',
          description: 'Thank you, the food is delicious',
        ),
      ],
    ),
  ];

  TemplateData get _currentTemplate => _templates[_currentTemplateIndex];

  void _addTextToInput(String text) {
    final currentText = _textController.text;
    if (currentText.isEmpty) {
      _textController.text = text;
    } else {
      _textController.text = '$currentText $text';
    }
  }

  void _navigateToNextTemplate() {
    setState(() {
      _currentTemplateIndex = (_currentTemplateIndex + 1) % _templates.length;
    });
  }

  void _navigateToPreviousTemplate() {
    setState(() {
      _currentTemplateIndex = (_currentTemplateIndex - 1 + _templates.length) % _templates.length;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                spacing: 10,
                children: [
                  Expanded(
                    child: const Text(
                      'Ketik atau pilih kata/kalimat di bawah untuk mulai bicara ✨💬',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        IconsaxPlusLinear.setting,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  
                ),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Ketik pesan di sini...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade400,
                        width: 1,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        IconsaxPlusBold.volume_high,
                        color: HexColor('#3C37AF'),
                      ),
                      onPressed: () {
                        print('mic button pressed');
                        // Add your mic button logic here
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HexColor('#3C37AF').withOpacity(0.05),
                      border: Border.all(
                        color: HexColor('#3C37AF'),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: _navigateToPreviousTemplate,
                      icon: Icon(
                        Icons.chevron_left,
                        color: HexColor('#3C37AF'),
                        size: 28,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: HexColor('#3C37AF'),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _currentTemplate.type.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HexColor('#3C37AF').withOpacity(0.05),
                      border: Border.all(
                        color: HexColor('#3C37AF'),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: _navigateToNextTemplate,
                      icon: Icon(
                        Icons.chevron_right,
                        color: HexColor('#3C37AF'),
                        size: 28,
                      ),
                    ),
                  ),
                ],
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
                  child: WordBoard(
                    templateData: _currentTemplate,
                    onTextSelected: _addTextToInput,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}