
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip.dart';

class TripService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Future<String> saveTrip(Trip trip) async {
  final user = _auth.currentUser;

  if (user == null) {
    throw Exception('User is not logged in.');
  }

  print('USER ID: ${user.uid}');
  print('Saving trip to Firestore...');

  final docRef = await _firestore
      .collection('trips')
      .add({
    ...trip.toMap(),
    'userId': user.uid,
    'createdAt': FieldValue.serverTimestamp(),
    'status': 'planned',
  });

  print('TRIP ID CREATED: ${docRef.id}');

  return docRef.id;
}

  Future<List<Trip>> getUserTrips() async {
    final user = _auth.currentUser;

    if (user == null) {
      return [];
    }

    final snapshot = await _firestore
        .collection('trips')
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();

      return Trip.fromJson({
        ...data,
        'id': doc.id,
      });
    }).toList();
  }

  Future<Trip?> getTrip(String tripId) async {
    final doc = await _firestore
        .collection('trips')
        .doc(tripId)
        .get();

    if (!doc.exists) {
      return null;
    }

    return Trip.fromJson({
      ...doc.data()!,
      'id': doc.id,
    });
  }

  Future<void> updateTrip(
    String tripId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .update(data);
  }

  Future<void> deleteTrip(String tripId) async {
    await _firestore
        .collection('trips')
        .doc(tripId)
        .delete();
  }
}

