# frozen_string_literal: true

module Content
  # Props of the FAQ page (Content::PagesController#faq).
  class PagesFaqResource < ApplicationResource
    many :items, resource: FaqItemResource
  end
end
