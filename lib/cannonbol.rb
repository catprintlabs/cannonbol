require "cannonbol/version"

module Cannonbol
    
  class MatchString < String
    
    attr_reader :captured
    attr_reader :match_start
    attr_reader :match_end
    
    def initialize(string, match_start, match_end, captured)
      @cannonbol_string = string
      @match_start = match_start
      @match_end = match_end
      @captured = captured
      super(@match_end < 0 ? "" : string[@match_start..@match_end])
    end 
    
    def replace_match_with(s)
      @cannonbol_string.dup.tap do |new_s| 
        new_s[@match_start..@match_end] = "" if @match_end >= 0
        new_s.insert(@match_start, s)
      end 
    end
    
  end
  
  class Needle
    
    attr_reader :cursor
    attr_reader :string
    
    def initialize(string)
      @string = string
    end
    
    def thread(pattern, opts = {}, &match_block)
      @captures = {}
      anchor = opts[:anchor]
      raise_error = opts[:raise_error]
      replacement_value = opts[:replace_with]
      as_hash = opts[:as_hash]
      @cursor = 0
      try_again = true
      while @cursor < @string.length and try_again
        @starting_character = nil
        @success_blocks = []
        if pattern._match?(self)
          @starting_character ||= @cursor
          @success_blocks.each(&:call)
          match = if match_block
            match_block.call(*match_block.parameters[0..-1].collect { |param| @captures[param[1].to_sym] })
          elsif as_hash
            @captures[as_hash] = @cursor == 0 ? "" : @string[@starting_character..@cursor-1]
            @captures
          elsif replacement_value
            @string.dup.tap do |new_s| 
              new_s[@starting_character..@cursor-1] = "" if @cursor > 0
              new_s.insert(@starting_character, replacement_value)
            end
          else
            MatchString.new(@string, @starting_character, @cursor-1, @captures)
          end
          return match
        end
        try_again = !anchor
        @cursor += 1
      end
      raise "No Match" if raise_error 
    end
    
    def capture(name, value)
      @captures[name.to_sym] = value if name
    end
      
       
    def remaining_string
      @string[@cursor..-1]
    end
     
    def push(length, &success_block)
      thread_state = [@starting_character, @cursor, @success_blocks.dup]
      @starting_character ||= @cursor
      @cursor += length
      @success_blocks << success_block if success_block
      thread_state
    end
      
    def pull(thread_state)
      @starting_character, @cursor, @success_blocks = thread_state if thread_state
      nil
    end
      
    def fail
      raise "match failure"
    end
      
  end
  
  module Operators
    
    def match?(s, opts = {}, &match_block)
      Needle.new(s).thread(self, opts, &match_block)
    end
    
    def |(pattern)
      Choose.new(self, pattern)
    end
  
    def &(pattern)
      Concat.new(self, pattern)
    end

    def on_success(name = nil, &block)
      OnSuccess.new(self, name, &block)
    end
    
    def on_match(&block)
      OnMatch.new(self, &block)
    end
    
    def capture_as(name)
      OnSuccess.new(self, name)
    end
    
  end
   
  class Pattern < Array
    
    include Operators
    
    def to_s
      "#{self.class.name}#{super}"
    end
    
    def _match?(needle)
      []
    end
      
  end
  
  class Choose < Pattern
    
    def _match?(needle, i = 0, s = [])
      while i < self.length
        s = self[i]._match?(needle, *s)
        return [i, s] if s
        s = []
        i += 1
      end
    end
    
    def initialize(p1, p2)
      self << p1 << p2
    end
    
    def |(p2)
      self << p2
    end
    
    def &(p2)
      Concat.new(self, p2)
    end
    
  end
  
  class Concat < Pattern
    
    def _match?(needle, i = 0, s = [])
      while i < self.length and i >= 0
        s[i] = self[i]._match?(needle, *(s[i] || []))
        i = s[i] ? i+1 : i-1
      end
      [i-1, s] if i == self.length
    end
    
    def initialize(p1, p2)
      self << p1 << p2
    end
    
    def &(p2)
      self << p2
    end
    
    def |(p2)
      Choose.new(self, p2)
    end
    
  end
  
  class OnSuccess < Pattern
    
    def initialize(pattern, capture_name = nil, &block)
      @pattern = pattern
      @capture_name = capture_name
      @block = block
    end
    
    def _match?(needle, thread_state = nil, starting_cursor = nil, s=[])
      needle.pull(thread_state)
      starting_cursor ||= needle.cursor
      if s = @pattern._match?(needle, *s)
        ending_cursor = needle.cursor-1
        push = needle.push(0) do
          value = ending_cursor < 0 ? "" : needle.string[starting_cursor..ending_cursor]
          needle.capture(@capture_name, value)
          @block.call(value) if @block
        end
        [ push, starting_cursor, s ]
      end
    end
    
  end
  
  class OnMatch < Pattern
    
    def initialize(pattern, &block)
      @pattern = pattern
      @block = block
    end
    
    def _match?(needle, starting_cursor = nil, s=[])
      starting_cursor ||= needle.cursor
      if s = @pattern._match?(needle, *s)
        @block.call(needle.cursor == 0 ? "" : needle.string[starting_cursor..needle.cursor-1])
        [starting_cursor, s]
      end
    end
    
  end 
  
  class Rem < Pattern
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle_pull(thread_state)
      else
        [needle.push(needle.string.length-needle.cursor)]
      end 
    end
    
  end
  
  class Arb < Pattern
    
    def _match?(needle, match_length = 0, thread_state = nil)
      needle.pull(thread_state)
      if needle.remaining_string.length >= match_length 
        thread_state = needle.push(match_length)
        match_length += 1
        [match_length, thread_state]
      end
    end
    
  end
  
  class ParameterizedPattern < Pattern
    
    def initialize(param = nil, &block)
      @param = param
      @block = block
    end
    
    def self.parameter(name, &post_processor)
      @post_processor = post_processor
      define_method(name) do 
        val = @block ? @block.call : @param
        val = post_processor.call(val) if @post_processor
        val
      end
    end
    
  end
  
  class Len < ParameterizedPattern
    
    parameter :len
    
    def _match?(needle, thread_state = nil)

      if thread_state
        needle.pull(thread_state)
      else
        len_temp = len
        [needle.push(len_temp)] if needle.remaining_string.length >= len_temp
      end
      
    end
    
  end
  
  class Pos < ParameterizedPattern
    
    parameter :pos
    
    def _match?(needle, matched = nil)
      return [true] if needle.cursor == pos and !matched
    end 
    
  end 
  
  class RPos < ParameterizedPattern
    
    parameter :pos
    
    def _match?(needle, matched = nil)
      return [true] if needle.string.length-needle.cursor == pos and !matched
    end 
    
  end
  
  class Tab < ParameterizedPattern
    
    parameter :pos
    
    def _match?(needle, thread_state = nil)
      
      if thread_state
        needle.pull(thread_state)
      else
        len = pos - needle.cursor
        [needle.push(len)] if len > 0 and needle.remaining_string.length >= len 
      end
    end
    
  end
  
  class RTab < ParameterizedPattern
    
    parameter :pos
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      else
        len = (needle.remaining_string.length - pos) 
        [needle.push(len)] if len >= 0 and needle.remaining_string.length >= len
      end
    end
    
  end
  
  class Any < ParameterizedPattern
    
    parameter :chars, &:split
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      elsif chars.include? needle.remaining_string[0..0]
        [needle.push(1)]
      end
    end
    
  end
  
  class NotAny < ParameterizedPattern
    
    parameter :chars, &:split
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      elsif !(chars.include? needle.remaining_string[0..0])
        [needle.push(1)]
      end
    end
    
  end  
  
  class Span < ParameterizedPattern
    
    parameter :chars, &:split
    
    def _match?(needle, match_length = nil, thread_state = nil)
      unless match_length
        the_chars, match_length = chars, 0
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
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      else
        the_chars, len = chars, 0
        while needle.remaining_string.length > len and !(the_chars.include? needle.remaining_string[len..len])
          len += 1
        end 
        [needle.push(len)]
      end 
    end 
    
  end 

  
  class BreakX < ParameterizedPattern
    
    parameter :chars, &:split
    
    def _match?(needle, len = 0, thread_state = nil)
      needle.pull(thread_state)
      the_chars = chars
      while needle.remaining_string.length > len and !(the_chars.include? needle.remaining_string[len..len])
        len += 1
      end 
      [len+1, needle.push(len)] if needle.remaining_string.length >= len
    end 
    
  end   
  
end

class String
  
  include Cannonbol::Operators
  
  def _match?(needle, thread_state = nil)
    if thread_state
      needle.pull(thread_state)
    elsif needle.remaining_string[0..self.length-1] == self
      [needle.push(self.length)]
    end
  end
  
end

class Regexp
  
  include Cannonbol::Operators
  
  def _match?(needle, thread_state = nil)
    @cannonbol_regex ||= Regexp.new("^#{self.source}", self.options)
    if thread_state
      needle.pull(thread_state)
    elsif m = @cannonbol_regex.match(needle.remaining_string)
      [needle.push(m[0].length)]
    end
  end
  
end

class Object
    
  REM = Cannonbol::Rem.new
  
  ARB = Cannonbol::Arb.new
  
  def LEN(p=nil, &block)
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
  
end