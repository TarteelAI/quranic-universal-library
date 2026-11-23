# frozen_string_literal: true

module Account
  # Props of the profile page (Account::ProfilesController#show), from Account::Profile: the user,
  # a count for each tab and the rows of the open tab (the other lists are null).
  class ProfilesShowResource < ApplicationResource
    typelize tab: [:string, { enum: Profile::TABS }], page: :number, pages: :number, catalog: :boolean
    attributes :tab, :page, :pages
    # Whether the resource pages are new pages, so a download's link is an Inertia visit.
    attributes :catalog

    one :person, resource: PersonResource
    one :counts, resource: CountsResource

    typelize filter: { nullable: true }
    one :filter, resource: FilterResource

    typelize downloads: { nullable: true }, contributions: { nullable: true }, accesses: { nullable: true },
             requests: { nullable: true }
    many :downloads, resource: DownloadResource
    many :contributions, resource: ContributionResource
    many :accesses, resource: AccessResource
    many :requests, resource: RequestResource
  end
end
