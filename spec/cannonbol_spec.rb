require 'spec_helper'

describe Cannonbol do

  it 'has a version number' do
    expect(Cannonbol::VERSION).not_to be nil
  end
  
  it 'can build and match a simple pattern' do
    expect('hello'.match?('he said hello to her')).to eq('hello')
    expect('hello'.match?('he said goodby to her')).to be_falsy
  end

  it 'can match alternatives' do
    say_hello_or_goodby = 'hello' | 'goodby'
    expect(say_hello_or_goodby.match?('he said hello!')).to eq('hello')
    expect(say_hello_or_goodby.match?('he said goodby!')).to eq('goodby')
    expect(say_hello_or_goodby.match?('he said gaday mate!')).to be_falsy
  end

  it 'can match concatenated patterns' do
    expect(('this' & 'that' & 'the' & 'other').match?('i can match thisthattheother okay!')).to eq('thisthattheother')
  end
  
  it "will backtrack to match a pattern" do
    expect(('can' & ('n' | 'non') & ('o' | 'b') & 'ol').match?('snobol4 + ruby = cannonbol!')).to eq('cannonbol')
  end
  
  it "can can generate an empty pattern" do
    expect((Cannonbol.new & "hello").match?("hello world")).to eq('hello')
  end
  
  
  it 'can call a block on a submatch' do
    ("'" & ('so long' | 'hello' | 'goodby').on_success { |match| expect(match).to eq('hello')} & "'").match?("it was great to say 'hello' today")
  end
  
  it 'wont call a success block if the match fails' do
    block_was_called = false
    ("'" & ('so long' | 'hello' | 'goodby').on_success { |match| block_was_called = true } & "'").match?("it was great to say 'sawadii kaap' today")
    expect(block_was_called).to be_falsy
  end
  
  it 'can use the rem builtin pattern' do
    expect("hello".rem.match?('he said hello to her')).to eq('hello to her')
  end
  
  it 'can use the arb builtin pattern' do
    ("O" & ''.arb.on_success { |match| expect(match).to eq('UNT') } & "A").match?('MOUNTAIN') 
    ("O" & ''.arb.on_success { |match| expect(match).to eq('') } & "U").match?('MOUNTAIN')
    expect(("O" & ''.arb & "Z").match?('MOUNTAIN')).to be_falsy
  end
  
  it 'can use the len builtin pattern' do
    expect(( ("Z" | "I" | "U").len(36) & ("ME" | "U")).match?("Hey! I am separated by 36 characters from U")).to be_truthy
    expect(( ("Z" | "I" | "U").len(35) & ("ME" | "U")).match?("Hey! I am separated by 36 characters from U")).to be_falsy
  end
  
  it 'can delay evaluation of parameters to builtin patterns' do
    expected_length = nil
    pattern = ("Z" | "I" | "U").len {expected_length} & ("ME" | "U")
    expected_length = 36
    expect(pattern.match?("Hey! I am separated by 36 characters from U")).to be_truthy
    expected_length = 3
    expect(pattern.match?("Z123ME")).to be_truthy
  end
  
  it 'can use pos and rpos builtin patterns' do
    s = 'ABCDA'
    expect((''.pos(0) & 'B').match?(s)).to be_falsy
    ''.len(3).on_success { |match| expect(match).to be('CDA') }.rpos(0).match?(s)
    ''.pos(3) & (''.len(1).on_success { |match| expect(match).to be('D') }).match?(s)
    expect((''.pos(0) & 'ABCD'.rpos(0)).match?(s)).to be_falsy
  end
  
  it 'can use tab and rtab builtin patterns' do
    s = '   X1234ABCD9012345XYZZY'
    ( 'X'.len(4) & 
      (''.tab(12).on_success { |match| expect(match).to be('ABCD') }) & 
      (''.rtab(5).on_success { |match| expect(match).to be('9012345XYZZY') })
    ).match?(s)
  end

end
