import 'package:flutter/material.dart';

class SpinWheelLayout extends StatelessWidget {
  const SpinWheelLayout({
    super.key,
    required this.header,
    required this.board,
    required this.footer,
    required this.selectedAmount,
    required this.onAmountChanged,
  });

  final Widget header;
  final Widget board;
  final Widget footer;
  final int selectedAmount;
  final ValueChanged<int>? onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final chips = ColoredBox(
      color: const Color(0xFF47B8EB),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(children: [
          for (final value in const [100, 1000, 10000, 100000])
            Expanded(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Semantics(
                button: true,
                enabled: onAmountChanged != null,
                onTap: onAmountChanged == null
                    ? null
                    : () => onAmountChanged!(value),
                selected: value == selectedAmount,
                label: '$value Diamonds',
                excludeSemantics: true,
                child: Material(
                  color: value == selectedAmount
                      ? const Color(0xFFB82923)
                      : const Color(0xFFFFCF38),
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: onAmountChanged == null
                        ? null
                        : () => onAmountChanged!(value),
                    child: SizedBox(
                        height: 48,
                        child: Center(
                            child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                              value == 100 ? '100' : '${value ~/ 1000}k',
                              style: TextStyle(
                                  color: value == selectedAmount
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                        ))),
                  ),
                ),
              ),
            )),
        ]),
      ),
    );
    return SafeArea(child: LayoutBuilder(builder: (context, box) {
      final wheel = FittedBox(fit: BoxFit.contain, child: board);
      final stats = SingleChildScrollView(primary: false, child: footer);
      if (box.maxWidth > box.maxHeight) {
        return Column(children: [
          header,
          Expanded(
              child: Row(children: [
            Expanded(child: SizedBox.expand(child: wheel)),
            Expanded(child: Column(children: [chips, Expanded(child: stats)])),
          ])),
        ]);
      }
      return Column(children: [
        header,
        Expanded(child: SizedBox.expand(child: wheel)),
        chips,
        ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.38),
            child: stats),
      ]);
    }));
  }
}
