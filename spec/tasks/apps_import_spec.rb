# frozen_string_literal: true

require 'clone_helper'
require 'rake'

# `apps:import`: the entries of config/apps.yml become published App rows, keyed on the entry id.
RSpec.describe 'apps:import' do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?('apps:import') }

  let(:entries) { AppDirectory.data.fetch('apps') }

  def import
    task = Rake::Task['apps:import']
    task.reenable
    expect { task.invoke }.to output(/rows created/).to_stdout
  end

  def snapshot
    App.order(:id).map { |app| [app.attributes, app.icon.blob&.checksum] }
  end

  it 'creates one published row per entry, with its fields and icon' do
    expect { import }.to change(App, :count).by(entries.size)

    entries.each do |entry|
      app = App.find_by!(import_key: entry['id'])
      expect(app).to have_attributes(
        name: entry['name'], url: entry['url'], platforms: entry['platforms'], uses: entry['uses'],
        kind: entry['kind'], description: entry['description'], evidence: entry['evidence'],
        featured: entry.fetch('featured', false), published: true, user: nil, contact: nil,
      )
      expect(app.icon.attached?).to eq(entry.key?('icon')), entry['id']
    end
    quranwbw = App.find_by!(import_key: 'quranwbw')
    expect(quranwbw.icon.blob).to have_attributes(
      content_type: 'image/png', filename: ActiveStorage::Filename.new('icon.png'),
      byte_size: File.size(AppDirectory::ICONS_DIR.join('quranwbw.png')),
    )
    expect(App.where.not(import_key: nil).order(:id).pluck(:import_key)).to eq(entries.pluck('id'))
  end

  it 'changes nothing the second time, and keeps an edit made between the runs' do
    import
    edited = App.find_by!(import_key: 'quranwbw')
    edited.update!(name: 'QuranWBW (edited)', featured: false, description: 'Edited by an editor.')
    before = snapshot

    expect { import }.not_to change(App, :count)

    expect(snapshot).to eq(before)
    expect(edited.reload).to have_attributes(name: 'QuranWBW (edited)', featured: false,
                                             description: 'Edited by an editor.',)
  end

  it 'leaves submissions alone' do
    submission = App.create!(name: 'A submission', url: 'https://example.test/app', platforms: ['web'],
                             uses: ['translation'],)

    import

    expect(submission.reload).to have_attributes(import_key: nil, published: false)
  end
end
