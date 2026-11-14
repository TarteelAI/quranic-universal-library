require 'clone_helper'

# The catalog search folds the query and the indexed text with the same normalizer, so text
# that differs only in the ways below matches.
RSpec.describe Catalog::TextKey do
  {
    'Latin accents' => ['Türkçe Çeviri', 'turkce ceviri'],
    'a decomposed Latin accent' => ["Bośnian", 'bosnian'],
    'Latin case' => ['ENGLISH Saheeh', 'english saheeh'],
    'a Latin ligature' => ['ﬁqh', 'fiqh'],
    'Arabic harakat' => ['تَفْسِيرُ السَّعْدِيِّ', 'تفسير السعدي'],
    'the Arabic superscript alef' => ['الرَّحْمَٰن', 'الرحمن'],
    'tatweel' => ['تفسيـــر', 'تفسير'],
    'alef with hamza above' => ['أحمد', 'احمد'],
    'alef with hamza below' => ['إسلام', 'اسلام'],
    'alef with madda' => ['آية', 'ايه'],
    'alef wasla' => ['ٱلقرآن', 'القران'],
    'alef maksura' => ['موسى', 'موسي'],
    'Farsi ya' => ['فارسی', 'فارسي'],
    'ya with hamza' => ['مائة', 'مايه'],
    'ta marbuta' => ['العربية', 'العربيه'],
    'harakat and letter variants together' => ['الْعَرَبِيَّة', 'العربيه'],
    'Arabic presentation forms' => ['ﻻ', 'لا'],
    'punctuation and spacing' => ["  Ibn-Kathir's\ttafsir ", 'ibn kathir s tafsir']
  }.each do |label, (text, key)|
    it "folds #{label}" do
      expect(described_class.call(text)).to eq(key)
      expect(described_class.call(key)).to eq(key)
    end
  end

  it 'keeps letters that are not variants of each other apart' do
    expect(described_class.call('تفسير')).not_to eq(described_class.call('تفسر'))
    expect(described_class.call('ه')).not_to eq(described_class.call('ت'))
    expect(described_class.call('ي')).not_to eq(described_class.call('ا'))
  end

  it 'gives an empty key for nil and blank text' do
    expect(described_class.call(nil)).to eq('')
    expect(described_class.call(" ـ ")).to eq('')
  end
end
