import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

// ─────────────────────────────────────────────
//  FAQ SERVICE SINGLETON
//  Fetches once per app session, then returns cache
// ─────────────────────────────────────────────
class FaqService {
  FaqService._();
  static final FaqService instance = FaqService._();

  List<FaqCategory>? _cache;

  // Set your Laravel API Endpoint URL here
  // Use http://10.0.2.2:8000/api/faq if testing on Android Emulator
  static const String _faqEndpoint = 'http://10.0.2.2:8000/api/faq';

  Future<List<FaqCategory>> getCategories() async {
    // Return cached data if already fetched this session
    if (_cache != null) return _cache!;

    try {
      final response = await http.get(
        Uri.parse(_faqEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = jsonDecode(response.body);

        _cache = categoriesJson.map((catData) {
          final itemsList = (catData['items'] as List<dynamic>).map((itemData) {

            // Extract action_buttons returned from Laravel (if present)
            List<String>? actionBtns;
            if (itemData['action_buttons'] != null) {
              actionBtns = List<String>.from(itemData['action_buttons']);
            }

            return FaqItem(
              question: itemData['question'] as String,
              answer: itemData['answer'] as String,
              actionButtons: actionBtns,
            );
          }).toList();

          return FaqCategory(
            id: catData['id'] as String,
            label: catData['label'] as String,
            icon: iconFromString(catData['icon'] as String? ?? ''),
            items: itemsList,
          );
        }).toList();

        return _cache!;
      } else {
        debugPrint('FaqService API error: ${response.statusCode}');
        _cache = kFaqCategories;
        return _cache!;
      }
    } catch (e) {
      debugPrint('FaqService network error: $e');
      // Fallback to hardcoded data if Laravel backend is unreachable
      _cache = kFaqCategories;
      return _cache!;
    }
  }

  /// Call this if you ever want to force a fresh fetch from Laravel
  void clearCache() => _cache = null;
}