# frozen_string_literal: true

class SplitScreenComponent < ApplicationComponent
  renders_one :left
  renders_one :right

  def initialize(left_content: nil, right_content: nil)
    @left_content = left_content
    @right_content = right_content
  end
end
