#--------------------------------------------------------------------------------------------------#
#--                                                                                              --#
#-- Class:    Sudoku::Board                                                                      --#
#-- Purpose:  Class which represents the Sudoku board                                            --#
#--                                                                                              --#
#-- Rev Hist: 2010-06-12  rws  Initial version                                                   --#
#--                                                                                              --#
#--------------------------------------------------------------------------------------------------#

require 'cell.rb'

module Sudoku
  BOARD_SIZE = 9

  class Board
    attr_reader :transDepth
    
    def initialize()
      @cells = Hash.new
      @cells.default = nil
      (1..Sudoku::BOARD_SIZE).to_a.each do |row|
        (1..Sudoku::BOARD_SIZE).to_a.each do |col|
          tag = genTag(row,col)
          @cells[tag] = Sudoku::Cell.new(Sudoku::BOARD_SIZE)
          @cells[tag].tag = tag
        end
      end
      
      @transDepth = 1
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Cell manipulation methods                                                                --#
    #----------------------------------------------------------------------------------------------#
    def solveCell(row,col,value)
      [row,col,value].each do |num|
        raise ArgumentError, "Expected an Integer" unless num.is_a?(Integer)
        unless (1..Sudoku::BOARD_SIZE).to_a.include?(num)
          raise ArgumentError, "Expected an Integer between 1 and " + Sudoku::BOARD_SIZE.to_s
        end
      end

      cell(row,col).value = value
        
      #-- Remove value from all other cells in the same row, column, and block
      row(row).each {|tag| cellByTag(tag).removePossibleValue(value)}
      col(col).each {|tag| cellByTag(tag).removePossibleValue(value)}
      block(blockNumber(row,col)).each {|tag| cellByTag(tag).removePossibleValue(value)}
    end
    
    def solveCellByTag(tag,value)
      row = rowFromTag(tag)
      col = colFromTag(tag)
      solveCell(row,col,value)
    end

    #----------------------------------------------------------------------------------------------#
    #-- Cell access methods                                                                      --#
    #----------------------------------------------------------------------------------------------#
    def cell(row,col)
      [row,col].each do |num|
        raise ArgumentError, "Expected an Integer" unless num.is_a?(Integer)
        unless (1..Sudoku::BOARD_SIZE).to_a.include?(num)
          raise ArgumentError, "Expected an Integer between 1 and " + Sudoku::BOARD_SIZE.to_s
        end
      end

      @cells[genTag(row,col)]
    end
    
    def cellByTag(tag)
      raise ArgumentError, "Expected a String" unless tag.is_a?(String)
      raise ArgumentError, "Tag [" + tag + "] does not exist" unless @cells.has_key?(tag)

      @cells[tag]
    end
    
    def row(row)
      raise ArgumentError, "Expected an Integer" unless row.is_a?(Integer)
      unless (1..Sudoku::BOARD_SIZE).to_a.include?(row)
        raise ArgumentError, "Expected an Integer between 1 and " + Sudoku::BOARD_SIZE.to_s
      end

      retArr = Array.new
      (1..Sudoku::BOARD_SIZE).to_a.each {|col| retArr.push(genTag(row,col))}
      retArr
    end
    
    def col(col)
      raise ArgumentError, "Expected an Integer" unless col.is_a?(Integer)
      unless (1..Sudoku::BOARD_SIZE).to_a.include?(col)
        raise ArgumentError, "Expected an Integer between 1 and " + Sudoku::BOARD_SIZE.to_s
      end

      retArr = Array.new
      (1..Sudoku::BOARD_SIZE).to_a.each {|row| retArr.push(genTag(row,col))}
      retArr
    end
    
    def block(block)
      raise ArgumentError, "Expected an Integer" unless block.is_a?(Integer)
      unless (1..Sudoku::BOARD_SIZE).to_a.include?(block)
        raise ArgumentError, "Expected an Integer between 1 and " + Sudoku::BOARD_SIZE.to_s
      end

      #-- blockDim is an Integer, so the / is Integer division -- no decimal
      blockDim = Math.sqrt(Sudoku::BOARD_SIZE).to_i
      minRow = (((block - 1) / blockDim) * blockDim) + 1
      maxRow = minRow + blockDim - 1
      minCol = (((block - 1) % blockDim) * blockDim) + 1
      maxCol = minCol + blockDim - 1
      
      retArr = Array.new
      (minRow..maxRow).to_a.each do |row|
        (minCol..maxCol).to_a.each do |col|
          retArr.push(genTag(row,col))
        end
      end
      retArr
    end
    
    def errorCells
      retArr = Array.new
      (1..Sudoku::BOARD_SIZE).to_a.each do |row|
        (1..Sudoku::BOARD_SIZE).to_a.each do |col|
          retArr.push(genTag(row,col)) if cell(row,col).error
        end
      end
      retArr
    end
    
    def actionCells
      retArr = Array.new
      (1..Sudoku::BOARD_SIZE).to_a.each do |row|
        (1..Sudoku::BOARD_SIZE).to_a.each do |col|
          retArr.push(genTag(row,col)) if cell(row,col).action
        end
      end
      retArr
    end

    def solvedCells
      cellsBySolvedStatus(true)
    end
    
    def unsolvedCells
      cellsBySolvedStatus(false)
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Informational methods                                                                    --#
    #----------------------------------------------------------------------------------------------#
    def blockNumber(row,col)
      [row,col].each do |num|
        raise ArgumentError, "Expected an Integer" unless num.is_a?(Integer)
        unless (1..Sudoku::BOARD_SIZE).to_a.include?(num)
          raise ArgumentError, "Expected an Integer between 1 and " + Sudoku::BOARD_SIZE.to_s
        end
      end

      #-- blockDim is an Integer, so the / is Integer division -- no decimal
      blockDim = Math.sqrt(Sudoku::BOARD_SIZE).to_i
      (((col - 1) / blockDim) + 1) + (((row - 1) / blockDim) * blockDim)
    end
    
    def genTag(row,col)
      row.to_s + '-' + col.to_s
    end
    
    def action?
      actionCells.length > 0
    end
    
    def errors?
      errorCells.length > 0
    end
    
    def solved?
      unsolvedCells.empty?
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
      @cells.each do |key, cell|
        cell.savepoint
      end
      @transDepth += 1
    end
    
    def commit
      if @transDepth > 1
        @cells.each do |key, cell|
          cell.commit
        end
      
        @transDepth -= 1
      end
    end
    
    def rollback
      if @transDepth > 1
        @cells.each do |key, cell|
          cell.rollback
        end
      
        @transDepth -= 1
      end
    end
    
    #----------------------------------------------------------------------------------------------#
    #-- Display methods                                                                          --#
    #----------------------------------------------------------------------------------------------#
    def display
      blockDim = Math.sqrt(Sudoku::BOARD_SIZE).to_i

      puts '    +-' + Array.new(Sudoku::BOARD_SIZE * 2 + blockDim,'-').join('') + '-+'
      (1..Sudoku::BOARD_SIZE).to_a.each do |row|
        print '    | '
        (1..Sudoku::BOARD_SIZE).to_a.each do |col|
          print cell(row,col).solved? ? cell(row,col).value.to_s : '.'
          print ' '
          
          if (col % blockDim) == 0
            print '|'
            print ' ' if col < Sudoku::BOARD_SIZE
          end
        end
        puts ''
        
        if ((row % blockDim) == 0) and (row < Sudoku::BOARD_SIZE)
          print '    |-'
          1.upto(blockDim) do |i|
            print '--' * blockDim
            print '+-' if i < blockDim
          end
          puts '|'
        end
      end
      puts '    +-' + Array.new(Sudoku::BOARD_SIZE * 2 + blockDim,'-').join('') + '-+'
    end
    

    #----------------------------------------------------------------------------------------------#
    #-- Private methods                                                                          --#
    #----------------------------------------------------------------------------------------------#
    private

    def cellsBySolvedStatus(solved)
      retArr = Array.new
      (1..Sudoku::BOARD_SIZE).to_a.each do |row|
        (1..Sudoku::BOARD_SIZE).to_a.each do |col|
          retArr.push(genTag(row,col)) if cell(row,col).solved? == solved
        end
      end
      retArr
    end
    
    def rowFromTag(tag)
      tag.split('-')[0].to_i
    end
    
    def colFromTag(tag)
      tag.split('-')[1].to_i
    end
  end
end


#--------------------------------------------------------------------------------------------------#
#-- End of File                                                                                  --#
#--------------------------------------------------------------------------------------------------#
