Rails.application.routes.draw do
  ActiveAdmin.routes(self)

  unauthenticated do
    root to: 'landing#home'
  end

  authenticated :user do
    root to: 'community#tools', as: :authenticated_root
  end

  get 'tools', to: 'community#tools', as: :tools
  get 'community/chars_info', as: :chars_info
  get 'svg', to: 'community#svg_optimizer'

  get 'arabic_transliterations/:surah_number/export', to: "arabic_transliterations#render_surah"
  get 'foot_notes/:id', to: "foot_notes#show"


  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }

  authenticated :user, ->(user) { user.super_admin? } do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end

  resources :morphology_phrases
  resources :downloads

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

  resources :arabic_transliterations, except: :delete
  resources :proof_read_comments
  resources :word_translations, except: :delete
  resources :word_text_proofreadings, only: [:index, :show]
  resources :wbw_texts, except: :delete
  resources :translation_proofreadings, except: :delete
  resources :tafsir_proofreadings, except: :delete
  resources :surah_infos, except: :delete do
    member do
      get :history
      get :changes
    end
  end
end
