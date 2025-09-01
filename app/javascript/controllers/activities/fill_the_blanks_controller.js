import ActivityController from "./activity_controller";
import Sortable from 'sortablejs';

export default class extends ActivityController {
  connect() {
    super.connect();
    this.blankBoxes = this.element.querySelectorAll('.blank-box');
    this.remainingWords = this.element.querySelectorAll('.draggable-word');
    this.options = this.element.querySelector("#options");

    this.initSortable();
    this.addClickEvents();
  }

  initSortable() {
    Sortable.create(this.options, {
      group: "shared",
      animation: 150,
      onEnd: (event) => this.handleDrop(event)
    });

    this.blankBoxes.forEach((blank) => {
      Sortable.create(blank, {
        group: "shared",
        animation: 150,
        onEnd: (event) => this.handleDrop(event)
      });
    });
  }

  handleDrop(event) {
    const target = event.to;
    const draggableWord = event.item;

    if (!target.classList.contains('blank-box')) {
      event.from.appendChild(draggableWord);
      return;
    }

    this.fillWord(target, draggableWord);
    this.checkCompletion();
  }

  addClickEvents() {
    this.blankWordClick =  this.handleBlankWordClick.bind(this);
    this.dragableWordClick = this.handleDraggableWordClick.bind(this);

    this.blankBoxes.forEach((blank) => {
      blank.addEventListener('click', this.blankWordClick);
    });

    this.remainingWords.forEach((word) => {
      word.addEventListener('click', this.dragableWordClick);
    });
  }

  handleBlankWordClick(event) {
    const blank = event.currentTarget;

    if (blank.classList.contains('filled')) {
      const wordId = blank.dataset.filledId;
      const draggableWord = this.options.querySelector(`[data-word-id='${wordId}']`);

      if (draggableWord) {
        draggableWord.classList.remove('d-none')
      }

      blank.innerHTML = '';
      blank.classList.remove('filled');
      blank.dataset.filledId = '';
    }
  }

  handleDraggableWordClick(event) {
    const wordElement = event.currentTarget;
    const blankBox = Array.from(this.blankBoxes).find(blank => !blank.classList.contains('filled'));

    if (blankBox) {
      this.fillWord(blankBox, wordElement);
    }
  }

  fillWord(blankBox, draggableWord) {
    if (blankBox.classList.contains('filled')) {
      const currentFilledWordId = blankBox.dataset.filledId;
      const currentFilledWord = this.options.querySelector(`[data-word-id='${currentFilledWordId}']`);

      if (currentFilledWord) {
        currentFilledWord.classList.remove('d-none');
      }
    }

    blankBox.innerHTML = draggableWord.innerHTML.trim();
    blankBox.classList.add('filled');
    blankBox.dataset.filledId = draggableWord.dataset.wordId;

    draggableWord.classList.add('d-none')
    this.options.appendChild(draggableWord);

    this.checkCompletion();
  }

  checkCompletion() {
    let isCorrect = true;

    if (this.element.querySelectorAll('#options .draggable-word:not(.d-none)').length === 0) {
      this.blankBoxes.forEach((word) => {
        const { wordId, filledId } = word.dataset;
        if (wordId != filledId) {
          this.wrongAnswer();
          isCorrect = false; // Break the loop
          return false;
        }
      });

      if (isCorrect) {
        this.onSuccess();
      }
    }
  }

    resetActivity() {
        this.blankBoxes.forEach((blank) => {
            blank.innerHTML = '';
            blank.classList.remove('filled');
            blank.dataset.filledId = '';
        });

        this.remainingWords.forEach((word) => {
            word.classList.remove('d-none');
            this.options.appendChild(word);
        });
    }


    onSuccess() {
    super.onSuccess();

    this.blankBoxes.forEach((blank) => {
      blank.classList.add('word-box');
      blank.classList.remove('blank-box');

      blank.removeEventListener('click', this.blankWordClick);
      Sortable.get(blank).option("disabled", true);
    });

    this.remainingWords.forEach((word) => {
      word.removeEventListener('click', this.dragableWordClick);
      Sortable.get(word.parentElement).option("disabled", true); // Disable sorting on the word's container
    });
  }
}
