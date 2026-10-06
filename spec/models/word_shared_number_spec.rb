# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Word, 'shared number columns' do
  it 'has the four columns with safe defaults' do
    cols = Word.columns_hash
    expect(cols['number'].type).to eq(:integer)
    expect(cols['number_last'].type).to eq(:integer)
    expect(cols['hafs_reads'].default).to eq('true')
    expect(cols['hafs_reads'].null).to be(false)
    expect(cols['sub_position'].default).to eq('0')
    expect(cols['sub_position'].null).to be(false)
  end

  it 'leaves every existing word readable by Hafs with no number yet' do
    words = Word.unscoped.where(verse_id: Verse.find_by!(verse_key: '1:1').id)
    expect(words.where(hafs_reads: false)).to be_empty
    expect(words.where.not(sub_position: 0)).to be_empty
  end

  it 'exposes Word.hafs and leaves the default scope alone' do
    expect(Word.hafs.to_sql).to include('"hafs_reads" = TRUE')
    expect(Word.unscoped.hafs.count).to eq(Word.unscoped.count - Word.unscoped.where(hafs_reads: false).count)
    expect(Word.all.to_sql).not_to include('hafs_reads')
  end

  it 'enforces uniqueness of number where set' do
    a, b = Word.unscoped.where(verse_id: Verse.find_by!(verse_key: '1:1').id).order(:position).first(2)
    a.update_columns(number: 1)
    expect { b.update_columns(number: 1) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
