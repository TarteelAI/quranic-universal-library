require_relative '../test_helper'
require 'yaml'

class MorphologyLocalesTest < Minitest::Test
  LOCALES_DIR = File.expand_path('../../config/locales/morphology', __dir__)
  FILES = %w[edge_relations irab pos_tags special_groups].freeze

  def self.flatten(tree, path = [])
    tree.each_with_object({}) do |(key, value), acc|
      full = path + [key.to_s]
      value.is_a?(Hash) ? acc.merge!(flatten(value, full)) : acc[full.join('.')] = value
    end
  end

  def self.problems(reference, candidate)
    ref = flatten(reference)
    cand = flatten(candidate)
    missing = (ref.keys - cand.keys).map { |k| "missing #{k}" }
    extra = (cand.keys - ref.keys).map { |k| "extra #{k}" }
    blank = (cand.keys & ref.keys).select { |k| cand[k].to_s.strip.empty? && !ref[k].to_s.strip.empty? }.map { |k| "blank #{k}" }
    missing + extra + blank
  end

  def load_locale(name, locale)
    path = File.join(LOCALES_DIR, "#{name}.#{locale}.yml")
    assert File.exist?(path), "#{name}.#{locale}.yml is missing"
    YAML.load_file(path)
  end

  FILES.each do |name|
    define_method("test_#{name}_ru_mirrors_en") do
      en = load_locale(name, 'en')
      ru = load_locale(name, 'ru')
      assert_equal ['ru'], ru.keys, "#{name}.ru.yml must have a single root key ru"
      assert_equal [], self.class.problems(en['en'], ru['ru']), "#{name}.ru.yml differs from #{name}.en.yml"
    end
  end

  def test_problems_accepts_identical_structure
    en = { 'morphology' => { 'irab' => { 'prefix' => { 'Al+' => 'definite article' }, 'def_infix' => '' } } }
    ru = { 'morphology' => { 'irab' => { 'prefix' => { 'Al+' => 'определённый артикль' }, 'def_infix' => '' } } }
    assert_equal [], self.class.problems(en, ru)
  end

  def test_problems_reports_missing_extra_and_blank_keys
    en = { 'morphology' => { 'pos_tags' => { 'N' => 'Noun', 'V' => 'Verb', 'P' => 'Preposition' } } }
    ru = { 'morphology' => { 'pos_tags' => { 'N' => 'Имя', 'V' => '  ', 'X' => 'Лишнее' } } }
    assert_equal ['missing morphology.pos_tags.P', 'extra morphology.pos_tags.X', 'blank morphology.pos_tags.V'],
                 self.class.problems(en, ru)
  end

  def test_problems_tracks_nested_paths
    en = { 'a' => { 'b' => { 'c' => 'x' } } }
    ru = { 'a' => { 'b' => 'x' } }
    assert_equal ['missing a.b.c', 'extra a.b'], self.class.problems(en, ru)
  end

  def test_en_files_mirror_themselves
    FILES.each do |name|
      en = load_locale(name, 'en')
      assert_equal [], self.class.problems(en['en'], en['en']), name
    end
  end
end
