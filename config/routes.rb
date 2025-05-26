Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  root to: 'landing#home'

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :chapters, only: [:index, :show] do
        member do
          get 'verses', to: 'verses#index', filter: 'by_chapter'
        end
      end

      get '/verses/select2', to: 'verses#select2'
    end
  end

  get 'tools', to: 'community#tools', as: :tools
  get 'docs/:key', to: 'community#docs', as: :docs
  get 'tools/help/:key', to: 'community#tool_help', as: :tools_help
  get 'community/chars_info', as: :chars_info
  get 'svg', to: 'community#svg_optimizer'
  get 'credits', to: 'community#credits', as: :credits
  get 'faq', to: 'community#faq', as: :faq
  get 'contributors', to: 'community#contributors', as: :contributors

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

  resources :morphology_phrases
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

  get '/ayah/:key', to: 'ayah#show', as: :ayah
  match '/404', to: 'application#not_found', via: :all
  #  match '*unmatched', to: 'application#not_found', via: :all
end
