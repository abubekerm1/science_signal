import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> commit() async {
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

  Future<Timestamp?> readFromServer() async {
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
