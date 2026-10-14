# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CMS font samples (P5.4)', type: :request do
  before { sign_in_admin }

  it 'renders one row per unicode script with a font class, each word in its own class' do
    get '/cms/scripts/font_samples'
    expect(response).to have_http_status(:ok)
    body = response.body
    %w[qpc-hafs qpc-shuba qpc-warsh qpc-qaloun qpc-douri qpc-sousi qpc-bazzi].each do |css|
      expect(body).to include("class=\"#{css}\"")
    end
    expect(body).to include('id="script-qpc-warsh"')
    expect(body).not_to include('id="script-qpc-v1"') # glyph scripts have no unicode sample
    # the Warsh word 1:4:1 comes from word_texts, not the Hafs column
    warsh = Script.find_by!(slug: 'qpc-warsh')
    word = Word.find_by!(location: '1:4:1')
    expect(body).to include(word.text_for(warsh)) if word.text_for(warsh).present?
  end

  it 'links from the scripts index' do
    get '/cms/scripts'
    expect(response.body).to include('/cms/scripts/font_samples')
  end
end
