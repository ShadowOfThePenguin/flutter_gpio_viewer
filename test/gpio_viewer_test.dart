import 'package:flutter/material.dart';
import 'package:flutter_gpio_display/src/gpio_source.dart';
import 'package:flutter_gpio_display/src/gpio_viewer_page.dart';
import 'package:flutter_gpiod/flutter_gpiod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<GpioChipSnapshot>> _fakeChips() async => const [
  GpioChipSnapshot(
    index: 0,
    name: 'gpiochip0',
    label: 'pinctrl-bcm2711',
    lines: [
      GpioLineSnapshot(
        offset: 0,
        name: 'ID_SDA',
        direction: LineDirection.input,
        activeState: ActiveState.high,
        isUsed: false,
      ),
      GpioLineSnapshot(
        offset: 42,
        name: 'STATUS_LED',
        consumer: 'led0',
        direction: LineDirection.output,
        bias: Bias.pullUp,
        activeState: ActiveState.low,
        isUsed: true,
      ),
    ],
  ),
  GpioChipSnapshot(
    index: 1,
    name: 'gpiochip1',
    label: 'raspberrypi-exp-gpio',
    lines: [],
  ),
];

Widget _app(GpioLoader loader, {Duration? refreshInterval}) => MaterialApp(
  home: GpioViewerPage(
    loader: loader,
    refreshInterval: refreshInterval,
    autoScroll: false,
  ),
);

void main() {
  testWidgets('shows all chips and lines without interaction', (tester) async {
    await tester.pumpWidget(_app(_fakeChips));
    await tester.pumpAndSettle();

    expect(find.textContaining('gpiochip0 · pinctrl-bcm2711'), findsOneWidget);
    expect(
      find.textContaining('gpiochip1 · raspberrypi-exp-gpio'),
      findsOneWidget,
    );
    expect(find.textContaining('2 chips · 2 lines · 1 in use'), findsOneWidget);

    expect(find.text('ID_SDA'), findsOneWidget);
    expect(find.text('free'), findsOneWidget);
    expect(find.text('STATUS_LED'), findsOneWidget);
    expect(find.text('led0'), findsOneWidget);
    expect(find.text('OUT PU AL'), findsOneWidget);
  });

  testWidgets('refreshes on its own', (tester) async {
    var calls = 0;
    Future<List<GpioChipSnapshot>> loader() async {
      calls++;
      return _fakeChips();
    }

    await tester.pumpWidget(
      _app(loader, refreshInterval: const Duration(seconds: 1)),
    );
    await tester.pump();
    expect(calls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 3);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows an error when GPIO cannot be read', (tester) async {
    await tester.pumpWidget(
      _app(() async => throw Exception('permission denied')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not read GPIO chips'), findsOneWidget);
  });

  testWidgets('auto-scrolls when lines do not fit a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<List<GpioChipSnapshot>> manyLines() async => [
      GpioChipSnapshot(
        index: 0,
        name: 'gpiochip0',
        label: 'pinctrl-bcm2711',
        lines: [
          for (var i = 0; i < 58; i++)
            GpioLineSnapshot(
              offset: i,
              name: 'GPIO$i',
              direction: LineDirection.input,
              activeState: ActiveState.high,
              isUsed: i.isEven,
              consumer: i.isEven ? 'some-long-consumer-name-$i' : null,
            ),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: GpioViewerPage(loader: manyLines, refreshInterval: null),
      ),
    );
    await tester.pump();
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollable.position.pixels, 0);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(scrollable.position.pixels, greaterThan(0));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 5));
  });
}
