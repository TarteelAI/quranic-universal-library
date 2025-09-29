# frozen_string_literal: true

class Audio::CloneRecitationJob < ApplicationJob
  queue_as :default

  def perform(recitation_id, user_id = nil)
    recitation = Audio::Recitation.find_by(id: recitation_id)
    return unless recitation

    user = User.find_by(id: user_id) if user_id.present?
    new_rec = nil

    begin
      # DB work inside transaction
      ActiveRecord::Base.transaction do
        new_rec = clone_recitation_record(recitation)
        clone_chapter_audio_files(recitation, new_rec)
        new_rec.save!
        create_change_log_if_available(recitation, new_rec, user)
      end

      # File system copy outside transaction (safer)
      copy_audio_files_on_disk(recitation, new_rec)

      Rails.logger.info("[Audio::CloneRecitationJob] cloned recitation #{recitation.id} -> #{new_rec.id}")
    rescue => e
      Rails.logger.error("[Audio::CloneRecitationJob] error cloning recitation #{recitation.id}: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      raise
    end
  end

  private

  def clone_recitation_record(orig)
    attrs = orig.attributes.except('id', 'created_at', 'updated_at')
    attrs['name'] = "#{orig.name} (cloned)"
    base = attrs['relative_path'].to_s.chomp('/')
    timestamp = Time.now.to_i
    new_rel = base.present? ? "#{base}_cloned_#{timestamp}/" : "cloned_#{timestamp}/"
    attrs['relative_path'] = new_rel
    attrs['approved'] = false if attrs.key?('approved')
    Audio::Recitation.create!(attrs)
  end

  def clone_chapter_audio_files(orig, new_rec)
    return unless orig.respond_to?(:chapter_audio_files)

    orig.chapter_audio_files.find_each do |caf|
      new_caf = caf.dup

      # set relation to new recitation using common fk names
      if new_caf.respond_to?(:audio_recitation=)
        new_caf.audio_recitation = new_rec
      elsif new_caf.respond_to?(:recitation_id=)
        new_caf.recitation_id = new_rec.id
      elsif new_caf.respond_to?(:audio_recitation_id=)
        new_caf.audio_recitation_id = new_rec.id
      end

      # update path/url fields if they embed relative_path
      %i[audio_url file_path relative_path].each do |attr|
        next unless new_caf.respond_to?(attr) && new_caf[attr].present?
        new_caf[attr] = new_caf[attr].to_s.gsub(orig.relative_path.to_s, new_rec.relative_path.to_s)
      end

      new_caf.save!

      # collect segment association
      segments_enum = if caf.respond_to?(:audio_segments)
                        caf.audio_segments
                      elsif caf.respond_to?(:segments)
                        caf.segments
                      else
                        nil
                      end

      next unless segments_enum

      segments_enum.find_each do |seg|
        begin
          new_seg = seg.dup

          # prefer common FK: audio_file_id
          if new_seg.respond_to?(:audio_file_id=)
            new_seg.audio_file_id = new_caf.id
          elsif new_seg.respond_to?(:chapter_audio_file_id=)
            new_seg.chapter_audio_file_id = new_caf.id
          elsif new_seg.respond_to?(:audio_chapter_audio_file_id=)
            new_seg.audio_chapter_audio_file_id = new_caf.id
          end

          # update any path/url fields inside segment
          %i[file_path audio_url].each do |attr|
            if new_seg.respond_to?(attr) && new_seg[attr].present?
              new_seg[attr] = new_seg[attr].to_s.gsub(orig.relative_path.to_s, new_rec.relative_path.to_s)
            end
          end

          new_seg.save!
        rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
          Rails.logger.warn("[Audio::CloneRecitationJob] skipped creating segment for original segment id=#{seg.id} due to uniqueness: #{e.message}")
          next
        rescue => e
          Rails.logger.error("[Audio::CloneRecitationJob] failed to clone segment id=#{seg.id}: #{e.class} - #{e.message}")
          raise
        end
      end
    end
  end

  def copy_audio_files_on_disk(orig, new_rec)
    old_rel = orig.relative_path.to_s
    new_rel = new_rec.relative_path.to_s
    return if old_rel.blank?

    public_dir = Rails.root.join('public')
    old_dir = public_dir.join(old_rel)
    new_dir = public_dir.join(new_rel)

    if Dir.exist?(old_dir)
      FileUtils.mkdir_p(new_dir)
      FileUtils.cp_r(Dir.glob("#{old_dir}/*"), new_dir)
      Rails.logger.info("[Audio::CloneRecitationJob] copied files from #{old_dir} to #{new_dir}")
    else
      Rails.logger.info("[Audio::CloneRecitationJob] source audio dir not found on disk: #{old_dir}. Skipping file copy.")
    end
  rescue => e
    Rails.logger.error("[Audio::CloneRecitationJob] file copy failed: #{e.class} - #{e.message}")
  end

  def create_change_log_if_available(orig, new_rec, user)
    change_log_class =
      if defined?(Audio::ChangeLog)
        Audio::ChangeLog
      elsif defined?(Audio::AudioChangeLog)
        Audio::AudioChangeLog
      else
        nil
      end

    return unless change_log_class

    change_log_class.create!(
      audio_recitation_id: new_rec.id,
      mini_desc: "Cloned from #{orig.id} by #{user&.id || 'system'}"
    )
  rescue => e
    Rails.logger.error("[Audio::CloneRecitationJob] change log create failed: #{e.class} - #{e.message}")
  end
end
