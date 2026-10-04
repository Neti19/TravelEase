import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/trip.dart';
import 'trip_member_service.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // CREATE TRIP
  // ============================================================

  Future<String> saveTrip(Trip trip) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    print('USER ID: ${user.uid}');
    print('Saving trip to Firestore...');

    final docRef = await _firestore.collection('trips').add({
      ...trip.toMap(),
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'planned',
    });

    // Add the creator as the owner/member.
    await TripMemberService().addOwnerToTrip(tripId: docRef.id);

    print('TRIP ID CREATED: ${docRef.id}');
    print('TRIP OWNER ADDED: ${user.uid}');

    return docRef.id;
  }

  // ============================================================
  // GET ALL USER TRIPS
  //
  // Includes:
  // 1. Trips created by the current user
  // 2. Trips joined by the current user
  // ============================================================

  Future<List<Trip>> getUserTrips() async {
    final user = _auth.currentUser;

    if (user == null) {
      return [];
    }

    final Map<String, Trip> tripMap = {};

    // ------------------------------------------------------------
    // 1. GET TRIPS OWNED BY CURRENT USER
    // ------------------------------------------------------------

    final ownedSnapshot = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (final doc in ownedSnapshot.docs) {
      final data = doc.data();

      tripMap[doc.id] = Trip.fromJson({...data, 'id': doc.id});
    }

    // ------------------------------------------------------------
    // 2. GET TRIP MEMBERSHIPS OF CURRENT USER
    // ------------------------------------------------------------

    final memberSnapshot = await _firestore
        .collection('trip_members')
        .where('userId', isEqualTo: user.uid)
        .get();

    // ------------------------------------------------------------
    // 3. LOAD THE ACTUAL TRIPS FOR THOSE MEMBERSHIPS
    // ------------------------------------------------------------

    for (final memberDoc in memberSnapshot.docs) {
      final memberData = memberDoc.data();

      final tripId = memberData['tripId']?.toString();

      if (tripId == null || tripId.isEmpty) {
        continue;
      }

      // Already loaded as an owned trip.
      if (tripMap.containsKey(tripId)) {
        continue;
      }

      final tripDoc = await _firestore.collection('trips').doc(tripId).get();

      if (!tripDoc.exists) {
        continue;
      }

      final data = tripDoc.data();

      if (data == null) {
        continue;
      }

      tripMap[tripId] = Trip.fromJson({...data, 'id': tripId});
    }

    // ------------------------------------------------------------
    // 4. SORT NEWEST FIRST
    // ------------------------------------------------------------

    final trips = tripMap.values.toList();

    trips.sort((a, b) => b.startDate.compareTo(a.startDate));

    return trips;
  }

  // ============================================================
  // GET SINGLE TRIP
  // ============================================================

  Future<Trip?> getTrip(String tripId) async {
    final doc = await _firestore.collection('trips').doc(tripId).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();

    if (data == null) {
      return null;
    }

    return Trip.fromJson({...data, 'id': doc.id});
  }

  Future<bool> isTripOwner(String tripId) async {
    final user = _auth.currentUser;
    if (user == null || tripId.trim().isEmpty) return false;

    final snapshot = await _firestore.collection('trips').doc(tripId).get();
    return snapshot.data()?['userId']?.toString() == user.uid;
  }

  // ============================================================
  // UPDATE TRIP
  // ============================================================

  Future<void> updateTrip(String tripId, Map<String, dynamic> data) async {
    await _firestore.collection('trips').doc(tripId).update(data);
  }

  // ============================================================
  // DELETE TRIP
  // ============================================================

  Future<void> deleteTrip(String tripId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    if (tripId.trim().isEmpty) {
      throw Exception('Trip ID is missing.');
    }

    final tripRef = _firestore.collection('trips').doc(tripId);
    final tripSnapshot = await tripRef.get();

    if (!tripSnapshot.exists) {
      throw Exception('Trip not found.');
    }

    if (tripSnapshot.data()?['userId']?.toString() != user.uid) {
      throw Exception('Only the trip owner can delete this trip.');
    }

    final tripData = tripSnapshot.data();
    if (tripData == null) {
      throw Exception('Trip data could not be loaded.');
    }
    final trip = Trip.fromJson({...tripData, 'id': tripSnapshot.id});
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(
      trip.startDate.year,
      trip.startDate.month,
      trip.startDate.day,
    );
    final endDate = DateTime(
      trip.endDate.year,
      trip.endDate.month,
      trip.endDate.day,
    );
    if (!today.isBefore(startDate) || today.isAfter(endDate)) {
      throw Exception('Only planning or upcoming trips can be deleted.');
    }

    for (final collectionName in [
      'destinations',
      'selectedPlaces',
      'expenses',
    ]) {
      await _deleteCollection(tripRef.collection(collectionName));
    }

    await _deleteCollection(
      _firestore.collection('trip_members').where('tripId', isEqualTo: tripId),
    );

    await tripRef.delete();
  }

  Future<void> _deleteCollection(Query<Map<String, dynamic>> query) async {
    while (true) {
      final snapshot = await query.limit(500).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }
}
