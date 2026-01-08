import {Controller} from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    toggle: { type: Boolean, default: true },
    target: String
  }

  connect() {
    if (this.hasTargetValue) {
      const targetElement = document.querySelector(this.targetValue);
      if (targetElement && targetElement.classList.contains('collapse')) {
        this.isTrigger = true;
        this.targetElement = targetElement;
        const targetHasHidden = targetElement.classList.contains('tw-hidden');
        const targetHasShow = targetElement.classList.contains('show');
        const targetHasActive = targetElement.classList.contains('active');
        const targetIsOpen = targetHasShow || targetHasActive || !targetHasHidden;
        this.updateTriggerState(targetIsOpen);
        return;
      }
    }
    
    const hasMdFlex = this.element.classList.contains('md:tw-flex');
    const isMobile = window.innerWidth < 768;
    
    if (hasMdFlex) {
      if (!isMobile) {
        const computedStyle = window.getComputedStyle(this.element);
        if (computedStyle.display === 'none') {
          this.element.style.display = '';
        }
        this.isOpen = true;
        return;
      } else {
        if (!this.element.classList.contains('show') && !this.element.classList.contains('active')) {
          if (!this.element.classList.contains('tw-hidden')) {
            this.element.classList.add('tw-hidden');
          }
          this.isOpen = false;
        } else {
          if (this.element.classList.contains('tw-hidden')) {
            this.element.classList.remove('tw-hidden');
          }
          this.isOpen = true;
        }
      }
    } else {
      const hasShow = this.element.classList.contains('show');
      const hasActive = this.element.classList.contains('active');
      this.isOpen = hasShow || hasActive || !this.element.classList.contains('collapse');
      
      if (!this.isOpen) {
        this.element.classList.add('tw-hidden');
        this.element.style.maxHeight = '0';
      } else {
        this.element.classList.remove('tw-hidden');
        this.element.style.maxHeight = '';
      }
    }
    
    this.element.classList.add('tw-transition-all', 'tw-duration-300', 'tw-ease-in-out', 'tw-overflow-hidden');
    
    setTimeout(() => {
      this.setupTriggers();
    }, 0);
  }

  disconnect() {
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler);
    }
    // Remove event listeners from triggers
    if (this.triggerClickHandlers) {
      this.triggerClickHandlers.forEach(({ trigger, handler }) => {
        trigger.removeEventListener('click', handler);
      });
    }
  }

  setupTriggers() {
    // Find triggers by data-bs-target or aria-controls
    const targetId = this.element.id;
    if (!targetId) {
      return;
    }
    
    // Find triggers with data-bs-target pointing to this element (with or without #)
    const bsTargetTriggers = document.querySelectorAll(`[data-bs-target="#${targetId}"], [data-bs-target="${targetId}"]`);
    
    // Find triggers with aria-controls pointing to this element
    const ariaTriggers = document.querySelectorAll(`[aria-controls="${targetId}"]`);
    
    // Combine all triggers and remove duplicates
    const allTriggers = Array.from(new Set([...bsTargetTriggers, ...ariaTriggers]));
    
    // Store handlers for cleanup
    this.triggerClickHandlers = [];
    
    allTriggers.forEach(trigger => {
      // Check if trigger has data-bs-toggle="collapse" or points to this element
      const hasBsToggle = trigger.getAttribute('data-bs-toggle') === 'collapse';
      const triggerTarget = trigger.getAttribute('data-bs-target');
      const triggerAriaControls = trigger.getAttribute('aria-controls');
      const pointsToThis = triggerTarget === `#${targetId}` || triggerTarget === targetId || triggerAriaControls === targetId;
      
      // Attach handler if trigger has data-bs-toggle="collapse" and points to this element
      if (hasBsToggle && pointsToThis) {
        const handler = (e) => {
          e.preventDefault();
          e.stopPropagation();
          this.toggle();
        };
        
        trigger.addEventListener('click', handler);
        this.triggerClickHandlers.push({ trigger, handler });
      }
    });
    
    // Update initial trigger states
    this.updateTriggers();
    
    const hasMdFlex = this.element.classList.contains('md:tw-flex');
    if (hasMdFlex) {
      this.resizeHandler = () => {
        const isMobile = window.innerWidth < 768;
        if (!isMobile) {
          const computedStyle = window.getComputedStyle(this.element);
          if (computedStyle.display === 'none') {
            this.element.style.display = '';
          }
          if (this.element.classList.contains('tw-hidden')) {
            this.element.classList.remove('tw-hidden');
          }
          this.isOpen = true;
        } else {
          if (!this.isOpen) {
            if (!this.element.classList.contains('tw-hidden')) {
              this.element.classList.add('tw-hidden');
            }
          } else {
            if (this.element.classList.contains('tw-hidden')) {
              this.element.classList.remove('tw-hidden');
            }
          }
        }
      };
      window.addEventListener('resize', this.resizeHandler);
    }
  }

  toggle(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }
    
    if (this.isTrigger && this.targetElement) {
      const targetHasHidden = this.targetElement.classList.contains('tw-hidden');
      const targetHasShow = this.targetElement.classList.contains('show');
      const targetHasActive = this.targetElement.classList.contains('active');
      const targetIsOpen = targetHasShow || targetHasActive || !targetHasHidden;
      
      if (targetIsOpen) {
        this.hideTarget(this.targetElement);
      } else {
        this.showTarget(this.targetElement);
      }
      return;
    }
    
    const isMobile = window.innerWidth < 768;
    const hasMdFlex = this.element.classList.contains('md:tw-flex');
    if (hasMdFlex && !isMobile) {
      return;
    }
    
    if (this.isOpen) {
      this.hide();
    } else {
      this.show();
    }
  }
  
  showTarget(targetElement) {
    targetElement.classList.remove('tw-hidden');
    targetElement.style.maxHeight = '0';
    targetElement.style.overflow = 'hidden';
    
    requestAnimationFrame(() => {
      const height = targetElement.scrollHeight;
      targetElement.style.maxHeight = `${height}px`;
      
      setTimeout(() => {
        targetElement.style.maxHeight = '';
        targetElement.style.overflow = '';
        targetElement.classList.add('show', 'active');
        this.updateTriggerState(true);
      }, 300);
    });
  }
  
  hideTarget(targetElement) {
    const height = targetElement.scrollHeight;
    targetElement.style.maxHeight = `${height}px`;
    targetElement.style.overflow = 'hidden';
    
    requestAnimationFrame(() => {
      targetElement.style.maxHeight = '0';
      
      setTimeout(() => {
        targetElement.classList.add('tw-hidden');
        targetElement.classList.remove('show', 'active');
        targetElement.style.maxHeight = '';
        targetElement.style.overflow = '';
        this.updateTriggerState(false);
      }, 300);
    });
  }
  
  updateTriggerState(isOpen) {
    if (!this.isTrigger) return;
    
    if (isOpen) {
      this.element.setAttribute('aria-expanded', 'true');
      this.element.classList.remove('collapsed');
      
      const revealIcon = this.element.querySelector('.collapsed-reveal');
      const hiddenIcon = this.element.querySelector('.collapsed-hidden');
      if (revealIcon) revealIcon.classList.add('tw-hidden');
      if (hiddenIcon) hiddenIcon.classList.remove('tw-hidden');
    } else {
      this.element.setAttribute('aria-expanded', 'false');
      this.element.classList.add('collapsed');
      
      const revealIcon = this.element.querySelector('.collapsed-reveal');
      const hiddenIcon = this.element.querySelector('.collapsed-hidden');
      if (revealIcon) revealIcon.classList.remove('tw-hidden');
      if (hiddenIcon) hiddenIcon.classList.add('tw-hidden');
    }
  }

  show() {
    const isMobile = window.innerWidth < 768;
    const hasMdFlex = this.element.classList.contains('md:tw-flex');
    if (hasMdFlex && !isMobile) {
      return;
    }
    
    if (hasMdFlex) {
      if (this.element.classList.contains('tw-hidden')) {
        this.element.classList.remove('tw-hidden');
      }
      this.isOpen = true;
      this.updateTriggers();
      return;
    }
    
    this.element.classList.remove('tw-hidden');
    this.element.style.maxHeight = '0';
    this.element.style.overflow = 'hidden';
    
    requestAnimationFrame(() => {
      const height = this.element.scrollHeight;
      this.element.style.maxHeight = `${height}px`;
      
      setTimeout(() => {
        this.element.style.maxHeight = '';
        this.element.style.overflow = '';
        this.element.classList.add('show', 'active');
        this.isOpen = true;
        this.updateTriggers();
      }, 300);
    });
  }

  hide() {
    const isMobile = window.innerWidth < 768;
    const hasMdFlex = this.element.classList.contains('md:tw-flex');
    if (hasMdFlex && !isMobile) {
      return;
    }
    
    if (hasMdFlex) {
      if (!this.element.classList.contains('tw-hidden')) {
        this.element.classList.add('tw-hidden');
      }
      this.isOpen = false;
      this.updateTriggers();
      return;
    }
    
    const height = this.element.scrollHeight;
    this.element.style.maxHeight = `${height}px`;
    this.element.style.overflow = 'hidden';
    
    requestAnimationFrame(() => {
      this.element.style.maxHeight = '0';
      
      setTimeout(() => {
        this.element.classList.add('tw-hidden');
        this.element.classList.remove('show', 'active');
        this.element.style.maxHeight = '';
        this.element.style.overflow = '';
        this.isOpen = false;
        this.updateTriggers();
      }, 300);
    });
  }

  updateTriggers() {
    const targetId = this.element.id;
    if (!targetId) return;
    
    const triggers = document.querySelectorAll(
      `[data-bs-target="#${targetId}"], [data-bs-target="${targetId}"], [aria-controls="${targetId}"], [data-collapse-target-value="#${targetId}"], [data-collapse-target-value="${targetId}"]`
    );
    
    triggers.forEach(trigger => {
      if (this.isOpen) {
        trigger.setAttribute('aria-expanded', 'true');
        trigger.classList.remove('collapsed');
        
        const revealIcon = trigger.querySelector('.collapsed-reveal');
        const hiddenIcon = trigger.querySelector('.collapsed-hidden');
        if (revealIcon) revealIcon.classList.add('tw-hidden');
        if (hiddenIcon) hiddenIcon.classList.remove('tw-hidden');
      } else {
        trigger.setAttribute('aria-expanded', 'false');
        trigger.classList.add('collapsed');
        
        const revealIcon = trigger.querySelector('.collapsed-reveal');
        const hiddenIcon = trigger.querySelector('.collapsed-hidden');
        if (revealIcon) revealIcon.classList.remove('tw-hidden');
        if (hiddenIcon) hiddenIcon.classList.add('tw-hidden');
      }
    });
  }
}
