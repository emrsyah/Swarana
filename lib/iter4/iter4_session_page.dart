import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services/storage.dart';
import 'iter4_controller.dart';
import 'iter4_options.dart';

/// Runs one participant through 3 options × 3 tasks.
class Iter4SessionPage extends StatefulWidget {
  const Iter4SessionPage({super.key, required this.participantId, required this.storage});
  final String participantId;
  final Storage storage;

  @override
  State<Iter4SessionPage> createState() => _Iter4SessionPageState();
}

class _Iter4SessionPageState extends State<Iter4SessionPage> {
  late final c = Iter4Controller(participantId: widget.participantId, storage: widget.storage);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (c.running) setState(() {});
    });
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _tick?.cancel();
    c.removeListener(_changed);
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PopScope(
      canPop: c.phase == I4Phase.done,
      child: Stack(children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) => c.onTap(e.position, size),
          // Key per option so each starts fresh.
          child: KeyedSubtree(key: ValueKey(c.option), child: buildOption(c)),
        ),
        if (c.phase == I4Phase.running) _pill(),
        if (c.phase != I4Phase.running) _overlay(context),
      ]),
    );
  }

  Widget _pill() {
    final s = c.elapsedSec;
    final clock = '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    return Positioned(
      left: 8,
      top: MediaQuery.paddingOf(context).top + 4,
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${c.task.id} · $clock', style: const TextStyle(color: Colors.white)),
            if (c.task == I4Task.recall)
              TextButton(
                onPressed: c.foundAnswer,
                child: const Text('Sudah ketemu', style: TextStyle(color: Colors.white)),
              ),
            TextButton(
              onPressed: c.giveUp,
              child: const Text('Menyerah', style: TextStyle(color: Colors.white70)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final Widget card = switch (c.phase) {
      I4Phase.brief => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${c.option.label} · Tugas ${c.taskIndex + 1} dari 3', style: t.labelLarge),
          const SizedBox(height: 8),
          Text(c.task.title, style: t.headlineSmall),
          const SizedBox(height: 10),
          Text(c.task.instruction, style: t.bodyLarge),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: c.startTask,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Mulai'),
          ),
        ]),
      I4Phase.mark => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Untuk peneliti', style: t.labelLarge),
          const SizedBox(height: 8),
          Text('Partisipan menjawab "dua puluh lima ribu" (Rp25.000)?', style: t.titleLarge),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => c.markAnswer(true),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Benar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => c.markAnswer(false),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Salah'),
          ),
        ]),
      I4Phase.between => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Opsi selesai', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text('Berikutnya: ${c.order[c.optionIndex + 1].label}', style: t.bodyLarge),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: c.nextOption,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Lanjut'),
          ),
        ]),
      _ => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Selesai', style: t.headlineSmall),
          const SizedBox(height: 8),
          Text('Semua tugas untuk ${c.participantId} sudah tersimpan.', style: t.bodyLarge),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Tutup'),
          ),
        ]),
    };
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(padding: const EdgeInsets.all(24), child: card),
            ),
          ),
        ),
      ),
    );
  }
}
