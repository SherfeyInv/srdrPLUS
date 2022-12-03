# == Schema Information
#
# Table name: key_questions
#
#  id         :integer          not null, primary key
#  name       :text(65535)
#  deleted_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class KeyQuestion < ApplicationRecord
  include SharedSuggestableMethods
  include SharedQueryableMethods

  acts_as_paranoid
  #before_destroy :really_destroy_children!
  def really_destroy_children!
    key_questions_projects.with_deleted.each do |child|
      child.really_destroy!
    end
  end

  after_create :record_suggestor

  has_one :suggestion, as: :suggestable, dependent: :destroy

  has_many :key_questions_projects, dependent: :destroy, inverse_of: :key_question
  has_many :projects,         through: :key_questions_projects
  has_many :extraction_forms, through: :key_questions_projects

  has_many :sd_key_questions, inverse_of: :key_question, dependent: :destroy
  has_many :sd_meta_data, through: :sd_key_questions

  validates :name, presence: true, uniqueness: { case_sensitive: true }
end
