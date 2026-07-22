import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["password", "passwordConfirmation", "email", "currentPassword"]
  static values = { originalEmail: String }

  connect() {
    this.refresh()
  }

  refresh() {
    const passwordChanged = this.hasPasswordTarget && this.passwordTarget.value.length > 0
    const emailChanged = this.hasEmailTarget && this.emailTarget.value !== this.originalEmailValue

    if (this.hasCurrentPasswordTarget) {
      this.currentPasswordTarget.required = passwordChanged || emailChanged
    }

    this.validatePasswordMatch()
  }

  validatePasswordMatch() {
    if (!(this.hasPasswordConfirmationTarget && this.hasPasswordTarget)) return

    const mismatch = this.passwordConfirmationTarget.value !== this.passwordTarget.value
    this.passwordConfirmationTarget.setCustomValidity(mismatch ? "Passwords do not match." : "")
  }
}
