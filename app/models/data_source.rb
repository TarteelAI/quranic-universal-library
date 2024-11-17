# == Schema Information
#
# Table name: data_sources
#
#  id             :integer          not null, primary key
#  description    :text
#  name           :string
#  resource_count :integer          default(0)
#  url            :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class DataSource < QuranApiRecord
  has_many :resource_contents

  def update_resource_count
    update_column :resource_count, resource_contents.count
  end

  def grouped_resources_on_type
    resource_contents.order('name').group_by(&:sub_type)
  end
end
