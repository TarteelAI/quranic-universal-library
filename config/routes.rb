# frozen_string_literal: true

Rails.application.routes.draw do
  # Redirect old admin paths to new CMS paths
  get '/admin', to: redirect('/cms', status: 301)
  get '/admin/*path', to: redirect(status: 301) { |params, _req| "/cms/#{params[:path]}" }

  ActiveAdmin.routes(self)

  # The new home page while the `home` page group is on (PageGroups); the old landing page otherwise.
  constraints(PageGroups.constraint(:home)) do
    root to: 'site/home#show', as: :home_page
  end
  root to: 'landing#home'
  # The new FAQ, credits, tools overview, changelog, docs index and docs pages while the `content`
  # page group is on, above the old routes below, and the docs search index (JSON) the new pages
  # fetch. The old /change_logs URLs redirect to the changelog, on the same entries. The docs pages
  # answer page loads and Inertia visits only (Content::DocsRequest): the old pages' help dialogs
  # keep the old answer.
  # The two constraints are nested blocks because a `constraints:` option on the route would
  # replace the group's constraint instead of adding to it.
  constraints(PageGroups.constraint(:content)) do
    get '/faq', to: 'content/pages#faq', as: :faq_page, format: false
    get '/credits', to: 'content/pages#credits', as: :credits_page, format: false
    get '/tools', to: 'content/pages#tools', as: :tools_page, format: false
    get '/changelog', to: 'content/changelog#index', as: :changelog_page, format: false
    get '/changelog/:id', to: 'content/changelog#show', as: :changelog_entry_page, format: false,
                          constraints: { id: /\d+/ }
    get '/change_logs', format: false, to: redirect(status: 301) { |_params, request|
      Content::Changelog.path_for_old_page(request.query_parameters['page'])
    }
    get '/change_logs/:id', to: redirect(status: 301) { |params, _request| "/changelog/#{params[:id]}" },
                            format: false, constraints: { id: /\d+/ }
    get '/docs/search-index', to: 'content/docs_search#index', as: :docs_search_index, format: false
    constraints(Content::DocsRequest) do
      get '/docs', to: 'content/docs#index', as: :docs_index_page, format: false
      get '/docs/:key', to: 'content/docs#show', as: :docs_page, format: false
    end
  end

  get '/search', to: 'search#index', as: :search

  get '/health', to: 'health#show'

  namespace :api, defaults: { format: :json } do
    namespace :morphology do
      resources :edge_relations, only: [:index]
    end

    namespace :v1 do
      resources :chapters, only: [:index, :show] do
        member do
          get 'verses', to: 'verses#index', filter: 'by_chapter'
        end
      end

      namespace :audio do
        get 'surah_recitations', to: 'recitations#surah_recitations'
        get 'surah_recitations/:id', to: 'recitations#surah_recitation_detail'
        get 'surah_recitations/:id/wav_manifest', to: 'recitations#wav_manifest'
        get 'surah_recitations/:id/transcript', to: 'transcripts#surah_transcript'

        get 'ayah_recitations', to: 'recitations#ayah_recitations'
        get 'ayah_recitations/:id', to: 'recitations#ayah_recitation_detail'

        get 'surah_segments/:recitation_id', to: 'segments#surah_segments'
        get 'ayah_segments/:recitation_id', to: 'segments#ayah_segments'
      end

      scope 'resources' do
        get '/translations', to: 'resources#translations'
        get '/tafsirs', to: 'resources#tafsirs'
        get '/recitations', to: 'resources#recitations'
        get '/ayah_recitations', to: 'resources#ayah_recitations'
        get '/surah_recitations', to: 'resources#surah_recitations'
        get '/languages', to: 'resources#languages'
      end

      get 'unicode/name', to: 'unicode#name'

      get 'tafsirs/random', to: 'tafsirs#random'
      get 'tafsirs/for_ayah/:ayah_key', to: 'tafsirs#for_ayah'
      get 'tafsirs/:resource_id/by_range', to: 'tafsirs#by_range'

      get 'translations/random', to: 'translations#random'
      get 'translations/for_ayah/:ayah_key', to: 'translations#for_ayah'
      get 'translations/:resource_id/by_range', to: 'translations#by_range'

      get '/verses/select2', to: 'verses#select2'
    end
  end

  get 'tools', to: 'community#tools', as: :tools
  get :quran_scripts_comparison, to: 'quran_scripts_comparison#compare_words', as: :compare_words_quran_scripts_comparison
  get 'compare-audio', to: 'community#compare_audio', as: :compare_audio
  get 'compare-font', to: 'community#compare_font', as: :compare_font
  get 'gapless-ayah-extractor', to: 'community#gapless_ayah_extractor', as: :gapless_ayah_extractor
  get 'docs', to: 'community#docs_index', as: :docs_index
  get 'docs/:key', to: 'community#docs', as: :docs
  get 'tools/help/:key', to: 'community#tool_help', as: :tools_help
  get 'community/chars_info', as: :chars_info

  get :svg, to: 'community#svg_optimizer'
  get :credits, to: 'community#credits', as: :credits
  get :faq, to: 'community#faq', as: :faq
  get :compare_ayah, to: 'verses#compare', as: :compare_ayah

  get 'arabic_transliterations/:surah_number/export', to: 'arabic_transliterations#render_surah'
  get 'foot_notes/:id', to: 'foot_notes#show'

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions',
  }

  resource :profile, only: [:show, :edit, :update]

  authenticated :user, ->(user) { user.is_super_admin? || user.is_admin? } do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end

  resources :tajweed_words, except: [:new, :destroy]
  get 'tajweed_rule/:rule', to: 'tajweed_words#rule_doc', as: :tajweed_rule

  resources :morphology_phrases do
    member do
      get :phrase_verses
      get :detect
      get :ayahs
      patch :review_ayah
    end

    collection do
      post :merge
    end
  end

  namespace :morphology do
    get 'roots/:id', to: 'roots#show', as: :root
    get 'lemmas/:id', to: 'lemmas#show', as: :lemma
    get 'stems/:id', to: 'stems#show', as: :stem
    get 'word', to: 'words#show', as: :word

    get 'grammar/:category/:term', to: 'grammar_terms#show', as: :grammar_term

    resources :dependency_graphs, path: 'dependency-graphs', only: [:index, :show, :edit] do
      member do
        get :syntax_graph
        get :verse_graphs_data
        post :split
      end

      resources :nodes, controller: 'dependency_graph_nodes', only: [:create, :update, :destroy] do
        member do
          post :fields
        end
      end

      resources :edges, controller: 'dependency_graph_edges', only: [:create, :update, :destroy]
    end

    get 'treebank', to: 'treebank#index', as: :treebank_index
    get 'treebank/:chapter/:verse', to: 'treebank#show', as: :treebank_ayah,
                                    constraints: { chapter: /\d+/, verse: /\d+/ }
    get 'treebank/:chapter/:verse/data', to: 'treebank#data', as: :treebank_ayah_data,
                                         constraints: { chapter: /\d+/, verse: /\d+/ }
  end

  resources :user_projects, except: [:index, :destroy]
  resources :change_logs, only: [:index, :show]

  # New pages (app/frontend) for the page groups listed in QUL_PAGE_GROUPS (PageGroups). These
  # routes must stay above the old ones for the same paths: when a group is off, its constraint
  # fails and the old route below answers.
  constraints(PageGroups.constraint(:catalog)) do
    # The guided setup's results: the catalog with the setup's answers in the query string
    # (GuidedSetup), while the `start` group is on too.
    constraints(PageGroups.constraint(:start)) do
      constraints(->(request) { request.query_parameters.key?('goal') }) do
        get '/resources', to: 'start/setup#results', as: :start_results, format: false
      end
    end
    get '/resources', to: 'catalog/resources#index', as: :catalog_resources, format: false
    get '/resources/:type', to: 'catalog/types#show', as: :catalog_type, format: false
    # The old copyright and tab URLs answer with the resource page.
    get '/resources/:slug/copyright', to: 'catalog/resources#copyright', format: false
    get '/resources/:type/:slug', to: 'catalog/resources#show', as: :catalog_resource, format: false
    get '/resources/:type/:slug/preview', to: 'catalog/previews#show', as: :catalog_resource_preview, format: false
    # The bundle tray's lookup (JSON): the bundle's resource ids as the catalog shows them now.
    get '/bundle', to: 'catalog/bundles#show', as: :catalog_bundle, format: false
    get '/resources/:type/:slug/:tab', to: 'catalog/resources#tab', format: false,
                                       constraints: { tab: /docs|licence|ligatures|glyphs/ }
  end
  # The guided setup and the starter kits have no old page: with the `start` group off, they are 404s.
  constraints(PageGroups.constraint(:start)) do
    get '/start', to: 'start/setup#show', as: :start_setup, format: false
    get '/kits', to: 'start/kits#index', as: :start_kits, format: false
    get '/kits/:key', to: 'start/kits#show', as: :start_kit, format: false
  end
  constraints(PageGroups.constraint(:apps)) do
    get '/apps', to: 'site/apps#index', as: :apps_directory, format: false
    post '/apps', to: 'site/app_submissions#create', as: :app_submissions, format: false
  end
  # Resource requests have no old page: with the `requests` group off, these are 404s.
  constraints(PageGroups.constraint(:requests)) do
    post '/requests', to: 'requests/requests#create', as: :resource_requests, format: false
    post '/requests/:id/vote', to: 'requests/requests#vote', as: :resource_request_vote, format: false,
                               constraints: { id: /\d+/ }
    delete '/requests/:id/vote', to: 'requests/requests#unvote', format: false, constraints: { id: /\d+/ }
  end
  # The spotlight's search results (JSON), for every new page whatever the groups.
  get '/spotlight', to: 'catalog/spotlight#index', as: :catalog_spotlight, format: false
  # File downloads, whatever the groups. The token path is the old download URL, declared again
  # here so it reaches the same download rules before the old route below.
  get '/resources/:type/:slug/download/:file_id', to: 'catalog/downloads#show', as: :catalog_download,
                                                  constraints: { file_id: /\d+/ }, format: false
  get '/resources/:type/:token/download', to: 'catalog/downloads#token', as: :catalog_token_download

  resources :resources do
    get '/:token/download', action: 'download', as: :download_file

    member do
      get :copyright
    end

    collection do
      get '/:type/:id', action: 'detail', as: :detail
      get '/:type/:id/related_resources', action: 'related_resources', as: :related
      get '/:type/:id/:tab', action: 'detail', as: :detail_tab, constraints: { tab: /docs|licence|ligatures|glyphs/ }
    end
  end

  resources :ayah_audio_files do
    member do
      get :segment_builder
      get :segments
      post :save_segments
    end
  end

  resources :surah_audio_files do
    member do
      get :segment_builder
      get :segments
      get :letter_segments
      post :save_segments
      post :validate_segments
    end

    collection do
      get :builder_help
    end
  end

  resources :mushaf_layouts, except: [:destroy, :new] do
    member do
      put :save_page_mapping
      put :save_line_alignment
    end
  end

  resources :word_concordance_labels, only: [:show, :index] do
    member do
      get :word_detail
      get :segment_detail
      put :update_segment
      put :update_word
    end
  end

  resources :learning_activities, only: [:show, :index]
  resources :arabic_transliterations, except: :destroy
  resources :word_texts, only: [:index, :show] do
    collection do
      get :compare_words
    end
  end
  resources :translations, except: :destroy
  resources :transliterations, except: :destroy
  resources :word_transliterations, only: [:index, :show, :edit, :update]
  resources :tafsirs, except: :destroy do
    get :range_preview, on: :collection
  end
  resources :topics, only: [:index, :show, :edit, :update]
  # ayah_theme is taken by /ayah/:key/theme
  resources :themes, path: 'ayah_themes', controller: 'ayah_themes', only: [:index, :show, :edit, :update]
  # root is the home page
  resources :arabic_roots, path: 'roots', controller: 'roots', only: [:index, :show, :edit, :update]
  resources :stems, only: [:index, :show, :edit, :update]
  resources :lemmas, only: [:index, :show, :edit, :update]
  resources :word_roots, only: [:index, :show, :edit, :update] do
    get :options, on: :collection
  end
  resources :similar_ayahs, only: [:index, :show, :edit, :update]
  resources :word_translations, except: :destroy do
    collection do
      get :select_resource
    end
    member do
      match :group_info, via: [:get, :post]
    end
  end

  resources :surah_infos, except: :destroy
  resources :translation_diffs, only: [:index, :show]

  namespace :exports do
    get :word
    get :ayah
    get :mushaf_page
    get :mushaf
  end

  if Rails.application.config.x.qul_scripts_available
    namespace :segment_pipeline do
      get '/', to: 'runs#index', as: :root
      # Validate segments of any reciters/surahs: live, drafts, sources, runs.
      get 'validation', to: 'validations#show', as: :validation
      # QUD deliveries imported as drafts that have no QUL recitation yet.
      resources :deliveries, only: [:index, :show] do
        collection do
          get :search_recitations
        end
        member do
          post :attach
          post :create_recitation
          post :dismiss
          delete :drafts, action: :destroy_drafts
        end
      end
      get 'reciters/:recitation_id', to: 'runs#show', as: :reciter
      get 'reciters/:recitation_id/status', to: 'runs#status', as: :reciter_status
      get 'reciters/:recitation_id/runs/:chapter_id', to: 'runs#run', as: :run
      post 'reciters/:recitation_id/generate_all', to: 'runs#generate_all', as: :generate_all
      post 'reciters/:recitation_id/import_all', to: 'runs#import_all', as: :import_all
      post 'reciters/:recitation_id/review_all_drafts', to: 'runs#review_all_drafts', as: :review_all_drafts
      post 'reciters/:recitation_id/cleanup', to: 'runs#cleanup', as: :reciter_cleanup
      scope 'reciters/:recitation_id/chapters/:chapter_id' do
        post 'generate', to: 'runs#generate', as: :generate
        post 'rerun_step', to: 'runs#rerun_step', as: :rerun_step
        post 'cancel', to: 'runs#cancel', as: :cancel
        post 'build_drafts', to: 'runs#stage_drafts', as: :build_drafts
        post 'cleanup', to: 'runs#cleanup_chapter', as: :cleanup_chapter
        post 'import', to: 'runs#import_drafts', as: :import
        post 'drafts/review', to: 'runs#review_drafts', as: :review_drafts
        post 'drafts/:id/review', to: 'runs#review_draft', as: :review_draft
        post 'ayah_boundary', to: 'runs#update_ayah_boundary', as: :ayah_boundary
        get 'artifact', to: 'runs#artifact', as: :artifact
        get 'audio', to: 'runs#audio', as: :audio
        get 'surah_timeline', to: 'runs#surah_timeline', as: :surah_timeline
        get 'compare_data', to: 'runs#compare_data', as: :compare_data
      end
    end

    namespace :audio_repair do
      resources :sessions, only: [:index, :create, :edit] do
        member do
          get :data
          get :candidates
          get :audition
          get :peaks
          get :letters
          get :vowel_donors
          post :vowel_preview
          post :match
          get :status
          post :preview
          post :add_operation
          post :undo
          post :redo
          post :export
          post :compare
          get :comparison
          get :comparison_zoom
        end
      end

      resources :polarity, only: [:index, :create, :show] do
        member { post :fix }
      end

      resources :ingests, only: [:index, :create, :show, :destroy] do
        collection { get :preview }
        member do
          get :data
          post :download
          post :retry_item
          post :update_settings
          post :update_source
          post :upload
          post :encode_selected
          post :cleanup
          # One surah within the run, addressed by item_id.
          get :item
          get :audio
          get :peaks
          post :detect
          post :approve
          post :encode
          get :surah
          get :surah_data
          post :reencode
          post :polarity_check
        end
      end
      root to: 'sessions#index'
    end

    namespace :manifest_diff do
      get '/', to: 'comparisons#index', as: :root
      get ':group/:id', to: 'comparisons#asset', as: :asset
      get ':group/:id/surahs/:surah', to: 'comparisons#surah', as: :surah
    end
  end

  get '/ayah/:key', to: 'ayah#show', as: :ayah
  get '/ayah/:key/text', to: 'ayah#text', as: :ayah_text
  get '/ayah/:key/translations', to: 'ayah#translations', as: :ayah_translations
  get '/ayah/:key/tafsirs', to: 'ayah#tafsirs', as: :ayah_tafsirs
  get '/ayah/:key/words', to: 'ayah#words', as: :ayah_words
  get '/ayah/:key/theme', to: 'ayah#theme', as: :ayah_theme
  get '/ayah/:key/transliteration', to: 'ayah#transliteration', as: :ayah_transliteration
  get '/ayah/:key/topics', to: 'ayah#topics', as: :ayah_topics
  get '/ayah/:key/topics/:topic_id', to: 'ayah#topic', as: :ayah_topic
  get '/ayah/:key/recitation', to: 'ayah#recitation', as: :ayah_recitation

  get 'mistake-heatmap', to: 'word_mistakes#show', as: 'mistake_heatmap'
  put 'mistake-heatmap', to: 'word_mistakes#update'
  get 'mistake-heatmap/edit', to: 'word_mistakes#edit', as: 'edit_mistake_heatmap'
  get 'mistake-heatmap/:id', to: 'word_mistakes#word_details', as: 'mistake_heatmap_word_details'

  # QUL_INERTIA_SAMPLE_PAGE=true also adds the development-only Inertia sample page to a locally
  # run production image.
  if Rails.env.local? || ENV['QUL_INERTIA_SAMPLE_PAGE'] == 'true'
    namespace :dev, path: '__dev' do
      resource :inertia_sample, only: [:show, :create] do
        get :ping
      end
    end
  end

  match '/404', to: 'application#not_found', via: :all
end
