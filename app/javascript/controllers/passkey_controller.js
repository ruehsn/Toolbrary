import { Controller } from "@hotwired/stimulus"

// Drives WebAuthn passkey ceremonies.
//   data-action="passkey#register"     – add a passkey to the signed-in account
//   data-action="passkey#authenticate" – sign in with a passkey
// Values: optionsUrl (returns JSON options), submitUrl (verifies the credential).
export default class extends Controller {
  static values = { optionsUrl: String, submitUrl: String }
  static targets = ["error", "nickname", "button"]

  connect() {
    if (!window.PublicKeyCredential) {
      this.element.hidden = true
    }
  }

  async register(event) {
    event.preventDefault()
    await this.#run(async () => {
      const options = await this.#post(this.optionsUrlValue)
      const credential = await navigator.credentials.create({ publicKey: decodeCreationOptions(options) })
      const nickname = this.hasNicknameTarget ? this.nicknameTarget.value : ""
      return this.#post(this.submitUrlValue, { credential: encodeCredential(credential), nickname })
    })
  }

  async authenticate(event) {
    event.preventDefault()
    await this.#run(async () => {
      const options = await this.#post(this.optionsUrlValue)
      const credential = await navigator.credentials.get({ publicKey: decodeRequestOptions(options) })
      return this.#post(this.submitUrlValue, { credential: encodeCredential(credential) })
    })
  }

  async #run(ceremony) {
    this.#showError("")
    this.#busy(true)
    try {
      const result = await ceremony()
      window.Turbo ? Turbo.visit(result.redirect_to) : (window.location = result.redirect_to)
    } catch (error) {
      if (error.name === "NotAllowedError" || error.name === "AbortError") {
        this.#showError("Passkey prompt was cancelled.")
      } else if (error.name === "InvalidStateError") {
        this.#showError("This device already has a passkey for your account.")
      } else {
        this.#showError(error.message || "Something went wrong with the passkey.")
      }
    } finally {
      this.#busy(false)
    }
  }

  async #post(url, body = {}) {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      credentials: "same-origin",
      body: JSON.stringify(body)
    })
    const data = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`)
    return data
  }

  #showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.hidden = !message
    }
  }

  #busy(isBusy) {
    if (this.hasButtonTarget) this.buttonTarget.disabled = isBusy
  }
}

// --- base64url <-> ArrayBuffer helpers ---------------------------------------
function toBuffer(base64url) {
  const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/")
  const padded = base64 + "=".repeat((4 - (base64.length % 4)) % 4)
  return Uint8Array.from(atob(padded), c => c.charCodeAt(0)).buffer
}

function toBase64url(buffer) {
  let binary = ""
  new Uint8Array(buffer).forEach(b => (binary += String.fromCharCode(b)))
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

function decodeCreationOptions(options) {
  return {
    ...options,
    challenge: toBuffer(options.challenge),
    user: { ...options.user, id: toBuffer(options.user.id) },
    excludeCredentials: (options.excludeCredentials || []).map(c => ({ ...c, id: toBuffer(c.id) }))
  }
}

function decodeRequestOptions(options) {
  return {
    ...options,
    challenge: toBuffer(options.challenge),
    allowCredentials: (options.allowCredentials || []).map(c => ({ ...c, id: toBuffer(c.id) }))
  }
}

function encodeCredential(credential) {
  const r = credential.response
  const response = { clientDataJSON: toBase64url(r.clientDataJSON) }
  if (r.attestationObject) {
    response.attestationObject = toBase64url(r.attestationObject)
    if (r.getTransports) response.transports = r.getTransports()
  }
  if (r.authenticatorData) {
    response.authenticatorData = toBase64url(r.authenticatorData)
    response.signature = toBase64url(r.signature)
    response.userHandle = r.userHandle ? toBase64url(r.userHandle) : null
  }
  return {
    type: credential.type,
    id: credential.id,
    rawId: toBase64url(credential.rawId),
    authenticatorAttachment: credential.authenticatorAttachment,
    clientExtensionResults: credential.getClientExtensionResults(),
    response
  }
}
