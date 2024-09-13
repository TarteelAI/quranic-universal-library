# frozen_string_literal: true

ActiveAdmin.register_page 'Data Integrity Check' do
  menu false

  content do
    check_name = params[:check_name].to_s
    title, description, check = nil

    if Tools::DataIntegrityChecks.valid_check?(check_name)
      checker_klass = Tools::DataIntegrityChecks
    elsif Tools::TajweedRulesCheck.valid_check?(check_name)
      checker_klass = Tools::TajweedRulesCheck
    end

    if checker_klass
      check = checker_klass.send(check_name)
      title = check[:name]
      description = check[:description]
      instructions = check[:instructions]

      klass = check[:check]
      data = klass.call(params)
      stats = {}
    else
      title = 'Results'
      description = "Sorry <b>#{check_name}</b> is not a valid check".html_safe
      instructions = []
    end

    panel title do
      div description.to_s.html_safe, class: 'py-2'
      div data[:error], class: 'alert alert-info' if data.is_a?(Hash) && data[:error].present?

      if instructions.present?
        div "<strong>Usage</strong> <div>#{instructions.join('<br>')}</div>".html_safe, class: 'alert alert-dark'
      end

      if check
        if check[:fields].present?
          div do
            render partial: 'admin/data_integrity_check_filters', locals: { check: check, check_name: check_name }
          end
        end

        div do
          # Results
          if data.is_a?(Hash)
            stats = data.except(:collection)
            data = data[:collection]
          end

          table_columns = check[:table_attrs]
          attrs_links = check[:links_proc] || {}
          sort_order = params[:sort_order].presence == 'asc' ? 'desc' : 'asc'
          sort_by = params[:sort_by].presence.to_s.downcase
          check_name = params[:check_name]
          per_page = params[:per_page].presence

          if stats.present?
            div do
              stats.each do |k, v|
                span "<strong>#{k.to_s.humanize}</strong>: #{v} |".html_safe
              end
            end
          end

          table border: true do
            thead do
              table_columns.each do |attr|
                th do
                  link_attrs = params.except(:controller, :action, :commit).permit!.to_h
                  link_to(attr, link_attrs.merge(
                    { per_page: per_page,
                      sort_by: attr,
                      sort_order: sort_by == attr.downcase ? sort_order : 'asc'
                    }
                  ))
                end
              end
            end

            tbody do
              tr do
                td colspan: table_columns.size do
                  if check[:paginate] == false
                    "Total: #{data.count}"
                  else
                    paginated_collection(data)
                  end
                end
              end

              data.each do |record|
                tr do
                  table_columns.each do |attr|
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
