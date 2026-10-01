import 'package:flutter/material.dart';
import 'package:flutter_gpio_display/main.dart';
import 'package:flutter_gpio_display/src/gpio_source.dart';
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

void main() {
  testWidgets('lists chips and their lines', (tester) async {
    await tester.pumpWidget(const MainApp(loader: _fakeChips));
    await tester.pumpAndSettle();

    expect(find.text('gpiochip0  ·  pinctrl-bcm2711'), findsOneWidget);
    expect(find.text('gpiochip1  ·  raspberrypi-exp-gpio'), findsOneWidget);
    expect(find.text('2 lines, 1 in use'), findsOneWidget);

    await tester.tap(find.text('gpiochip0  ·  pinctrl-bcm2711'));
    await tester.pumpAndSettle();

    expect(find.text('ID_SDA'), findsOneWidget);
    expect(find.text('STATUS_LED'), findsOneWidget);
    expect(find.text('Used by led0'), findsOneWidget);
    expect(find.text('active-low'), findsOneWidget);

    await tester.tap(find.text('Used only'));
    await tester.pumpAndSettle();

    expect(find.text('ID_SDA'), findsNothing);
    expect(find.text('STATUS_LED'), findsOneWidget);
  });

  testWidgets('shows an error when GPIO cannot be read', (tester) async {
    await tester.pumpWidget(
      MainApp(loader: () async => throw Exception('permission denied')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not read GPIO chips'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
