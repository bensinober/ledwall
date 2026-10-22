// Custom elements for the led wall control UI.
//
// The server is the source of truth for the active wall mode: a shared
// tracker polls /getMode and rebroadcasts "wallmodechange". <ledwall-mode-bar>
// uses it to highlight the active mode, and <ledwall-gamepad> swaps in the
// correct controls for whichever game is running.

const wallMode = {
  mode: null,
  timer: null,
  async refresh() {
    try {
      const res = await fetch("/getMode")
      if (res.ok) {
        this.set((await res.text()).trim())
        // re-broadcast each poll so late/failed renders self-heal
        document.dispatchEvent(new Event("wallmodetick"))
      }
    } catch {
      // wall unreachable; keep the last known mode
    }
  },
  set(mode) {
    if (!mode || mode === this.mode) return
    this.mode = mode
    document.dispatchEvent(new CustomEvent("wallmodechange", { detail: { mode } }))
  },
  start() {
    if (this.timer) return
    this.refresh()
    this.timer = setInterval(() => this.refresh(), 1500)
  },
}

// subscribe to mode changes; the callback fires immediately with the last
// known mode (may be null until the first /getMode poll resolves)
export function onWallMode(cb) {
  document.addEventListener("wallmodechange", (e) => cb(e.detail.mode))
  cb(wallMode.mode)
}

export async function setWallMode(mode) {
  wallMode.set(mode) // optimistic; the poll confirms
  try {
    await fetch(`/setMode/${mode}`)
  } catch (err) {
    console.error("failed to set mode:", err)
  }
}

// arms the wall for breakout (used by the breakout control page)
export function armBreakout() {
  return setWallMode("BREAKOUT")
}

const sendDirection = (d) => fetch(`/setDirection/${d}`).catch(() => {})
const sendLaunch = () => fetch("/launchBall").catch(() => {})

const MODES = [
  { id: "ANIMATION", label: "Animation" },
  { id: "SNAKE", label: "Snake" },
  { id: "BREAKOUT", label: "Breakout" },
  { id: "IDLE", label: "Pause" },
]

const BAR_CSS = `
  :host { display: flex; }
  .bar { display: flex; gap: 10px; flex-wrap: wrap; }
  button {
    font: 600 0.95rem/1.2 system-ui, sans-serif;
    padding: 10px 20px;
    color: #cfd6e4;
    background: #1a2028;
    border: 1px solid #2c3644;
    border-radius: 10px;
    cursor: pointer;
    transition: background 120ms, color 120ms, box-shadow 120ms, transform 80ms;
  }
  button:hover { background: #232c38; }
  button:active { transform: scale(0.97); }
  button.active {
    color: #0b0f14;
    background: linear-gradient(135deg, #4ade80, #22d3ee);
    border-color: transparent;
    box-shadow: 0 0 16px rgba(74, 222, 128, 0.45);
  }
`

class LedwallModeBar extends HTMLElement {
  connectedCallback() {
    if (this.shadowRoot) return
    const root = this.attachShadow({ mode: "open" })
    root.innerHTML = `<style>${BAR_CSS}</style><div class="bar"></div>`
    const bar = root.querySelector(".bar")
    this._btns = new Map()
    for (const { id, label } of MODES) {
      const b = document.createElement("button")
      b.textContent = label
      b.addEventListener("click", () => setWallMode(id))
      this._btns.set(id, b)
      bar.appendChild(b)
    }
    this._sync = () => {
      for (const [id, b] of this._btns) b.classList.toggle("active", wallMode.mode === id)
    }
    document.addEventListener("wallmodechange", this._sync)
    this._sync()
  }

  disconnectedCallback() {
    document.removeEventListener("wallmodechange", this._sync)
  }
}
customElements.define("ledwall-mode-bar", LedwallModeBar)

const PAD_CSS = `
  :host {
    display: block;
    color: #cfd6e4;
    user-select: none;
    -webkit-user-select: none;
    touch-action: manipulation;
  }
  .pad.snake {
    display: grid;
    gap: 12px;
    grid-template-columns: repeat(3, auto);
    justify-content: center;
    place-items: center;
  }
  .pad.breakout {
    display: flex;
    flex-direction: column;
    gap: 14px;
    align-items: center;
  }
  .pad.breakout .row { display: flex; gap: 14px; }
  .btn {
    display: flex;
    justify-content: center;
    align-items: center;
    width: 84px;
    height: 84px;
    font: 700 1.4rem system-ui, sans-serif;
    color: #0b0f14;
    background: #38bdf8;
    border: none;
    border-radius: 50%;
    cursor: pointer;
    box-shadow: 0 4px 14px rgba(0, 0, 0, 0.4);
    transition: filter 100ms, transform 80ms;
  }
  .btn:active, .btn.pressed { filter: brightness(1.25); transform: scale(0.94); }
  .btn.start { background: #4ade80; }
  .btn.launch { background: #fbbf24; }
  .btn.pill {
    width: auto;
    height: 56px;
    padding: 0 26px;
    font-size: 1rem;
    border-radius: 999px;
  }
  /* CSS triangles so all arrow keys are visually the same size on every font */
  .btn.tri::before {
    content: "";
    width: 0;
    height: 0;
  }
  .btn.t-up::before,
  .btn.t-down::before {
    border-left: 12px solid transparent;
    border-right: 12px solid transparent;
  }
  .btn.t-up::before {
    border-bottom: 20px solid currentColor;
  }
  .btn.t-down::before {
    border-top: 20px solid currentColor;
  }
  .btn.t-left::before,
  .btn.t-right::before {
    border-top: 12px solid transparent;
    border-bottom: 12px solid transparent;
  }
  .btn.t-left::before {
    border-right: 20px solid currentColor;
  }
  .btn.t-right::before {
    border-left: 20px solid currentColor;
  }
  .spacer { width: 84px; height: 84px; }
  .hint {
    margin: 14px 0 0;
    font: 500 0.85rem system-ui, sans-serif;
    color: #7c8798;
    text-align: center;
  }
`

class LedwallGamepad extends HTMLElement {
  connectedCallback() {
    if (this.shadowRoot) return
    const root = this.attachShadow({ mode: "open" })
    root.innerHTML = `<style>${PAD_CSS}</style><div class="pad"></div><p class="hint"></p>`
    this._pad = root.querySelector(".pad")
    this._hint = root.querySelector(".hint")
    this._onMode = () => this._render(wallMode.mode)
    document.addEventListener("wallmodechange", this._onMode)
    document.addEventListener("wallmodetick", this._onMode)
    // desktop keyboard: arrows + space/enter, interpreted per active mode
    this._onKey = (e) => this._handleKey(e)
    this._onKeyUp = (e) => this._handleKeyUp(e)
    document.addEventListener("keydown", this._onKey)
    document.addEventListener("keyup", this._onKeyUp)
    this._render(wallMode.mode)
  }

  disconnectedCallback() {
    document.removeEventListener("wallmodechange", this._onMode)
    document.removeEventListener("wallmodetick", this._onMode)
    document.removeEventListener("keydown", this._onKey)
    document.removeEventListener("keyup", this._onKeyUp)
  }

  _mk(label, cls, { press, release, tap, aria } = {}) {
    const b = document.createElement("button")
    b.className = "btn" + (cls ? " " + cls : "")
    b.textContent = label
    if (aria) b.setAttribute("aria-label", aria)
    if (tap) b.addEventListener("click", tap)
    if (press) {
      b.addEventListener("pointerdown", (e) => {
        e.preventDefault()
        b.classList.add("pressed")
        press()
      })
    }
    if (release) {
      const up = () => {
        b.classList.remove("pressed")
        release()
      }
      b.addEventListener("pointerup", up)
      b.addEventListener("pointercancel", up)
      b.addEventListener("pointerleave", up)
    }
    return b
  }

  _spacer() {
    const s = document.createElement("div")
    s.className = "spacer"
    return s
  }

  _render(mode) {
    this._pad.innerHTML = ""
    if (mode === "SNAKE") {
      this._pad.className = "pad snake"
      // NB: the wall y-axis is mirrored, so UP sends down (matches physical wall)
      this._pad.append(
        this._spacer(),
        this._mk("", "tri t-up", { tap: () => sendDirection("down"), aria: "Up" }),
        this._spacer(),
        this._mk("", "tri t-left", { tap: () => sendDirection("left"), aria: "Left" }),
        this._mk("START", "start pill", { tap: () => setWallMode("SNAKE") }),
        this._mk("", "tri t-right", { tap: () => sendDirection("right"), aria: "Right" }),
        this._spacer(),
        this._mk("", "tri t-down", { tap: () => sendDirection("up"), aria: "Down" }),
        this._spacer(),
      )
      this._hint.textContent = "Arrow keys steer the snake. ENTER restarts."
    } else if (mode === "BREAKOUT") {
      this._pad.className = "pad breakout"
      const row1 = document.createElement("div")
      row1.className = "row"
      row1.append(
        this._mk("", "tri t-left", { press: () => sendDirection("left"), release: () => sendDirection("stop"), aria: "Left" }),
        this._mk("", "tri t-right", { press: () => sendDirection("right"), release: () => sendDirection("stop"), aria: "Right" }),
      )
      const row2 = document.createElement("div")
      row2.className = "row"
      row2.append(
        this._mk("LAUNCH", "launch pill", { tap: () => sendLaunch() }),
        this._mk("START", "start pill", { tap: () => setWallMode("BREAKOUT") }),
      )
      this._pad.append(row1, row2)
      this._hint.textContent = "Hold ◀ ▶ to slide the paddle, release to stop. SPACE or LAUNCH fires the ball."
    } else {
      this._pad.className = "pad empty"
      const label = MODES.find((m) => m.id === mode)?.label
      this._hint.textContent = mode ? `${label || mode} — choose Snake or Breakout to play.` : "Connecting to wall…"
    }
  }

  _handleKey(e) {
    if (wallMode.mode === "SNAKE") {
      const map = { ArrowUp: "down", ArrowDown: "up", ArrowLeft: "left", ArrowRight: "right" } // mirrored y-axis
      const d = map[e.key]
      if (d) {
        e.preventDefault()
        sendDirection(d)
      } else if (e.key === "Enter") {
        setWallMode("SNAKE")
      }
    } else if (wallMode.mode === "BREAKOUT") {
      if (e.key === "ArrowLeft") {
        e.preventDefault()
        sendDirection("left")
      } else if (e.key === "ArrowRight") {
        e.preventDefault()
        sendDirection("right")
      } else if (e.key === " " || e.key === "ArrowUp") {
        e.preventDefault()
        sendLaunch()
      }
    }
  }

  _handleKeyUp(e) {
    if (wallMode.mode === "BREAKOUT" && (e.key === "ArrowLeft" || e.key === "ArrowRight")) {
      sendDirection("stop")
    }
  }
}
customElements.define("ledwall-gamepad", LedwallGamepad)

wallMode.start()
