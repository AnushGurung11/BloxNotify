import 'package:flutter/material.dart';

import '../models/value.dart';
import '../services/stock_api.dart';

/// Trade calculator: pick the items you give and receive; the win/loss bar
/// shows the value difference in real time using live game.guide values.
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
  ValueItem? _givenSelection;
  ValueItem? _receivedSelection;

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
      _givenSelection = null;
      _receivedSelection = null;
    });
  }

  void _addTo(List<ValueItem> side, ValueItem item) {
    setState(() {
      side.add(item);
      if (identical(side, _given)) {
        _givenSelection = null;
      } else {
        _receivedSelection = null;
      }
    });
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
            givenSelection: _givenSelection,
            receivedSelection: _receivedSelection,
            onGivenSelectionChanged: (item) =>
                setState(() => _givenSelection = item),
            onReceivedSelectionChanged: (item) =>
                setState(() => _receivedSelection = item),
            onAddGiven: () {
              final item = _givenSelection;
              if (item != null) _addTo(_given, item);
            },
            onAddReceived: () {
              final item = _receivedSelection;
              if (item != null) _addTo(_received, item);
            },
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
    required this.givenSelection,
    required this.receivedSelection,
    required this.onGivenSelectionChanged,
    required this.onReceivedSelectionChanged,
    required this.onAddGiven,
    required this.onAddReceived,
    required this.onRemoveGiven,
    required this.onRemoveReceived,
    required this.onClear,
  });

  final List<ValueItem> items;
  final List<ValueItem> given;
  final List<ValueItem> received;
  final ValueItem? givenSelection;
  final ValueItem? receivedSelection;
  final ValueChanged<ValueItem?> onGivenSelectionChanged;
  final ValueChanged<ValueItem?> onReceivedSelectionChanged;
  final VoidCallback onAddGiven;
  final VoidCallback onAddReceived;
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
    final barValue = maxTotal == 0 ? 0.0 : (receivedTotal / maxTotal);
    final difference = (receivedTotal - givenTotal).abs();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _SideCard(
          title: 'You give',
          icon: Icons.outbound,
          items: items,
          selection: givenSelection,
          total: givenTotal,
          addedItems: given,
          onSelectionChanged: onGivenSelectionChanged,
          onAdd: onAddGiven,
          onRemove: onRemoveGiven,
        ),
        const SizedBox(height: 16),
        _SideCard(
          title: 'You receive',
          icon: Icons.input,
          items: items,
          selection: receivedSelection,
          total: receivedTotal,
          addedItems: received,
          onSelectionChanged: onReceivedSelectionChanged,
          onAdd: onAddReceived,
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
        Text(
          isWin ? 'Win' : 'Loss',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: isWin ? Colors.green.shade400 : Colors.red.shade400,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: barValue,
            minHeight: 14,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: isWin ? Colors.green.shade600 : Colors.red.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          maxTotal == 0
              ? 'Add items to both sides to compare values'
              : isWin
                  ? 'You gain ${formatValue(difference)} in value'
                  : 'You lose ${formatValue(difference)} in value',
          style: theme.textTheme.bodySmall,
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
    required this.items,
    required this.selection,
    required this.total,
    required this.addedItems,
    required this.onSelectionChanged,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final IconData icon;
  final List<ValueItem> items;
  final ValueItem? selection;
  final num total;
  final ValueChanged<ValueItem?> onSelectionChanged;
  final VoidCallback onAdd;
  final ValueChanged<ValueItem> onRemove;

  /// The chips shown below the picker (populated by the parent).
  final List<ValueItem> addedItems;

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
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ValueItem>(
                    initialValue: selection,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'Pick an item...',
                    ),
                    items: [
                      for (final item in items)
                        DropdownMenuItem(
                          value: item,
                          child: Text(
                            '${item.name} (${formatValue(item.normalValue)})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onSelectionChanged,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add item',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in addedItems)
                  InputChip(
                    label: Text(
                      '${item.name} (${formatValue(item.normalValue)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: () => onRemove(item),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                if (addedItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Nothing added yet — pick an item above.',
                      style: TextStyle(fontSize: 12),
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