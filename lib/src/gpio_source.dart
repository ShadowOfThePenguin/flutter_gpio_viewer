import 'package:flutter_gpiod/flutter_gpiod.dart';

/// Snapshot of a single GPIO line's state at the time it was read.
class GpioLineSnapshot {
  const GpioLineSnapshot({
    required this.offset,
    this.name,
    this.consumer,
    required this.direction,
    this.outputMode,
    this.bias,
    required this.activeState,
    required this.isUsed,
  });

  factory GpioLineSnapshot.fromInfo(int offset, LineInfo info) {
    return GpioLineSnapshot(
      offset: offset,
      name: info.name,
      consumer: info.consumer,
      direction: info.direction,
      outputMode: info.outputMode,
      bias: info.bias,
      activeState: info.activeState,
      isUsed: info.isUsed,
    );
  }

  /// Index of the line on its chip.
  final int offset;
  final String? name;
  final String? consumer;
  final LineDirection direction;
  final OutputMode? outputMode;
  final Bias? bias;
  final ActiveState activeState;
  final bool isUsed;
}

/// Snapshot of a GPIO chip and all of its lines.
class GpioChipSnapshot {
  const GpioChipSnapshot({
    required this.index,
    required this.name,
    required this.label,
    required this.lines,
  });

  final int index;
  final String name;
  final String label;
  final List<GpioLineSnapshot> lines;

  int get usedLineCount => lines.where((l) => l.isUsed).length;
}

/// Reads the chips and lines available on this system.
typedef GpioLoader = Future<List<GpioChipSnapshot>> Function();

/// Reads all GPIO chips and lines using flutter_gpiod.
///
/// Line info is re-queried from the kernel on every call, so calling this
/// again picks up lines that were requested or released since.
Future<List<GpioChipSnapshot>> loadGpioChips() async {
  final chips = FlutterGpiod.instance.chips.values.toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  return [
    for (final chip in chips)
      GpioChipSnapshot(
        index: chip.index,
        name: chip.name,
        label: chip.label,
        lines: [
          for (var i = 0; i < chip.lines.length; i++)
            GpioLineSnapshot.fromInfo(i, chip.lines[i].info),
        ],
      ),
  ];
}
