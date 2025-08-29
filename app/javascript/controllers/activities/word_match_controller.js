import ActivityController from "./activity_controller";

export default class extends ActivityController {
  connect() {
    super.connect();

    this.leftList = this.element.querySelector('#left-column');
    this.rightList = this.element.querySelector('#right-column');
    this.progressBar = this.element.querySelector('#progress-bar');
    this.matchArea = this.element.querySelector('#match-area');
    this.svg = this.element.querySelector('#match-svg');

    this.selectedLeft = null;
    this.selectedRight = null;
    this.totalPairs = this.leftList.querySelectorAll('[data-id]').length;
    this.matchedCount = 0;

    this.bindEvents();
  }

  disconnect() {
  }

  bindEvents() {
    this.leftList.querySelectorAll('.select-left').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const item = e.currentTarget.closest('[data-id]');
        this.handleLeftSelect(item);
      })
    });

    this.rightList.querySelectorAll('.select-right').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const item = e.currentTarget.closest('[data-id]');
        this.handleRightSelect(item);
      })
    });

    // Drag and drop support
    this.rightList.querySelectorAll('[data-id]').forEach(item => {
      item.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', item.dataset.id);
      })
    });

    this.leftList.querySelectorAll('[data-id]').forEach(item => {
      item.addEventListener('dragover', (e) => e.preventDefault());
      item.addEventListener('drop', (e) => {
        e.preventDefault();
        const rightId = e.dataTransfer.getData('text/plain');
        this.checkPair(item, this.rightList.querySelector(`[data-id='${rightId}']`));
      })
    });
  }

  handleLeftSelect(item) {
    if (item.classList.contains('matched')) return;

    if (this.selectedLeft) this.selectedLeft.classList.remove('active');
    this.selectedLeft = item;
    item.classList.add('active');

    if (this.selectedRight) this.checkPair(this.selectedLeft, this.selectedRight);
  }

  handleRightSelect(item) {
    if (item.classList.contains('matched')) return;

    if (this.selectedRight) this.selectedRight.classList.remove('active');
    this.selectedRight = item;
    item.classList.add('active');

    if (this.selectedLeft) this.checkPair(this.selectedLeft, this.selectedRight);
  }

  checkPair(leftItem, rightItem) {
    if (!leftItem || !rightItem) return;

    const isCorrect = leftItem.dataset.id === rightItem.dataset.id;
    // If this is a correct match, remove any previous incorrect connections
    if (isCorrect) {
      this.removeConnectionsForItems(leftItem.dataset.id, rightItem.dataset.id, true);
    }
    this.drawConnection(leftItem, rightItem, isCorrect);

    if (isCorrect) {
      this.matchedCount += 1;
      leftItem.classList.add('matched', 'border', 'border-success', 'bg-success-subtle');
      rightItem.classList.add('matched', 'border', 'border-success', 'bg-success-subtle');
      leftItem.querySelector('.status-icon')?.classList.add('text-success');
      leftItem.querySelector('.status-icon')?.classList.add('fa', 'fa-check-circle');
      rightItem.querySelector('.status-icon')?.classList.add('text-success');
      rightItem.querySelector('.status-icon')?.classList.add('fa', 'fa-check-circle');
      leftItem.querySelector('.select-left')?.setAttribute('disabled', 'disabled');
      rightItem.querySelector('.select-right')?.setAttribute('disabled', 'disabled');

      leftItem.classList.remove('active');
      rightItem.classList.remove('active');
      this.selectedLeft = null;
      this.selectedRight = null;

      this.updateProgress();
      if (this.matchedCount === this.totalPairs) this.finish();
    } else {
      leftItem.classList.add('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');
      rightItem.classList.add('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');

      // show red cross icon temporarily
      const leftIcon = leftItem.querySelector('.status-icon');
      const rightIcon = rightItem.querySelector('.status-icon');
      leftIcon?.classList.add('fa', 'fa-times-circle', 'text-danger');
      rightIcon?.classList.add('fa', 'fa-times-circle', 'text-danger');

      setTimeout(() => {
        leftItem.classList.remove('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');
        rightItem.classList.remove('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');
        // remove red cross icon after feedback
        leftIcon?.classList.remove('fa', 'fa-times-circle', 'text-danger');
        rightIcon?.classList.remove('fa', 'fa-times-circle', 'text-danger');
      }, 600);
    }
  }

  updateProgress() {
    if (!this.progressBar) return;
    const percent = Math.round((this.matchedCount / this.totalPairs) * 100);
    this.progressBar.style.width = `${percent}%`;
    this.progressBar.setAttribute('aria-valuenow', `${percent}`);
  }

  finish() {
    this.onSuccess();

    const result = this.element.closest('.quiz-container')?.querySelector('#quiz-result');
    if (result) {
      const msg = document.createElement('div');
      msg.className = 'mt-3 text-success fw-bold';
      msg.textContent = `All pairs matched! Great job!`;
      result.appendChild(msg);
      result.classList.remove('d-none');
    }
  }

  // Draw a connection between two items with a midpoint indicator (✓/✕)
  drawConnection(leftItem, rightItem, isCorrect) {
    if (!this.svg || !this.matchArea) return;

    const leftDot = leftItem.querySelector(".anchor-dot[data-side='left']");
    const rightDot = rightItem.querySelector(".anchor-dot[data-side='right']");
    if (!leftDot || !rightDot) return;

    const leftPos = this.getCenterRelativeTo(leftDot, this.matchArea);
    const rightPos = this.getCenterRelativeTo(rightDot, this.matchArea);

    const g = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    g.setAttribute('data-left-id', leftItem.dataset.id);
    g.setAttribute('data-right-id', rightItem.dataset.id);
    g.setAttribute('data-correct', isCorrect ? 'true' : 'false');

    const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    line.setAttribute('x1', `${leftPos.x}`);
    line.setAttribute('y1', `${leftPos.y}`);
    line.setAttribute('x2', `${rightPos.x}`);
    line.setAttribute('y2', `${rightPos.y}`);
    line.setAttribute('stroke', isCorrect ? '#28a745' : '#dc3545');
    line.setAttribute('stroke-width', '3');

    const midX = (leftPos.x + rightPos.x) / 2;
    const midY = (leftPos.y + rightPos.y) / 2;

    const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    circle.setAttribute('cx', `${midX}`);
    circle.setAttribute('cy', `${midY}`);
    circle.setAttribute('r', '12');
    circle.setAttribute('fill', isCorrect ? '#e6f4ea' : '#fdecea');
    circle.setAttribute('stroke', isCorrect ? '#28a745' : '#dc3545');
    circle.setAttribute('stroke-width', '2');

    const icon = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    icon.setAttribute('x', `${midX}`);
    icon.setAttribute('y', `${midY + 4}`);
    icon.setAttribute('text-anchor', 'middle');
    icon.setAttribute('font-size', '14');
    icon.setAttribute('font-weight', 'bold');
    icon.setAttribute('fill', isCorrect ? '#28a745' : '#dc3545');
    icon.textContent = isCorrect ? '✓' : '✕';

    g.appendChild(line);
    g.appendChild(circle);
    g.appendChild(icon);
    this.svg.appendChild(g);
  }

  getCenterRelativeTo(el, relativeTo) {
    const rect = el.getBoundingClientRect();
    const parentRect = relativeTo.getBoundingClientRect();
    return {
      x: rect.left - parentRect.left + rect.width / 2,
      y: rect.top - parentRect.top + rect.height / 2
    };
  }

  // If onlyIncorrect=true, only remove red (incorrect) ones
  removeConnectionsForItems(leftId, rightId, onlyIncorrect = false) {
    if (!this.svg) return;
    const groups = this.svg.querySelectorAll('g[data-left-id]');
    groups.forEach(g => {
      const involvesLeft = g.getAttribute('data-left-id') === leftId || g.getAttribute('data-right-id') === leftId;
      const involvesRight = g.getAttribute('data-left-id') === rightId || g.getAttribute('data-right-id') === rightId;
      const isIncorrect = g.getAttribute('data-correct') === 'false';

      if ((involvesLeft || involvesRight) && (!onlyIncorrect || isIncorrect)) {
        g.remove();
      }
    });
  }
}


