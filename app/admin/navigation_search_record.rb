# frozen_string_literal: true

# == Schema Information
#
# Table name: navigation_search_records
#
#  id                     :bigint           not null, primary key
#  key                    :string
#  name                   :string
#  result_type            :string
#  searchable_record_type :string
#  text                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  searchable_record_id   :bigint
#
# Indexes
#
#  index_navigation_search_records_on_result_type        (result_type)
#  index_navigation_search_records_on_searchable_record  (searchable_record_type,searchable_record_id)
#  index_navigation_search_records_on_text               (text)
#
ActiveAdmin.register NavigationSearchRecord do
  searchable_select_options(scope: NavigationSearchRecord,
                            text_attribute: :humanize,
                            filter: lambda do |term, scope|
                              scope.ransack(
                                key_cont: term,
                                name_cont: term,
                                result_type_cont: term,
                                text_cont: term,
                                m: 'or'
                              ).result
                            end)

  menu parent: 'Settings', priority: 1
  actions :all, except: :destroy

  filter :result_type
  filter :searchable_record_type
  filter :key

  permit_params do
    %i[result_type searchable_record_type searchable_record_id key text]
  end

  form do |f|
    f.inputs  do
      f.input :text
      f.input :result_type, as: :select, collection: NavigationSearchRecord.pluck(:result_type).uniq
      f.input :searchable_record_id
    end

    f.actions
  end
end
