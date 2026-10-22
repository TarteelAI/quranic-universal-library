# frozen_string_literal: true

# A suggested fix for the translation of one ayah, as the proofreading form
# edits it. Footnotes are written as {{1}}, {{2}} in the text instead of HTML,
# and the text of each footnote is edited in its own box:
#
#   "Lord of all worlds,<sup foot_note=296787>1</sup>"  <=>  "Lord of all worlds, {{1}}"
#
# The number only links a marker to its box, readers see footnotes numbered in
# order. A box with a new number is a new footnote, and removing {{n}} from the
# text removes that footnote once the suggestion is approved.
#
#   suggestion = Draft::TranslationSuggestion.new(translation)
#   suggestion.text       # "Lord of all worlds, {{1}}"
#   suggestion.footnotes  # [Footnote(key: 1, foot_note_id: 296787, text: "...")]
#   suggestion.assign(params).save(user)
module Draft
  class TranslationSuggestion
    MARKER = /\{\{\s*(\d+)\s*\}\}/
    Footnote = Struct.new(:key, :foot_note_id, :text, keyword_init: true)

    attr_reader :translation, :text, :footnotes, :comment, :errors

    def initialize(translation)
      @translation = translation
      @errors = []
      load_current
    end

    # params: text, comment and footnotes as { "1" => { foot_note_id:, text: } }
    def assign(params)
      @text = params[:text].to_s
      @comment = params[:comment].to_s.strip.presence
      @footnotes = (params[:footnotes] || {}).to_h.map do |key, note|
        id = note[:foot_note_id].to_i
        Footnote.new(key: key.to_i, foot_note_id: (id if current_notes.key?(id)), text: note[:text].to_s.strip)
      end.sort_by(&:key)
      self
    end

    def valid?
      @errors = []
      keys = marker_keys

      @errors << 'Translation text is required' if text.gsub(MARKER, '').strip.blank?
      keys.tally.select { |_, count| count > 1 }.each_key do |key|
        @errors << "{{#{key}}} is in the text more than once, each footnote can be in the text once"
      end
      keys.uniq.each do |key|
        @errors << "Footnote {{#{key}}} has no text" if footnote(key)&.text.blank?
      end
      @errors << "You haven't changed anything" if @errors.empty? && !changed?

      @errors.empty?
    end

    def save(user)
      return false unless valid?

      Draft::Translation.transaction do
        draft = Draft::Translation.new(
          translation_id: translation.id,
          verse_id: translation.verse_id,
          resource_content_id: translation.resource_content_id,
          current_text: translation.text,
          current_footnotes_count: current_notes.size,
          need_review: true,
          user: user
        )
        draft.meta_data = { 'comment' => comment, 'removed-foot-note-ids' => removed_ids }.compact_blank
        draft.draft_text = text
        draft.save!(validate: false)

        # New footnotes are linked by their draft id until the suggestion is approved
        ids = used_footnotes.to_h do |note|
          record = draft.foot_notes.create!(foot_note_id: note.foot_note_id, draft_text: note.text, resource_content_id: footnote_resource_id)
          [note.key, note.foot_note_id || record.id]
        end

        draft.draft_text = html(ids)
        draft.text_matched = draft.draft_text == translation.text
        draft.save!(validate: false)
        draft
      end
    end

    def footnote(key)
      footnotes.detect { |note| note.key == key }
    end

    def used_footnotes
      marker_keys.uniq.map { |key| footnote(key) }
    end

    # Footnotes of the current text that the suggestion takes out
    def removed_ids
      current_ids - used_footnotes.map(&:foot_note_id)
    end

    def changed?
      html(used_footnotes.to_h { |note| [note.key, note.foot_note_id || 0] }) != current_html ||
        used_footnotes.any? { |note| note.foot_note_id.nil? || note.text != current_notes[note.foot_note_id]&.text.to_s.strip }
    end

    private

    def load_current
      @footnotes = []
      @text = translation.text.to_s.gsub(Draft::Translation::FOOTNOTE_SUP_REGEXP) do
        id = Regexp.last_match(:id).to_i
        key = @footnotes.size + 1
        @footnotes << Footnote.new(key: key, foot_note_id: (id if current_notes.key?(id)), text: current_notes[id]&.text.to_s)
        " {{#{key}}}"
      end.strip
    end

    def marker_keys
      text.scan(MARKER).flatten.map(&:to_i)
    end

    def html(ids)
      index = 0
      formatted = text.gsub(MARKER) do
        index += 1
        "<sup foot_note=#{ids[Regexp.last_match(1).to_i]}>#{index}</sup>"
      end
      Utils::TextFormatter.new(formatted).format
    end

    # The current text written the way a suggestion writes it, to compare
    def current_html
      index = 0
      formatted = translation.text.to_s.gsub(Draft::Translation::FOOTNOTE_SUP_REGEXP) do
        index += 1
        "<sup foot_note=#{Regexp.last_match(:id)}>#{index}</sup>"
      end
      Utils::TextFormatter.new(formatted).format
    end

    def current_notes
      @current_notes ||= translation.foot_notes.index_by(&:id)
    end

    # Footnotes the current text links to
    def current_ids
      translation.text.to_s.scan(Draft::Translation::FOOTNOTE_SUP_REGEXP).flatten.map(&:to_i) & current_notes.keys
    end

    def footnote_resource_id
      current_notes.values.first&.resource_content_id ||
        ResourceContent.find(translation.resource_content_id).meta_value('related-footnote-resource-id')
    end
  end
end
