class CreateKeyQuestionsProjects < ActiveRecord::Migration[5.0]
  def change
    create_table :key_questions_projects do |t|
      t.references :extraction_forms_project, foreign_key: true
      t.references :key_question, foreign_key: true
      t.references :project, foreign_key: true
      t.datetime :deleted_at
      t.boolean :active

      t.timestamps
    end

    add_index :key_questions_projects, :deleted_at
    add_index :key_questions_projects, :active
    add_index :key_questions_projects, [:key_question_id, :project_id, :deleted_at], name: 'index_kqp_on_kq_id_p_id_deleted_at', where: 'deleted_at IS NULL'
    add_index :key_questions_projects, [:key_question_id, :project_id, :active],     name: 'index_kqp_on_kq_id_p_id_active'
    add_index :key_questions_projects, [:extraction_forms_project_id, :key_question_id, :project_id, :deleted_at], name: 'index_kqp_on_ef_id_kq_id_p_id_deleted_at', where: 'deleted_at IS NULL'
    add_index :key_questions_projects, [:extraction_forms_project_id, :key_question_id, :project_id, :active],     name: 'index_kqp_on_ef_id_kq_id_p_id_active'
  end
end
