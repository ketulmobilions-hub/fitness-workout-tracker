import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pr_card_data.dart';
import '../providers/pr_share_provider.dart';
import 'pr_card.dart';

class PrShareBottomSheet extends ConsumerStatefulWidget {
  const PrShareBottomSheet({super.key, required this.data});

  final PrCardData data;

  static Future<void> show(BuildContext context, PrCardData data) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: PrShareBottomSheet(data: data),
      ),
    );
  }

  @override
  ConsumerState<PrShareBottomSheet> createState() =>
      _PrShareBottomSheetState();
}

class _PrShareBottomSheetState extends ConsumerState<PrShareBottomSheet> {
  final _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    ref.listen<PrShareState>(prShareProvider, (prev, next) {
      if (!(prev?.savedSuccessfully ?? false) && next.savedSuccessfully) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PR card saved to Photos')),
        );
      }
    });

    final shareState = ref.watch(prShareProvider);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: PrCard(data: widget.data, size: 340),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (shareState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  shareState.error!,
                  style: TextStyle(color: cs.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            if (shareState.isCapturing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.save_alt_outlined),
                    label: const Text('Save to Photos'),
                    onPressed: shareState.isCapturing
                        ? null
                        : () => ref
                            .read(prShareProvider.notifier)
                            .captureAndSave(_cardKey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: shareState.isCapturing
                        ? null
                        : () => ref
                            .read(prShareProvider.notifier)
                            .captureAndShare(_cardKey),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
