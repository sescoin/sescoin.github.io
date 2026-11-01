/// Identifiant du compte administrateur (connexion inchangée).
const adminUsername = 'prof.ses';

/// Nom sous lequel l'administrateur apparaît dans l'application.
const adminPublicName = 'Mme Kajouj-Bouchelaghem';

/// « @identifiant » d'un compte, tel qu'affiché dans l'application.
///
/// L'administrateur apparaît sous son nom public plutôt que sous son
/// identifiant technique. Accepte aussi un nom affiché : certains écrans
/// n'ont que lui.
String userHandle(String? username) {
  final name = (username ?? '').trim();
  if (name.isEmpty) return '@?';
  if (isAdminName(name)) return adminPublicName;
  return '@$name';
}

/// Nom à afficher pour un compte : son nom tel quel (sans « @ »), ou à
/// défaut « @identifiant ». L'administrateur apparaît sous son nom public.
String userLabel({String? displayName, String? username}) {
  if (isAdminName(username) || isAdminName(displayName)) {
    return adminPublicName;
  }
  final name = (displayName ?? '').trim();
  if (name.isNotEmpty) return name;
  if ((username ?? '').trim().isEmpty) return 'Inconnu';
  return userHandle(username);
}

/// Vrai pour l'identifiant ou le nom public de l'administrateur.
bool isAdminName(String? name) {
  final value = (name ?? '').trim().toLowerCase();
  return value == adminUsername || value == adminPublicName.toLowerCase();
}
