import 'package:flutter/material.dart';
import 'package:flutter_gpiod/flutter_gpiod.dart';

import 'gpio_source.dart';

/// Lists every GPIO chip on the system and, under each chip, all its lines.
class GpioViewerPage extends StatefulWidget {
  const GpioViewerPage({super.key, required this.loader});

  final GpioLoader loader;

  @override
  State<GpioViewerPage> createState() => _GpioViewerPageState();
}

class _GpioViewerPageState extends State<GpioViewerPage> {
  late Future<List<GpioChipSnapshot>> _chips;
  String _query = '';
  bool _usedOnly = false;

  @override
  void initState() {
    super.initState();
    _chips = widget.loader();
  }

  void _refresh() {
    setState(() => _chips = widget.loader());
  }

  bool _matches(GpioLineSnapshot line) {
    if (_usedOnly && !line.isUsed) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return line.offset.toString() == q ||
        (line.name?.toLowerCase().contains(q) ?? false) ||
        (line.consumer?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GPIO Viewer'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Filter by line number, name or consumer',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Used only'),
                  selected: _usedOnly,
                  onSelected: (v) => setState(() => _usedOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GpioChipSnapshot>>(
              future: _chips,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Message(
                    icon: Icons.error_outline,
                    title: 'Could not read GPIO chips',
                    detail: '${snapshot.error}\n\n'
                        'Make sure /dev/gpiochip* exists and this user can '
                        'access it (e.g. is in the "gpio" group).',
                    onRetry: _refresh,
                  );
                }
                final chips = snapshot.data!;
                if (chips.isEmpty) {
                  return _Message(
                    icon: Icons.memory,
                    title: 'No GPIO chips found',
                    detail: 'No /dev/gpiochip* devices were found.',
                    onRetry: _refresh,
                  );
                }
                return ListView(
                  children: [
                    for (final chip in chips)
                      _ChipTile(
                        chip: chip,
                        lines: chip.lines.where(_matches).toList(),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipTile extends StatelessWidget {
  const _ChipTile({required this.chip, required this.lines});

  final GpioChipSnapshot chip;
  final List<GpioLineSnapshot> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey('chip-${chip.index}'),
        leading: const Icon(Icons.memory),
        title: Text('${chip.name}  ·  ${chip.label}'),
        subtitle: Text(
          '${chip.lines.length} lines, ${chip.usedLineCount} in use'
          '${lines.length != chip.lines.length ? ', ${lines.length} shown' : ''}',
        ),
        children: [
          if (lines.isEmpty)
            const ListTile(title: Text('No lines match the filter')),
          for (final line in lines) _LineTile(line: line),
        ],
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({required this.line});

  final GpioLineSnapshot line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor:
            line.isUsed ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        child: Text(
          '${line.offset}',
          style: theme.textTheme.labelMedium,
        ),
      ),
      title: Text(
        line.name?.isNotEmpty == true ? line.name! : '(unnamed)',
        style: line.name?.isNotEmpty == true
            ? null
            : TextStyle(color: theme.disabledColor),
      ),
      subtitle: Text(
        line.isUsed
            ? 'Used by ${line.consumer?.isNotEmpty == true ? line.consumer : 'kernel / unknown'}'
            : 'Free',
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          _Tag(line.direction == LineDirection.output ? 'OUT' : 'IN'),
          if (line.outputMode == OutputMode.openDrain) const _Tag('open-drain'),
          if (line.outputMode == OutputMode.openSource)
            const _Tag('open-source'),
          if (line.bias == Bias.pullUp) const _Tag('pull-up'),
          if (line.bias == Bias.pullDown) const _Tag('pull-down'),
          if (line.bias == Bias.disable) const _Tag('no bias'),
          if (line.activeState == ActiveState.low) const _Tag('active-low'),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
