class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def toggle_approve!
    update_attribute :approved, !self.approved?
  end
end
