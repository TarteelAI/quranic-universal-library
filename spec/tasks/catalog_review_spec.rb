require 'clone_helper'
require_relative '../support/catalog_resources'
require 'rake'

# The data team's correction path this sprint: `catalog:mark_reviewed` and the review report.
RSpec.describe 'catalog review tasks' do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?('catalog:mark_reviewed') }

  before { Catalog::Backfill.run }

  def run_task(name, *args)
    Rake::Task[name].reenable
    Rake::Task[name].invoke(*args)
  end

  def drafted(resource)
    resource.reload.review.fetch('drafted', {})
  end

  def values(resource)
    resource.reload.attributes.slice(*CatalogFields::DRAFTED_FIELDS)
  end

  def links(resource)
    resource.downloadable_related_resources.reload.pluck(:related_resource_id, :relation_type)
  end

  describe 'catalog:mark_reviewed' do
    let(:layout) { resource_named('KFGQPC V2 layout (1421H print)') }

    it 'marks one field reviewed without changing any value, and the next backfill leaves both' do
      before_values = values(layout)
      expect(drafted(layout).keys).to include('rendering', 'script_family')

      expect { run_task('catalog:mark_reviewed', layout.slug, 'rendering') }.to output(/rendering/).to_stdout

      expect(drafted(layout)).not_to have_key('rendering')
      expect(drafted(layout)).to have_key('script_family')
      expect(values(layout)).to eq(before_values)

      Catalog::Backfill.run

      expect(drafted(layout)).not_to have_key('rendering')
      expect(values(layout)).to eq(before_values)
    end

    it 'marks every drafted value of a resource reviewed, links included, when no field is given' do
      before_values = values(layout)
      before_links = links(layout)

      expect { run_task('catalog:mark_reviewed', layout.id.to_s) }.to output.to_stdout
      Catalog::Backfill.run

      expect(drafted(layout)).to be_empty
      expect(values(layout)).to eq(before_values)
      expect(links(layout)).to match_array(before_links)
    end

    it 'refuses a field that is not drafted' do
      expect { run_task('catalog:mark_reviewed', layout.id.to_s, 'recommended') }
        .to raise_error(ArgumentError, /recommended/)
    end
  end

  describe 'catalog:review_report' do
    let(:path) { Rails.root.join('tmp/spec-catalog-review-report.md') }

    after { FileUtils.rm_f(path) }

    it 'writes one row per drafted value and a section for each known data error class' do
      expect { run_task('catalog:review_report', path.to_s) }.to output(/#{Regexp.escape(path.to_s)}/).to_stdout

      report = path.read
      entries = ApplicationRecord.connection.select_value(<<~SQL)
        SELECT count(*) FROM downloadable_resources, jsonb_object_keys(review->'drafted')
      SQL
      drafted_section = report[/^## Drafted values\n(.*?)(?=^## )/m, 1]
      rows = drafted_section.lines.grep(/\A\| \d/)
      expect(entries).to be > 100
      expect(rows.size).to eq(entries)

      Catalog::ReviewReport::DATA_ERRORS.each_key do |title|
        expect(report).to include("### #{title}")
      end
      expect(report).to include('catalog:mark_reviewed', 'bin/rails runner')
      expect(report).not_to match(/@\w/)
      resource_names = DownloadableResource.pluck(:name).join("\n")
      DataSource.pluck(:name).compact_blank.reject { |name| resource_names.include?(name) }
                .each { |name| expect(report).not_to include(name) }
    end

    it 'escapes backslashes as well as pipes in report cells, so a cell never splits or swallows a pipe' do
      table = Catalog::ReviewReport.new.send(:table, ['Value'], [['a|b'], ['c\\|d'], ['e\\']])

      expect(table.lines.drop(2)).to eq(["| a\\|b |\n", "| c\\\\\\|d |\n", "| e\\\\ |\n"])
    end

    it 'refuses a path outside tmp/' do
      expect { run_task('catalog:review_report', Rails.root.join('review.md').to_s) }
        .to raise_error(ArgumentError, %r{tmp/})
    end
  end
end
