import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProfileSetupDraft {
  const ProfileSetupDraft({
    required this.nome,
    required this.cognome,
    required this.idConsole,
  });

  final String nome;
  final String cognome;
  final String idConsole;

  bool get isValid =>
      nome.trim().isNotEmpty &&
      cognome.trim().isNotEmpty &&
      idConsole.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'nome': nome.trim(),
      'cognome': cognome.trim(),
      'id_console': idConsole.trim(),
    };
  }

  factory ProfileSetupDraft.fromMap(Map<String, dynamic> map) {
    return ProfileSetupDraft(
      nome: map['nome']?.toString() ?? '',
      cognome: map['cognome']?.toString() ?? '',
      idConsole: map['id_console']?.toString() ?? '',
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

      final draft = ProfileSetupDraft.fromMap(Map<String, dynamic>.from(decoded));
      return draft.isValid ? draft : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }
}
