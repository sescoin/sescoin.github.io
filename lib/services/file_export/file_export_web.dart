import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Déclenche le téléchargement du fichier par le navigateur.
///
/// Passe par un Blob plutôt qu'une URL `data:` : celles-ci sont plafonnées en
/// longueur par certains navigateurs, ce qui tronquerait une transcription un
/// peu fournie.
Future<String?> saveTextFile(String fileName, String contents) async {
  try {
    // BOM en tête : sans lui, la plupart des lecteurs de texte mobiles
    // supposent un encodage local et affichent les accents de travers.
    final blob = web.Blob(
      ['﻿$contents'.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    // L'objet est retenu tant que l'URL vit : on la libère une fois le
    // téléchargement lancé.
    web.URL.revokeObjectURL(url);
    return 'Téléchargements';
  } catch (_) {
    return null;
  }
}
