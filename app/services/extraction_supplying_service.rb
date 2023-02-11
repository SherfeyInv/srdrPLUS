class ExtractionSupplyingService

  def find_by_project_id(id)
    extractions = Project.find(id).extractions
    extraction_bundles = []
    for extraction in extractions do
      extraction_bundles.append(find_by_extraction_id(extraction.id))
    end

    create_bundle(objs=extraction_bundles, type='collection')
  end

  def find_by_extraction_id(id)
    extraction = Extraction.find(id)
    fhir_extraction_sections = []

    efpss = extraction.extraction_forms_projects_sections.first.extraction_forms_project.extraction_forms_projects_sections
    extraction_sections = []
    for efps in efpss do
      eefpss = efps.extractions_extraction_forms_projects_sections
      for eefps in eefpss do
        if eefps.extraction_id == id.to_i
          extraction_sections.append(eefps)
        end
      end
    end
    for extraction_section in extraction_sections do
      fhir_extraction_sections.append(create_fhir_obj(extraction_section))
    end

    create_bundle(objs=fhir_extraction_sections, type='collection')
  end

  private

  def create_bundle(fhir_objs, type)
    bundle = {
      'type' => type,
      'entry' => []
    }

    for fhir_obj in fhir_objs do
      bundle['entry'].append({ 'resource' => fhir_obj }) if fhir_obj and fhir_obj.valid?
    end

    FHIR::Bundle.new(bundle)
  end

  def create_fhir_obj(raw)
    form = ExtractionFormsProjectsSection.find(raw.extraction_forms_projects_section_id)

    if form.extraction_forms_projects_section_type_id == 1
      if raw.status['name'] == 'Draft'
        status = 'draft'
      elsif raw.status['name'] == 'Completed'
        status = 'active'
      end

      eefps = {
        'status' => status,
        'id' => '4' + '-' + raw.id.to_s,
        'title' => form.section_label,
        'identifier' => [{
          'type' => {
            'text' => 'SRDR+ Object Identifier'
          },
          'system' => 'https://srdrplus.ahrq.gov/',
          'value' => 'ExtractionsExtractionFormsProjectsSection/' + raw.id.to_s
        }],
        'characteristic' => []
      }
      for row in raw.extractions_extraction_forms_projects_sections_type1s do
        info = Type1.find(row['type1_id'])
        eefps['characteristic'].append({
          'description' => info['description'],
          'definitionCodeableConcept' => {
            'text' => info['name']
          }
        })
      end
      if eefps['characteristic'].empty?
        return
      end
      return FHIR::EvidenceVariable.new(eefps)
    elsif form.extraction_forms_projects_section_type_id == 2
      if raw.status['name'] == 'Draft'
        status = 'in-progress'
      elsif raw.status['name'] == 'Completed'
        status = 'completed'
      end

      questions = ExtractionFormsProjectsSectionSupplyingService.new.find_by_extraction_forms_projects_section_id(form.id)

      eefps = {
        'status' => status,
        'id' => '4' + '-' + raw.id.to_s,
        'text' => form.section_label,
        'identifier' => [{
          'type' => {
            'text' => 'SRDR+ Object Identifier'
          },
          'system' => 'https://srdrplus.ahrq.gov/',
          'value' => 'ExtractionsExtractionFormsProjectsSection/' + raw.id.to_s
        }],
        'contained' => questions,
        'questionnaire' => '#' + questions.id,
        'item' => []
      }

      restriction_symbol = ''

      for eefpsqrf in raw.extractions_extraction_forms_projects_sections_question_row_column_fields do
        question_row_column_field = eefpsqrf.question_row_column_field
        question_row_column_id = question_row_column_field.question_row_column_id
        question_row_column = QuestionRowColumn.find(question_row_column_id)
        ans_form = question_row_column.question_row_columns_question_row_column_options
        question_row_id = question_row_column.question_row_id
        question_row = QuestionRow.find(question_row_id)
        question_id = question_row.question_id
        question = Question.find(question_id)
        type = question_row_column.question_row_column_type.id
        value = eefpsqrf.records[0]['name']
        if not eefpsqrf.extractions_extraction_forms_projects_sections_type1.nil?
          type1 = eefpsqrf.extractions_extraction_forms_projects_sections_type1.type1
        else
          type1 = nil
        end

        if value.nil?
          if type != 9
            next
          end
        else
          if type != 9
            item = {
              'linkId' => question.position.to_s + '-' + question_id.to_s + '-' + question_row_id.to_s + '-' + question_row_column_id.to_s
            }
            if not type1.nil?
              item['text'] = type1.name
            end
          end
        end

        followups = {}
        for followup in raw.extractions_extraction_forms_projects_sections_followup_fields do
          followups = followups.merge({
            FollowupField.find(followup.followup_field_id).question_row_columns_question_row_column_option_id => {
              'name' => followup.records[0]['name'],
              'id' => followup.followup_field_id
            }
          })
        end

        if type == 1
          item['answer'] = {
            'valueString' => value
          }
          eefps['item'].append(item)
        elsif type == 2
          if /-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/.match(value)
            item['answer'] = {
              'valueDecimal' => value
            }
            eefps['item'].append(item)
            unless restriction_symbol.empty?
              symbol_item = {
                'linkId' => question.position.to_s + '-' + question_id.to_s + '-' + question_row_id.to_s + '-' + question_row_column_id.to_s,
                'answer' => {
                  'valueString' => restriction_symbol
                }
              }
              eefps['item'].append(symbol_item)
            end
            restriction_symbol = ''
          else
            restriction_symbol = value
          end
        elsif type == 5
          matches = value.scan(/\D*(\d+)\D*/)
          for match in matches do
            checkbox_id = match[0].to_i
            name = ans_form.find(checkbox_id)['name']
            item['answer'] = {
              'valueString' => name
            }
            
            eefps['item'].append(item.dup)
            if followups.has_key?(checkbox_id)
              followup_item = {}
              followup_item['linkId'] = item['linkId'] + '-' + followups[checkbox_id]['id'].to_s
              followup_item['answer'] = {
                'valueString' => followups[checkbox_id]['name']
              }
              eefps['item'].append(followup_item)
            end
          end
        elsif type == 6
          name = ans_form.find(value)['name']
          item['answer'] = {
            'valueString' => name
          }
          eefps['item'].append(item)
        elsif type == 7
          name = ans_form.find(value)['name']
          item['answer'] = {
            'valueString' => name
          }
          eefps['item'].append(item)
          if followups.has_key?(value.to_i)
            followup_item = {}
            followup_item['linkId'] = item['linkId'] + '-' + followups[value.to_i]['id'].to_s
            followup_item['answer'] = {
              'valueString' => followups[value.to_i]['name']
            }
            eefps['item'].append(followup_item)
          end
        elsif type == 8
          name = ans_form.find(value)['name']
          item['answer'] = {
            'valueString' => name
          }
          eefps['item'].append(item)
        elsif type == 9
          item = {
            'linkId' => question.position.to_s + '-' + question_id.to_s + '-' + question_row_id.to_s + '-' + question_row_column_id.to_s
          }
          if not type1.nil?
            item['text'] = type1.name
          end
          for dicts in question_row_column_field.extractions_extraction_forms_projects_sections_question_row_column_fields[0].extractions_extraction_forms_projects_sections_question_row_column_fields_question_row_columns_question_row_column_options do
            value = dicts.question_row_columns_question_row_column_option_id
            name = ans_form.find(value)['name']
            item['answer'] = {
              'valueString' => name
            }
            eefps['item'].append(item.dup)
          end
          item = {}
        end 
      end

      if eefps['item'].empty?
        return
      end
      return FHIR::QuestionnaireResponse.new(eefps)
    elsif form.extraction_forms_projects_section_type_id == 3
      extraction = Extraction.find(raw.extraction_id)
      project = Project.find(extraction.project_id)
      efp_type_id = extraction.extraction_forms_projects_sections.first.extraction_forms_project.extraction_forms_project_type_id
      if efp_type_id == 1
        outcomes = ExtractionsExtractionFormsProjectsSectionsType1
          .by_section_name_and_extraction_id_and_extraction_forms_project_id(
            'Outcomes',
            raw.extraction_id,
            project.extraction_forms_projects.first.id
          )
        evidences = []

        for outcome in outcomes do
          if outcome.status['name'] == 'Draft'
            outcome_status = 'draft'
          elsif outcome.status['name'] == 'Completed'
            outcome_status = 'active'
          end

          outcome_name = Type1.find(outcome.type1_id)['name']
          populations = outcome.extractions_extraction_forms_projects_sections_type1_rows

          for population in populations do
            population_name = PopulationName.find(population.population_name_id)['name']
            result_statistic_sections = population.result_statistic_sections

            for sec_num in [0, 1, 2, 3] do
              if sec_num == 0
                for result_statistic_sections_measure in result_statistic_sections[sec_num].result_statistic_sections_measures do
                  measure_name = Measure.find(result_statistic_sections_measure.measure_id)['name']
                  for tps_arms_rssm in result_statistic_sections_measure.tps_arms_rssms do
                    record = tps_arms_rssm.records[0]['name']
                    if record.nil?
                      next
                    end
                    record_id = tps_arms_rssm.records[0]['id']
                    time_point = ExtractionsExtractionFormsProjectsSectionsType1RowColumn.find(tps_arms_rssm.timepoint_id)
                    time_point_name = time_point.timepoint_name['name'] + ' ' + time_point.timepoint_name['unit']
                    arm = ExtractionsExtractionFormsProjectsSectionsType1.find(tps_arms_rssm.extractions_extraction_forms_projects_sections_type1_id)
                    arm_name = Type1.find(arm.type1_id)['name']

                    evidence = get_evidence_obj(
                      record_id,
                      outcome_status,
                      population_name,
                      [arm_name],
                      outcome_name,
                      [time_point_name],
                      record,
                      measure_name
                    )

                    evidences.append(evidence)
                  end
                end
              elsif sec_num == 1
                for result_statistic_sections_measure in result_statistic_sections[sec_num].result_statistic_sections_measures do
                  measure_name = Measure.find(result_statistic_sections_measure.measure_id)['name']
                  for tps_comparisons_rssm in result_statistic_sections_measure.tps_comparisons_rssms do
                    record = tps_comparisons_rssm.records[0]['name']
                    if record.nil?
                      next
                    end
                    record_id = tps_comparisons_rssm.records[0]['id']
                    time_point = ExtractionsExtractionFormsProjectsSectionsType1RowColumn.find(tps_comparisons_rssm.timepoint_id)
                    time_point_name = time_point.timepoint_name['name'] + ' ' + time_point.timepoint_name['unit']
                    comparison = Comparison.find(tps_comparisons_rssm.comparison_id)
                    arm_names = []
                    for comparate_group in comparison.comparate_groups do
                      comparable_elements = comparate_group.comparable_elements
                      arm_names.append(Type1.find(ExtractionsExtractionFormsProjectsSectionsType1.find(comparable_elements[0].comparable_id).type1_id)['name'])
                    end

                    evidence = get_evidence_obj(
                      record_id,
                      outcome_status,
                      population_name,
                      arm_names,
                      outcome_name,
                      [time_point_name],
                      record,
                      measure_name
                    )

                    evidences.append(evidence)
                  end
                end
              elsif sec_num == 2
                for result_statistic_sections_measure in result_statistic_sections[sec_num].result_statistic_sections_measures do
                  measure_name = Measure.find(result_statistic_sections_measure.measure_id)['name']
                  for comparisons_arms_rssm in result_statistic_sections_measure.comparisons_arms_rssms do
                    record = comparisons_arms_rssm.records[0]['name']
                    if record.nil?
                      next
                    end
                    record_id = comparisons_arms_rssm.records[0]['id']
                    comparison = Comparison.find(comparisons_arms_rssm.comparison_id)
                    time_point_names = []
                    for comparate_group in comparison.comparate_groups do
                      comparable_elements = comparate_group.comparable_elements
                      timepoint_name = ExtractionsExtractionFormsProjectsSectionsType1RowColumn.find(comparable_elements[0].comparable_id).timepoint_name
                      time_point_name = timepoint_name['name'] + ' ' + timepoint_name['unit']
                      time_point_names.append(time_point_name)
                    end
                    arm = ExtractionsExtractionFormsProjectsSectionsType1.find(comparisons_arms_rssm.extractions_extraction_forms_projects_sections_type1_id)
                    arm_name = Type1.find(arm.type1_id)['name']

                    evidence = get_evidence_obj(
                      record_id,
                      outcome_status,
                      population_name,
                      [arm_name],
                      outcome_name,
                      time_point_names,
                      record,
                      measure_name
                    )

                    evidences.append(evidence)
                  end
                end
              elsif sec_num == 3
                for result_statistic_sections_measure in result_statistic_sections[sec_num].result_statistic_sections_measures do
                  measure_name = Measure.find(result_statistic_sections_measure.measure_id)['name']
                  for wacs_bacs_rssm in result_statistic_sections_measure.wacs_bacs_rssms do
                    record = wacs_bacs_rssm.records[0]['name']
                    if record.nil?
                      next
                    end
                    record_id = wacs_bacs_rssm.records[0]['id']

                    comparison_arm = Comparison.find(wacs_bacs_rssm.bac_id)
                    arm_names = []
                    for comparate_group in comparison_arm.comparate_groups do
                      comparable_elements = comparate_group.comparable_elements
                      arm_names.append(Type1.find(ExtractionsExtractionFormsProjectsSectionsType1.find(comparable_elements[0].comparable_id).type1_id)['name'])
                    end

                    comparison_time_point = Comparison.find(wacs_bacs_rssm.wac_id)
                    time_point_names = []
                    for comparate_group in comparison_time_point.comparate_groups do
                      comparable_elements = comparate_group.comparable_elements
                      timepoint_name = ExtractionsExtractionFormsProjectsSectionsType1RowColumn.find(comparable_elements[0].comparable_id).timepoint_name
                      time_point_name = timepoint_name['name'] + ' ' + timepoint_name['unit']
                      time_point_names.append(time_point_name)
                    end

                    evidence = get_evidence_obj(
                      record_id,
                      outcome_status,
                      population_name,
                      arm_names,
                      outcome_name,
                      time_point_names,
                      record,
                      measure_name
                    )

                    evidences.append(evidence)
                  end
                end
              end
            end
          end
        end

        if evidences.empty?
          return
        else
          return create_bundle(fhir_objs=evidences, type='collection')
        end

      else
        outcomes = ExtractionsExtractionFormsProjectsSectionsType1
          .by_section_name_and_extraction_id_and_extraction_forms_project_id(
            'Diagnoses',
            raw.extraction_id,
            project.extraction_forms_projects.first.id
          )
        evidences = [] 

        for outcome in outcomes do
          if outcome.status['name'] == 'Draft'
            outcome_status = 'draft'
          elsif outcome.status['name'] == 'Completed'
            outcome_status = 'active'
          end

          outcome_name = Type1.find(outcome.type1_id)['name']
          populations = outcome.extractions_extraction_forms_projects_sections_type1_rows

          for population in populations do
            population_name = PopulationName.find(population.population_name_id)['name']
            result_statistic_sections = population.result_statistic_sections

            for sec_num in [4, 5, 6, 7] do
              for result_statistic_sections_measure in result_statistic_sections[sec_num].result_statistic_sections_measures do
                measure_name = Measure.find(result_statistic_sections_measure.measure_id)['name']
                for tps_comparisons_rssm in result_statistic_sections_measure.tps_comparisons_rssms do
                  record = tps_comparisons_rssm.records[0]['name']
                  if record.nil?
                    next
                  end
                  record_id = tps_comparisons_rssm.records[0]['id']
                  time_point = ExtractionsExtractionFormsProjectsSectionsType1RowColumn.find(tps_comparisons_rssm.timepoint_id)
                  time_point_name = time_point.timepoint_name['name'] + ' ' + time_point.timepoint_name['unit']
                  comparison = Comparison.find(tps_comparisons_rssm.comparison_id)
                  arm_names = []
                  for comparate_group in comparison.comparate_groups do
                    comparable_elements = comparate_group.comparable_elements
                    arm_names.append(Type1.find(ExtractionsExtractionFormsProjectsSectionsType1.find(comparable_elements[0].comparable_id).type1_id)['name'])
                  end

                  evidence = get_evidence_obj(
                    record_id,
                    outcome_status,
                    population_name,
                    arm_names,
                    outcome_name,
                    [time_point_name],
                    record,
                    measure_name
                  )

                  evidences.append(evidence)
                end
              end
            end
          end
        end

        if evidences.empty?
          return
        else
          return create_bundle(fhir_objs=evidences, type='collection')
        end
      end
    end
  end

  def get_evidence_obj(
    record_id,
    outcome_status,
    population_name,
    arm_names,
    outcome_name,
    time_point_names,
    record,
    measure_name
  )
    evidence = {
      'id' => '5' + '-' + record_id.to_s,
      'status' => outcome_status,
      'identifier' => [{
        'type' => {
          'text' => 'SRDR+ Object Identifier'
        },
        'system' => 'https://srdrplus.ahrq.gov/',
        'value' => 'Record/' + record_id.to_s
      }],
      'variableDefinition' => [
        {
          'description' => population_name,
          'variableRole' => {
            'coding' => [{
              'system' => 'http://terminology.hl7.org/CodeSystem/variable-role',
              'code' => 'population'
            }]
          }
        }
      ],
      'statistic' => [{
        'quantity' => {
          'value' => record
        },
        'description' => measure_name
      }]
    }

    for arm_name in arm_names do
      variable_definition = {
        'description' => arm_name,
        'variableRole' => {
          'coding' => [{
            'system' => 'http://terminology.hl7.org/CodeSystem/variable-role',
            'code' => 'exposure'
          }]
        }
      }
      evidence['variableDefinition'].append(variable_definition)
    end

    for time_point_name in time_point_names do
      variable_definition = {
        'description' => outcome_name + ', ' + time_point_name,
        'variableRole' => {
          'coding' => [{
            'system' => 'http://terminology.hl7.org/CodeSystem/variable-role',
            'code' => 'measuredVariable'
          }]
        }
      }
      evidence['variableDefinition'].append(variable_definition)
    end

    if measure_name == 'Total (N analyzed)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C25463',
          'display' => 'Count'
        }]
      }
    elsif measure_name == 'Proportion'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C44256',
          'display' => 'Proportion'
        }]
      }
    elsif measure_name == 'Incidence Rate (per 1000)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C16726',
          'display' => 'Incidence'
        }]
      }
    elsif measure_name == 'Incidence rate (per 10,000)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C16726',
          'display' => 'Incidence'
        }]
      }
    elsif measure_name == 'Incidence rate (per 100,000)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C16726',
          'display' => 'Incidence'
        }]
      }
    elsif measure_name == 'Odds Ratio (OR)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C16932',
          'display' => 'Odds Ratio'
        }]
      }
    elsif measure_name == 'Odds Ratio, Adjusted (adjOR)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C16932',
          'display' => 'Odds Ratio'
        }]
      }
    elsif measure_name == 'Incidence Rate Ratio (IRR)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'rate-ratio',
          'display' => 'Incidence Rate Ratio'
        }]
      }
    elsif measure_name == 'Incidence Rate Ratio, Adjusted (adjIRR)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'rate-ratio',
          'display' => 'Incidence Rate Ratio'
        }]
      }
    elsif measure_name == 'Hazard Ratio (HR)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C93150',
          'display' => 'Hazard Ratio'
        }]
      }
    elsif measure_name == 'Hazard Ratio, Adjusted (adjHR)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => 'C93150',
          'display' => 'Hazard Ratio'
        }]
      }
    elsif measure_name == 'Risk Difference (RD)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => '0000424',
          'display' => 'Risk Difference'
        }]
      }
    elsif measure_name == 'Risk Difference, Adjusted (adjRD)'
      evidence['statistic'][0]['statisticType'] = {
        'coding' => [{
          'system' => 'http://terminology.hl7.org/CodeSystem/statistic-type',
          'code' => '0000424',
          'display' => 'Risk Difference'
        }]
      }
    end

    return FHIR::Evidence.new(evidence)
  end
end
