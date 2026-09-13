import 'package:cloud_firestore/cloud_firestore.dart';

class TouristPlaceService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> addPlace({
    required String name,
    required String description,
    required String category,
    required double latitude,
    required double longitude,
    required double rating,
  }) async {
    await _firestore.collection('touristPlaces').add({
      'name': name,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
  }

  Future<void> updatePlace(
    String placeId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection('touristPlaces')
        .doc(placeId)
        .update(data);
  }

  Future<void> deletePlace(String placeId) async {
    await _firestore
        .collection('touristPlaces')
        .doc(placeId)
        .delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPlaces() {
    return _firestore
        .collection('touristPlaces')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }
}