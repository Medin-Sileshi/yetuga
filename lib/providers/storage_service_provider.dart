import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yetuga/utils/logger.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
