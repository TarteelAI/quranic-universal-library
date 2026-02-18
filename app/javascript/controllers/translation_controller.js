// Visit The Stimulus Handbook for more details
// https://stimulusjs.org/handbook/introduction
//
// This example controller works with specially annotated HTML like:
//
// <div data-controller="hello">
//   <h1 data-target="hello.output"></h1>
// </div>

import AjaxModalController from "./ajax_modal_controller"

export default class extends AjaxModalController {
    connect() {
        const draft = this.element.getAttribute("draft");

        $(this.element).on("click", "sup", e => {
            e.preventDefault();
            const target = e.target;

            this.loadModal(target.getAttribute("foot_note"), draft);
        });
    }

    loadModal(id, isDraft) {
        var that = this;

        let url = `/foot_notes/${id}?draft=${isDraft}`;
        this.createModal('translation');
        this.show();

        fetch(url).then(response => response.text()).then(content => {
            const response = $("<div>").html(content);
            this.setContent(response.find("#title").html(), response.find("#body").html())
        }).catch(err => {
            if (401 == err.status) {
                const modalBody = document.getElementById('modal-body');
                if (modalBody) {
                    modalBody.innerHTML = `
                    <div class='tw-text-center tw-p-5'> 
                        <h2>${err.responseText}</h2>
                        <p><a href="/users/sign_in?user_return_to=${location.pathname}" class="tw-btn tw-btn-primary">Login</a></p>
                    </div>`;
                }
            }
        })
    }
}