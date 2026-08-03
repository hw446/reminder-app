const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  // Renderer → Main
  startReminder: (data) => ipcRenderer.send('start-reminder', data),
  stopReminder:  ()     => ipcRenderer.send('stop-reminder'),
  dismissOverlay:()     => ipcRenderer.send('dismiss-overlay'),
  testReminder:  (data) => ipcRenderer.send('test-reminder', data),
  saveSettings:  (data) => ipcRenderer.send('save-settings', data),
  getSettings:   ()     => ipcRenderer.invoke('get-settings'),

  // Main → Renderer (listeners)
  onCountdownTick:    (cb) => ipcRenderer.on('countdown-tick',    (_, v) => cb(v)),
  onReminderStarted:  (cb) => ipcRenderer.on('reminder-started',  ()     => cb()),
  onReminderStopped:  (cb) => ipcRenderer.on('reminder-stopped',  ()     => cb()),
  onRestoreSettings:  (cb) => ipcRenderer.on('restore-settings',  (_, v) => cb(v)),
  onTrayStart:        (cb) => ipcRenderer.on('tray-start',        ()     => cb()),
  onTrayStop:         (cb) => ipcRenderer.on('tray-stop',         ()     => cb()),
  onShowReminder:     (cb) => ipcRenderer.on('show-reminder',     (_, v) => cb(v)),
  onScreenLocked:     (cb) => ipcRenderer.on('screen-locked',     ()     => cb()),
  onScreenUnlocked:   (cb) => ipcRenderer.on('screen-unlocked',   ()     => cb()),

  // Remove listeners (cleanup)
  removeAllListeners: (channel) => ipcRenderer.removeAllListeners(channel)
})
