import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TriviaQuestion {
  const TriviaQuestion(this.question, this.correctAnswer);

  final String question;
  final String correctAnswer;
}

DateTime? lastTriviaRequest;
int triviaTestCase = 0;

Future<List<TriviaQuestion>> loadTriviaQuestions() async {
  final now = DateTime.now();
  final lastRequest = lastTriviaRequest;

  if (lastRequest != null &&
      now.difference(lastRequest) < const Duration(seconds: 5)) {
    throw const FormatException('Wait five seconds before trying again.');
  }

  lastTriviaRequest = now;
  final url = Uri.parse(
    'https://opentdb.com/api.php?amount=5&category=17'
    '&difficulty=medium&type=boolean&encode=url3986',
  );
  const testT03 = bool.fromEnvironment('SCIENCE_SIGNAL_T03');
  final http.Response response;
  if (kDebugMode && testT03 && triviaTestCase < 3) {
    triviaTestCase++;
    response = makeTriviaTestResponse(triviaTestCase);
  } else {
    response = await http.get(url).timeout(const Duration(seconds: 10));
  }

  if (response.statusCode != 200) {
    throw FormatException(
      'Question request failed (HTTP ${response.statusCode}).',
    );
  }

  final data = jsonDecode(response.body);
  if (data is! Map || data['response_code'] != 0) {
    throw const FormatException(
      'OpenTDB did not return a successful response.',
    );
  }

  final results = data['results'];
  if (results is! List || results.length != 5) {
    throw const FormatException('Expected exactly five questions.');
  }

  final questions = <TriviaQuestion>[];
  for (final result in results) {
    if (result is! Map ||
        result['difficulty'] != 'medium' ||
        result['type'] != 'boolean') {
      throw const FormatException('Expected a medium True/False question.');
    }

    final wrongAnswers = result['incorrect_answers'];
    if (wrongAnswers is! List || wrongAnswers.length != 1) {
      throw const FormatException('Expected one incorrect answer.');
    }

    final category = decodeTriviaText(result['category']);
    final question = decodeTriviaText(result['question']);
    final correct = decodeTriviaText(result['correct_answer']);
    final wrong = decodeTriviaText(wrongAnswers.first);

    if (category != 'Science & Nature' ||
        question.trim().isEmpty ||
        !((correct == 'True' && wrong == 'False') ||
            (correct == 'False' && wrong == 'True'))) {
      throw const FormatException(
        'OpenTDB returned an invalid science question.',
      );
    }

    questions.add(TriviaQuestion(question, correct));
  }
  if (kDebugMode && testT03) {
    debugPrint('T02 encoded question: ${results.first['question']}');
    debugPrint('T02 decoded question: ${questions.first.question}');
  }
  return questions;
}

String decodeTriviaText(Object? value) {
  if (value is! String) {
    throw const FormatException('A question field is missing or invalid.');
  }

  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    throw const FormatException(
      'OpenTDB returned invalid percent-encoded text.',
    );
  } on ArgumentError {
    throw const FormatException(
      'OpenTDB returned invalid percent-encoded text.',
    );
  }
}

http.Response makeTriviaTestResponse(int testCase) {
  const sample = {
    'category': 'Science%20%26%20Nature',
    'difficulty': 'medium',
    'type': 'boolean',
    'question': 'Water%20contains%20hydrogen.',
    'correct_answer': 'True',
    'incorrect_answers': ['False'],
  };
  final results = List.generate(5, (_) => {...sample});
  var responseCode = 0;

  if (testCase == 1) {
    debugPrint('T03 test: injecting malformed percent encoding.');
    results[0]['question'] = '%ZZ';
  } else if (testCase == 2) {
    debugPrint('T03 test: injecting a nonzero response code.');
    responseCode = 1;
  } else {
    debugPrint('T03 test: injecting four results.');
    results.removeLast();
  }

  return http.Response(
    jsonEncode({'response_code': responseCode, 'results': results}),
    200,
  );
}
