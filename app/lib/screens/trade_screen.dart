import 'package:flutter/material.dart';

import '../models/value.dart';
import '../services/stock_api.dart';

/// Trade calculator: pick the items you give and receive; the win/loss and
/// the value difference are shown in real time using live game.guide values.
/// Items are picked from an image grid and the selected items stay on
/// screen as image tiles too.
class TradeScreen extends StatefulWidget {
  const TradeScreen({super.key, required this.stockApi});

  final StockApi stockApi;

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen> {
  late Future<List<ValueItem>?> _future;

  final List<ValueItem> _given = [];
  final List<ValueItem> _received = [];

  @override
  void initState() {
    super.initState();
    _future = _fetchSafely();
  }

  Future<List<ValueItem>?> _fetchSafely() =>
      widget.stockApi.fetchValues().catchError((_) => null);

  void _reload() {
    setState(() {
      _future = _fetchSafely();
      _given.clear();
      _received.clear();
    });
  }

  void _addTo(List<ValueItem> side, ValueItem item) {
    setState(() => side.add(item));
  }

  void _removeFrom(List<ValueItem> side, ValueItem item) {
    setState(() => side.remove(item));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trade Calculator')),
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
          final tradable =
              items.where((i) => i.normalValue != null).toList();
          if (tradable.isEmpty) {
            return _NoValuesView(onRetry: _reload);
          }
          return _TradeView(
            items: tradable,
            given: _given,
            received: _received,
            onPickGiven: (item) => _addTo(_given, item),
            onPickReceived: (item) => _addTo(_received, item),
            onRemoveGiven: (item) => _removeFrom(_given, item),
            onRemoveReceived: (item) => _removeFrom(_received, item),
            onClear: () => setState(() {
              _given.clear();
              _received.clear();
            }),
          );
        },
      ),
    );
  }
}

class _TradeView extends StatelessWidget {
  const _TradeView({
    required this.items,
    required this.given,
    required this.received,
    required this.onPickGiven,
    required this.onPickReceived,
    required this.onRemoveGiven,
    required this.onRemoveReceived,
    required this.onClear,
  });

  final List<ValueItem> items;
  final List<ValueItem> given;
  final List<ValueItem> received;
  final ValueChanged<ValueItem> onPickGiven;
  final ValueChanged<ValueItem> onPickReceived;
  final ValueChanged<ValueItem> onRemoveGiven;
  final ValueChanged<ValueItem> onRemoveReceived;
  final VoidCallback onClear;

  num get _givenTotal =>
      given.fold<num>(0, (sum, i) => sum + (i.normalValue ?? 0));
  num get _receivedTotal =>
      received.fold<num>(0, (sum, i) => sum + (i.normalValue ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final givenTotal = _givenTotal;
    final receivedTotal = _receivedTotal;
    final isWin = receivedTotal >= givenTotal && receivedTotal > 0;
    final maxTotal = givenTotal > receivedTotal ? givenTotal : receivedTotal;
    final difference = (receivedTotal - givenTotal).abs();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SideCard(
          title: 'You give',
          icon: Icons.outbound,
          pickerKey: const Key('give-picker'),
          items: items,
          total: givenTotal,
          addedItems: given,
          onPick: onPickGiven,
          onRemove: onRemoveGiven,
        ),
        const SizedBox(height: 16),
        _SideCard(
          title: 'You receive',
          icon: Icons.input,
          pickerKey: const Key('receive-picker'),
          items: items,
          total: receivedTotal,
          addedItems: received,
          onPick: onPickReceived,
          onRemove: onRemoveReceived,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Given',
                    style: theme.textTheme.labelSmall,
                  ),
                  Text(
                    formatValue(givenTotal),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            Text('vs', style: theme.textTheme.bodyMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Received', style: theme.textTheme.labelSmall),
                  Text(
                    formatValue(receivedTotal),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              isWin ? 'Win' : 'Loss',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: isWin ? Colors.green.shade400 : Colors.red.shade400,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                maxTotal == 0
                    ? 'Add items to both sides to compare values'
                    : isWin
                        ? 'You gain ${formatValue(difference)} in value'
                        : 'You lose ${formatValue(difference)} in value',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (given.isNotEmpty || received.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
          ),
        ],
      ],
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({
    required this.title,
    required this.icon,
    required this.pickerKey,
    required this.items,
    required this.total,
    required this.addedItems,
    required this.onPick,
    required this.onRemove,
  });

  final String title;
  final IconData icon;
  final Key pickerKey;
  final List<ValueItem> items;
  final num total;

  /// The items already added to this side (shown as tiles below the picker).
  final List<ValueItem> addedItems;

  final ValueChanged<ValueItem> onPick;
  final ValueChanged<ValueItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(title, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  formatValue(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 210,
              key: pickerKey,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 110,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return _PickerTile(
                    item: item,
                    selected: addedItems.contains(item),
                    onTap: () => onPick(item),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (addedItems.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Nothing added yet — tap an item above.',
                  style: TextStyle(fontSize: 12),
                ),
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: [
                  for (final item in addedItems)
                    _TradeItemTile(
                      item: item,
                      onRemove: () => onRemove(item),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A pickable item tile in the picker grid; tap to add it to the side.
class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ValueItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  item.name.isNotEmpty
                                      ? item.name[0].toUpperCase()
                                      : '?',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                item.name.isNotEmpty
                                    ? item.name[0].toUpperCase()
                                    : '?',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: theme.textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            formatValue(item.normalValue),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

/// A selected trade item shown as an image tile; tap to remove.
class _TradeItemTile extends StatelessWidget {
  const _TradeItemTile({required this.item, required this.onRemove});

  final ValueItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: item.imageUrl != null
                        ? Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Text(
                                  item.name.isNotEmpty
                                      ? item.name[0].toUpperCase()
                                      : '?',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: Text(
                                item.name.isNotEmpty
                                    ? item.name[0].toUpperCase()
                                    : '?',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: theme.textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            formatValue(item.normalValue),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
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
            Icon(Icons.swap_horiz,
                size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Trade calculator unavailable'),
            const SizedBox(height: 8),
            const Text(
              'Live item values are needed to compare trades. '
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