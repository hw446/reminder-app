// ── State ──────────────────────────────────────────────────────────
let interval = 45
let running = false

// ── DOM ───────────────────────────────────────────────────────────
const msgInput      = document.getElementById('msgInput')
const charCount     = document.getElementById('charCount')
const intervalDisp  = document.getElementById('intervalDisplay')
const statusDot     = document.getElementById('statusDot')
const statusText    = document.getElementById('statusText')
const countdown     = document.getElementById('countdown')
const btnMain       = document.getElementById('btnMain')
const btnTest       = document.getElementById('btnTest')
const btnUp         = document.getElementById('btnUp')
const btnDown       = document.getElementById('btnDown')
const presetBtns    = document.querySelectorAll('.preset-btn')

// ── Init ──────────────────────────────────────────────────────────
;(async () => {
  const saved = await window.electronAPI.getSettings()
  if (saved) {
    if (saved.intervalMinutes) setInterval_(saved.intervalMinutes)
    if (saved.message) {
      msgInput.value = saved.message
      updateCharCount()
    }
  }
})()

// ── Textarea ──────────────────────────────────────────────────────
msgInput.addEventListener('input', () => {
  updateCharCount()
  if (!running) saveSettings()
})

function updateCharCount() {
  charCount.textContent = msgInput.value.length
}

// ── Interval Controls ─────────────────────────────────────────────
btnUp.addEventListener('click', () => { if (!running) setInterval_(interval + 1) })
btnDown.addEventListener('click', () => { if (!running) setInterval_(interval - 1) })

presetBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    if (!running) setInterval_(parseInt(btn.dataset.val))
  })
})

function setInterval_(val) {
  interval = Math.max(1, Math.min(999, val))
  intervalDisp.textContent = interval
  updatePresetHighlight()
  if (!running) saveSettings()
}

function updatePresetHighlight() {
  presetBtns.forEach(btn => {
    btn.classList.toggle('active', parseInt(btn.dataset.val) === interval)
  })
}

// ── Main Button ───────────────────────────────────────────────────
btnMain.addEventListener('click', () => {
  if (running) {
    stopReminder()
  } else {
    startReminder()
  }
})

function startReminder() {
  const message = msgInput.value.trim()
  if (!message) {
    msgInput.focus()
    msgInput.style.borderColor = 'rgba(224,122,122,0.5)'
    msgInput.style.animation = 'shake 0.3s ease'
    setTimeout(() => {
      msgInput.style.borderColor = ''
      msgInput.style.animation = ''
    }, 800)
    return
  }

  window.electronAPI.startReminder({ intervalMinutes: interval, message })
}

function stopReminder() {
  window.electronAPI.stopReminder()
}

// ── Test Button ───────────────────────────────────────────────────
btnTest.addEventListener('click', () => {
  const message = msgInput.value.trim() || '这是一条测试提醒 🔔'
  window.electronAPI.testReminder({ message })
})

// ── IPC: Listeners from Main ──────────────────────────────────────
window.electronAPI.onReminderStarted(() => {
  running = true
  btnMain.textContent = '停止提醒'
  btnMain.classList.add('stop')
  statusDot.classList.add('active')
  statusText.textContent = `每 ${interval} 分钟提醒一次`
  setControlsDisabled(true)
})

window.electronAPI.onReminderStopped(() => {
  running = false
  btnMain.textContent = '开始提醒'
  btnMain.classList.remove('stop')
  statusDot.classList.remove('active')
  statusText.textContent = '已停止'
  countdown.textContent = ''
  setControlsDisabled(false)
})

window.electronAPI.onCountdownTick((seconds) => {
  const m = Math.floor(seconds / 60)
  const s = seconds % 60
  countdown.textContent = `${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`
})

window.electronAPI.onTrayStart(() => startReminder())
window.electronAPI.onTrayStop(() => stopReminder())

// ── Screen lock / unlock feedback ────────────────────────────────
window.electronAPI.onScreenLocked(() => {
  statusDot.classList.remove('active')
  statusDot.style.background = 'var(--muted)'
  statusText.textContent = '息屏中，计时已暂停'
  countdown.textContent = ''
})

window.electronAPI.onScreenUnlocked(() => {
  statusDot.classList.add('active')
  statusDot.style.background = ''
  statusText.textContent = `每 ${interval} 分钟提醒一次（已重置倒计时）`
})

// ── Helpers ───────────────────────────────────────────────────────
function setControlsDisabled(disabled) {
  msgInput.disabled = disabled
  btnUp.disabled = disabled
  btnDown.disabled = disabled
  presetBtns.forEach(b => b.disabled = disabled)
  if (disabled) {
    msgInput.style.opacity = '0.5'
  } else {
    msgInput.style.opacity = ''
  }
}

function saveSettings() {
  window.electronAPI.saveSettings({
    intervalMinutes: interval,
    message: msgInput.value.trim()
  })
}
