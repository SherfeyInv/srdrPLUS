class AbstractScreeningService
  def self.as_user?(user)
    return false if user.nil?

    (ENV['SRDRPLUS_AS_USERS'].nil? ? [] : JSON.parse(ENV['SRDRPLUS_AS_USERS'])).include?(user.id)
  end

  def self.find_citation_id(abstract_screening, user)
    unfinished_asr = find_unfinished_asr(abstract_screening, user)
    return unfinished_asr.citation_id if unfinished_asr

    return nil if at_or_over_limit?(abstract_screening, user)

    case abstract_screening.abstract_screening_type
    when AbstractScreening::PILOT
      get_next_pilot_citation_id(abstract_screening, user)
    when AbstractScreening::SINGLE_PERPETUAL, AbstractScreening::N_SIZE_SINGLE
      get_next_singles_citation_id(abstract_screening, user)
    when AbstractScreening::DOUBLE_PERPETUAL, AbstractScreening::N_SIZE_DOUBLE
      get_next_doubles_citation_id(abstract_screening, user)
    end
  end

  def self.find_or_create_asr(abstract_screening, user)
    citation_id = find_citation_id(abstract_screening, user)
    return nil if citation_id.nil?

    AbstractScreeningResult.find_or_create_by!(abstract_screening:, user:, citation_id:)
  end

  def self.find_unfinished_asr(abstract_screening, user)
    AbstractScreeningResult.find_by(
      abstract_screening:,
      user:,
      label: nil
    )
  end

  def self.get_next_pilot_citation_id(abstract_screening, user)
    user_screened_citation_ids = user_screened_citation_ids(abstract_screening, user)
    project_citation_ids = abstract_screening.project.citations.map(&:id)
    project_citation_ids.sample
  end

  def self.get_next_singles_citation_id(abstract_screening, _user)
    project_screened_citation_ids = project_screened_citation_ids(abstract_screening)
    abstract_screening.project.citations.where.not(id: project_screened_citation_ids).sample&.id
  end

  def self.get_next_doubles_citation_id(abstract_screening, user)
    unscreened_citation_ids =
      other_users_screened_citation_ids(abstract_screening, user) - user_screened_citation_ids(abstract_screening, user)
    citation_id = unscreened_citation_ids.tally.select { |_, v| v == 1 }.keys.sample
    get_next_singles_citation_id(abstract_screening, user) if citation_id.nil?
  end

  def self.other_users_screened_citation_ids(abstract_screening, user)
    abstract_screening.abstract_screening_results.where.not(user:).pluck(:citation_id)
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
