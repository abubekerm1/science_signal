import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'attempt_store.dart';
import 'trivia.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.uid});

  final String uid;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<TriviaQuestion> questions = [];
  final answers = <String>[];
  int questionIndex = 0;
  int score = 0;
  bool loading = true;
  bool finished = false;
  String errorMessage = '';
  String roundId = '';
  bool saving = false;
  bool saveStarted = false;
  bool writeAcknowledged = false;
  bool collision = false;
  Timestamp? verifiedAt;
  String cloudMessage = '';

  bool get unresolved =>
      saving || (saveStarted && verifiedAt == null && !collision);

  bool isCurrentRound(String id) {
    return mounted &&
        roundId == id &&
        FirebaseAuth.instance.currentUser?.uid == widget.uid;
  }

  Future<void> submitScore() async {
    final id = roundId;
    if (!finished ||
        saving ||
        collision ||
        verifiedAt != null ||
        !isCurrentRound(id)) {
      return;
    }

    final store = AttemptStore(widget.uid, id, score);
    final reconcile = saveStarted;
    var timedOut = false;

    setState(() {
      saving = true;
      saveStarted = true;
      cloudMessage = reconcile
          ? 'Checking the original round…'
          : 'Saving score…';
    });

    final timer = Timer(const Duration(seconds: 10), () {
      timedOut = true;
      if (!isCurrentRound(id)) return;
      setState(() {
        cloudMessage = writeAcknowledged
            ? 'Write acknowledged; verification unavailable.'
            : 'Save status unknown. Waiting for the current request to finish.';
      });
    });

    try {
      Timestamp? timestamp;
      if (reconcile) {
        timestamp = await store.readFromServer();
      }

      if (timedOut || !isCurrentRound(id)) return;
      if (timestamp == null && !writeAcknowledged) {
        await store.commit();
        if (!isCurrentRound(id)) return;
        setState(() {
          writeAcknowledged = true;
          cloudMessage = timedOut
              ? 'Write acknowledged; verification unavailable.'
              : 'Write acknowledged. Checking the server…';
        });

        if (timedOut) return;
        timestamp = await store.readFromServer(afterCommit: true);
      }

      if (!isCurrentRound(id) || timedOut) return;
      if (timestamp == null) {
        throw const FormatException('The server did not return the round.');
      }

      setState(() {
        verifiedAt = timestamp;
        cloudMessage = 'Cloud verified';
      });
    } on AttemptCollision {
      if (!isCurrentRound(id)) return;
      setState(() {
        collision = true;
        cloudMessage = 'This round ID already has a different score or schema.';
      });
    } on FirebaseException catch (error) {
      if (!isCurrentRound(id)) return;
      final detail = switch (error.code) {
        'permission-denied' =>
          error.message == 'T09 injected verification failure'
              ? 'T09 test: injected permission-denied.'
              : 'Firestore permission denied.',
        'unauthenticated' => 'Your sign-in session is unavailable.',
        'resource-exhausted' => 'Firestore quota limit reached.',
        'unavailable' => 'Firestore is unavailable. Check your connection.',
        _ => 'Firestore error (${error.code}).',
      };
      if (error.message == 'T12 injected save error') {
        showCloudError('T12 test: injected ${error.code}. $detail');
      } else {
        showCloudError(detail);
      }
    } on FormatException catch (error) {
      if (isCurrentRound(id)) showCloudError(error.message);
    } finally {
      timer.cancel();
      if (isCurrentRound(id)) {
        setState(() {
          saving = false;
        });
      } else if (mounted && roundId == id) {
        setState(() {
          saving = false;
          cloudMessage = 'The signed-in account changed.';
        });
      }
    }
  }

  void showCloudError(String detail) {
    setState(() {
      final status = writeAcknowledged
          ? 'Write acknowledged; verification unavailable.'
          : 'Save status unknown.';
      cloudMessage = '$status $detail';
    });
  }

  @override
  void initState() {
    super.initState();
    startRound();
  }

  Future<void> startRound() async {
    if (unresolved) return;
    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      final newQuestions = await loadTriviaQuestions();
      if (!mounted) return;

      final attempts = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('attempts');
      final newRoundId = attempts.doc().id;

      setState(() {
        questions = newQuestions;
        roundId = newRoundId;
        answers.clear();
        questionIndex = 0;
        score = 0;
        finished = false;
        saveStarted = false;
        writeAcknowledged = false;
        collision = false;
        verifiedAt = null;
        cloudMessage = '';
      });
    } on TimeoutException {
      errorMessage = 'The question request timed out. Try again.';
    } on FormatException catch (error) {
      errorMessage = error.message;
    } catch (_) {
      errorMessage = 'Could not load questions. Check your connection.';
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void chooseAnswer(String answer) {
    if (answers.length > questionIndex) return;

    setState(() {
      answers.add(answer);
      if (answer == questions[questionIndex].correctAnswer) {
        score++;
      }
    });
  }

  void nextQuestion() {
    if (answers.length != questionIndex + 1) return;

    setState(() {
      if (questionIndex == questions.length - 1) {
        finished = true;
      } else {
        questionIndex++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !unresolved || FirebaseAuth.instance.currentUser?.uid != widget.uid,
      child: Scaffold(
        appBar: AppBar(title: const Text('Science Signal')),
        body: buildQuizBody(),
      ),
    );
  }

  Widget buildQuizBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(errorMessage),
          ElevatedButton(onPressed: startRound, child: const Text('Retry')),
        ],
      );
    }

    if (finished) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Score: $score/${questions.length}'),
          Text('Round: …${roundId.substring(roundId.length - 4)}'),
          if (cloudMessage.isNotEmpty) Text(cloudMessage),
          if (verifiedAt != null)
            Text('Server timestamp: ${verifiedAt!.toDate().toUtc()}'),
          if (verifiedAt == null && !collision)
            ElevatedButton(
              onPressed: saving ? null : submitScore,
              child: Text(saveStarted ? 'Retry cloud check' : 'Submit score'),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < questions.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${i + 1}. ${questions[i].question}'),
              subtitle: Text(
                'Your answer: ${answers[i]}\n'
                'Correct answer: ${questions[i].correctAnswer}',
              ),
            ),
          ElevatedButton(
            onPressed: unresolved ? null : startRound,
            child: const Text('Replay'),
          ),
        ],
      );
    }

    final question = questions[questionIndex];
    final answered = answers.length > questionIndex;
    final correct =
        answered && answers[questionIndex] == question.correctAnswer;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Question ${questionIndex + 1} of ${questions.length}'),
        LinearProgressIndicator(value: answers.length / questions.length),
        const SizedBox(height: 20),
        Text(question.question),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: answered ? null : () => chooseAnswer('True'),
          child: const Text('True'),
        ),
        ElevatedButton(
          onPressed: answered ? null : () => chooseAnswer('False'),
          child: const Text('False'),
        ),
        if (answered)
          Text(
            correct
                ? 'Correct!'
                : 'Incorrect. Answer: ${question.correctAnswer}',
            style: TextStyle(
              color: correct ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        Text('Score: $score'),
        ElevatedButton(
          onPressed: answered ? nextQuestion : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
