# Reminder Assistant

Reminder Assistant is a lightweight macOS app that shows customizable reminders across all connected displays. It runs in the menu bar, pauses while your Mac is locked or asleep, and lets you dismiss reminders with a click, `Esc`, `Space`, or `Enter`.

## Requirements

- macOS 12 or later
- Node.js 18 or later
- npm 9 or later

## Install and Run

```bash
git clone https://github.com/hw446/reminder-app.git
cd reminder-app
npm install
npm start
```

## Build a macOS App

```bash
npm install
npm run build
```

The packaged app and DMG will be created in `dist/`. Open the DMG and drag Reminder Assistant into `Applications`. Because the app is not notarized, macOS may require you to right-click the app and choose **Open** the first time.

## Usage Example

1. Enter `Drink water and stretch` as the reminder message.
2. Choose `45 分` as the interval.
3. Click **开始提醒**.
4. When the reminder appears, dismiss it with a click, `Esc`, `Space`, or `Enter`.
5. Use the menu bar icon to show the window, stop reminders, or quit the app.

Use **测试** to preview a reminder immediately. Reminders cover every connected display, and the countdown restarts after your Mac wakes or unlocks.

## License

Licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). Personal, educational, research, and other noncommercial use is allowed. Commercial use is prohibited.
