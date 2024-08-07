# frozen_string_literal: true

require "paper_trail/version_concern"

class PaperTrail::Version < ActiveRecord::Base
     include PaperTrail::VersionConcern

    def self.ransackable_attributes(auth_object = nil)
      ["created_at", "event", "id", "item_id", "item_type", "object", "reviewed", "reviewed_by_id", "whodunnit"]
    end
end
