require "cannonbol/version"

module Cannonbol
  
  class Cannonbol
    
    def initialize(&block)
      @pattern = TopLevelPattern.new(self.class.class_eval(&block))
    end
    
    def match(subject)
      @pattern.reset(subject).match?
    end
    
    class Pattern < Array
      
      def reset(top_level_pattern = nil)
        @top_level_pattern = top_level_pattern if top_level_pattern
        self.each { |e| e.reset(top_level_pattern) }
      end
      
      def cursor
        @top_level_pattern.cursor
      end
      
      def cursor=(val)
        @top_level_pattern.cursor = val
      end
      
      def subject
        @top_level_pattern.subject
      end
      
      def on_success(&block)
        OnSuccess.new(self, block)
      end
      
      def build_from_string(s)
        return s if s.respond_to? :match?
        StringPattern[s]
      end
      
      def to_s
        "#{self.class.name}#{super}"
      end
      
    end
    
    class StringPattern < Pattern
      
      def match?
        if self[0].length == 0 or subject[self.cursor..self.cursor+self[0].length-1] == self[0]
          self.cursor += self[0].length
          self[0]
        end
      end
      
      def reset(top_level_pattern = nil)
        @top_level_pattern = top_level_pattern if top_level_pattern
      end
      
    end
    
    class TopLevelPattern < Pattern
      
      attr_accessor :cursor
      attr_reader :subject
      
      def initialize(pattern)
        self[0] = build_from_string(pattern)
      end
      
      def reset(subject)
        @subject = subject
        @cursor = 0
        super(self)
      end
      
      def match?
        while cursor < @subject.length do
          starting_cursor = cursor
          matched = self[0].match?
          return subject[starting_cursor..cursor-1] if matched
          self.cursor += 1
          self[0].reset
        end
      end
      
    end
    
    class Choose < Pattern
      
      def reset(top_level_pattern = nil)
        super(top_level_pattern)
        @next_element = 0
        @starting_cursor = self.cursor
      end
      
      def match?
        
        while @next_element < self.length
          self.cursor = @starting_cursor
          return true if self[@next_element].match?
          @next_element += 1
        end
        reset and return false
      end
      
      def initialize(p1, p2)
        self << build_from_string(p1) << build_from_string(p2)
      end
      
      def |(p2)
        self << build_from_string(p2)
      end
      
      def &(p2)
        Concat.new(self, build_from_string(p2))
      end
      
    end
    
    class Concat < Pattern
      def initialize(p1, p2)
        self << build_from_string(p1) << build_from_string(p2)
      end
      
      def &(p2)
        self << build_from_string(p2)
      end
      
      def |(p2)
        Choose.new(self, build_from_string(p2))
      end
      
    end
    
    class OnSuccess < Pattern
      def initialize(pattern, block)
        self[0] = pattern
        @block = block
      end
    end
    
  end
  
end

class String
  
  def |(pat_or_string)
    Cannonbol::Cannonbol::Choose.new(self,pat_or_string)
  end
  
  def &(pat_or_string)
    Cannonbol::Cannonbol::Concat.new(self,pat_or_string)
  end
  
end