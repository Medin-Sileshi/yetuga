import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreServices {
  // get collection of notes
  final CollectionReference userDetails =
      FirebaseFirestore.instance.collection('userDetails');

  // create: add user informations
  Future<void> addUserDetails(
    String userDetail,
    DateTime birthDay,
  ) {
    return userDetails.add({
      'nickname': userDetail,
      'BirthDay': birthDay,
    });
  }
}
