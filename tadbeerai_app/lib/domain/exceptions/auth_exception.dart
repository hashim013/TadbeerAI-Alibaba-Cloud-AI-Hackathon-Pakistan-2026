/// Application-level authentication exception with user-friendly copy.
///
/// Ensures raw technical details, stack traces, or Firebase-specific error codes
/// never leak to the presentation layer.
class AuthException implements Exception {
  const AuthException({
    required this.message,
    this.code,
  });

  /// User-facing, clean, and friendly explanation.
  final String message;

  /// Optional machine code for testing or logging (not shown to user).
  final String? code;

  /// Factory creating an [AuthException] mapped from Firebase Auth error codes.
  factory AuthException.fromFirebaseCode(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return const AuthException(
          message: 'Email or password is incorrect.',
          code: 'invalid_credentials',
        );
      case 'invalid-email':
        return const AuthException(
          message: 'Please enter a valid email address.',
          code: 'invalid_email',
        );
      case 'email-already-in-use':
        return const AuthException(
          message: 'An account already exists with this email address.',
          code: 'email_already_in_use',
        );
      case 'weak-password':
        return const AuthException(
          message: 'Password is too weak. Please choose a stronger password.',
          code: 'weak_password',
        );
      case 'user-disabled':
        return const AuthException(
          message: 'Your account is currently unavailable.',
          code: 'account_disabled',
        );
      case 'network-request-failed':
        return const AuthException(
          message: 'Unable to connect. Please check your internet connection.',
          code: 'network_error',
        );
      case 'too-many-requests':
        return const AuthException(
          message: 'Too many attempts. Please try again later.',
          code: 'rate_limited',
        );
      case 'operation-not-allowed':
        return const AuthException(
          message: 'Email/password authentication is not enabled.',
          code: 'operation_not_allowed',
        );
      default:
        return const AuthException(
          message: 'Something went wrong. Please try again.',
          code: 'unknown_error',
        );
    }
  }

  @override
  String toString() => message;
}
