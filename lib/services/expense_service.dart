import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/expense.dart';

class ExpenseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _expenseCollection() {
    final userId = _userId;

    if (userId == null) {
      throw Exception('User is not logged in.');
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses');
  }

  // Get expenses of the logged-in user
  Stream<List<Expense>> getExpenses() {
    return _expenseCollection()
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Expense.fromMap(doc.data());
      }).toList();
    });
  }

  // Add a new expense
  Future<void> addExpense({
    required String title,
    required double amount,
    required String category,
    required String note,
    required DateTime date,
  }) async {
    final collection = _expenseCollection();

    final document = collection.doc();

    final expense = Expense(
      id: document.id,
      title: title,
      amount: amount,
      category: category,
      note: note,
      date: date,
    );

    await document.set(expense.toMap());
  }

  // Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    await _expenseCollection().doc(expenseId).delete();
  }
}