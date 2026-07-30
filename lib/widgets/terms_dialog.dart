// lib/widgets/terms_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/sound_manager.dart';

class TermsDialog extends StatelessWidget {
  const TermsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const TermsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1957A8);
    final dialogHeight = MediaQuery.of(context).size.height * 0.55;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: primaryColor, width: 2.5),
      ),
      backgroundColor: Colors.white,
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: const Text(
        'Terms and Conditions',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: primaryColor,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        // EXPLICIT CONSTRAINTS STOP INTRINSIC DIMENSION ERRORS:
        width: double.maxFinite,
        height: dialogHeight,
        child: FutureBuilder<String>(
          future: rootBundle.loadString('assets/terms_and_conditions.md'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(
                child: Text('Unable to load Terms and Conditions.'),
              );
            }

            return Scrollbar(
              thumbVisibility: true,
              child: Markdown(
                data: snapshot.data!,
                shrinkWrap: false,
                physics: const BouncingScrollPhysics(),
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  h1: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  h2: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  h3: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  listBullet: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            SoundManager.instance.playClick();
            Navigator.of(context).pop();
          },
          child: const Text(
            'Close',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}