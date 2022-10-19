class AbstractScreeningService
  def self.get_asr(abstract_screening, user)
    unfinished_asr = find_unfinished_asr(abstract_screening, user)
    return unfinished_asr if unfinished_asr

    return nil if at_or_over_limit?(abstract_screening, user)

    case abstract_screening.abstract_screening_type
    when AbstractScreening::PILOT
      check_by_pilot(abstract_screening, user)
    when AbstractScreening::SINGLE_PERPETUAL, AbstractScreening::N_SIZE_SINGLE
      check_by_singles(abstract_screening, user)
    when AbstractScreening::DOUBLE_PERPETUAL, AbstractScreening::N_SIZE_DOUBLE
      check_by_doubles(abstract_screening, user)
    end
  end

  def self.find_unfinished_asr(abstract_screening, user)
    AbstractScreeningResult.find_by(
      abstract_screening:,
      user:,
      label: nil
    )
  end

  def self.check_by_pilot(abstract_screening, user)
    user_screened_citation_ids = user_screened_citation_ids(abstract_screening, user)
    project_citation_ids = abstract_screening.project.citations.map(&:id)
    citation_id = project_citation_ids.sample

    return nil unless citation_id

    AbstractScreeningResult.find_or_create_by!(abstract_screening:, user:, citation_id:)
  end

  def self.check_by_doubles(abstract_screening, user)
    unscreened_citation_ids =
      other_users_screened_citation_ids(abstract_screening, user) - user_screened_citation_ids(abstract_screening, user)
    citation_id = unscreened_citation_ids.tally.select { |_, v| v == 1 }.keys.sample
    if citation_id.nil?
      check_by_singles(abstract_screening, user)
    else
      AbstractScreeningResult.find_or_create_by!(abstract_screening:, user:, citation_id:)
    end
  end

  def self.other_users_screened_citation_ids(abstract_screening, user)
    abstract_screening.abstract_screening_results.where.not(user:).pluck(:citation_id)
  end

  def self.check_by_singles(abstract_screening, user)
    project_screened_citation_ids = project_screened_citation_ids(abstract_screening)
    citation = abstract_screening.project.citations.where.not(id: project_screened_citation_ids).sample
    return nil if citation.blank?

    AbstractScreeningResult.find_or_create_by!(abstract_screening:, user:, citation:)
  end

  def self.user_screened_citation_ids(abstract_screening, user)
    abstract_screening.abstract_screening_results.where(user:).pluck(:citation_id)
  end

  def self.project_screened_citation_ids(abstract_screening)
    abstract_screening.project.abstract_screening_results.pluck(:citation_id)
  end

  def self.at_or_over_limit?(abstract_screening, user)
    return false unless AbstractScreening::NON_PERPETUAL.include?(abstract_screening.abstract_screening_type)

    abstract_screening
      .abstract_screening_results
      .where(user:)
      .where('label IS NOT NULL')
      .count >= abstract_screening.no_of_citations
  end

  def self.before_asr_id(abstract_screening, asr_id, user)
    return nil if abstract_screening.blank? || asr_id.blank? || user.blank?

    AbstractScreeningResult
      .where(
        abstract_screening:,
        user:
      )
      .where(
        'updated_at < ?', AbstractScreeningResult.find_by(id: asr_id).updated_at
      ).order(:updated_at).last
  end
end
