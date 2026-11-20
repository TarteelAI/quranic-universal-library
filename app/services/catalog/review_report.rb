# frozen_string_literal: true

module Catalog
  # The review report for the data team: the known data errors that visitors can see. It is
  # Markdown, generated on demand into tmp/ and
  # never committed. It holds public catalog facts only: resource, mushaf and tag names, ids and
  # counts. No data source and no user field.
  class ReviewReport
    DATA_ERRORS = {
      'Published resources with no files' => :without_files,
      'Published resources on content rows that are not approved' => :unapproved_contents,
      'Published resources whose content row has no name' => :unnamed_contents,
      'Content rows behind more than one resource' => :shared_contents,
      'Published layouts whose mushaf is disabled or has no words' => :layouts_without_words,
      'Published layouts with more page rows than pages' => :layouts_with_extra_pages,
      'Published layouts with too few bismillah lines' => :layouts_without_bismillah,
      'Default mushafs with no published layout' => :defaults_without_layout,
      'Tags that are spellings of the same name' => :tag_variants,
    }.freeze

    Section = Data.define(:note, :columns, :rows)

    def initialize(at: Time.current)
      @at = at
      @resources = DownloadableResource.order(:id).preload(:downloadable_files, :resource_content).to_a
    end

    # Writes the report and returns the number of rows under the data errors.
    def write(path)
      File.write(path, to_markdown)
      sections.sum { |_title, section| section.rows.size }
    end

    def to_markdown
      [header, *sections.map { |title, section| error(title, section) }].join("\n")
    end

    private

    def header
      <<~MD
        # Catalog review report

        Generated #{@at.utc.iso8601}.

        The catalog fields (display name, script family, rendering, status, replacement, recommended) are
        computed from this data when a page is read. To correct one, fix the data it comes from, or set the
        override key in the resource's meta data in the CMS: #{Derived::OVERRIDES.values.map { |key| "`#{key}`" }.join(', ')}.

        ## Known data errors
      MD
    end

    def sections
      @sections ||= DATA_ERRORS.map { |title, name| [title, send(name)] }
    end

    def error(title, section)
      body = section.rows.empty? ? "None found.\n" : table(section.columns, section.rows)
      "### #{title}\n\n#{section.note}\n\n#{body}"
    end

    def published
      @resources.select(&:published)
    end

    def without_files
      rows = published.select { |resource| resource.downloadable_files.none?(&:published) }
        .reject(&:restrict_download?).map { |resource| named(resource) }
      Section.new('Restricted resources are left out: they have no files on purpose.', ['Id', 'Type', 'Resource'], rows)
    end

    def unapproved_contents
      rows = published.reject { |resource| resource.resource_content&.approved }.map { |resource| named(resource) }
      Section.new('The download pages list them; the content API hides them.', ['Id', 'Type', 'Resource'], rows)
    end

    def unnamed_contents
      rows = published.select { |resource| resource.resource_content&.name.blank? }
        .map { |resource| [*named(resource), resource.resource_content_id] }
      Section.new('The content API shows these resources with a blank name.', ['Id', 'Type', 'Resource', 'Content row'],
                  rows,)
    end

    def shared_contents
      groups = @resources.group_by(&:resource_content_id).select { |id, group| id && group.size > 1 }
      rows = groups.map do |id, group|
        [id, group.map { |resource| "#{resource.display_name} (#{resource.id})" }.join(', ')]
      end
      Section.new('Each content row should back one resource.', ['Content row', 'Resources'], rows)
    end

    def layouts
      @layouts ||= published.select { |resource| resource.resource_type == 'mushaf-layout' }
        .map { |resource| [resource, MushafLayouts::Page.mushaf_for(resource)] }
    end

    def layouts_without_words
      worded = MushafWord.where(mushaf_id: layouts.filter_map { |_, mushaf| mushaf&.id }).distinct.pluck(:mushaf_id)
      rows = layouts.reject { |_, mushaf| mushaf&.enabled && worded.include?(mushaf.id) }.map do |layout, mushaf|
        [*named(layout), mushaf ? "#{mushaf.name} (#{mushaf.id})" : 'none', mushaf&.enabled ? 'yes' : 'no']
      end
      Section.new('These layouts cannot show a page.', ['Id', 'Type', 'Resource', 'Mushaf', 'Enabled'], rows)
    end

    def layouts_with_extra_pages
      counts = MushafPage.where(mushaf_id: layouts.filter_map { |_, mushaf| mushaf&.id }).group(:mushaf_id).count
      rows = layouts.select { |_, mushaf| mushaf && counts.fetch(mushaf.id, 0) > mushaf.pages_count }
        .map { |layout, mushaf| [*named(layout), mushaf.pages_count, counts[mushaf.id]] }
      Section.new('Pages past the page count are not shown.', ['Id', 'Type', 'Resource', 'Pages', 'Page rows'], rows)
    end

    # A mushaf has a surah-name line and a bismillah line at the start of almost every surah; far
    # fewer bismillah lines than surah-name lines means the alignment data is incomplete.
    def layouts_without_bismillah
      ids = layouts.filter_map { |_, mushaf| mushaf&.id }
      counts = MushafLineAlignment.where(mushaf_id: ids, alignment: ['bismillah', 'surah_name'])
        .group(:mushaf_id, :alignment).count
      rows = layouts.filter_map do |layout, mushaf|
        next unless mushaf

        bismillah = counts.fetch([mushaf.id, 'bismillah'], 0)
        surah_names = counts.fetch([mushaf.id, 'surah_name'], 0)
        [*named(layout), bismillah, surah_names] if bismillah * 2 < surah_names
      end
      Section.new('A bismillah line without an alignment row is drawn as a justified line of text.',
                  ['Id', 'Type', 'Resource', 'Bismillah lines', 'Surah name lines'], rows,)
    end

    def defaults_without_layout
      shown = layouts.filter_map { |_, mushaf| mushaf&.id }
      rows = Mushaf.where(is_default: true).where.not(id: shown).order(:id).map { |mushaf| [mushaf.id, mushaf.name] }
      Section.new('The recommended flag needs a default mushaf with a published layout, so no layout is ' \
                  'recommended for these.', ['Mushaf', 'Name'], rows,)
    end

    def tag_variants # rubocop:disable Metrics/AbcSize -- one query chain and one grouping
      used = DownloadableResourceTagging.where(downloadable_resource_id: published.map(&:id))
        .distinct.pluck(:downloadable_resource_tag_id)
      groups = DownloadableResourceTag.where(id: used).order(:name).group_by do |tag|
        tag.name.downcase.gsub(/[^[:alnum:]]/, '').delete_suffix('s')
      end
      rows = groups.values.select { |tags| tags.size > 1 }.map { |tags| [tags.map(&:name).join(', ')] }
      Section.new('Each set is one tag spelled more than one way.', ['Tags'], rows)
    end

    def named(resource)
      [resource.id, resource.resource_type, resource.display_name]
    end

    def table(columns, rows)
      lines = [columns, columns.map { '---' }, *rows].map do |cells|
        "| #{cells.map { |cell| cell.to_s.gsub(/[\\|]/) { "\\#{_1}" }.squish }.join(' | ')} |"
      end
      "#{lines.join("\n")}\n"
    end
  end
end
