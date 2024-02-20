class ScreeningFormsController < ApplicationController
  def index
    @project = Project.find(params[:project_id])
    authorize(@project, policy_class: ScreeningFormPolicy)
    @nav_buttons.push('form_builder_dropdown', 'screening_form_builder', 'my_projects')

    respond_to do |format|
      format.json do
        return render json: { errors: ['invalid form type'], status: 400 } unless %w[fulltext
                                                                                     abstract].include?(params[:form_type])

        @screening_form = ScreeningForm.find_or_create_by(project: @project, form_type: params[:form_type])
        @screening_form = ScreeningForm.includes(
          sf_questions: [
            {
              sf_rows: { sf_cells: %i[sf_options sf_abstract_records] },
              sf_columns: { sf_cells: %i[sf_options sf_abstract_records] }
            }
          ]
        ).where(id: @screening_form.id).first
      end
      format.html
    end
  end
end
