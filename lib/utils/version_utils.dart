class VersionUtils {
  VersionUtils._();

  static List<int> parse(String version) {
    final normalized = version.split('+').first.trim();
    if (normalized.isEmpty) {
      return const [0];
    }

    return normalized
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList(growable: false);
  }

  static int compare(String left, String right) {
    final leftParts = parse(left);
    final rightParts = parse(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;

    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }

    return 0;
  }

  static bool isUpdateRequired({
    required String currentVersion,
    required String requiredVersion,
  }) {
    return compare(currentVersion, requiredVersion) < 0;
  }
}
