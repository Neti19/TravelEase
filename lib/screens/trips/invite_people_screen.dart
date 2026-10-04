
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/trip_member_service.dart';
import '../../widgets/dashboard_navigation_button.dart';

class InvitePeopleScreen extends StatefulWidget {
final String tripId;

const InvitePeopleScreen({
super.key,
required this.tripId,
});

@override
State<InvitePeopleScreen> createState() =>
_InvitePeopleScreenState();
}

class _InvitePeopleScreenState
extends State<InvitePeopleScreen> {
final TripMemberService _memberService =
TripMemberService();

final FirebaseFirestore _firestore =
FirebaseFirestore.instance;

String? _tripCode;
List<Map<String, dynamic>> _members = [];

bool _loading = true;
String? _error;

@override
void initState() {
super.initState();
_loadTrip();
}

Future<void> _loadTrip() async {
try {
final tripSnapshot = await _firestore
    .collection('trips')
    .doc(widget.tripId)
    .get();

if (!tripSnapshot.exists) {
throw Exception('Trip not found.');
}

final data = tripSnapshot.data()!;

final code = data['tripCode']?.toString();

final members =
await _memberService.getTripMembers(
widget.tripId,
);

if (!mounted) return;

setState(() {
_tripCode = code;
_members = members;
_loading = false;
_error = null;
});
} catch (e) {
if (!mounted) return;

setState(() {
_loading = false;
_error = e.toString();
});
}
}

Future<void> _copyCode() async {
final code = _tripCode;

if (code == null || code.isEmpty) {
return;
}

await Clipboard.setData(
ClipboardData(text: code),
);

if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Trip code copied!'),
behavior: SnackBarBehavior.floating,
duration: Duration(seconds: 2),
),
);
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
'Travelers',
style: TextStyle(
fontWeight: FontWeight.w800,
),
),
actions: const [DashboardNavigationButton()],
),
body: _buildBody(),
);
}

Widget _buildBody() {
if (_loading) {
return const Center(
child: CircularProgressIndicator(),
);
}

if (_error != null) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.error_outline_rounded,
size: 52,
color: Color(0xFFEF5350),
),
const SizedBox(height: 14),
Text(
_error!,
textAlign: TextAlign.center,
),
const SizedBox(height: 18),
FilledButton(
onPressed: _loadTrip,
child: const Text('Retry'),
),
],
),
),
);
}

return RefreshIndicator(
onRefresh: _loadTrip,
child: ListView(
physics: const AlwaysScrollableScrollPhysics(),
padding: const EdgeInsets.all(20),
children: [
_buildHeroCard(),
const SizedBox(height: 20),
_buildCodeCard(),
const SizedBox(height: 24),
_buildMembersHeader(),
const SizedBox(height: 10),
if (_members.isEmpty)
_buildEmptyMembersCard()
else
..._members.map(_buildMemberCard),
],
),
);
}

Widget _buildHeroCard() {
return Container(
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
borderRadius: BorderRadius.circular(24),
),
child: const Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
Icons.groups_rounded,
color: Colors.white,
size: 38,
),
SizedBox(height: 16),
Text(
'Your travel crew.',
style: TextStyle(
color: Colors.white,
fontSize: 26,
fontWeight: FontWeight.w900,
),
),
SizedBox(height: 8),
Text(
'See everyone who is part of this trip '
'and share the trip code with people '
'you want to travel with.',
style: TextStyle(
color: Colors.white70,
fontSize: 14,
height: 1.5,
),
),
],
),
);
}

Widget _buildCodeCard() {
return Container(
padding: const EdgeInsets.all(22),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(22),
border: Border.all(
color: const Color(0xFFDCE7F0),
),
),
child: Column(
children: [
const Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.vpn_key_rounded,
color: Color(0xFF1677FF),
size: 18,
),
SizedBox(width: 7),
Text(
'TRIP CODE',
style: TextStyle(
color: Color(0xFF1677FF),
fontSize: 11,
fontWeight: FontWeight.w900,
letterSpacing: 1.2,
),
),
],
),
const SizedBox(height: 14),
Text(
_tripCode ?? '------',
style: const TextStyle(
color: Color(0xFF102A43),
fontSize: 32,
fontWeight: FontWeight.w900,
letterSpacing: 5,
),
),
const SizedBox(height: 8),
const Text(
'Share this code with people who should '
'join this trip.',
textAlign: TextAlign.center,
style: TextStyle(
color: Color(0xFF627D98),
fontSize: 13,
),
),
const SizedBox(height: 18),
SizedBox(
width: double.infinity,
height: 48,
child: FilledButton.icon(
onPressed:
_tripCode == null ? null : _copyCode,
icon: const Icon(
Icons.copy_rounded,
size: 19,
),
label: const Text(
'Copy Trip Code',
),
style: FilledButton.styleFrom(
backgroundColor:
const Color(0xFF1677FF),
shape: RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(14),
),
),
),
),
],
),
);
}

Widget _buildMembersHeader() {
return Row(
children: [
const Expanded(
child: Text(
'Travelers',
style: TextStyle(
color: Color(0xFF102A43),
fontSize: 20,
fontWeight: FontWeight.w900,
),
),
),
Text(
'${_members.length} joined',
style: const TextStyle(
color: Color(0xFF627D98),
fontWeight: FontWeight.w600,
),
),
],
);
}

Widget _buildEmptyMembersCard() {
return Container(
padding: const EdgeInsets.all(24),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: const Color(0xFFE3EAF1),
),
),
child: const Column(
children: [
Icon(
Icons.person_add_alt_1_rounded,
size: 38,
color: Color(0xFF1677FF),
),
SizedBox(height: 12),
Text(
'No travelers yet',
style: TextStyle(
color: Color(0xFF102A43),
fontWeight: FontWeight.w800,
fontSize: 16,
),
),
SizedBox(height: 6),
Text(
'Share the trip code to start planning '
'with your travel crew.',
textAlign: TextAlign.center,
style: TextStyle(
color: Color(0xFF627D98),
fontSize: 13,
height: 1.4,
),
),
],
),
);
}

Widget _buildMemberCard(
Map<String, dynamic> member,
) {
final name =
member['name']?.toString() ?? 'Traveler';

final email =
member['email']?.toString() ?? '';

final role =
member['role']?.toString() ?? 'member';

final isOwner = role == 'owner';

return Container(
margin: const EdgeInsets.only(bottom: 10),
padding: const EdgeInsets.all(15),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(17),
border: Border.all(
color: const Color(0xFFE3EAF1),
),
),
child: Row(
children: [
CircleAvatar(
radius: 22,
backgroundColor:
const Color(0xFFEAF3FF),
child: Text(
name.isEmpty
? '?'
    : name[0].toUpperCase(),
style: const TextStyle(
color: Color(0xFF1677FF),
fontWeight: FontWeight.w900,
),
),
),
const SizedBox(width: 13),
Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
name,
style: const TextStyle(
color: Color(0xFF102A43),
fontWeight: FontWeight.w800,
),
),
if (email.isNotEmpty)
Text(
email,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
color: Color(0xFF829AB1),
fontSize: 12,
),
),
],
),
),
Container(
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 5,
),
decoration: BoxDecoration(
color: isOwner
? const Color(0xFFFFF3E8)
    : const Color(0xFFEAF3FF),
borderRadius:
BorderRadius.circular(20),
),
child: Text(
isOwner ? 'Owner' : 'Traveler',
style: TextStyle(
color: isOwner
? const Color(0xFFFF7A45)
    : const Color(0xFF1677FF),
fontSize: 11,
fontWeight: FontWeight.w800,
),
),
),
],
),
);
}
}
