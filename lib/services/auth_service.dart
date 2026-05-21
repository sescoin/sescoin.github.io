import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/account_request.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  // ─── Getters ────────────────────────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  String? get currentUserId => currentUser?.id;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ─── Normalisation du username ───────────────────────────────────────────────

  /// Convertit "Éléonore" → "eleonore", "François" → "francois", etc.
  static String normalizeText(String input) {
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'á': 'a',
      'ã': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'í': 'i',
      'ì': 'i',
      'ô': 'o',
      'ö': 'o',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ú': 'u',
      'ç': 'c',
      'ñ': 'n',
      'ý': 'y',
      'ÿ': 'y',
      'À': 'a',
      'Â': 'a',
      'Ä': 'a',
      'Á': 'a',
      'È': 'e',
      'É': 'e',
      'Ê': 'e',
      'Ë': 'e',
      'Î': 'i',
      'Ï': 'i',
      'Í': 'i',
      'Ô': 'o',
      'Ö': 'o',
      'Ó': 'o',
      'Ù': 'u',
      'Û': 'u',
      'Ü': 'u',
      'Ú': 'u',
      'Ç': 'c',
      'Ñ': 'n',
    };
    var result = input;
    accents.forEach((accent, replacement) {
      result = result.replaceAll(accent, replacement);
    });
    return result.toLowerCase();
  }

  /// Génère "prenom.nom" à partir des deux champs
  static String generateUsername(String firstName, String lastName) {
    final first = normalizeText(firstName.trim());
    final last = normalizeText(lastName.trim());
    // Garde uniquement les lettres
    final cleanFirst = first.replaceAll(RegExp(r'[^a-z]'), '');
    final cleanLast = last.replaceAll(RegExp(r'[^a-z]'), '');
    return '$cleanFirst.$cleanLast';
  }

  /// Valide que le username ne contient que des lettres et un point
  static bool isValidUsername(String username) {
    return RegExp(r'^[a-z]+\.[a-z]+$').hasMatch(username);
  }

  // ─── Vérifications ───────────────────────────────────────────────────────────

  /// Vérifie si un username est déjà pris (profiles ou account_requests)
  Future<bool> isUsernameTaken(String username) async {
    final profileResult = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();

    if (profileResult != null) return true;

    final requestResult = await _client
        .from('account_requests')
        .select('id')
        .eq('username', username)
        .neq('status', 'rejected')
        .neq('status', 'cancelled')
        .maybeSingle();

    return requestResult != null;
  }

  /// Compte le nombre de demandes envoyées depuis cette IP / device (via metadata)
  Future<int> countRequestsByDevice(String deviceId) async {
    final result = await _client
        .from('account_requests')
        .select('id')
        .eq('device_id', deviceId);
    return (result as List).length;
  }

  // ─── Demande de compte ───────────────────────────────────────────────────────

  /// Soumet une demande de création de compte à la prof
  Future<AccountRequest> submitAccountRequest({
    required String firstName,
    required String lastName,
    required String password,
    required String avatarUrl,
    required String deviceId,
  }) async {
    final username = generateUsername(firstName, lastName);

    if (!isValidUsername(username)) {
      throw Exception('Username invalide : lettres uniquement.');
    }

    final taken = await isUsernameTaken(username);
    if (taken) {
      throw Exception('Ce nom est déjà pris ou en attente d\'approbation.');
    }

    final requestCount = await countRequestsByDevice(deviceId);
    if (requestCount >= 3) {
      throw Exception('Nombre maximum de demandes atteint pour cet appareil.');
    }

    // On stocke le mot de passe hashé côté Supabase via une fonction RPC
    // pour ne jamais manipuler le mot de passe en clair dans le client
    final response = await _client.rpc('submit_account_request', params: {
      'p_first_name': firstName,
      'p_last_name': lastName,
      'p_username': username,
      'p_password': password,
      'p_avatar_url': avatarUrl,
      'p_device_id': deviceId,
    });

    return AccountRequest.fromJson(response as Map<String, dynamic>);
  }

  // ─── Connexion / Déconnexion ─────────────────────────────────────────────────

  /// Connexion avec username + mot de passe
  /// Supabase Auth utilise un email fictif : username@sescoin.local
  Future<Profile> signIn({
    required String username,
    required String password,
  }) async {
    final fakeEmail = '${username.trim()}@sescoin.local';

    final response = await _client.auth.signInWithPassword(
      email: fakeEmail,
      password: password,
    );

    if (response.user == null) {
      throw Exception('Identifiant ou mot de passe incorrect.');
    }

    final profileData = await _client
        .from('profiles')
        .select()
        .eq('id', response.user!.id)
        .maybeSingle();

    if (profileData == null) {
      await _client.auth.signOut();
      throw Exception(
        'Aucun profil trouvé pour ce compte.\n'
        'Demande à l\'admin de recréer ton profil dans Supabase.',
      );
    }

    final profile = Profile.fromJson(profileData);

    if (profile.isBanned) {
      await _client.auth.signOut();
      throw Exception('Ce compte a été banni.');
    }

    return profile;
  }

  /// Déconnexion
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Session ─────────────────────────────────────────────────────────────────

  /// Récupère le profil de l'utilisateur connecté
  Future<Profile?> getCurrentProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final data =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Vérifie si la session est encore valide
  Future<bool> hasValidSession() async {
    final session = _client.auth.currentSession;
    if (session == null) return false;
    return !session.isExpired;
  }

  // ─── Mot de passe ────────────────────────────────────────────────────────────

  /// Change le mot de passe de l'utilisateur connecté
  Future<void> changePassword(String newPassword) async {
    if (newPassword.length < 8) {
      throw Exception('Le mot de passe doit contenir au moins 8 caractères.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Vérifie l'ancien mot de passe avant de changer le nouveau
  Future<void> changePasswordWithVerification(
    String oldPassword,
    String newPassword,
  ) async {
    final user = currentUser;
    if (user == null) throw Exception('Non connecté.');
    if (newPassword.length < 8) {
      throw Exception('Le nouveau mot de passe doit contenir au moins 8 caractères.');
    }
    final email = user.email;
    if (email == null) throw Exception('Email introuvable.');
    try {
      await _client.auth.signInWithPassword(email: email, password: oldPassword);
    } catch (_) {
      throw Exception('Mot de passe actuel incorrect.');
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
