import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class BeansInfoSection extends StatelessWidget {
  const BeansInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "set password for exchanging rewards and diamonds",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.6, color: Colors.black),
          ),
          const SizedBox(height: 8),
          _buildNumberedList([
            "After setting password, beans and diamonds can only be exchanged by user who knows the password.",
            "If you forget or need to reset your password, please contact us via Feedback on your profile page.",
          ]),
          const SizedBox(height: 20),
          const Text(
            "What are beans?",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.6, color: Colors.black),
          ),
          const SizedBox(height: 8),
          _buildNumberedList([
            "Beans can be exchanged to diamonds",
            "Beans can be exchanged to rewards",
          ]),
        ],
      ),
    );
  }

  Widget _buildNumberedList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final text = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, height: 1.6, color: Color(0xFF555555)),
              children: [
                TextSpan(text: "$index. "),
                _buildTextWithLink(text),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  TextSpan _buildTextWithLink(String text) {
    if (!text.contains("Feedback")) {
      return TextSpan(text: text);
    }

    final parts = text.split("Feedback");
    return TextSpan(
      children: [
        TextSpan(text: parts[0]),
        TextSpan(
          text: "Feedback",
          style: const TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.bold),
          recognizer: TapGestureRecognizer()..onTap = () {
            // Navigate to Feedback screen
          },
        ),
        TextSpan(text: parts[1]),
      ],
    );
  }
}
