ActiveAdmin.register_page 'Analytics' do
  menu priority: 1, label: 'Analytics', parent: 'Settings'

  content do
    now = Time.zone.now
    this_month_start = now.beginning_of_month
    last_month_start = 1.month.ago.beginning_of_month

    total_users = User.count
    confirmed_users = User.where.not(confirmed_at: nil).count
    confirmation_rate = total_users.positive? ? (confirmed_users * 100.0 / total_users).round(1) : 0

    signups_this_month = User.where(created_at: this_month_start..).count
    signups_last_month = User.where(created_at: last_month_start...this_month_start).count
    signup_mom = signups_last_month.positive? ? ((signups_this_month - signups_last_month) * 100.0 / signups_last_month).round(1) : nil

    total_downloads = UserDownload.sum(:download_count)
    new_downloads_this_month = UserDownload.where(created_at: this_month_start..).count
    unique_downloaders = UserDownload.distinct.count(:user_id)
    avg_downloads_per_user = unique_downloaders.positive? ? (total_downloads.to_f / unique_downloaders).round(1) : 0
    published_resources = DownloadableResource.published.count

    render_kpi = lambda do |number, label, sub = nil, sub_class = nil|
      div class: 'kpi-card' do
        span number.to_s, class: 'kpi-number'
        span label, class: 'kpi-label'
        span(sub, class: "kpi-sub #{sub_class}") if sub
      end
    end

    signup_sub = if signup_mom.nil?
                   'vs last month: n/a'
                 else
                   "#{signup_mom >= 0 ? '▲' : '▼'} #{signup_mom.abs}% vs last month"
                 end
    signup_sub_class = signup_mom.nil? ? nil : (signup_mom >= 0 ? 'up' : 'down')

    div class: 'kpi-row' do
      render_kpi.call(number_with_delimiter(total_users), 'Total users')
      render_kpi.call(number_with_delimiter(confirmed_users), 'Confirmed users', "#{confirmation_rate}% confirmed")
      render_kpi.call(number_with_delimiter(signups_this_month), 'Signups this month', signup_sub, signup_sub_class)
      render_kpi.call(number_with_delimiter(total_downloads), 'Total downloads')
      render_kpi.call(number_with_delimiter(new_downloads_this_month), 'New downloads this month')
      render_kpi.call(number_with_delimiter(unique_downloaders), 'Unique downloaders', "#{avg_downloads_per_user} avg / downloader")
      render_kpi.call(number_with_delimiter(published_resources), 'Published resources')
    end

    comparison_series = lambda do |klass, date_col|
      current_start = this_month_start - 11.months
      previous_start = current_start - 12.months

      current = klass.where(date_col => current_start..)
                     .group_by_month(date_col).count
                     .transform_keys { |k| k.to_date.beginning_of_month }
      previous = klass.where(date_col => previous_start...current_start)
                      .group_by_month(date_col).count
                      .transform_keys { |k| k.to_date.beginning_of_month }

      current_data = {}
      previous_data = {}
      (0..11).each do |i|
        current_month = (current_start + i.months).to_date.beginning_of_month
        previous_month = (previous_start + i.months).to_date.beginning_of_month
        label = current_month.strftime('%b')
        current_data[label] = current[current_month] || 0
        previous_data[label] = previous[previous_month] || 0
      end

      [
        { name: 'Last 12 months', data: current_data },
        { name: 'Previous 12 months', data: previous_data }
      ]
    end

    growth_caption = lambda do |series|
      current_total = series.first[:data].values.sum
      previous_total = series.last[:data].values.sum
      pct = previous_total.positive? ? ((current_total - previous_total) * 100.0 / previous_total).round(1) : nil
      change = if pct.nil?
                 'n/a'
               else
                 "#{pct >= 0 ? '▲' : '▼'} #{pct.abs}%"
               end

      div class: "analytics-caption #{pct && (pct >= 0 ? 'up' : 'down')}" do
        "Last 12 months: #{number_with_delimiter(current_total)} · Previous: #{number_with_delimiter(previous_total)} · #{change}"
      end
    end

    columns do
      column do
        panel 'Signup trends (12 months vs previous)' do
          series = comparison_series.call(User, :created_at)
          growth_caption.call(series)
          text_node line_chart(series)
        end
      end

      column do
        panel 'Download trends (12 months vs previous)' do
          series = comparison_series.call(UserDownload, :created_at)
          growth_caption.call(series)
          text_node line_chart(series)
        end
      end
    end

    panel 'Downloads by resource type (last 12 months)' do
      div class: 'analytics-caption' do
        'Counts new download records created per month, grouped by resource type.'
      end

      downloads_by_type_over_time = UserDownload
                                      .joins(downloadable_file: :downloadable_resource)
                                      .group('downloadable_resources.resource_type')
                                      .group_by_month('user_downloads.created_at', last: 12)
                                      .count

      text_node column_chart(downloads_by_type_over_time, stacked: true, height: '400px')
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

    columns do
      column do
        panel 'Download By Resource Type' do
          downloads_by_resource_type = DownloadableResource.joins(downloadable_files: :user_downloads)
                                                           .group(:resource_type)
                                                           .order('SUM(user_downloads.download_count) DESC')
                                                           .select('downloadable_resources.resource_type, SUM(user_downloads.download_count) AS total_downloads')

          chart_data = downloads_by_resource_type.map do |resource|
            [resource.resource_type, resource.total_downloads]
          end

          pie_chart chart_data, height: '400px', library: { title: { text: 'Download By Resource Type', x: -20, y: 30, align: 'center' } }
        end
      end

      column do
        panel 'Published downloadable resources by type' do
          column_chart DownloadableResource.published.group(:resource_type).order('count_all DESC').count, height: '400px'
        end
      end
    end

    panel 'Approved library content by type' do
      content_counts = {
        'Translations' => ResourceContent.translations.approved.count,
        'Tafsirs' => ResourceContent.tafsirs.approved.count,
        'Recitations' => ResourceContent.recitations.approved.count,
        'Transliterations' => ResourceContent.transliteration.approved.count,
        'Quran Scripts' => ResourceContent.quran_script.approved.count,
        'Morphology' => ResourceContent.morphology.approved.count,
        'Fonts' => ResourceContent.fonts.approved.count
      }

      column_chart content_counts, height: '350px'
    end
  end
end
