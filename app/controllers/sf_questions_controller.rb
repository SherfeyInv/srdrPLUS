class SfQuestionsController < ApplicationController
  def create
    @screening_form = ScreeningForm.find(params[:screening_form_id])
    respond_to do |format|
      format.json do
        @screening_form.sf_questions.create!
        render json: {}
      end
    end
  end

  def update
    @sf_question = SfQuestion.find(params[:id])
    respond_to do |format|
      format.json do
        @sf_question.update(params.permit(:name, :description))
        render json: @sf_question
      end
    end
  end

  def destroy
    @sf_question = SfQuestion.find(params[:id])
    respond_to do |format|
      format.json do
        @sf_question.destroy
        render json: {}
      end
    end
  end
end
