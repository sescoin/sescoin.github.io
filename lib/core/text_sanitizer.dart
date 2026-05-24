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
      'Ã ': 'à',
      'Ã¢': 'â',
      'Ã¤': 'ä',
      'Ã¡': 'á',
      'Ã£': 'ã',
      'Ã§': 'ç',
      'Ã¨': 'è',
      'Ã©': 'é',
      'Ãª': 'ê',
      'Ã«': 'ë',
      'Ã®': 'î',
      'Ã¯': 'ï',
      'Ã¬': 'ì',
      'Ã­': 'í',
      'Ã´': 'ô',
      'Ã¶': 'ö',
      'Ã²': 'ò',
      'Ã³': 'ó',
      'Ãµ': 'õ',
      'Ã¹': 'ù',
      'Ãº': 'ú',
      'Ã»': 'û',
      'Ã¼': 'ü',
      'Ã€': 'À',
      'Ã‚': 'Â',
      'Ã„': 'Ä',
      'Ã': 'Á',
      'Ã‡': 'Ç',
      'Ãˆ': 'È',
      'Ã‰': 'É',
      'ÃŠ': 'Ê',
      'Ã‹': 'Ë',
      'ÃŽ': 'Î',
      'Ã': 'Ï',
      'ÃŒ': 'Ì',
      'Ã': 'Í',
      'Ã”': 'Ô',
      'Ã–': 'Ö',
      'Ã’': 'Ò',
      'Ã“': 'Ó',
      'Ã™': 'Ù',
      'Ãš': 'Ú',
      'Ã›': 'Û',
      'Ãœ': 'Ü',
      'â€™': '\'',
      'â€"': '-',
      'â€“': '-',
      'Â·': '·',
      'Â ': ' ',
      'Ã': 'à',
      'RÃ©': 'Ré',
      'appliquÃ©': 'appliqué',
      'dÃ©croissant': 'décroissant',
      'dÃ©croissante': 'décroissante',
      'Ã©largis': 'élargis',
      'RemboursÃ©': 'Remboursé',
      'dÃ©faut': 'défaut',
      'RefusÃ©': 'Refusé',
      'AnnulÃ©': 'Annulé',
      'IntÃ©rÃªts': 'Intérêts',
      'Total dÃ»': 'Total dû',
      'RemboursÃ© :': 'Remboursé :',
      'Restant :': 'Restant :',
      'Ã‰chÃ©ance': 'Échéance',
      'PrÃªteur': 'Prêteur',
      'prÃªtez Ã ': 'prêtez à ',
      'apparaÃ®tra': 'apparaîtra',
      'Aucun filtre avancÃ© appliquÃ©.': 'Aucun filtre avancé appliqué.',
      'RÃ©initialiser': 'Réinitialiser',
      'Classement apparaÃ®tra ici': 'Le classement apparaîtra ici',
      'donnÃ©es': 'données',
      'PrÃ©nom': 'Prénom',
      'allÃ©gÃ©e': 'allégée',
      'formatÃ©': 'formaté',
      'pr?t': 'prêt',
      'Pr?t': 'Prêt',
      'recu': 'reçu',
      'Recu': 'Reçu',
      'accepte': 'accepté',
      'Accepte': 'Accepté',
      'a ?t?': 'a été',
      '?tre': 'être',
      'd?': 'dû',
      '?ch?ance': 'échéance',
    };

    replacements.forEach((source, target) {
      result = result.replaceAll(source, target);
    });

    result = result
        .replaceAll('de prêt de', 'de prêt de')
        .replaceAll('accepté.', 'accepté.')
        .replaceAll('prêt accordé', 'prêt accordé');

    return result;
  }
}
