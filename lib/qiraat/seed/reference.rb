# frozen_string_literal: true

require 'json'

module Qiraat
  module Seed
    # Loads counting_systems and qiraat from the pinned qiraat-ayah-map files.
    # Idempotent: rows are matched by slug and updated in place.
    #
    #   Qiraat::Seed::Reference.new(dir: Rails.root.join('tmp/qiraat/upstream/qiraat-ayah-map/data')).call
    class Reference
      # The canonical order of the ten qiraat as listed in qiraat.json.
      QIRAAT_ORDER = %w[nafi ibn-kathir abu-amr ibn-amir asim hamza kisai abu-jafar yaqub khalaf].freeze

      attr_reader :dir, :report

      def initialize(dir:)
        @dir = Pathname(dir)
        @report = { counting_systems: 0, qiraat: 0 }
      end

      def call
        seed_counting_systems
        seed_qiraat
        report
      end

      private

      def read(name)
        JSON.parse(dir.join(name).read)
      end

      def seed_counting_systems
        read('counting-systems.json').each do |slug, attrs|
          row = CountingSystem.find_or_initialize_by(slug: slug)
          row.assign_attributes(
            name_ar: attrs['name_ar'],
            name_en: attrs['name_en'],
            total_ayahs: attrs['total_ayahs'],
            is_reference: attrs['is_reference'] == true,
            description_ar: attrs['description_ar'],
            description_en: attrs['description_en']
          )
          row.save!
          report[:counting_systems] += 1
        end
      end

      def seed_qiraat
        systems = CountingSystem.all.index_by(&:slug)
        read('qiraat.json').each do |slug, attrs|
          system = systems.fetch(attrs['counting_system_associated_with_qari']) do
            raise "qiraat.json: #{slug} names unknown counting system #{attrs['counting_system_associated_with_qari']}"
          end
          row = Qiraah.find_or_initialize_by(slug: slug)
          row.assign_attributes(
            name_ar: attrs['name_ar'],
            name_en: attrs['name_en'],
            counting_system: system,
            position: QIRAAT_ORDER.index(slug)&.+(1)
          )
          row.save!
          report[:qiraat] += 1
        end
      end
    end
  end
end
