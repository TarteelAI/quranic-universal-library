module ActiveAdmin
  module Comments
    module Views
      class Comments < ActiveAdmin::Views::Panel
        def build_comment(comment)
          div for: comment do
            div class: 'active_admin_comment_meta' do
              user_name = comment.author ? link_to(comment.author.name, [:admin, comment.author]) : 'Anonymous'
              h4(user_name, class: 'active_admin_comment_author')
              span(pretty_format(comment.created_at))
            end

            div class: 'active_admin_comment_body' do
              simple_format(comment.body)
            end

            div do
              span link_to('Show', "/admin/active_admin_comments/#{comment.id}")
              span link_to('Edit', "/admin/active_admin_comments/#{comment.id}/edit")
            end
          end
        end
      end
    end
  end
end
