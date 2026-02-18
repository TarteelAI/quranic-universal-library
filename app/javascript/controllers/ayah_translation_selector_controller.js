import { Controller } from "@hotwired/stimulus";
import { getAyahModalPrefs, setAyahModalPrefs } from "../lib/ayah_modal_store";

export default class extends Controller {
  static targets = [
    "panel",
    "backdrop",
    "form",
    "search",
    "translationList",
    "chevron",
    "groupContent",
  ];

  connect() {
    const prefs = getAyahModalPrefs();
    if (prefs.translationPanelOpen) {
      this.backdropTarget.classList.remove("tw-hidden");
      this.backdropTarget.classList.add("tw-block");
      this.panelTarget.classList.remove("tw-hidden");
      this.panelTarget.classList.add("tw-flex");
    }
    if (prefs.translationIds && prefs.translationIds.length) {
      const current = this.currentTranslationIds();
      const desired = prefs.translationIds
        .map((x) => parseInt(x, 10))
        .filter((x) => Number.isInteger(x));
      if (!this.sameIds(current, desired)) {
        this.setTranslationIds(desired);
        if (this.formTarget) this.formTarget.requestSubmit();
      }
    }
  }

  open(e) {
    e.preventDefault();
    setAyahModalPrefs({ translationPanelOpen: true });
    this.backdropTarget.classList.remove("tw-hidden");
    this.backdropTarget.classList.add("tw-block");
    this.panelTarget.classList.remove("tw-hidden");
    this.panelTarget.classList.add("tw-flex");
  }

  close(e) {
    e.preventDefault();
    setAyahModalPrefs({ translationPanelOpen: false });
    this.panelTarget.classList.add("tw-hidden");
    this.panelTarget.classList.remove("tw-flex");
    this.backdropTarget.classList.add("tw-hidden");
    this.backdropTarget.classList.remove("tw-block");
    // Submit form when closing to save translation selections
    if (this.formTarget) this.formTarget.requestSubmit();
  }

  change() {
    const ids = this.currentTranslationIds();
    setAyahModalPrefs({ translationIds: ids });
    // Removed form submission to prevent dropdown collapse during selection
  }

  currentTranslationIds() {
    if (!this.formTarget) return [];
    const inputs = this.formTarget.querySelectorAll(
      'input[name="translation_ids[]"]:checked',
    );
    return Array.from(inputs)
      .map((i) => parseInt(i.value, 10))
      .filter((x) => Number.isInteger(x));
  }

  setTranslationIds(ids) {
    if (!this.formTarget) return;
    const set = new Set(ids.map((x) => x.toString()));
    const inputs = this.formTarget.querySelectorAll(
      'input[name="translation_ids[]"]',
    );
    inputs.forEach((i) => {
      i.checked = set.has(i.value);
    });
    setAyahModalPrefs({ translationIds: ids });
  }

  sameIds(a, b) {
    const as = [...new Set(a)].sort((x, y) => x - y);
    const bs = [...new Set(b)].sort((x, y) => x - y);
    if (as.length !== bs.length) return false;
    for (let i = 0; i < as.length; i++) {
      if (as[i] !== bs[i]) return false;
    }
    return true;
  }

  search() {
    const query = this.searchTarget.value.toLowerCase();
    const items =
      this.translationListTarget.querySelectorAll(".translation-item");
    const groups =
      this.translationListTarget.querySelectorAll(".translation-group");

    if (query === "") {
      // Show all items and groups when search is empty
      items.forEach((item) => (item.style.display = ""));
      groups.forEach((group) => (group.style.display = ""));
      return;
    }

    // Find groups that match the search query (language names)
    const matchingGroups = [];
    groups.forEach((group) => {
      const language = group.dataset.language;
      if (language && language.includes(query)) {
        matchingGroups.push(group);
      }
    });

    // If any groups match the query (language search), show all items in those groups
    if (matchingGroups.length > 0) {
      items.forEach((item) => {
        const parentGroup = item.closest(".translation-group");
        const isInMatchingGroup = matchingGroups.includes(parentGroup);
        item.style.display = isInMatchingGroup ? "" : "none";
      });

      groups.forEach((group) => {
        const isMatching = matchingGroups.includes(group);
        group.style.display = isMatching ? "" : "none";

        // Expand matching groups
        if (isMatching) {
          const groupContent = group.querySelector(
            '[data-ayah-translation-selector-target="groupContent"]',
          );
          if (groupContent) {
            groupContent.classList.remove("tw-hidden");
            const chevron = group.querySelector(
              '[data-ayah-translation-selector-target="chevron"]',
            );
            if (chevron) chevron.style.transform = "rotate(180deg)";
          }
        }
      });
    } else {
      // No groups match, filter individual items by name
      items.forEach((item) => {
        const name = item.dataset.name;
        const matches = name.includes(query);
        item.style.display = matches ? "" : "none";
      });

      // Hide groups that have no visible items
      groups.forEach((group) => {
        const visibleItems = group.querySelectorAll(
          '.translation-item[style=""], .translation-item:not([style*="none"])',
        );
        group.style.display = visibleItems.length > 0 ? "" : "none";

        // If group is visible and has matching items, expand it
        if (visibleItems.length > 0) {
          const groupContent = group.querySelector(
            '[data-ayah-translation-selector-target="groupContent"]',
          );
          if (groupContent) {
            groupContent.classList.remove("tw-hidden");
            const chevron = group.querySelector(
              '[data-ayah-translation-selector-target="chevron"]',
            );
            if (chevron) chevron.style.transform = "rotate(180deg)";
          }
        }
      });
    }
  }

  toggleGroup(event) {
    const button = event.currentTarget;
    const group = button.dataset.group;
    const content = this.groupContentTargets.find(
      (target) => target.dataset.group === group,
    );
    const chevron = this.chevronTargets.find(
      (target) => target.dataset.group === group,
    );

    if (content) {
      content.classList.toggle("tw-hidden");
    }

    if (chevron) {
      const isExpanded = !content.classList.contains("tw-hidden");
      chevron.style.transform = isExpanded ? "rotate(180deg)" : "rotate(0deg)";
    }
  }
}
