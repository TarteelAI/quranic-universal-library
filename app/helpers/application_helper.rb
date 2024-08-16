module ApplicationHelper
  include Pagy::Frontend

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
        name: "Ahmed El-Helw",
        url: "https://github.com/ahmedre",
        description: "For previously hosting what is now the QUL app, providing the initial dataset, and contributing fixes to many resources."
      },
      {
        name: "Ayman Siddiqui",
        url: nil,
        description: "For his amazing work on Indopak and tajweed fonts and script."
      },
      {
        name: "QuranWBW.com",
        url: "http://quranwbw.com/",
        description: "For providing word-by-word translations in multiple languages."
      },
      {
        name: "Collin Fair",
        url: "https://github.com/cpfair",
        description: "For generating the original word-by-word timestamps for various reciters."
      },
      {
        name: "GreenTech Foundation",
        url: "http://gtaf.org",
        description: "For providing Bengali tafisr and word by word translation."
      },
      {
        name: "King Fahd Quran Printing Complex",
        url: "http://qurancomplex.gov.sa/",
        description: "For publishing many of the original images and fonts available in QUL, which are the same assets used to publish the physical mushaf."
      },
      {
        name: "Naveed Ahmad",
        url: "https://github.com/naveed-ahmad",
        description: "For building and maintaining QUL as well as leading the acquisition and refinement of many resources in QUL."
      },
      {
        name: "Quran.com",
        url: "http://quran.com",
        description: "For serving as a gathering place for many great individuals to contribute Quran resources and discover each other."
      },
      {
        name: 'Mustafa',
        url: 'https://github.com/mustafa0x/',
        description: 'For providing the dataset for the Quranic Arabic Corpus.'
      },
      {
        name: "EveryAyah.com",
        url: "http://everyayah.com",
        description: "For collecting and providing Quran recitations from a variety of famous reciters."
      },
      {
        name: "QuranicAudio.com",
        url: "http://quranicaudio.com/",
        description: "For collecting and providing Quran recitations from a variety of famous reciters."
      },
      {
        name: "Sami Rifai",
        url: nil,
        description: "For providing wbw and tajweed recitations of Imam Wisam Sharieff, tajweed images and svgs."
      },
      {
        name: "ReciteQuran.com",
        url: "http://recitequran.com",
        description: "For providing wbw and tajweed recitations of Imam Wisam Sharieff, tajweed images and svgs."
      },
      {
        name: "Tanzil",
        url: "https://tanzil.net/",
        description: "For preparing and auditing the Quran text that underpins most digital Islamic projects and sourcing many translations."
      }
    ]
  end
end
