# Clickable step diagrams for the tool help, in place of screenshots.
# Each step shows a small drawing of the controls it uses, made with the ui_* helpers,
# so the help doesn't go out of date when a page is restyled.
module StepFlowHelper
  # steps: [{ title:, text:, ui: html }], ui is optional
  def step_flow(steps)
    nodes = steps.each_with_index.map do |step, i|
      arrow = i < steps.size - 1 ? "<span class='text-gray-400 px-1' aria-hidden='true'>&rarr;</span>" : ''

      "<li class='flex items-center'>" \
        "<button type='button' role='tab' aria-selected='#{i.zero?}' data-step-flow-target='node' " \
        "data-action='step-flow#show' data-step-flow-index-param='#{i}' " \
        "class='flex items-center gap-2 rounded-full border border-gray-300 bg-white px-3 py-1 text-sm text-gray-700 hover:border-blue-500 " \
        "aria-selected:border-blue-600 aria-selected:bg-blue-600 aria-selected:text-white'>" \
        "<span class='flex h-5 w-5 items-center justify-center rounded-full bg-gray-100 text-xs font-semibold text-gray-700'>#{i + 1}</span>" \
        "#{step[:title]}</button>#{arrow}</li>"
    end.join

    panels = steps.each_with_index.map do |step, i|
      previous_button = "<button type='button' data-action='step-flow#previous' class='text-sm text-blue-700 hover:underline'>&larr; #{steps[i - 1][:title]}</button>" if i.positive?
      next_button = "<button type='button' data-action='step-flow#next' class='text-sm text-blue-700 hover:underline'>#{steps[i + 1][:title]} &rarr;</button>" if i < steps.size - 1

      "<div role='tabpanel' data-step-flow-target='panel' class='#{'hidden' unless i.zero?} rounded-lg border border-gray-200 bg-white p-4'>" \
        "<p class='mb-2 font-semibold text-gray-900'>#{i + 1}. #{step[:title]}</p>" \
        "<div class='text-gray-800'>#{step[:text]}</div>" \
        "#{"<div class='mt-3'>#{step[:ui]}</div>" if step[:ui]}" \
        "<div class='mt-3 flex justify-between gap-2'><span>#{previous_button}</span><span>#{next_button}</span></div>" \
        "</div>"
    end.join

    "<div class='my-3' data-controller='step-flow'>" \
      "<ol role='tablist' class='mb-3 flex flex-wrap items-center gap-y-2'>#{nodes}</ol>" \
      "#{panels}</div>".html_safe
  end

  # A page or dialog: a title bar and the controls in it.
  def ui_screen(*parts, title: nil)
    bar = "<div class='border-b border-gray-200 bg-gray-100 px-2 py-1 text-xs text-gray-500'>#{title}</div>" if title

    "<div class='overflow-hidden rounded-md border border-gray-300 bg-gray-50 text-sm'>#{bar}" \
      "<div class='flex flex-wrap items-end gap-2 p-2'>#{parts.join}</div></div>"
  end

  # Two columns, like the PDF next to the editor in the Mushaf tools
  def ui_split(left, right)
    "<div class='grid w-full grid-cols-2 gap-2'><div>#{left}</div><div class='flex flex-wrap content-start gap-2'>#{right}</div></div>"
  end

  # A page of a printed Mushaf, drawn as lines of text
  def ui_pdf(lines = 5)
    rows = Array.new(lines) { |i| "<div class='h-1.5 rounded bg-gray-300 #{'mx-auto w-2/3' if i.zero?}'></div>" }.join
    "<div class='space-y-1.5 rounded border border-gray-300 bg-white p-2'><div class='text-[10px] text-gray-400'>PDF page</div>#{rows}</div>"
  end

  def ui_button(label, style = :primary)
    css = {
      primary: 'bg-green-600 text-white',
      blue: 'bg-blue-600 text-white',
      dark: 'bg-gray-800 text-white',
      light: 'border border-gray-300 bg-white text-gray-700'
    }[style]

    "<span class='inline-block rounded px-2 py-1 text-xs font-medium #{css}'>#{label}</span>"
  end

  def ui_select(label, value = 'Select')
    "<span class='inline-flex flex-col text-xs text-gray-600'>#{ui_text(label)}" \
      "<span class='mt-0.5 inline-flex min-w-[5rem] items-center justify-between gap-2 rounded border border-gray-300 bg-white px-2 py-1 text-gray-800'>#{ui_text(value)}<span class='text-gray-400'>&#9662;</span></span></span>"
  end

  def ui_input(label, value = '')
    "<span class='inline-flex flex-col text-xs text-gray-600'>#{ui_text(label)}" \
      "<span class='mt-0.5 inline-block min-w-[5rem] rounded border border-gray-300 bg-white px-2 py-1 text-gray-800'>#{value.present? ? ui_text(value) : '&nbsp;'}</span></span>"
  end

  # Arabic words in the Quran font, big enough to read
  def ui_text(text)
    return text unless text.to_s.match?(/\p{Arabic}/)

    "<span class='qpc-hafs text-base leading-normal text-gray-800' dir='rtl'>#{text}</span>"
  end

  def ui_checkbox(label, checked: true)
    box = checked ? "<span class='inline-flex h-3.5 w-3.5 items-center justify-center rounded-sm bg-blue-600 text-[9px] text-white'>&#10003;</span>" : "<span class='inline-block h-3.5 w-3.5 rounded-sm border border-gray-400 bg-white'></span>"
    "<span class='inline-flex items-center gap-1 text-xs text-gray-700'>#{box}#{label}</span>"
  end

  # Free text in a drawing, e.g. a short note or a row of a table
  def ui_note(text)
    "<span class='w-full text-xs text-gray-500'>#{text}</span>"
  end
end
