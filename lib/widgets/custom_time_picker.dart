import 'package:flutter/material.dart';

/// Shows a custom time picker dialog
/// This is a wrapper around the standard time picker that can be customized
Future<TimeOfDay?> showCustomTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  TransitionBuilder? builder,
  bool useRootNavigator = true,
}) async {
  // For now, we're just using the standard time picker
  // This can be customized later to use a wheel picker or other UI
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: builder,
    useRootNavigator: useRootNavigator,
  );
}
