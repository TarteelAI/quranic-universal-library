module ApplicationHelper
  include Pagy::Frontend

  def is_current_page?(controller:, action: nil)
    controller_name == controller && (action.nil? || action_name == action)
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
end
