import { Controller } from "@hotwired/stimulus"

const CONFIRM_MESSAGE = "You have unsaved changes. Are you sure you want to leave??";
const DIRTY_ATTR = 'd-value';
const BOOL_FIELDS = ['checkbox', 'radio'];

export default class extends Controller {
    dirty = false;
    isModal = false
    confirmLeaveMessage = null

    connect() {
        this.init();
        this.bindChangeEvents()
        this.leaveEvent = this.leavingPage.bind(this);
        this.isModal = this.element.dataset.modal;
        this.confirmLeaveMessage = this.element.dataset.confirmLeaveMessage;

        window.onbeforeunload = (e) => this.leaveEvent(e);
        document.addEventListener("turbo:before-visit", this.leaveEvent);
        //window.addEventListener("beforeunload", this.leaveEvent);
        this.dirty = 'true' == this.element.dataset.forceSubmit;

        //clear the dirty after submitting the form
        $(this.element).on("dirty:clear", () => {
            this.dirty = false
        })

        if (this.isModal) {
            let modal = this.element.closest('.modal');

            $(modal).on("hide.bs.modal", (e) => {
                return this.leavingPage(e);
            });
        }
    }

    disconnect() {
        document.removeEventListener("turbo:before-visit", this.leaveEvent);
        window.removeEventListener("beforeunload", this.leaveEvent);

        window.onbeforeunload = null;
    }

    bindChangeEvents() {
        $(this.element).on('change', (e) => {
            let target = e.target;

            if (BOOL_FIELDS.includes(target.type)) {
                this.dirty = target.getAttribute("d-value") != target.checked.toString();
            } else
                this.dirty = target.getAttribute("d-value") != target.value;
        });
    }

    /*
    * Save the initial values of all fields
    *
    */
    init() {
        this.element.querySelectorAll("select,input,textarea").forEach(input => {
            input.setAttribute(DIRTY_ATTR, input.value)
        })

        this.element.querySelectorAll("input[type=checkbox], input[type=radio]").forEach(input => {
            input.setAttribute(DIRTY_ATTR, input.checked.toString())
        });
    }

    leavingPage(event) {
        const message = this.confirmMessage

        if (this.dirty) {
            if (["turbo:before-visit", 'hide'].includes(event.type)) {
                if (!confirm(message)) {
                    event.stopPropagation();
                    event.preventDefault()
                    return false;
                }
            } else {
                event.returnValue = message;//Gecko + IE
                return message;//Gecko + Webkit, Safari, Chrome etc.
            }
        }
    }

    get confirmMessage() {
        return this.confirmLeaveMessage || CONFIRM_MESSAGE
    }
}