
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TripMemberService {
final FirebaseFirestore _firestore =
FirebaseFirestore.instance;

final FirebaseAuth _auth =
FirebaseAuth.instance;

CollectionReference<Map<String, dynamic>> get _members =>
_firestore.collection('trip_members');

Future<void> addOwnerToTrip({
required String tripId,
}) async {
final user = _auth.currentUser;

if (user == null) {
throw Exception('User is not logged in.');
}

final tripRef =
_firestore.collection('trips').doc(tripId);

final tripSnapshot = await tripRef.get();

if (!tripSnapshot.exists) {
throw Exception('Trip not found.');
}

final tripData = tripSnapshot.data()!;

String? tripCode =
tripData['tripCode']?.toString();

// Generate a trip code if this trip does not have one.
if (tripCode == null || tripCode.isEmpty) {
tripCode = await _generateUniqueTripCode();

await tripRef.update({
'tripCode': tripCode,
});
}

final memberRef =
_members.doc('${user.uid}_$tripId');

await memberRef.set(
{
'tripId': tripId,
'userId': user.uid,
'name':
user.displayName?.trim().isNotEmpty == true
? user.displayName!.trim()
    : 'Trip Owner',
'email': user.email ?? '',
'role': 'owner',
'joinedAt': FieldValue.serverTimestamp(),
},
SetOptions(merge: true),
);
}

Future<String> _generateUniqueTripCode() async {
const characters =
'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

final random = Random();

while (true) {
final code = List.generate(
6,
(_) => characters[
random.nextInt(characters.length)],
).join();

final snapshot = await _firestore
    .collection('trips')
    .where(
'tripCode',
isEqualTo: code,
)
    .limit(1)
    .get();

if (snapshot.docs.isEmpty) {
return code;
}
}
}

Future<bool> isMember(String tripId) async {
final user = _auth.currentUser;

if (user == null) {
return false;
}

final snapshot =
await _members.doc('${user.uid}_$tripId').get();

return snapshot.exists;
}

// ------------------------------------------------------------
// GET TRIP MEMBERS
// ------------------------------------------------------------

Future<List<Map<String, dynamic>>> getTripMembers(
String tripId,
) async {
final snapshot = await _members
    .where(
'tripId',
isEqualTo: tripId,
)
    .get();

return snapshot.docs
    .map(
(doc) => {
'id': doc.id,
...doc.data(),
},
)
    .toList();
}

Future<String> joinTripByCode(
String tripCode,
) async {
final user = _auth.currentUser;

if (user == null) {
throw Exception('User is not logged in.');
}

final code =
tripCode.trim().toUpperCase();

if (code.isEmpty) {
throw Exception('Please enter a trip code.');
}

if (code.length != 6) {
throw Exception(
'Trip code must be 6 characters.',
);
}

// Find the trip using its code.
final tripSnapshot = await _firestore
    .collection('trips')
    .where(
'tripCode',
isEqualTo: code,
)
    .limit(1)
    .get();

if (tripSnapshot.docs.isEmpty) {
throw Exception(
'Invalid trip code. Please check the code and try again.',
);
}

final tripDoc =
tripSnapshot.docs.first;

final tripId = tripDoc.id;

final tripData =
tripDoc.data();

// Check whether this user already joined.
final memberRef =
_members.doc('${user.uid}_$tripId');

final existingMember =
await memberRef.get();

if (existingMember.exists) {
throw Exception(
'You are already a member of this trip.',
);
}

// Get current members.
final members =
await getTripMembers(tripId);

final travelersCount =
(tripData['travelersCount'] as num?)
    ?.toInt() ??
1;

// Do not allow more members than
// the number of travelers planned.
if (members.length >= travelersCount) {
throw Exception(
'This trip has reached its traveler limit.',
);
}

// Add the current user as a member.
await memberRef.set({
'tripId': tripId,
'userId': user.uid,
'name':
user.displayName?.trim().isNotEmpty == true
? user.displayName!.trim()
    : 'Traveler',
'email': user.email ?? '',
'role': 'member',
'joinedAt': FieldValue.serverTimestamp(),
});

return tripId;
}
}
