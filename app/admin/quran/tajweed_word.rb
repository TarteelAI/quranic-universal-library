ActiveAdmin.register TajweedWord do
  menu parent: 'Quran', priority: 3

  searchable_select_options(
    scope: TajweedWord,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        location_cont: term,
        m: 'or'
      ).result
    end
  )

  show do
    attributes_table do
      row :id
      row :location
      row :word
      row :mushaf
      row :position

      row :text do
        div resource.text.to_s.html_safe, class: 'qpc-hafs quran-text', style: 'font-size: 50px', data: {controller: 'tajweed-highlight'}
      end

      row :v4_tajweed_image, class: 'quran-text' do
        div do
          image_tag resource.word.tajweed_v4_image_url
        end
      end

      row :uthmani_tajweed do
        div resource.word.text_uthmani_tajweed.to_s.html_safe, class: 'qpc-hafs quran-text', style: 'font-size: 50px', data: {controller: 'tajweed-highlight'}
      end

      row :rq_tajweed,  class: 'quran-text' do
        s,a,w = resource.location.split(':')
        link_to "https://recitequran.com/#{s}:#{a}/w#{w}", target: '_blank' do
          image_tag resource.word.rq_tajweed_image_url
        end
      end

      row :created_at
      row :updated_at
      row :rules do
        table do
          thead do
            th :char_index
            th :rule
            th :preview
          end
        end
      end
    end

    active_admin_comments

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end
end
