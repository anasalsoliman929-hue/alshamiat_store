import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/all_providers.dart';

class CurrencyDisplay extends ConsumerWidget {
  final double amountUsd;
  final TextStyle? style;
  final bool showBoth;

  const CurrencyDisplay({
    super.key,
    required this.amountUsd,
    this.style,
    this.showBoth = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rateAsync = ref.watch(currentExchangeRateProvider);
    final usdFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final sypFormat = NumberFormat.currency(symbol: 'ل.س', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(usdFormat.format(amountUsd), style: style),
        if (showBoth)
          rateAsync.when(
            data: (rate) => Text(
              rate > 0 ? sypFormat.format(amountUsd * rate) : '— ل.س',
              style: (style ?? const TextStyle())
                  .copyWith(fontSize: 12, color: Colors.grey),
            ),
            loading: () => const SizedBox(
                height: 12,
                width: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5)),
            error: (_, __) => const Text('— ل.س',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
      ],
    );
  }
}
