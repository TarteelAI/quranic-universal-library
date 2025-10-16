Rails.application.routes.draw do
  # Redirect old admin paths to new CMS paths
  get '/admin', to: redirect('/cms', status: 301)
  get '/admin/*path', to: redirect(status: 301) { |params, _req| "/cms/#{params[:path]}" }

  ActiveAdmin.routes(self)

  root to: 'landing#home'

  namespace :api, defaults: { format: :json } do
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

        get 'ayah_recitations', to: 'recitations#ayah_recitations'
        get 'ayah_recitations/:id', to: 'recitations#ayah_recitation_detail'

        get 'surah_segments/:recitation_id', to: 'segments#surah_segments'
        get 'ayah_segments/:recitation_id', to: 'segments#ayah_segments'
      end

      get '/verses/select2', to: 'verses#select2'
    end
  end

  get 'tools', to: 'community#tools', as: :tools
  get '/ayah-boundaries', to: 'community#ayah_boundaries', as: :ayah_boundaries
  get 'docs/:key', to: 'community#docs', as: :docs
  get 'tools/help/:key', to: 'community#tool_help', as: :tools_help
  get 'community/chars_info', as: :chars_info
  get 'svg', to: 'community#svg_optimizer'
  get 'credits', to: 'community#credits', as: :credits
  get 'faq', to: 'community#faq', as: :faq
  get '/compare_ayah', to: 'verses#compare', as: :compare_ayah
  
  get 'arabic_transliterations/:surah_number/export', to: "arabic_transliterations#render_surah"
  get 'foot_notes/:id', to: "foot_notes#show"

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
  }

  authenticated :user, ->(user) { user.is_super_admin? || user.is_admin? } do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end

  resources :tajweed_words, except: [:new, :destroy]
  get 'tajweed_rule/:rule', to: 'tajweed_words#rule_doc', as: :tajweed_rule

  resources :morphology_phrases do
    member do
      get :phrase_verses
    end
  end

  namespace :morphology do
    get 'roots/:id', to: 'roots#show', as: :root
    get 'lemmas/:id', to: 'lemmas#show', as: :lemma
    get 'stems/:id', to: 'stems#show', as: :stem
  end

  resources :user_projects, except: [:index, :destroy]
  resources :resources do
    get '/:token/download', action: 'download' , as: :download_file

    member do
      get :copyright
    end

    collection do
      get '/:type/:id', action: 'detail', as: :detail
      get '/:type/:id/related_resources', action: 'related_resources', as: :related
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
      post :save_segments
    end

    collection do
      get :builder_help
    end
  end

  resources :mushaf_layouts, except: [:delete, :new] do
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
    end
  end

  resources :learning_activities, only: [:show, :index]
  resources :arabic_transliterations, except: :delete
  resources :word_text_proofreadings, only: [:index, :show] do
    collection do
      get :compare_words
    end
  end
  resources :translation_proofreadings, except: :delete
  resources :tafsir_proofreadings, except: :delete
  resources :word_translations, except: :delete do
    member do
      match :group_info, via: [:get, :post]
    end
  end
  resources :surah_infos, except: :delete do
    member do
      get :history
      get :changes
    end
  end
  resources :translation_diffs, only: [:index, :show]

  namespace :exports do
    get :word
    get :ayah
    get :mushaf_page
    get :mushaf
  end

  namespace :segments do
    get '/', to: 'dashboard#show', as: :dashboard
    get '/failures', to: 'dashboard#failures', as: :failures
    get '/word_failures', to: 'dashboard#word_failures', as: :word_failures
    get '/word_failure_detail', to: 'dashboard#word_failure_detail', as: :word_failure_detail
    get '/detections', to: 'dashboard#detections', as: :detections
    get '/logs', to: 'dashboard#logs', as: :logs
    get '/reciters', to: 'dashboard#reciters', as: :reciters
    get '/reciters/:id', to: 'dashboard#reciter', as: :reciter
    get '/timeline', to: 'dashboard#timeline', as: :timeline
    get '/ayah_report', to: 'dashboard#ayah_report', as: :ayah_report
    get '/review_ayahs', to: 'dashboard#review_ayahs', as: :review_ayahs
    post '/reciters/:id/download', to: 'dashboard#download_reciter', as: :download_reciter
    match '/setup_db', to: 'dashboard#setup_db', via: [:get, :post], as: :setup_db
  end

  get '/ayah/:key', to: 'ayah#show', as: :ayah
  match '/404', to: 'application#not_found', via: :all
  #  match '*unmatched', to: 'application#not_found', via: :all
end
