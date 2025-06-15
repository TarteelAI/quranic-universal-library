module ActiveAdminViewHelpers
  class << self
    def compare_panel(context, resource)
      context.panel 'Changes' do
        compare_with = resource.versions[context.params[:compare].to_i].reify

        context.attributes_table_for resource do
          resource.attributes.each do |key, val|
            context.row key do
              diff = Diffy::SplitDiff.new(compare_with.send(key).to_s, val.to_s, format: :html, allow_empty_diff: false)

              if diff
                "Old <br/> #{diff.left} <br/> New #{diff.right}".html_safe
              else
                val
              end
            end
          end
        end
      end
    end

    def diff_panel(context, resource)
      context.panel 'Changes diff for this version' do
        if version = resource.versions[context.params[:version].to_i]
          version_object = version.reify
          next_version = version_object.paper_trail.next_version

          context.attributes_table_for version_object do
            version_object.attributes.each do |key, val|
              context.row key do
                diff = Diffy::SplitDiff.new(val.to_s, next_version.send(key).to_s, format: :html, allow_empty_diff: false)

                if diff
                  "Old <br/> #{diff.left} <br/> New #{diff.right}".html_safe
                else
                  val
                end
              end
            end
          end
        else
          p "Sorry, can't find this version"
        end
      end
    end

    def versionate(context)
      context.controller do
        def original_resource
          scoped_collection.find(params[:id])
        end

        def find_resource
          if params[:version].to_i > 0
            item = scoped_collection.includes(:versions).find(params[:id])
            version = item.versions[params[:version].to_i]
            version ? version.reify : original_resource
          else
            original_resource
          end
        end
      end

      context.sidebar "Versions", only: :show do
        div do
          h2 "Current version #{link_to resource.versions.size}".html_safe

          table do
            thead do
              td :version
              td :changes
              td :created_at
              td :user
              td :actions
            end

            tbody do
              (resource.versions.size - 1).downto(0) do |index|
                version = resource.versions[index]
                tr do
                  td link_to index, version: version.index
                  td link_to index, "/cms/content_changes/#{version.id}"
                  td version.created_at
                  td GlobalID::Locator.locate(version.whodunnit).try(:humanize)
                  td do
                    link_to 'Compare', url_for(compare: version.index)
                  end
                end
              end
            end
          end
        end
      end
    end

    def render_navigation_search_sidebar(context)
      context.sidebar "Navigation Search Variations", only: :show do
        if can?(:manage, NavigationSearchRecord)
          div do
            render 'admin/navigation_search_form'
          end
        end

        table do
          thead do
            td :id
            td :text
          end

          tbody do
            resource.navigation_search_records.each do |record|
              tr do
                td link_to(record.id, [:cms, record])
                td record.text
              end
            end
          end
        end
      end
    end

    def render_translated_name_sidebar(context)
      context.sidebar "Translated names", only: :show do
        if can?(:manage, TranslatedName)
          div do
            render 'admin/translated_names'
          end
        end

        table do
          thead do
            td :id
            td :language
            td :name
          end

          tbody do
            resource.translated_names.each do |translated_name|
              tr do
                td link_to(translated_name.id, [:cms, translated_name])
                td translated_name.language_name
                td translated_name.name
              end
            end
          end
        end
      end
    end

    def render_slugs(context)
      context.sidebar 'Slugs', only: :show do
        if can?(:manage, Slug)
          div do
            semantic_form_for [:cms, Slug.new] do |form|
              form.input(:chapter_id, as: :hidden, input_html: { value: resource.id }) +
                form.inputs(:slug, :locale) +
                form.actions(:submit)
            end
          end
        end

        table do
          thead do
            td :id
            td :slug
            td :locale
          end

          tbody do
            resource.slugs.each do |slug|
              tr do
                td slug.id
                td slug.slug
                td slug.locale
              end
            end
          end
        end
      end
    end
  end
end
