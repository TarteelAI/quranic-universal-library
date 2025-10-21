class SegmentsMailer < ApplicationMailer
  def send_reciter_data(user, reciter, zip_file_path)
    @user = user
    @reciter = reciter
    @zip_file_path = zip_file_path
    
    attachments["#{reciter.name.parameterize}_segments_data.zip"] = File.read(zip_file_path)
    
    mail(
      to: user.email,
      subject: "Segments Data for #{reciter.name}"
    )
  end

  def send_export_error(user, reciter, error_message)
    @user = user
    @reciter = reciter
    @error_message = error_message
    
    mail(
      to: user.email,
      subject: "Error Exporting Segments Data for #{reciter.name}"
    )
  end
end
