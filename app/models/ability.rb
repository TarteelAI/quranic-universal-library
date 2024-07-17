class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    can :read, :all
    can :read, ActiveAdmin::Page, name: "Dashboard"
    cannot :read, User
    can :manage, User, id: user.id

    if user.admin?
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
      can :admin, :run_actions
      can :download, :restricted_content
      can :manage, :draft_content
    end

    if user.moderator?
      can :create, UserProject
      can :update, UserProject
      can :manage, Morphology::Phrase
      can :manage, Morphology::PhraseVerse
      can :manage, Morphology::MatchingVerse
    end

    if user.normal_user?
      cannot :read, ApiClient
      cannot :read, AdminTodo
      cannot :read, Feedback
      cannot :read, DatabaseBackup
      cannot :read, ResourcePermission
      cannot :read, UserProject
      cannot :read, ActiveAdmin::Comment
    end

    can :manage, :all if user.super_admin?
  end
end
