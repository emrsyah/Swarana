class WordItem {
  final String text;
  final String iconPath;
  final String? description;

  const WordItem({
    required this.text,
    required this.iconPath,
    this.description,
  });
}

class SentenceItem {
  final String text;
  final String? description;

  const SentenceItem({
    required this.text,
    this.description,
  });
}

enum TemplateType {
  umum('Umum'),
  rumahSakit('Rumah Sakit'),
  restoran('Restoran/Cafe'),
  tempatBelanja('Tempat Belanja'),
  layananPublik('Layanan Publik'),
  sekolahKampus('Sekolah/Kampus'),
  bank('Bank'),
  tempatWisata('Tempat Wisata'),
  transportasiUmum('Transportasi Umum');

  const TemplateType(this.displayName);
  final String displayName;
}

class TemplateData {
  final TemplateType type;
  final List<WordItem> words;
  final List<SentenceItem> sentences;

  const TemplateData({
    required this.type,
    required this.words,
    required this.sentences,
  });
}