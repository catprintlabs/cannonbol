# Cannonbol

Cannonbol is a ruby dsl for patten matching based on SNOBOL4 and SPITBOL.

Makes complex patterns easier to read and write!

Allows recursive patterns!

Complete SNOBOL4 + SPITBOL extensions!

Simple syntax looks great alongside ruby!


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cannonbol'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cannonbol

## Lets Go!

### Basic Matching `- &, |, capture?, match_any, match_all`

Here is a simple pattern that matches a simple noun clause:

    ("a" | "the") & /\s+/ & ("boy" | "girl")
    
So we will match either "a" or "the" followed white spae and then by "boy or "girl".  Okay!  Lets use it!

    ("a" | "the") & /\s+/ & ("boy" | "girl").match?("he saw a boy going home")
    => "a boy"
    ("a" | "the") & /\s+/ & ("boy" | "girl").match?("he saw a big boy going home")
    => nil

Notice that we can use regexes or strings as pattern primitives.

Let's save the pieces of the match using the capture? method:

    article, noun = nil, nil
    pattern = ("a" | "the").capture? { |m| article = m } & /\s+/ & ("boy" | "girl").capture? { |m| noun = m }
    pattern.match?("he saw the girl going home")
    noun
    => girl
    article
    => the

You can also turn an array into a pattern using the match_any or match_all methods:

    ARTICLES = ["a", "the"]
    NOUNS = ["boy", "girl", "dog", "cat"]
    ADJECTIVES = ["big", "small", "fierce", "friendly"]
    SPACE = /\s+/
    [ARTICLES.match_any, [SPACE, [SPACE, ADJECTIVES.match_any, SPACE].match_all].match_any, NOUNS.match_any].match_all
    
is equivilent to 
   
    ("a" | "the") & (SPACE | (SPACE & ("big" | "small" | "fierce" | "friendly") & SPACE)) & ("boy" | "girl" | "dog" | "cat")
    
### match? options

The match? method takes a couple of options to globally control the match process:

    ignore_case: true # (default false.  When on, the basic regex, and string pattern matching will NOT be case sensitive)
    anchor: true # (default false.  When on pattern matching is forced to begin at the beginning of the string)
    raise_error: true # (default false.  When on, a match failure will raise Cannonbol::MatchFailed)
    replace_with: "string" # (default false.  When supplied, the replace_with string will replace the matched substring, and the entire input string will be returned.)

example of `replace_with:`
    'hello'.match?("she said hello", replace_with: "goodby") === "she said goodby"
    
The value returned by match? is a subclass of String with that has a replace_match_with method so you can write the above as
     'hello'.match?("she said hello").replace_match_with("goodby")

### Backtracking 

The pattern matcher begins at the left of the string and moves forward through the string matching each element left to right. 

Eventually it will either match the entire pattern, or will will fail.  At this point the matcher backs up one element at a time seeking available alternatives, and then moving forward again.  If the match is NOT anchored (the default mode) then the matcher will keep retrying by advancing the starting point one character at a time.   A more complete explanation can be found here: ftp://ftp.snobol4.com/spitman.pdf

Bottom line is the matcher will try every possible option until a match is made or he match fails.

### Basic Primitive Patterns

As we have seen any string or regexes will act as patterns so for example
  "foomanchu".match?("He had a FooManchu mustache", ignore_case: true)
will succeed.

Patterns are combined using the & (concatenation) and | operators.

In addition to these basics there is a complete set of the original SNOBOL4 + SPITBOL primitive patterns:

`REM` Match 0 or more characters to the end of the subject string.  
`("the" & REM).match?("he saw the small boy") === "the small boy"`

`ARB` Match 0 or more characters.  ARB first tries to match zero characters, then 1 character, then 2 until the match succeeds. It is equivilent to `\.*\`
`("the" & ARB & "boy").match?("he saw the small boy running") === "the small boy"`

`LEN(n)` Match any n characters. Equivilent to `\.{n}\`

`POS(x)` Match ONLY if current cursor is at x.  POS(0) is the start of the string.
`(POS(5) & ARB & POS(7)).match?("01234567") === "567"`

`RPOS(x)` Just like POS except measured from the end of the string.  I.e. RPOS(0) is just after the last character
`("hello" & RPOS(0)).match?("she said hello!")` would fail.

`TAB(x)` Is equivilent to `ARB & POS(x)`.  In otherwords match zero or more characters up to the x'th character. Fails if x < the current cursor.

`RTAB(x)`  You guessed it === `ARB & RPOS(x)`

`ANY(s)` Will match 1 character in s.  So if s = "ABC" it will match A or B or C.  Regexes are generally more useful.

`NOTANY(s)` Will match 1 character as long as its NOT in s.

`SPAN(s)`  Matches 1 or more from s.  Again regexes are generally easier to write.

`BREAK(s)` Matches 0 or more characters until a character in s is hit.

`BREAKX(s)` Woah... like BREAK, but if the match fails, then it will skip the character and try again.  Huh!

`ARBNO(pat)` Match pat zero or more times.
`POS(0) & /\w+/ & ARBNO(/\s*,\s*/ & /\w+/) & /\s*/ & RPOS(0)` will match a list of identifiers separated by commas.

### Delayed Evaluation of Primitive Pattern Parameters

There are several cases where it is useful to delay the evaluation of a primitive patterns arguments to when the match is 
being made, rather than when the pattern is created.

To allow for this all primitive patterns can take a block.  The block is evaluated when the matcher encounters the primitive, and the result of the block is used as the argument to the pattern.

Here is a method that will parse a set of fixed width fields, where the widths are supplied as arguments to the method:

    def parse(s, *widths)
      fields = []
      (ARBNO(LEN {widths.shift}.capture? {|field| fields << field}) & RPOS(0)).match?(s)
      fields
    end

To really get into the power of delayed evaluation however we need to add two more concepts:

The MATCH primitive, and the capture! (read as capture NOW) method.  

The capture? (read as capture IF) method executes when the match has completed successfully.  The capture! method 
calls is block as soon as its sub-pattern matches.  Using capture! allows you to pick up values during one phase of the match and then use those values later.  

Meanwhile MATCH takes a pattern as its argument (like ARBNO) but will only match the pattern once.  The power in MATCH is when it is used with a delayed evaluation block.  Together MATCH and capture! allow for patterns that are much more powerful than simple regexes.  For example here is a palindrome matcher:
    
     palindrome = MATCH do | ; c|
       /\W*/ & LEN(1).capture! { |m| c = m } & /\W*/ & ( palindrome | LEN(1) | LEN(0)) & /\W*/ & MATCH { c } 
     end 
     
Lets see it again with some comments

    palindrome = MATCH do | ; c | 
      # by putting the MATCH pattern in a block to be evaluated later we can use palindrome in its definition
      # just to keep things clean and robust we declare c (the character matched) as local to the block
      
      /\W*/ &                          # skip any white space
      LEN(1).capture! { |m| c = m } &  # grab the next character now and save it in c
      /\W*/ &                          # skip more white space
      (                                # now there are three possibilities: 
        palindrome |                     # there are more characters on the left side of the palindrome OR
        LEN(1) |                         # we are at the middle ODD character OR
        LEN(0)                           # the palindrome has an even number of characters
      ) &                              # now that we have the left half matched, we match the right half
      /\W*/ &                          # skip any white space and finally
      MATCH { c }                      # match the same character on the left now on the far right
      
    end
    
    palindrome.match?('A man, a plan, a canal, Panama!")

Using MATCH to define recursive patterns makes Cannonbol into a full blown BNF parser.  

### Advanced capture techniques

There are few more features of capture that are worth noting:

#### capture position

The second parameter of the capture block will recieve the current cursor position.   For example

   "i".capture! { |m, p| puts "i found at #{p-1}"}.match("I said hello!", ignore_case: true)
prints
    i found at 0
    i found at 4

#### Using capture variables    

Often we just want to save capture data and so saying `some_pattern.capture!{ |m| my_var = m}` gets old.  You can shorten this to
    some_pattern.capture!(:my_var)
The value gets stored into an internal hash inside the matcher.  You can get the value back out in any primitive by using
the same symbol.  For example
    LEN(1).capture(:length) & LEN(:length)
would match old school data of the form `5Hello` where the length of the string preceeds the string.

We can use this to clean up the palindrome pattern a little bit:
    palindrome = /\W*/ & LEN(1).capture!(:c) & /\W*/ & ( MATCH{palindrome} | LEN(1) | LEN(0) ) & /\W*/ & MATCH(:c) 
    
#### Accessing capture variables

What if we want to get the captured values out at the end of the match?  There are two ways to do this.  One is add a block to the match? method.  This block will be called with the match string, followed by any capture variables you name.  For example

    pattern = ('he' | 'she').capture?(:gender) & /\s+/ & 'said' & /\s+/ & ('hello' | 'goodby').capture?(:greeting)
    string = 'Then she  said  hello'
    pattern.match?(string) do | match, gender, greeting| 
      "klaw #{greeting == 'hello' ? 'sawadii' : 'choke dee'} #{gender == 'he' ? 'kaap' : 'kaa'}" if match
    end
    => klaw sawadii kaa

During the match we capture :gender and :greeting.  This are transferred to each of the block parameters that
have the same name, for use in the block.

Note that the match? block is always called, and the first parameter is the match string.

The second way to get a hold of the capture variables is to use the captured method on the result of match? (which is a subclass of String, and has some special methods.)  So for example the above match? could be rewritten as:
    result = pattern.match?(string)
    "klaw #{result[:greeting] == 'hello' ? 'sawadii' : 'choke dee'} #{result[:gender] == 'he' ? 'kaap' : 'kaa'}"

#### Initializing capture variables

When used as parameter to a primitve the capture variable may be given an initial value.   For example:
    LEN(baz: 12)
would do a LEN(12) if :baz had not yet been set.

A second way to initialize (or update capture variables) is to combine capture variables with a capture block like this:
    some_pattern.capture!(:baz) { |match, position, baz| baz || position * 2 } initializes :baz to position * 2
If a symbol is specified in a capture!, and there is a block, then the symbol will be set to the value returned by the block.

#### Capture variables and nested patterns

Each time MATCH is called the current state of any known capture variables is saved, and those values will be restored when the MATCH exits.  If new capture variables are introduced by the nested pattern, these new values will be merged with the existing set of variables.  

### Advanced PRIMITIVES

There are few more SNOBOL4 + SPITBOL primitives that are included for completeness.

`FENCE` matches the empty string, but will fail if there is an attempt to backtrack through the FENCE.
`FENCE(pattern)` will attempt to match pattern, but if an attempt is made to backtrack through the FENCE the pattern will fail.

The difference is that FENCE will fail the whole match, but FENCE(pattern) will just fail the subpattern.

`ABORT` unconditionally will exit the match.

`FAIL` will never match anything, and will force the matcher to backtrack and retry the next alternative.

`SUCCEED` will force the match to retry unless `ABORT` is used.

These can be used together to do some interesting things.  For example
    pattern = POS(0) & SUCCEED & (FENCE(TAB(n: 1).capture!(:n) { |m, p, n|  puts m; p+1 } | ABORT)) & FAIL
    pattern.match?("abcd")
prints
    a
    ab
    abc
    abcd
The SUCCEED and FAIL primitives keep forcing the matcher to retry.  Eventually the TAB will fail causing the ABORT alternative to execute the matcher.

So it goes like this
    SUCCEED
    TAB(1)
    FAIL
    SUCEED
    TAB(2)
    etc...
    
The FENCE keeps the matcher from backtracking into the ABORT option to early. Otherwise when the matcher hit fail, it would try different alternatives, and would hit the ABORT.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/cannonbol/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
