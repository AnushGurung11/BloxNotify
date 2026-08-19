import 'package:flutter/material.dart';

import '../models/value.dart';
import '../services/stock_api.dart';

/// Shows the live fruit/item values from game.guide: in-game and permanent
/// values, demand, trend and rarity, in a grid with search and a single
/// tier filter (rarity for fruits, "Gamepass"/"Limited" for other items).
class ValuesScreen extends StatefulWidget {
  const ValuesScreen({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<ValuesScreen> createState() => _ValuesScreenState();
}

class _ValuesScreenState extends State<ValuesScreen> {
  late Future<List<ValueItem>?> _future;
  String _query = '';
  String _tier = 'All';

  @override
  void initState() {
    super.initState();
    _future = _fetchSafely();
  }

  Future<List<ValueItem>?> _fetchSafely() =>
      widget.stockApi.fetchValues().catchError((_) => null);

  void _reload() {
    setState(() => _future = _fetchSafely());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Values')),
      body: FutureBuilder<List<ValueItem>?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data;
          if (items == null || items.isEmpty) {
            return _NoValuesView(onRetry: _reload);
          }
          return _ValuesView(
            items: items,
            query: _query,
            tier: _tier,
            onQueryChanged: (value) => setState(() => _query = value),
            onTierChanged: (value) => setState(() => _tier = value),
            onClearFilters: () => setState(() {
              _query = '';
              _tier = 'All';
            }),
          );
        },
      ),
    );
  }
}

/// Canonical display order for the tier chips.
const _tierOrder = [
  'Common', 'Uncommon', 'Rare', 'Legendary', 'Mythical',
  'Gamepass', 'Limited',
];

class _ValuesView extends StatelessWidget {
  const _ValuesView({
    required this.items,
    required this.query,
    required this.tier,
    required this.onQueryChanged,
    required this.onTierChanged,
    required this.onClearFilters,
  });

  final List<ValueItem> items;
  final String query;
  final String tier;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onTierChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    // One filter row for everything: fruits keep their rarity tiers, while
    // gamepasses and limiteds get their own "Gamepass"/"Limited" tiers.
    final counts = <String, int>{};
    for (final item in items) {
      final rarity = item.rarity;
      if (rarity != null && rarity.isNotEmpty) {
        counts[rarity] = (counts[rarity] ?? 0) + 1;
      }
    }
    final tiers = <String>['All', ..._tierOrder.where(counts.containsKey)];
    for (final rarity in counts.keys) {
      if (!tiers.contains(rarity)) tiers.add(rarity);
    }

    final q = query.trim().toLowerCase();
    final hasFilter = tier != 'All' || q.isNotEmpty;
    final filtered = items.where((item) {
      final matchesTier = tier == 'All' || item.rarity == tier;
      final matchesQuery = q.isEmpty || item.name.toLowerCase().contains(q);
      return matchesTier && matchesQuery;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search items...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final t in tiers)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        t == 'All' ? t : '$t (${counts[t]})',
                      ),
                      selected: tier == t,
                      onSelected: (_) => onTierChanged(t),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyFilterView(
                  hasFilter: hasFilter,
                  onClear: onClearFilters,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _ValueTile(item: filtered[index]),
                ),
        ),
      ],
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.item});

  final ValueItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _Placeholder(
                              name: item.name, icon: Icons.category),
                        )
                      : _Placeholder(name: item.name, icon: Icons.category),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              style: theme.textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.rarity != null) ...[
              const SizedBox(height: 2),
              _RarityBadge(rarity: item.rarity!),
            ],
            const Spacer(),
            Text(
              formatValue(item.normalValue),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (item.permanentValue != null)
              Text(
                'Perm ${formatValue(item.permanentValue)}',
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                _DemandBadge(demand: item.demand),
                if (item.trend != null) ...[
                  const Spacer(),
                  Icon(
                    item.trend == 'Increasing' || item.trend == 'Rising'
                        ? Icons.trending_up
                        : item.trend == 'Decreasing' ||
                                item.trend == 'Falling'
                            ? Icons.trending_down
                            : Icons.trending_flat,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});

  final String rarity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(rarity, style: theme.textTheme.labelSmall),
    );
  }
}

class _DemandBadge extends StatelessWidget {
  const _DemandBadge({required this.demand});

  final String? demand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (demand == null) return const SizedBox.shrink();
    final (background, foreground) = switch (demand) {
      'Very High' => (Colors.green.shade700, Colors.white),
      'High' => (Colors.green.shade900, Colors.white),
      'Medium' => (theme.colorScheme.tertiaryContainer,
          theme.colorScheme.onTertiaryContainer),
      'Low' => (Colors.orange.shade900, Colors.white),
      _ => (theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        demand!,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name, required this.icon});

  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: name.isEmpty
            ? Icon(icon, size: 24)
            : Text(name[0].toUpperCase(), style: theme.textTheme.titleMedium),
      ),
    );
  }
}

class _EmptyFilterView extends StatelessWidget {
  const _EmptyFilterView({required this.hasFilter, required this.onClear});

  final bool hasFilter;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('No items match your search'),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try a different search or tier.'
                  : 'Items will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoValuesView extends StatelessWidget {
  const _NoValuesView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('No values yet'),
            const SizedBox(height: 8),
            const Text(
              'The backend has not cached the value list yet. '
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
