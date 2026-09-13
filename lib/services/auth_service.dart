
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class AuthService {
final FirebaseAuth _auth = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// ------------------------------------------------------------
// REGISTER
// ------------------------------------------------------------

Future<UserCredential> register(
String name,
String email,
String password,
) async {
// Create account in Firebase Authentication
final UserCredential userCredential =
await _auth.createUserWithEmailAndPassword(
email: email,
password: password,
);

final User? user = userCredential.user;

if (user == null) {
throw Exception('User registration failed.');
}

// Create UserModel
final UserModel userModel = UserModel(
  uid: user.uid,
  name: name,
  email: email,
  createdAt: DateTime.now(),
  role: 'user',
);

// Save user information in Firestore
await _firestore
    .collection('users')
    .doc(user.uid)
    .set(userModel.toMap());

return userCredential;
}

// ------------------------------------------------------------
// LOGIN
// ------------------------------------------------------------

Future<UserCredential> login(
String email,
String password,
) async {
return await _auth.signInWithEmailAndPassword(
email: email,
password: password,
);
}

// ------------------------------------------------------------
// LOGOUT
// ------------------------------------------------------------

Future<void> logout() async {
await _auth.signOut();
}

// ------------------------------------------------------------
// RESET PASSWORD
// ------------------------------------------------------------

Future<void> resetPassword(String email) async {
await _auth.sendPasswordResetEmail(
email: email,
);
}

// ------------------------------------------------------------
// CURRENT USER
// ------------------------------------------------------------

User? get currentUser => _auth.currentUser;

// ------------------------------------------------------------
// GET USER PROFILE
// ------------------------------------------------------------

Future<UserModel?> getUserProfile() async {
final User? user = _auth.currentUser;

if (user == null) {
return null;
}

final DocumentSnapshot doc = await _firestore
    .collection('users')
    .doc(user.uid)
    .get();

if (!doc.exists) {
return null;
}

return UserModel.fromMap(
doc.data() as Map<String, dynamic>,
);
}
}
