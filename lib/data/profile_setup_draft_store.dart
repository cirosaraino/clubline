import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileSetupDraft {
  const ProfileSetupDraft({
    required this.nome,
    required this.cognome,
    required this.idConsole,
    required this.shirtNumber,
    required this.primaryRole,
    this.secondaryRoles = const [],
    this.accountEmail,
  });

  final String nome;
  final String cognome;
  final String idConsole;
  final int? shirtNumber;
  final String? primaryRole;
  final List<String> secondaryRoles;
  final String? accountEmail;

  bool get isValid =>
      nome.trim().isNotEmpty &&
      cognome.trim().isNotEmpty &&
      idConsole.trim().isNotEmpty &&
      shirtNumber != null &&
      (primaryRole?.trim().isNotEmpty == true);

  Map<String, dynamic> toMap() {
    return {
      'nome': nome.trim(),
      'cognome': cognome.trim(),
      'id_console': idConsole.trim(),
      'shirt_number': shirtNumber,
      'primary_role': primaryRole?.trim(),
      'secondary_roles': secondaryRoles,
      'account_email': accountEmail?.trim(),
    };
  }

  factory ProfileSetupDraft.fromMap(Map<String, dynamic> map) {
    final rawSecondaryRoles = map['secondary_roles'];
    return ProfileSetupDraft(
      nome: map['nome']?.toString() ?? '',
      cognome: map['cognome']?.toString() ?? '',
      idConsole: map['id_console']?.toString() ?? '',
      shirtNumber: map['shirt_number'] is num
          ? (map['shirt_number'] as num).toInt()
          : int.tryParse(map['shirt_number']?.toString() ?? ''),
      primaryRole: map['primary_role']?.toString(),
      secondaryRoles: rawSecondaryRoles is Iterable
          ? rawSecondaryRoles
                .map((role) => role?.toString().trim() ?? '')
                .where((role) => role.isNotEmpty)
                .toList()
          : const [],
      accountEmail: map['account_email']?.toString(),
    );
  }
}

class ProfileSetupDraftStore {
  ProfileSetupDraftStore._();

  static final instance = ProfileSetupDraftStore._();
  static const _storageKey = 'clubline_profile_setup_draft_v1';

  Future<void> save(ProfileSetupDraft draft) async {
    if (!draft.isValid) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(draft.toMap()));
  }

  Future<ProfileSetupDraft?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final rawValue = preferences.getString(_storageKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return null;
      }

      final draft = ProfileSetupDraft.fromMap(
        Map<String, dynamic>.from(decoded),
      );
      return draft.isValid ? draft : null;
    } catch (_) {
      return null;
    }
  }

  Future<ProfileSetupDraft?> loadForAccount(String? accountEmail) async {
    final normalizedAccountEmail = _normalizeAccountEmail(accountEmail);
    if (normalizedAccountEmail == null) {
      return null;
    }

    final draft = await load();
    final normalizedDraftEmail = _normalizeAccountEmail(draft?.accountEmail);
    if (draft == null || normalizedDraftEmail == null) {
      return null;
    }

    return normalizedDraftEmail == normalizedAccountEmail ? draft : null;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  String? _normalizeAccountEmail(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
