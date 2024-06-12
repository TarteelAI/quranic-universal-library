class ProofReadCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_resource

  def create
    @resource.proof_read_comments.create proof_read_comment_params

    redirect_back fallback_location: root_path, notice: 'comment added successfully'
  end

  def index
    @comments = @resource.proof_read_comments.includes(:user)
    render layout: false
  end

  protected

  def load_resource
    resource_class, resource_id = if params[:proof_read_comment]
                                    [params[:proof_read_comment][:resource], params[:proof_read_comment][:resource_id]]
                                  else
                                    [params[:resource], params[:resource_id]]
                                  end

    @resource = resource_class
                .constantize
                .find(resource_id)
  end

  def proof_read_comment_params
    params
      .require(:proof_read_comment)
      .permit(:text).merge(user_id: current_user.id)
  end
end
