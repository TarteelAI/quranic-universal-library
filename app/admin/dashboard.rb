# frozen_string_literal: true

ActiveAdmin.register_page 'Dashboard' do
  menu priority: 1, label: 'Dashboard'

  content title: 'Dashboard' do
    columns do
      column do
        panel 'Actions' do
          render partial: 'admin/actions'
        end
      end

      column do
        panel 'Export Word as SQLite DB' do
          render partial: 'admin/export_words_db'
        end
      end
    end

    columns '<h1>Tools</h1>'.html_safe do
      column do
        panel 'Data Integrity checks' do
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
      panel "Recent changes (Total #{PaperTrail::Version.count}) #{link_to 'View all changes',
                                                                           '/admin/content_changes'}".html_safe do
        table_for PaperTrail::Version.order('id desc').limit(20) do
          # Use PaperTrail::Version if this throws an error
          column('ID') { |v| link_to v.id, "/admin/content_changes/#{v.id}" }
          column('Item', &:item_type)
          column('Event', &:event)
          column('Modified at') { |v| v.created_at.to_s :long }
          column('User') do |v|
            if (user = GlobalID::Locator.locate(v.whodunnit))
              link_to "#{user.email} (#{user.class})", [:admin, user]
            elsif(admin=AdminUser.find_by(id: v.whodunnit))
              link_to(admin.email, [:admin, admin])
            end
          end
        end
      end
    end
  end
end
