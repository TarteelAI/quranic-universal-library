# frozen_string_literal: true

class SplitScreenComponent < ApplicationComponent
  renders_one :left
  renders_one :right

  # height_class: pass 'max-h-[80vh]' for short content, so the panes fit it
  def initialize(left_content: nil, right_content: nil, height_class: 'h-screen md:h-[80vh]')
    @left_content = left_content
    @right_content = right_content
    @height_class = height_class
  end
end
