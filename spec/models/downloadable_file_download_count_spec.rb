require 'clone_helper'
require_relative '../support/download_files'

# Concurrent downloads from separate connections, so these examples commit their rows instead of
# running inside the example's transaction, and delete them afterwards.
RSpec.describe DownloadableFile, '#count_download' do
  include DownloadFiles

  self.use_transactional_tests = false

  let!(:file) { create_download_file(create_download_resource) }
  let!(:users) { [create_account, create_account] }

  after do
    blob_id = file.file.blob.id
    file.user_downloads.delete_all
    ActiveStorage::Attachment.where(record: file).delete_all
    ActiveStorage::Blob.where(id: blob_id).delete_all
    file.delete
    file.downloadable_resource.delete
    User.where(id: users.map(&:id)).delete_all
  end

  # Runs the block in `count` threads at once, each on its own connection.
  def concurrently(count, &block)
    ready = Queue.new
    start = Queue.new
    threads = Array.new(count) do |i|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          block.call(i)
        end
      end
    end
    count.times { ready.pop }
    count.times { start << true }
    threads.each(&:join)
  end

  it 'counts every one of many concurrent signed-in downloads, by one user and by two' do
    concurrently(4) { |i| 5.times { DownloadableFile.find(file.id).count_download(users[i % 2]) } }
    concurrently(2) { 5.times { DownloadableFile.find(file.id).count_download(users.first) } }

    rows = file.user_downloads.group(:user_id).pluck(:user_id, Arel.sql('COUNT(*)'), Arel.sql('SUM(download_count)'))
    expect(rows).to contain_exactly([users.first.id, 1, 20], [users.last.id, 1, 10])
    expect(file.reload.download_count).to eq(30)
  end

  it 'counts every one of many concurrent anonymous downloads, and keeps them through signed-in ones' do
    concurrently(4) { |i| 5.times { DownloadableFile.find(file.id).count_download(i.even? ? nil : users.first) } }

    file.reload
    expect(file.anonymous_download_count).to eq(10)
    expect(file.download_count).to eq(10)
    expect(file.total_download_count).to eq(20)
    expect(file.user_downloads.count).to eq(1)
  end
end
