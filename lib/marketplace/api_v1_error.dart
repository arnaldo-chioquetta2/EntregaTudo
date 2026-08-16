class ApiV1Error {
  final int statusCode;
  final String? code;
  final String message;
  final Map<String, dynamic> errors;

  const ApiV1Error({
    required this.statusCode,
    required this.message,
    this.code,
    this.errors = const <String, dynamic>{},
  });

  @override
  String toString() =>
      'ApiV1Error(statusCode: $statusCode, code: $code, message: $message)';
}

class ApiV1Exception implements Exception {
  final ApiV1Error error;

  const ApiV1Exception(this.error);

  int get statusCode => error.statusCode;
  String? get code => error.code;
  String get message => error.message;
  Map<String, dynamic> get errors => error.errors;

  bool hasFieldError(String field, String code) {
    final value = errors[field];
    if (value is String) return value == code;
    if (value is Iterable) {
      return value.any((item) => item.toString() == code);
    }
    return false;
  }

  List<String> fieldErrors(String field) {
    final value = errors[field];
    if (value is String) return <String>[value];
    if (value is Iterable) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  @override
  String toString() => error.toString();
}
