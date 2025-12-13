class WordMistakesController < AdminsController
  def show
  end

  def word_details
    render layout: false
  rescue ActiveRecord::RecordNotFound => e
    render plain: e.message, status: :not_found
  end

  def edit
  end

  def update
    update_presenter = WordMistakeUpdatePresenter.new(params[:mistakes], @presenter.page_number)
    update_presenter.update!

    respond_to do |format|
      format.html { redirect_to mistake_heatmap_path(page: @presenter.page_number), notice: 'Mistakes saved successfully.' }
      format.json { head :ok }
    end
  rescue => e
    respond_to do |format|
      format.html do
        flash[:alert] = "Error saving mistakes: #{e.message}"
        redirect_to edit_mistake_heatmap_path(page: @presenter.page_number)
      end
      format.json { render json: { error: e.message }, status: :unprocessable_entity }
    end
  end

  private

  def init_presenter
    @presenter = WordMistakesPresenter.new(self)
  end
end
