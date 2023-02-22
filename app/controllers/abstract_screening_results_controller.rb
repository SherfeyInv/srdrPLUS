class AbstractScreeningResultsController < ApplicationController
  def update
    respond_to do |format|
      format.json do
        @abstract_screening_result = AbstractScreeningResult
                                     .includes(citations_project: :citation)
                                     .find(params[:id])
        case params[:submissionType]
        when 'label'
          @abstract_screening_result.update(asr_params)
          @abstract_screening_result =
            AbstractScreeningService.find_or_create_asr(
              @abstract_screening_result.abstract_screening, current_user
            )
          prepare_json_data
          @screened_cps =
            AbstractScreeningResult
            .includes(citations_project: :citation)
            .where(user: current_user,
                   abstract_screening: @abstract_screening_result.abstract_screening)
          render :show
        when 'reasons_and_tags'
          @screened_cps = []
          handle_reasons_and_tags
          prepare_json_data
          render :show
        when 'notes'
          @abstract_screening_result.update(notes: params[:asr][:notes])
          @screened_cps = []
          render json: {}
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.json do
        @abstract_screening_result = AbstractScreeningResult
                                     .includes(citations_project: :citation)
                                     .find(params[:id])
        @screened_cps = AbstractScreeningResult
                        .includes(citations_project: :citation)
                        .where(user: current_user,
                               abstract_screening: @abstract_screening_result.abstract_screening)
        prepare_json_data
      end
    end
  end

  private

  def handle_reasons_and_tags
    reasons_and_tags_params['predefined_reasons'].concat(reasons_and_tags_params['custom_reasons']).each do |reason_object|
      if reason_object[:selected]
        AbstractScreeningResultsReason.find_or_create_by(reason_id: reason_object[:reason_id],
                                                         abstract_screening_result: @abstract_screening_result)
      else
        AbstractScreeningResultsReason.where(reason_id: reason_object[:reason_id],
                                             abstract_screening_result: @abstract_screening_result).destroy_all
      end
    end

    reasons_and_tags_params['predefined_tags'].concat(reasons_and_tags_params['custom_tags']).each do |tag_object|
      if tag_object[:selected]
        AbstractScreeningResultsTag.find_or_create_by(tag_id: tag_object[:tag_id],
                                                      abstract_screening_result: @abstract_screening_result)
      else
        AbstractScreeningResultsTag.where(tag_id: tag_object[:tag_id],
                                          abstract_screening_result: @abstract_screening_result).destroy_all
      end
    end
  end

  def prepare_json_data
    @abstract_screening = @abstract_screening_result.abstract_screening
    @predefined_reasons = @abstract_screening.reasons_object
    @predefined_tags = @abstract_screening.tags_object
    @custom_reasons = AbstractScreeningsReasonsUser.custom_reasons_object(@abstract_screening, current_user)
    @custom_tags = AbstractScreeningsTagsUser.custom_tags_object(@abstract_screening, current_user)

    @predefined_reasons.map! do |predefined_reason|
      predefined_reason[:selected] = true if @abstract_screening_result.reasons.any? do |reason|
                                               reason.id == predefined_reason[:reason_id]
                                             end
      predefined_reason
    end

    @custom_reasons.map! do |custom_reason|
      custom_reason[:selected] = true if @abstract_screening_result.reasons.any? do |reason|
                                           reason.id == custom_reason[:reason_id]
                                         end
      custom_reason
    end

    @predefined_tags.map! do |predefined_tag|
      predefined_tag[:selected] = true if @abstract_screening_result.tags.any? do |tag|
                                            tag.id == predefined_tag[:tag_id]
                                          end
      predefined_tag
    end

    @custom_tags.map! do |custom_tag|
      custom_tag[:selected] = true if @abstract_screening_result.tags.any? { |tag| tag.id == custom_tag[:tag_id] }
      custom_tag
    end
  end

  def asr_params
    params
      .require(:asr)
      .permit(
        :label,
        :notes
      )
  end

  def reasons_and_tags_params
    params.require(:asr).permit(
      predefined_reasons: %i[id reason_id name position selected],
      predefined_tags: %i[id tag_id name position selected],
      custom_reasons: %i[id reason_id name position selected],
      custom_tags: %i[id tag_id name position selected]
    )
  end
end
