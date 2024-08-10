# frozen_string_literal: true

ActiveAdmin.register NavigationSearchRecord do
  searchable_select_options(
    scope: NavigationSearchRecord,
    text_attribute: :humanize,
    filter: lambda do |term, scope|
      scope.ransack(
        key_cont: term,
        name_cont: term,
        result_type_cont: term,
        text_cont: term,
        m: 'or'
      ).result
    end
  )

  menu parent: 'Settings', priority: 1
  actions :all, except: :destroy

  filter :result_type
  filter :searchable_record_type
  filter :key

  permit_params do
    %i[result_type searchable_record_type searchable_record_id key text]
  end

  form do |f|
    f.inputs do
      f.input :text
      f.input :result_type, as: :select, collection: NavigationSearchRecord.pluck(:result_type).uniq
      f.input :searchable_record_id
    end

    f.actions
  end
end
