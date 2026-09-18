import 'package:cloud_firestore/cloud_firestore.dart';

class TripDestinationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _destinations(String tripId) {
    return _firestore.collection('trips').doc(tripId).collection('destinations');
  }

  CollectionReference<Map<String, dynamic>> _selectedPlaces(String tripId) {
    return _firestore
        .collection('trips')
        .doc(tripId)
        .collection('selectedPlaces');
  }

  Future<String?> addDestination({
    required String tripId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? placeId,
    String source = 'places_api',
  }) async {
    if (placeId != null && placeId.isNotEmpty) {
      final existing = await _destinations(tripId)
          .where('placeId', isEqualTo: placeId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return existing.docs.first.id;
    } else {
      final existing = await _destinations(tripId).get();
      final alreadyAdded = existing.docs.any((doc) {
        final data = doc.data();
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        return lat == latitude && lng == longitude;
      });

      if (alreadyAdded) return null;
    }

    final docRef = await _destinations(tripId).add({
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> destinationsStream(
    String tripId,
  ) {
    return _destinations(tripId).orderBy('createdAt').snapshots();
  }

  Future<List<Map<String, dynamic>>> getDestinations(String tripId) async {
    final snapshot = await _destinations(tripId).get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  Future<void> removeDestination(String tripId, String destinationId) async {
    await _destinations(tripId).doc(destinationId).delete();
  }

  Future<void> saveSelectedPlace({
    required String tripId,
    required String placeId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? category,
  }) async {
    await _selectedPlaces(tripId).doc(placeId).set({
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }


  Future<List<Map<String, dynamic>>> getSelectedPlaces(String tripId) async {
    final snapshot = await _selectedPlaces(tripId).get();
    return snapshot.docs.map((doc) {
      return {
        'id': doc.id,
        ...doc.data(),
      };
    }).toList();
  }

  Future<void> removeSelectedPlace(String tripId, String placeId) async {
    await _selectedPlaces(tripId).doc(placeId).delete();
  }
}
