import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/note.dart';
import 'notes_repository.dart';

/// Provider do repositório por teamId.
final notesRepositoryProvider =
    Provider.family<NotesRepository, String>((ref, teamId) {
  return NotesRepository(teamId);
});

/// Lista de notas do team. Invalide pra forçar refetch.
final notesListProvider =
    AutoDisposeFutureProvider.family<List<NoteSummary>, String>(
        (ref, teamId) async {
  final repo = ref.watch(notesRepositoryProvider(teamId));
  return repo.list();
});

/// Argumento composto para carregar uma nota.
class NoteKey {
  const NoteKey(this.teamId, this.name);
  final String teamId;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is NoteKey && other.teamId == teamId && other.name == name;

  @override
  int get hashCode => Object.hash(teamId, name);
}

/// Nota individual. Invalide ao salvar/deletar.
final noteProvider =
    AutoDisposeFutureProvider.family<Note, NoteKey>((ref, key) async {
  final repo = ref.watch(notesRepositoryProvider(key.teamId));
  return repo.read(key.name);
});
