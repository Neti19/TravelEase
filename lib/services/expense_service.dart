import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';

class ExpenseService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  User? get _currentUser =>
      _auth.currentUser;

  CollectionReference<Map<String, dynamic>>
  _expenseCollection(String tripId) {
    if (_currentUser == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    if (tripId.trim().isEmpty) {
      throw Exception(
        'Trip ID is missing.',
      );
    }

    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('expenses');
  }

  // Get all expenses belonging to one trip.
  Stream<List<Expense>> getExpenses(
      String tripId,
      ) {
    return _expenseCollection(tripId)
        .orderBy(
      'date',
      descending: true,
    )
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Expense.fromMap({
          ...doc.data(),
          'id': doc.id,
        });
      }).toList();
    });
  }

  // Add a shared trip expense.
  Future<void> addExpense({
    required String tripId,
    required String title,
    required double amount,
    required String category,
    required String note,
    required DateTime date,
    required Map<String, double> splitBetween,
    required Map<String, String> splitBetweenNames,
  }) async {
    final user = _currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    if (tripId.trim().isEmpty) {
      throw Exception(
        'Trip ID is missing.',
      );
    }

    if (title.trim().isEmpty) {
      throw Exception(
        'Expense title is required.',
      );
    }

    if (amount <= 0) {
      throw Exception(
        'Expense amount must be greater than zero.',
      );
    }

    if (splitBetween.isEmpty) {
      throw Exception(
        'Select at least one traveler to split the expense with.',
      );
    }

    final totalShares = splitBetween.values.fold<double>(
      0,
          (sum, share) => sum + share,
    );

    if ((totalShares - amount).abs() > 0.01) {
      throw Exception(
        'The split amounts do not equal the expense total.',
      );
    }

    final collection =
    _expenseCollection(tripId);

    final document = collection.doc();

    final paidByName =
    user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.trim().isNotEmpty == true
        ? user.email!.trim()
        : 'Traveler';

    final expense = Expense(
      id: document.id,
      tripId: tripId,
      title: title.trim(),
      amount: amount,
      category: category,
      note: note.trim(),
      date: date,
      paidBy: user.uid,
      paidByName: paidByName,
      splitBetween: splitBetween,
      splitBetweenNames: splitBetweenNames,
    );

    await document.set(
      expense.toMap(),
    );
  }

  // Delete a shared trip expense.
  Future<void> deleteExpense({
    required String tripId,
    required String expenseId,
  }) async {
    final user = _currentUser;

    if (user == null) {
      throw Exception(
        'User is not logged in.',
      );
    }

    if (tripId.trim().isEmpty) {
      throw Exception(
        'Trip ID is missing.',
      );
    }

    if (expenseId.trim().isEmpty) {
      throw Exception(
        'Expense ID is missing.',
      );
    }

    await _expenseCollection(tripId)
        .doc(expenseId)
        .delete();
  }
}