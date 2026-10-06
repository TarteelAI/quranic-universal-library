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
  end
end
