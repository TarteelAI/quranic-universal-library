module Morphology
  module Treebank
    # Builds the display label for a dependency relation.
    #
    # NoorBayan marks the subject and predicate of kāna, inna and their sisters
    # as `subj<<in>>` / `pred<<kan>>`; the importer keeps the relation (`subj`)
    # and the governor word (إنّ) apart. The subject of those words is their
    # اسم, not a فاعل, so "subj + governor" needs its own wording rather than
    # the plain relation name followed by the governor.
    module RelationLabel
      GOVERNED = %w[subj pred].freeze

      DEFAULT_TRANSLATOR = lambda do |key, locale:, default:|
        I18n.t(key, locale: locale, default: default)
      end

      def self.call(rel_label, governor = nil, locale:, translator: DEFAULT_TRANSLATOR)
        rel = rel_label.to_s
        return '' if rel.strip.empty?

        gov = governor.to_s.strip
        if !gov.empty? && GOVERNED.include?(rel)
          template = translator.call("morphology.irab.governed.#{rel}", locale: locale, default: '')
          return template.gsub('%{governor}', gov) if template.is_a?(String) && template.include?('%{governor}')
        end

        base = translator.call("morphology.edge_relations.#{rel}", locale: locale, default: rel)
        [base, gov].reject { |s| s.to_s.strip.empty? }.join(' ')
      end
    end
  end
end
