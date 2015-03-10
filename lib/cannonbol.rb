require "cannonbol/version"

module Cannonbol
  
  # ways to create a pattern
  # use & or | operator on string
  # use other Cannobol operator on a string
  # Cannonbol.new
  
  # matching
  # call match?(subject) on a pattern or a string 
  
  def self.new
    Pattern.new
  end
  
  def self.match?(pattern, string, anchor = nil)
    Needle.new(string).thread(pattern, anchor)
  end
  
  class Needle
    
    attr_reader :cursor
    attr_reader :string
    
    def initialize(string)
      @string = string
    end
    
    def thread(pattern, anchor = nil)
      @cursor = 0
      @starting_character = nil
      @success_blocks = []
      while @cursor < @string.length
        if pattern._match?(self)
          @success_blocks.each(&:call)
          return match
        end
        return nil if anchor
        @cursor += 1
      end
      nil
    end
       
    def remaining_string
      @string[@cursor..-1]
    end
     
    def push(length, &success_block)
      thread_state = [@starting_character, @cursor, @success_blocks]
      @starting_character ||= @cursor
      @cursor += length
      @success_blocks << success_block if success_block
      thread_state
    end
      
    def pull(thread_state)
      @starting_character, @cursor = thread_state if thread_state
      nil
    end
      
    def match
      @string[@starting_character..@cursor-1] if @starting_character
    end
      
    def fail
      raise "match failure"
    end
      
  end
   
  class Pattern < Array
    
    def initialize(pattern = nil)
      @pattern = pattern
    end
    
    def to_s
      "#{self.class.name}#{super}"
    end
    
    def match?(s, anchor = nil)
      Needle.new(s).thread(self, anchor)
    end
    
    def _match?(needle)
      []
    end
    
    def |(pattern)
      Choose.new(self, pattern)
    end
  
    def &(pattern)
      Concat.new(self, pattern)
    end
    
    def on_success(&block)
      OnSuccess.new(self, &block)
    end
    
    def rem
      Cannonbol::Rem.new(self)
    end
    
    def arb
      Cannonbol::Arb.new(self)
    end
    
    def len(l=nil, &block)
      Cannonbol::Len.new(self, l, &block)
    end
    
    def pos(p=nil, &block)
      Cannonbol::Pos.new(self, p, &block)
    end  
    
    def rpos(p=nil, &block)
      Cannonbol::RPos.new(self, p, &block)
    end  
    
    def tab(p=nil, &block)
      Cannonbol::Tab.new(self, p, &block)
    end
    
    def rtab(p=nil, &block)
      Cannonbol::RTab.new(self, p, &block)
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
    
    def initialize(pattern, &block)
      @pattern = pattern
      @block = block
    end
    
    def _match?(needle, thread_state = nil)
      starting_cursor = needle.cursor
      if thread_state
        needle.pull(thread_state)
      elsif @pattern._match?(needle)
        ending_cursor = needle.cursor-1
        [ needle.push(0) { @block.call(needle.string[starting_cursor..ending_cursor]) } ]
      end
    end
    
  end
  
  class Rem < Pattern
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle_pull(thread_state)
      elsif @pattern._match?(needle)
        [needle.push(needle.string.length-needle.cursor)]
      end 
    end
    
  end
  
  class Arb < Pattern
    
    def _match?(needle, match_length = 0, thread_state = nil)
      needle.pull(thread_state)
      while needle.remaining_string.length >= match_length 
        thread_state = needle.push(match_length)
        match_length += 1
        return [match_length, thread_state] if @pattern._match?(needle) 
        needle.pull(thread_state)
      end
    end
    
  end
  
  class Len < Pattern
    
    def initialize(pattern, len = nil, &block)
      @pattern = pattern
      @block = block
      @len = len
    end 
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      else
        len = @block ? @block.call : @len
        [needle.push(len)] if needle.remaining_string.length >= len and @pattern._match?(needle)
      end
    end
    
  end
  
  class Pos < Pattern
    
    def initialize(pattern, pos = nil, &block)
      @pattern = pattern
      @block = block
      @pos = pos
    end 
    
    def _match?(needle, matched = nil)
      return (needle.cursor == (@block ? @block.call : @pos) and @pattern._match?(needle)) unless matched
    end 
    
  end 
  
  class RPos < Pos
    
    def _match?(needle, matched = nil)
      return (needle.string.length-needle.cursor == (@block ? @block.call : @pos) and @pattern._match?(needle)) unless matched
    end 
    
  end
  
  class Tab < Pos
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      else
        len = (@block ? @block.call : @pos) - needle.cursor
        [needle.push(len)] if len > 0 and needle.remaining_string.length >= len and @pattern._match?(needle)
      end
    end
    
  end
  
  class RTab < Pos
    
    def _match?(needle, thread_state = nil)
      if thread_state
        needle.pull(thread_state)
      else
        len = (needle.remaining_string.length - (@block ? @block.call : @pos)) - needle.cursor
        [needle.push(len)] if len > 0 and needle.remaining_string.length >= len and @pattern._match?(needle)
      end
    end
    
  end
  
end

class String
  
  def |(pat_or_string)
    Cannonbol::Choose.new(self,pat_or_string)
  end
  
  def &(pat_or_string)
    Cannonbol::Concat.new(self,pat_or_string)
  end
  
  def on_success(&block)
    Cannonbol::OnSuccess.new(self, &block)
  end
  
  def rem
    Cannonbol::Rem.new(self)
  end
  
  def arb
    Cannonbol::Arb.new(self)
  end
    
  def len(l=nil, &block)
    Cannonbol::Len.new(self, l, &block)
  end
  
  def pos(p=nil, &block)
    Cannonbol::Pos.new(self, p, &block)
  end  
  
  def rpos(p=nil, &block)
    Cannonbol::RPos.new(self, p, &block)
  end  
  
  def tab(p=nil, &block)
    Cannonbol::Tab.new(self, p, &block)
  end
  
  def rtab(p=nil, &block)
    Cannonbol::RTab.new(self, p, &block)
  end
  
  def match?(s, anchor = nil)
    Cannonbol::Needle.new(s).thread(self, anchor)
  end
  
  def _match?(needle, thread_state = nil)
    if thread_state
      needle.pull(thread_state)
    elsif needle.remaining_string[0..self.length-1] == self
      [needle.push(self.length)]
    end
  end
  
end