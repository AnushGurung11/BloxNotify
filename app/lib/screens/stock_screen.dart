import 'package:flutter/material.dart';

import '../models/fruit.dart';
import '../services/stock_api.dart';

/// Shows the current stock as a grid of fruit cards with pull-to-refresh.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  late Future<StockSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.stockApi.fetchCurrentStock();
  }

  Future<void> _refresh() async {
    final future = widget.stockApi.fetchCurrentStock();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // errors surface through the FutureBuilder
    }
  }

  void _reload() {
    setState(() => _future = widget.stockApi.fetchCurrentStock());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Current Stock')),
      body: FutureBuilder<StockSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(error: '${snapshot.error}', onRetry: _reload);
          }
          final stock = snapshot.data!;
          if (stock.isEmpty) {
            return _EmptyView(onRetry: _reload);
          }
          return _StockGrid(stock: stock, onRefresh: _refresh);
        },
      ),
    );
  }
}

class _StockGrid extends StatelessWidget {
  const _StockGrid({required this.stock, required this.onRefresh});

  final StockSnapshot stock;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updatedAt = stock.updatedAt;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                updatedAt == null
                    ? 'Never updated'
                    : 'Last updated: ${_formatTimestamp(updatedAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _FruitCard(fruit: stock.fruits[index]),
                childCount: stock.fruits.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}

class _FruitCard extends StatelessWidget {
  const _FruitCard({required this.fruit});

  final Fruit fruit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: fruit.imageUrl != null
                ? Image.network(
                    fruit.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _NoImage(),
                  )
                : const _NoImage(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              fruit.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
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
        child: Icon(Icons.image_not_supported_outlined, size: 40),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            const Text('Could not load the stock'),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('No stock recorded yet'),
            const SizedBox(height: 8),
            const Text(
              'The backend has not captured a stock rotation yet. '
              'Pull to refresh or try again later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}