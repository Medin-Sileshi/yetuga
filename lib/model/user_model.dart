class UserModel {
  String userName;
  DateTime birthDay;
  String profilePic;
  String uid;

  UserModel({
    required this.userName,
    required this.birthDay,
    required this.profilePic,
    required this.uid,
  });

  // from map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userName: map['userName'] ?? '',
      birthDay: map['birthDay'] ?? '',
      profilePic: map['profilePic'] ?? '',
      uid: map['uid'] ?? '',
    );
  }

  // to map
  Map<String, dynamic> toMap() {
    return {
      "userName": userName,
      "birthDay": birthDay,
      "profilePic": profilePic,
      "ui": uid,
    };
  }
}
