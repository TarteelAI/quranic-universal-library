import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.el = $(this.element);
    
    this.history = [];
    this.historyIndex = -1;
    this.maxHistorySize = 50;
    
    this.saveState();
    
    this.el.find("#decrement").on("click", this.decrementPage.bind(this));
    this.el.find("#increment").on("click", this.incrementPage.bind(this));

    this.setupKeyboardShortcuts();

    $(".mushaf-layout-form .remove-ayah").on('click', (event) => {
      event.preventDefault()
      $(event.target).closest(".verse").remove()
    });

    $(".mushaf-layout-form .line-number-input").on('change', (event) => {
      const ayahNumber = Number(event.currentTarget.dataset.verse);
      const positionNumber = Number(event.currentTarget.dataset.wordPosition);
      const lineNumber = Number(event.currentTarget.value);
      const propagate = $("#propagate-changes").is(":checked")

      // If lineNumber is 0, always propagate regardless of checkbox
      // For other values, respect the propagate checkbox
      const shouldPropagate = lineNumber === 0 || propagate;

      if (!shouldPropagate) {
        this.saveState();
        return;
      }

      document.querySelectorAll('.line-number-input').forEach((input) => {
        var ayah = Number(input.dataset.verse)
        const position = Number(input.dataset.wordPosition);

        if (ayah > ayahNumber) {
          input.value = lineNumber;
        } else if(ayah == ayahNumber){
          if(position > positionNumber)
            input.value = lineNumber;
        }
      })
      
      // Save state after propagation
      this.saveState();
    });
  }

  decrementPage(){
    this.changePageNumberForAllWords(-1);
    this.saveState();
  }
  
  incrementPage(){
    this.changePageNumberForAllWords(1);
    this.saveState();
  }

  changePageNumberForAllWords(change){
    document.querySelectorAll('.line-number-input').forEach((input) => {
      var line = Number(input.value);
      if(line != 0)
        input.value = line + change;
    })
  }
  
  // Save current state to history for undo/redo
  saveState() {
    const currentState = this.getCurrentState();
    
    if (this.historyIndex < this.history.length - 1) {
      this.history = this.history.slice(0, this.historyIndex + 1);
    }
    
    this.history.push(currentState);
    
    if (this.history.length > this.maxHistorySize) {
      this.history.shift();
    } else {
      this.historyIndex++;
    }
    
    this.updateUndoRedoButtons();
  }
  
  getCurrentState() {
    const state = [];
    document.querySelectorAll('.line-number-input').forEach((input) => {
      state.push({
        verse: input.dataset.verse,
        wordPosition: input.dataset.wordPosition,
        value: input.value
      });
    });
    return state;
  }
  
  restoreState(state) {
    state.forEach((item) => {
      const input = document.querySelector(
        `.line-number-input[data-verse="${item.verse}"][data-word-position="${item.wordPosition}"]`
      );
      if (input) {
        input.value = item.value;
      }
    });
  }
  
  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--;
      this.restoreState(this.history[this.historyIndex]);
      this.updateUndoRedoButtons();
    }
  }
  
  redo() {
    if (this.historyIndex < this.history.length - 1) {
      this.historyIndex++;
      this.restoreState(this.history[this.historyIndex]);
      this.updateUndoRedoButtons();
    }
  }
  
  setupUndoRedo() {
    this.el.find("#undo-button").on("click", (e) => {
      e.preventDefault();
      this.undo();
    });
    
    this.el.find("#redo-button").on("click", (e) => {
      e.preventDefault();
      this.redo();
    });
  }
  
  updateUndoRedoButtons() {
    const undoButton = this.el.find("#undo-button");
    const redoButton = this.el.find("#redo-button");
    
    if (undoButton.length) {
      undoButton.prop('disabled', this.historyIndex <= 0);
    }
    
    if (redoButton.length) {
      redoButton.prop('disabled', this.historyIndex >= this.history.length - 1);
    }
  }
  
  setupKeyboardShortcuts() {
    $(document).on('keydown.mushaf-builder', (e) => {
      // Check if we're in the mushaf layout form context
      if (!$(e.target).closest('.mushaf-layout-form').length && 
          !$(e.target).closest('[data-controller*="mushaf-page-builder"]').length) {
        return;
      }
      
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey) {
        e.preventDefault();
        this.undo();
      }
      
      if ((e.ctrlKey || e.metaKey) && (e.key === 'y' || (e.shiftKey && e.key === 'z'))) {
        e.preventDefault();
        this.redo();
      }
    });
  }
  
  disconnect() {
    $(document).off('keydown.mushaf-builder');
  }
}
