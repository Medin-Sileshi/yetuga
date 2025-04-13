import 'package:hive/hive.dart';

part 'onboarding_cache.g.dart';

@HiveType(typeId: 2)
class OnboardingCache extends HiveObject {
  @HiveField(0)
  final String? accountType;

  @HiveField(1)
  final String? displayName;

  @HiveField(2)
  final String? username;

  @HiveField(3)
  final DateTime? birthday;

  @HiveField(4)
  final String? phoneNumber;

  @HiveField(5)
  final String? profileImageUrl;

  @HiveField(6)
  final List<String>? interests;

  @HiveField(7)
  final bool isComplete;

  OnboardingCache({
    this.accountType,
    this.displayName,
    this.username,
    this.birthday,
    this.phoneNumber,
    this.profileImageUrl,
    this.interests,
    this.isComplete = false,
  });

  factory OnboardingCache.fromJson(Map<String, dynamic> json) {
    return OnboardingCache(
      accountType: json['accountType'] as String?,
      displayName: json['displayName'] as String?,
      username: json['username'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      phoneNumber: json['phoneNumber'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      interests: json['interests'] != null
          ? List<String>.from(json['interests'] as List)
          : null,
      isComplete: json['isComplete'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountType': accountType,
      'displayName': displayName,
      'username': username,
      'birthday': birthday?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'interests': interests,
      'isComplete': isComplete,
    };
  }
}
