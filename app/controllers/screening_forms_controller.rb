class ScreeningFormsController < ApplicationController
  def index
    @project = Project.find(params[:project_id])

    respond_to do |format|
      format.json do
        @screening_form = ScreeningForm.find_or_create_by(project: @project, form_type: params[:form_type])
        render json: [
          { id: 1,
            name: 'Question 1',
            description: 'Lorem ipsum dolor sit amet consectetur adipisicing elit. Nostrum eius ipsa quod. Culpa accusamus, commodi vero voluptates velit quam sunt laboriosam impedit, nisi est temporibus in sint natus quae aperiam!' },
          { id: 2,
            name: 'Question 2',
            description: 'Lorem ipsum dolor sit amet consectetur adipisicing elit. Nostrum eius ipsa quod. Culpa accusamus, commodi vero voluptates velit quam sunt laboriosam impedit, nisi est temporibus in sint natus quae aperiam!' },
          { id: 3,
            name: 'Question 3',
            description: 'Lorem ipsum dolor sit amet consectetur adipisicing elit. Nostrum eius ipsa quod. Culpa accusamus, commodi vero voluptates velit quam sunt laboriosam impedit, nisi est temporibus in sint natus quae aperiam!' },
          { id: 4,
            name: 'Question 4',
            description: 'Lorem ipsum dolor sit amet consectetur adipisicing elit. Nostrum eius ipsa quod. Culpa accusamus, commodi vero voluptates velit quam sunt laboriosam impedit, nisi est temporibus in sint natus quae aperiam!' }
        ]
      end
      format.html
    end
  end
end
