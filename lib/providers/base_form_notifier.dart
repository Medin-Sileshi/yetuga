import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/logger.dart';

/// Base class for form notifiers to reduce code duplication
abstract class BaseFormNotifier<T> extends StateNotifier<T> {
  final String _tag;
  
  BaseFormNotifier(T initialState, this._tag) : super(initialState);
  
  /// Helper method to update a single field in the state
  /// Subclasses must implement this to handle their specific state type
  void updateField(String fieldName, dynamic value);
  
  /// Log a state update
  void logUpdate(String fieldName, dynamic value) {
    Logger.d(_tag, '$fieldName updated: $value');
  }
  
  /// Reset the state to initial values
  /// Subclasses must implement this to handle their specific state type
  void reset();
}
