/// Enregistrement d'un fichier texte généré par l'application.
///
/// L'implémentation est choisie à la compilation :
/// - `file_export_web.dart` : téléchargement par le navigateur ;
/// - `file_export_io.dart`  : écriture dans le dossier de documents.
///
/// `saveTextFile` renvoie une description de l'emplacement, à montrer à
/// l'utilisateur, ou `null` si l'enregistrement a échoué.
library;

export 'file_export_stub.dart'
    if (dart.library.io) 'file_export_io.dart'
    if (dart.library.js_interop) 'file_export_web.dart';
