String toCamelCase(String snakeCase) {
  List<String> words = snakeCase.split('_');
  String camelCase = words[0]; // Add the first word as it is

  for (int i = 1; i < words.length; i++) {
    String word = words[i];
    String capitalizedWord =
        word[0].toUpperCase() + word.substring(1).toLowerCase();
    camelCase += capitalizedWord;
  }
  return camelCase;
}

ucFirst(String str) {
  return str.substring(0, 1).toUpperCase() + str.substring(1);
}

lcFirst(String? str) {
  if (str == null) {
    return '';
  }
  return str.substring(0, 1).toLowerCase() + str.substring(1);
}
