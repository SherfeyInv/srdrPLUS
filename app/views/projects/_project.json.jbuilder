json.extract!(
  project,
  :id,
  :name,
  :description,
  :attribution,
  :authors_of_report,
  :methodology_description,
  :prospero,
  :doi,
  :notes,
  :funding_source,
  :as_allow_adding_reasons,
  :as_allow_adding_tags,
  :fs_allow_adding_reasons,
  :fs_allow_adding_tags,
  :as_limit_one_reason,
  :fs_limit_one_reason,
  :created_at,
  :updated_at
)
json.url project_url(project, format: :json)
