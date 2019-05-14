# == Schema Information
#
# Table name: extraction_forms_projects_section_types
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  deleted_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class ExtractionFormsProjectsSectionType < ApplicationRecord
  acts_as_paranoid
  has_paper_trail

  has_many :extraction_forms_projects_sections, dependent: :destroy, inverse_of: :extraction_forms_projects_section_type

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
