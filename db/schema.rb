# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2025_09_16_073555) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_admin_comments", id: :serial, force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_id", null: false
    t.string "resource_type", null: false
    t.string "author_type"
    t.integer "author_id"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource_type_and_resource_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id"
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admin_todos", force: :cascade do |t|
    t.string "description"
    t.boolean "is_finished"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "resource_content_id"
    t.string "tags"
    t.index ["resource_content_id"], name: "index_admin_todos_on_resource_content_id"
  end

  create_table "admin_users", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["confirmation_token"], name: "index_admin_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_admin_users_on_unlock_token", unique: true
  end

  create_table "contact_messages", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.text "detail"
    t.string "subject"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "contributors", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.text "description"
    t.boolean "published", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "database_backups", force: :cascade do |t|
    t.string "database_name"
    t.string "file"
    t.string "size"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "tag"
  end

  create_table "downloadable_files", force: :cascade do |t|
    t.bigint "downloadable_resource_id", null: false
    t.string "name"
    t.integer "position", default: 1
    t.integer "download_count", default: 0
    t.string "file_type"
    t.string "token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "published", default: true
    t.text "info"
    t.index ["downloadable_resource_id"], name: "index_downloadable_files_on_downloadable_resource_id"
    t.index ["token"], name: "index_downloadable_files_on_token"
  end

  create_table "downloadable_related_resources", force: :cascade do |t|
    t.integer "downloadable_resource_id"
    t.integer "related_resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "downloadable_resource_taggings", force: :cascade do |t|
    t.integer "downloadable_resource_id", null: false
    t.integer "downloadable_resource_tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["downloadable_resource_id", "downloadable_resource_tag_id"], name: "index_downloadable_resource_tag"
  end

  create_table "downloadable_resource_tags", force: :cascade do |t|
    t.string "name"
    t.string "glossary_term"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug"
    t.string "color_class"
    t.integer "resources_count"
    t.index ["name"], name: "index_downloadable_resource_tags_on_name"
  end

  create_table "downloadable_resources", force: :cascade do |t|
    t.string "name"
    t.integer "resource_content_id"
    t.string "resource_type"
    t.integer "position", default: 1
    t.string "tags"
    t.text "info"
    t.string "cardinality_type"
    t.boolean "published", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "language_id"
    t.integer "files_count", default: 0
    t.jsonb "meta_data", default: {}
  end

  create_table "draft_contents", force: :cascade do |t|
    t.string "text"
    t.string "location"
    t.integer "chapter_id"
    t.integer "verse_id"
    t.integer "word_id"
    t.text "draft_text"
    t.text "current_text"
    t.boolean "imported"
    t.boolean "need_review"
    t.boolean "text_matched"
    t.integer "resource_content_id"
    t.jsonb "meta_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chapter_id"], name: "index_draft_contents_on_chapter_id"
    t.index ["imported"], name: "index_draft_contents_on_imported"
    t.index ["location"], name: "index_draft_contents_on_location"
    t.index ["need_review"], name: "index_draft_contents_on_need_review"
    t.index ["resource_content_id"], name: "index_draft_contents_on_resource_content_id"
    t.index ["text_matched"], name: "index_draft_contents_on_text_matched"
    t.index ["verse_id"], name: "index_draft_contents_on_verse_id"
    t.index ["word_id"], name: "index_draft_contents_on_word_id"
  end

  create_table "draft_foot_notes", force: :cascade do |t|
    t.text "draft_text"
    t.text "current_text"
    t.boolean "text_matched"
    t.integer "draft_translation_id"
    t.integer "resource_content_id"
    t.integer "true"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "foot_note_id"
    t.index ["draft_translation_id"], name: "index_draft_foot_notes_on_draft_translation_id"
    t.index ["foot_note_id"], name: "index_draft_foot_notes_on_foot_note_id"
    t.index ["text_matched"], name: "index_draft_foot_notes_on_text_matched"
  end

  create_table "draft_tafsirs", force: :cascade do |t|
    t.integer "resource_content_id"
    t.integer "tafsir_id"
    t.text "current_text"
    t.text "draft_text"
    t.boolean "imported", default: false
    t.boolean "need_review", default: false
    t.boolean "text_matched"
    t.integer "verse_id"
    t.string "verse_key"
    t.string "group_verse_key_from"
    t.string "group_verse_key_to"
    t.integer "group_verses_count"
    t.integer "group_tafsir_id"
    t.integer "start_verse_id"
    t.integer "end_verse_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "md5"
    t.string "comments"
    t.boolean "reviewed", default: false
    t.integer "user_id"
    t.jsonb "meta_data", default: {}
    t.index ["need_review"], name: "index_draft_tafsirs_on_need_review"
    t.index ["tafsir_id"], name: "index_draft_tafsirs_on_tafsir_id"
    t.index ["text_matched"], name: "index_draft_tafsirs_on_text_matched"
    t.index ["verse_id"], name: "index_draft_tafsirs_on_verse_id"
    t.index ["verse_key"], name: "index_draft_tafsirs_on_verse_key"
  end

  create_table "draft_translations", force: :cascade do |t|
    t.text "draft_text"
    t.text "current_text"
    t.boolean "text_matched"
    t.integer "verse_id"
    t.integer "resource_content_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "need_review"
    t.boolean "imported", default: false
    t.integer "user_id"
    t.integer "translation_id"
    t.integer "footnotes_count", default: 0
    t.jsonb "meta_data", default: {}
    t.integer "current_footnotes_count", default: 0
    t.index ["footnotes_count"], name: "index_draft_translations_on_footnotes_count"
    t.index ["need_review"], name: "index_draft_translations_on_need_review"
    t.index ["resource_content_id"], name: "index_draft_translations_on_resource_content_id"
    t.index ["text_matched"], name: "index_draft_translations_on_text_matched"
    t.index ["translation_id"], name: "index_draft_translations_on_translation_id"
    t.index ["verse_id"], name: "index_draft_translations_on_verse_id"
  end

  create_table "draft_word_translations", force: :cascade do |t|
    t.string "draft_text"
    t.string "current_text"
    t.string "draft_group_text"
    t.string "current_group_text"
    t.integer "current_group_word_id"
    t.integer "draft_group_word_id"
    t.integer "word_id"
    t.integer "verse_id"
    t.integer "word_translation_id"
    t.integer "language_id"
    t.integer "resource_content_id"
    t.integer "user_id"
    t.boolean "text_matched", default: false
    t.boolean "imported", default: false
    t.boolean "need_review", default: true
    t.jsonb "meta_data", default: {}
    t.string "location"
    t.integer "word_group_size", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["current_group_word_id"], name: "index_draft_word_translations_on_current_group_word_id"
    t.index ["draft_group_word_id"], name: "index_draft_word_translations_on_draft_group_word_id"
    t.index ["imported"], name: "index_draft_word_translations_on_imported"
    t.index ["language_id"], name: "index_draft_word_translations_on_language_id"
    t.index ["location"], name: "index_draft_word_translations_on_location"
    t.index ["need_review"], name: "index_draft_word_translations_on_need_review"
    t.index ["resource_content_id"], name: "index_draft_word_translations_on_resource_content_id"
    t.index ["text_matched"], name: "index_draft_word_translations_on_text_matched"
    t.index ["verse_id"], name: "index_draft_word_translations_on_verse_id"
    t.index ["word_group_size"], name: "index_draft_word_translations_on_word_group_size"
    t.index ["word_id"], name: "index_draft_word_translations_on_word_id"
    t.index ["word_translation_id"], name: "index_draft_word_translations_on_word_translation_id"
  end

  create_table "dummy", force: :cascade do |t|
  end

  create_table "faqs", force: :cascade do |t|
    t.string "question"
    t.text "answer"
    t.integer "position"
    t.boolean "published", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position", "published"], name: "index_faqs_on_position_and_published"
  end

  create_table "feedbacks", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "url"
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "important_notes", force: :cascade do |t|
    t.text "text"
    t.string "label"
    t.integer "user_id"
    t.integer "verse_id"
    t.integer "word_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "title"
  end

  create_table "morphology_matching_verses", force: :cascade do |t|
    t.integer "chapter_id"
    t.integer "verse_id"
    t.integer "words_count"
    t.integer "matched_words_count"
    t.integer "coverage"
    t.integer "score"
    t.jsonb "matched_word_positions", default: []
    t.integer "matched_verse_id"
    t.integer "matched_chapter_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "approved"
    t.index ["chapter_id"], name: "index_morphology_matching_verses_on_chapter_id"
    t.index ["coverage"], name: "index_morphology_matching_verses_on_coverage"
    t.index ["matched_chapter_id"], name: "index_morphology_matching_verses_on_matched_chapter_id"
    t.index ["matched_verse_id"], name: "index_morphology_matching_verses_on_matched_verse_id"
    t.index ["matched_words_count"], name: "index_morphology_matching_verses_on_matched_words_count"
    t.index ["score"], name: "index_morphology_matching_verses_on_score"
    t.index ["verse_id"], name: "index_morphology_matching_verses_on_verse_id"
    t.index ["words_count"], name: "index_morphology_matching_verses_on_words_count"
  end

  create_table "morphology_phrase_verses", force: :cascade do |t|
    t.integer "phrase_id"
    t.integer "verse_id"
    t.integer "word_position_from"
    t.integer "word_position_to"
    t.jsonb "missing_word_positions", default: []
    t.jsonb "similar_words_position", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "matched_words_count"
    t.boolean "approved"
    t.string "review_status"
    t.index ["phrase_id"], name: "index_morphology_phrase_verses_on_phrase_id"
    t.index ["verse_id"], name: "index_morphology_phrase_verses_on_verse_id"
    t.index ["word_position_from"], name: "index_morphology_phrase_verses_on_word_position_from"
    t.index ["word_position_to"], name: "index_morphology_phrase_verses_on_word_position_to"
  end

  create_table "morphology_phrases", force: :cascade do |t|
    t.string "text_qpc_hafs_simple"
    t.string "text_qpc_hafs"
    t.integer "source_verse_id"
    t.integer "word_position_from"
    t.integer "word_position_to"
    t.integer "words_count"
    t.integer "chapters_count"
    t.integer "verses_count"
    t.integer "occurrence"
    t.boolean "approved", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "review_status"
    t.integer "phrase_type"
    t.integer "source"
    t.index ["approved"], name: "index_morphology_phrases_on_approved"
    t.index ["phrase_type"], name: "index_morphology_phrases_on_phrase_type"
    t.index ["source_verse_id"], name: "index_morphology_phrases_on_source_verse_id"
    t.index ["word_position_from"], name: "index_morphology_phrases_on_word_position_from"
    t.index ["word_position_to"], name: "index_morphology_phrases_on_word_position_to"
    t.index ["words_count"], name: "index_morphology_phrases_on_words_count"
  end

  create_table "mushaf_line_alignments", force: :cascade do |t|
    t.integer "mushaf_id"
    t.string "alignment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "properties", default: {}
    t.integer "page_number"
    t.integer "line_number"
    t.jsonb "meta_data", default: {}
    t.index ["line_number"], name: "index_mushaf_line_alignments_on_line_number"
    t.index ["mushaf_id"], name: "index_mushaf_line_alignments_on_mushaf_id"
    t.index ["page_number"], name: "index_mushaf_line_alignments_on_page_number"
  end

  create_table "pause_marks", id: :serial, force: :cascade do |t|
    t.integer "word_id"
    t.string "verse_key"
    t.integer "position"
    t.string "mark"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["word_id"], name: "index_pause_marks_on_word_id"
  end

  create_table "proof_read_comments", force: :cascade do |t|
    t.bigint "user_id"
    t.string "resource_type", null: false
    t.bigint "resource_id", null: false
    t.text "text"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["resource_type", "resource_id"], name: "index_proof_read_comments_on_resource_type_and_resource_id"
    t.index ["user_id"], name: "index_proof_read_comments_on_user_id"
  end

  create_table "qr_sync_histories", force: :cascade do |t|
    t.datetime "timestamp"
    t.integer "posts_count"
    t.integer "comments_count"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["timestamp"], name: "index_qr_sync_histories_on_timestamp"
  end

  create_table "quran_table_details", force: :cascade do |t|
    t.string "name"
    t.integer "records_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "raw_data_ayah_records", force: :cascade do |t|
    t.integer "verse_id"
    t.text "text"
    t.text "text_cleaned"
    t.jsonb "properties", default: {}
    t.boolean "processed", default: false
    t.integer "resource_id"
    t.string "content_css_class"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["verse_id"], name: "index_raw_data_ayah_records_on_verse_id"
  end

  create_table "raw_data_resources", force: :cascade do |t|
    t.string "name"
    t.string "sub_type"
    t.integer "language_id"
    t.string "lang_iso"
    t.integer "records_count", default: 0
    t.text "description"
    t.integer "resource_content_id"
    t.boolean "processed", default: false
    t.string "content_css_class"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sub_type"], name: "index_raw_data_resources_on_sub_type"
  end

  create_table "resource_permissions", force: :cascade do |t|
    t.integer "resource_content_id"
    t.integer "permission_to_host", default: 0
    t.integer "permission_to_share", default: 0
    t.text "permission_to_host_info"
    t.text "permission_to_share_info"
    t.string "source_info"
    t.string "contact_info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "copyright_notice"
  end

  create_table "segments_databases", force: :cascade do |t|
    t.string "name"
    t.boolean "active", default: false
  end

  create_table "synonyms", force: :cascade do |t|
    t.string "text"
    t.text "synonyms"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.jsonb "approved_synonyms", default: []
  end

  create_table "uloom_contents", force: :cascade do |t|
    t.text "text"
    t.string "cardinality_type"
    t.integer "chapter_id"
    t.integer "verse_id"
    t.integer "word_id"
    t.integer "resource_content_id"
    t.string "location"
    t.string "location_range"
    t.jsonb "meta_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cardinality_type"], name: "index_uloom_contents_on_cardinality_type"
    t.index ["chapter_id"], name: "index_uloom_contents_on_chapter_id"
    t.index ["location"], name: "index_uloom_contents_on_location"
    t.index ["location_range"], name: "index_uloom_contents_on_location_range"
    t.index ["resource_content_id"], name: "index_uloom_contents_on_resource_content_id"
    t.index ["text"], name: "index_uloom_contents_on_text"
    t.index ["verse_id"], name: "index_uloom_contents_on_verse_id"
    t.index ["word_id"], name: "index_uloom_contents_on_word_id"
  end

  create_table "user_downloads", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "downloadable_file_id", null: false
    t.datetime "last_download_at"
    t.integer "download_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["downloadable_file_id"], name: "index_user_downloads_on_downloadable_file_id"
    t.index ["user_id"], name: "index_user_downloads_on_user_id"
  end

  create_table "user_projects", force: :cascade do |t|
    t.integer "user_id"
    t.integer "resource_content_id"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "admin_notes"
    t.boolean "approved", default: false
    t.text "additional_notes"
    t.text "reason_for_request"
    t.text "language_proficiency"
    t.text "motivation_and_goals"
    t.boolean "review_process_acknowledgment"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.boolean "approved", default: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.inet "current_sign_in_ip"
    t.inet "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.datetime "confirmation_sent_at", precision: nil
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.string "projects"
    t.text "about_me"
    t.boolean "add_to_mailing_list", default: false
    t.integer "role", default: 0
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", id: :serial, force: :cascade do |t|
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.string "event", null: false
    t.string "whodunnit"
    t.text "object"
    t.datetime "created_at", precision: nil
    t.boolean "reviewed", default: false
    t.integer "reviewed_by_id"
    t.index ["reviewed"], name: "index_versions_on_reviewed"
  end

  create_table "word_synonyms", force: :cascade do |t|
    t.integer "synonym_id"
    t.integer "word_id"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["synonym_id", "word_id"], name: "index_word_synonyms_on_synonym_id_and_word_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "downloadable_files", "downloadable_resources"
  add_foreign_key "user_downloads", "downloadable_files"
  add_foreign_key "user_downloads", "users"
end
