import { Controller } from "@hotwired/stimulus";


export default class extends Controller {
  connect() {
    this.el = $(this.element);
    this.state = 'hidden'

    this.parent = this.el.closest('.password')
    this.parent.css('position', 'relative')

    this.el.after(`<div class="toggle-password"><i class="fa fa-eye"></i></div>`);
    this.parent.on('click', '.toggle-password', this.togglePassword.bind(this));
  }

  togglePassword(){
    if(this.state === 'hidden'){
      this.parent.find('input').attr('type', 'text');
      this.state = 'visible';
      this.parent.find('i').removeClass('fa-eye').addClass('fa-eye-slash');
    } else {
      this.parent.find('input').attr('type', 'password');
      this.state = 'hidden';
      this.parent.find('i').removeClass('fa-eye-slash').addClass('fa-eye');
    }
  }
}
