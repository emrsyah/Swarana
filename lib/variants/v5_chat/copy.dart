/// Single source for v5 labels so the same action has the same name on every
/// screen (review finding: "Bunyikan Lagi" vs "Putar ulang", "Ringkasan" vs
/// "Sederhana").
class Copy {
  static const obrolan = 'Obrolan';
  static const transkrip = 'Transkrip';
  static const riwayat = 'Riwayat';
  static const pengaturan = 'Pengaturan';

  static const listening = 'Mendengarkan';
  static const paused = 'Jeda, tidak mendengar';
  static const idle = 'Tidak merekam';
  static const micUnavailable = 'Mikrofon tidak tersedia';
  static const jeda = 'Berhenti dengar sebentar';
  static const lanjutkan = 'Lanjutkan dengar';
  static const akhiriObrolan = 'Akhiri obrolan';

  // Figma wording ("disuarakan").
  static const bunyikanLagi = 'Suarakan lagi';
  static const sedangDibunyikan = 'Sedang disuarakan';
  static const sudahDibunyikan = 'Sudah disuarakan';
  static const gagalDibunyikan = 'Gagal disuarakan';
  static const volumeNol = 'Volume 0, suara tidak keluar';

  static const sederhanakan = 'Sederhanakan';
  static const tanyaArti = 'Tanya arti';
  static const salin = 'Salin';
  static const mintaUlangi = 'Minta ulangi';
  static const asli = 'Asli';
  static const sederhana = 'Sederhana';

  static const tulisPesan = 'Tulis pesan di sini';
  static const rekomendasi = 'Rekomendasi Balasan';
  static const mengenaliSuara = 'Mengenali suara pembicara baru…';
  static String pembicaraTerdeteksi(int n) => '$n pembicara terdeteksi…';
  static const orangLainBicara = 'Orang lain bicara';

  static const simpan = 'Simpan';
  static const batal = 'Batal';
  static const buang = 'Buang';
  static const hapus = 'Hapus';
}
