class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class UserNotAuthenticatedException extends AuthException {
  const UserNotAuthenticatedException() : super('User not authenticated');
}

class UsernameAlreadyExistsException extends AuthException {
  const UsernameAlreadyExistsException() : super('Username already exists');
}

class ValidationException extends AuthException {
  const ValidationException(String message) : super(message);
}

class FirebaseOperationException extends AuthException {
  const FirebaseOperationException(String message) : super(message);
}