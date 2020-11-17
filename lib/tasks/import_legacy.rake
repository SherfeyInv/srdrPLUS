require 'mysql2'

def db
  @client ||= Mysql2::Client.new(Rails.configuration.database_configuration['legacy_production'])
end

namespace(:db) do
  namespace(:import_legacy) do
    desc "import legacy projects"
    task :projects => :environment do 
      initialize_variables

      #projects = db.query("SELECT * FROM projects")
      projects = db.query("SELECT * FROM projects WHERE id>516 LIMIT 3")
      projects.each do |project_hash|
        begin
          @legacy_project_id = project_hash["id"]
          reset_project_variables
          migrate_legacy_srdr_project project_hash
        rescue => error
          puts error
          puts error.backtrace
          @legacy_project_id = nil
          reset_project_variables
        end
      end
    end
    
    def initialize_variables
      @efps_type_1 = ExtractionFormsProjectsSectionType.find_by(name: 'Type 1')
      @efps_type_2 = ExtractionFormsProjectsSectionType.find_by(name: 'Type 2')
      @efps_type_results = ExtractionFormsProjectsSectionType.find_by(name: 'Results')
      @efps_type_4 = ExtractionFormsProjectsSectionType.find_by(name: 'Type 4')
      @efp_type_standard = ExtractionFormsProjectType.find_by(name: 'Standard')
      @efp_type_diagnostic = ExtractionFormsProjectType.find_by(name: 'Diagnostic Test')

      @qrc_type_text = QuestionRowColumnType.find_by(name: 'text')
      @qrc_type_numeric = QuestionRowColumnType.find_by(name: 'numeric')
      @qrc_type_numeric_range = QuestionRowColumnType.find_by(name: 'numeric_range')
      @qrc_type_scientific = QuestionRowColumnType.find_by(name: 'scientific')
      @qrc_type_checkbox = QuestionRowColumnType.find_by(name: 'checkbox')
      @qrc_type_dropdown = QuestionRowColumnType.find_by(name: 'dropdown')
      @qrc_type_radio = QuestionRowColumnType.find_by(name: 'radio')
      @qrc_type_select2_single = QuestionRowColumnType.find_by(name: 'select2_single')
      @qrc_type_select2_multi = QuestionRowColumnType.find_by(name: 'select2_multi')

      @qrco_answer_choice = QuestionRowColumnOption.find_by(name: 'answer_choice')
      @qrco_min_length = QuestionRowColumnOption.find_by(name: 'min_length')
      @qrco_max_length = QuestionRowColumnOption.find_by(name: 'max_length')
      @qrco_additional_char = QuestionRowColumnOption.find_by(name: 'additional_char')
      @qrco_min_value = QuestionRowColumnOption.find_by(name: 'min_value')
      @qrco_max_value = QuestionRowColumnOption.find_by(name: 'max_value')
      @qrco_coefficient = QuestionRowColumnOption.find_by(name: 'coefficient')
      @qrco_exponent = QuestionRowColumnOption.find_by(name: 'exponent')
    end

    def reset_project_variables
      @srdr_to_srdrplus_project_dict = {}
      @srdr_to_srdrplus_key_questions_dict = {}
      @default_projects_users_role = nil
    end

    def get_srdrplus_project srdr_project_id
      @srdr_to_srdrplus_project_dict[srdr_project_id]
    end

    def set_srdrplus_project srdr_project_id, srdrplus_project
      @srdr_to_srdrplus_project_dict[srdr_project_id] = srdrplus_project
    end

    def set_srdrplus_key_question srdr_key_question_id, srdrplus_key_question
      @srdr_to_srdrplus_key_questions_dict[srdr_key_question_id] = srdrplus_key_question
    end

    def get_srdrplus_key_question srdr_key_question_id
      @srdr_to_srdrplus_key_questions_dict[srdr_key_question_id]
    end

    def add_default_user_to_srdrplus_project srdrplus_project
      srdrplus_project.users << User.first
      srdrplus_project.projects_users.first.roles << Role.first

      @default_projects_users_role = srdrplus_project.projects_users.first.projects_users_roles.first
    end

    def create_srdrplus_project project_hash
      project_id = project_hash["id"]
      project_name = project_hash["title"]
      project_description = project_hash["description"]

      #TODO What to do with publications ?, is_public means published in SRDR
      srdrplus_project = Project.new name: project_name, description: project_description
      srdrplus_project.save #need to save, because i want the default efp
      srdrplus_project.extraction_forms_projects.first.extraction_forms_projects_sections.destroy_all #need to delete default sections

      add_default_user_to_srdrplus_project srdrplus_project

      set_srdrplus_project project_id, srdrplus_project
    end

    def migrate_legacy_srdr_project project_hash
      # DO I WANT TO CREATE USERS? probably no
      #purs = db.query "SELECT * FROM user_project_roles where project_id=#{project_hash["id"]}"
      #purs.each do |pur|
      #  break#DELETE THIS 
      #end

      create_srdrplus_project project_hash
      migrate_key_questions

      # Extraction Forms Migration
      efs = db.query "SELECT * FROM extraction_forms where project_id=#{@legacy_project_id}"
      efp_type = get_efp_type efs

      if efp_type == false
        return
      elsif efp_type == @efp_type_diagnostic
        get_srdrplus_project(@legacy_project_id).extraction_forms_projects.first.update(extraction_forms_project_type: efp_type)
        #migrate_extraction_forms_as_diagnostic_efp efs
      else
        migrate_extraction_forms_as_standard_efp efs
      end

      studies_hash = db.query "SELECT * FROM studies where project_id=#{@legacy_project_id}"
      studies_hash.each do |study_hash|
        study_id = study_hash["id"]

        primary_publications = db.query "SELECT * FROM primary_publications where study_id=#{study_id}"
        primary_publications.each do |primary_publication_hash|
          citation = migrate_primary_publication_as_citation primary_publication_hash 
          citations_project = CitationsProject.create citation: citation, project: get_srdrplus_project(@legacy_project_id)
          migrate_study_as_extraction study_hash, citations_project.id
          break
        end

      end
    end

    def migrate_extraction_forms_as_standard_efp efs
      combined_efp = get_srdrplus_project(@legacy_project_id).extraction_forms_projects.first

      efs.each do |ef|
        ef_sections = db.query "SELECT * FROM extraction_form_sections where extraction_form_id=#{ef["id"]}"
        ef_key_questions = db.query "SELECT * FROM extraction_form_key_questions where extraction_form_id=#{ef["id"]}"

        t1_efps = []
        t2_efps = []
        other_efps = []

        arms_efps = nil
        outcomes_efps = nil
        adverse_events_efps = nil
        diagnostic_tests_efps = nil

        ef_sections.each do |ef_section|
          section = Section.find_or_create_by(name: ef_section["section_name"].titleize)
          case ef_section["section_name"]
          when "arms"
            arms_efps = combined_efp.extraction_forms_projects_sections.create(section: section, extraction_forms_projects_section_type: @efps_type_1)
            if adverse_events_efps.present? then adverse_events_efps.update(link_to_type1:arms_efps) end
          when "outcomes"
            outcomes_efps = combined_efp.extraction_forms_projects_sections.create(section: section, extraction_forms_projects_section_type: @efps_type_1)
          when "diagnostic_tests"
            diagnostic_tests_efps = combined_efp.extraction_forms_projects_sections.create(section: section, extraction_forms_projects_section_type: @efps_type_4)
          when "adverse"
            #efps.link_to_type1 = arms_efps
            #t1_efps << efps
            #efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.create ef.adverse_event_display_arms, ef.adverse_event_display_total
            #adverse_events_efps = efps
            #t2_efps << ExtractionFormsProjectsSectionWrapper.new(s)

          when "quality", "arm_details","outcome_details", "quality_details", "diagnostic_test_details","design"
            section = Section.find_or_create_by(name: ef_section["section_name"].titleize)
            t2_efps << combined_efp.extraction_forms_projects_sections.create(section: section, extraction_forms_projects_section_type: @efps_type_2)
          when "results"
            section = Section.find_or_create_by(name: ef_section["section_name"].titleize)
            combined_efp.extraction_forms_projects_sections.create(section: section, extraction_forms_projects_section_type: @efps_type_results)

          else
            #Baseline Characteristics
          end
        end

        t2_efps.each do |efps|
          efps.extraction_forms_projects_section_option.update by_type1: false
          efps.extraction_forms_projects_section_option.update include_total: false
          case efps.section.name
          when "Arm Details"
            efsos = db.query("SELECT * FROM ef_section_options where section='arm_detail' AND extraction_form_id=#{ef["id"]}")
            efsos.each do |efso|
              if efso["by_arm"] == 1
                efps.link_to_type1 = arms_efps
              end
              efps.extraction_forms_projects_section_option.update by_type1: (if efso["by_arm"] == 1 then true else false end)
              efps.extraction_forms_projects_section_option.update include_total: (if efso["include_total"] == 1 then true else false end)
            end

            migrate_questions efps, ef["id"], 'arm_detail', ef_key_questions
          when "Outcome Details"
            efsos = db.query("SELECT * FROM ef_section_options where section='outcome_detail' AND extraction_form_id=#{ef["id"]}")
            efsos.each do |efso|
              if efso["by_outcome"] == 1
                efps.update link_to_type1: outcomes_efps
              end
              efps.extraction_forms_projects_section_option.update by_type1: (if efso["by_outcome"] == 1 then true else false end)
              efps.extraction_forms_projects_section_option.update include_total: (if efso["include_total"] == 1 then true else false end)
            end
            migrate_questions efps, ef["id"], 'outcome_detail', ef_key_questions
          when "Diagnostic Test Details"
            efsos = db.query("SELECT * FROM ef_section_options where section='diagnostic_test' AND extraction_form_id=#{ef["id"]}")
            efsos.each do |efso|
              if efso["by_diagnostic_test"]
                efps.update link_to_type1: diagnostic_tests_efps
              end
              efps.extraction_forms_projects_section_option.update by_type1: (if efso["by_diagnostic_test"] == 1 then true else false end)
              efps.extraction_forms_projects_section_option.update include_total: (if efso["include_total"] == 1 then true else false end)
            end
            migrate_questions efps, ef["id"], 'diagnostic_test_detail', ef_key_questions
          when "Adverse"
            #efps.link_to_type1 = adverse_events_efps
            #efps.extraction_forms_projects_section_option = ExtractionFormsProjectsSectionOptionWrapper.new true, false
          when "Design"
            migrate_questions efps, ef["id"], 'design_detail', ef_key_questions
          when "Quality"
          when "Baseline"

          else
          end
        end
        break
      end
    end

    def get_questions table_root, ef_id
      db.query "SELECT * FROM #{table_root}s where extraction_form_id=#{ef_id} ORDER BY question_number ASC"
    end

    def get_question_fields table_root, ef_id
      qs = db.query "SELECT * FROM #{table_root}s where extraction_form_id=#{ef_id} ORDER BY question_number ASC"
      q_ids_string = qs.map{|q| q["id"]}.join ","

      if q_ids_string.present?
        return db.query "SELECT * FROM #{table_root}_fields where #{table_root}_id IN (#{q_ids_string}) ORDER BY row_number ASC"
      else
        return []
      end
    end

    def get_data_points table_root, ef_id
      db.query "SELECT * FROM #{table_root}_data_points where extraction_form_id=#{ef_id}"
    end

    def migrate_questions efps, ef_id, table_root, ef_key_questions
      legacy_questions = get_questions table_root, ef_id
      legacy_question_fields = get_question_fields table_root, ef_id
      legacy_data_points = get_data_points table_root, ef_id

      legacy_questions.each do |q|
        legacy_question_id = q["id"]
        name = q["question"]
        description = q["instruction"]
        question_type = q["field_type"]
        include_other = q["include_other_as_option"]
        is_matrix = q["is_matrix"]
        question = Question.create name: name,
                                   description: description,
                                   extraction_forms_projects_section: efps

        ef_key_questions.each do |kq|
          KeyQuestionsProjectsQuestion.create! key_questions_project: get_srdrplus_key_question(kq["key_question_id"]),
                                               question: question
        end

        q_fields = legacy_question_fields.select{|qf| qf["#{table_root}_id"] == legacy_question_id}
        q_fields = (q_fields.select{|qf| qf["row_number"] != -1} + q_fields.select{|qf| qf["row_number"] == -1})
        q_data_points = legacy_data_points.select{|dp| dp["#{table_root}_field_id"] == q["id"]}

        case question_type
        when "text"
        when "checkbox"
          migrate_multiple_choice_question question, @qrc_type_checkbox, q, q_fields, q_data_points, table_root
        when "radio"
          migrate_multiple_choice_question question, @qrc_type_radio, q, q_fields, q_data_points, table_root
        when "select"
          migrate_multiple_choice_question question, @qrc_type_dropdown, q, q_fields, q_data_points, table_root
        when "matrix_select"
          migrate_matrix_dropdown_question question, q, q_data_points, table_root
        when "matrix_radio"
          migrate_multi_row_question question, @qrc_type_radio, q, q_fields, q_data_points, table_root
        when "matrix_checkbox"
          migrate_multi_row_question question, @qrc_type_checkbox, q, q_fields, q_data_points, table_root
        else
        end
      end
    end

    def migrate_multiple_choice_question question, question_type, legacy_question, fields_of_legacy_question, data_points_of_legacy_question, table_root
      question_row_column = question.question_rows.first.question_row_columns.first
      question_row_column.update question_row_column_type: question_type
      
      question_row_column.question_row_columns_question_row_column_options.where(question_row_column_option: @qrco_answer_choice).destroy_all
      fields_of_legacy_question.each do |qf|
        if qf["row_number"] == -1
          qrcqrco = QuestionRowColumnsQuestionRowColumnOption.create name: "Other (please specify):",
                                                                     question_row_column_option: @qrco_answer_choice,
                                                                     question_row_column: question_row_column
          ff = FollowupField.create question_row_columns_question_row_column_option: qrcqrco
        else
          if qf["has_subquestion"] == 1
            qrcqrco = QuestionRowColumnsQuestionRowColumnOption.create name: qf["option_text"]+"..."+qf["subquestion"],
                                                                       question_row_column_option: @qrco_answer_choice,
                                                                       question_row_column: question_row_column
            FollowupField.create question_row_columns_question_row_column_option: qrcqrco
          else
            qrcqrco = QuestionRowColumnsQuestionRowColumnOption.create name: qf["option_text"],
                                                                       question_row_column_option: @qrco_answer_choice,
                                                                       question_row_column: question_row_column
          end
        end
        data_points_of_legacy_question.select{|dp| dp["#{table_root}_id=#{qf["id"]}"]}.each do |dp|
          queue_qrcqrco_data_point dp, qrcqrco
        end
      end
    end

    def migrate_multi_row_question question, question_type, legacy_question, fields_of_legacy_question, data_points_of_legacy_question, table_root
      r_farr = db.query "SELECT * FROM #{table_root}_fields WHERE #{table_root}_id=#{legacy_question["id"]} and column_number=0 ORDER BY row_number ASC"
      c_farr = db.query "SELECT * FROM #{table_root}_fields WHERE #{table_root}_id=#{legacy_question["id"]} and row_number=0 ORDER BY column_number ASC"

      qr = question.question_rows.first
      qrc = qr.question_row_columns.first
      _is_first = true

      (r_farr.select{|rf| rf["row_number"] != -1} + r_farr.select{|rf| rf["row_number"] == -1}).each do |rf|
        if _is_first
          _is_first = false
        else
          qr = QuestionRow.create question: question
          qrc = qr.question_row_columns.first
        end

        if rf["row_number"] == -1
          qr.update name: "Other (please specify):"
        else
          qrc.update question_row_column_type: question_type
          qr.update name: rf["option_text"]
        end

        qrc.question_row_columns_question_row_column_options.where(question_row_column_option: @qrco_answer_choice).destroy_all
        c_farr.each do |cf|
          qrcqrco = QuestionRowColumnsQuestionRowColumnOption.create name: cf["option_text"],
                                                                     question_row_column_option: @qrco_answer_choice,
                                                                     question_row_column: qrc
        end

        data_points_of_legacy_question.select{|dp| dp["row_field_id=#{rf["id"]}"]}.each do |dp|
          queue_qrcf_data_point dp, qrc.question_row_column_fields.first
        end
      end
    end
    
    def migrate_matrix_dropdown_question question, legacy_question, data_points_of_legacy_question, table_root
      p "Project: " + question.project.name
      p "Question: " + question.name
      r_farr = db.query "SELECT * FROM #{table_root}_fields WHERE #{table_root}_id=#{legacy_question["id"]} and column_number=0 ORDER BY row_number ASC"
      c_farr = db.query "SELECT * FROM #{table_root}_fields WHERE #{table_root}_id=#{legacy_question["id"]} and row_number=0 ORDER BY column_number ASC"

      qr = question.question_rows.first
      qrc = qr.question_row_columns.first
      _is_first = true

      (r_farr.select{|rf| rf["row_number"] != -1} + r_farr.select{|rf| rf["row_number"] == -1}).each do |rf|
        if _is_first
          _is_first = false
        else
          qr = QuestionRow.create question: question
          qrc = qr.question_row_columns.first
        end

        if rf["row_number"] == -1
          qr.update name: "Other (please specify):"
        else
          qr.update name: rf["option_text"]
        end

        _is_first_2 = true
        c_farr.each do |cf|
          if _is_first_2
            _is_first_2 = false
          else
            qrc = QuestionRowColumn.create question_row: qr
          end

          matrix_dropdown_options = db.query "SELECT * FROM matrix_dropdown_options WHERE row_id=#{rf["id"]} and column_id=#{cf["id"]} ORDER BY option_number"

          dropdown_options = []
          other_name = ""

          p matrix_dropdown_options.count
          return
          matrix_dropdown_options.each do |op|
            dropdown_options << op
          end

          if not dropdown_options.empty?
            qrc.update question_row_column_type: @qrc_type_dropdown
            qrc.question_row_columns_question_row_column_options.where(question_row_column_option: @qrco_answer_choice).destroy_all
            dropdown_options.each do |op|
              qrcqrco = QuestionRowColumnsQuestionRowColumnOption.create name: op,
                                                                         question_row_column_option: @qrco_answer_choice,
                                                                         question_row_column: qrc
              if op["option_text"].downcase == 'other'
                FollowupField.create question_row_columns_question_row_column_option: qrcqrco
              end
            end
          end
        end

        data_points_of_legacy_question.select{|dp| dp["row_field_id=#{rf["id"]}"]}.each do |dp|
          queue_qrcf_data_point dp, qrc.question_row_column_fields.first
        end
      end
    end

    def queue_qrcf_data_point dp, qrcf
    end

    def queue_qrcqrco_data_point dp, qrcqrco
    end

    def migrate_key_questions
      kqs = db.query "SELECT * FROM key_questions where project_id=#{@legacy_project_id}"
      srdrplus_project = get_srdrplus_project @legacy_project_id
      kqs.each do |kq|
        srdrplus_kq = KeyQuestion.find_or_create_by name: kq["question"]
        srdrplus_kqp = KeyQuestionsProject.create key_question: srdrplus_kq, project: srdrplus_project
        set_srdrplus_key_question kq["id"], srdrplus_kqp
      end
    end

    def migrate_study_as_extraction study_hash, citations_project_id
      extraction = Extraction.create(projects_users_role: @default_projects_users_role,
                                     citations_project_id: citations_project_id,
                                     consolidated: false,
                                     project: get_srdrplus_project(@legacy_project_id))
      return
    end

    def migrate_primary_publication_as_citation primary_publication_hash
      if primary_publication_hash["journal"]
        journal = Journal.find_or_create_by name: primary_publication_hash["journal"],
                                            volume: primary_publication_hash["volume"],
                                            issue: primary_publication_hash["issue"],
                                            publication_date: primary_publication_hash["year"]
      end
      new_citation = Citation.new name: primary_publication_hash["title"] || "", 
                                  abstract: primary_publication_hash["abstract"] || "",
                                  journal: journal

      #TODO import key_words (do they even exist in srdr)

      #TODO separate authors
      #Author.new name: primary_publication_hash["author"]

      #if new_citation.save then return new_citation end
      return new_citation
    end

    def migrate_secondary_publication_as_citation secondary_publication_hash
    end

    def migrate_author_string_as_separate_authors authors_string
      authors = []
      author_names = split_authors_string authors_string
      author_names.each do |author_name|
        authors << Author.find_or_create_by(name: author_name)
      end
      authors
    end

    def split_authors_string authors_string
      []
    end

    def get_efp_type efs
      has_diagnostic = false
      has_standard = false
      efs.each do |ef_hash|
        if ef_hash["is_diagnostic"] == 1
          has_diagnostic = true
        else
          has_standard = true
        end
      end
      if has_diagnostic and has_standard
        return false
      elsif has_diagnostic
        return @efp_type_diagnostic
      else
        return @efp_type_standard
      end
    end
  end
end
