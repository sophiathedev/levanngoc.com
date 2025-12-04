// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/levanngoc"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// OTP Input Hook - Auto-focus to next input
const OTPInput = {
  mounted() {
    this.el.addEventListener('input', (e) => {
      const value = e.target.value
      // Only allow digits
      if (value && !/^\d$/.test(value)) {
        e.target.value = ''
        return
      }

      // Move to next input if digit entered
      if (value.length === 1) {
        const nextInput = this.el.nextElementSibling
        if (nextInput) {
          nextInput.focus()
        }
      }
    })

    this.el.addEventListener('keydown', (e) => {
      // Move to previous input on backspace if current is empty
      if (e.key === 'Backspace' && !e.target.value) {
        const prevInput = this.el.previousElementSibling
        if (prevInput) {
          prevInput.focus()
        }
      }
    })

    this.el.addEventListener('paste', (e) => {
      e.preventDefault()
      const pastedData = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 8)
      const inputs = document.querySelectorAll('[phx-hook="OTPInput"]')
      pastedData.split('').forEach((char, index) => {
        if (inputs[index]) {
          inputs[index].value = char
        }
      })
      // Focus on last filled input or next empty
      const lastFilledIndex = Math.min(pastedData.length - 1, 7)
      if (inputs[lastFilledIndex + 1]) {
        inputs[lastFilledIndex + 1].focus()
      }
    })
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, OTPInput },
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Handle file downloads from LiveView
window.addEventListener("phx:download-file", (event) => {
  const { content, filename } = event.detail
  const blob = base64ToBlob(content)
  const url = window.URL.createObjectURL(blob)
  const a = document.createElement("a")
  a.style.display = "none"
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  window.URL.revokeObjectURL(url)
  document.body.removeChild(a)
})

window.addEventListener("phx:submit_sepay_form", (event) => {
  const { id } = event.detail
  const form = document.getElementById(id)
  if (form) {
    form.submit()
  }
})

// Helper function to convert base64 to blob
function base64ToBlob(base64) {
  const binaryString = window.atob(base64)
  const bytes = new Uint8Array(binaryString.length)
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }
  return new Blob([bytes])
}

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if (keyDown === "d") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

