class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?
    can :read, :all

    if user.admin?
      can :manage, AdminUser, id: user.id

      can :manage, NavigationSearchRecord
      can :manage, ResourceContent
      can :manage, Translation
      can :manage, TranslatedName
      can :manage, FootNote
      can :manage, Draft::Translation
      can :manage, Draft::Tafsir

      can :manage, Reciter
      can :manage, Tafsir
      can :manage, Audio::Recitation
    end

    if user.moderator?
      can :create, UserProject
      can :update, UserProject
      can :manage, Morphology::Phrase
      can :manage, Morphology::PhraseVerse
      can :manage, Morphology::MatchingVerse
    end

    can :manage, :all if user.super_admin?
  end
end
