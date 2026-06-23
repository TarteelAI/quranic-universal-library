module DocsHelper
  ACCENTS = {
    "blue" => {
      icon_bg: "bg-blue-50 text-blue-600 ring-blue-100",
      card_hover: "hover:border-blue-300 hover:shadow-blue-100",
      arrow: "text-blue-600",
      active: "border-blue-500 text-blue-700 bg-blue-50",
      dot: "bg-blue-500"
    },
    "violet" => {
      icon_bg: "bg-violet-50 text-violet-600 ring-violet-100",
      card_hover: "hover:border-violet-300 hover:shadow-violet-100",
      arrow: "text-violet-600",
      active: "border-violet-500 text-violet-700 bg-violet-50",
      dot: "bg-violet-500"
    },
    "emerald" => {
      icon_bg: "bg-emerald-50 text-emerald-600 ring-emerald-100",
      card_hover: "hover:border-emerald-300 hover:shadow-emerald-100",
      arrow: "text-emerald-600",
      active: "border-emerald-500 text-emerald-700 bg-emerald-50",
      dot: "bg-emerald-500"
    },
    "amber" => {
      icon_bg: "bg-amber-50 text-amber-600 ring-amber-100",
      card_hover: "hover:border-amber-300 hover:shadow-amber-100",
      arrow: "text-amber-600",
      active: "border-amber-500 text-amber-700 bg-amber-50",
      dot: "bg-amber-500"
    }
  }.freeze

  def docs_accent(accent, key)
    ACCENTS.dig(accent.to_s, key) || ACCENTS.dig("blue", key)
  end

  def docs_page_count(category)
    category.pages.sum { |page| 1 + page.children.size }
  end

  def docs_icon(key, css_class = "w-6 h-6")
    paths = case key.to_s
            when "download"
              '<path d="M12 3v12m0 0l-4-4m4 4l4-4M4 17v2a2 2 0 002 2h12a2 2 0 002-2v-2" />'
            when "code"
              '<path d="M8 9l-3 3 3 3m8-6l3 3-3 3M13.5 6l-3 12" />'
            when "data"
              '<ellipse cx="12" cy="6" rx="7" ry="3" /><path d="M5 6v6c0 1.657 3.134 3 7 3s7-1.343 7-3V6M5 12v6c0 1.657 3.134 3 7 3s7-1.343 7-3v-6" />'
            when "api"
              '<path d="M4 7h16M4 12h16M4 17h10" /><circle cx="18" cy="17" r="2.5" />'
            else
              '<circle cx="12" cy="12" r="9" />'
            end

    raw(
      %(<svg xmlns="http://www.w3.org/2000/svg" class="#{css_class}" fill="none" viewBox="0 0 24 24" ) +
      %(stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">#{paths}</svg>)
    )
  end
end
