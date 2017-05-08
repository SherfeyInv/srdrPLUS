class CreateExtractionFormsProjects < ActiveRecord::Migration[5.0]
  def change
    create_table :extraction_forms_projects do |t|
      t.references :extraction_form, foreign_key: true
      t.references :project, foreign_key: true
      t.datetime :deleted_at
      t.boolean :active

      t.timestamps
    end

    add_index :extraction_forms_projects, :deleted_at
    add_index :extraction_forms_projects, :active
    add_index :extraction_forms_projects, [:extraction_form_id, :project_id],          name: 'index_efp_on_ef_id_p_id', where: 'deleted_at IS NULL'
    add_index :extraction_forms_projects, [:extraction_form_id, :project_id, :active], name: 'index_efp_on_ef_id_p_id_active'
  end
end
