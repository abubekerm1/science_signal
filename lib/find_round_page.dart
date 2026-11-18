import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'attempt_store.dart';

class FindRoundPage extends StatefulWidget {
  const FindRoundPage({super.key, required this.uid});

  final String uid;

  @override
  State<FindRoundPage> createState() => _FindRoundPageState();
}

class _FindRoundPageState extends State<FindRoundPage> {
  final roundController = TextEditingController();
  final ownerController = TextEditingController();

  bool get showOwnerTest =>
      kDebugMode &&
      const bool.fromEnvironment('SCIENCE_SIGNAL_T10') &&
      FirebaseAuth.instance.currentUser?.email ==
          'science-signal-b@example.com';

  Future<void> runOwnerTest() async {
    if (!showOwnerTest || lookingUp) return;

    final owner = ownerController.text.trim();
    final id = roundController.text.trim();
    if (owner.isEmpty ||
        owner.contains('/') ||
        owner == widget.uid ||
        !RegExp(r'^[a-zA-Z0-9]{20}$').hasMatch(id)) {
      setState(() {
        result = 'Enter User A’s UID and the full saved round ID.';
      });
      return;
    }

    setState(() {
      lookingUp = true;
      result = 'Running T10 against Firestore…';
    });

    final attempts = FirebaseFirestore.instance
        .collection('users')
        .doc(owner)
        .collection('attempts');
    final readResult = await checkDenial(() async {
      await attempts.doc(id).get(const GetOptions(source: Source.server));
    });
    var writeResult = 'Skipped because the signed-in account changed.';
    if (FirebaseAuth.instance.currentUser?.uid == widget.uid) {
      writeResult = await checkDenial(() async {
        await attempts
            .doc()
            .set({
              'schemaVersion': 1,
              'variant': 'B',
              'categoryId': 17,
              'questionCount': 5,
              'correctCount': 0,
              'submittedAt': FieldValue.serverTimestamp(),
            })
            .timeout(const Duration(seconds: 10));
      });
    }

    if (!mounted) return;
    setState(() {
      lookingUp = false;
      result = FirebaseAuth.instance.currentUser?.uid == widget.uid
          ? 'T10 — User B targeting User A\n'
                'Server read: $readResult\n'
                'Create attempt: $writeResult'
          : 'The signed-in account changed.';
    });
  }

  bool get showSchemaTest =>
      kDebugMode &&
      const bool.fromEnvironment('SCIENCE_SIGNAL_T11') &&
      FirebaseAuth.instance.currentUser?.email ==
          'science-signal-a@example.com';

  Future<void> runSchemaTest() async {
    if (!showSchemaTest ||
        lookingUp ||
        FirebaseAuth.instance.currentUser?.uid != widget.uid) {
      return;
    }

    final id = roundController.text.trim();
    if (!RegExp(r'^[a-zA-Z0-9]{20}$').hasMatch(id)) {
      setState(() => result = 'Enter the full ID of your saved round.');
      return;
    }

    setState(() {
      lookingUp = true;
      result = 'Running T11 against Firestore…';
    });

    final original = AttemptStore(widget.uid, id, 2);
    final attempts = original.ref.parent;
    final validFields = {
      ...original.fields,
      'submittedAt': FieldValue.serverTimestamp(),
    };

    final badScore = await checkDenial(
      () => attempts.doc().set({...validFields, 'correctCount': 6}),
    );
    final extraField = await checkDenial(
      () => attempts.doc().set({...validFields, 'testOnly': true}),
    );
    final update = await checkDenial(
      () => original.ref.update({'correctCount': 1}),
    );

    if (!mounted) return;
    setState(() {
      lookingUp = false;
      result =
          'T11 — Firestore validation\n'
          'Create with score 6: $badScore\n'
          'Create with extra field: $extraField\n'
          'Update existing round: $update';
    });
  }

  Future<String> checkDenial(Future<void> Function() request) async {
    try {
      await request().timeout(const Duration(seconds: 10));
      return 'Unexpectedly allowed';
    } on FirebaseException catch (error) {
      return error.code;
    } on TimeoutException {
      return 'Timed out. Run again while online.';
    }
  }

  bool lookingUp = false;
  String result = '';

  Future<void> findRound() async {
    if (lookingUp || FirebaseAuth.instance.currentUser?.uid != widget.uid) {
      return;
    }

    final id = roundController.text.trim();
    if (!RegExp(r'^[a-zA-Z0-9]{20}$').hasMatch(id)) {
      setState(() {
        result = 'Enter the full round ID from Firestore.';
      });
      return;
    }

    setState(() {
      lookingUp = true;
      result = 'Reading from the server…';
    });

    var message = '';
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('attempts')
          .doc(id);
      final verified = await ref
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));
      final data = verified.data();

      if (verified.metadata.isFromCache || verified.metadata.hasPendingWrites) {
        message = 'The server result is still unresolved.';
      } else if (data == null) {
        message = 'No saved round with that ID was found for this account.';
      } else {
        final score = data['correctCount'];
        final timestamp = data['submittedAt'];
        if (score is int &&
            score >= 0 &&
            score <= 5 &&
            timestamp is Timestamp &&
            data.length == 6 &&
            AttemptStore(widget.uid, id, score).matches(data)) {
          message =
              'Cloud verified\n'
              'Round: …${id.substring(id.length - 4)}\n'
              'Score: $score/5\n'
              'Server timestamp: ${timestamp.toDate().toUtc()}';
        } else {
          message = 'The server record does not match the Class B schema.';
        }
      }
    } on TimeoutException {
      message = 'The server read timed out. Try again.';
    } on FirebaseException catch (error) {
      message = 'Could not read the saved round (${error.code}).';
    } finally {
      if (mounted) {
        setState(() {
          lookingUp = false;
          result = FirebaseAuth.instance.currentUser?.uid == widget.uid
              ? message
              : 'The signed-in account changed.';
        });
      }
    }
  }

  @override
  void dispose() {
    roundController.dispose();
    ownerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find saved round')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: roundController,
            enabled: !lookingUp,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Full round ID'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: lookingUp ? null : findRound,
            child: const Text('Read from server'),
          ),
          const SizedBox(height: 12),
          if (showOwnerTest) ...[
            TextField(
              controller: ownerController,
              enabled: !lookingUp,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'User A UID'),
            ),
            OutlinedButton(
              onPressed: lookingUp ? null : runOwnerTest,
              child: const Text('Run T10 ownership test'),
            ),
          ],
          if (showSchemaTest)
            OutlinedButton(
              onPressed: lookingUp ? null : runSchemaTest,
              child: const Text('Run T11 validation test'),
            ),
          Text(result),
        ],
      ),
    );
  }
}
