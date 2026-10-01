
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_routes.dart';
import '../../models/trip.dart';
import '../../services/trip_service.dart';

class MyTripsScreen extends StatefulWidget {
const MyTripsScreen({super.key});

@override
State<MyTripsScreen> createState() =>
_MyTripsScreenState();
}

class _MyTripsScreenState
extends State<MyTripsScreen> {
final TripService _tripService = TripService();

final FirebaseFirestore _firestore =
FirebaseFirestore.instance;

final FirebaseAuth _auth =
FirebaseAuth.instance;

List<Trip> _trips = [];

final Map<String, bool> _ownership = {};

bool _loading = true;

String? _error;

@override
void initState() {
super.initState();
_loadTrips();
}

// ------------------------------------------------------------
// LOAD TRIPS
// ------------------------------------------------------------

Future<void> _loadTrips() async {
try {
if (mounted) {
setState(() {
_loading = true;
_error = null;
});
}

final trips =
await _tripService.getUserTrips();

final user = _auth.currentUser;

final ownership = <String, bool>{};

if (user != null) {
for (final trip in trips) {
ownership[trip.id] =
await _isTripOwner(
trip.id,
user.uid,
);
}
}

if (!mounted) {
return;
}

setState(() {
_trips = trips;

_ownership
..clear()
..addAll(ownership);

_loading = false;
});
} catch (e) {
if (!mounted) {
return;
}

setState(() {
_loading = false;
_error = e.toString();
});
}
}

// ------------------------------------------------------------
// CHECK OWNER
// ------------------------------------------------------------

Future<bool> _isTripOwner(
String tripId,
String userId,
) async {
final snapshot = await _firestore
    .collection('trips')
    .doc(tripId)
    .get();

if (!snapshot.exists) {
return false;
}

final data = snapshot.data();

return data?['userId']?.toString() ==
userId;
}

// ------------------------------------------------------------
// DELETE TRIP
// ------------------------------------------------------------

Future<void> _deleteTrip(Trip trip) async {
if (_ownership[trip.id] != true) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Only the trip owner can delete this trip.',
),
behavior: SnackBarBehavior.floating,
),
);

return;
}

final confirm =
await showDialog<bool>(
context: context,
builder: (context) {
return AlertDialog(
title: const Text(
'Delete Trip?',
),
content: Text(
'Are you sure you want to delete '
'"${trip.name.isEmpty ? trip.destination : trip.name}"?',
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(
context,
false,
);
},
child: const Text(
'Cancel',
),
),
ElevatedButton(
onPressed: () {
Navigator.pop(
context,
true,
);
},
child: const Text(
'Delete',
),
),
],
);
},
);

if (confirm != true) {
return;
}

try {
await _tripService.deleteTrip(
trip.id,
);

if (!mounted) {
return;
}

setState(() {
_trips.removeWhere(
(item) => item.id == trip.id,
);

_ownership.remove(trip.id);
});

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text(
'Trip deleted successfully.',
),
behavior: SnackBarBehavior.floating,
),
);
} catch (e) {
if (!mounted) {
return;
}

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(
'Failed to delete trip: $e',
),
behavior: SnackBarBehavior.floating,
),
);
}
}

// ------------------------------------------------------------
// OPEN TRIP
// ------------------------------------------------------------

void _openTrip(Trip trip) {
if (trip.id.isEmpty) {
return;
}

Navigator.pushNamed(
context,
AppRoutes.tripWorkspace,
arguments: {
'tripId': trip.id,
},
);
}

// ------------------------------------------------------------
// NEW TRIP / JOIN TRIP MENU
// ------------------------------------------------------------

void _showTripActions() {
showModalBottomSheet(
context: context,
backgroundColor: Colors.transparent,
builder: (sheetContext) {
return Container(
padding: const EdgeInsets.fromLTRB(
20,
12,
20,
30,
),
decoration: const BoxDecoration(
color: Colors.white,
borderRadius:
BorderRadius.vertical(
top: Radius.circular(28),
),
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 42,
height: 4,
decoration: BoxDecoration(
color:
const Color(0xFFD9E2EC),
borderRadius:
BorderRadius.circular(10),
),
),

const SizedBox(height: 22),

const Text(
'What would you like to do?',
style: TextStyle(
color: Color(0xFF102A43),
fontSize: 20,
fontWeight: FontWeight.w900,
),
),

const SizedBox(height: 18),

// CREATE NEW TRIP
ListTile(
leading: const CircleAvatar(
backgroundColor:
Color(0xFFEAF3FF),
child: Icon(
Icons.add_rounded,
color: Color(0xFF1677FF),
),
),
title: const Text(
'Create New Trip',
style: TextStyle(
fontWeight: FontWeight.w800,
),
),
subtitle: const Text(
'Plan your own trip',
),
onTap: () {
Navigator.pop(sheetContext);

Navigator.pushNamed(
context,
AppRoutes.tripDetails,
).then((_) {
_loadTrips();
});
},
),

const SizedBox(height: 6),

// JOIN TRIP
ListTile(
leading: const CircleAvatar(
backgroundColor:
Color(0xFFEAF8F2),
child: Icon(
Icons.group_add_rounded,
color: Color(0xFF16805C),
),
),
title: const Text(
'Join a Trip',
style: TextStyle(
fontWeight: FontWeight.w800,
),
),
subtitle: const Text(
'Enter a trip code from a friend',
),
onTap: () async {
Navigator.pop(sheetContext);

final result =
await Navigator.pushNamed(
context,
AppRoutes.joinTrip,
);

if (result != null) {
await _loadTrips();
}
},
),
],
),
);
},
);
}

// ------------------------------------------------------------
// FORMAT DATE
// ------------------------------------------------------------

String _formatDate(DateTime date) {
return '${date.day.toString().padLeft(2, '0')}/'
'${date.month.toString().padLeft(2, '0')}/'
'${date.year}';
}

// ------------------------------------------------------------
// BUILD
// ------------------------------------------------------------

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'My Trips',
),
actions: [
IconButton(
onPressed: _loadTrips,
icon: const Icon(
Icons.refresh,
),
tooltip: 'Refresh',
),
],
),
body: _buildBody(),
floatingActionButton:
FloatingActionButton.extended(
onPressed: _showTripActions,
icon: const Icon(
Icons.add,
),
label: const Text(
'Trip',
),
),
);
}

// ------------------------------------------------------------
// BODY
// ------------------------------------------------------------

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
mainAxisAlignment:
MainAxisAlignment.center,
children: [
const Icon(
Icons.error_outline,
size: 60,
),
const SizedBox(height: 16),
const Text(
'Unable to load trips',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 12),
Text(
_error!,
textAlign: TextAlign.center,
),
const SizedBox(height: 20),
ElevatedButton(
onPressed: _loadTrips,
child: const Text(
'Retry',
),
),
],
),
),
);
}

if (_trips.isEmpty) {
return Center(
child: Padding(
padding: const EdgeInsets.all(24),
child: Column(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
const Icon(
Icons.luggage_outlined,
size: 80,
),
const SizedBox(height: 20),
const Text(
'No Trips Yet',
style: TextStyle(
fontSize: 24,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
const Text(
'Create your first trip and your '
'itinerary will appear here.',
textAlign: TextAlign.center,
),
const SizedBox(height: 24),
ElevatedButton.icon(
onPressed: () {
Navigator.pushNamed(
context,
AppRoutes.tripDetails,
).then((_) {
_loadTrips();
});
},
icon: const Icon(
Icons.add,
),
label: const Text(
'Plan New Trip',
),
),
],
),
),
);
}

return RefreshIndicator(
onRefresh: _loadTrips,
child: ListView.builder(
padding: const EdgeInsets.fromLTRB(
16,
16,
16,
100,
),
itemCount: _trips.length,
itemBuilder: (context, index) {
final trip = _trips[index];

return _buildTripCard(trip);
},
),
);
}

// ------------------------------------------------------------
// TRIP CARD
// ------------------------------------------------------------

Widget _buildTripCard(Trip trip) {
final destination =
trip.destination.isEmpty
? 'Destination not selected'
    : trip.destination;

final isOwner =
_ownership[trip.id] == true;

return Card(
margin: const EdgeInsets.only(
bottom: 16,
),
elevation: 3,
clipBehavior: Clip.antiAlias,
child: InkWell(
onTap: () => _openTrip(trip),
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
CircleAvatar(
radius: 25,
child: const Icon(
Icons.flight_takeoff,
),
),

const SizedBox(width: 12),

Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Text(
trip.name.isEmpty
? destination
    : trip.name,
style: const TextStyle(
fontSize: 19,
fontWeight:
FontWeight.bold,
),
),

const SizedBox(height: 4),

if (trip.name.isNotEmpty)
Text(
destination,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style:
const TextStyle(
fontWeight:
FontWeight.w600,
),
),

Text(
'From: ${trip.startLocation}',
maxLines: 2,
overflow:
TextOverflow.ellipsis,
style:
const TextStyle(
color: Colors.grey,
),
),
],
),
),

const SizedBox(width: 8),

Container(
padding:
const EdgeInsets.symmetric(
horizontal: 9,
vertical: 5,
),
decoration: BoxDecoration(
color: isOwner
? const Color(0xFFEAF3FF)
    : const Color(0xFFEAF8F2),
borderRadius:
BorderRadius.circular(20),
),
child: Text(
isOwner ? 'Owner' : 'Joined',
style: TextStyle(
color: isOwner
? const Color(0xFF1677FF)
    : const Color(0xFF16805C),
fontSize: 11,
fontWeight:
FontWeight.w800,
),
),
),

PopupMenuButton<String>(
onSelected: (value) {
if (value == 'delete') {
_deleteTrip(trip);
}
},
itemBuilder: (context) => [
PopupMenuItem<String>(
value: 'delete',
enabled: isOwner,
child: Row(
children: [
const Icon(
Icons.delete_outline,
),
const SizedBox(width: 8),
Text(
isOwner
? 'Delete'
    : 'Owner only',
),
],
),
),
],
),
],
),

const SizedBox(height: 16),

const Divider(),

const SizedBox(height: 8),

Row(
children: [
Expanded(
child: _infoItem(
Icons.calendar_today,
'${_formatDate(trip.startDate)}'
' - '
'${_formatDate(trip.endDate)}',
),
),
Expanded(
child: _infoItem(
Icons.wb_sunny_outlined,
'${trip.numberOfDays} days',
),
),
],
),

const SizedBox(height: 12),

Row(
children: [
Expanded(
child: _infoItem(
Icons.people_outline,
'${trip.travelersCount} traveler'
'${trip.travelersCount == 1 ? '' : 's'}',
),
),
Expanded(
child: _infoItem(
Icons.currency_rupee,
'₹${trip.budget.toStringAsFixed(0)}',
),
),
],
),

const SizedBox(height: 14),

const Row(
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Icon(
Icons.touch_app_outlined,
size: 16,
color: Colors.grey,
),
SizedBox(width: 6),
Text(
'Tap to open trip',
style: TextStyle(
fontSize: 12,
color: Colors.grey,
),
),
],
),
],
),
),
),
);
}

// ------------------------------------------------------------
// INFO ITEM
// ------------------------------------------------------------

Widget _infoItem(
IconData icon,
String text,
) {
return Row(
children: [
Icon(
icon,
size: 20,
color: Colors.blue,
),
const SizedBox(width: 8),
Expanded(
child: Text(
text,
overflow: TextOverflow.ellipsis,
),
),
],
);
}
}
