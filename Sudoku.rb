#!/usr/bin/ruby
#--------------------------------------------------------------------------------------------------#
#--                                                                                              --#
#-- Script:   Sudoku.rb                                                                          --#
#-- Purpose:  Solved the Sudoku puzzle stored in sudoku.txt                                      --#
#--                                                                                              --#
#-- Rev Hist: 2010-06-12  rws  Initial version                                                   --#
#--           2010-06-28  rws  Changed logic to try combinations and then recursion              --#
#--           2010-06-29  rws  Added row, col, and block elimination logic                       --#
#--                                                                                              --#
#--------------------------------------------------------------------------------------------------#

require 'yaml'
require 'board.rb'


#--------------------------------------------------------------------------------------------------#
#-- Define constants                                                                             --#
#--------------------------------------------------------------------------------------------------#
CONFIG = 'sudoku.config.yml'
PUZZLE = 'sudoku.txt'


#--------------------------------------------------------------------------------------------------#
#-- Define and initialize variables                                                              --#
#--------------------------------------------------------------------------------------------------#
board         = Sudoku::Board.new                # The Sudoku board
combinations  = 2                                # Max combinations to try before switching to
                                                 # a recursive algorithm
threads       = 1                                # If threads is greater than 1, the recursive
                                                 # algorithm will use multiple threads
unsolvedCells = Array.new                        # Array of unsolved cells. Used by the
                                                 # combination and recursion sections
verbose       = false                            # Display extra information while solving


#--------------------------------------------------------------------------------------------------#
#-- Read the and process the config file                                                         --#
#--------------------------------------------------------------------------------------------------#
if File.exists?(CONFIG) and File.readable?(CONFIG)
  begin
    yml = YAML::load(File.open(CONFIG))
    
    combinations = yml['combinations'] if yml.key?('combinations')
    threads = yml['threads'] if yml.key?('threads')
    verbose = yml['verbose'] if yml.key?('verbose')
  rescue
    raise RuntimeError, 'Invalid configuration file [' + CONFIG + ']'
  end
end


#--------------------------------------------------------------------------------------------------#
#-- Initialize the board                                                                         --#
#--------------------------------------------------------------------------------------------------#
if File.exists?(PUZZLE) and File.readable?(PUZZLE)
  puzzleFile = File.new(PUZZLE, File::RDONLY)
  row = 1
  while (line = puzzleFile.gets)
    col = 1
    line.split(/\s+/).each do |val|
      raise RuntimeError, 'Supplied puzzle is too large' if board.cell(row,col).nil?
      
      begin
        board.solveCell(row,col,val.to_i) unless val.to_s.upcase == '.'
      rescue
        raise RuntimeError, 'Invalid integer [' + val.to_s + ']' +
                            ' in puzzle at row ' + row.to_s + ', col ' + col.to_s
      end
      col += 1
    end
    row += 1
  end
end


#--------------------------------------------------------------------------------------------------#
#-- Make sure we have a valid board                                                              --#
#--------------------------------------------------------------------------------------------------#
if board.errors?
  board.errorCells.each {|tag| puts 'Error in cell ' + tag}
  raise RuntimeError,"Invalid board"
end


#--------------------------------------------------------------------------------------------------#
#-- Define procedures                                                                            --#
#--------------------------------------------------------------------------------------------------#
def guessToString(tag,value)
  return tag + ':' + value.to_s + '|'
end

def stringToGuess(decodeStr)
  return /^(\d+-\d+):(\d+)\|/.match(decodeStr)[-2..-1]
end

def tryBoard(board,verbose)
  passes = 0
  while (not board.solved?) and (not board.errors?)
    passes += 1
    if verbose
      puts ''
      puts 'Pass #' + passes.to_s
      puts '  - Solved cells:   ' + board.solvedCells.length.to_s
      puts '  - Unsolved cells: ' + board.unsolvedCells.length.to_s
      puts '  - Action cells:   ' + board.actionCells.length.to_s
    end
  
    #-- Update all the action cells
    board.actionCells.each do |tag|
      puts '                    ' + tag.to_s + ' value: ' +
           board.cellByTag(tag).possibleValues[0].to_s if verbose
      value = board.cellByTag(tag).possibleValues[0]
      board.solveCellByTag(tag,value) unless board.cellByTag(tag).error
    end

    #-- Check for any cells which has a possible value not shared by any other cell
    #-- in the same row, column, or block
    tryEliminations = true
    while tryEliminations
      tryEliminations = false
      
      (1..Sudoku::BOARD_SIZE).to_a.each do |row|
        (1..Sudoku::BOARD_SIZE).to_a.each do |col|
          unless board.cell(row,col).solved?
            cellTag = board.genTag(row,col)
            block = board.blockNumber(row,col)
            cellsHash = Hash.new
            cellsHash['Row']   = board.row(row)
            cellsHash['Col']   = board.col(col)
            cellsHash['Block'] = board.block(block)

            cellsHash.keys.each do |elemType|
              possVals = board.cell(row,col).possibleValues
              cellsHash[elemType].each do |tag|
                board.cellByTag(tag).possibleValues.each {|val| possVals.delete(val)} unless tag == cellTag
              end
              if possVals.length == 1
                board.solveCellByTag(cellTag,possVals[0])
                puts '  - ' + (elemType + ' Elim:').ljust(16) + cellTag + ' -> ' + possVals[0].to_s if verbose
                tryEliminations = true
              end
            end
          end
        end
      end
    end

    if verbose
      puts ''
      board.display
    end
    break if board.actionCells.empty?
  end
  
  if verbose
    puts ''
    puts '  - Board has errors!' if board.errors?
    puts '  - Board stuck!' if (not board.solved?) and (not board.action?)
    puts '  - Board solved!' if board.solved?
  end
  
  return board.solved?, board.errors?
end


#--------------------------------------------------------------------------------------------------#
#-- Display initial information                                                                  --#
#--------------------------------------------------------------------------------------------------#
if verbose
  puts ''
  puts '======================'
  puts '== Starting board   =='
  puts '======================'
  puts ''
  board.display

  puts ''
  puts ''
  puts '======================'
  puts '== Trying to solve  =='
  puts '======================'
end


#--------------------------------------------------------------------------------------------------#
#-- Try to solve the board using rules (cell elimination) only                                   --#
#--------------------------------------------------------------------------------------------------#
isSolved, hasErrors = tryBoard(board,verbose)


#--------------------------------------------------------------------------------------------------#
#-- Create an Array of tags of cells which have not been solved                                  --#
#-- This array is sorted based on the number of possible guesses for the cell. The hope the cell --#
#-- with the fewest possibles will be guessed correctly the fastest, and that the new correct    --#
#-- cell will lead to a solution                                                                 --#
#--                                                                                              --#
#-- Note: the subsort on the tag name is not needed for the solution, but was added so that the  --#
#--       guesses taken are always the same. I was finding the Ruby interpreter under windows    --#
#--       was doing one thing and JRuby another. This allows repeatable runs.                    --#
#--------------------------------------------------------------------------------------------------#
unless isSolved or hasErrors
  unsolvedCells = board.unsolvedCells.sort do |a,b|
    if board.cellByTag(a).possibleValues.length == board.cellByTag(b).possibleValues.length
      a <=> b
    else
      board.cellByTag(a).possibleValues.length <=> board.cellByTag(b).possibleValues.length
    end
  end
  if verbose
    puts ''
    puts 'Unsolved cells:'
    unsolvedCells.each do |tag|
      puts '  - ' + tag + ' (' + board.cellByTag(tag).possibleValues.join(',') + ')'
    end
  end
end


#--------------------------------------------------------------------------------------------------#
#-- Try to solve using combinations if not solved                                                --#
#-- The initial cells did not provide enought information to solve the puzzle. We will now start --#
#-- solving the board by running through the combinations of possible values for cells. We will  --#
#-- only try going as deep as the combinations setting.                                          --#
#--------------------------------------------------------------------------------------------------#
unless isSolved or hasErrors
  if verbose
    puts ''
    puts '========================='
    puts '== Trying Combinations =='
    puts '========================='
    puts ''
  end

  numCellsCombination = 1
  while (not isSolved) and (numCellsCombination <= combinations)
    puts '' if verbose
    puts '==> Trying combinations of ' + sprintf('%2s',numCellsCombination) +
         ' cell' + (numCellsCombination == 1 ? ' ' : 's') + ' <=='
    
    unsolvedCells.combination(numCellsCombination).each do |tagArr|
      unless isSolved
        puts ''
        puts 'Trying values for: ' + tagArr.join(', ') if verbose
        unsolvedCellsPtrs = Array.new(tagArr.length,0)
      end

      while (not isSolved) and (unsolvedCellsPtrs[0] < board.cellByTag(tagArr[0]).possibleValues.length)
        board.savepoint
        puts '  - Saving board state' if verbose
        
        #-- Determine values to try
        tryValues = Array.new
        tagArr.each_index do |ndx|
          tag = tagArr[ndx]
          value = board.cellByTag(tag).possibleValues[unsolvedCellsPtrs[ndx]]
          puts '  - Setting ' + tag + ' to ' + value.to_s +
               ' (' + board.cellByTag(tag).possibleValues.join(',') + ')' if verbose
          tryValues.push(guessToString(tag,value))
        end

        #-- Set the values. This is being done separately from determining as setting a cell
        #-- will change possibleValues of additional cells.
        tryValues.each do |guessStr|
          tag, value = stringToGuess(guessStr)
          board.solveCellByTag(tag,value.to_i)
        end
        
        #-- Try the board
        if board.errors?
          isSolved  = false
          hasErrors = true
        else
          isSolved, hasErrors = tryBoard(board,verbose)
        end
        
        #-- Move on to the next guess
        unless isSolved
          board.rollback
          puts '  - Rolling back board' if verbose
          
          ndx = tagArr.length - 1
          donePtrUpdate = false
          while not donePtrUpdate
            unsolvedCellsPtrs[ndx] += 1
            if unsolvedCellsPtrs[ndx] < board.cellByTag(tagArr[ndx]).possibleValues.length
              donePtrUpdate = true
            else
              if ndx > 0
                unsolvedCellsPtrs[ndx] = 0
                ndx -= 1
              else
                donePtrUpdate = true
              end
            end
          end
        end
      end
    end
    numCellsCombination += 1 unless isSolved
  end
end


#--------------------------------------------------------------------------------------------------#
#-- Switch to recursive brute force if still not solved                                          --#
#--------------------------------------------------------------------------------------------------#
unless isSolved or hasErrors
  if verbose
    puts ''
    puts '======================'
    puts '== Using Recursion  =='
    puts '======================'
    puts ''
  end
end


#--------------------------------------------------------------------------------------------------#
#-- Display the solution                                                                         --#
#--------------------------------------------------------------------------------------------------#
if isSolved and (not hasErrors)
  puts ''
  puts 'Final Solution:'
  board.display
else
  puts 'Board was not able to be solved'
end


#--------------------------------------------------------------------------------------------------#
#-- End of Script                                                                                --#
#--------------------------------------------------------------------------------------------------#
