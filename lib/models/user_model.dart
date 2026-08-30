import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
final String uid;
final String name;
final String email;
final DateTime createdAt;

UserModel({
required this.uid,
required this.name,
required this.email,
required this.createdAt,
});

// Convert UserModel → Firestore Map
Map<String, dynamic> toMap() {
return {
'uid': uid,
'name': name,
'email': email,
'createdAt': Timestamp.fromDate(createdAt),
};
}

// Convert Firestore Map → UserModel
factory UserModel.fromMap(Map<String, dynamic> map) {
return UserModel(
uid: map['uid'] ?? '',
name: map['name'] ?? '',
email: map['email'] ?? '',
createdAt: (map['createdAt'] as Timestamp).toDate(),
);
}
}