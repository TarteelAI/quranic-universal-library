# Seed the riwayah reference tables from the pinned upstream files.
#
#   rake qiraat:fetch            # first, so tmp/qiraat/upstream is present and verified
#   rake qiraat:seed:reference   # counting_systems and qiraat (idempotent, matched by slug)
namespace :qiraat do
  namespace :seed do
    desc 'Seed counting_systems and qiraat from qiraat-ayah-map data/'
    task reference: :environment do
      dir = Rails.root.join('tmp', 'qiraat', 'upstream', 'qiraat-ayah-map', 'data')
      abort "#{dir} missing; run rake qiraat:fetch" unless dir.join('qiraat.json').exist?
      report = Qiraat::Seed::Reference.new(dir: dir).call
      puts "counting_systems: #{report[:counting_systems]} upserted (#{CountingSystem.count} total)"
      puts "qiraat: #{report[:qiraat]} upserted (#{Qiraah.count} total)"
      Qiraah.all.each { |q| puts format('  %-2d %-11s %-16s -> %s', q.position, q.slug, q.name_en, q.counting_system.slug) }
    end

    desc 'Seed the twenty riwayat from qiraat-ayah-map data/qiraat.json, keeping legacy qirat_types ids'
    task riwayat: :environment do
      dir = Rails.root.join('tmp', 'qiraat', 'upstream', 'qiraat-ayah-map', 'data')
      abort "#{dir} missing; run rake qiraat:fetch" unless dir.join('qiraat.json').exist?
      report = Qiraat::Seed::Riwayat.new(dir: dir).call
      Riwayah.hafs.update!(enabled: true) # the one riwayah the app serves today
      puts "riwayat: matched #{report[:matched]} legacy rows, created #{report[:created]}, deleted #{report[:deleted]} (#{Riwayah.count} total)"
      Riwayah.order(:id).each { |r| puts format('  %-3d %-14s %-18s %-10s %s%s', r.id, r.slug, r.name_en, r.qiraah&.slug, r.enabled ? 'enabled' : '', r.unverified? ? ' UNVERIFIED' : '') }
    end

    desc 'Register the existing Hafs scripts (text columns, glyph codes, image sets) as scripts rows'
    task scripts: :environment do
      report = Qiraat::Seed::Scripts.new.call
      puts "scripts: created #{report[:created]}, updated #{report[:updated]}, resource links #{report[:linked]} (#{Script.count} total)"
      Script.order(:id).each { |s| puts format('  %-3d %-26s %-8s %-8s %-30s %-24s wbw=%-5s ayah=%s', s.id, s.slug, s.kind, s.storage, s.column_name, s.font_css_class, s.word_resource_content_id, s.ayah_resource_content_id) }
    end

    desc 'Register the text already in quran_script_by_verses/by_words as legacy scripts'
    task legacy_scripts: :environment do
      report = Qiraat::Seed::LegacyScripts.new.call
      puts "legacy scripts: created #{report[:created]}, updated #{report[:updated]}"
      report[:scripts].each { |slug, ayah_rc, word_rc| puts format('  %-34s ayah rc=%-5s word rc=%s', slug, ayah_rc, word_rc) }
    end

    desc 'Seed every riwayah reference table'
    task all: %i[reference riwayat scripts legacy_scripts]

    # The translations the word-by-word tool showed beside the words were a
    # case on language id in WordTranslationsController (P6.4 moved it to
    # data): flag those resources so the tool keeps showing the same ones.
    WBW_REFERENCE_TRANSLATIONS = {
      174 => [54, 97],        # Urdu
      185 => [109, 56],       # Chinese (traditional, zhuyin, pinyin, simplified shared the list)
      195 => [109, 56], 196 => [109, 56], 197 => [109, 56],
      175 => [55, 127, 101],  # Uzbek
      38 => [131, 203],       # English
      20 => [380, 213]        # Bengali
    }.freeze

    desc 'Flag the reference translations the word-by-word tool shows (meta_data wbw-reference), idempotent'
    task wbw_reference_translations: :environment do
      ids = WBW_REFERENCE_TRANSLATIONS.values.flatten.uniq
      ResourceContent.where(id: ids).find_each do |rc|
        next if rc.meta_data.to_h['wbw-reference'] == 'yes'

        rc.meta_data = rc.meta_data.to_h.merge('wbw-reference' => 'yes')
        rc.save!(validate: false)
        puts "  flagged #{rc.id} #{rc.name} (#{rc.language_name})"
      end
      missing = ids - ResourceContent.where(id: ids).pluck(:id)
      puts "  not found: #{missing.inspect}" if missing.any?
      puts "wbw-reference: #{ResourceContent.wbw_reference.count} resources flagged"
    end
  end
end
