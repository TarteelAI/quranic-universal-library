# == Schema Information
#
# Table name: log_entries
#
#  id           :bigint           not null, primary key
#  chapter      :string
#  font         :string
#  language     :string
#  path         :text
#  recitation   :string
#  referrer     :string
#  search_query :string
#  status       :string
#  tafsir       :string
#  time         :datetime
#  translations :string
#  verse_key    :string
#  verse_range  :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_log_entries_on_font          (font)
#  index_log_entries_on_recitation    (recitation)
#  index_log_entries_on_tafsir        (tafsir)
#  index_log_entries_on_translations  (translations)
#
class LogEntry < ApplicationRecord
end
