# == Schema Information
#
# Table name: result_statistic_sections_measures
#
#  id                          :integer          not null, primary key
#  measure_id                  :integer
#  result_statistic_section_id :integer
#  deleted_at                  :datetime
#  active                      :boolean
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#

class ResultStatisticSectionsMeasure < ApplicationRecord
  include SharedParanoiaMethods

  acts_as_paranoid column: :active, sentinel_value: true
  has_paper_trail

  after_commit :set_extraction_stale, on: [:create, :update, :destroy]

  belongs_to :measure,                  inverse_of: :result_statistic_sections_measures
  belongs_to :result_statistic_section, inverse_of: :result_statistic_sections_measures

  has_many :wacs_bacs_rssms, dependent: :destroy, inverse_of: :result_statistic_sections_measure
  has_many :tps_arms_rssms, dependent: :destroy, inverse_of: :result_statistic_sections_measure
  has_many :tps_comparisons_rssms, dependent: :destroy, inverse_of: :result_statistic_sections_measure
  has_many :comparisons_arms_rssms, dependent: :destroy, inverse_of: :result_statistic_sections_measure

  delegate :extraction, to: :result_statistic_section

  private
    def set_extraction_stale
      self.extraction.extraction_checksum.update( is_stale: true )
    end
end
