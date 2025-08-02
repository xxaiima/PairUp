import 'package:flutter/material.dart';
import '../widgets/custom_widgets.dart';
import '../themes/theme.dart';
import 'signup.dart';
import 'signin.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Icon(
                  Icons.group_add,
                  size: 100,
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
                const SizedBox(height: 20),
                Text(
                  "Achieve Goals\nTogether",
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  "PairUp and stay accountable\non your journey.",
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
                ),
                const Spacer(flex: 3),
                PrimaryButton(
                  text: "Create an Account",
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignUpScreen()),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignInScreen()),
                      ),
                      child: const Text("Log In"),
                    ),
                  ],
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
