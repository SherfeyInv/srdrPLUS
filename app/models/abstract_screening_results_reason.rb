# == Schema Information
#
# Table name: abstract_screening_results_reasons
#
#  id                           :bigint           not null, primary key
#  abstract_screening_result_id :bigint           not null
#  reason_id                    :bigint           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#
class AbstractScreeningResultsReason < ApplicationRecord
  belongs_to :abstract_screening_result
  belongs_to :reason
end
