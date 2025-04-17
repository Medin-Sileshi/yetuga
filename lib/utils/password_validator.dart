class PasswordValidator {
  static bool hasMinLength(String password) => password.length >= 6;
  static bool hasUpperCase(String password) =>
      password.contains(RegExp(r'[A-Z]'));
  static bool hasLowerCase(String password) =>
      password.contains(RegExp(r'[a-z]'));
  static bool hasNumber(String password) => password.contains(RegExp(r'[0-9]'));
  static bool hasSymbol(String password) =>
      password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  static Map<String, bool> validatePassword(String password) {
    return {
      'minLength': hasMinLength(password),
      'uppercase': hasUpperCase(password),
      'lowercase': hasLowerCase(password),
      'number': hasNumber(password),
      'symbol': hasSymbol(password),
    };
  }

  static bool isPasswordValid(String password) {
    final validation = validatePassword(password);
    return validation.values.every((isValid) => isValid);
  }
}
