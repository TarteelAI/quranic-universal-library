module PaperTrailAttribution
  extend ActiveSupport::Concern

  private

  def attribute_versions_to(user)
    return yield unless user

    PaperTrail.request(whodunnit: user.to_gid.to_s, controller_info: { user_id: user.id }) do
      yield
    end
  end
end
