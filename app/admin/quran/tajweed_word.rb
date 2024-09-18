ActiveAdmin.register TajweedWord do
  tajweed = TajweedRules.new('new')

  menu parent: 'Quran', priority: 3
  includes :word, :mushaf

  filter :text
  filter :rule_eq, as: :select, collection: tajweed.rules
  filter :word, as: :searchable_select,
         ajax: { resource: Word }

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

  controller do
    def find_resource
      collection = scoped_collection
                     .includes(
                       :word,
                       :mushaf
                     )

      if params[:id].to_s.include?(':')
        collection.find_by(location: params[:id]) || raise(ActiveRecord::RecordNotFound.new("Couldn't find TajweedWord with 'location'=#{params[:id]}"))
      else
        collection.find(params[:id])
      end
    end
  end

  show do
    attributes_table do
      row :id
      row :location
      row :word
      row :mushaf
      row :position

      row :text do
        div resource.text.to_s.html_safe, class: 'qpc-hafs quran-text', style: 'font-size: 50px', data: { controller: 'tajweed-highlight' }
      end

      row :v4_tajweed_image, class: 'quran-text' do
        div do
          image_tag resource.word.tajweed_v4_image_url
        end
      end

      row :uthmani_tajweed do
        div resource.word.text_uthmani_tajweed.to_s.html_safe, class: 'qpc-hafs quran-text', style: 'font-size: 50px', data: { controller: 'tajweed-highlight' }
      end

      row :rq_tajweed, class: 'quran-text' do
        s, a, w = resource.location.split(':')
        link_to "https://recitequran.com/#{s}:#{a}/w#{w}", target: '_blank' do
          image_tag resource.word.rq_tajweed_image_url
        end
      end

      row :context do
        word = resource.word
        previous_word = TajweedWord.where(word_id: word.previous_word.id).first  if word.previous_word
        next_word = TajweedWord.where(word_id: word.next_word.id).first  if word.next_word

        text = [previous_word, resource, next_word].compact_blank.map(&:text).join(' ').html_safe
        div text, class: 'qpc-hafs quran-text', style: 'font-size: 50px', data: { controller: 'tajweed-highlight' }
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

          tbody do
            resource.letters.each do |letter|
              tr do
                td letter['i'] + 1
                td tajweed.name(letter['r'])
                td do
                  div letter['c'], class: "qpc-hafs #{tajweed.name(letter['r'])}"
                end
              end
            end
          end
        end
      end
    end

    active_admin_comments

    ActiveAdminViewHelpers.diff_panel(self, resource) if params[:version]
  end

  index do
    id_column
    column :word
    column :text do |resource|
      div class: 'qpc-hafs', data: { controller: 'tajweed-highlight' } do
        resource.text.to_s.html_safe
      end
    end

    column :v4_image do |resource|
      image_tag resource.word.tajweed_v4_image_url
    end

    actions
  end
end
