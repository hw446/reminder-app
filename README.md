# Reminder Assistant

Reminder Assistant is a native macOS menu bar app that shows timed break reminders across every connected display. It uses Swift and AppKit with no third-party dependencies.

## Requirements

- macOS 12 or later
- Xcode Command Line Tools

## Build and Install

```bash
git clone https://github.com/hw446/reminder-app.git
cd reminder-app
./scripts/build-macos.sh
```

Open `dist/Reminder-Assistant-1.1.0.dmg`, then drag Reminder Assistant to Applications. The app is not notarized, so macOS may require you to right-click it and choose **Open** the first time.

## Usage Example

1. Click the timer icon in the menu bar and choose **Settings...**.
2. Keep the default `Take a break ♨️` message or enter your own.
3. Set the reminder interval and rest duration. The defaults are 20 minutes and 20 seconds.
4. Click **Start Reminders**.
5. Dismiss a reminder with a click, `Esc`, `Space`, or `Return`, or let its rest countdown finish.

The next reminder interval starts only after the rest ends. Each reminder covers the full bounds of every connected display. Timers pause while the Mac is locked or asleep.

Run the native scheduling and multi-display check with:

```bash
./scripts/smoke-test.sh
```

## License

Licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). Personal, educational, research, and other noncommercial use is allowed. Commercial use is prohibited.
