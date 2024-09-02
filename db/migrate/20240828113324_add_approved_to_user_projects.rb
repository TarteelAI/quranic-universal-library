class AddApprovedToUserProjects < ActiveRecord::Migration[7.0]
  def change
    add_column :user_projects, :approved, :boolean, default: false
    add_column :user_projects, :additional_notes, :text
    add_column :user_projects, :reason_for_request, :text

    add_column :user_projects, :language_proficiency, :text
    add_column :user_projects, :motivation_and_goals, :text
    add_column :user_projects, :review_process_acknowledgment, :boolean
  end
end
