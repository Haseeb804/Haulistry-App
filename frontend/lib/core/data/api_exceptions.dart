class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException({String? message})
      : super(message: message ?? 'Please check your internet connection and try again');
}

/// User-friendly error message helper
class ErrorMessages {
  static const String noInternet = 'Please check your internet connection and try again';
  static const String connectionTimeout = 'Connection timed out. Please check your internet and try again';
  static const String serverError = 'Something went wrong. Please try again later';
  static const String unauthorized = 'Your session has expired. Please sign in again';
  
  /// Check if error is network-related and return friendly message
  static String getFriendlyMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no address associated') ||
        errorStr.contains('connection reset') ||
        errorStr.contains('connection closed') ||
        errorStr.contains('handshake')) {
      return noInternet;
    } else if (errorStr.contains('timeout')) {
      return connectionTimeout;
    } else if (errorStr.contains('401') || errorStr.contains('unauthorized')) {
      return unauthorized;
    }
    return serverError;
  }
}

class ServerException extends ApiException {
  ServerException({String? message, super.statusCode})
      : super(
          message: message ?? 'Server error occurred',
        );
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({String? message})
      : super(message: message ?? 'Unauthorized access', statusCode: 401);
}

class NotFoundException extends ApiException {
  NotFoundException({String? message})
      : super(message: message ?? 'Resource not found', statusCode: 404);
}

class ValidationException extends ApiException {
  ValidationException({String? message, super.data})
      : super(
          message: message ?? 'Validation error',
          statusCode: 422,
        );
}
