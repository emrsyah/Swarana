import '../core/models/scenario.dart';

/// Iterasi 6 · Uji 4: buka rekening bank (5 interaksi), kartu A/B.
/// Naskah persis sama dengan protokol pengujian.

const newsText =
    'Selamat siang. Bank Nusantara Jaya resmi membuka kantor cabang baru di Jalan Asia Afrika Nomor 45, Bandung. '
    'Kantor ini melayani pembukaan rekening setiap Senin sampai Jumat, pukul delapan pagi sampai tiga sore.';

class I6Card {
  const I6Card({
    required this.id,
    required this.name,
    required this.nik,
    required this.address,
    required this.npwp,
    required this.deposit,
    required this.depositWords,
    required this.formOrder,
    required this.formLine,
  });

  final String id;
  final String name;
  final String nik;
  final String address;
  final bool npwp;
  final String deposit;
  final String depositWords;
  final String formOrder;
  final String formLine;

  static const a = I6Card(
    id: 'A',
    name: 'Rani Putri',
    nik: '3273 0101 0101 0001',
    address: 'Jl. Melati No. 7, Bandung',
    npwp: false,
    deposit: 'Rp100.000',
    depositWords: 'seratus ribu rupiah',
    formOrder: 'NIK, nama, alamat',
    formLine: 'Silakan tulis identitas di formulir ini. Urutannya: NIK dulu, lalu nama lengkap, lalu alamat.',
  );

  static const b = I6Card(
    id: 'B',
    name: 'Dimas Pratama',
    nik: '3273 0202 0202 0002',
    address: 'Jl. Kenanga No. 12, Bandung',
    npwp: true,
    deposit: 'Rp50.000',
    depositWords: 'lima puluh ribu rupiah',
    formOrder: 'nama, alamat, NIK',
    formLine: 'Silakan tulis identitas di formulir ini. Urutannya: nama lengkap dulu, lalu alamat, lalu NIK.',
  );

  static I6Card byId(String id) => id == 'B' ? b : a;

  /// "Berhasil bila" per interaction, with this card's expected answer.
  List<(String, String)> get criteria => [
        ('1 · Rekaman berita', 'Nasabah menyebut alamat bank dengan benar: Jl. Asia Afrika No. 45.'),
        ('2 · Tujuan rekening', 'Petugas bisa menyebutkan tujuan nasabah dengan benar.'),
        ('3 · Dokumen', npwp ? 'Jawaban sesuai kartu: KTP ada, NPWP ada.' : 'Jawaban sesuai kartu: KTP ada, NPWP tidak ada.'),
        ('4 · Setoran awal', 'Nasabah menyebut nominal setoran dengan benar: $deposit.'),
        ('5 · Formulir', 'Identitas ditulis lengkap dengan urutan: $formOrder.'),
      ];

  /// Simulated teller (+ news) for "Simulasi" mode.
  ScenarioForm get form => ScenarioForm(
        instruction: 'Kamu nasabah yang mau buka rekening. Pakai Swarana saja untuk berkomunikasi.',
        turns: [
          ScenarioTurn(speaker: 's1', text: newsText, suggest: const ['Bisa diulang?', 'Terima kasih']),
          ScenarioTurn(waitForUser: true),
          ScenarioTurn(
            speaker: 's2',
            text: 'Selamat siang, selamat datang di Bank Nusantara Jaya. Ada yang bisa saya bantu? Rekeningnya mau dipakai untuk apa?',
            suggest: const ['Saya mau buka rekening tabungan', 'Untuk menerima gaji', 'Untuk usaha'],
          ),
          ScenarioTurn(waitForUser: true),
          ScenarioTurn(
            speaker: 's2',
            text: 'Baik. Apakah Bapak atau Ibu membawa KTP dan NPWP?',
            suggest: const ['KTP ada, NPWP tidak ada', 'KTP dan NPWP ada', 'Bisa diulang?'],
          ),
          ScenarioTurn(waitForUser: true),
          ScenarioTurn(
            speaker: 's2',
            text: 'Untuk rekening baru, setoran awalnya minimal $depositWords.',
            suggest: const ['Baik, saya setor', 'Bisa diulang?', 'Berapa?'],
          ),
          ScenarioTurn(waitForUser: true),
          ScenarioTurn(speaker: 's2', text: formLine, suggest: const ['Baik', 'Bisa diulang urutannya?', 'Terima kasih']),
        ],
      );
}

/// Interface texts the evaluator can pick as "Teks penyebab" (v5 labels).
const interfaceTexts = [
  'Mendengarkan',
  'Jeda, tidak mendengar',
  'Jeda',
  'Lanjutkan',
  'Tulis pesan di sini',
  'Rekomendasi balasan',
  'Bunyikan lagi',
  'Sudah dibunyikan',
  'Sederhanakan',
  'Tanya arti kata',
  'Orang lain bicara',
  'Tunjukkan ke lawan bicara',
  'Papan kata (ikon grid)',
  'Kata / Kalimat',
  'Frasa cepat',
  'Akhiri obrolan',
  'Menu (ikon garis tiga)',
  'Transkrip',
  'Riwayat',
];

const confusionTypes = ['Ragu', 'Salah tekan', 'Bertanya'];
