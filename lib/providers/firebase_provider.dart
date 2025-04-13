import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/utils/logger.dart';
import '../services/firebase_service.dart';

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});
