ActiveAdmin.register_page 'Analytics' do
  menu priority: 1, label: 'Analytics', parent: 'Settings'

  content do
    columns do
      column do
        panel 'Signup trends' do
          line_chart User.group_by_month(:created_at).count
        end
      end

      column do
        panel 'Download trends' do
          line_chart UserDownload.group_by_month(:created_at).count
        end
      end
    end

    columns do
      column do
        panel 'Top 50 Users with Most Downloads' do
          top_users = User.joins(:user_downloads)
                          .group('users.id')
                          .order('SUM(user_downloads.download_count) DESC')
                          .limit(50)
                          .select('users.id, users.first_name, SUM(user_downloads.download_count) AS total_downloads')

          latest_downloads = {}
          top_users.each do |user|
            latest_downloads[user.id] = UserDownload
                                          .eager_load(:downloadable_file)
                                          .where(user_id: user.id)
                                          .order('user_downloads.created_at DESC')
                                          .first
          end

          table_for top_users do
            column 'User Name' do |user|
              link_to user.first_name, cms_user_path(user.id)
            end

            column 'Total Downloads' do |user|
              user.total_downloads
            end

            column 'Last Downloaded Resource' do |user|
              latest_downloads[user.id]&.downloadable_file.name || 'No downloads yet'
            end

            column 'Last Downloaded At' do |user|
              latest_downloads[user.id] ?  l(latest_downloads[user.id].created_at) : 'No downloads yet'
            end
          end
        end
      end

      column do
        panel 'Top 50 downloaded resources' do
          top_downloaded_resources = DownloadableResource.joins(downloadable_files: :user_downloads)
                                                         .group('downloadable_resources.id')
                                                         .order('SUM(user_downloads.download_count) DESC')
                                                         .limit(50)
                                                         .select('downloadable_resources.name, downloadable_resources.id as resource_id, SUM(user_downloads.download_count) as total_downloads')

          table_for top_downloaded_resources do
            column 'Resource Name' do |resource|
              link_to resource.name, cms_downloadable_resource_path(resource.resource_id)
            end

            column 'Download Count' do |resource|
              resource.total_downloads
            end
          end
        end
      end
    end

    panel 'Download By Resource Type' do
      downloads_by_resource_type = DownloadableResource.joins(downloadable_files: :user_downloads)
                                                       .group(:resource_type)
                                                       .order('SUM(user_downloads.download_count) DESC')
                                                       .select('downloadable_resources.resource_type, SUM(user_downloads.download_count) AS total_downloads')

      chart_data = downloads_by_resource_type.map do |resource|
        [resource.resource_type, resource.total_downloads]
      end

      pie_chart chart_data, height: "400px", library: { title: { text: "Download By Resource Type", x: -20, y: 30, align: 'center' } }
    end
  end
end
