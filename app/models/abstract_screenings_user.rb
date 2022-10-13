class AbstractScreeningsUser < ApplicationRecord
  belongs_to :abstract_screening
  belongs_to :user

  has_many :word_weights, dependent: :destroy, inverse_of: :abstract_screenings_user
  has_many :abstract_screenings_tags_users,
           dependent: :destroy,
           inverse_of: :abstract_screenings_user
  has_many :abstract_screenings_reasons_users,
           dependent: :destroy,
           inverse_of: :abstract_screenings_user
  has_many :reasons, through: :abstract_screenings_reasons_users
  has_many :tags, through: :abstract_screenings_tags_users
  has_many :abstract_screening_results, dependent: :destroy, inverse_of: :abstract_screenings_user

  delegate :handle, to: :user

  def process_reasons(asr, predefined_reasons, custom_reasons)
    asr.reasons.destroy_all
    predefined_reasons.merge(custom_reasons).each do |reason, included|
      next unless included

      asr.reasons << Reason.find_or_create_by(name: reason)
    end
    self.reasons = custom_reasons.keys.map { |reason| Reason.find_or_create_by(name: reason) }
  end

  def process_tags(asr, predefined_tags, custom_tags)
    asr.tags.destroy_all
    predefined_tags.merge(custom_tags).each do |tag, included|
      next unless included

      asr.tags << Tag.find_or_create_by(name: tag)
    end
    self.tags = custom_tags.keys.map { |tag| Tag.find_or_create_by(name: tag) }
  end

  def reasons_object
    reasons.each_with_object({}) do |reason, hash|
      hash[reason.name] = false
      hash
    end
  end

  def tags_object
    tags.each_with_object({}) do |tag, hash|
      hash[tag.name] = false
      hash
    end
  end

  # AbstractScreeningsProjectsUsersRole is not always present since we allow anyone
  # to start screening by default (see AbstractScreeningPolicy).
  # In case ASPUR does not exist we initialize it here.
  def self.find_aspur(user, abstract_screening)
    # AbstractScreeningsProjectsUsersRole
    #  .joins(projects_users_role: { projects_user: :user })
    #  .where(abstract_screening:, projects_users_role: { projects_users: { user: } })
    #  .first
    AbstractScreeningsProjectsUsersRole
      .find_or_initialize_by(
        abstract_screening:,
        projects_users_role: ProjectsUsersRole.where(
          projects_user: ProjectsUser.find_by(
            project_id: abstract_screening.project.id,
            user:
          )
        ).first
      )
  end

  def word_weights_object
    word_weights.each_with_object({}) do |ww, hash|
      hash[ww.word] = { weight: ww.weight, id: ww.id }
      hash
    end
  end
end
