require 'spec_helper'

describe Cannonbol do
  
  class CB < Cannonbol::Cannonbol
  end

  it 'has a version number' do
    expect(Cannonbol::VERSION).not_to be nil
  end
  
  it 'can build and match a simple pattern' do
    expect('hello'.match('he said hello to her')).to eq('hello')
    expect('hello'.match('he said goodby to her')).to be_falsy
  end

  it 'can match alternatives' do
    say_hello_or_goodby = 'hello' | 'goodby'
    expect(say_hello_or_goodby.match('he said hello!')).to eq('hello')
    expect(say_hello_or_goodby.match('he said goodby!')).to eq('goodby')
    expect(say_hello_or_goodby.match('he said gaday mate!')).to be_falsy
  end

  it 'can match concatenated patterns' do
    expect(('this' & 'that' & 'the' & 'other').match('i can match thisthattheother okay!')).to eq('thisthattheother')
  end
  
  if false
  
  it 'can call a block on a submatch' do
    CB.new do
      "'" & ('hello' | 'goodby').on_success do |match|
          expect(match).to eq('hello')
        end & "'"
    end.match("it was great to say 'hello' today")
  end
  
  it 'can backtrack' do
    expect(CB.new { ('B' | 'BA' | 'BAT') & ('A' | 'TER') & 's' }.match('BATTERs UP!')).to eq('BATTERs')
  end
end
end
