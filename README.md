# flutter_gpio_display

A Flutter app for single-board computers (Raspberry Pi and similar) that lists
every GPIO chip (`/dev/gpiochip*`) and each line on it. It is built to run on
[flutter-pi](https://github.com/ardera/flutter-pi) and reads GPIO through
[flutter_gpiod](https://pub.dev/packages/flutter_gpiod).

For each chip it shows the device name, label, and how many lines are in use.
Expand a chip to see each line's offset, name, consumer, direction, output
mode, bias and active state. You can filter by line number, name or consumer,
show only lines that are in use, and refresh to read the current state again.

## Project layout

- `lib/src/gpio_source.dart`: reads chips and line info through `FlutterGpiod.instance`
- `lib/src/gpio_viewer_page.dart`: the UI
- `test/gpio_viewer_test.dart`: widget tests that use fake GPIO data

## Running on the SBC with flutter-pi

1. Install flutter-pi on the board by following the
   [flutter-pi instructions](https://github.com/ardera/flutter-pi#-building-flutter-pi-on-the-raspberry-pi).
2. On your development machine, install `flutterpi_tool`:
   ```sh
   flutter pub global activate flutterpi_tool
   ```
3. Build the app bundle. Use `--arch=arm` for 32-bit OS images:
   ```sh
   flutter pub get
   flutterpi_tool build --arch=arm64 --release
   ```
4. Copy the bundle to the board:
   ```sh
   rsync -a ./build/flutter_assets/ pi@raspberrypi:/home/pi/gpio_viewer
   ```
5. Run it on the board, from a console rather than inside a desktop session:
   ```sh
   flutter-pi --release /home/pi/gpio_viewer
   ```

You can also use `flutterpi_tool run -d <device>` after adding the board with
`flutterpi_tool devices add pi@raspberrypi`.

### Permissions

flutter_gpiod opens `/dev/gpiochip*` read/write, so the user running
flutter-pi needs access to those devices. On Raspberry Pi OS that means being
in the `gpio` group:

```sh
sudo usermod -aG gpio $USER
```

If the devices can't be opened, the app shows the error and a Retry button.

## Development

Requires Dart SDK 3.12.0 or newer (Flutter 3.44.0+).

```sh
flutter pub get
flutter analyze
flutter test
```

On a machine without GPIO chips, the app starts and reports that it found
none. flutter_gpiod uses FFI against libc, so the Linux desktop build works too.
