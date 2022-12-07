# == Schema Information
#
# Table name: projects_users_term_groups_colors
#
#  id                   :integer          not null, primary key
#  term_groups_color_id :integer
#  projects_user_id     :integer
#

class ProjectsUsersTermGroupsColor < ApplicationRecord
  include SharedProcessTokenMethods

  belongs_to :projects_user
  belongs_to :term_groups_color

  has_one :color, through: :term_groups_color
  has_one :term_group, through: :term_groups_color
  has_many :projects_users_term_groups_colors_terms
  has_many :terms, through: :projects_users_term_groups_colors_terms

  accepts_nested_attributes_for :term_groups_color

  def term_ids=(tokens)
    tokens.map do |token|
      resource = Term.new
      save_resource_name_with_token(resource, token)
    end
    super
  end

  def term_group_name=(new_name)
    term_group = TermGroup.find_or_create_by(name: new_name)
    term_groups_color = TermGroupsColor.find_or_create_by(term_group:, color:)
    self.term_groups_color = term_groups_color
    save
  end

  def term_group_name=(new_name)
    term_group = TermGroup.find_or_create_by(name: new_name)
    term_groups_color = TermGroupsColor.find_or_create_by(term_group:, color:)
    self.term_groups_color = term_groups_color
    save
  end
end
