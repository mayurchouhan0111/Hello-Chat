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
          _buildInfoText("set password for exchanging rewards and diamonds", isBold: true),
          const SizedBox(height: 8),
          _buildNumberedList([
            "After setting password, beans and diamonds can only be exchanged by user who knows the password.",
            "If you forget or need to reset your password, please contact us via Feedback on your profile page.",
          ]),
          const SizedBox(height: 16),
          _buildInfoText("What are beans?", isBold: true),
          const SizedBox(height: 8),
          _buildNumberedList([
            "Beans can be exchanged to diamonds",
            "Beans can be exchanged to rewards",
          ]),
          const SizedBox(height: 16),
          _buildInfoText("Exchange rules", isBold: true),
          const SizedBox(height: 8),
          _buildNumberedList([
            "The maximum daily withdrawal amount is USD500, and users cannot withdraw any more on the day after withdrawing USD500.",
            "How to increase daily withdrawal limit: The actual daily withdrawal amount will be limited by the withdrawal channel you choose. The normal daily withdrawal rules are as follows:",
          ]),
          const SizedBox(height: 12),
          _buildWithdrawalTable(),
          const SizedBox(height: 16),
          _buildNumberedList([
            "The audit time of bean is within 3 working days.",
            "Estimated arrival amount and processing fee are subject to the actual credited amount.",
          ], startIndex: 3),
          const SizedBox(height: 12),
          const Text(
            "Under certain circumstances, we will notify the change or update of the Bean redemption rules in advance through IM. Please pay attention to the IM notification.",
            style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoText(String text, {bool isBold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
        height: 1.6,
        color: const Color(0xFF333333),
      ),
    );
  }

  Widget _buildNumberedList(List<String> items, {int startIndex = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        final index = entry.key + startIndex;
        final text = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, height: 1.6, color: Color(0xFF777777)),
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
        const TextSpan(
          text: "Feedback",
          style: TextStyle(color: Color(0xFF00BCD4), fontWeight: FontWeight.normal),
        ),
        TextSpan(text: parts[1]),
      ],
    );
  }

  Widget _buildWithdrawalTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Table(
        border: TableBorder.all(color: const Color(0xFFEEEEEE), width: 0.5),
        children: [
          _buildTableRow("New beans of the month", "Next month's daily withdrawal amount", isHeader: true),
          _buildTableRow("0-20000", "\$500"),
          _buildTableRow("20001-100000", "\$1500"),
          _buildTableRow("100001-500000", "\$3500"),
          _buildTableRow("500001-9999999999", "\$5000"),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String left, String right, {bool isHeader = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            left,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF666666),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF666666),
            ),
          ),
        ),
      ],
    );
  }
}
