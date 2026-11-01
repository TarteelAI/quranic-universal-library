import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element["remoteSelect"] = this;
    this.bindRemoteSelect2();
  }

  bindRemoteSelect2() {
    let el = $(this.element);

    // reading from data allows <input data-searchable_select='{"tags": ['some']}'>
    // to be passed to select2
    let options = {
      multiple: el.data("multiple") || false,
      allowClear: true,
      placeholder: el.data("placeholder") || "Select",
      tags: el.data("tags") || false // for adding items on the fly
    };

    if (el.data("parent")) {
      options["dropdownParent"] = $(el.data("parent"));
    }

    // Label for typed text that isn't in the list, e.g. data-create-label="Add missing"
    if (options.tags && el.data("create-label")) {
      const label = el.data("create-label");
      options["createTag"] = params => {
        const term = $.trim(params.term);
        return term ? { id: term, text: `${label}: ${term}`, newTag: true } : null;
      };
      options["insertTag"] = (data, tag) => data.push(tag);
    }

    const url = el.data("url");
    const that = this;

    if (url) {
      $.extend(options, {
        minimumInputLength: 0,
        ajax: {
          url: url,
          dataType: "json",
          cache: true,

          data: function(params) {
            return {
              query: params.term,
              page: that.pageParamWithBaseZero(params)
            };
          }
        },
        escapeMarkup: function(text) {
          return text;
        }
      });
    }

    options["templateResult"] = item => {
      return this.dropdownItemTemplate(item);
    };

    // Arabic options, e.g. data-text-class="qpc-hafs text-xl". The value is the Arabic text,
    // results can have a meaning shown next to it.
    const textClass = el.data("text-class");
    if (textClass) {
      const arabic = item => {
        if (item.loading || !item.id) return item.text;

        const option = $("<span class='inline-flex items-baseline gap-2'>");
        if (item.newTag) option.append($("<span class='text-sm text-green-700'>").text(el.data("create-label")));
        option.append($("<span dir='rtl'>").addClass(textClass).text(item.id));
        if (item.meaning) option.append($("<span class='text-sm text-gray-500'>").text(item.meaning));
        return option;
      };
      options["templateResult"] = arabic;
      options["templateSelection"] = arabic;
    }
    /*
        options["templateSelection"] = item => {
            return this.resultTemplate(item);
        };*/

    this.select = el.select2(options);
  }

  dropdownItemTemplate(item) {
    if (item.loading) return item.text;

    if (!item.description) {
      return item.text;
    }

    let container = $(`
        <div class='select2-result'>
          <div class='select2-result__title'>${item.description}</div>
      </div>`);

    return container;
  }

  resultTemplate(item) {
    return item.text;
  }

  removeSelect2() {
    const select = this.select.data("select2");
    if (select) select.destroy();
  }

  disconnect() {
    this.removeSelect2();
  }

  pageParamWithBaseZero(params) {
    return params.page ? params.page - 1 : undefined;
  }
}
