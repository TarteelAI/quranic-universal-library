class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def toggle_approve!
    update_attribute :approved, !self.approved?
  end

  def self.ransackable_associations(auth_object = nil)
    []
  end

  def self.ransackable_attributes(auth_object = nil)
    column_names
  end

  def format_meta_key(key)
    key.to_s.gsub(/[\s_]/, '-').gsub('--', '-').downcase
  end
end
