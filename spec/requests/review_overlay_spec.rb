# frozen_string_literal: true

require 'clone_helper'

RSpec.describe 'Review overlay script tag (staging builds)', type: :request do
  let(:script_url) { 'https://overlay.example.test/overlay.js' }
  let(:keys) { ['REVIEW_OVERLAY_SCRIPT', 'REVIEW_OVERLAY_DROP', 'GIT_SHA'] }

  around do |example|
    original = keys.index_with { |key| ENV.fetch(key, nil) }
    keys.each { |key| ENV[key] = settings[key] }
    example.run
  ensure
    original.each { |key, value| ENV[key] = value }
  end

  def overlay_scripts
    Nokogiri::HTML(response.body).css("head script[src='#{script_url}']")
  end

  shared_examples 'a layout with the review overlay' do |path|
    context 'with the settings' do
      let(:settings) do
        { 'REVIEW_OVERLAY_SCRIPT' => script_url, 'REVIEW_OVERLAY_DROP' => 'review-1', 'GIT_SHA' => 'abc123' }
      end

      it 'writes one deferred script tag with the review and the build' do
        get path

        expect(response).to have_http_status(:ok)
        expect(overlay_scripts.size).to eq(1)
        expect(overlay_scripts.first.attributes.transform_values(&:value)).to eq(
          'src' => script_url, 'data-drop' => 'review-1', 'data-build' => 'abc123',
          'defer' => 'defer',
        )
      end
    end

    context 'without the settings' do
      let(:settings) { {} }

      it 'writes no tag' do
        get path

        expect(response).to have_http_status(:ok)
        expect(overlay_scripts).to be_empty
        expect(response.body).not_to include('data-build')
      end
    end
  end

  describe 'the new pages (inertia layout)', page_groups: ['catalog'] do
    it_behaves_like 'a layout with the review overlay', '/resources/translation'
  end

  describe 'the old pages (application layout)', page_groups: [] do
    it_behaves_like 'a layout with the review overlay', '/resources/translation'
  end
end
