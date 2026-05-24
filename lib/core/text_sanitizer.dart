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
      'Ãƒ ': 'Ã ',
      'ÃƒÂ¢': 'Ã¢',
      'ÃƒÂ¤': 'Ã¤',
      'ÃƒÂ¡': 'Ã¡',
      'ÃƒÂ£': 'Ã£',
      'ÃƒÂ§': 'Ã§',
      'ÃƒÂ¨': 'Ã¨',
      'ÃƒÂ©': 'Ã©',
      'ÃƒÂª': 'Ãª',
      'ÃƒÂ«': 'Ã«',
      'ÃƒÂ®': 'Ã®',
      'ÃƒÂ¯': 'Ã¯',
      'ÃƒÂ¬': 'Ã¬',
      'ÃƒÂ­': 'Ã­',
      'ÃƒÂ´': 'Ã´',
      'ÃƒÂ¶': 'Ã¶',
      'ÃƒÂ²': 'Ã²',
      'ÃƒÂ³': 'Ã³',
      'ÃƒÂµ': 'Ãµ',
      'ÃƒÂ¹': 'Ã¹',
      'ÃƒÂº': 'Ãº',
      'ÃƒÂ»': 'Ã»',
      'ÃƒÂ¼': 'Ã¼',
      'Ãƒâ‚¬': 'Ã€',
      'Ãƒâ€š': 'Ã‚',
      'Ãƒâ€ž': 'Ã„',
      'ÃƒÂ': 'Ã',
      'Ãƒâ€¡': 'Ã‡',
      'ÃƒË†': 'Ãˆ',
      'Ãƒâ€°': 'Ã‰',
      'ÃƒÅ ': 'ÃŠ',
      'Ãƒâ€¹': 'Ã‹',
      'ÃƒÅ½': 'ÃŽ',
      'ÃƒÂ': 'Ã',
      'ÃƒÅ’': 'ÃŒ',
      'ÃƒÂ': 'Ã',
      'Ãƒâ€': 'Ã”',
      'Ãƒâ€“': 'Ã–',
      'Ãƒâ€™': 'Ã’',
      'Ãƒâ€œ': 'Ã“',
      'Ãƒâ„¢': 'Ã™',
      'ÃƒÅ¡': 'Ãš',
      'Ãƒâ€º': 'Ã›',
      'ÃƒÅ“': 'Ãœ',
      'Ã¢â‚¬â„¢': '\'',
      'Ã¢â‚¬"': '-',
      'Ã¢â‚¬â€œ': '-',
      'Ã‚Â·': 'Â·',
      'Ã‚ ': ' ',
      'Ãƒ': 'Ã ',
      'RÃƒÂ©': 'RÃ©',
      'appliquÃƒÂ©': 'appliquÃ©',
      'dÃƒÂ©croissant': 'dÃ©croissant',
      'dÃƒÂ©croissante': 'dÃ©croissante',
      'ÃƒÂ©largis': 'Ã©largis',
      'RemboursÃƒÂ©': 'RemboursÃ©',
      'dÃƒÂ©faut': 'dÃ©faut',
      'RefusÃƒÂ©': 'RefusÃ©',
      'AnnulÃƒÂ©': 'AnnulÃ©',
      'IntÃƒÂ©rÃƒÂªts': 'IntÃ©rÃªts',
      'Total dÃƒÂ»': 'Total dÃ»',
      'RemboursÃƒÂ© :': 'RemboursÃ© :',
      'Restant :': 'Restant :',
      'Ãƒâ€°chÃƒÂ©ance': 'Ã‰chÃ©ance',
      'PrÃƒÂªteur': 'PrÃªteur',
      'prÃƒÂªtez Ãƒ ': 'prÃªtez Ã  ',
      'apparaÃƒÂ®tra': 'apparaÃ®tra',
      'Aucun filtre avancÃƒÂ© appliquÃƒÂ©.': 'Aucun filtre avancÃ© appliquÃ©.',
      'RÃƒÂ©initialiser': 'RÃ©initialiser',
      'Classement apparaÃƒÂ®tra ici': 'Le classement apparaÃ®tra ici',
      'donnÃƒÂ©es': 'donnÃ©es',
      'PrÃƒÂ©nom': 'PrÃ©nom',
      'allÃƒÂ©gÃƒÂ©e': 'allÃ©gÃ©e',
      'formatÃƒÂ©': 'formatÃ©',
      'pr?t': 'prÃªt',
      'Pr?t': 'PrÃªt',
      'recu': 'reÃ§u',
      'Recu': 'ReÃ§u',
      'accepte': 'acceptÃ©',
      'Accepte': 'AcceptÃ©',
      'Enchere': 'Enchère',
      'enchere': 'enchère',
      'gagnee': 'gagnée',
      'Gagnee': 'Gagnée',
      'gagne :': 'gagné :',
      'Gagne :': 'Gagné :',
      'achete': 'acheté',
      'Achete': 'Acheté',
      'confirme': 'confirmé',
      'Confirme': 'Confirmé',
      'demandÃ©': 'demandé',
      'refusee': 'refusée',
      'Refusee': 'Refusée',
      'a ?t?': 'a Ã©tÃ©',
      '?tre': 'Ãªtre',
      'd?': 'dÃ»',
      '?ch?ance': 'Ã©chÃ©ance',
    };

    replacements.forEach((source, target) {
      result = result.replaceAll(source, target);
    });

    result = result
        .replaceAll('de prÃªt de', 'de prÃªt de')
        .replaceAll('acceptÃ©.', 'acceptÃ©.')
        .replaceAll('prÃªt accordÃ©', 'prÃªt accordÃ©');

    return result;
  }
}
