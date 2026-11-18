import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    startRound();
  }

  Future<void> startRound() async {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Science Signal')),
      body: buildQuizBody(),
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
          ElevatedButton(onPressed: startRound, child: const Text('Replay')),
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
