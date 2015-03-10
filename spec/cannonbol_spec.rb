require 'spec_helper'

describe Cannonbol do

  it 'has a version number' do
    expect(Cannonbol::VERSION).not_to be nil
  end
  
  it 'can build and match a simple pattern' do
    expect('hello'.match?('he said hello to her')).to eq('hello')
    expect('hello'.match?('he said goodby to her')).to be_falsy
  end
  
  it 'can run in anchor mode' do
    expect('hello'.match?('he should have said hello first', anchor: true)).to be_falsy
    expect('hello'.match?('he should have said hello first')).to be_truthy
  end
  
  it 'can raise an error on failure' do
    expect { 'hello'.match?('never say goodby', raise_error: true) }.to raise_error
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
  
  it 'can call a block on a submatch' do
    ("'" & ('so long' | 'hello' | 'goodby').on_success { |match| expect(match).to eq('hello')} & "'").match?("it was great to say 'hello' today", raise_error: true)
  end
  
  it 'wont call a success block if the match fails' do
    block_was_called = false
    ("'" & ('so long' | 'hello' | 'goodby').on_success { |match| block_was_called = true } & "'").match?("it was great to say 'sawadii kaap' today")
    expect(block_was_called).to be_falsy
  end
  
  it 'can use the REM builtin pattern' do
    expect(("hello" & REM).match?('he said hello to her')).to eq('hello to her')
  end
  

  it 'can use the ARB builtin pattern' do
    ("O" & ARB.on_success { |match| expect(match).to eq('UNT') } & "A").match?('MOUNTAIN', raise_error: true)
    ("O" & ARB.on_success { |match| expect(match).to eq('') } & "U").match?('MOUNTAIN', raise_error: true)
    expect(("O" & ARB & "Z").match?('MOUNTAIN')).to be_falsy
  end

  it 'can use the LEN builtin pattern' do
    expect(( ("Z" | "I" | "U") & LEN(36) & ("ME" | "U")).match?("Hey! I am separated by 36 characters from U")).to be_truthy
    expect(( ("Z" | "I" | "U") & LEN(35) & ("ME" | "U")).match?("Hey! I am separated by 36 characters from U")).to be_falsy
  end
  
  it 'can delay evaluation of parameters to builtin patterns' do
    expected_length = nil
    pattern = ("Z" | "I" | "U") & LEN {expected_length} & ("ME" | "U")
    expected_length = 36
    expect(pattern.match?("Hey! I am separated by 36 characters from U")).to be_truthy
    expected_length = 3
    expect(pattern.match?("Z123ME")).to be_truthy
  end
  
  it 'can use POS and RPOS builtin patterns' do
    s = 'ABCDA'
    expect((POS(0) & 'B').match?(s)).to be_falsy
    (LEN(3).on_success { |match| expect(match).to eq('CDA') } & RPOS(0)).match?(s, raise_error: true)
    (POS(3) & LEN(1).on_success { |match| expect(match).to eq('D') }).match?(s, raise_error: true)
    expect((POS(0) & 'ABCD' & RPOS(0)).match?(s)).to be_falsy
  end
  
  it 'can use TAB and RTAB builtin patterns' do
    s = '   X1234ABCD9012345XYZZY'
    ( 'X' & LEN(4) & 
      TAB(12).on_success { |match| expect(match).to eq('ABCD') } & 
      RTAB(5).on_success { |match| expect(match).to eq('9012345') }
    ).match?(s, raise_error: true)
  end
  
  it 'can use ANY and NOTANY builtin patterns' do
    vowel = ANY('AEIOU')
    consonant = NOTANY('AEIOU')
    expect(vowel.match?('HELLO')).to eq('E')
    expect(consonant.match?('EASY')).to eq('S')
  end
  
  it 'will SPAN a number of characters' do
    expect(SPAN('1234567890').match?('The number 152 is stuck in here!')).to eq("152")
  end
  
  it 'will BREAK when it hits a non matching character' do
    expect(BREAK('1234567890').match?('Before 12')).to eq('Before ')
  end
  
  it 'can use the BREAKX builtin pattern' do
    (BREAKX('E').on_success { |match| expect(match).to eq("INTEG") } & 'ER').match?('INTEGERS', raise_error: true)
  end
  
  it 'can replace the match with a fixed value' do
    expect('hello'.match?("she said hello", replace_with: "goodby")).to eq("she said goodby")
  end 
  
  it 'can replace the match using a block' do
    match_value = nil
    pattern = ('hello' | 'goodby').on_success { |match| match_value = match}
    string = 'she said hello'
    expect(pattern.match?(string) { "she said #{match_value == 'hello' ? 'sawadii kaa' : 'choke dee kaa'}"}).to eq('she said sawadii kaa')
  end
    
  
  it 'can use regex patterns' do
    pattern = /\s*/ & /[a-zA-Z]+/.on_success { |the_word| expect(the_word).to eq('hello') }
    pattern.match?("      hello!", raise_error: true)
    pattern.match?("hello", raise_error: true)
    expect(pattern.match?("...")).to be_falsy
  end
  
  it 'can assign match variables using a block' do
    pattern = ('he' | 'she').capture_as(:gender) & /\s+/ & 'said' & /\s+/ & ('hello' | 'goodby').capture_as(:greeting)
    string = 'Then she  said  hello'
    expect(pattern.match?(string) do |gender, greeting| 
      "klaw #{greeting == 'hello' ? 'sawadii' : 'choke dee'} #{gender == 'he' ? 'kaap' : 'kaa'}"
    end).to eq("klaw sawadii kaa")
  end  
  
  it 'can returns the match data as a hash' do
    pattern = ('he' | 'she').capture_as(:gender) & /\s+/ & 'said' & /\s+/ & ('hello' | 'goodby').capture_as(:greeting)
    string = 'Then she  said  hello'
    match_data = pattern.match?(string)
    expect(match_data.captured[:gender]).to eq("she")
    expect(match_data.captured[:greeting]).to eq("hello")
    expect(match_data).to eq("she  said  hello")
    expect(pattern.match?("foo bar", as_hash: true)).to be_falsy
  end  
  
  it 'can replace the match string' do
    pattern = "boy" | "girl" | "man" | "woman"
    string = "There was a man here."
    expect(pattern.match?(string).replace_match_with("person")).to eq("There was a person here.")
  end
  
  it 'can do conditional assignments during matching' do
    conditional_matches = []
    pattern = ('car' | 'plane' | 'bike').on_match { | m | conditional_matches << m } & '!'
    string = "he had a car, a plane, and even a  bike!"
    expect(pattern.match?(string)).to eq("bike!")
    expect(conditional_matches).to eq(["car", "plane", "bike"])
  end
  
  it 'can do conditional assignments during matching even if the match fails' do
    arb_matches = []
    pattern = ARB.on_match { | match | arb_matches << match } & 'gotcha'
    string = "12345"
    expect(pattern.match?(string, anchor: true)).to be_falsy
    expect(arb_matches).to eq(["","1","12","123","1234","12345"])
  end
  
  it 'can insert a string at the beginning of match' do
    expect(POS(0).match?("hello there").replace_match_with("well ")).to eq("well hello there")
  end
  
  it 'ARBNO'
  
  it 'can match recursive patterns'
   #? ITEM = SPAN(“0123456789") | *LIST
   #? LIST = ”(“ ITEM ARBNO(”," ITEM) “)”
   #? TEST = POS(0) LIST RPOS(0)
   #? “(12,(3,45,(6)),78)” ? TEST
   #Success
   #? “(12,(34)” ? TEST
   #Failure

  it "ABORT"
  it "FAIL" # ? does fail backtrack 1 character, no must seek the next possible alternative, yes?
  it "FENCE"
  it "SUCCEED"
    #? P = FENCE(TAB(*(N + 1)) $ OUTPUT @N | ABORT)
    #? “abcd” ? POS(0) $ N SUCCEED P FAIL
    #a
    #ab
    #abc
    #abcd
    #Failure

end