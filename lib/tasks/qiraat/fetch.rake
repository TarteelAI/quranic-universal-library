# Fetch the upstream data the riwayah import tasks read, at pinned versions.
#
#   rake qiraat:fetch            # download every file in config/qiraat_sources.yml
#                                # into tmp/qiraat/upstream/ and verify its SHA-256
#   rake qiraat:fetch[quran-text] # one source only
#   rake qiraat:pin              # download and WRITE the SHA-256 of each file back
#                                # into the YAML (used once when bumping a version)
#
# Files are skipped when already present with the right checksum, so the task
# is cheap to re-run. A checksum mismatch aborts: the upstream file changed
# under the pinned reference, and the import must not run on it unverified.
require 'digest'
require 'fileutils'
require 'open-uri'
require 'yaml'

namespace :qiraat do
  SOURCES_PATH = Rails.root.join('config', 'qiraat_sources.yml')
  UPSTREAM_DIR = Rails.root.join('tmp', 'qiraat', 'upstream')

  def qiraat_sources
    YAML.safe_load(File.read(SOURCES_PATH), aliases: true)
  end

  def qiraat_sha256(path)
    Digest::SHA256.file(path).hexdigest
  end

  def qiraat_download(url, dest)
    FileUtils.mkdir_p(File.dirname(dest))
    tmp = "#{dest}.part"
    URI.parse(url).open('rb', read_timeout: 600, open_timeout: 60) do |remote|
      File.open(tmp, 'wb') { |f| IO.copy_stream(remote, f) }
    end
    FileUtils.mv(tmp, dest)
  end

  # Yields [source_key, source, file_entry, local_path, url] for every file.
  def qiraat_each_file(only = nil)
    qiraat_sources['sources'].each do |key, src|
      next if only && key != only

      src['files'].each do |file|
        local = UPSTREAM_DIR.join(key, file['path'])
        url = src['base_url'].sub('{ref}', src['ref'].to_s) + file['path'].split('/').map { |s| URI::DEFAULT_PARSER.escape(s) }.join('/')
        url = file['url'] if file['url']
        yield key, src, file, local, url
      end
    end
  end

  desc 'Download pinned upstream data into tmp/qiraat/upstream and verify checksums'
  task :fetch, [:only] => :environment do |_t, args|
    ok = 0
    bad = []
    qiraat_each_file(args[:only]) do |key, _src, file, local, url|
      expected = file['sha256']
      if File.exist?(local) && expected && qiraat_sha256(local) == expected
        ok += 1
        next
      end
      puts "fetch #{key}/#{file['path']}"
      qiraat_download(url, local)
      actual = qiraat_sha256(local)
      if expected.nil?
        bad << "#{key}/#{file['path']}: no sha256 pinned (run rake qiraat:pin)"
      elsif actual != expected
        bad << "#{key}/#{file['path']}: sha256 #{actual} != pinned #{expected}"
      else
        ok += 1
      end
    end
    puts "#{ok} file(s) verified"
    abort("Checksum problems:\n  " + bad.join("\n  ")) if bad.any?
  end

  desc 'Download upstream data and write each file SHA-256 into config/qiraat_sources.yml'
  task :pin, [:only] => :environment do |_t, args|
    data = qiraat_sources
    qiraat_each_file(args[:only]) do |key, _src, file, local, url|
      qiraat_download(url, local) unless File.exist?(local)
      sha = qiraat_sha256(local)
      entry = data['sources'][key]['files'].find { |f| f['path'] == file['path'] }
      entry['sha256'] = sha
      entry['size_bytes'] = File.size(local)
      puts "#{key}/#{file['path']} #{sha[0, 12]} #{File.size(local)}"
    end
    header = File.read(SOURCES_PATH).lines.take_while { |l| l.start_with?("#") }.join
    File.write(SOURCES_PATH, header + data.to_yaml.sub(/\A---\n/, ""))
    puts "wrote #{SOURCES_PATH}"
  end
end
