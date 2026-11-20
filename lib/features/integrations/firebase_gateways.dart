import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/database/app_database.dart';
import 'integration_contracts.dart';

class FirebaseAuthGateway implements AuthGateway {
  const FirebaseAuthGateway(this._auth);

  final FirebaseAuth _auth;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> createAccountWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut({required bool preserveLocalData}) => _auth.signOut();

  @override
  Future<void> signInWithGoogle() =>
      Future.error(const IntegrationNotConfiguredException('Login Google'));

  @override
  Future<void> signInWithSteam() =>
      Future.error(const IntegrationNotConfiguredException('Login Steam'));

  @override
  Future<void> signInWithEpic() =>
      Future.error(const IntegrationNotConfiguredException('Login Epic Games'));

  @override
  Future<void> linkProvider(AccountProvider provider) => Future.error(
    IntegrationNotConfiguredException('Vinculação de ${provider.name}'),
  );
}

class FirebaseSyncBackend implements SyncBackend {
  FirebaseSyncBackend({
    required AppDatabase database,
    required String userId,
    FirebaseFirestore? firestore,
  }) : _database = database,
       _userId = userId,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final AppDatabase _database;
  final String _userId;
  final FirebaseFirestore _firestore;
  bool _syncing = false;

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('users').doc(_userId).collection('games');

  CollectionReference<Map<String, dynamic>> get _preferences =>
      _firestore.collection('users').doc(_userId).collection('preferences');

  @override
  Future<void> syncPendingChanges() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final operations = await _database.getPendingOperations();
      for (final operation in operations) {
        final operationId = operation['operation_id']! as String;
        final entityId = operation['entity_id']! as String;
        try {
          final type = operation['operation_type']! as String;
          final payload =
              jsonDecode(operation['payload']! as String)
                  as Map<String, dynamic>;
          if (type == 'preference') {
            await _syncPreference(
              operationId: operationId,
              entityId: entityId,
              payload: payload,
            );
          } else {
            await _syncGame(
              operationId: operationId,
              entityId: entityId,
              payload: payload,
            );
          }
        } catch (error) {
          await _database.markSyncOperationFailed(
            operationId: operationId,
            error: error.toString(),
          );
          rethrow;
        }
      }

      await _pullRemoteGames();
      await _pullRemotePreferences();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncGame({
    required String operationId,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final document = _games.doc(entityId);
    final remote = await document.get();
    final remoteData = remote.data();
    final localUpdatedAt = _dateValue(payload['updatedAt']);
    final remoteUpdatedAt = _dateValue(remoteData?['updatedAt']);

    if (remoteData != null &&
        remoteUpdatedAt != null &&
        (localUpdatedAt == null || !localUpdatedAt.isAfter(remoteUpdatedAt))) {
      await _database.markSyncOperationSynced(
        operationId: operationId,
        entityId: entityId,
      );
      await _database.applyRemoteGame({...remoteData, 'id': entityId});
      return;
    }

    final remotePayload = Map<String, dynamic>.from(payload)
      ..remove('localSyncStatus')
      ..remove('remoteVersion');
    await document.set(remotePayload);
    await _database.markSyncOperationSynced(
      operationId: operationId,
      entityId: entityId,
    );
  }

  Future<void> _syncPreference({
    required String operationId,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final key = payload['key'] as String?;
    if (key == null || key.isEmpty) {
      throw const FormatException('Preferência sem chave.');
    }

    final document = _preferences.doc(key);
    final remote = await document.get();
    final remoteData = remote.data();
    final localUpdatedAt = _dateValue(payload['updatedAt']);
    final remoteUpdatedAt = _dateValue(remoteData?['updatedAt']);

    if (remoteData != null &&
        remoteUpdatedAt != null &&
        (localUpdatedAt == null || !localUpdatedAt.isAfter(remoteUpdatedAt))) {
      await _database.markSyncOperationSynced(
        operationId: operationId,
        entityId: entityId,
      );
      await _database.applyRemotePreference(
        key: key,
        value: remoteData['value'] as String? ?? '',
        updatedAt: remoteData['updatedAt'] as String? ?? '',
      );
      return;
    }

    await document.set(payload);
    await _database.markSyncOperationSynced(
      operationId: operationId,
      entityId: entityId,
    );
  }

  Future<void> _pullRemoteGames() async {
    final snapshot = await _games.get();
    for (final document in snapshot.docs) {
      await _database.applyRemoteGame({...document.data(), 'id': document.id});
    }
  }

  Future<void> _pullRemotePreferences() async {
    final snapshot = await _preferences.get();
    for (final document in snapshot.docs) {
      final data = document.data();
      final key = data['key'] as String? ?? document.id;
      final value = data['value'] as String?;
      final updatedAt = data['updatedAt'] as String?;
      if (value == null || updatedAt == null) continue;
      await _database.applyRemotePreference(
        key: key,
        value: value,
        updatedAt: updatedAt,
      );
    }
  }

  DateTime? _dateValue(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
