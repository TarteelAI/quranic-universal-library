# frozen_string_literal: true

ActiveAdmin.register_page 'Data Integrity Check' do
  menu false

  content do
    check_name = params[:check_name].to_s
    title, description, check = nil

    if Tools::DataIntegrityChecks.valid_check?(check_name)
      check = Tools::DataIntegrityChecks.send(check_name)
      title = check[:name]
      description = check[:description]
    else
      title = 'Results'
      description = "Sorry <b>#{check_name}</b> is not a valid check".html_safe
    end

    panel title do
      div description

      if check
        if check[:fields].present?
          div do
            render partial: 'admin/data_intergity_check_filters', locals: { check: check, check_name: check_name }
          end
        end

        div do
          # Results
          klass = check[:check]
          data = klass.call(params)
          attrs = check[:table_attrs]
          attrs_links = check[:links_proc] || {}
          sort_order = params[:sort_order].presence == 'asc' ? 'desc' : 'asc'
          sort_by = params[:sort_by].presence.to_s.downcase
          check_name = params[:check_name]
          per_page = params[:per_page].presence

          table border: true do
            thead do
              attrs.each do |attr|
                th do
                  link_to(attr, { per_page: per_page, check_name: check_name, sort_by: attr, sort_order: sort_by == attr.downcase ? sort_order : 'asc' })
                end
              end
            end

            tbody do
              tr do
                td colspan: attrs.size do
                  if check[:paginate] == false
                    "Total: #{data.count}"
                  else
                    paginated_collection(data)
                  end
                end
              end

              data.each do |record|
                tr do
                  attrs.each do |attr|
                    td do
                      if attrs_links[attr.to_sym]
                        text, url = attrs_links[attr.to_sym].call(record, params)

                        if url
                          link_to text, url, target: '_blank'
                        else
                          text
                        end
                      else
                        record.send(attr)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
