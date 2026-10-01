require_relative '../../../test_helper'
require_relative '../../../../app/services/morphology/noor_bayan/script_aligner'

class NoorBayanScriptAlignerTest < Minitest::Test
  Aligner = Morphology::NoorBayan::ScriptAligner

  def split(verse_text, segments)
    Aligner.new(verse_text).split(segments)
  end

  # The whole point: chapters 9-58 arrive with no tashkeel, and each token has
  # to come back carrying exactly its own share of the mushaf's marks.
  def test_restores_tashkeel_onto_unvocalised_tokens
    assert_equal %w[مَرۡجِعُ كُمۡۖ], split('مَرۡجِعُكُمۡۖ', %w[مرْجعُ كُمْ])
  end

  def test_splits_prefix_stem_and_suffix
    assert_equal %w[وَ بِ ٱلۡ كِتَٰبِ],
                 split('وَبِٱلۡكِتَٰبِ', %w[وَ بِ ٱلْ كِتَٰبِ])
  end

  # A trailing waqf sign belongs to the last token of the word, not to the next.
  def test_trailing_waqf_stays_with_the_final_token
    assert_equal %w[كُمۡۖ], split('كُمۡۖ', %w[كُمْ])
  end

  # NoorBayan spells alef-maddah as hamza + alif; the mushaf as one letter.
  def test_matches_hamza_alif_against_alef_maddah
    assert_equal %w[ٱلۡ أٓخِرَةِ], split('ٱلۡأٓخِرَةِ', %w[ٱلْ ءَاخِرَةِ])
  end

  # The interrogative hamza prefix: NoorBayan writes "ء" + "إذا", the mushaf
  # "أ" + "ءذا". The letters are in a different order, so this only works
  # through the alignment rather than a naive left-to-right walk.
  def test_handles_interrogative_hamza_prefix
    assert_equal %w[أَ ءِذَا], split('أَءِذَا', %w[ء إِذَا])
  end

  # The two sources disagree about word boundaries in a handful of places
  # (2:181 "بعدما"), which a per-word split cannot survive.
  def test_survives_word_boundary_disagreement
    assert_equal ['بَعۡدَ مَا', 'سَمِعَ', 'هُۥ'],
                 split('بَعۡدَ مَا سَمِعَهُۥ', %w[بَعْدَمَا سَمِعَ هُۥ])
  end

  # NoorBayan annotates the elided possessive ya of "rabbi" as its own token
  # whose text is nothing but a kasra: there is no letter to anchor it to, so it
  # has to claim the matching mark off the end of the stem. Written as escapes
  # because the mushaf's mark order (shadda then kasra) is what matters here and
  # is invisible in a rendered string.
  def test_places_a_mark_only_token_on_its_own_mark
    stem   = "\u0631\u064E\u0628\u0651"   # ra, fatha, ba, shadda
    kasra  = "\u0650"
    assert_equal [stem, kasra], split(stem + kasra, [stem, kasra])
  end

  # Unmappable slots come back nil so the caller can keep the original text
  # rather than render an empty token.
  def test_returns_nil_for_a_token_it_cannot_place
    assert_equal [nil], split('كِتَاب', [''])
  end

  def test_returns_nils_when_there_is_no_verse_text
    assert_equal [nil, nil], split('', %w[وَ بِ])
  end

  # Letters the two sources shape differently must not break the match.
  def test_folds_equivalent_letter_shapes
    assert_equal %w[شَيۡءٖ], split('شَيۡءٖ', %w[شىْءٍ])
  end
end
