
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/trip_member_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

extension TripMemberServiceJoinExtension on TripMemberService {
Future<String> joinTripByCode(String tripCode) async {
final auth = FirebaseAuth.instance;
final firestore = FirebaseFirestore.instance;

final user = auth.currentUser;

if (user == null) {
throw Exception('User is not logged in.');
}

final code = tripCode.trim().toUpperCase();

if (code.isEmpty) {
throw Exception('Please enter a trip code.');
}

if (code.length != 6) {
throw Exception('Trip code must be 6 characters.');
}

// Find the trip using the trip code.
final tripSnapshot = await firestore
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

final tripDoc = tripSnapshot.docs.first;
final tripId = tripDoc.id;
final tripData = tripDoc.data();

// Check whether the current user is already a member.
final memberRef = firestore
    .collection('trip_members')
    .doc('${user.uid}_$tripId');

final existingMember = await memberRef.get();

if (existingMember.exists) {
throw Exception(
'You are already a member of this trip.',
);
}

// Get current members.
final membersSnapshot = await firestore
    .collection('trip_members')
    .where(
'tripId',
isEqualTo: tripId,
)
    .get();

final travelersCount =
(tripData['travelersCount'] as num?)?.toInt() ?? 1;

if (membersSnapshot.docs.length >= travelersCount) {
throw Exception(
'This trip has reached its traveler limit.',
);
}

// Add current user as a trip member.
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

class JoinTripScreen extends StatefulWidget {
const JoinTripScreen({super.key});

@override
State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
final TextEditingController _codeController =
TextEditingController();

final TripMemberService _memberService =
TripMemberService();

bool _joining = false;

@override
void dispose() {
_codeController.dispose();
super.dispose();
}

Future<void> _joinTrip() async {
if (_joining) {
return;
}

final code =
_codeController.text.trim().toUpperCase();

if (code.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Please enter the trip code.'),
behavior: SnackBarBehavior.floating,
),
);
return;
}

if (code.length != 6) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Trip code must be 6 characters.',
),
behavior: SnackBarBehavior.floating,
),
);
return;
}

setState(() {
_joining = true;
});

try {
final tripId =
await _memberService.joinTripByCode(code);

if (!mounted) {
return;
}

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'You joined the trip successfully!',
),
behavior: SnackBarBehavior.floating,
),
);

Navigator.pop(context, tripId);
} catch (e) {
if (!mounted) {
return;
}

String message = e.toString();

if (message.startsWith('Exception: ')) {
message =
message.substring('Exception: '.length);
}

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(message),
behavior: SnackBarBehavior.floating,
),
);
} finally {
if (mounted) {
setState(() {
_joining = false;
});
}
}
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF7FAFC),
appBar: AppBar(
backgroundColor: Colors.white,
foregroundColor: const Color(0xFF102A43),
elevation: 0,
title: const Text(
'Join a Trip',
style: TextStyle(
fontWeight: FontWeight.w800,
),
),
actions: const [DashboardNavigationButton()],
),
body: SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.all(20),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.stretch,
children: [
const SizedBox(height: 12),

Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
gradient: const LinearGradient(
colors: [
Color(0xFF1677FF),
Color(0xFF00A6A6),
],
begin: Alignment.topLeft,
end: Alignment.bottomRight,
),
borderRadius:
BorderRadius.circular(24),
),
child: const Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Icon(
Icons.group_rounded,
color: Colors.white,
size: 42,
),
SizedBox(height: 16),
Text(
'Join your travel buddies.',
style: TextStyle(
color: Colors.white,
fontSize: 25,
fontWeight: FontWeight.w900,
),
),
SizedBox(height: 8),
Text(
'Enter the 6-character trip code '
'shared by the trip owner.',
style: TextStyle(
color: Colors.white70,
fontSize: 14,
height: 1.5,
),
),
],
),
),

const SizedBox(height: 28),

const Text(
'Trip Code',
style: TextStyle(
color: Color(0xFF102A43),
fontSize: 18,
fontWeight: FontWeight.w800,
),
),

const SizedBox(height: 10),

TextField(
controller: _codeController,
textCapitalization:
TextCapitalization.characters,
textAlign: TextAlign.center,
maxLength: 6,
enabled: !_joining,
style: const TextStyle(
fontSize: 26,
fontWeight: FontWeight.w900,
letterSpacing: 5,
color: Color(0xFF102A43),
),
decoration: InputDecoration(
hintText: 'ABC123',
counterText: '',
filled: true,
fillColor: Colors.white,
prefixIcon: const Icon(
Icons.vpn_key_rounded,
color: Color(0xFF1677FF),
),
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(16),
borderSide: const BorderSide(
color: Color(0xFFDCE7F0),
),
),
enabledBorder: OutlineInputBorder(
borderRadius:
BorderRadius.circular(16),
borderSide: const BorderSide(
color: Color(0xFFDCE7F0),
),
),
focusedBorder: OutlineInputBorder(
borderRadius:
BorderRadius.circular(16),
borderSide: const BorderSide(
color: Color(0xFF1677FF),
width: 2,
),
),
),
onSubmitted: (_) {
_joinTrip();
},
),

const SizedBox(height: 12),

const Text(
'The trip owner can find this code '
'inside Invite Travelers.',
textAlign: TextAlign.center,
style: TextStyle(
color: Color(0xFF627D98),
fontSize: 13,
height: 1.4,
),
),

const SizedBox(height: 28),

SizedBox(
height: 52,
child: FilledButton.icon(
onPressed:
_joining ? null : _joinTrip,
icon: _joining
? const SizedBox(
height: 20,
width: 20,
child:
CircularProgressIndicator(
strokeWidth: 2.5,
color: Colors.white,
),
)
    : const Icon(
Icons.login_rounded,
),
label: Text(
_joining
? 'Joining Trip...'
    : 'Join Trip',
),
style: FilledButton.styleFrom(
backgroundColor:
const Color(0xFF1677FF),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(15),
),
textStyle: const TextStyle(
fontWeight: FontWeight.w800,
fontSize: 15,
),
),
),
),

const SizedBox(height: 30),

Container(
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.circular(18),
border: Border.all(
color: const Color(0xFFE3EAF1),
),
),
child: const Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Icon(
Icons.info_outline_rounded,
color: Color(0xFF1677FF),
),
SizedBox(width: 12),
Expanded(
child: Text(
'After joining, this trip will '
'appear in your My Trips and you '
'can open the shared trip workspace.',
style: TextStyle(
color: Color(0xFF486581),
fontSize: 13,
height: 1.45,
),
),
),
],
),
),
],
),
),
),
);
}
}
