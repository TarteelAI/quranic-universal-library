# frozen_string_literal: true

module Start
  # Props of the kits index (Start::KitsController#index): a card for each kit.
  class KitsIndexResource < ApplicationResource
    many :kits, resource: KitCardResource
  end
end
