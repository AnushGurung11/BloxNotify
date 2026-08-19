import 'package:flutter/material.dart';

import '../models/value.dart';
import '../services/stock_api.dart';

/// Shows the live fruit/item values from game.guide: in-game and permanent
/// (Robux) values, demand, trend and rarity, with search and category
/// filters.
class ValuesScreen extends StatefulWidget {
  const ValuesScreen({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<ValuesScreen> createState() => _ValuesScreenState();
}

class _ValuesScreenState extends State<ValuesScreen> {
  late Future<List<ValueItem>?> _future;
  String _query = '';
  String _category = 'All';

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
            category: _category,
            onQueryChanged: (value) => setState(() => _query = value),
            onCategoryChanged: (value) => setState(() => _category = value),
          );
        },
      ),
    );
  }
}

class _ValuesView extends StatelessWidget {
  const _ValuesView({
    required this.items,
    required this.query,
    required this.category,
    required this.onQueryChanged,
    required this.onCategoryChanged,
  });

  final List<ValueItem> items;
  final String query;
  final String category;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final categories = <String>['All'];
    for (final item in items) {
      final category = item.category;
      if (category != null && !categories.contains(category)) {
        categories.add(category);
      }
    }
    final q = query.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesCategory = category == 'All' || item.category == category;
      final matchesQuery = q.isEmpty || item.name.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
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
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      onSelected: (_) => onCategoryChanged(c),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No items match your search'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.rarity != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.rarity!,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatValue(item.normalValue)} in-game'
                    '${item.permanentValue != null ? ' · ${formatValue(item.permanentValue)} Robux' : ''}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _DemandBadge(demand: item.demand),
                      if (item.trend != null) ...[
                        const SizedBox(width: 8),
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
                        const SizedBox(width: 4),
                        Text(
                          item.trend!,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
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