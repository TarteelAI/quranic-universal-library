export default class ScreenSize {
  screenSize = '';

  constructor() {
    this.update();
    window.addEventListener('resize', () => this.update());
  }

  update() {
    const width = window.innerWidth;

    if (width <= 425) {
      this.screenSize = 'mobile';
    } else if (width >= 425 && width < 768) {
      this.screenSize = 'tablet';
    } else if (width >= 768 && width <= 1680) {
      this.screenSize = 'desktop';
    } else if (width > 1680) {
      this.screenSize = 'large desktop';
    }
  }

  getScreenSize() {
    return this.screenSize;
  }

  isMobile() {
    return this.screenSize === 'mobile';
  }

  isTablet() {
    return this.screenSize === 'tablet';
  }

  isDesktop() {
    return this.screenSize === 'desktop';
  }

  isLargeDesktop() {
    return this.screenSize === 'large desktop';
  }
}
