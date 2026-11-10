# Catalog resources, files and accounts for the download specs. The files point at blobs that
# exist only as rows (nothing is uploaded), so a download redirects to a storage URL of a file
# made for the spec, never to a real file.
module DownloadFiles
  PASSWORD = 'spec-password'

  # A resource needs a content row no other resource uses (the two are in separate databases).
  def free_resource_content
    ResourceContent.where.not(id: DownloadableResource.where.not(resource_content_id: nil).pluck(:resource_content_id))
                   .order(:id).first
  end

  def create_download_resource(published: true, restricted: false)
    DownloadableResource.create!(
      name: "Spec download resource #{SecureRandom.hex(3)}", resource_type: 'tafsir', cardinality_type: '1_ayah',
      published: published, resource_content: free_resource_content,
      meta_data: restricted ? { 'copyright' => 'Spec restriction' } : {}
    )
  end

  def create_download_file(resource, published: true)
    file = resource.downloadable_files.create!(name: 'spec.json', file_type: 'json', published: published)
    file.file.attach(
      ActiveStorage::Blob.create!(key: "spec-downloads/#{SecureRandom.hex}", filename: 'spec.json.zip',
                                  content_type: 'application/zip', byte_size: 1, checksum: 'c3BlYw==',
                                  service_name: 'qul_exports', metadata: { identified: true, analyzed: true })
    )
    file
  end

  def create_account(role: :normal_user)
    User.new(email: "spec-#{SecureRandom.hex(4)}@example.test", first_name: 'Spec', last_name: 'Account',
             password: PASSWORD, role: role).tap do |user|
      user.skip_confirmation!
      user.save!
    end
  end
end
