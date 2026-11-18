import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AttemptCollision implements Exception {
  const AttemptCollision();
}

class AttemptStore {
  AttemptStore(String uid, String roundId, int score)
    : ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('attempts')
          .doc(roundId),
      fields = {
        'schemaVersion': 1,
        'variant': 'B',
        'categoryId': 17,
        'questionCount': 5,
        'correctCount': score,
      };

  final DocumentReference<Map<String, dynamic>> ref;
  final Map<String, Object> fields;

  bool matches(Map<String, dynamic> data) {
    return fields.entries.every((field) {
      final value = data[field.key];
      return value.runtimeType == field.value.runtimeType &&
          value == field.value;
    });
  }

  static int remainingT12Errors = 2;

  Future<void> commit() async {
    const testT12 = bool.fromEnvironment('SCIENCE_SIGNAL_T12');
    if (kDebugMode && testT12 && remainingT12Errors > 0) {
      final code = remainingT12Errors == 2
          ? 'unavailable'
          : 'resource-exhausted';
      remainingT12Errors--;
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: code,
        message: 'T12 injected save error',
      );
    }

    final payload = {...fields, 'submittedAt': FieldValue.serverTimestamp()};

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (!existing.exists) {
        transaction.set(ref, payload);
      } else if (!matches(existing.data()!)) {
        throw const AttemptCollision();
      }
    });
  }

  Future<Timestamp?> readFromServer({bool afterCommit = false}) async {
    const testT09 = bool.fromEnvironment('SCIENCE_SIGNAL_T09');
    if (kDebugMode && testT09 && afterCommit) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
        message: 'T09 injected verification failure',
      );
    }

    final verified = await ref.get(const GetOptions(source: Source.server));

    if (verified.metadata.isFromCache || verified.metadata.hasPendingWrites) {
      throw const FormatException('The server result is still unresolved.');
    }
    if (!verified.exists) return null;

    final data = verified.data()!;
    if (!matches(data)) throw const AttemptCollision();

    final timestamp = data['submittedAt'];
    if (data.length != 6 || timestamp is! Timestamp) {
      throw const FormatException('The server record is incomplete.');
    }
    return timestamp;
  }
}
