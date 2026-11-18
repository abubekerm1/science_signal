import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
          Text(result),
        ],
      ),
    );
  }
}
