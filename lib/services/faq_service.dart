import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Import your chatbot screen models
// Adjust the import path to match your project structure
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
    // Add more icons here if you add new categories later
    'star_rounded': Icons.star_rounded,
    'school_rounded': Icons.school_rounded,
  };
  return map[name] ?? Icons.help_outline_rounded;
}

// ─────────────────────────────────────────────
//  ACTION BUTTONS (hardcoded by category/question)
// ─────────────────────────────────────────────
List<String>? _getActionButtons(String categoryId, String question) {
  if (categoryId == 'about' && question.toLowerCase().contains('located')) {
    return ['Get Directions'];
  }
  if (categoryId == 'about') {
    return ['Visit Website'];
  }
  if (categoryId == 'contact' && question.toLowerCase().contains('contact')) {
    return ['Contact Form'];
  }
  return null;
}

// ─────────────────────────────────────────────
//  FAQ SERVICE SINGLETON
//  Fetches once per app session, then returns cache
// ─────────────────────────────────────────────
class FaqService {
  FaqService._();
  static final FaqService instance = FaqService._();

  List<FaqCategory>? _cache;

  Future<List<FaqCategory>> getCategories() async {
    // Return cached data if already fetched this session
    if (_cache != null) return _cache!;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('faq_categories')
          .orderBy('order')
          .get();

      _cache = snapshot.docs.map((doc) {
        final data = doc.data();
        final items = (data['items'] as List<dynamic>).map((item) {
          return FaqItem(
            question: item['question'] as String,
            answer: item['answer'] as String,
            actionButtons: _getActionButtons(
              doc.id,
              item['question'] as String,
            ),
          );
        }).toList();

        return FaqCategory(
          id: doc.id,
          label: data['label'] as String,
          icon: iconFromString(data['icon'] as String),
          items: items,
        );
      }).toList();

      return _cache!;
    } catch (e) {
      debugPrint('FaqService error: $e');
      // Fallback to hardcoded data if Firestore is unreachable
      _cache = kFaqCategories;
      return _cache!;
    }
  }

  /// Call this if you ever want to force a fresh fetch from Firestore
  void clearCache() => _cache = null;
}