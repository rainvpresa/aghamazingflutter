import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

// Import your chatbot screen models
import '../screens/chatbot_screen.dart';

// ─────────────────────────────────────────────
//  ICON STRING → ICONDATA MAP
// ─────────────────────────────────────────────
IconData iconFromString(String name) {
  const map = {
    'info_outline_rounded': Icons.info_outline_rounded,
    'design_services_rounded': Icons.design_services_rounded,
    'menu_book_rounded': Icons.menu_book_rounded,
    'science_rounded': Icons.science_rounded,
    'contact_support_rounded': Icons.contact_support_rounded,
    'star_rounded': Icons.star_rounded,
    'school_rounded': Icons.school_rounded,
  };
  return map[name] ?? Icons.help_outline_rounded;
}

//  FAQ SERVICE SINGLETON
//  Fetches fresh on every call; cache is an offline fallback only
class FaqService {
  FaqService._();
  static final FaqService instance = FaqService._();

  List<FaqCategory>? _cache;

  // Set your Laravel API Endpoint URL here
  // Use http://10.0.2.2:8000/api/faq if testing on Android Emulator
  static String get _faqEndpoint => '${ApiConfig.baseUrl}/api/faq';

  Future<List<FaqCategory>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse(_faqEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = jsonDecode(response.body);

        final parsed = categoriesJson.map((catData) {
          final itemsList = (catData['items'] as List<dynamic>).map((itemData) {
            List<FaqActionButton>? actionBtns;
            if (itemData['action_buttons'] != null) {
              actionBtns = (itemData['action_buttons'] as List)
                  .map((b) => FaqActionButton.fromJson(b as Map<String, dynamic>))
                  .toList();
            }

            List<FaqItem>? followUps;
            if (itemData['follow_ups'] != null) {
              followUps = (itemData['follow_ups'] as List)
                  .map((f) => FaqItem(
                question: f['question'] as String,
                answer: f['answer'] as String,
              ))
                  .toList();
            }
            return FaqItem(
              question: itemData['question'] as String,
              answer: itemData['answer'] as String,
              actionButtons: actionBtns,
              followUps: followUps,
            );
          }).toList();

          return FaqCategory(
            id: catData['id'] as String,
            label: catData['label'] as String,
            icon: iconFromString(catData['icon'] as String? ?? ''),
            items: itemsList,
          );
        }).toList();

        _cache = parsed; // last known good copy from the server
        return parsed;
      }

      debugPrint('FaqService API error: ${response.statusCode}');
    } catch (e) {
      debugPrint('FaqService network error: $e');
    }

    // Fetch failed: last good server copy first, hardcoded content as last resort.
    // The hardcoded list is intentionally NOT cached.
    return _cache ?? kFaqCategories;
  }

  /// Call this if you ever want to force a fresh fetch from Laravel
  void clearCache() => _cache = null;
}