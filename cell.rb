#--------------------------------------------------------------------------------------------------#
#--                                                                                              --#
#-- Class:    Sudoku::Cell                                                                       --#
#-- Purpose:  Class which represents a single Sudoku cell                                        --#
#--                                                                                              --#
#-- Rev Hist: 2010-06-12  rws  Initial version                                                   --#
#--           2010-06-29  rws  Updated possibleValues getter to return a cloned object           --#
#--                                                                                              --#
#--------------------------------------------------------------------------------------------------#

module Sudoku
  class Cell
    attr_reader :transDepth

    def initialize(size)
      @possibleValues = Array.new
      @possibleValues.push((1..size).to_a)
      @value          = Array.new
      @value.push(nil)

      @tag = ''
      @transDepth = 1
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Cell manipulation methods                                                                --#
    #----------------------------------------------------------------------------------------------#
    def removePossibleValue(num)
      unless num.is_a?(Integer)
        raise ArgumentError, "Expected an Integer"
      end
      
      @possibleValues[-1].delete(num)
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Cell attribute methods (setters/getters)                                                 --#
    #----------------------------------------------------------------------------------------------#
    def noticeAction
      (@possibleValues[-1].length == 1)
    end
    
    def action
      noticeAction
    end
    
    def noticeError
      ((not solved?) and @possibleValues[-1].empty?)
    end
    
    def error
      noticeError
    end
    
    def possibleValues
      @possibleValues[-1].clone
    end
    
    def tag=(value)
      @tag = value.to_s
    end

    def tag
      @tag
    end

    def value=(num)
      raise ArgumentError,"The value of this cell has already been set" if solved?
      
      @value[-1] = num if @possibleValues[-1].include?(num)
      @possibleValues[-1] = []
    end
    
    def value
      @value[-1]
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Informational methods                                                                    --#
    #----------------------------------------------------------------------------------------------#
    def solved?
      not value.nil?
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Clone                                                                                    --#
    #----------------------------------------------------------------------------------------------#
    def clone
      Marshal.load(Marshal.dump(self))
    end

    #----------------------------------------------------------------------------------------------#
    #-- Transactional methods                                                                    --#
    #----------------------------------------------------------------------------------------------#
    def savepoint
      @possibleValues.push(@possibleValues[-1].clone)
      @value.push(@value[-1])
      
      @transDepth += 1
    end
    
    def commit
      if @transDepth > 1
        @possibleValues.delete_at(-2)
        @value.delete_at(-2)
        
        @transDepth -= 1
      end
    end
    
    def rollback
      if @transDepth > 1
        @possibleValues.pop
        @value.pop
        
        @transDepth -= 1
      end
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Private methods                                                                          --#
    #----------------------------------------------------------------------------------------------#
    private
    
  end
end


#--------------------------------------------------------------------------------------------------#
#-- End of File                                                                                  --#
#--------------------------------------------------------------------------------------------------#
