# == Schema Information
#
# Table name: citations_projects
#
#  id                :integer          not null, primary key
#  citation_id       :integer
#  project_id        :integer
#  deleted_at        :datetime
#  active            :boolean
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  consensus_type_id :integer
#  pilot_flag        :boolean
#  screening_status  :string(255)      default("CP"), not null
#

class CitationsProject < ApplicationRecord
  include SharedParanoiaMethods

  acts_as_paranoid column: :active, sentinel_value: true
  before_destroy :really_destroy_children!
  def really_destroy_children!
    extractions.with_deleted.each do |child|
      child.really_destroy!
    end
    labels.with_deleted.each do |child|
      child.really_destroy!
    end
    notes.with_deleted.each do |child|
      child.really_destroy!
    end
    taggings.with_deleted.each do |child|
      child.really_destroy!
    end
  end
  # paginates_per 25

  scope :unlabeled, lambda { |project, count|
                      includes(citation: [{ authors_citations: [:author] }, :keywords, :journal])
                        .left_outer_joins(:labels)
                        .where(labels: { id: nil },
                               project_id: project.id)
                        .distinct
                        .limit(count)
                    }

  scope :labeled, lambda { |project, count|
                    includes({ :citation => [{ authors_citations: [:author] }, :keywords, :journal], labels => [:reasons] })
                      .joins(:labels)
                      .where(project_id: project.id)
                      .distinct
                      .limit(count)
                  }

  belongs_to :citation, inverse_of: :citations_projects
  belongs_to :project, inverse_of: :citations_projects # , touch: true

  has_one :prediction, dependent: :destroy
  has_one :priority, dependent: :destroy

  has_many :extractions, dependent: :destroy
  has_many :labels, dependent: :destroy
  has_many :notes, as: :notable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  accepts_nested_attributes_for :citation, reject_if: :all_blank

  # We find all CitationsProject entries that have the exact same citation_id
  # and project_id. Then we pick the first (oldest) one. We refer to it as the
  # "Master CP" and link associations from all other CitationsProject entries
  # to the "Master CP"
  def dedupe
    citations_projects = CitationsProject.where(
      citation_id:,
      project_id:
    ).to_a
    master_citations_project = citations_projects.shift
    citations_projects.each do |cp|
      dedupe_update_associations(master_citations_project, cp)
      cp.destroy
    end
  end

  def self.dedupe_update_associations(master_cp, cp_to_remove)
    cp_to_remove.extractions.each do |e|
      e.dup.update_attributes(citations_project_id: master_cp.id)
    end
    cp_to_remove.labels.each do |l|
      l.dup.update_attributes(citations_project_id: master_cp.id)
    end
    cp_to_remove.notes.each do |n|
      n.dup.update_attributes(notable_id: master_cp.id)
    end
    cp_to_remove.taggings.each do |t|
      t.dup.update_attributes(taggable_id: master_cp.id)
    end
  end
end
