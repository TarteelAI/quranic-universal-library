# frozen_string_literal: true

# Starter kits: curated sets of resources that work together for one kind of app, each item
# with the reason it was picked and an optional alternative. They are a file in the repo
# (config/kits.yml), read here, and name resources by slug. It knows nothing of controllers,
# requests or the session.
module Kits
  FILE = Rails.root.join('config', 'kits.yml')

  # `resource` and `alternative` are resource slugs.
  Item = Data.define(:need, :resource, :why, :alternative)
  # `answers` are the guided setup's answers for the kit, as a query.
  Kit = Data.define(:key, :title, :tag, :blurb, :description, :answers, :items) do
    # The answers as GuidedSetup reads them. spec/services/kits_spec.rb checks that the guided
    # setup offers the kit's languages.
    def setup_answers
      GuidedSetup::Answers.from(answers, languages: answers.fetch('lang').split(','))
    end
  end
  # A kit item with its published resource and its alternative's, or nil when that is unpublished.
  Entry = Data.define(:item, :resource, :alternative)
  # A kit with the entries of its published resources (DownloadableResource rows), for its card.
  Listed = Data.define(:kit, :entries)

  def self.all
    YAML.safe_load_file(FILE).fetch('kits').map do |kit|
      items = kit.fetch('items').map do |item|
        Item.new(need: item.fetch('need'), resource: item.fetch('resource'), why: item.fetch('why'),
                 alternative: item['alternative'],)
      end
      Kit.new(key: kit.fetch('key'), title: kit.fetch('title'), tag: kit.fetch('tag'), blurb: kit.fetch('blurb'),
              description: kit.fetch('description'), answers: kit.fetch('answers'), items: items,)
    end
  end

  def self.find(key)
    all.find { |kit| kit.key == key }
  end

  # Every slug the kits name.
  def self.slugs(kits = all)
    kits.flat_map { |kit| kit.items.flat_map { |item| [item.resource, item.alternative] } }.compact.uniq
  end

  # The kits with their published resources, in one query whatever the number of kits.
  def self.listed(kits)
    published = DownloadableResource.published.where(slug: slugs(kits)).index_by(&:slug)
    kits.map { |kit| Listed.new(kit: kit, entries: resolve(kit, published)) }
  end

  # The kit's items whose resource is in `published` (slug => resource, or any value keyed by
  # slug), in order. An item whose resource is missing there is left out, so a kit still shows
  # when one of its resources is unpublished.
  def self.resolve(kit, published)
    kit.items.filter_map do |item|
      resource = published[item.resource]
      Entry.new(item: item, resource: resource, alternative: published[item.alternative]) if resource
    end
  end
end
