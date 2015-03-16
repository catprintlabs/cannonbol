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
    

   



There is a related method `capture!` The difference is when the methods are
called.  `capture?` (read as capture IF) is called once the match succeeds with the final value matched by its pattern.  
`capture!` (read as capture NOW) is called as soon as the pattern component matches.  

For example:

    words = []
    gather_words = MATCH {\[A-Za-z]+\





## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/cannonbol/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
