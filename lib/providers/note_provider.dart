import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../utils/hive_box_manager.dart';

const _uuid = Uuid();

/// Provider for the Hive box containing notes
final noteBoxProvider = FutureProvider<Box<Note>>((ref) async {
  return await HiveBoxManager.get<Note>('notes');
});

/// Provider for the list of notes
final noteListProvider = StateNotifierProvider<NoteListNotifier, List<Note>>((
  ref,
) {
  return NoteListNotifier(ref);
});

class NoteListNotifier extends StateNotifier<List<Note>> {
  final Ref ref;
  Box<Note>? _box;

  NoteListNotifier(this.ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    try {
      _box = await HiveBoxManager.get<Note>('notes');
      state = _box!.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      // Handle error
      state = [];
    }
  }

  Future<void> addNote(String content) async {
    if (_box == null) return;

    final note = Note(
      id: _uuid.v4(),
      content: content.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _box!.put(note.id, note);
    state = [...state, note]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> updateNote(String id, String newContent) async {
    if (_box == null) return;

    final note = _box!.get(id);
    if (note != null) {
      final updated = note.copyWith(
        content: newContent.trim(),
        updatedAt: DateTime.now(),
      );
      await _box!.put(id, updated);
      state = _box!.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
  }

  Future<void> deleteNote(String id) async {
    if (_box == null) return;

    await _box!.delete(id);
    state = state.where((note) => note.id != id).toList();
  }

  Note? get latestNote => state.isEmpty ? null : state.first;
}
