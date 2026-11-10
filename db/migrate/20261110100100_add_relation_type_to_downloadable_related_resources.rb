# Every existing link gets the default relation type, `pairs_with`.
# Reversible: a rollback drops the column and its constraint.
class AddRelationTypeToDownloadableRelatedResources < ActiveRecord::Migration[8.0]
  def change
    add_column :downloadable_related_resources, :relation_type, :string, null: false, default: 'pairs_with'
    add_check_constraint :downloadable_related_resources,
                         "relation_type IN ('requires', 'pairs_with', 'alternative', 'supersedes')",
                         name: 'downloadable_related_resources_relation_type'
  end
end
