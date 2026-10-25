# frozen_string_literal: true

# Shared helpers for permanently removing a recitation and everything hanging
# off it. Only reachable from the CMS by super admins, see
# `app/admin/audio/recitation.rb` and `app/admin/audio/audio_recitation.rb`.
module RecitationDestroyable
  extend ActiveSupport::Concern

  # A resource content is only safe to drop when nothing else was built on top
  # of it. Anything listed here means the record is shared and we keep it.
  def resource_content_blockers(content = get_resource_content)
    return ['Recitation has no resource content'] if content.nil?

    blockers = []
    blockers << "#{content.downloadable_resources.count} downloadable resources" if content.downloadable_resources.exists?
    blockers << "#{content.user_projects.count} user projects" if content.user_projects.exists?
    blockers << 'a book' if content.book.present?
    blockers
  end

  protected

  # Returns the reason the resource content was kept, or nil when it was deleted.
  def destroy_resource_content(content)
    blockers = resource_content_blockers(content)
    return blockers.join(', ') if blockers.present?

    content.destroy!
    nil
  end
end
