module ApplicationHelper
  def pagy_nav_tailwind(pagy, **opts)
    link = pagy_link_proc(pagy, **opts)
    
    html = +%(<nav class="pagination-nav tw-flex tw-items-center tw-justify-center tw-gap-1.5" aria-label="pager">)
    
    # Previous link
    if pagy.prev
      html << link.call(pagy.prev, '<svg class="tw-w-4.5 tw-h-4.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path></svg>'.html_safe, 'aria-label="previous" class="tw-inline-flex tw-items-center tw-justify-center tw-w-9 tw-h-9 tw-text-gray-500 tw-bg-white tw-border tw-border-gray-200 tw-rounded-lg hover:tw-bg-gray-50 hover:tw-text-[#46ac7a] hover:tw-border-[#46ac7a] hover:tw-shadow-sm tw-transition-all tw-duration-200"')
    else
      html << %(<span class="tw-inline-flex tw-items-center tw-justify-center tw-w-9 tw-h-9 tw-text-gray-300 tw-bg-gray-50/50 tw-border tw-border-gray-100 tw-rounded-lg tw-cursor-not-allowed">)
      html << %(<svg class="tw-w-4.5 tw-h-4.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"></path></svg>)
      html << %(</span>)
    end
    
    # Page links
    pagy.series.each do |item|
      if item.is_a?(Integer) # page number
        html << link.call(item, item, 'class="tw-inline-flex tw-items-center tw-justify-center tw-w-9 tw-h-9 tw-text-sm tw-font-medium tw-text-gray-600 tw-bg-white tw-border tw-border-gray-200 tw-rounded-lg hover:tw-bg-gray-50 hover:tw-text-[#46ac7a] hover:tw-border-[#46ac7a] hover:tw-shadow-sm tw-transition-all tw-duration-200"')
      elsif item.is_a?(String) # current page
        html << %(<span class="tw-inline-flex tw-items-center tw-justify-center tw-w-9 tw-h-9 tw-text-sm tw-font-bold tw-text-white tw-bg-[#46ac7a] tw-border tw-border-[#46ac7a] tw-rounded-lg tw-shadow-sm tw-shadow-green-500/10">#{item}</span>)
      elsif item == :gap # gap
        html << %(<span class="tw-inline-flex tw-items-center tw-justify-center tw-w-9 tw-h-9 tw-text-gray-400 tw-font-bold">...</span>)
      end
    end
    
    # Next link
    if pagy.next
      html << link.call(pagy.next, '<svg class="tw-w-4.5 tw-h-4.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>'.html_safe, 'aria-label="next" class="tw-inline-flex tw-items-center tw-justify-center tw-w-9 tw-h-9 tw-text-gray-500 tw-bg-white tw-border tw-border-gray-200 tw-rounded-lg hover:tw-bg-gray-50 hover:tw-text-[#46ac7a] hover:tw-border-[#46ac7a] hover:tw-shadow-sm tw-transition-all tw-duration-200"')
    else
      html << %(<span class="tw-inline-flex tw-items-center tw-justify-center tw-w-9 tw-h-9 tw-text-gray-300 tw-bg-gray-50/50 tw-border tw-border-gray-100 tw-rounded-lg tw-cursor-not-allowed">)
      html << %(<svg class="tw-w-4.5 tw-h-4.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>)
      html << %(</span>)
    end
    
    html << %(</nav>)
    html.html_safe
  end

  def pagy_info_tailwind(pagy)
    %(<div class="tw-text-sm tw-text-gray-500 tw-font-medium tw-bg-gray-50 tw-px-3 tw-py-1 tw-rounded-full tw-border tw-border-gray-200">#{pagy_info(pagy)}</div>).html_safe
  end
  include Pagy::Frontend

  def is_current_page?(controller:, action: nil)
    controller_name == controller && (action.nil? || action_name == action)
  end

  def header_nav_item_active?(key)
    case key.to_sym
    when :resources
      current_page?(resources_path) || controller_name == 'resources'
    when :tools
      current_page?(tools_path)
    when :faq
      current_page?(faq_path)
    when :credits
      current_page?(credits_path)
    when :cms
      request.path.start_with?('/cms')
    else
      false
    end
  end

  def header_nav_link_classes(active:, variant: :desktop, extra: nil)
    if active
      case variant.to_sym
      when :desktop
        ['tw-text-[#46ac7a] tw-font-semibold hover:tw-text-[#46ac7a] tw-transition-colors tw-hidden md:tw-flex', extra].compact.join(' ')
      when :drawer
        ['tw-text-[#46ac7a] tw-font-semibold hover:tw-text-[#46ac7a] tw-transition-colors tw-text-lg', extra].compact.join(' ')
      else
        raise ArgumentError, "unsupported variant: #{variant.inspect}"
      end
    else
      base = case variant.to_sym
             when :desktop
               'tw-text-black hover:tw-text-[#46ac7a] tw-transition-colors tw-hidden md:tw-flex'
             when :drawer
               'tw-text-black hover:tw-text-[#46ac7a] tw-transition-colors tw-text-lg'
             else
               raise ArgumentError, "unsupported variant: #{variant.inspect}"
             end
      [ base, extra ].compact.join(' ')
    end
  end

  def header_nav_cms_link_classes(active:)
    base = 'btn-outline-pill tw-px-4 tw-py-1 md:tw-px-6 md:tw-py-2'
    active_suffix = 'tw-font-semibold tw-border-[#46ac7a] !tw-text-[#46ac7a] hover:!tw-bg-[#46ac7a]/10 hover:!tw-text-[#46ac7a] hover:!tw-border-[#46ac7a]'
    active ? "#{base} #{active_suffix}" : base
  end

  def header_nav_aria_current_attrs(active)
    active ? { aria: { current: 'page' } } : {}
  end

  def set_page_title(title, data_options = {})
    content_for :title, title
    options = data_options.map do |key, value|
      "data-#{key}=#{value}"
    end.join(' ')

    "<div class='d-none' data-controller='page-title' data-title='#{title}' #{options}></div>".html_safe
  end

  def has_filters?(*filters)
    filters.detect do |f|
      params[f].present?
    end
  end

  def font_ids(verses)
    pages = {}
    verses.each do |v|
      pages[v.page_number] = true
      pages[v.v2_page] = true
    end

    pages.keys
  end

  def contributors
    [
      {
        name: "Dr. Amin Anane",
        url: "https://github.com/aminanan",
        description: "For developing and providing the DigitalKhatt fonts."
      },
      {
        name: "Ayman Siddiqui",
        url: 'https://zoopernet.com',
        description: "For his amazing work on Indopak and tajweed fonts and script."
      },
      {
        name: "QuranWBW.com",
        url: "https://quranwbw.com/",
        description: "For providing word-by-word translations in multiple languages."
      },
      {
        name: "Collin Fair",
        url: "https://github.com/cpfair",
        description: "For generating the original word-by-word timestamps for various reciters."
      },
      {
        name: "Dr. Kais Dukes",
        url: "https://github.com/kaisdukes",
        description: "For preparing the original digitized Quran morphology data."
      },
      {
        multiple: [
          {
            name: "EveryAyah.com",
            url: "https://everyayah.com",
          },
          {
            name: "QuranicAudio.com",
            url: "https://quranicaudio.com/",
          }
        ],
        description: "For collecting and providing Quran recitations from a variety of famous reciters."
      },
      {
        name: 'Fawaz Ahmed',
        url: 'https://github.com/fawazahmed0',
        description: 'For performing OCR on multiple translations.'
      },
      {
        name: "King Fahd Quran Printing Complex",
        url: "https://qurancomplex.gov.sa/",
        description: "For publishing many of the original images and fonts available in QUL, which are the same assets used to publish the physical mushaf."
      },
      {
        name: "Mustafa Jibaly",
        url: "https://github.com/mustafa0x",
        description: "For improving and providing Quran morphology data."
      },
      {
        name: "Naveed Ahmad",
        url: "https://github.com/naveed-ahmad",
        description: "For building and maintaining QUL as well as leading the acquisition and refinement of many resources in QUL."
      },
      {
        name: "Quran.com",
        url: "https://quran.com",
        description: "For serving as a gathering place for many great individuals to contribute Quran resources and discover each other."
      },
      {
        multiple: [
          {
            name: "Sami Rifai",
            url: nil,
          },
          {
            name: "ReciteQuran.com",
            url: "https://recitequran.com",
          }
        ],
        description: "For providing wbw and tajweed recitations of Imam Wisam Sharieff, tajweed images and SVGs."
      },
      {
        name: "Tanzil",
        url: "https://tanzil.net/",
        description: "For preparing and auditing the Quran text that underpins most digital Islamic projects and sourcing many translations."
      }
    ]
  end

  def safe_html(html)
    html.to_s.html_safe
  end

  def change_log_resource_path(change_log)
    resource = change_log.public_downloadable_resource
    return if resource.blank?

    detail_resources_path(resource.resource_type, resource.id)
  end

  def change_log_resource_url(change_log)
    resource = change_log.public_downloadable_resource
    return if resource.blank?

    detail_resources_url(resource.resource_type, resource.id)
  end

  def change_log_resource_type(change_log)
    resource = change_log.public_downloadable_resource
    value = resource&.group_name || change_log.resource_type_slug
    value.to_s.tr('_', ' ').tr('-', ' ').titleize
  end

  def quran_scripts
    {
      text_qpc_hafs: "QPC Hafs",
      text_uthmani: "Utmani(Me Quran)",
      text_indopak_nastaleeq: "Indopak Nastaleeq",
      text_indopak: "Inodpak(PDMS Saleem)",
      text_imlaei: "Imlaei(Simple script)",
      text_imlaei_simple: "Imlaei(Without tashkeel)",
      text_uthmani_tajweed: "QPC Hafs with tajweed",
      text_qpc_nastaleeq: "QPC Nastaleeq",
      text_digital_khatt: "Digitak Khatt v2(1422 - 1439H print)",
      text_digital_khatt_v1: "Digitak Khatt v1(1405H print)",
      text_digital_khatt_indopak: "Digitak Khatt Indopak",
    }
  end

  def arabic_fonts_options
    quran_scripts.map { |key, name| [name, key.to_s.sub(/^text_/, "").tr("_", "-")] }
  end
end
