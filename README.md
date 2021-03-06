# CannonBol

CannonBol is a ruby DSL for patten matching based on SNOBOL4 and SPITBOL.

* Makes complex patterns easier to read and write!
* Combine regexes, plain strings and powerful new primitive match functions!
* Makes capturing match results simple!
* Allows recursive patterns!
* Complete SNOBOL4 + SPITBOL extensions!
* Based on the well documented, proven SNOBOL4 language!
* Simple syntax looks great within your ruby code!
* Tested with ruby 1.9.3 - 2.6.3 and [Opal](www.opalrb.org)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cannonbol'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cannonbol

## Compatibility With Ruby 2.5

> In Ruby 2.5 the methods `#match?` and `#-@` were added to strings and regex patterns.  These methods were also used to build
patterns in Cannonbol.  The latest version of Cannonbol uses the `#matches?` and `#insensitive` methods instead.  See the
end of the readme for using your old patterns with the latest Cannonbol.

## Lets Go!

### Basic Matching `- &, |, capture?, match_any, match_all`

Strings, Regexes and primitives are combined using & (concatenation) and | (alternation) operators.

Here is a simple pattern that matches a simple noun clause:

```ruby
> ("a" | "the") & /\s+/ & ("boy" | "girl")
```

This will match either "a" or "the" followed white space and then by "boy or "girl".  Okay!  Lets use it!

```ruby
> ("a" | "the") & /\s+/ & ("boy" | "girl").matches?("he saw a boy going home")
=> "a boy"
> ("a" | "the") & /\s+/ & ("boy" | "girl").matches?("he saw a big boy going home")
=> nil
```

Now let's save the pieces of the match using the `capture?` (pronounced _capture IF_) method:

```ruby
> article, noun = nil, nil;
* pattern = ("a" | "the").capture? { |m| article = m } & /\s+/ & ("boy" | "girl").capture? { |m| noun = m };
* pattern.matches?("he saw the girl going home")
=> the girl
> noun
=> girl
> article
=> the
```

The `capture?` method and its friend `capture!` (pronounced _capture NOW_) have many powerful features.
As shown above it can take a block which is passed the matching substring, _IF the match succeeds_.  
The other features of the capture method will be detailed [below.](#advanced-capture-techniques)

Arrays can be turned into patterns using the `match_any` and `match_all` methods:

```ruby
ARTICLES = ["a", "the"]
NOUNS = ["boy", "girl", "dog", "cat"]
ADJECTIVES = ["big", "small", "fierce", "friendly"]
WS = /\s+/
[ARTICLES.match_any, [WS, [WS, ADJECTIVES.match_any, WS].match_all].match_any, NOUNS.match_any].match_all
```

This is equivilent to

```ruby
("a" | "the") & (WS | (WS & ("big" | "small" | "fierce" | "friendly") & WS)) & ("boy" | "girl" | "dog" | "cat")
```

### The matches? options

The `matches?` method shown above takes a couple of options to globally control the match process:

option | default |  meaning
------|-----|-----
`insensitive` | `false`  | When on, the basic regex and string pattern will NOT be case sensitive. Note you can also use `ignore_case`
`anchor` | `false`  | When on, pattern matching must begin at the first character.  Normally the matcher will keep moving the starting character to the right, until the match suceeds.
`raise_error` | `false` | When on, a match failure will raise Cannonbol::MatchFailed.
`replace_with` | `nil` | When a non-falsy value is supplied, the value will replace the matched portion of the string, and the entire string will be returned.  Normally only the matched portion of the string is returned.

Example of replace with:

```ruby
> "hello".matches?("She said hello!")
=> hello
> "hello".matches?("She said hello!", replace_with => "goodby")
=> She said goodby!
```

#### Ignore case on a subpattern

Sometimes it's useful to run the matcher in the default case sensitive mode, and only turn off matching for one part of the pattern.  To do this
use the `#insensitive` method.  For example

```ruby
> ("GIRL".insensitive | "boy").matches?("A big girl!")
=> girl
> ("GIRL".insensitive | "boy").matches?("A big BOY!")
=> nil
```

### Patterns, Subjects, Cursors, Alternatives, and Backtracking

A pattern is an object that responds to the matches? method.  Cannonbol adds the matches? method to Ruby strings, and regexes, and provides a number of _primitive_ patterns.  A pattern can be combined with another pattern using the &, and | operators.  There are also several primitive patterns that take a pattern and create a new pattern.  Here are some example patterns:

```ruby
"hello"  # matches any string containing hello
/\s+/    # matches one or more white space characters
"hello" & /\s+/ & "there"  # matches "hello" and "there" seperated by white space
"hello" | "goodby"         # matches EITHER "hello" or "goodby"
ARB      # a primitive pattern that matches anything (similar to /.*/)
("hello" | "goodby") & ARB & "Fred"  # matches "hello" or "goodby" followed by any characters and finally "Fred"
```

Patterns are just objects, so they can be assigned to variables:

```ruby
greeting = "hello" | "goodby"
names = "Fred" | "Suzy"
ws = /\s+/
greeting & ws & names # matches "hello Fred" or "goodby     Suzy"
```

The first parameter of the matches? method is the subject string.  The subject string is matched left to right driven by the pattern object.  Normally the matcher will attempt to match starting at the first character.  If no match is found, then
matching begins again one character to the right.  This continues until a match is made, or there are insufficient characters to make a match.  This behavior can be turned off by specifying `anchor: true` in the matches? options hash.

The current position of the matcher in the string is the _cursor_.  The cursor begins at zero and as each character is matched it moves to the right.  If the match fails (and anchor is false) then the match is restarted with the cursor at position 1, etc.

Alternatives are considered left to right as specified in the pattern.  Once an alternative is matched, the matcher moves on to the next element in the pattern, but it does remember the alternative, and if matching fails at a later pattern, the matcher will back up and try the next alternative.  For example:

```ruby
a_pattern = "a" | "aaa" | "aa"
b_pattern = "b" | "aaabb"  | "abbbc"
c_pattern = "cc"
(a_pattern & b_pattern & c_pattern).matches?("aaabbbccc")
```

* "a" is matched from a_pattern, and then we move to b_pattern.
* None of the alternatives in b_pattern can match, so we backtrack and try the next alterntive in the a_pattern,
* "aaa" now matches, and so we move back to the b_pattern and start at the first alternative,
* "b" now matches, and so we move to the c_pattern,
* None of the alternatives in the c_pattern can match, so we move back to the b_pattern,
* None of the remaining alternatives in the b_pattern match, so we move back to the a_pattern,
* "aa" now matches, and so we move to the b_pattern, which can only match its last alternative, and
* finally we complete the match!

For a more complete explanation see the [SNOBOL4 manual Chapter 2](https://github.com/catprintlabs/cannonbol/blob/master/snobol4-language-reference.pdf)

Bottom line is the matcher will try every possible option until a match is made or the match fails.

### Basic Primitive Patterns

Cannonbol includes the complete set of SNOBOL4 + SPITBOL primitive patterns and functions.  These are added to the ruby name space via the Object class, and so are available everywhere.

`REM` Match 0 or more characters to the end of the subject string.  

`("the" & REM).matches?("he saw the small boy") === "the small boy"`

`ARB` Match 0 or more characters.  ARB first tries to match zero characters, then 1 character, then 2 until the match succeeds. It is roughly equivilent to `\.*\`, except the regex will NOT backtrack like ARB will.

`("the" & ARB & "boy").matches?("he saw the small boy running") === "the small boy"`

`LEN(n)` Match any n characters. Equivilent to `\.{n}\`

`POS(x)` Match ONLY if current cursor is at x.  POS(0) is the start of the string.

`(POS(5) & ARB & POS(7)).matches?("01234567") === "56"`

`RPOS(x)` Just like POS except measured from the end of the string.  I.e. RPOS(0) is just after the last character.

`("hello" & RPOS(0)).matches?("she said hello!")` would fail.

`("hello" & RPOS(1)).matches?("she said hello!")` would succeed.

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

There are several cases where it is useful to delay the evaluation of a primitive pattern arguments until the match is
being made, rather than when the pattern is created.

To allow for this all primitive patterns can take a block.  The block is evaluated when the matcher encounters the primitive, and the result of the block is used as the argument to the pattern.

Here is a method that will parse a set of fixed width fields, where the widths are supplied as arguments to the method:

```ruby
def parse(s, *widths)
      fields = []
      (ARBNO(LEN {widths.shift}.capture? {|field| fields << field}) & RPOS(0)).matches?(s)
      fields
    end
```

To really get into the power of delayed evaluation however we need to add two more concepts:

The `MATCH` primitive, and the `capture!` (pronounced _capture NOW_) method.  

The `capture?` (pronounced _capture IF_) method executes _IF_ the match has completed successfully.  In contrast the `capture!` method calls its block as soon as its sub-pattern matches.  Using `capture!` allows you to pick up values during one phase of the match and then use those values later.  

Meanwhile `MATCH` takes a pattern as its argument (like `ARBNO`) but will only match the pattern once.  The power in `MATCH` is when it is used with a delayed evaluation block.  Together `MATCH` and `capture!` allow for patterns that are much more powerful than simple regexes.  For example here is a palindrome matcher:

```ruby
palindrome = MATCH do | ; c|
  /\W*/ & LEN(1).capture! { |m| c = m } & /\W*/ & ( palindrome | LEN(1) | LEN(0)) & /\W*/ & MATCH { c }
end
```

Lets see it again with some comments

```ruby
palindrome = MATCH do | ; c |

  # By putting the MATCH pattern in a block to be evaluated later
  # we can use palindrome in its own definition.
  # Just to keep things clean and robust we declare c
  # (the character matched) as local to the block.

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

palindrome.matches?('A man, a plan, a canal, Panama!") # succeeds!
```

Using `MATCH` to define recursive patterns makes Cannonbol into a full blown BNF parser.  See the example [email address parser](#a-complete-real-world-example)

### Advanced capture techniques

Both `capture?` and `capture!` have a number of useful features.

* They can take a block which is passed the matching substring.
* As well as the current match, they can pass the current cursor position and the current value of capture variable.
* They can take a symbol parameter i.e. `capture?(:data)` which will save the value under the name :data.
* The block can be used to update the capture variable before its aved.
* They can capture an array of values in a single capture variable.

#### Passing a block to a capture method

This is the most general way of capturing a submatch.  For example

```ruby
word = /\W*/ & /\w+/.capture? { |match| words << match } & /\W*/
```

will shovel each word it matches into the words array.  You could use it like this:

```ruby
words = []
(ARBNO(word).matches?("a big strange, long sentence!")
```

Using `capture? { |m| puts m }` is handy for debugging your patterns.

#### Current cursor position

The second parameter of the capture block will receive the current cursor position.   For example

```ruby
("i".capture! { |m, p| puts "i found at #{p-1}"} & RPOS(0)).matches("I said hello!", insensitive: true)
 => i found at 0
 => i found at 4
```

Notice the use of `RPOS(0)` which will force the pattern to look at every character in the subject, until the pattern finally fails.  By using `capture!` (capture _now_) we record every hit, even though the pattern fails in the end.

#### Using capture variables

If the capture methods are supplied with a symbol, then the captured value will be saved in an internal capture variable.  For example:

```ruby
some_pattern.capture!(:value)
```

would save the string matched by `some_pattern` into the capture variable called `:value`.  

There are a couple of ways to retrieve the capture variables:

Any primitive pattern that takes a parameter can use the value of a capture variable.  So for example `LEN(:foo)` means
take the current value of the capture variable `:foo` as the parameter to `LEN`.

We can use this to clean up the palindrome pattern a little bit:

```ruby
palindrome = /\W*/ & LEN(1).capture!(:c) & /\W*/ & ( MATCH{palindrome} | LEN(1) | LEN(0) ) & /\W*/ & MATCH(:c)
```

Another way to get the capture variables is to interogate the value returned by matches?.  The value returned by matches? is a subclass of string, that has some extra methods.  One of these is the captured method which gives a hash of all the captured variables.  For example:

```ruby
> ("dog" | "cat").capture?(:pet).matches?("He had a dog named Spot.").captured[:pet]
=> dog
```

You can also give a block to the matches? method which will be called whether the block passes or not.  For example:

```ruby
> ("dog" | "cat").capture?(:pet).matches?("He had a dog named Spot."){ |match| match.captured[:pet] if match}
=> dog
```

The matches? block can also explicitly name any capture variables you need to get the values of.  So for example:

```ruby
> pet_data = (POS(0) & ARBNO(("big" | "small").capture?(:size) | ("dog" | "cat").capture?(:pet) | LEN(1)) & RPOS(0))
=> #<Cannonbol::Concat .... etc
> pet_data.matches?("He has a big dog!") { |m, pet, size| "type of pet: #{pet.upcase}, size: #{size.upcase}"}
=> type of pet: DOG, size: BIG
```

If the matches? block mentions capture variables that were not assigned in the match they get nil.

#### Initializing capture variables

When used as a parameter to a primitve the capture variable may be given an initial value.   For example:

```ruby
LEN(baz: 12)
```

would match `LEN(12)` if :baz had not yet been set.

A second way to initialize (or update capture variables) is to combine capture variables with a capture block like this:

```ruby
some_pattern.capture!(:baz) { |match, position, baz| baz || position * 2 } # initializes :baz to position * 2
```

If a symbol is specified in a capture!, and there is a block, then the symbol will be set to the value returned by the block.

#### Capturing arrays of data

To capture all the words into a capture variable as an array you could do this:

```ruby
words = []
word = /\W*/ & /\w+/.capture?(:words) { |match| words << match } & /\W*/
ARBNO(word)
```

The `word` pattern can be shortened to:

```ruby
word = /\W*/ & /\w+/.capture?(:words => []) & /\W*/
```

This works because anytime there is a 1) capture with a capture variable that is 2) holding an array,  3) that does NOT have a block, capture method will go ahead and shovel the captured value into the capture variable.   Note this behavior can be overriden if needed by including a block.

#### Capture variables and nested patterns

Each time MATCH, or ARBNO is called the current state of any known capture variables are saved, and those values will be restored when the MATCH/ARBNO exits.  If new capture variables are introduced by the nested pattern, these new values will be merged with the existing set of variables.  

More powerful yet is the fact that every match string sent to a capture variable has access to all the values captured so far via the captured method. For example:

```ruby
> subject_clause = article & noun.capture!(:subject) ;
* object_clause = article & noun.capture!(:object);
* verb_clause = ...
* sentence = (subject_clause & verb_clause & object_clause & ".");
* sentences = ARBNO(sentence.capture?(:sentences => [])) & RPOS(0);
* sentences.matches(file_stream).captured[:sentences].collect(&:captured)
=> [{:subject => "dog", :object => "man"}, {:subject => "man", :object => "dog} ...]
```

As each noun is matched, it is captured and saved in :subject or :object.  When the sentence is captured, the match is shoveled away into the :sentences variable.  Because the match value itself responds to the captured method we end up with a all the data collected in a nice array.  

Note that capture! is used for capturing the nouns.  This is cheaper and does not hurt anything since the value of
the capture variable will just be overwritten.

### Advanced PRIMITIVES

There are few more SNOBOL4 + SPITBOL primitives that are included for completeness.

`FENCE` matches the empty string, but will fail if there is an attempt to backtrack through the FENCE.

`FENCE(pattern)` will attempt to match pattern, but if an attempt is made to backtrack through the FENCE the pattern will fail.

The difference is that FENCE will fail the whole match, but FENCE(pattern) will just fail the subpattern.

`ABORT` unconditionally will exit the match.

`FAIL` will never match anything, and will force the matcher to backtrack and retry the next alternative.

`SUCCEED` will force the match to retry.  The only pattern that gets passed `SUCCEED` is `ABORT`.

These can be used together to do some interesting things.  For example

```ruby
> pattern = POS(0) & SUCCEED & (FENCE(TAB(n: 1).capture!(:n) { |m, p, n|  puts m; p+1 } | ABORT)) & FAIL;
* pattern.matches?("abcd")
a
ab
abc
abcd
=> nil
```

The SUCCEED and FAIL primitives keep forcing the matcher to retry.  Eventually the TAB will fail causing the ABORT alternative to execute the matcher.

So it goes like this

    SUCCEED
    TAB(1)
    FAIL
    SUCCEED
    TAB(2)
    etc...

The FENCE keeps the matcher from backtracking into the ABORT option too early. Note that FENCE prevents backtracking through the level it is on,
however we can backtrack *around* the FENCE and into the SUCCEED, which forces us to retry the FENCE but with a new value of `n`.

### A complete real world example

Cannonbol can be used to easily translate the email BNF spec into an email address parser.

```ruby
ws             = /\s*/
quoted_string  = ws & '"' & ARBNO(NOTANY('"\\') | '\\"' | '\\\n' | '\\\\') & '"' & ws
atom           = ws & SPAN("!#$%&'*+-/0123456789=?@ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`abcdefghijklmnopqrstuvwxyz{|}~") & ws
word           = (atom | quoted_string)
phrase         = word & ARBNO(word)
domain_ref     = atom
domain_literal = "[" & /[0-9]+/ & ARBNO(/\.[0-9]+/) & "]"
sub_domain     = domain_ref | domain_literal
domain         = (sub_domain & ARBNO("." & sub_domain)).capture?(:domain) { |m| m.strip }
local_part     = (word & ARBNO("." & word)).capture?(:local_part) { |m| m.strip }
addr_spec      = (local_part & "@" & domain)
route          = (ws & "@" & domain & ARBNO("@" & domain)).capture?(:route) { |m| m.strip } & ":"
route_addr     = "<" & ((route | "") & addr_spec).capture?(:mailbox) { |m| m.strip } & ">"
mailbox        = (addr_spec.capture?(:mailbox) { |m| m.strip } |
                 (phrase.capture?(:display_name) { |m| m.strip } & route_addr))  
group          = (phrase.capture?(:group_name) { |m| m.strip } & ":" &
                 (( mailbox.capture?(group_mailboxes: []) & ARBNO("," & mailbox.capture?(:group_mailboxes) ) ) | ws)) & ";"
address        = POS(0) & (mailbox | group ) & RPOS(0)
```

So for example we can even parse an obscure email with groups and routes

```ruby
> email = 'here is my "big fat \\\n groupen" : someone@catprint.com, Fred Nurph<@sub1.sub2@sub3.sub4:fred.nurph@catprint.com>;'
=> here is my "big fat \\\n groupen" : someone@catprint.com, Fred Nurph<@sub1.sub2@sub3.sub4:fred.nurph@catprint.com>;
> match = address.matches?(email)
=> here is my "big fat \\\n groupen" : someone@catprint.com, Fred Nurph<@sub1.sub2@sub3.sub4:fred.nurph@catprint.com>;
> match.captured[:group_mailboxes].first.captured[:mailbox]
=> someone@catprint.com
> match.captured[:group_name]
=> here is my "big fat \\\n groupen
```

### Backward Compatibility (`matches?` and `insensitive` methods)

If you have existing Cannonbol code and are using Ruby 2.5+ you will need to either replace
uses of the `match?` method and the `-` unary operator with `matches?` and `insensitive`.

Alternatively you can add the following code to your application:

```ruby
class Regexp
  include Cannonbol::CompatibilityAdapter
end

class String
  include Cannonbol::CompatibilityAdapter
end
```

## Development

After checking out the repo, run `bundle install` to install dependencies.

### Specs

Run `bundle exec rspec` to run the tests on your server environment

> Testing on Opal is currently broken because of compatibility issues with Opal 1.1 and opal-rspec.  However everything should work fine with Opal.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/cannonbol/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
