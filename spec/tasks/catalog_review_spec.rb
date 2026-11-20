# frozen_string_literal: true

require 'clone_helper'
require_relative '../support/catalog_resources'
require 'rake'

# The data team's list of known data errors: the review report.
RSpec.describe 'catalog review report task' do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?('catalog:review_report') }

  def run_task(name, *args)
    Rake::Task[name].reenable
    Rake::Task[name].invoke(*args)
  end

  describe 'catalog:review_report' do
    let(:path) { Rails.root.join('tmp', 'spec-catalog-review-report.md') }

    after { FileUtils.rm_f(path) }

    it 'writes a section for each known data error class and names the override keys' do
      expect do
        run_task('catalog:review_report', path.to_s)
      end.to output(/#{Regexp.escape(path.to_s)}: \d+ rows/).to_stdout

      report = path.read
      expect(report).not_to include('Drafted', 'mark_reviewed')
      expect(report.lines.grep(/\A\| \d/)).not_to be_empty
      Catalog::ReviewReport::DATA_ERRORS.each_key do |title|
        expect(report).to include("### #{title}")
      end
      expect(report).to include(*Catalog::Derived::OVERRIDES.values.map { |key| "`#{key}`" })
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
