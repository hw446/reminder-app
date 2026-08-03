const { app, BrowserWindow, Tray, Menu, ipcMain, nativeImage, screen, shell, powerMonitor } = require('electron')
const path = require('path')
const Store = require('electron-store')

const store = new Store()

let mainWindow = null
let overlayWindow = null
let tray = null
let reminderTimer = null
let countdownInterval = null
let isRunning = false
let remainingSeconds = 0
let currentIntervalMinutes = 0
let currentMessage = ''
let screenLocked = false

// ─── App Lifecycle ──────────────────────────────────────────────

app.whenReady().then(() => {
  createMainWindow()
  createTray()
  setupPowerMonitor()

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow()
    else mainWindow?.show()
  })
})

app.on('window-all-closed', (e) => {
  // Keep app alive in tray on macOS
  e.preventDefault()
})

app.on('before-quit', () => {
  clearTimers()
})

// ─── Main Window ─────────────────────────────────────────────────

function createMainWindow() {
  mainWindow = new BrowserWindow({
    width: 480,
    height: 640,
    minWidth: 400,
    minHeight: 560,
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 20, y: 20 },
    vibrancy: 'under-window',
    visualEffectState: 'active',
    backgroundColor: '#00000000',
    transparent: true,
    roundedCorners: true,
    resizable: true,
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    }
  })

  mainWindow.loadFile(path.join(__dirname, 'renderer/index.html'))

  mainWindow.once('ready-to-show', () => {
    mainWindow.show()
    // Restore saved settings
    const saved = store.get('settings')
    if (saved) {
      mainWindow.webContents.send('restore-settings', saved)
    }
  })

  mainWindow.on('close', (e) => {
    e.preventDefault()
    mainWindow.hide()
  })
}

// ─── Overlay (Fullscreen Reminder) — ALL Screens ─────────────────

let overlayWindows = []   // one per display

function createOverlayWindow(message) {
  const displays = screen.getAllDisplays()

  displays.forEach((display) => {
    const { x, y, width, height } = display.bounds

    const win = new BrowserWindow({
      x, y, width, height,
      frame: false,
      alwaysOnTop: true,
      backgroundColor: '#000000',
      skipTaskbar: true,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        preload: path.join(__dirname, 'preload.js')
      }
    })

    win.loadFile(path.join(__dirname, 'renderer/overlay.html'))
    win.setAlwaysOnTop(true, 'screen-saver')
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true })

    win.once('ready-to-show', () => {
      win.show()
      win.webContents.send('show-reminder', { message })
    })

    win.on('closed', () => {
      overlayWindows = overlayWindows.filter(w => w !== win)
    })

    overlayWindows.push(win)
  })
}

function closeOverlay() {
  overlayWindows.forEach(win => {
    if (!win.isDestroyed()) win.destroy()
  })
  overlayWindows = []
  // keep backward compat
  overlayWindow = null
}

// ─── Tray ─────────────────────────────────────────────────────────

function createTray() {
  // Create a simple 16x16 template image for tray
  const icon = nativeImage.createFromDataURL(getTrayIconDataURL())
  tray = new Tray(icon)
  tray.setToolTip('Reminder Assistant')
  updateTrayMenu()

  tray.on('click', () => {
    if (mainWindow) {
      mainWindow.isVisible() ? mainWindow.hide() : mainWindow.show()
    }
  })
}

function updateTrayMenu() {
  const contextMenu = Menu.buildFromTemplate([
    {
      label: isRunning ? '⏸ Stop Reminders' : '▶ Start Reminders',
      click: () => {
        if (isRunning) {
          mainWindow?.webContents.send('tray-stop')
        } else {
          mainWindow?.show()
          mainWindow?.webContents.send('tray-start')
        }
      }
    },
    { type: 'separator' },
    {
      label: 'Show Window',
      click: () => { mainWindow?.show() }
    },
    { type: 'separator' },
    {
      label: 'Quit',
      click: () => { app.exit(0) }
    }
  ])
  tray.setContextMenu(contextMenu)
}

// ─── Power / Screen Monitor ───────────────────────────────────────

function setupPowerMonitor() {
  // Screen locked
  powerMonitor.on('lock-screen', () => {
    if (!isRunning) return
    screenLocked = true
    pauseTimers()
    mainWindow?.webContents.send('screen-locked')
    console.log('[ReminderApp] Screen locked — timers paused')
  })

  // Screen unlocked
  powerMonitor.on('unlock-screen', () => {
    if (!isRunning) return
    screenLocked = false
    // Reset countdown from full interval when screen wakes
    remainingSeconds = currentIntervalMinutes * 60
    resumeTimers()
    mainWindow?.webContents.send('screen-unlocked')
    console.log('[ReminderApp] Screen unlocked — timers resumed')
  })

  // System sleep
  powerMonitor.on('suspend', () => {
    if (!isRunning) return
    screenLocked = true
    pauseTimers()
    mainWindow?.webContents.send('screen-locked')
    console.log('[ReminderApp] System suspended — timers paused')
  })

  // System wake
  powerMonitor.on('resume', () => {
    if (!isRunning) return
    screenLocked = false
    remainingSeconds = currentIntervalMinutes * 60
    resumeTimers()
    mainWindow?.webContents.send('screen-unlocked')
    console.log('[ReminderApp] System resumed — timers restarted')
  })
}



function startReminder(intervalMinutes, message) {
  clearTimers()
  isRunning = true
  currentIntervalMinutes = intervalMinutes
  currentMessage = message
  remainingSeconds = intervalMinutes * 60

  reminderTimer = setInterval(() => {
    triggerReminder(currentMessage)
    remainingSeconds = currentIntervalMinutes * 60
  }, intervalMinutes * 60 * 1000)

  countdownInterval = setInterval(() => {
    remainingSeconds = Math.max(0, remainingSeconds - 1)
    mainWindow?.webContents.send('countdown-tick', remainingSeconds)
  }, 1000)

  updateTrayMenu()
}

function pauseTimers() {
  if (reminderTimer)    { clearInterval(reminderTimer);    reminderTimer = null }
  if (countdownInterval){ clearInterval(countdownInterval); countdownInterval = null }
}

function resumeTimers() {
  if (!isRunning) return
  pauseTimers() // clear any existing timers before creating new ones

  // Restart main reminder timer from current remainingSeconds
  reminderTimer = setTimeout(function fire() {
    triggerReminder(currentMessage)
    remainingSeconds = currentIntervalMinutes * 60
    reminderTimer = setTimeout(fire, currentIntervalMinutes * 60 * 1000)
  }, remainingSeconds * 1000)

  countdownInterval = setInterval(() => {
    remainingSeconds = Math.max(0, remainingSeconds - 1)
    mainWindow?.webContents.send('countdown-tick', remainingSeconds)
  }, 1000)
}

function stopReminder() {
  clearTimers()
  isRunning = false
  currentIntervalMinutes = 0
  currentMessage = ''
  updateTrayMenu()
}

function clearTimers() {
  if (reminderTimer)    { clearTimeout(reminderTimer);  clearInterval(reminderTimer);  reminderTimer = null }
  if (countdownInterval){ clearInterval(countdownInterval); countdownInterval = null }
}

function triggerReminder(message) {
  createOverlayWindow(message)
  // Also bounce dock icon
  app.dock?.bounce('critical')
}

// ─── IPC Handlers ─────────────────────────────────────────────────

ipcMain.on('start-reminder', (_, { intervalMinutes, message }) => {
  startReminder(intervalMinutes, message)
  store.set('settings', { intervalMinutes, message })
  mainWindow?.webContents.send('reminder-started')
})

ipcMain.on('stop-reminder', () => {
  stopReminder()
  mainWindow?.webContents.send('reminder-stopped')
})

ipcMain.on('dismiss-overlay', () => {
  closeOverlay()
})

ipcMain.on('test-reminder', (_, { message }) => {
  triggerReminder(message || 'This is a test reminder 🔔')
})

ipcMain.on('save-settings', (_, settings) => {
  store.set('settings', settings)
})

ipcMain.handle('get-settings', () => {
  return store.get('settings', { intervalMinutes: 45, message: '' })
})

// ─── Tray Icon (SVG → DataURL) ────────────────────────────────────

function getTrayIconDataURL() {
  // Simple bell SVG as template image (black on transparent for macOS)
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">
    <path fill="#000000" d="M8 1a1 1 0 0 1 1 1v.5A4 4 0 0 1 12 6v3l1.5 1.5v.5h-11v-.5L4 9V6A4 4 0 0 1 7 2.5V2a1 1 0 0 1 1-1zm0 13a2 2 0 0 1-2-2h4a2 2 0 0 1-2 2z"/>
  </svg>`
  return `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`
}
