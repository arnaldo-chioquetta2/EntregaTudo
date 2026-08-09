int? compareVersions(String a, String b) {
  final left = _parseVersion(a);
  final right = _parseVersion(b);
  if (left == null || right == null) return null;

  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final leftPart = index < left.length ? left[index] : 0;
    final rightPart = index < right.length ? right[index] : 0;
    if (leftPart != rightPart) return leftPart.compareTo(rightPart);
  }
  return 0;
}

List<int>? _parseVersion(String value) {
  var normalized = value.trim();
  if (normalized.startsWith('v') || normalized.startsWith('V')) {
    normalized = normalized.substring(1).trim();
  }
  if (normalized.isEmpty) return null;

  final parts = normalized.split('.');
  if (parts.length < 3 || parts.any((part) => !RegExp(r'^\d+$').hasMatch(part))) {
    return null;
  }
  return parts.map(int.parse).toList(growable: false);
}
