module Cannonbol

  class MatchFailed < Exception; end

  class MatchString < String

    attr_reader :captured
    attr_reader :match_start
    attr_reader :match_end

    def initialize(string, match_start, match_end, captured)
      @cannonbol_string = string
      @match_start = match_start
      @match_end = match_end
      @captured = captured.dup
      super(@match_end < 0 ? "" : string[@match_start..@match_end])
    end

    def replace_match_with(s)
      before_match = ""
      before_match = @cannonbol_string[0..@match_start-1] if @match_start > 0
      after_match = @cannonbol_string[@match_end+1..-1] || ""
      before_match + s + after_match
    end

  end

  class Needle

    attr_reader :cursor
    attr_reader :string
    attr_accessor :captures
    attr_accessor :match_failed
    attr_accessor :ignore_case

    def initialize(string)
      @string = string
    end

    def thread(pattern, opts = {}, &match_block)
      @captures = {}
      anchor = opts[:anchor]
      raise_error = opts[:raise_error]
      replace_with = opts[:replace_match_with]
      ignore_case = opts[:ignore_case] | opts[:insensitive]
      @cursor = -1
      match = nil
      begin
        while !match and !match_failed and @cursor < @string.length-1
          @cursor += 1
          @starting_character = nil
          @success_blocks = []
          @ignore_case = ignore_case
          match = pattern._match?(self)
          break if !match and anchor
        end
      rescue MatchFailed
      end
      if match
        @success_blocks.each(&:call)
        match = MatchString.new(@string, @starting_character || @cursor, @cursor-1, @captures)
      else
        raise MatchFailed if raise_error
      end
      if match_block
        match = match_block.call(*([match] + (match_block.parameters[1..-1] || []).collect { |param| @captures[param[1].to_sym] }))
      elsif replace_with
        match = match.replace_match_with(replace_with)
      end
      match
    end

    def capture(name, value)
      @captures[name.to_sym] = value if name
      value
    end


    def remaining_string
      @string[@cursor..-1]
    end

    def push(length, &success_block)
      thread_state = [@starting_character, @cursor, @success_blocks.dup, @ignore_case]
      @starting_character ||= @cursor
      @cursor += length
      @success_blocks << success_block if success_block
      thread_state
    end

    def pull(thread_state)
      @starting_character, @cursor, @success_blocks, @ignore_case = thread_state if thread_state
      nil
    end

  end

  module Operators

    def _match?(needle, *args, &block)
      return if needle.match_failed
      __match?(needle, *args, &block)
    end

    def matches?(s, opts = {}, &match_block)
      Needle.new(s).thread(self, opts, &match_block)
    end

    def |(pattern)
      Choose.new(self, pattern)
    end

    def &(pattern)
      Concat.new(self, pattern)
    end

    def insensitive
      CaseSensitiveOff.new(self)
    end

    def capture?(opts = {}, &block)
      OnSuccess.new(self, opts, &block)
    end

    def capture!(opts = {},  &block)
      OnMatch.new(self, opts, &block)
    end

    def self.included(base)
      base.alias_method :match?, :matches? unless base.method_defined? :match?
      base.alias_method :-@, :insensitive unless base.method_defined? :-@
    end
  end

  module CompatibilityAdapter
    def self.included(base)
      base.alias_method :match?, :matches?
      base.alias_method :-@, :insensitive
    end
  end

  class Pattern

    include Operators


    def __match?(needle)
      []
    end

  end

  class Choose < Pattern

    def __match?(needle, i = 0, s = [])
      while i < @params.length
        s = @params[i]._match?(needle, *s)
        return [i, s] if s
        s = []
        i += 1
      end
      nil
    end

    def initialize(p1, p2)
      @params = [p1, p2]
    end

  end

  class Concat < Pattern

    def __match?(needle, i = 0, s = [])
      while i < @params.length and i >= 0
        s[i] = @params[i]._match?(needle, *(s[i] || []))
        i = s[i] ? i+1 : i-1
      end
      [i-1, s] if i == @params.length
    end

    def initialize(p1, p2)
      @params = [p1, p2]
    end

  end

  class CaseSensitiveOff < Pattern

    def initialize(pattern)
      @pattern = pattern
    end

    def __match?(needle, s=[])
      ignore_case = needle.ignore_case
      needle.ignore_case = true
      s = @pattern._match?(needle, *s)
      needle.ignore_case = ignore_case
      return [s] if s
    end

  end

  class OnSuccess < Pattern

    def initialize(pattern, opts, &block)
      if opts.class == Hash
        if opts.first
          @capture_name = opts.first.first
          @initial_capture_value = opts.first.last
        end
      else
        @capture_name = opts
      end
      @pattern = pattern
      @block = block
    end

    def __match?(needle, thread_state = nil, starting_cursor = nil, s=[])
      needle.pull(thread_state)
      starting_cursor ||= needle.cursor
      if s = @pattern._match?(needle, *s)
        ending_cursor = needle.cursor-1
        push = needle.push(0) do
          match_string = MatchString.new(needle.string, starting_cursor, ending_cursor, needle.captures)
          capture_value = @capture_name && (needle.captures.has_key?(@capture_name) ? needle.captures[@capture_name] : @initial_capture_value)
          if @block
            match_string = @block.call(match_string, ending_cursor+1, capture_value)
          elsif capture_value.class == Array
            match_string = capture_value + [match_string]
          end
          needle.capture(@capture_name, match_string)
        end
        [ push, starting_cursor, s ]
      end
    end

  end

  class OnMatch < OnSuccess

    def __match?(needle, starting_cursor = nil, s=[])
      starting_cursor ||= needle.cursor
      if s = @pattern._match?(needle, *s)
        match_string = MatchString.new(needle.string, starting_cursor, needle.cursor-1, needle.captures)
        capture_value = @capture_name && (needle.captures.has_key?(@capture_name) ? needle.captures[@capture_name] : @initial_capture_value)
        match_string = @block.call(match_string, needle.cursor, capture_value) if @block
        needle.capture(@capture_name, match_string)
        [starting_cursor, s]
      end
    end

  end

  class Match < Pattern

    def initialize(sub_pattern_or_name = nil, &block)
      if block
        @block = block
      elsif sub_pattern_or_name and sub_pattern_or_name.class == Symbol
        @name = sub_pattern_or_name
      elsif sub_pattern_or_name and sub_pattern_or_name.respond_to? "_match?"
        @pattern = sub_pattern_or_name
      elsif sub_pattern_or_name and sub_pattern_or_name.respond_to? "to_s"
        @pattern = sub_pattern_or_name.to_s
      end
    end

    def __match?(needle, pattern = nil, s = [])
      pattern ||= if @block
        @block.call
      elsif @name
        needle.captures[@name] || ""
      else
        @pattern
      end
      existing_captures = needle.captures.dup
      s = pattern._match?(needle, *s)
      needle.captures = needle.captures.merge(existing_captures)
      [pattern, s] if s
    end

  end

  class Rem < Pattern

    def __match?(needle, thread_state = nil)
      if thread_state
        needle_pull(thread_state)
      else
        [needle.push(needle.string.length-needle.cursor)]
      end
    end

  end

  class Arb < Pattern

    def __match?(needle, match_length = 0, thread_state = nil)
      needle.pull(thread_state)
      if needle.remaining_string.length >= match_length
        thread_state = needle.push(match_length)
        match_length += 1
        [match_length, thread_state]
      end
    end

  end

  class ParameterizedPattern < Pattern

    def initialize(opts = nil, &block)
      if opts.class == Hash
        if opts.first
          @param_name = opts.first.first
          @initial_param_value = opts.first.last
        end
      else
        @initial_param_value = opts
      end
      @block = block
    end

    def self.parameter(name, &post_processor)
      @post_processor = post_processor
      define_method(name) do |needle|
        value = (@param_name && needle.captures.has_key?(@param_name)) ? needle.captures[@param_name] : @initial_param_value
        value = @block.call(value) if @block
        needle.capture(@param_name, value)
        value = post_processor.call(value) if @post_processor
        value
      end
    end

  end

  class Len < ParameterizedPattern

    parameter :len

    def __match?(needle, thread_state = nil)

      if thread_state
        needle.pull(thread_state)
      else
        len_temp = len(needle)
        [needle.push(len_temp)] if needle.remaining_string.length >= len_temp
      end

    end

  end

  class Pos < ParameterizedPattern

    parameter :pos

    def __match?(needle, matched = nil)
      return [true] if needle.cursor == pos(needle) and !matched
    end

  end

  class RPos < ParameterizedPattern

    parameter :pos

    def __match?(needle, matched = nil)
      return [true] if needle.string.length-needle.cursor == pos(needle) and !matched
    end

  end

  class Tab < ParameterizedPattern

    parameter :pos

    def __match?(needle, thread_state = nil)

      if thread_state
        needle.pull(thread_state)
      else
        len = pos(needle) - needle.cursor
        [needle.push(len)] if len >= 0 and needle.remaining_string.length >= len
      end
    end

  end

  class RTab < ParameterizedPattern

    parameter :pos

    def __match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      else
        len = (needle.remaining_string.length - pos(needle))
        [needle.push(len)] if len >= 0 and needle.remaining_string.length >= len
      end
    end

  end

  class Any < ParameterizedPattern

    parameter :chars, &:split

    def __match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      elsif chars(needle).include? needle.remaining_string[0..0]
        [needle.push(1)]
      end
    end

  end

  class NotAny < ParameterizedPattern

    parameter :chars, &:split

    def __match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      elsif !(chars(needle).include? needle.remaining_string[0..0])
        [needle.push(1)]
      end
    end

  end

  class Span < ParameterizedPattern

    parameter :chars, &:split

    def __match?(needle, match_length = nil, thread_state = nil)
      unless match_length
        the_chars, match_length = chars(needle), 0
        while needle.remaining_string.length > match_length and the_chars.include? needle.remaining_string[match_length..match_length]
          match_length += 1
        end
      end
      needle.pull(thread_state)
      if match_length > 0
        thread_state = needle.push(match_length)
        match_length -= 1
        [match_length, thread_state]
      end
    end

  end

  class Break < ParameterizedPattern

    parameter :chars, &:split

    def __match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      else
        the_chars, len = chars(needle), 0
        while needle.remaining_string.length > len and !(the_chars.include? needle.remaining_string[len..len])
          len += 1
        end
        [needle.push(len)]
      end
    end

  end


  class BreakX < ParameterizedPattern

    parameter :chars, &:split

    def __match?(needle, len = 0, thread_state = nil)
      needle.pull(thread_state)
      the_chars = chars(needle)
      while needle.remaining_string.length > len and !(the_chars.include? needle.remaining_string[len..len])
        len += 1
      end
      [len+1, needle.push(len)] if needle.remaining_string.length >= len
    end

  end

  class Arbno < Match

    def __match?(needle, pattern = nil, s = [[]])
      return if s.length == 0
      if pattern
        existing_captures = needle.captures.dup
        s[-1] = pattern._match?(needle, *(s.last))
        s = s[-1] ? s + [[]] : s[0..-2]
        needle.captures = needle.captures.merge(existing_captures)
      else
        if @block
          pattern = @block.call
        elsif @name
          pattern = needle.captures[@name] || ""
        else
          pattern = @pattern
        end
      end
      [pattern, s]
    end

  end

  class FailPat < Pattern

    def __match?(needle)
    end

  end

  class Abort < Pattern

    def __match?(needle)
      raise MatchFailed
    end

  end

  class Fence < Match

    def __match?(needle, on_backtrack = nil)
      if on_backtrack == :fail_match
        needle.match_failed = true
        return nil
      elsif on_backtrack == :return_nil
        return nil
      elsif @block
        pattern = @block.call
      elsif @name
        pattern = needle.captures[@name] || ""
      elsif @pattern
        pattern = @pattern
      else
        return [:fail_match]
      end
      return [:return_nil] if pattern._match?(needle)
    end

  end

  class Succeed < Pattern
    def _match?(needle, thread_state = nil)
      needle.pull(thread_state)
      [needle.push(0)]
    end
  end
end

class String

  include Cannonbol::Operators

  def __match?(needle, thread_state = nil)

    if thread_state
      needle.pull(thread_state)
    elsif self.length == 0 or
          (!needle.ignore_case and needle.remaining_string[0..self.length-1] == self) or
          (needle.ignore_case and needle.remaining_string[0..self.length-1].upcase == self.upcase)
      [needle.push(self.length)]
    end
  end

end

class Regexp

  include Cannonbol::Operators

  def __match?(needle, thread_state = nil)
    if RUBY_ENGINE == 'opal'
      options = ""
      options += "m" if `#{self}.multiline`
      options += "g" if `#{self}.global`
      options += "i" if needle.ignore_case or `#{self}.ignoreCase`
    else
      options = self.options | (needle.ignore_case ? Regexp::IGNORECASE : 0)
    end
    @cannonbol_regex ||= Regexp.new("^#{self.source}", options )
    if thread_state
      needle.pull(thread_state)
    elsif m = @cannonbol_regex.match(needle.remaining_string)
      [needle.push(m[0].length)]
    end
  end

end


if RUBY_ENGINE == 'opal'

  class Proc

    def parameters
      /.*function[^(]*\(([^)]*)\)/.match(`#{self}.toString()`)[1].split(",").collect { |param| [:req, param.strip.to_sym]}
    end

  end

end

module Enumerable

  def match_any
    if self.first
      self[1..-1].inject(self.first) { |memo, item| memo | item }
    else
      FAIL
    end
  end

  def match_all
    self.inject("") { |memo, item| memo & item }
  end

end


class Object

  REM = Cannonbol::Rem.new

  ARB = Cannonbol::Arb.new

  FAIL = Cannonbol::FailPat.new

  ABORT = Cannonbol::Abort.new

  FENCE = Cannonbol::Fence.new

  SUCCEED = Cannonbol::Succeed.new

  def LEN(p={}, &block)
    Cannonbol::Len.new(p, &block)
  end

  def POS(p=nil, &block)
    Cannonbol::Pos.new(p, &block)
  end

  def RPOS(p=nil, &block)
    Cannonbol::RPos.new(p, &block)
  end

  def TAB(p=nil, &block)
    Cannonbol::Tab.new(p, &block)
  end

  def RTAB(p=nil, &block)
    Cannonbol::RTab.new(p, &block)
  end

  def ANY(p=nil, &block)
    Cannonbol::Any.new(p, &block)
  end

  def NOTANY(p=nil, &block)
    Cannonbol::NotAny.new(p, &block)
  end

  def SPAN(p=nil, &block)
    Cannonbol::Span.new(p, &block)
  end

  def BREAK(p=nil, &block)
    Cannonbol::Break.new(p, &block)
  end

  def BREAKX(p=nil, &block)
    Cannonbol::BreakX.new(p, &block)
  end

  def MATCH(p=nil, &block)
    Cannonbol::Match.new(p, &block)
  end

  def ARBNO(p=nil, &block)
    Cannonbol::Arbno.new(p, &block)
  end

  def FENCE(p=nil, &block)
    Cannonbol::Fence.new(p, &block)
  end

end
