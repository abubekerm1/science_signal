import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'find_round_page.dart';
import 'quiz_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MaterialApp(home: SignInPage()));
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authChanges = FirebaseAuth.instance.authStateChanges();

  bool signingIn = false;
  String errorMessage = '';

  Future<void> signIn() async {
    if (signingIn) return;

    setState(() {
      signingIn = true;
      errorMessage = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (mounted) passwordController.clear();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Sign-in failed (${error.code}).';
      });
    } finally {
      if (mounted) {
        setState(() {
          signingIn = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Science Signal')),
      body: StreamBuilder<User?>(
        stream: authChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          if (user != null) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signed in as ${user.email}'),
                  Text('UID: ${user.uid}'),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => QuizPage(uid: user.uid),
                        ),
                      );
                    },
                    child: const Text('Start quiz'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => FindRoundPage(uid: user.uid),
                        ),
                      );
                    },
                    child: const Text('Find saved round'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: signingIn ? null : signIn,
                child: Text(signingIn ? 'Signing in...' : 'Sign in'),
              ),
              if (errorMessage.isNotEmpty)
                Text(errorMessage, style: const TextStyle(color: Colors.red)),
            ],
          );
        },
      ),
    );
  }
}
