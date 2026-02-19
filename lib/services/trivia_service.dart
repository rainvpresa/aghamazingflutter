import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TriviaQuestion {
  final String id;
  final String question;
  final List<String> choices;
  final int correctIndex;
  final String category;
  final String difficulty;

  const TriviaQuestion({
    required this.id,
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.category,
    required this.difficulty,
  });

  factory TriviaQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TriviaQuestion(
      id: doc.id,
      question: data['question'] as String,
      choices: List<String>.from(data['choices'] as List),
      correctIndex: data['correctIndex'] as int,
      category: data['category'] as String? ?? 'general',
      difficulty: data['difficulty'] as String? ?? 'easy',
    );
  }
}

class TriviaService {
  TriviaService._();
  static final TriviaService instance = TriviaService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches [count] random questions from Firestore.
  /// Firestore doesn't support native random, so we fetch all and shuffle locally.
  Future<List<TriviaQuestion>> getRandomQuestions({int count = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('trivia_questions')
          .get();

      final all = snapshot.docs
          .map((doc) => TriviaQuestion.fromFirestore(doc))
          .toList();

      all.shuffle(); // Randomize order
      return all.take(count).toList();
    } catch (e) {
      debugPrint('TriviaService error: $e');
      return [];
    }
  }
}