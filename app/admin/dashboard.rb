# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Dashboard'

  content title: 'Dashboard' do
    div "Welcome to the QUL Admin Dashboard! ", class: 'alert alert-info'

    columns do
      column do
        panel 'Help' do
          render partial: 'admin/help'
        end
      end
    end

    columns do
      if can? :run_actions, :from_admin
        column do
          panel 'Actions' do
            render partial: 'admin/actions'
          end
        end
      end
    end

    columns do
      if can?(:download, :from_admin)
        column do
          panel 'Export Quran words as SQLite DB' do
            render partial: 'admin/export_words_db'
          end
        end

        column do
          panel 'Export ayah audio file segments' do
            render partial: 'admin/export_ayah_segments_db'
          end
        end

        column do
          panel 'Export Mushaf Layouts' do
            render partial: 'admin/export_mushaf_layouts_db'
          end
        end
      end
    end

    columns do
      column do
        panel 'Data Integrity checks' do
          div "This section includes various tools designed to ensure data integrity across the QUL resources. These tools help identify inconsistencies, missing data, and other potential issues within the dataset. Regularly running these checks helps us detect and resolve data issues effectively.", class: 'alert alert-info'

          div do
            Tools::DataIntegrityChecks.checks.each do |check_name|
              check = Tools::DataIntegrityChecks.send(check_name)
              div class: 'fs-lg p-3 d-flex border-bottom' do
                div do
                  div(check[:name])
                  small(check[:description].to_s.html_safe)
                end

                span link_to('Go', "/admin/data_integrity_check?check_name=#{check_name}"), class: 'ms-auto'
              end
            end
          end
        end
      end
    end

    columns do
      column do
        panel 'Tajweed rules' do
          div "This section includes tools to find words with a specific tajweed rule", class: 'alert alert-info'

          div do
            Tools::TajweedRulesCheck.checks.each do |check_name|
              check = Tools::TajweedRulesCheck.send(check_name)

              div class: 'fs-lg p-3 d-flex border-bottom' do
                div do
                  div(check[:name].to_s.html_safe)
                  small(check[:description].to_s.html_safe)
                end

                span link_to('Go', "/admin/data_integrity_check?check_name=#{check_name}"), class: 'ms-auto'
              end
            end
          end
        end
      end
    end if false

    div class: 'blank_slate_container', id: 'dashboard_default_message' do
      heading = "Recent changes (Total #{PaperTrail::Version.count}) #{link_to 'View all changes', '/admin/content_changes'}".html_safe
      panel heading do
        table_for PaperTrail::Version.order('id desc').limit(20) do
          # Use PaperTrail::Version if this throws an error
          column('ID') { |v| link_to v.id, "/admin/content_changes/#{v.id}" }
          column('Item', &:item_type)
          column('Event', &:event)
          column('Modified at') { |v| v.created_at.to_s :long }
          column('User') do |v|
            if (user = GlobalID::Locator.locate(v.whodunnit))
              link_to "#{user.name}(#{user.email})", [:admin, user]
            end
          end
        end
      end
    end
  end
end
