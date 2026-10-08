import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "qudRadio", "quaNotice", "qudTransport"]

  open() {
    this.dialogTarget.showModal()
    this.sourceChanged()
  }

  close() {
    this.dialogTarget.close()
  }

  sourceChanged() {
    if (!this.hasQudRadioTarget) return

    const qud = this.qudRadioTarget.checked

    if (this.hasQudTransportTarget) this.qudTransportTarget.classList.toggle("hidden", !qud)
    if (this.hasQuaNoticeTarget) this.quaNoticeTarget.classList.toggle("hidden", !qud)
  }
}
