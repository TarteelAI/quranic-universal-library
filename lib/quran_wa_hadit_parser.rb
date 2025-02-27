require 'nokogiri'

class QuranWaHaditParser
  # Regular expression to match Arabic diacritics
  ARABIC_DIACRITICS_REGEX = /[\u064B-\u0652\u0670]/.freeze
  attr_reader :language_classes, :para_delimiter
  DEFAULT_LANGUAGE_CLASSES = {
    arabic: 'indokpak arabic',
  }

  def initialize(raw_text, para_delimiter, language_classes = DEFAULT_LANGUAGE_CLASSES)
    @raw_text = raw_text.to_s.strip
    @language_classes = language_classes
    @para_delimiter = para_delimiter || /\r\n+/
  end

  def clean_html(input_html)
    doc = Nokogiri::HTML.parse(input_html)

    # Replace font tags with span tags and add classes based on color attribute
    doc.css('font').each do |font|
      span = doc.create_element('span', font.inner_html)

      # Map colors to corresponding classes
      color_classes = {
        '#3333FF' => 'blue',
        'red' => 'red'
      }

      color = font['color']
      span['class'] = color_classes[color] if color_classes.key?(color)

      font.replace(span)
    end

    div = doc.at('div')
    div.replace(div.children)

    # Remove \r\n within tags
    doc.traverse do |node|
      if node.text?
        node.content = node.content.strip
      end
    end

    doc.children.to_html
  end


  # Detects the language of a given text segment.
  # The heuristic here checks for Arabic diacritics.
  #
  # @param text [String] The text to be examined.
  # @return [String] "arabic" if Arabic diacritics are found, otherwise "urdu".
  def detect_language(text)
    return "arabic" if text =~ ARABIC_DIACRITICS_REGEX
    "urdu"
  end

  # Splits a text (typically a paragraph) into segments where consecutive words share the same language.
  #
  # @param text [String] The paragraph text.
  # @return [Array<Array(String, String)>] An array of [segment, language] pairs.
  def split_into_language_segments(text)
    segments = []
    words = text.split(/\s+/)
    return [[text, detect_language(text)]] if words.empty?

    current_segment = words.first.dup
    current_lang = detect_language(current_segment)

    words[1..-1].each do |word|
      word_lang = detect_language(word)
      if word_lang == current_lang
        current_segment << " " << word
      else
        segments << [current_segment, current_lang]
        current_segment = word.dup
        current_lang = word_lang
      end
    end

    segments << [current_segment, current_lang]
    segments
  end

  # Parses the raw text into an HTML fragment.
  #
  # The method splits the raw text into paragraphs (using "\r\n" as the delimiter).
  # For each paragraph, if it contains text in only one language, the language class is set
  # on the `<p>` element. For paragraphs with mixed language segments, each segment is wrapped
  # in a `<span>` with its corresponding language class.
  #
  # @return [String] The resulting HTML string.
  def parse
    # Create an empty Nokogiri document fragment.
    doc = Nokogiri::HTML::DocumentFragment.parse("")

    # Split the text into paragraphs using one or more "\r\n" as the delimiter
    paragraphs = @raw_text.split(para_delimiter)

    paragraphs.each do |para_text|
      para_text.strip!
      next if para_text.empty?  # Skip empty lines

      # Create a <p> element for the paragraph.
      p_node = Nokogiri::XML::Node.new("p", doc)

      # Break the paragraph into language segments.
      segments = split_into_language_segments(para_text)

      if segments.size == 1
        # For a single-language paragraph, set the content and language class on the <p> tag.
        segment_text, lang = segments.first
        p_node.content = segment_text
        p_node["class"] = get_language_class(lang)
      else
        # For mixed-language paragraphs, wrap each segment in a <span> with its language class.
        segments.each do |segment_text, lang|
          span_node = Nokogiri::XML::Node.new("span", doc)
          span_node.content = segment_text
          span_node["class"] = get_language_class(lang)
          p_node.add_child(span_node)
          # Optionally, add a space between segments
          p_node.add_child(Nokogiri::XML::Text.new(" ", doc))
        end
      end

      doc.add_child(p_node)
    end

    # Return the generated HTML as a string.
    doc.to_html
  end


  def get_language_class(lang)
    language_classes[lang.to_sym] || lang
  end
end

