import 'dart:async';

import 'package:flutter/material.dart';

import '../models/prediction.dart';
import '../services/stock_api.dart';
import 'stock_screen.dart' show formatCountdown;

/// Shows the predicted next stock with fruit images, confidence bars,
/// rarity badges, and the model's backtested rating.
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '#$rank ${prediction.name}',
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prediction.rarity != null) ...[
                        const SizedBox(width: 8),
                        _RarityChip(rarity: prediction.rarity!),
                      ],
                    ],
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

/// Small rarity badge; Legendary and Mythical are highlighted.
class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity});

  final String rarity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = rarity == 'Legendary' || rarity == 'Mythical';
    final background = isPremium
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = isPremium
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        rarity,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
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