import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import '../../domain/entities/word_item.dart';

enum BoardMode { kata, kalimat }

class WordBoard extends StatefulWidget {
  final TemplateData templateData;
  final Function(String) onTextSelected;
  
  const WordBoard({
    super.key,
    required this.templateData,
    required this.onTextSelected,
  });

  @override
  State<WordBoard> createState() => _WordBoardState();
}

class _WordBoardState extends State<WordBoard> {
  BoardMode _selectedMode = BoardMode.kata;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab selector
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = BoardMode.kata),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedMode == BoardMode.kata
                          ? HexColor('#3C37AF')
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Kata',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedMode == BoardMode.kata
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = BoardMode.kalimat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedMode == BoardMode.kalimat
                          ? HexColor('#3C37AF')
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Kalimat',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _selectedMode == BoardMode.kalimat
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Content area
        Expanded(
          child: _selectedMode == BoardMode.kata
              ? _buildWordsGrid()
              : _buildSentencesGrid(),
        ),
      ],
    );
  }



  Widget _buildWordsGrid() {
    final words = widget.templateData.words;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final word = words[index];
        return _WordCard(
          word: word,
          onTap: () => _onWordTap(word.text),
        );
      },
    );
  }

  Widget _buildSentencesGrid() {
    final sentences = widget.templateData.sentences;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sentences.length,
      itemBuilder: (context, index) {
        final sentence = sentences[index];
        return _SentenceCard(
          sentence: sentence,
          onTap: () => _onSentenceTap(sentence.text),
        );
      },
    );
  }

  void _onWordTap(String word) {
    widget.onTextSelected(word);
  }

  void _onSentenceTap(String sentence) {
    widget.onTextSelected(sentence);
  }
}

class _WordCard extends StatelessWidget {
  final WordItem word;
  final VoidCallback onTap;

  const _WordCard({
    required this.word,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                word.iconPath,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  word.text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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

class _SentenceCard extends StatelessWidget {
  final SentenceItem sentence;
  final VoidCallback onTap;

  const _SentenceCard({
    required this.sentence,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          sentence.text,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}