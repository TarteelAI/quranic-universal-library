# frozen_string_literal: true

module Content
  # A published FAQ item. The answer is editor HTML reduced to prose (Content::Prose).
  class FaqItemResource < ApplicationResource
    typelize id: :number, question: :string, answer: :string
    attributes :id, :question

    attribute(:answer) { |faq| Prose.sanitize(faq.answer) }
  end
end
