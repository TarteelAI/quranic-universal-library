module Morphology
  module Treebank
    module Colors
      RELATION_COLORS = {
        'adj'   => 'purple',
        'app'   => 'sky',
        'circ'  => 'seagreen',
        'cog'   => 'seagreen',
        'com'   => 'metal',
        'cond'  => 'orange',
        'conj'  => 'navy',
        'cpnd'  => 'sky',
        'gen'   => 'rust',
        'int'   => 'orange',
        'intg'  => 'rose',
        'link'  => 'orange',
        'neg'   => 'red',
        'obj'   => 'metal',
        'pass'  => 'sky',
        'poss'  => 'sky',
        'pred'  => 'metal',
        'predx' => 'metal',
        'prev'  => 'orange',
        'pro'   => 'red',
        'prp'   => 'metal',
        'spec'  => 'sky',
        'sub'   => 'gold',
        'subj'  => 'sky',
        'subjx' => 'sky',
        'voc'   => 'green',
        'CS'    => 'orange',
        'PP'    => 'rust',
        'SC'    => 'gold',
        'VS'    => 'seagreen',
        'NS'    => 'sky',
        'S'     => 'sky'
      }.freeze

      def self.pos(pos_key)
        key = pos_key.to_s.downcase.to_sym
        Morphology::WordSegment::POS_TAG_COLORS[key] || 'pink'
      end

      def self.relation(rel_label)
        RELATION_COLORS[rel_label.to_s] || 'metal'
      end
    end
  end
end
