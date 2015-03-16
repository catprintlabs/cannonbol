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
    ("'" & ('so long' | 'hello' | 'goodby').capture? { |match| expect(match).to eq('hello')} & "'").match?("it was great to say 'hello' today", raise_error: true)
  end
  
  it 'will execute a conditional capture block even if the match fails' do
    block_was_called = false
    ("'" & ('so long' | 'hello' | 'goodby').capture? { |match| block_was_called = true } & "'").match?("it was great to say 'sawadii kaap' today")
    expect(block_was_called).to be_falsy
  end
  
  it 'can use the REM primitive pattern' do
    expect(("hello" & REM).match?('he said hello to her')).to eq('hello to her')
  end
  

  it 'can use the ARB primitive pattern' do
    ("O" & ARB.capture? { |match| expect(match).to eq('UNT') } & "A").match?('MOUNTAIN', raise_error: true)
    ("O" & ARB.capture? { |match| expect(match).to eq('') } & "U").match?('MOUNTAIN', raise_error: true)
    expect(("O" & ARB & "Z").match?('MOUNTAIN')).to be_falsy
  end

  it 'can use the LEN primitive pattern' do
    expect(( ("Z" | "I" | "U") & LEN(36) & ("ME" | "U")).match?("Hey! I am separated by 36 characters from U")).to be_truthy
    expect(( ("Z" | "I" | "U") & LEN(35) & ("ME" | "U")).match?("Hey! I am separated by 36 characters from U")).to be_falsy
  end
  
  it 'can delay evaluation of parameters to primitive patterns' do
    expected_length = nil
    pattern = ("Z" | "I" | "U") & LEN {expected_length} & ("ME" | "U")
    expected_length = 36
    expect(pattern.match?("Hey! I am separated by 36 characters from U")).to be_truthy
    expected_length = 3
    expect(pattern.match?("Z123ME")).to be_truthy
  end
  
  it 'can use POS and RPOS primitive patterns' do
    s = 'ABCDA'
    expect((POS(0) & 'B').match?(s)).to be_falsy
    (LEN(3).capture? { |match| expect(match).to eq('CDA') } & RPOS(0)).match?(s, raise_error: true)
    (POS(3) & LEN(1).capture? { |match| expect(match).to eq('D') }).match?(s, raise_error: true)
    expect((POS(0) & 'ABCD' & RPOS(0)).match?(s)).to be_falsy
  end
  
  it 'can use TAB and RTAB primitive patterns' do
    s = '   X1234ABCD9012345XYZZY'
    ( 'X' & LEN(4) & 
      TAB(12).capture? { |match| expect(match).to eq('ABCD') } & 
      RTAB(5).capture? { |match| expect(match).to eq('9012345') }
    ).match?(s, raise_error: true)
  end
  
  it "has a TAB and RTAB matches the null string" do
    pattern = POS(0) & TAB(0).capture? { |m| expect(m).to eq("") } & ARB & RPOS(0) & RTAB(0).capture? { |m| expect(m).to eq("")}
    pattern.match?("hello", raise_error: true)
  end
  
  it 'can use ANY and NOTANY primitive patterns' do
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
  
  it 'can use the BREAKX primitive pattern' do
    (BREAKX('E').capture? { |match| expect(match).to eq("INTEG") } & 'ER').match?('INTEGERS', raise_error: true)
  end
  
  it 'can replace the match with a fixed value' do
    expect('hello'.match?("she said hello", replace_with: "goodby")).to eq("she said goodby")
  end 
  
  it 'can replace the match using a block' do
    match_value = nil
    pattern = ('hello' | 'goodby').capture? { |match| match_value = match}
    string = 'she said hello'
    expect(pattern.match?(string) { "she said #{match_value == 'hello' ? 'sawadii kaa' : 'choke dee kaa'}"}).to eq('she said sawadii kaa')
  end
    
  
  it 'can use regex patterns' do
    pattern = /\s*/ & /[a-zA-Z]+/.capture? { |the_word| expect(the_word).to eq('hello') }
    pattern.match?("      hello!", raise_error: true)
    pattern.match?("hello", raise_error: true)
    expect(pattern.match?("...")).to be_falsy
  end
  
  it 'can assign match variables using a block' do
    pattern = ('he' | 'she').capture?(:gender) & /\s+/ & 'said' & /\s+/ & ('hello' | 'goodby').capture?(:greeting)
    string = 'Then she  said  hello'
    expect(pattern.match?(string) do | match, gender, greeting| 
      "klaw #{greeting == 'hello' ? 'sawadii' : 'choke dee'} #{gender == 'he' ? 'kaap' : 'kaa'}"
    end).to eq("klaw sawadii kaa")
  end  
  
  it 'can returns the match data as a hash' do
    pattern = ('he' | 'she').capture?(:gender) & /\s+/ & 'said' & /\s+/ & ('hello' | 'goodby').capture?(:greeting)
    string = 'Then she  said  hello'
    match_data = pattern.match?(string)
    expect(match_data.captured[:gender]).to eq("she")
    expect(match_data.captured[:greeting]).to eq("hello")
    expect(match_data).to eq("she  said  hello")
    expect(pattern.match?("foo bar")).to be_falsy
  end  
  
  it 'can replace the match string' do
    pattern = "boy" | "girl" | "man" | "woman"
    string = "There was a man here."
    expect(pattern.match?(string).replace_match_with("person")).to eq("There was a person here.")
  end
  
  it 'can do conditional assignments during matching' do
    conditional_matches = []
    pattern = ('car' | 'plane' | 'bike').capture! { | m | conditional_matches << m } & '!'
    string = "he had a car, a plane, and even a  bike!"
    expect(pattern.match?(string)).to eq("bike!")
    expect(conditional_matches).to eq(["car", "plane", "bike"])
  end
  
  it 'can do conditional assignments during matching even if the match fails' do
    arb_matches = []
    pattern = ARB.capture! { | match | arb_matches << match } & 'gotcha'
    string = "12345"
    expect(pattern.match?(string, anchor: true)).to be_falsy
    expect(arb_matches).to eq(["","1","12","123","1234","12345"])
  end
  
  it 'can insert a string at the beginning of match' do
    expect(POS(0).match?("hello there").replace_match_with("well ")).to eq("well hello there")
  end
  
  it 'can save and retrieve values using capture and MATCH' do
    pattern = LEN(5).capture!(:first_five) & "|" & MATCH(:first_five)
    string = "12345|12345"
    expect(pattern.match?(string).captured[:first_five]).to eq('12345')
  end
  
  it 'can name, and overwrite a capture variable' do
    palindrome = ARB.capture!(:front) { |m, p, front|  m.reverse} & MATCH(:front) & RPOS(0)
    expect(palindrome.match?('toot')).to be_truthy
    expect(palindrome.match?('boot')).to be_falsy
  end
  
  it 'can capture the match, position, and the current value of the capture variable, and set the match variable' do
    pattern = ARB.capture!(data: []) { |m, p, d| d + [m, p]}.capture?(final_data: []) { |m, p, d| d + [m, p] } & RPOS(0)
    pattern.match?("ABC") do |m, data, final_data|
      expect(data).to eq(["",0,"A",1,"AB",2,"ABC",3])
      expect(final_data).to eq(["ABC", 3])
    end
  end
  
  it "can match the empty string" do
    expect((LEN(1) & ("" & RPOS(0) | "e") & "").match?("hello")).to eq("he")
  end
  
  it 'has a ARBNO primitive pattern' do
    pattern = POS(0) & ARBNO("A" | "B") & RPOS(0)
    expect(pattern.match? "ABBAAABBBA").to be_truthy
    expect(pattern.match? "ABBAXBAA").to be_falsy
  end
    
  
  it 'can match a palindrome' do
    palindrome = /\s*/ & LEN(1).capture!(:c)  & /\s*/ & ( MATCH {palindrome} | LEN(1) | LEN(0) ) & /\s*/ & MATCH(:c) & /\s*/
    expect(palindrome.match?("a man a plan a canal panama")).to be_truthy
    expect(palindrome.match?("palindrome")).to be_falsy
  end
  
  it 'can match a palindrome rev 2' do
    palindrome = MATCH do | ; c|
      /\s*/ & LEN(1).capture! { |m| c = m } & /\s*/ & ( palindrome | LEN(1) | LEN(0)) & /\s*/ & MATCH { c } & /\s*/ 
    end 
    expect(palindrome.match?("a man a plan a canal panama")).to be_truthy
    expect(palindrome.match?("palindrome")).to be_falsy    
  end 
  
  it 'can nest patterns' do
    fn_name = "foo" | "bar"
    var_name = "A" | "B"
    fn_call = POS(0) & fn_name & "(" & var_name & ")" & RPOS(0)
    expect(fn_call.match?("bar(B)")).to be_truthy
  end
    
  
  it 'can match recursive patterns' do
    #? ITEM = SPAN(“0123456789") | *LIST
    #? LIST = ”(“ ITEM ARBNO(”," ITEM) “)”
    #? TEST = POS(0) LIST RPOS(0)
    #? “(12,(3,45,(6)),78)” ? TEST
    #Success
    #? “(12,(34)” ? TEST
    #Failure
    list = nil
    item = SPAN('01234567890') | MATCH {list}
    list = ("(" & item & ARBNO("," & item) & ")")
    test = POS(0) & list & RPOS(0)
    expect(test.match? "(12,(3,45,(6)),78)" ).to be_truthy
    expect(test.match? "(12,(34)").to be_falsy
  end

  it "has an ABORT primitive pattern" do
    #?       '--AB-1-' (ANY('AB') | '1' ABORT)
    #Success
    #?       '--1B-A-' (ANY('AB') | '1' ABORT)
    #Failure
    pattern = (ANY('AB') | '1' & ABORT)
    expect(pattern.match?('--AB-1-')).to eq('A')
    expect(pattern.match?('--1B-A-')).to be_falsy
  end
    
  it "has a FAIL primitive pattern" do
    some_chars = ""
    ( LEN(1).capture! { |char| some_chars << char } & FAIL ).match?("hello world")
    expect(some_chars).to eq("hello world")
  end
  
  it "has a FENCE primitive pattern" do
    pattern = ANY('AB') & FENCE & '+'
    expect(pattern.match?('1AB+' )).to be_falsy
    expect(pattern.match?('1A+')).to eq("A+")
    expect((FENCE & "B").match?("ABC")).to be_falsy
  end
  
  it "can FENCE a sub-pattern" do
    pattern = FENCE(ANY('AB') & 'x')  & '+'
    expect(pattern.match?('1AxBx+' )).to be_falsy
    expect(pattern.match?('1ABx+')).to eq('Bx+')
  end
  
  it "has a SUCCEED primitive pattern" do
    #? P = FENCE(TAB(*(N + 1)) $ OUTPUT @N | ABORT)
    #? “abcd” ? POS(0) $ N SUCCEED P FAIL
    #a
    #ab
    #abc
    #abcd
    #Failure
    matches = []
    pattern = POS(0) & SUCCEED & (FENCE(TAB(n: 1).capture!(:n) { |m, p, n|  matches << m; p+1 } | ABORT)) & FAIL
    pattern.match?("abcd")
    expect(matches).to eq(['a', 'ab', 'abc', 'abcd'])
  end

end