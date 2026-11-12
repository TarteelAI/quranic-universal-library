# frozen_string_literal: true

# The page group setting: which groups of URLs the new Inertia pages serve. It is one
# deploy-time variable, QUL_PAGE_GROUPS, a comma-separated list such as "home,catalog,apps,content".
# A group that is not listed is served by the old ERB views, which stay in the code.
#
# Routes take over a group's URLs inside `constraints(PageGroups.constraint(:catalog))`, placed
# above the old routes for the same paths. The setting is read on every request, so turning a
# group off restores the old page with no code change (a restart picks up the new value).
module PageGroups
  GROUPS = %w[home catalog apps content].freeze

  def self.enabled
    ENV.fetch('QUL_PAGE_GROUPS', '').split(',').map(&:strip) & GROUPS
  end

  def self.enabled?(group)
    enabled.include?(group.to_s)
  end

  def self.constraint(group)
    raise ArgumentError, "Unknown page group: #{group}" unless GROUPS.include?(group.to_s)

    ->(_request) { enabled?(group) }
  end
end
