import 'package:flutter/material.dart';

import '../../../core/env.dart';
import '../../../core/services/local_gemma.dart';
import '../../../core/services/voice_lab.dart';
import '../design/tokens.dart';

/// Test bench for on-device speaker detection + Gemma transcription.
/// Not part of the study flow; reached from Pengaturan.
class VoiceLabPage extends StatefulWidget {
  const VoiceLabPage({super.key});

  @override
  State<VoiceLabPage> createState() => _VoiceLabPageState();
}

class _VoiceLabPageState extends State<VoiceLabPage> {
  final lab = VoiceLab.instance;

  @override
  void dispose() {
    lab.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uji deteksi pembicara'),
        actions: [
          IconButton(tooltip: 'Hapus hasil', onPressed: lab.reset, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Column(children: [
        ValueListenableBuilder<LocalGemmaStatus>(
          valueListenable: LocalGemma.instance.status,
          builder: (_, s, _) {
            final g = LocalGemma.instance;
            final why = switch (s) {
              _ when g.hearsAudio => null,
              LocalGemmaStatus.ready => 'AI di ponsel aktif, tapi bagian audionya gagal dimuat: '
                  '${g.audioError ?? 'tidak diketahui'}',
              LocalGemmaStatus.loading => 'AI di ponsel sedang disiapkan…',
              LocalGemmaStatus.downloading || LocalGemmaStatus.importing => 'Model AI masih diunduh/disalin.',
              LocalGemmaStatus.error => 'AI di ponsel gagal: ${g.lastError ?? 'tidak diketahui'}',
              LocalGemmaStatus.unsupported => 'AI di ponsel hanya ada di Android.',
              LocalGemmaStatus.absent => 'Model AI belum diunduh. Unduh atau impor dulu di Pengaturan.',
            };
            if (why == null) return const SizedBox.shrink();
            return _Banner(Env.hasLlm
                ? '$why Tulisan dibuat oleh AI online (audio dikirim ke internet).'
                : '$why Pembicara tetap dideteksi, tapi tulisan tidak muncul.');
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: lab.threshold,
          builder: (_, t, _) => ListTile(
            title: Text('Batas suara sama: ${t.toStringAsFixed(2)}'),
            subtitle: Slider(
              value: t,
              min: 0.2,
              max: 0.8,
              divisions: 12,
              onChanged: (x) => lab.threshold.value = x,
            ),
          ),
        ),
        ValueListenableBuilder<int>(
          valueListenable: lab.people,
          builder: (_, n, _) => ListTile(
            dense: true,
            leading: const Icon(Icons.groups_outlined),
            title: Text(n == 0 ? 'Belum ada yang terdeteksi' : 'Terdeteksi $n orang'),
            subtitle: Text(n >= 2
                ? 'Lebih dari satu orang: tulisan dibuat AI online dulu.'
                : 'Satu orang: tulisan dibuat AI di ponsel dulu.'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ValueListenableBuilder<List<LabUtterance>>(
            valueListenable: lab.utterances,
            builder: (_, list, _) => list.isEmpty
                ? const Center(child: Text('Tekan Mulai, lalu bicara bergantian.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(V5Space.lg),
                    reverse: true,
                    itemCount: list.length,
                    itemBuilder: (_, i) => _UtteranceTile(list[list.length - 1 - i]),
                  ),
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(V5Space.lg),
        child: ValueListenableBuilder<VoiceLabStatus>(
          valueListenable: lab.status,
          builder: (_, s, _) => Column(mainAxisSize: MainAxisSize.min, children: [
            if (s == VoiceLabStatus.error)
              Padding(
                padding: const EdgeInsets.only(bottom: V5Space.sm),
                child: Text('Gagal: ${lab.lastError}', style: const TextStyle(color: V5Colors.error)),
              ),
            SizedBox(
              width: double.infinity,
              child: switch (s) {
                VoiceLabStatus.preparing => const FilledButton(
                    onPressed: null,
                    child: Text('Menyiapkan model suara (±30 MB)…'),
                  ),
                VoiceLabStatus.listening => FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: V5Colors.recording),
                    onPressed: lab.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Berhenti'),
                  ),
                _ => FilledButton.icon(onPressed: lab.start, icon: const Icon(Icons.mic), label: const Text('Mulai')),
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _UtteranceTile extends StatelessWidget {
  const _UtteranceTile(this.u);
  final LabUtterance u;

  @override
  Widget build(BuildContext context) {
    final color = speakerColor(u.speaker);
    final meta = [
      '${u.seconds.toStringAsFixed(1)} dtk suara',
      'kemiripan ${u.similarity.toStringAsFixed(2)}',
      if (u.transcribeMs != null)
        'ditulis ${(u.transcribeMs! / 1000).toStringAsFixed(1)} dtk${u.backend == null ? '' : ' (${u.backend})'}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: V5Space.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 14, backgroundColor: color, child: Text('${u.speaker + 1}', style: const TextStyle(color: Colors.white, fontSize: 13))),
        const SizedBox(width: V5Space.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Orang ${u.speaker + 1}', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: V5Space.xs),
            if (u.error != null)
              Text(u.error!, style: const TextStyle(color: V5Colors.error))
            else if (u.text == null)
              const Text('Menulis…', style: TextStyle(color: V5Colors.muted))
            else
              Text(u.text!.isEmpty ? '(tidak ada ucapan)' : u.text!, style: Theme.of(context).textTheme.bodyLarge),
            Text(meta, style: const TextStyle(fontSize: 12, color: V5Colors.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: V5Colors.warningBg,
        padding: const EdgeInsets.all(V5Space.md),
        child: Text(text),
      );
}
