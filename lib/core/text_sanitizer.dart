class TextSanitizer {
  TextSanitizer._();

  static String? nullable(String? value) {
    if (value == null) {
      return null;
    }
    return clean(value);
  }

  static String clean(String value) {
    var result = value;

    const replacements = {
      'ÃƒÆ’Ã†â€™': 'Ã',
      'Ãƒâ€šÃ‚': '',
      'Ã‚Â': '',
      'Â': '',
      'â€™': '\'',
      'â€œ': '"',
      'â€': '"',
      'â€“': '-',
      'â€”': '-',
      'â€¦': '...',
      'Ã ': 'à',
      'Ã¡': 'á',
      'Ã¢': 'â',
      'Ã£': 'ã',
      'Ã¤': 'ä',
      'Ã§': 'ç',
      'Ã¨': 'è',
      'Ã©': 'é',
      'Ãª': 'ê',
      'Ã«': 'ë',
      'Ã®': 'î',
      'Ã¯': 'ï',
      'Ã´': 'ô',
      'Ã¶': 'ö',
      'Ã¹': 'ù',
      'Ãº': 'ú',
      'Ã»': 'û',
      'Ã¼': 'ü',
      'Ã€': 'À',
      'Ã‰': 'É',
      'Ãˆ': 'È',
      'ÃŠ': 'Ê',
      'Ã‹': 'Ë',
      'ÃŽ': 'Î',
      'Ã”': 'Ô',
      'Ã™': 'Ù',
      'Ã›': 'Û',
      'pr?t': 'prêt',
      'Pr?t': 'Prêt',
      'recu': 'reçu',
      'Recu': 'Reçu',
      'accepte': 'accepté',
      'Accepte': 'Accepté',
      'accept?': 'accepté',
      'Accept?': 'Accepté',
      'a ?t?': 'a été',
      '?tre': 'être',
      'd?': 'dû',
      '?ch?ance': 'échéance',
    };

    replacements.forEach((source, target) {
      result = result.replaceAll(source, target);
    });

    return result;
  }
}
