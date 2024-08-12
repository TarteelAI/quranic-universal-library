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
      if can? :admin, :run_actions
        column do
          panel 'Actions' do
            # render partial: 'admin/actions'
          end
        end
      end

      if can? :admin, :export_words
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
      end
    end

    columns do
      column do
        panel 'Data Integrity checks' do
          div "This section has various tools for checking data integrity, such as finding words that don't have translations for specific languages.", class: 'alert alert-info'

          div do
            Tools::DataIntegrityChecks.checks.each do |check_name|
              check = Tools::DataIntegrityChecks.send(check_name)
              div class: 'fs-lg' do
                span(check[:name])
                span link_to('Go', "/admin/data_integrity_check?check_name=#{check_name}")
              end
            end
          end
        end
      end
    end

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
