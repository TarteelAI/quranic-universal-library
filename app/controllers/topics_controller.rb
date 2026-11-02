class TopicsController < CommunityController
  before_action :authenticate_user!, only: %i[edit update]

  def index
  end

  def show
  end

  def edit
  end

  def update
    topic = @presenter.topic

    if suggestion_acknowledged? && topic.save_suggestions(topic_params, current_user)
      redirect_to topic_path(topic.id), notice: "Your suggestion is saved. The topic is updated once it's approved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def topic_params
    params.require(:topic).permit(:name, :arabic_name, :description, :add_verse_keys, :comment, keep_verse_ids: [])
  end

  def init_presenter
    @presenter = TopicsPresenter.new(self)
  end
end
