final RegExp _variablePattern = RegExp(r'\{\{\s*([^{}]+?)\s*\}\}');

String interpolateString(String value, Map<String, String> variables) {
  return value.replaceAllMapped(_variablePattern, (match) {
    final key = match.group(1)?.trim() ?? '';
    if (variables.containsKey(key)) return variables[key]!;
    return match.group(0)!;
  });
}

dynamic interpolateUnknown(dynamic value, Map<String, String> variables) {
  if (value is String) return interpolateString(value, variables);
  if (value is List) {
    return value.map((item) => interpolateUnknown(item, variables)).toList();
  }
  if (value is Map) {
    return value.map(
      (key, item) =>
          MapEntry(key.toString(), interpolateUnknown(item, variables)),
    );
  }
  return value;
}

bool hasUnresolvedVariables(String value) {
  return RegExp(r'\{\{[^{}]+\}\}').hasMatch(value);
}
