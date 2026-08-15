import 'dart:io';

/// Écrit le fichier dans le dossier temporaire du système.
///
/// Sur mobile il n'existe pas d'équivalent au téléchargement du navigateur :
/// on retourne le chemin obtenu pour que l'appelant puisse l'indiquer.
Future<String?> saveTextFile(String fileName, String contents) async {
  try {
    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}$fileName',
    );
    // BOM en tête : sans lui, la plupart des lecteurs de texte mobiles
    // supposent un encodage local et affichent les accents de travers.
    await file.writeAsString('﻿$contents');
    return file.path;
  } catch (_) {
    return null;
  }
}
