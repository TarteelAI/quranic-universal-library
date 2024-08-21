class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    can :read, :all
    can :read, ActiveAdmin::Page, name: "Dashboard"
    cannot :read, User
    cannot :impersonate, User
    cannot :read, DownloadableResource
    cannot :read, DownloadableFile
    cannot :read, UserDownload
    cannot :read, Feedback
    cannot :read, ImportantNote
    cannot :read, AdminTodo
    cannot :read, AdminUser

    can :read, User, id: user.id
    can :update, User, id: user.id

    if user.is_admin?
      can :manage, NavigationSearchRecord
      can :manage, ResourceContent
      can :manage, Translation
      can :manage, TranslatedName
      can :manage, FootNote
      can :manage, Draft::Translation
      can :manage, Draft::Tafsir
      can :manage, Draft::FootNote

      can :manage, Reciter
      can :manage, Tafsir
      can :manage, Audio::Recitation
      can :download, :restricted_content
      can :manage, :draft_content
      can :assign_project, User
      can :moderate, User
      can :download, :from_admin
      can :run_actions, :from_admin
    end

    if user.is_moderator?
      can :create, UserProject
      can :update, UserProject
      can :manage, Morphology::Phrase
      can :manage, Morphology::PhraseVerse
      can :manage, Morphology::MatchingVerse

      can [:read, :update, :create], Draft::Translation
      can [:read, :update, :create], Draft::Tafsir
      can [:read, :update, :create], Draft::FootNote

      cannot :destroy, Draft::Translation
      cannot :destroy,  Draft::Tafsir
      cannot :destroy, Draft::FootNote
    end

    if user.is_normal_user?
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
