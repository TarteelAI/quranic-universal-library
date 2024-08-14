// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import {
  Controller
} from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const {userRole, actionKey} = this.element.dataset;

    if(this.shouldHideSidebar(userRole, actionKey))
      this.hideSidebar()
  }

  hideSidebar(){
    $("#active_admin_content").removeClass('with_sidebar');
    $("#active_admin_content #sidebar").remove()
    $("#main_content").css('marginRight', '0px');
  }

  shouldHideSidebar(userRole, actionKey){
    return !['admin', 'super_admin'].includes(userRole) && ['users-index'].includes(actionKey)
  }
}