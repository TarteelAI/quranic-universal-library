import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['suggestions', 'morphologyFilter']
  static values = { 
    suggestionsUrl: String,
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    this.setupTypeHelpers()
    this.debounceTimer = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  // Handle search type change
  onTypeChange(event) {
    const selectedType = event.target.value
    this.updateTypeHelpers(selectedType)
    this.toggleMorphologyFilter(selectedType)
  }

  // Update search suggestions with debouncing
  updateSuggestions(event) {
    const query = event.target.value.trim()
    
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = setTimeout(() => {
      this.fetchSuggestions(query)
    }, this.debounceDelayValue)
  }

  // Setup type-specific help text
  setupTypeHelpers() {
    const typeSelect = this.element.querySelector('select[name="type"]')
    if (typeSelect) {
      this.updateTypeHelpers(typeSelect.value)
    }
  }

  // Update help text based on selected search type
  updateTypeHelpers(selectedType) {
    const helpContainers = this.element.querySelectorAll('.search-type-help [data-type]')
    
    helpContainers.forEach(container => {
      const containerType = container.dataset.type
      if (containerType === selectedType) {
        container.classList.remove('hidden')
      } else {
        container.classList.add('hidden')
      }
    })
  }

  // Show/hide morphology filter based on search type
  toggleMorphologyFilter(selectedType) {
    if (this.hasMorphologyFilterTarget) {
      if (selectedType === 'morphology') {
        this.morphologyFilterTarget.classList.remove('hidden')
      } else {
        this.morphologyFilterTarget.classList.add('hidden')
      }
    }
  }

  // Fetch search suggestions from API
  async fetchSuggestions(query) {
    if (!query || query.length < 2) {
      this.hideSuggestions()
      return
    }

    try {
      const response = await fetch(`/api/v1/search/suggestions?q=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.displaySuggestions(data.suggestions)
      } else {
        console.error('Failed to fetch suggestions:', response.statusText)
        this.hideSuggestions()
      }
    } catch (error) {
      console.error('Error fetching suggestions:', error)
      this.hideSuggestions()
    }
  }

  // Display search suggestions
  displaySuggestions(suggestions) {
    if (!this.hasSuggestionsTarget) return

    const suggestionsContainer = this.suggestionsTarget
    
    // Clear existing suggestions
    suggestionsContainer.innerHTML = ''
    
    // Check if we have any suggestions
    const allSuggestions = [
      ...suggestions.roots || [],
      ...suggestions.lemmas || [],
      ...suggestions.stems || [],
      ...suggestions.verses || []
    ]

    if (allSuggestions.length === 0) {
      this.hideSuggestions()
      return
    }

    // Create suggestions list
    const suggestionsList = document.createElement('div')
    suggestionsList.className = 'bg-white border border-gray-300 rounded-md shadow-lg max-h-60 overflow-y-auto'

    allSuggestions.slice(0, 10).forEach((suggestion, index) => {
      const suggestionItem = this.createSuggestionItem(suggestion, index)
      suggestionsList.appendChild(suggestionItem)
    })

    suggestionsContainer.appendChild(suggestionsList)
    this.showSuggestions()
  }

  // Create individual suggestion item
  createSuggestionItem(suggestion, index) {
    const item = document.createElement('div')
    item.className = 'px-4 py-2 hover:bg-gray-100 cursor-pointer border-b border-gray-200 last:border-b-0'
    
    let displayText = suggestion.text
    let typeLabel = suggestion.type
    
    if (suggestion.type === 'root' && suggestion.english) {
      displayText += ` (${suggestion.english})`
    }

    item.innerHTML = `
      <div class="flex justify-between items-center">
        <span class="text-gray-900">${this.escapeHtml(displayText)}</span>
        <span class="text-xs text-gray-500 bg-gray-200 px-2 py-1 rounded">${this.escapeHtml(typeLabel)}</span>
      </div>
    `

    // Add click handler to select suggestion
    item.addEventListener('click', () => {
      this.selectSuggestion(suggestion)
    })

    return item
  }

  // Select a suggestion and update the search input
  selectSuggestion(suggestion) {
    const queryInput = this.element.querySelector('input[name="query"]')
    if (queryInput) {
      queryInput.value = suggestion.text
      
      // Update search type if applicable
      if (suggestion.type === 'root') {
        this.updateSearchType('root')
      } else if (suggestion.type === 'lemma') {
        this.updateSearchType('lemma')
      } else if (suggestion.type === 'stem') {
        this.updateSearchType('stem')
      }
    }
    
    this.hideSuggestions()
  }

  // Update search type select
  updateSearchType(type) {
    const typeSelect = this.element.querySelector('select[name="type"]')
    if (typeSelect) {
      typeSelect.value = type
      this.onTypeChange({ target: typeSelect })
    }
  }

  // Show suggestions container
  showSuggestions() {
    if (this.hasSuggestionsTarget) {
      this.suggestionsTarget.classList.remove('hidden')
    }
  }

  // Hide suggestions container
  hideSuggestions() {
    if (this.hasSuggestionsTarget) {
      this.suggestionsTarget.classList.add('hidden')
    }
  }

  // Escape HTML to prevent XSS
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Handle clicks outside suggestions to hide them
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }
}