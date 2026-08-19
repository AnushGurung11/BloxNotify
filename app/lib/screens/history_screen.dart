import 'package:flutter/material.dart';

import '../models/fruit.dart';
import '../services/stock_api.dart';
import 'stock_screen.dart' show formatStockTimestamp;

/// Shows the past stock snapshots recorded by the backend.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<StockSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.stockApi.fetchCurrentStock();
  }

  void _reload() {
    setState(() => _future = widget.stockApi.fetchCurrentStock());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock History')),
      body: FutureBuilder<StockSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off,
                        size: 56, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    const Text('Could not load the history'),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }
          final stock = snapshot.data!;
          if (stock.history.isEmpty) {
            return const _EmptyHistoryView();
          }
          return _HistoryList(entries: stock.history);
        },
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});

  final List<StockHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Previous stock snapshots, newest first.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final entry in entries) _HistoryTile(entry: entry),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final StockHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = entry.updatedAt == null
        ? 'Unknown time'
        : formatStockTimestamp(entry.updatedAt!);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(when, style: theme.textTheme.labelMedium),
              ],
            ),
            if (entry.fruits.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.fruits.join(', '),
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (entry.mirageFruits.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome,
                      size: 14, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mirage: ${entry.mirageFruits.join(', ')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (entry.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('(empty snapshot)',
                    style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56),
            SizedBox(height: 16),
            Text('No history yet'),
            SizedBox(height: 8),
            Text(
              'Past stock snapshots will appear here after the next '
              'rotation.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}