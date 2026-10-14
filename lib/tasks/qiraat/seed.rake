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

    desc 'Seed every riwayah reference table'
    task all: %i[reference riwayat]
  end
end
