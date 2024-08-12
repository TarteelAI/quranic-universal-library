# config/initializers/paper_trail_patch.rb
ActiveSupport.on_load(:active_record) do
  require 'paper_trail'

  module PaperTrailRansackablePatch
    def self.included(base)
      base.singleton_class.class_eval do
        def ransackable_attributes(auth_object = nil)
          ["created_at", "event", "id", "item_id", "item_type", "object", "reviewed", "reviewed_by_id", "whodunnit"]
        end

        def ransackable_associations(auth_object = nil)
          []
        end
      end
    end
  end

  PaperTrail::Version.include PaperTrailRansackablePatch
end
