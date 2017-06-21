class ExtractionFormsProjectsSection < ApplicationRecord
  include SharedOrderableMethods
  include SharedProcessTokenMethods
  include SharedParanoiaMethods

  acts_as_paranoid column: :active, sentinel_value: true
  has_paper_trail

  before_validation -> { set_ordering_scoped_by(:extraction_forms_project_id) }

  belongs_to :extraction_forms_project, inverse_of: :extraction_forms_projects_sections
  belongs_to :extraction_forms_projects_section_type, inverse_of: :extraction_forms_projects_sections
  belongs_to :section, inverse_of: :extraction_forms_projects_sections

  has_one :ordering, as: :orderable, dependent: :destroy

  has_many :key_questions_projects, dependent: :nullify, inverse_of: :extraction_forms_projects_section
  has_many :key_questions, through: :key_questions_projects, dependent: :destroy

  has_many :questions, dependent: :destroy, inverse_of: :extraction_forms_projects_section

  validates :ordering, presence: true

  def section_id=(token)
    process_token(token, :section)
    super
  end
end
