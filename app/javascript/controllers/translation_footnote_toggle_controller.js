import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  toggle(e) {
    e.preventDefault();
    e.stopPropagation();

    const sup = e.currentTarget;
    const id = sup.getAttribute("data-footnote-id");
    if (!id) return;

    const block = this.element.querySelector(`[data-footnote-block-id="${id}"]`);
    if (!block) return;

    if (block.classList.contains("tw-hidden")) {
      this.element
        .querySelectorAll("[data-footnote-block-id]")
        .forEach((el) => el.classList.add("tw-hidden"));
      block.classList.remove("tw-hidden");
    } else {
      block.classList.add("tw-hidden");
    }
  }

  close(e) {
    e.preventDefault();
    e.stopPropagation();

    const btn = e.currentTarget;
    const id = btn.getAttribute("data-footnote-close-id");
    if (!id) return;

    const block = this.element.querySelector(`[data-footnote-block-id="${id}"]`);
    if (block) block.classList.add("tw-hidden");
  }
}


