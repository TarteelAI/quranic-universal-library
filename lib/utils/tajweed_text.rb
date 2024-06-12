# frozen_string_literal: true

module Utils
  class TajweedText
    attr_reader :text

    RULE_GHUNNA = /[ن|م]ّ/
    RULE_QALQALA = /[قطبجد](ْ|ۡ|[^ه]?[^هىا]?[^هىا]$)/

    BUCKWALTER_RULES = {
      ham_wasl: {
        identifier: /\[h/,
        css_class: 'ham_wasl'
      },

      silent: {
        identifier: /\[s/,
        css_class: 'slnt'
      },

      laam_shamsiyah: {
        identifier: /\[l/,
        css_class: 'laam_shamsiyah'
      },

      madda_normal: {
        identifier: /\[n/,
        css_class: 'madda_normal'
      },

      madda_permissible: {
        identifier: /\[p/,
        css_class: 'madda_permissible'
      },

      madda_necessary: {
        identifier: /\[m/,
        css_class: 'madda_necessary'
      },

      madda_obligatory: {
        identifier: /\[o/,
        css_class: 'madda_obligatory'
      },

      qalaqah: {
        identifier: /\[q/,
        css_class: 'qalaqah'
      },

      ikhafa_shafawi: {
        identifier: /\[c/,
        css_class: 'ikhafa_shafawi'
      },

      ikhafa: {
        identifier: /\[f/,
        css_class: 'ikhafa'
      },

      iqlab: {
        identifier: '[i',
        css_class: 'iqlab'
      },

      idgham_shafawi: {
        identifier: '[w',
        css_class: 'idgham_shafawi'
      },

      idgham_ghunnah: {
        identifier: '[a',
        css_class: 'idgham_ghunnah'
      },

      idgham_wo_ghunnah: {
        identifier: '[u',
        css_class: 'idgham_wo_ghunnah'
      },

      idgham_mutajanisayn: {
        identifier: '[d',
        css_class: 'idgham_mutajanisayn'
      },

      idgham_mutaqaribayn: {
        identifier: '[b',
        css_class: 'idgham_mutaqaribayn'
      },

      ghunnah: {
        identifier: '[g',
        css_class: 'ghunnah'
      }
    }.freeze

    def initialize(text)
      @text = text
    end

    def to_tajweed
      tajweed_text = text.clone

      tajweed_text.gsub!(RULE_GHUNNA) do |part|
        "<span class=qal>#{part}</span>"
      end

      tajweed_text!.gsub!(RULE_QALQALA) do |part|
        "<span class=qal>#{part}</span>"
      end

      tajweed_text
    end

    def parse_buckwalter_tajweed(text)
      BUCKWALTER_RULES.each_value do |rule|
        text.gsub! rule[:identifier] do
          "<tajweed class=#{rule[:css_class]}"
        end
      end

      text.gsub! /\[/, '>'
      text.gsub! /\]/, '</tajweed>'
      text.gsub! /:\d+/, ''

      text
    end
  end
end
