import 'package:flutter/material.dart';

import '../models/history.dart';
import '../services/stock_api.dart';
import '../utils/fruit_images.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a moment as `Tue, Aug 18, 2026` (local time), like the reference
/// bloxvalues history page.
String formatHistoryDay(DateTime dt) {
  final local = dt.toLocal();
  return '${_weekdays[local.weekday - 1]}, '
      '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

/// Formats a moment as `5:00 PM` (12-hour clock, local time).
String formatHistoryTime(DateTime dt) {
  final local = dt.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hour:$mm $ampm';
}

/// Shows the past 7 days of stock rotations (Normal + Mirage dealer
/// restocks) in the style of the bloxvalues history page: a "most frequent
/// fruits" leaderboard, then day-grouped restocks with dealer badges and
/// fruit chips.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<StockHistory?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.stockApi.fetchHistory();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.stockApi.fetchHistory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock History')),
      body: FutureBuilder<StockHistory?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(onRetry: _reload);
          }
          final history = snapshot.data;
          if (history == null || history.events.isEmpty) {
            return const _EmptyHistoryView();
          }
          return _HistoryView(history: history, onRefresh: _reload);
        },
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.history, required this.onRefresh});

  final StockHistory history;
  final Future<void> Function() onRefresh;

  /// Fruits ranked by how often they appeared, then by most recent.
  List<MapEntry<String, (int count, DateTime lastSeen)>> get _rankedFruits {
    final counts = <String, int>{};
    final lastSeen = <String, DateTime>{};
    for (final event in history.events) {
      for (final item in event.items) {
        counts[item.name] = (counts[item.name] ?? 0) + 1;
        final previous = lastSeen[item.name];
        if (previous == null || event.time.isAfter(previous)) {
          lastSeen[item.name] = event.time;
        }
      }
    }
    final ranked = counts.entries.map((e) {
      return MapEntry(e.key, (e.value, lastSeen[e.key]!));
    }).toList()
      ..sort((a, b) {
        final byCount = b.value.$1.compareTo(a.value.$1);
        return byCount != 0
            ? byCount
            : b.value.$2.compareTo(a.value.$2);
      });
    return ranked.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = history.events;
    final latest = events.first.time;
    final updated = history.updatedAt ?? latest;
    final ranked = _rankedFruits;

    // Group events by their local calendar day, keeping newest first.
    final groups = <String, List<StockHistoryEvent>>{};
    for (final event in events) {
      final local = event.time.toLocal();
      final key = '${local.year}-${local.month}-${local.day}';
      groups.putIfAbsent(key, () => []).add(event);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            'Updated ${formatHistoryDay(updated)} · '
            '${history.source == 'bloxvalues' ? 'bloxvalues.net' : 'local'}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Most Frequent Fruits (Last 7 Days)',
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final entry in ranked)
            _LeaderboardRow(rank: ranked.indexOf(entry) + 1, fruit: entry),
          const SizedBox(height: 16),
          Text('Recent Restocks', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final group in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                formatHistoryDay(group.value.first.time).toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final event in group.value) _EventCard(event: event),
          ],
          const SizedBox(height: 16),
          Text(
            'Showing the ${events.length} most recent restocks. '
            'Older entries roll off after 7 days.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.fruit});

  final int rank;
  final MapEntry<String, (int, DateTime)> fruit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = fruit.key;
    final (count, lastSeen) = fruit.value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('#$rank', style: theme.textTheme.labelMedium),
          ),
          _FruitImage(name: name, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  'Last seen ${formatHistoryDay(lastSeen)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count×',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final StockHistoryEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DealerBadge(isMirage: event.isMirage),
              const Spacer(),
              Text(
                formatHistoryTime(event.time),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in event.items) _FruitChip(item: item),
            ],
          ),
        ],
      ),
    );
  }
}

class _DealerBadge extends StatelessWidget {
  const _DealerBadge({required this.isMirage});

  final bool isMirage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isMirage ? const Color(0xFFE879F9) : const Color(0xFF93C5FD);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        isMirage ? 'MIRAGE DEALER' : 'NORMAL DEALER',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FruitChip extends StatelessWidget {
  const _FruitChip({required this.item});

  final StockHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceText = formatBeli(item.price);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FruitImage(
            name: item.name,
            url: item.imageUrl,
            size: 26,
            radius: 4,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (priceText.isNotEmpty)
                  Text(
                    priceText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.green.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round fruit thumbnail: prefers the item's own URL, falls back to
/// FruityBlox, then a letter avatar.
class _FruitImage extends StatelessWidget {
  const _FruitImage({required this.name, this.url, required this.size, this.radius = 8});

  final String name;
  final String? url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = url ?? fruitImageUrl(name);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: Text(
                fruitInitial(name),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
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
              'Stock rotation history will appear here once it has been '
              'recorded.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
