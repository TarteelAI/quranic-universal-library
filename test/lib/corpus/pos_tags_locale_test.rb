require_relative '../../test_helper'
require 'yaml'
require_relative '../../../lib/corpus/morphology/unsupported_operation_exception'
require_relative '../../../lib/corpus/morphology/part_of_speech'

class PosTagsLocaleTest < Minitest::Test
  ROOT = File.expand_path('../../..', __dir__)

  %w[en ar].each do |locale|
    define_method("test_every_pos_tag_has_#{locale}_label") do
      keys = YAML.load_file(File.join(ROOT, "config/locales/morphology/pos_tags.#{locale}.yml"))
                 .dig(locale, 'morphology', 'pos_tags').keys
      missing = Corpus::Morphology::PartOfSpeech.all.map(&:tag) - keys
      assert_equal [], missing
    end
  end
end
