# frozen_string_literal: true

# == Schema Information
#
# Table name: versions
#
#  id             :integer          not null, primary key
#  event          :string           not null
#  item_type      :string           not null
#  object         :text
#  reviewed       :boolean          default(FALSE)
#  whodunnit      :string
#  created_at     :datetime
#  item_id        :integer          not null
#  reviewed_by_id :integer
#
# Indexes
#
#  index_versions_on_reviewed  (reviewed)
#
require "paper_trail/version_concern"

module PaperTrail
  class Version < ActiveRecord::Base
    include PaperTrail::VersionConcern

    def self.ransackable_attributes(auth_object = nil)
      ["created_at", "event", "id", "item_id", "item_type", "object", "reviewed", "reviewed_by_id", "whodunnit"]
    end
  end
end