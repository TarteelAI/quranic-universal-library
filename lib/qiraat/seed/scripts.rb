# frozen_string_literal: true

module Qiraat
  module Seed
    # Registers every Hafs script QUL already has as a scripts row (P3.1).
    #
    # Each entry names the words/verses column the text lives in, the CSS
    # class QUL renders it with (from QuranScriptHelper and the admin forms)
    # and, where QUL publishes it, the matching resource_contents rows by
    # their meta_data "text-type". Idempotent: matched by slug.
    class Scripts
      HAFS_COLUMN_SCRIPTS = [
        # slug, name, column, kind, css class, meta
        # family / compare_position / charset_position: the scripts comparison tool's Madani and Indopak lists (P7.2)
        ['qpc-hafs', 'KFGQPC Hafs (unicode)', 'text_qpc_hafs', 'unicode', 'qpc-hafs', { publisher_font_family: 'KFGQPC HAFS Uthmanic Script', family: 'madani', compare_position: 1, charset_position: 1 }],
        ['qpc-hafs-tajweed', 'KFGQPC Hafs, tajweed tagged', 'text_qpc_hafs_tajweed', 'unicode', 'qpc-hafs-color', { tagged: true }],
        ['uthmani-tajweed', 'Uthmani, tajweed tagged', 'text_uthmani_tajweed', 'unicode', 'tajweed-new qpc-hafs', { tagged: true }],
        ['uthmani', 'Uthmani (me_quran)', 'text_uthmani', 'unicode', 'me_quran', { family: 'madani', compare_position: 4, charset_position: 2 }],
        ['uthmani-simple', 'Uthmani simple', 'text_uthmani_simple', 'unicode', 'me_quran', { simplified: true }],
        ['imlaei', 'Imlaei', 'text_imlaei', 'unicode', 'qpc-hafs', {}],
        ['imlaei-simple', 'Imlaei simple', 'text_imlaei_simple', 'unicode', 'qpc-hafs', { simplified: true }],
        ['indopak', 'Indopak (pdms-saleem)', 'text_indopak', 'unicode', 'indopak', { family: 'indopak', compare_position: 3, charset_position: 3 }],
        ['indopak-nastaleeq', 'Indopak nastaleeq', 'text_indopak_nastaleeq', 'unicode', 'indopak-nastaleeq', { family: 'indopak', compare_position: 4, charset_position: 4 }],
        ['indopak-misbah', 'Indopak Misbah', 'text_indopak_misbah', 'unicode', 'misbah-font', { family: 'indopak', compare_position: 6, charset_position: 6 }],
        ['qpc-nastaleeq', 'QPC nastaleeq', 'text_qpc_nastaleeq', 'unicode', 'qpc-nastaleeq', {}],
        ['qpc-nastaleeq-hafs', 'QPC nastaleeq (Hafs)', 'text_qpc_nastaleeq_hafs', 'unicode', 'qpc-nastaleeq', { family: 'indopak', compare_position: 2, charset_position: 2 }],
        ['digitalkhatt', 'Digital Khatt v2', 'text_digital_khatt', 'unicode', 'digitalkhatt-v2', { family: 'madani', compare_position: 3, charset_position: 3 }],
        ['digitalkhatt-v1', 'Digital Khatt v1', 'text_digital_khatt_v1', 'unicode', 'digitalkhatt', { family: 'madani', compare_position: 6, charset_position: 4 }],
        ['digitalkhatt-indopak', 'Digital Khatt Indopak', 'text_digital_khatt_indopak', 'unicode', 'digitalkhatt-indopak', { family: 'indopak', compare_position: 1, charset_position: 1 }],
        ['indonesian-sign-language', 'Indonesian sign language', 'text_indonesian_sign_language', 'unicode', 'arabic-sign-font', { family: 'indopak', compare_position: 5, charset_position: 5 }],
        ['qpc-v1', 'QPC v1 glyph codes (1405H print)', 'code_v1', 'glyph', 'p{page}-v1', { css_pattern: 'p{page}-v1', page_column: 'page_number', family: 'madani', compare_position: 5 }],
        ['qpc-v2', 'QPC v2 glyph codes (1421H print)', 'code_v2', 'glyph', 'p{page}-v2', { css_pattern: 'p{page}-v2', page_column: 'v2_page', family: 'madani', compare_position: 2 }],
        ['qpc-v4-tajweed', 'QPC v4 tajweed glyph codes', 'code_v2', 'glyph', 'p{page}-v4-tajweed', { css_pattern: 'p{page}-v4-tajweed', page_column: 'v2_page', alias_of: 'code_v4', family: 'madani', compare_position: 7 }],
        ['tajweed-images-new', 'Tajweed images (new)', 'qa_tajweed_image_url', 'image', nil, { word_method: true }],
        ['tajweed-images-old', 'Tajweed images (old)', 'rq_tajweed_image_url', 'image', nil, { word_method: true }],
        ['black-images', 'Black images', 'qa_black_image_url', 'image', nil, { word_method: true }]
      ].freeze

      attr_reader :report

      def initialize
        @report = { created: 0, updated: 0, linked: 0 }
      end

      def call
        hafs = Riwayah.hafs
        HAFS_COLUMN_SCRIPTS.each do |slug, name, column, kind, css, meta|
          row = Script.find_or_initialize_by(slug: slug)
          report[row.new_record? ? :created : :updated] += 1
          row.assign_attributes(
            name: name, riwayah: hafs, kind: kind, storage: 'column', column_name: column,
            font_css_class: css, font_family: (css && kind != 'glyph' ? css.split.last : nil),
            meta_data: row.meta_data.merge(meta.stringify_keys)
          )
          link_resources(row, column, meta)
          row.save!
        end
        report
      end

      private

      def link_resources(row, column, meta)
        # An aliased script (v4 tajweed shares the code_v2 column) links only the
        # resources published under its own text-type.
        text_types = meta[:alias_of] ? [meta[:alias_of]] : [column]
        scope = ResourceContent.quran_script.where("meta_data->>'text-type' IN (?)", text_types)
        word = scope.where(cardinality_type: ResourceContent::CardinalityType::OneWord).order(:id).first
        ayah = scope.where(cardinality_type: ResourceContent::CardinalityType::OneVerse).order(:id).first
        row.word_resource_content_id ||= word&.id
        row.ayah_resource_content_id ||= ayah&.id
        report[:linked] += [word, ayah].compact.size
      end
    end
  end
end
