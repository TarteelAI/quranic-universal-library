# Anonymous downloads of a file (download mode `public`), counted apart from `download_count`,
# which DownloadableFile#track_download recomputes from the per-user rows. Existing rows start
# at 0, so every file's combined total is unchanged. Reversible: a rollback drops the column.
class AddAnonymousDownloadCountToDownloadableFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :downloadable_files, :anonymous_download_count, :integer, null: false, default: 0
  end
end
