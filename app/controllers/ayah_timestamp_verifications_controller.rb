# frozen_string_literal: true

class AyahTimestampVerificationsController < CommunityController
  before_action :authenticate_user!, only: [:create]

  def show
    @payload = AyahTimestampVerification::RandomSegment.new(user: current_user).call
  end

  def create
    result = AyahTimestampVerification::VoteRecorder.new(
      user: current_user,
      audio_segment_id: params[:audio_segment_id],
      vote: params[:vote],
    ).call

    if result.success?
      redirect_to ayah_timestamp_verification_path, notice: "Thanks — recorded as #{result.vote.vote}."
    else
      redirect_to ayah_timestamp_verification_path, alert: result.error
    end
  end
end
