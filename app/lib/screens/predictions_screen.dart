import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prediction.dart';
import '../services/stock_api.dart';
import 'stock_screen.dart' show formatCountdown, formatStockTimestamp;

/// Shows the predicted next stock with fruit images, confidence bars, the
/// model's backtested rating, and the historically best rotation times.
class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  late Future<PredictionResult?> _future;

  Future<PredictionResult?> _fetchSafely() =>
      widget.stockApi.fetchPredictions().catchError((_) => null);

  @override
  void initState() {
    super.initState();
    _future = _fetchSafely();
  }

  void _reload() {
    setState(() => _future = _fetchSafely());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Predictions')),
      body: FutureBuilder<PredictionResult?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null || result.predictions.isEmpty) {
            return _NoPredictionsView(onRetry: _reload);
          }
          return _PredictionsView(result: result);
        },
      ),
    );
  }
}

class _PredictionsView extends StatelessWidget {
  const _PredictionsView({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = result.rating;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Next rotation', style: theme.textTheme.labelLarge),
        if (result.nextResetAt != null)
          _CountdownText(nextResetAt: result.nextResetAt!),
        const SizedBox(height: 16),
        Text('Predicted Stock', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Based on ${_rotationsLabel(rating)} of wiki stock history',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final (i, p) in result.predictions.indexed) ...[
          _PredictionCard(rank: i + 1, prediction: p),
          const SizedBox(height: 8),
        ],
        if (rating != null && rating.testedRotations > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.speed, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Model rating: ${rating.top3Accuracy.toStringAsFixed(1)}% '
                  'top-3 accuracy '
                  '(${rating.top1Accuracy.toStringAsFixed(1)}% top-1, '
                  '${rating.testedRotations} rotations backtested)',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
        if (result.bestSlots.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Best Times to Check', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'UTC slots ranked by how many premium fruits appeared '
            'per rotation in the recorded history.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final (i, slot) in result.bestSlots.indexed) ...[
            _BestSlotTile(rank: i + 1, slot: slot),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  String _rotationsLabel(PredictionRating? rating) {
    if (rating == null || rating.testedRotations == 0) return '';
    final n = rating.testedRotations;
    if (n < 1000) return '$n';
    return '${((n / 1000) * 10).floor() / 10}k';
  }
}

/// Ticks every second, showing the time until the next rotation.
class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.nextResetAt});

  final DateTime nextResetAt;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final diff = widget.nextResetAt.difference(now);
    final remaining = diff.isNegative ? Duration.zero : diff;
    return Text(
      'in ${formatCountdown(remaining)}',
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.rank, required this.prediction});

  final int rank;
  final FruitPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidence = (prediction.confidence * 100).clamp(0, 100);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: prediction.imageUrl != null
                    ? Image.network(
                        prediction.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _NoImage(),
                      )
                    : const _NoImage(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#$rank ${prediction.name}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: confidence / 100,
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${confidence.toStringAsFixed(0)}% confidence',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestSlotTile extends StatelessWidget {
  const _BestSlotTile({required this.rank, required this.slot});

  final int rank;
  final BestSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = DateTime.fromMillisecondsSinceEpoch(
      DateUtils.dateOnly(DateTime.now()).millisecondsSinceEpoch +
          slot.hour * 3600 * 1000,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 14,
          backgroundColor: rank == 1
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            '$rank',
            style: theme.textTheme.labelMedium?.copyWith(
              color: rank == 1
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
        title: Text(
          '${slot.hour.toString().padLeft(2, '0')}:00 UTC'
          ' (${formatStockTimestamp(local).split(' ').last}) local',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          '${slot.premiumCount} premium fruits across ${slot.rotations} rotations',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, size: 24),
      ),
    );
  }
}

class _NoPredictionsView extends StatelessWidget {
  const _NoPredictionsView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.query_stats_outlined,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('No predictions yet'),
            const SizedBox(height: 8),
            const Text(
              'The prediction model needs the wiki stock history to build. '
              'Try again later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}