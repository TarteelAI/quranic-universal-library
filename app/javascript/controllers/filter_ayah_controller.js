import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.filter = this.el.find("#search-input");
    this.ayahs = this.el.find("#ayahs");
    this.headers = this.el.find("thead th");

    this.filter.on("input", this.filterAyah.bind(this));
    this.headers.on("click", this.sortColumn.bind(this));

    this.el.find(".group-header").on("click", this.toggleGroup.bind(this));
  }

  filterAyah() {
    const filter = this.filter.val().trim().toLowerCase();

    this.ayahs.find("tr").each((index, ayah) => {
      const text = ayah.firstElementChild.textContent.trim().toLowerCase();
      ayah.classList.toggle("d-none", !text.includes(filter));
    });
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
    const groupClass = $(event.currentTarget).data("target");
    $(groupClass).toggleClass("show");
  }
}
