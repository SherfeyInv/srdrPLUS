class FulltextScreeningService
  def self.find_citation_id(fulltext_screening, user)
    unfinished_fsr = find_unfinished_fsr(fulltext_screening, user)
    return unfinished_fsr.citation_id if unfinished_fsr

    return nil if at_or_over_limit?(fulltext_screening, user)

    case fulltext_screening.fulltext_screening_type
    when FulltextScreening::PILOT
      get_next_pilot_citation_id(fulltext_screening, user)
    when FulltextScreening::SINGLE_PERPETUAL, FulltextScreening::N_SIZE_SINGLE
      get_next_singles_citation_id(fulltext_screening, user)
    when FulltextScreening::DOUBLE_PERPETUAL, FulltextScreening::N_SIZE_DOUBLE
      get_next_doubles_citation_id(fulltext_screening, user)
    end
  end

  def self.find_or_create_fsr(fulltext_screening, user)
    citation_id = find_citation_id(fulltext_screening, user)
    return nil if citation_id.nil?

    FulltextScreeningResult.find_or_create_by!(fulltext_screening:, user:, citation_id:)
  end

  def self.find_unfinished_fsr(fulltext_screening, user)
    FulltextScreeningResult.find_by(
      fulltext_screening:,
      user:,
      label: nil
    )
  end

  def self.get_next_pilot_citation_id(fulltext_screening, user)
    uniq_other_users_screened_citation_ids = other_users_screened_citation_ids(fulltext_screening, user).uniq
    user_screened_citation_ids = user_screened_citation_ids(fulltext_screening, user)
    unscreened_citation_ids = uniq_other_users_screened_citation_ids - user_screened_citation_ids
    citation_id = unscreened_citation_ids.sample

    if citation_id.nil?
      get_next_singles_citation_id(fulltext_screening, user)
    else
      citation_id
    end
  end

  def self.get_next_singles_citation_id(fulltext_screening, _user)
    project_screened_citation_ids = project_screened_citation_ids(fulltext_screening)
    fulltext_screening.project.citations.where.not(id: project_screened_citation_ids).sample&.id
  end

  def self.get_next_doubles_citation_id(fulltext_screening, user)
    unscreened_citation_ids =
      other_users_screened_citation_ids(fulltext_screening, user) - user_screened_citation_ids(fulltext_screening, user)
    citation_id = unscreened_citation_ids.tally.select { |_, v| v == 1 }.keys.sample
    if citation_id.nil?
      get_next_singles_citation_id(fulltext_screening, user)
    else
      citation_id
    end
  end

  def self.other_users_screened_citation_ids(fulltext_screening, user)
    fulltext_screening.fulltext_screening_results.where.not(user:).pluck(:citation_id)
  end

  def self.user_screened_citation_ids(fulltext_screening, user)
    fulltext_screening.fulltext_screening_results.where(user:).pluck(:citation_id)
  end

  def self.project_screened_citation_ids(fulltext_screening)
    fulltext_screening.project.fulltext_screening_results.pluck(:citation_id)
  end

  def self.at_or_over_limit?(fulltext_screening, user)
    return false unless FulltextScreening::NON_PERPETUAL.include?(fulltext_screening.fulltext_screening_type)

    fulltext_screening
      .fulltext_screening_results
      .where(user:)
      .where('label IS NOT NULL')
      .count >= fulltext_screening.no_of_citations
  end

  def self.before_fsr_id(fulltext_screening, fsr_id, user)
    return nil if fulltext_screening.blank? || fsr_id.blank? || user.blank?

    FulltextScreeningResult
      .where(
        fulltext_screening:,
        user:
      )
      .where(
        'updated_at < ?', FulltextScreeningResult.find_by(id: fsr_id).updated_at
      ).order(:updated_at).last
  end
end
