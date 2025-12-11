import ActivityController from "./activity_controller";
import Sortable from 'sortablejs';

export default class extends ActivityController {
  connect() {
    super.connect();
    
    this.mode = this.element.dataset.mode;
    
    if (this.mode === 'sort') {
      this.initSortMode();
    } else {
      this.initMultipleChoiceMode();
    }
  }

  initMultipleChoiceMode() {
    $(this.element).find('.option').on('click', this.checkAnswer.bind(this))
  }

  initSortMode() {
    this.availableSurahs = this.element.querySelector('#available-surahs');
    this.sortSlots = this.element.querySelector('#sort-slots');
    this.sortSlotsList = Array.from(this.sortSlots.querySelectorAll('.sort-slot'));
    this.correctOrderData = JSON.parse(this.element.querySelector('#correct-order-data').textContent);
    
    this.initSortable();
    this.addClickEvents();
  }

  initSortable() {
    Sortable.create(this.availableSurahs, {
      group: "shared",
      animation: 150,
      onEnd: (event) => this.handleDrop(event)
    });

    this.sortSlotsList.forEach((slot) => {
      Sortable.create(slot, {
        group: "shared",
        animation: 150,
        onEnd: (event) => this.handleDrop(event)
      });
    });
  }

  handleDrop(event) {
    const target = event.to;
    const draggableSurah = event.item;

    if (!target.classList.contains('sort-slot')) {
      if (target === this.availableSurahs) {
        draggableSurah.classList.remove('tw-cursor-default');
        draggableSurah.classList.add('tw-cursor-grab');
        if (!draggableSurah.hasEventListener) {
          draggableSurah.addEventListener('click', this.surahClick);
          draggableSurah.hasEventListener = true;
        }
      }
      return;
    }

    if (target.querySelector('.sortable-surah')) {
      const existingSurah = target.querySelector('.sortable-surah');
      existingSurah.classList.remove('tw-cursor-default');
      existingSurah.classList.add('tw-cursor-grab');
      this.availableSurahs.appendChild(existingSurah);
      if (!existingSurah.hasEventListener) {
        existingSurah.addEventListener('click', this.surahClick);
        existingSurah.hasEventListener = true;
      }
    }

    target.innerHTML = '';
    target.appendChild(draggableSurah);
    draggableSurah.classList.remove('tw-cursor-grab');
    draggableSurah.classList.add('tw-cursor-default');
    if (draggableSurah.hasEventListener) {
      draggableSurah.removeEventListener('click', this.surahClick);
      draggableSurah.hasEventListener = false;
    }
    
    this.checkSortCompletion();
  }

  addClickEvents() {
    this.surahClick = this.handleSurahClick.bind(this);
    this.slotClick = this.handleSlotClick.bind(this);

    this.availableSurahs.querySelectorAll('.sortable-surah').forEach((surah) => {
      surah.addEventListener('click', this.surahClick);
      surah.hasEventListener = true;
    });

    this.sortSlotsList.forEach((slot) => {
      slot.addEventListener('click', this.slotClick);
    });
  }

  handleSurahClick(event) {
    const surahElement = event.currentTarget;
    const emptySlot = this.sortSlotsList.find(slot => !slot.querySelector('.sortable-surah'));

    if (emptySlot) {
      this.fillSlot(emptySlot, surahElement);
    }
  }

  handleSlotClick(event) {
    const slot = event.currentTarget;
    const surahInSlot = slot.querySelector('.sortable-surah');

    if (surahInSlot) {
      surahInSlot.classList.remove('tw-cursor-default');
      surahInSlot.classList.add('tw-cursor-grab');
      this.availableSurahs.appendChild(surahInSlot);
      slot.innerHTML = '<span class="tw-text-xl tw-text-blue-400 tw-font-bold">?</span>';
      if (!surahInSlot.hasEventListener) {
        surahInSlot.addEventListener('click', this.surahClick);
        surahInSlot.hasEventListener = true;
      }
      this.checkSortCompletion();
    }
  }

  fillSlot(slot, surahElement) {
    if (slot.querySelector('.sortable-surah')) {
      const existingSurah = slot.querySelector('.sortable-surah');
      existingSurah.classList.remove('tw-cursor-default');
      existingSurah.classList.add('tw-cursor-grab');
      this.availableSurahs.appendChild(existingSurah);
      if (!existingSurah.hasEventListener) {
        existingSurah.addEventListener('click', this.surahClick);
        existingSurah.hasEventListener = true;
      }
    }

    slot.innerHTML = '';
    slot.appendChild(surahElement);
    surahElement.classList.remove('tw-cursor-grab');
    surahElement.classList.add('tw-cursor-default');
    if (surahElement.hasEventListener) {
      surahElement.removeEventListener('click', this.surahClick);
      surahElement.hasEventListener = false;
    }
    
    this.checkSortCompletion();
  }

  checkSortCompletion() {
    const filledSlots = this.sortSlotsList.filter(slot => slot.querySelector('.sortable-surah'));
    
    if (filledSlots.length === 4) {
      let isCorrect = true;
      
      this.sortSlotsList.forEach((slot, index) => {
        const surah = slot.querySelector('.sortable-surah');
        if (!surah) {
          isCorrect = false;
          return;
        }
        const surahChapterNumber = parseInt(surah.dataset.chapterNumber);
        const correctChapterNumber = this.correctOrderData[index].chapter_number;
        
        if (surahChapterNumber !== correctChapterNumber) {
          isCorrect = false;
        }
      });

      if (isCorrect) {
        this.handleSortCorrect();
      } else {
        this.handleSortWrong();
      }
    }
  }

  handleSortCorrect() {
    this.sortSlotsList.forEach((slot) => {
      slot.classList.add('correct-answer');
      const surah = slot.querySelector('.sortable-surah');
      if (surah) {
        surah.classList.add('correct-answer');
      }
    });
    
    this.sortSlotsList.forEach((slot) => {
      if (Sortable.get(slot)) {
        Sortable.get(slot).option("disabled", true);
      }
    });
    
    if (Sortable.get(this.availableSurahs)) {
      Sortable.get(this.availableSurahs).option("disabled", true);
    }
    
    this.onSuccess();
  }

  handleSortWrong() {
    this.sortSlotsList.forEach((slot) => {
      const surah = slot.querySelector('.sortable-surah');
      if (surah) {
        surah.classList.add('wrong-answer', 'shake');
      }
    });
    
    this.wrongAnswer();
    
    setTimeout(() => {
      this.sortSlotsList.forEach((slot) => {
        const surah = slot.querySelector('.sortable-surah');
        if (surah) {
          surah.classList.remove('shake', 'wrong-answer');
        }
      });
    }, 1000);
  }

  resetActivity() {
    if (this.mode !== 'sort') return;
    
    const allSurahs = [];
    
    this.sortSlotsList.forEach((slot) => {
      const surahInSlot = slot.querySelector('.sortable-surah');
      if (surahInSlot) {
        allSurahs.push(surahInSlot);
      }
      slot.innerHTML = '<span class="tw-text-xl tw-text-blue-400 tw-font-bold">?</span>';
      slot.classList.remove('correct-answer');
      
      if (Sortable.get(slot)) {
        Sortable.get(slot).option("disabled", false);
      }
    });

    const availableSurahsList = Array.from(this.availableSurahs.querySelectorAll('.sortable-surah'));
    allSurahs.push(...availableSurahsList);

    this.availableSurahs.innerHTML = '';
    
    allSurahs.forEach((surah) => {
      surah.classList.remove('tw-cursor-default', 'correct-answer', 'wrong-answer', 'shake');
      surah.classList.add('tw-cursor-grab');
      
      if (surah.hasEventListener) {
        surah.removeEventListener('click', this.surahClick);
      }
      surah.addEventListener('click', this.surahClick);
      surah.hasEventListener = true;
      
      this.availableSurahs.appendChild(surah);
    });

    if (Sortable.get(this.availableSurahs)) {
      Sortable.get(this.availableSurahs).option("disabled", false);
    }
  }

  checkAnswer(e) {
    e.preventDefault();
    const button = $(e.target);
    
    if (button.attr('disabled')) {
      return;
    }

    const {correct} = e.target.dataset;

    if (correct == 'true') {
      this.handleCorrectAnswer(button);
    } else {
      this.handleWrongAnswer(button);
    }
  }

  handleCorrectAnswer(correctButton) {
    this.el.find(".option").attr('disabled', 'disabled');
    correctButton.addClass('correct-answer');
    this.onSuccess();
  }

  handleWrongAnswer(wrongButton) {
    wrongButton.addClass('wrong-answer shake');
    wrongButton.attr('disabled', 'disabled');
    
    this.wrongAnswer();

    setTimeout(() => {
      wrongButton.removeClass('shake');
      wrongButton.removeClass('wrong-answer');
      wrongButton.removeAttr('disabled');
    }, 1000);
  }
}
