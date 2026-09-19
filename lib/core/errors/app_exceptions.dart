class AppException implements Exception {
  AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

class VotingException extends AppException {
  VotingException(super.message, {super.code});
}

class ElectionException extends AppException {
  ElectionException(super.message, {super.code});
}
