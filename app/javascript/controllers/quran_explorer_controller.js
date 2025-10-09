import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["sortSelect", "sortDirection", "gridViewBtn", "juzViewBtn", "gridViewContent", "juzViewContent", "sortControls"];
  static values = {
    direction: String,
    view: String
  };

  connect() {
    this.currentDirection = this.directionValue || "asc";
    this.currentView = this.viewValue || "grid";
    
    this.updateSortIcon();
    this.updateViewButtons();
    this.toggleSortControls();
  }
  
  // Toggle visibility of sort controls based on view
  toggleSortControls() {
    if (this.hasSortControlsTarget) {
      if (this.currentView === 'juz') {
        this.sortControlsTarget.classList.add('tw-hidden');
      } else {
        this.sortControlsTarget.classList.remove('tw-hidden');
      }
    }
  }

  // Update sort direction icon
  updateSortIcon() {
    const icon = this.sortDirectionTarget.querySelector('svg path');
    if (this.currentDirection === 'desc') {
      icon.setAttribute('d', 'M3 4h13M3 8h9m-9 4h6m4 0l4 4m0 0l4-4m-4 4v12');
    } else {
      icon.setAttribute('d', 'M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12');
    }
  }

  // Update view toggle buttons
  updateViewButtons() {
    if (this.currentView === 'juz') {
      this.gridViewBtnTarget.classList.remove('tw-bg-white', 'tw-text-[#57d798]', 'tw-shadow-sm');
      this.gridViewBtnTarget.classList.add('tw-text-gray-600', 'hover:tw-text-[#57d798]');
      this.juzViewBtnTarget.classList.add('tw-bg-white', 'tw-text-[#57d798]', 'tw-shadow-sm');
      this.juzViewBtnTarget.classList.remove('tw-text-gray-600', 'hover:tw-text-[#57d798]');
    } else {
      this.juzViewBtnTarget.classList.remove('tw-bg-white', 'tw-text-[#57d798]', 'tw-shadow-sm');
      this.juzViewBtnTarget.classList.add('tw-text-gray-600', 'hover:tw-text-[#57d798]');
      this.gridViewBtnTarget.classList.add('tw-bg-white', 'tw-text-[#57d798]', 'tw-shadow-sm');
      this.gridViewBtnTarget.classList.remove('tw-text-gray-600', 'hover:tw-text-[#57d798]');
    }
  }

  // Handle view toggle
  switchView(view) {
    this.currentView = view;
    this.updateViewButtons();
    this.toggleSortControls();
    
    const url = new URL(window.location);
    url.searchParams.set('view', view);
    if (view !== 'juz') {
      url.searchParams.set('sort', this.sortSelectTarget.value);
      url.searchParams.set('direction', this.currentDirection);
    }
    window.location.href = url.toString();
  }

  // Handle sort selection change
  sortChanged(event) {
    const url = new URL(window.location);
    url.searchParams.set('sort', event.target.value);
    url.searchParams.set('direction', this.currentDirection);
    url.searchParams.set('view', this.currentView);
    window.location.href = url.toString();
  }

  // Handle sort direction toggle
  toggleSortDirection() {
    this.currentDirection = this.currentDirection === 'asc' ? 'desc' : 'asc';
    this.updateSortIcon();
    
    const url = new URL(window.location);
    url.searchParams.set('sort', this.sortSelectTarget.value);
    url.searchParams.set('direction', this.currentDirection);
    url.searchParams.set('view', this.currentView);
    window.location.href = url.toString();
  }

  // Handle grid view button click
  showGridView() {
    this.switchView('grid');
  }

  // Handle juz view button click
  showJuzView() {
    this.switchView('juz');
  }
}

