# frozen_string_literal: true

module Site
  # The home page (/), while the `home` page group is on (PageGroups). The old landing page
  # (LandingController) answers otherwise. The head keeps the old page's title, description and
  # WebSite JSON-LD with its publisher.
  class HomeController < InertiaController
    # The starter kits the "Start from a kit" row shows; its "All kits" link lists the rest.
    KITS = 3

    def show # rubocop:disable Metrics/AbcSize -- sets each prop of the page
      # Each is computed when a prop first reads it (HomeShowResource calls it): a card's partial
      # reload reads only its sample's preview, so it skips the counts, the apps and the kits.
      @stats = lazy { Catalog::Stats.new.call }
      @contributors = lazy { contributors }
      @samples = lazy { Catalog::Samples.new.call }
      @tools = SiteNav::ContributeTools.featured(helpers.developer_tools)
      @apps = lazy { AppDirectory.apps }
      @kits = lazy { PageGroups.enabled?(:start) ? Kits.listed(Kits.all.first(KITS)) : [] }

      render_inertia 'site/HomePage', meta: page_meta(
        title: 'Quranic Universal Library — Download Quran Data, JSON & APIs',
        description: 'Download free Quran data as JSON — translations, tafsir, word-by-word, audio recitations ' \
                     'and Uthmani/IndoPak scripts — plus developer tools and APIs from the Quranic Universal Library.',
        json_ld: {
          '@type': 'WebSite',
          name: PageMeta::SITE_NAME,
          alternateName: 'QUL',
          url: SeoHelper::HOST,
          image: PageMeta::IMAGE,
          publisher: {
            '@type': 'Organization',
            name: 'Tarteel AI',
            url: 'https://tarteel.ai',
            logo: { '@type': 'ImageObject', url: "#{SeoHelper::HOST}/favicon.svg" },
          },
        },
      )
    end

    private

    # A value computed on the first call and kept for the request. The values here are never nil.
    def lazy
      value = nil
      -> { value ||= yield }
    end

    def contributors
      data_contributors + GithubService.contributors_count
    end

    # The people who changed the Quran data in the CMS: the users its edits are attributed to
    # (PaperTrailAttribution sets user_id; older rows have only a whodunnit GlobalID), who left a
    # proofreading comment or who were approved for a project. GitHub logins cannot be matched to
    # them, so someone in both lists counts twice. Cached for a day: the edits table is large. When
    # the day is up, one request counts again while the others keep the old count.
    def data_contributors
      Rails.cache.fetch('home_data_contributors', expires_in: 1.day, race_condition_ttl: 1.minute) do
        ApplicationRecord.connection.select_value(<<~SQL.squish)
          SELECT COUNT(DISTINCT user_id) FROM (
            SELECT COALESCE(user_id, substring(whodunnit from '/User/([0-9]+)$')::bigint) FROM versions
            UNION SELECT user_id FROM proof_read_comments
            UNION SELECT user_id FROM user_projects WHERE approved
          ) contributors(user_id)
        SQL
      end
    end
  end
end
