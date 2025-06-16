# frozen_string_literal: true

ActiveAdmin.register QuranTableDetail do
  menu parent: 'Settings', priority: 1
  filter :name

  show do
    attributes_table do
      row :id
      row :name
      row :enteries
      row :created_at
      row :updated_at
    end

    if params[:record_id]
      panel 'Record Detail' do
        record = resource.load_record(params[:record_id])

        attributes_table_for(record) do
          record.attributes.each do |key, _val|
            row key do
              record.send(key).to_s.html_safe
            end
          end
        end
      end
    else
      panel 'Table Preview' do
        enteries = resource.load_table(params[:page] || 0, 30)
        fields = QuranTable.column_names

        table do
          thead do
            fields.each do |c|
              td c
            end
          end

          tbody do
            enteries.each do |entry|
              tr do
                td do
                  link_to 'Show', "/cms/quran_table_details/#{resource.id}?record_id=#{entry.id}", target: '_blank'
                end

                fields.each do |column|
                  td truncate(entry.read_attribute(column).to_s, length: 250)
                end
              end
            end

            tr do
              td paginated_collection(enteries)
            end

            nil
          end
        end
      end
    end
  end
end
