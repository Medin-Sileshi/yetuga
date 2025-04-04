import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/onboarding_cache.dart';

class OnboardingState {
  final String? accountType;
  final String? displayName;
  final String? username;
  final DateTime? birthday;
  final String? phoneNumber;
  final String? profileImageUrl;
  final List<String>? interests;
  final bool isComplete;

  OnboardingState({
    this.accountType,
    this.displayName,
    this.username,
    this.birthday,
    this.phoneNumber,
    this.profileImageUrl,
    this.interests,
    this.isComplete = false,
  });

  OnboardingState copyWith({
    String? accountType,
    String? displayName,
    String? username,
    DateTime? birthday,
    String? phoneNumber,
    String? profileImageUrl,
    List<String>? interests,
    bool? isComplete,
  }) {
    return OnboardingState(
      accountType: accountType ?? this.accountType,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      birthday: birthday ?? this.birthday,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      interests: interests ?? this.interests,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final Box<OnboardingCache> _box;

  OnboardingNotifier(this._box) : super(OnboardingState()) {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cache = _box.get('onboarding');
    if (cache != null) {
      state = OnboardingState(
        accountType: cache.accountType,
        displayName: cache.displayName,
        username: cache.username,
        birthday: cache.birthday,
        phoneNumber: cache.phoneNumber,
        profileImageUrl: cache.profileImageUrl,
        interests: cache.interests,
        isComplete: cache.isComplete,
      );
    }
  }

  void _saveToCache() {
    final cache = OnboardingCache(
      accountType: state.accountType,
      displayName: state.displayName,
      username: state.username,
      birthday: state.birthday,
      phoneNumber: state.phoneNumber,
      profileImageUrl: state.profileImageUrl,
      interests: state.interests,
      isComplete: state.isComplete,
    );
    _box.put('onboarding', cache);
  }

  void setAccountType(String type) {
    state = state.copyWith(accountType: type);
    _saveToCache();
  }

  void setDisplayName(String name, String username) {
    state = state.copyWith(displayName: name, username: username);
    _saveToCache();
  }

  void setUsername(String username) {
    state = state.copyWith(username: username);
    _saveToCache();
  }

  void setBirthday(DateTime date) {
    state = state.copyWith(birthday: date);
    _saveToCache();
  }

  void setPhoneNumber(String number) {
    state = state.copyWith(phoneNumber: number);
    _saveToCache();
  }

  void setProfileImage(String url) {
    state = state.copyWith(profileImageUrl: url);
    _saveToCache();
  }

  void setInterests(List<String> interests) {
    state = state.copyWith(interests: interests);
    _saveToCache();
  }

  void completeOnboarding() {
    state = state.copyWith(isComplete: true);
    _saveToCache();
  }

  void resetOnboarding() {
    state = OnboardingState();
    _box.delete('onboarding');
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final box = Hive.box<OnboardingCache>('onboarding');
  return OnboardingNotifier(box);
});
