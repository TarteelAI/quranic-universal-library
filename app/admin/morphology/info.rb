# frozen_string_literal: true

ActiveAdmin.register_page 'Morphology Info' do
  menu parent: 'Morphology', priority: 1, label: 'Info & Concepts'

  content title: 'Morphology & Grammar Datasets' do
    render "admin/morphology/docs"
  end
end
