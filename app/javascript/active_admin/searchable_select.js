function initSearchableSelects(inputs, extra) {
  inputs.attr("data-controller", "select2")
}

const onDOMReady = () => {
  initSearchableSelects($(".searchable-select-input"), {placeholder: ""});
}

$(document).on('turbo:load', onDOMReady);