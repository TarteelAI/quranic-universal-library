import ActivityController from "./activity_controller";

export default class extends ActivityController {
  connect() {
    super.connect();

    this.leftList = this.element.querySelector('#left-column');
    this.rightList = this.element.querySelector('#right-column');
    this.progressBar = this.element.querySelector('#progress-bar');
    this.matchArea = this.element.querySelector('#match-area');
    this.svg = this.element.querySelector('#match-svg');

    this.draggingFrom = null; 
    this.ghostLine = null; 
    this.totalPairs = this.leftList.querySelectorAll('[data-id]').length;
    this.matchedCount = 0;

    this.bindEvents();

    this._handleResize = () => this.refreshConnections();
    window.addEventListener('resize', this._handleResize);
  }

  disconnect() {
    super.disconnect();
    if (this._allDots) {
      this._allDots.forEach((dot) => {
        dot.removeEventListener('click', this._handleDotClick);
        dot.removeEventListener('mouseenter', this._handleDotEnter);
        dot.removeEventListener('mouseleave', this._handleDotLeave);
      });
    }
    if (this._handleMouseMove) {
      window.removeEventListener('mousemove', this._handleMouseMove);
    }
    if (this._handleResize) {
      window.removeEventListener('resize', this._handleResize);
    }
  }

  bindEvents() {
    // Dots on both sides
    this._allDots = Array.from(this.element.querySelectorAll('.anchor-dot'));

    // Handlers
    this._handleDotClick = (e) => {
      const dot = e.currentTarget;
      const item = dot.closest('[data-id]');
      if (!item || item.classList.contains('matched')) return;

      if (!this.draggingFrom) {
        // Start
        this.draggingFrom = dot;
        // mark active
        this._clearActiveDot();
        dot.classList.add('active');
        const start = this.getCenterRelativeTo(dot, this.matchArea);
        this.ensureGhostLine();
        this.updateGhostLine(start.x, start.y, start.x, start.y);
        // color ghost line like success
        if (this.ghostLine) {
          this.ghostLine.setAttribute('stroke', '#198754');
        }
        // Begin following mouse for preview
        this._handleMouseMove = (evt) => {
          if (!this.draggingFrom || !this.ghostLine) return;
          const parentRect = this.matchArea.getBoundingClientRect();
          const x = evt.clientX - parentRect.left;
          const y = evt.clientY - parentRect.top;
          const startPos = this.getCenterRelativeTo(this.draggingFrom, this.matchArea);
          this.updateGhostLine(startPos.x, startPos.y, x, y);
        };
        window.addEventListener('mousemove', this._handleMouseMove);
      } else {
        // Finish
        const startItem = this.draggingFrom.closest('[data-id]');
        const startSide = this.draggingFrom.getAttribute('data-side');
        const targetDot = dot;
        const targetItem = targetDot.closest('[data-id]');
        const targetSide = targetDot.getAttribute('data-side');

        if (startItem && targetItem && startSide !== targetSide) {
          const leftItem = startSide === 'left' ? startItem : targetItem;
          const rightItem = startSide === 'right' ? startItem : targetItem;
          this.checkPair(leftItem, rightItem);
        }

        this.clearGhostLine();
        window.removeEventListener('mousemove', this._handleMouseMove);
        this._handleMouseMove = null;
        this.draggingFrom = null;
        this._clearActiveDot();
      }
    };

    // Hover cues on dots
    this._handleDotEnter = (e) => {
      const dot = e.currentTarget;
      dot.style.backgroundColor = '#000';
    };
    this._handleDotLeave = (e) => {
      const dot = e.currentTarget;
      dot.style.backgroundColor = '';
    };

    this._allDots.forEach(dot => {
      dot.addEventListener('click', this._handleDotClick);
      dot.addEventListener('mouseenter', this._handleDotEnter);
      dot.addEventListener('mouseleave', this._handleDotLeave);
    });
  }

  _clearActiveDot() {
    const dot = this.element.querySelector('.anchor-dot.active');
    if (dot) dot.classList.remove('active');
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

      this.updateProgress();
      if (this.matchedCount === this.totalPairs) this.finish();
    } else {
      leftItem.classList.add('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');
      rightItem.classList.add('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');
      setTimeout(() => {
        leftItem.classList.remove('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');
        rightItem.classList.remove('wrong-answer', 'bg-danger-subtle', 'border', 'border-danger');
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
      // Wait a frame so layout settles, then refresh positions
      requestAnimationFrame(() => this.refreshConnections());
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

  // Recompute all connection positions based on current layout
  refreshConnections() {
    if (!this.svg) return;
    const groups = Array.from(this.svg.querySelectorAll('g[data-left-id]'));
    groups.forEach((g) => {
      const leftId = g.getAttribute('data-left-id');
      const rightId = g.getAttribute('data-right-id');
      const isCorrect = g.getAttribute('data-correct') === 'true';

      const leftItem = this.leftList.querySelector(`[data-id='${leftId}']`);
      const rightItem = this.rightList.querySelector(`[data-id='${rightId}']`);
      if (!leftItem || !rightItem) return;

      const leftDot = leftItem.querySelector(".anchor-dot[data-side='left']");
      const rightDot = rightItem.querySelector(".anchor-dot[data-side='right']");
      if (!leftDot || !rightDot) return;

      const leftPos = this.getCenterRelativeTo(leftDot, this.matchArea);
      const rightPos = this.getCenterRelativeTo(rightDot, this.matchArea);

      const line = g.querySelector('line');
      if (line) {
        line.setAttribute('x1', `${leftPos.x}`);
        line.setAttribute('y1', `${leftPos.y}`);
        line.setAttribute('x2', `${rightPos.x}`);
        line.setAttribute('y2', `${rightPos.y}`);
      }

      const midX = (leftPos.x + rightPos.x) / 2;
      const midY = (leftPos.y + rightPos.y) / 2;
      const circle = g.querySelector('circle');
      const icon = g.querySelector('text');
      if (circle) {
        circle.setAttribute('cx', `${midX}`);
        circle.setAttribute('cy', `${midY}`);
      }
      if (icon) {
        icon.setAttribute('x', `${midX}`);
        icon.setAttribute('y', `${midY + 4}`);
        icon.textContent = isCorrect ? '✓' : '✕';
      }
    });
  }

  ensureGhostLine() {
    if (!this.svg || this.ghostLine) return;
    this.ghostLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    this.ghostLine.setAttribute('stroke', '#000');
    this.ghostLine.setAttribute('stroke-width', '2');
    this.ghostLine.setAttribute('stroke-dasharray', '4 4');
    this.svg.appendChild(this.ghostLine);
  }

  updateGhostLine(x1, y1, x2, y2) {
    if (!this.ghostLine) return;
    this.ghostLine.setAttribute('x1', `${x1}`);
    this.ghostLine.setAttribute('y1', `${y1}`);
    this.ghostLine.setAttribute('x2', `${x2}`);
    this.ghostLine.setAttribute('y2', `${y2}`);
  }

  clearGhostLine() {
    if (this.ghostLine && this.svg) {
      this.ghostLine.remove();
    }
    this.ghostLine = null;
  }
}


