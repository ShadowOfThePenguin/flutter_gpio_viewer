import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gpiod/flutter_gpiod.dart';

import 'gpio_source.dart';

/// Display-only view of every GPIO chip on the system and all its lines.
///
/// Meant for screens without mouse, keyboard or touch: everything is shown
/// at once, the data refreshes itself every [refreshInterval], and when the
/// content is taller than the screen it scrolls itself up and down.
class GpioViewerPage extends StatefulWidget {
  const GpioViewerPage({
    super.key,
    required this.loader,
    this.refreshInterval = const Duration(seconds: 2),
    this.autoScroll = true,
  });

  final GpioLoader loader;

  /// How often to re-read the chips. Null disables automatic refreshing.
  final Duration? refreshInterval;

  /// Whether to scroll through content that doesn't fit on screen.
  final bool autoScroll;

  @override
  State<GpioViewerPage> createState() => _GpioViewerPageState();
}

class _GpioViewerPageState extends State<GpioViewerPage> {
  List<GpioChipSnapshot>? _chips;
  Object? _error;
  DateTime? _updatedAt;
  Timer? _refreshTimer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
    final interval = widget.refreshInterval;
    if (interval != null) {
      _refreshTimer = Timer.periodic(interval, (_) => _load());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final chips = await widget.loader();
      if (!mounted) return;
      setState(() {
        _chips = chips;
        _error = null;
        _updatedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = _chips;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(chips: chips, updatedAt: _updatedAt),
            Expanded(
              child: _error != null
                  ? _Message(
                      icon: Icons.error_outline,
                      title: 'Could not read GPIO chips',
                      detail:
                          '$_error\n\n'
                          'Make sure /dev/gpiochip* exists and this user can '
                          'access it (e.g. is in the "gpio" group). '
                          'Retrying automatically.',
                    )
                  : chips == null
                  ? const Center(child: CircularProgressIndicator())
                  : chips.isEmpty
                  ? const _Message(
                      icon: Icons.memory,
                      title: 'No GPIO chips found',
                      detail: 'No /dev/gpiochip* devices were found.',
                    )
                  : _AutoScroll(
                      enabled: widget.autoScroll,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final chip in chips) _ChipSection(chip: chip),
                          ],
                        ),
                      ),
                    ),
            ),
            if (_error == null && chips != null && chips.isNotEmpty)
              _Legend(style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.chips, required this.updatedAt});

  final List<GpioChipSnapshot>? chips;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = this.chips ?? const [];
    final lineCount = chips.fold<int>(0, (n, c) => n + c.lines.length);
    final usedCount = chips.fold<int>(0, (n, c) => n + c.usedLineCount);
    final t = updatedAt;
    String two(int v) => v.toString().padLeft(2, '0');

    return Container(
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            'GPIO Viewer',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${chips.length} chips · $lineCount lines · $usedCount in use'
              '${t == null ? '' : ' · updated ${two(t.hour)}:${two(t.minute)}:${two(t.second)}'}',
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.chip});

  static const _minCellWidth = 190.0;
  static const _spacing = 4.0;

  final GpioChipSnapshot chip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${chip.name} · ${chip.label} · '
              '${chip.lines.length} lines, ${chip.usedLineCount} in use',
              style: theme.textTheme.titleSmall,
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / _minCellWidth)
                  .floor()
                  .clamp(1, 1 << 20);
              final cellWidth =
                  (constraints.maxWidth - _spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: _spacing,
                runSpacing: _spacing,
                children: [
                  for (final line in chip.lines)
                    SizedBox(
                      width: cellWidth,
                      child: _LineCell(line: line),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LineCell extends StatelessWidget {
  const _LineCell({required this.line});

  final GpioLineSnapshot line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasName = line.name?.isNotEmpty == true;
    final fg = line.isUsed ? scheme.onPrimaryContainer : scheme.onSurface;
    final small = theme.textTheme.labelSmall?.copyWith(color: fg);

    final flags = [
      line.direction == LineDirection.output ? 'OUT' : 'IN',
      if (line.outputMode == OutputMode.openDrain) 'OD',
      if (line.outputMode == OutputMode.openSource) 'OS',
      if (line.bias == Bias.pullUp) 'PU',
      if (line.bias == Bias.pullDown) 'PD',
      if (line.activeState == ActiveState.low) 'AL',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: line.isUsed
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${line.offset}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  hasName ? line.name! : '-',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: hasName ? fg : fg.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Text(flags.join(' '), style: small),
            ],
          ),
          Text(
            line.isUsed
                ? (line.consumer?.isNotEmpty == true
                      ? line.consumer!
                      : 'used (kernel)')
                : 'free',
            overflow: TextOverflow.ellipsis,
            style: small?.copyWith(color: fg.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        'IN/OUT direction · OD open-drain · OS open-source · '
        'PU pull-up · PD pull-down · AL active-low · highlighted = in use',
        style: style,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Slowly scrolls [child] to the bottom and back to the top when it is taller
/// than the available space. Does nothing when everything fits.
class _AutoScroll extends StatefulWidget {
  const _AutoScroll({required this.child, required this.enabled});

  final Widget child;
  final bool enabled;

  @override
  State<_AutoScroll> createState() => _AutoScrollState();
}

class _AutoScrollState extends State<_AutoScroll> {
  static const _pixelsPerSecond = 40.0;
  static const _pause = Duration(seconds: 4);

  final _controller = ScrollController();
  bool _running = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;
    _running = true;
    while (!_disposed) {
      await Future<void>.delayed(_pause);
      if (_disposed || !_controller.hasClients) continue;

      final extent = _controller.position.maxScrollExtent;
      if (extent <= 0) continue;

      final remaining = extent - _controller.offset;
      if (remaining > 0) {
        await _controller.animateTo(
          extent,
          duration: Duration(
            milliseconds: (remaining / _pixelsPerSecond * 1000).round(),
          ),
          curve: Curves.linear,
        );
      }
      if (_disposed) break;
      await Future<void>.delayed(_pause);
      if (_disposed || !_controller.hasClients) continue;
      _controller.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      physics: const NeverScrollableScrollPhysics(),
      child: widget.child,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

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
          ],
        ),
      ),
    );
  }
}
