import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "surah", "statusButton", "visibleCount"]

  connect() {
    this.el = $(this.element);
    this.ayahs = this.el.find("#ayahs");
    this.headers = this.el.find("thead th");
    this.rows = this.ayahs.find("tr").toArray();
    this.status = "diff";

    this.headers.on("click", this.sortColumn.bind(this));
    this.el.find(".group-header").on("click", this.toggleGroup.bind(this));

    this.applyFilters();
  }

  setStatus(event) {
    this.status = event.currentTarget.dataset.status;

    this.statusButtonTargets.forEach((button) => {
      const active = button.dataset.status === this.status;
      button.classList.toggle("btn-primary", active);
      button.classList.toggle("btn-outline-info", !active);
    });

    this.applyFilters();
  }

  matchesStatus(status) {
    if (this.status === "all") return true;
    if (this.status === "diff") return status !== "same";
    return this.status === status;
  }

  // Any filter other than the plain "All" view is narrowing. While narrowing,
  // collapsed groups are forced open so a matching ayah is never hidden behind
  // its group header.
  applyFilters() {
    const search = this.searchTarget.value.trim().toLowerCase();
    const surah = this.surahTarget.value;
    const narrowed = this.status !== "all" || surah !== "" || search !== "";
    let visible = 0;

    this.rows.forEach((row) => {
      const verseKey = row.firstElementChild.textContent.trim().toLowerCase();
      const show = this.matchesStatus(row.dataset.status) &&
        (surah === "" || row.dataset.surah === surah) &&
        (search === "" || verseKey.includes(search));

      row.classList.toggle("hidden", !show);

      if (row.classList.contains("collapse")) {
        row.classList.toggle("show", narrowed && show);
      }

      if (show) visible += 1;
    });

    this.visibleCountTarget.textContent = visible;
  }

  sortColumn(event) {
    const header = $(event.target);
    const columnIndex = header.index();
    const isAscending = header.hasClass("asc");

    this.headers.removeClass("asc desc");
    header.addClass(isAscending ? "desc" : "asc");

    const rows = this.ayahs.find("tr.group-header").toArray();

    rows.sort((rowA, rowB) => {
      let cellA = rowA.cells[columnIndex].textContent.trim();
      let cellB = rowB.cells[columnIndex].textContent.trim();

      let numA = parseFloat(cellA), numB = parseFloat(cellB);
      if (!isNaN(numA) && !isNaN(numB)) {
        cellA = numA;
        cellB = numB;
      }

      return isAscending ? (cellA > cellB ? 1 : -1) : (cellA < cellB ? 1 : -1);
    });

    this.ayahs.append(rows);
  }

  toggleGroup(event) {
    if (event.target.closest("a, button")) return;

    const groupClass = $(event.currentTarget).data("target");
    $(groupClass).toggleClass("show");
  }
}
