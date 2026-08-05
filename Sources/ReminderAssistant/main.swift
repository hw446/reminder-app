import AppKit
import Darwin

private let defaultMessage = "Take a break ♨️"
private let defaultIntervalMinutes = 20
private let defaultRestSeconds = 20

private enum DefaultsKey {
    static let message = "message"
    static let intervalMinutes = "intervalMinutes"
    static let restSeconds = "restSeconds"
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class OverlayView: NSView {
    private let countdownLabel = NSTextField(labelWithString: "")
    private let onDismiss: () -> Void

    init(message: String, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: "Break")
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        icon.contentTintColor = NSColor(calibratedRed: 0.91, green: 0.79, blue: 0.48, alpha: 1)

        let messageLabel = NSTextField(wrappingLabelWithString: message)
        messageLabel.alignment = .center
        messageLabel.font = .systemFont(ofSize: 44, weight: .light)
        messageLabel.textColor = .white
        messageLabel.maximumNumberOfLines = 0

        countdownLabel.alignment = .center
        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        countdownLabel.textColor = NSColor.white.withAlphaComponent(0.55)

        let hint = NSTextField(labelWithString: "Click anywhere or press Esc, Space, or Return")
        hint.alignment = .center
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = NSColor.white.withAlphaComponent(0.3)

        let stack = NSStackView(views: [icon, messageLabel, countdownLabel, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.8),
            messageLabel.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.75)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onDismiss()
    }

    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers ?? ""
        if event.keyCode == 53 || key == " " || key == "\r" || key == "\n" {
            onDismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    func updateCountdown(_ seconds: Int) {
        countdownLabel.stringValue = "Closes automatically in \(seconds)s"
    }
}

private final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var views: [OverlayView] = []
    private var timer: Timer?
    private var completion: (() -> Void)?
    private var message = ""
    private var endDate: Date?

    var isShowing: Bool { !windows.isEmpty }
    var windowFrames: [NSRect] { windows.map(\.frame) }
    var allWindowsVisible: Bool { windows.allSatisfy(\.isVisible) }

    var remainingSeconds: Int {
        guard let endDate else { return 0 }
        return max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    func show(message: String, duration: Int, onFinished: @escaping () -> Void) {
        close(notifyCompletion: false)
        self.message = message
        completion = onFinished
        endDate = Date().addingTimeInterval(TimeInterval(duration))
        createWindows()
        updateCountdown()

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refreshScreens() {
        guard isShowing else { return }
        closeWindows()
        createWindows()
        updateCountdown()
    }

    func close(notifyCompletion: Bool) {
        timer?.invalidate()
        timer = nil
        endDate = nil
        closeWindows()

        let callback = completion
        completion = nil
        if notifyCompletion {
            callback?()
        }
    }

    private func tick() {
        if remainingSeconds == 0 {
            close(notifyCompletion: true)
        } else {
            updateCountdown()
        }
    }

    private func updateCountdown() {
        let seconds = remainingSeconds
        views.forEach { $0.updateCountdown(seconds) }
    }

    private func createWindows() {
        for screen in NSScreen.screens {
            let view = OverlayView(message: message) { [weak self] in
                self?.close(notifyCompletion: true)
            }
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.setFrame(screen.frame, display: false)
            window.contentView = view
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.isReleasedWhenClosed = false
            window.orderFrontRegardless()
            windows.append(window)
            views.append(view)
        }

        if let window = windows.first, let view = views.first {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
        }
    }

    private func closeWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        views.removeAll()
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    private let defaults = UserDefaults.standard
    private let overlayController = OverlayController()

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow!
    private var statusMenuItem: NSMenuItem!
    private var startMenuItem: NSMenuItem!
    private var stopMenuItem: NSMenuItem!

    private let messageField = NSTextField()
    private let intervalField = NSTextField()
    private let restField = NSTextField()
    private let intervalStepper = NSStepper()
    private let restStepper = NSStepper()
    private let statusLabel = NSTextField(labelWithString: "Stopped")
    private let testButton = NSButton()
    private let startButton = NSButton()

    private var intervalTimer: Timer?
    private var statusTimer: Timer?
    private var nextReminderDate: Date?
    private var isRunning = false
    private var isSystemPaused = false
    private var activeMessage = defaultMessage
    private var activeIntervalMinutes = defaultIntervalMinutes
    private var activeRestSeconds = defaultRestSeconds

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        defaults.register(defaults: [
            DefaultsKey.message: defaultMessage,
            DefaultsKey.intervalMinutes: defaultIntervalMinutes,
            DefaultsKey.restSeconds: defaultRestSeconds
        ])

        createSettingsWindow()
        createStatusItem()
        observeSystemEvents()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
        refreshControls()

        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            DispatchQueue.main.async { [weak self] in
                self?.runSmokeTest()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        intervalTimer?.invalidate()
        statusTimer?.invalidate()
        overlayController.close(notifyCompletion: false)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        _ = saveSettings()
    }

    private func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Reminder Assistant")
            button.image?.isTemplate = true
            button.toolTip = "Reminder Assistant"
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",").target = self

        statusMenuItem = NSMenuItem(title: "Stopped", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        startMenuItem = menu.addItem(withTitle: "Start Reminders", action: #selector(startRemindersFromMenu), keyEquivalent: "")
        startMenuItem.target = self
        stopMenuItem = menu.addItem(withTitle: "Stop Reminders", action: #selector(stopRemindersFromMenu), keyEquivalent: "")
        stopMenuItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    private func createSettingsWindow() {
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Reminder Assistant"
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.center()

        let contentView = NSView()
        settingsWindow.contentView = contentView

        let title = NSTextField(labelWithString: "Reminder Assistant")
        title.font = .systemFont(ofSize: 22, weight: .semibold)

        let messageLabel = fieldLabel("Reminder message")
        messageField.stringValue = defaults.string(forKey: DefaultsKey.message) ?? defaultMessage
        messageField.placeholderString = defaultMessage
        messageField.font = .systemFont(ofSize: 14)
        messageField.delegate = self
        messageField.translatesAutoresizingMaskIntoConstraints = false
        messageField.widthAnchor.constraint(equalToConstant: 410).isActive = true

        let intervalLabel = fieldLabel("Reminder interval")
        configureNumberField(intervalField, value: defaults.integer(forKey: DefaultsKey.intervalMinutes), min: 1, max: 999)
        configureStepper(intervalStepper, value: intervalField.integerValue, min: 1, max: 999, action: #selector(intervalStepperChanged))
        let intervalRow = numberRow(field: intervalField, stepper: intervalStepper, suffix: "minutes")

        let restLabel = fieldLabel("Rest duration")
        configureNumberField(restField, value: defaults.integer(forKey: DefaultsKey.restSeconds), min: 1, max: 3600)
        configureStepper(restStepper, value: restField.integerValue, min: 1, max: 3600, action: #selector(restStepperChanged))
        let restRow = numberRow(field: restField, stepper: restStepper, suffix: "seconds")

        statusLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.widthAnchor.constraint(equalToConstant: 410).isActive = true

        testButton.title = "Test Reminder"
        testButton.bezelStyle = .rounded
        testButton.target = self
        testButton.action = #selector(testReminder)

        startButton.title = "Start Reminders"
        startButton.bezelStyle = .rounded
        startButton.keyEquivalent = "\r"
        startButton.target = self
        startButton.action = #selector(toggleReminders)

        let buttonRow = NSStackView(views: [testButton, startButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 10

        let stack = NSStackView(views: [
            title,
            messageLabel,
            messageField,
            intervalLabel,
            intervalRow,
            restLabel,
            restRow,
            statusLabel,
            buttonRow
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(20, after: title)
        stack.setCustomSpacing(18, after: messageField)
        stack.setCustomSpacing(18, after: intervalRow)
        stack.setCustomSpacing(22, after: restRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 25),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -25),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -22)
        ])
    }

    private func fieldLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func configureNumberField(_ field: NSTextField, value: Int, min: Int, max: Int) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: min)
        formatter.maximum = NSNumber(value: max)
        formatter.allowsFloats = false

        field.integerValue = value
        field.alignment = .right
        field.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        field.formatter = formatter
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 82).isActive = true
    }

    private func configureStepper(_ stepper: NSStepper, value: Int, min: Int, max: Int, action: Selector) {
        stepper.integerValue = value
        stepper.minValue = Double(min)
        stepper.maxValue = Double(max)
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = action
    }

    private func numberRow(field: NSTextField, stepper: NSStepper, suffix: String) -> NSStackView {
        let suffixLabel = NSTextField(labelWithString: suffix)
        suffixLabel.textColor = .secondaryLabelColor
        let row = NSStackView(views: [field, stepper, suffixLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func observeSystemEvents() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(self, selector: #selector(pauseForSystem), name: NSWorkspace.willSleepNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(resumeAfterSystem), name: NSWorkspace.didWakeNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(pauseForSystem), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspaceCenter.addObserver(self, selector: #selector(resumeAfterSystem), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    private func saveSettings() -> (message: String, intervalMinutes: Int, restSeconds: Int) {
        let trimmedMessage = messageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = trimmedMessage.isEmpty ? defaultMessage : String(trimmedMessage.prefix(200))
        let interval = max(1, min(999, intervalField.integerValue))
        let rest = max(1, min(3600, restField.integerValue))

        messageField.stringValue = message
        intervalField.integerValue = interval
        intervalStepper.integerValue = interval
        restField.integerValue = rest
        restStepper.integerValue = rest
        defaults.set(message, forKey: DefaultsKey.message)
        defaults.set(interval, forKey: DefaultsKey.intervalMinutes)
        defaults.set(rest, forKey: DefaultsKey.restSeconds)
        return (message, interval, rest)
    }

    private func startReminders() {
        let settings = saveSettings()
        activeMessage = settings.message
        activeIntervalMinutes = settings.intervalMinutes
        activeRestSeconds = settings.restSeconds
        isRunning = true
        isSystemPaused = false
        scheduleNextReminder()
        refreshControls()
    }

    private func stopReminders() {
        isRunning = false
        isSystemPaused = false
        intervalTimer?.invalidate()
        intervalTimer = nil
        nextReminderDate = nil
        overlayController.close(notifyCompletion: false)
        refreshControls()
    }

    private func scheduleNextReminder() {
        guard isRunning, !isSystemPaused else { return }
        intervalTimer?.invalidate()
        let delay = TimeInterval(activeIntervalMinutes * 60)
        nextReminderDate = Date().addingTimeInterval(delay)

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.beginRest()
        }
        RunLoop.main.add(timer, forMode: .common)
        intervalTimer = timer
        updateStatus()
    }

    private func beginRest() {
        guard isRunning else { return }
        intervalTimer?.invalidate()
        intervalTimer = nil
        nextReminderDate = nil
        overlayController.show(message: activeMessage, duration: activeRestSeconds) { [weak self] in
            self?.scheduleNextReminder()
        }
        updateStatus()
    }

    private func refreshControls() {
        let settingsEnabled = !isRunning
        messageField.isEnabled = settingsEnabled
        intervalField.isEnabled = settingsEnabled
        intervalStepper.isEnabled = settingsEnabled
        restField.isEnabled = settingsEnabled
        restStepper.isEnabled = settingsEnabled
        testButton.isEnabled = settingsEnabled
        startButton.title = isRunning ? "Stop Reminders" : "Start Reminders"
        startMenuItem?.isEnabled = !isRunning
        stopMenuItem?.isEnabled = isRunning
        updateStatus()
    }

    private func updateStatus() {
        let text: String
        if isSystemPaused {
            text = "Paused while your Mac is locked or asleep"
        } else if overlayController.isShowing {
            let prefix = isRunning ? "Resting" : "Preview"
            text = "\(prefix): \(overlayController.remainingSeconds)s remaining"
        } else if isRunning, let nextReminderDate {
            let seconds = max(0, Int(ceil(nextReminderDate.timeIntervalSinceNow)))
            text = "Next reminder in \(formatDuration(seconds))"
        } else {
            text = "Stopped"
        }

        statusLabel.stringValue = text
        statusMenuItem?.title = text
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remaining = seconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remaining)
        }
        return String(format: "%02d:%02d", minutes, remaining)
    }

    private func runSmokeTest() {
        activeMessage = defaultMessage
        activeIntervalMinutes = defaultIntervalMinutes
        activeRestSeconds = 1
        isRunning = true
        beginRest()

        let expectedFrames = NSScreen.screens.map(\.frame)
        let actualFrames = overlayController.windowFrames
        let coversEveryScreen = expectedFrames.count == actualFrames.count
            && expectedFrames.allSatisfy { expected in
                actualFrames.contains { actual in NSEqualRects(expected, actual) }
            }
            && overlayController.allWindowsVisible
        let timerPausedDuringRest = intervalTimer == nil && nextReminderDate == nil
        let menuBarReady = statusItem.button?.image != nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self else { exit(1) }
            let nextDelay = self.nextReminderDate?.timeIntervalSinceNow ?? -1
            let timerStartedAfterRest = !self.overlayController.isShowing
                && self.intervalTimer != nil
                && nextDelay > 1198
                && nextDelay <= 1200
            let passed = coversEveryScreen && timerPausedDuringRest && timerStartedAfterRest && menuBarReady
            let formattedDelay = String(format: "%.1f", nextDelay)
            print("SMOKE_TEST passed=\(passed) screens=\(expectedFrames.count) timerPausedDuringRest=\(timerPausedDuringRest) nextDelay=\(formattedDelay)")
            fflush(stdout)
            self.stopReminders()
            exit(passed ? 0 : 1)
        }
    }

    @objc private func showSettings() {
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleReminders() {
        isRunning ? stopReminders() : startReminders()
    }

    @objc private func startRemindersFromMenu() {
        startReminders()
    }

    @objc private func stopRemindersFromMenu() {
        stopReminders()
    }

    @objc private func testReminder() {
        let settings = saveSettings()
        overlayController.show(message: settings.message, duration: settings.restSeconds) { [weak self] in
            self?.updateStatus()
        }
        updateStatus()
    }

    @objc private func intervalStepperChanged() {
        intervalField.integerValue = intervalStepper.integerValue
        _ = saveSettings()
    }

    @objc private func restStepperChanged() {
        restField.integerValue = restStepper.integerValue
        _ = saveSettings()
    }

    @objc private func pauseForSystem() {
        guard isRunning, !isSystemPaused else { return }
        isSystemPaused = true
        intervalTimer?.invalidate()
        intervalTimer = nil
        nextReminderDate = nil
        overlayController.close(notifyCompletion: false)
        updateStatus()
    }

    @objc private func resumeAfterSystem() {
        guard isRunning, isSystemPaused else { return }
        isSystemPaused = false
        scheduleNextReminder()
    }

    @objc private func screensChanged() {
        overlayController.refreshScreens()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let application = NSApplication.shared
private let delegate = AppDelegate()
application.delegate = delegate
application.run()
