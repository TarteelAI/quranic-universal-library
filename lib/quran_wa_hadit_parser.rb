class QuranWaHaditParser
  require 'nokogiri'

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

end