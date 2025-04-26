/**
* Level defines a grid configuration and goal word count.
*/
import container.*;
import error.*;
import math.*;

class Level
{
    // Instance members:

    public var gridShape:GridShape;
    public var goalWordCount:Number; // Find this many words to complete the level.

    // Constructor:

    public function Level()
    {
        gridShape       = new GridShape();
        goalWordCount   = 0;
    }

    // Instance methods:

    /// Construct level for given level index.  Call this before apply().
    public function construct( levelIndex:Number ):Void
    {
        switch( levelIndex )
        {
        case 0:
            goalWordCount = 5;
            applyGridShape( 0 );
            break;
        case 1:
            goalWordCount = 6;
            applyGridShape( 0 );
            break;
        case 2:
            goalWordCount = 7;
            applyGridShape( 1 );
            break;
        case 3:
            goalWordCount = 8;
            applyGridShape( 1 );
            break;
        case 4:
            goalWordCount = 9;
            applyGridShape( 1 );
            break;
        case 5:
            goalWordCount = 6;
            applyGridShape( 2 );
            break;
        case 6:
            goalWordCount = 7;
            applyGridShape( 2 );
            break;
        case 7:
            goalWordCount = 8;
            applyGridShape( 2 );
            break;
        case 8:
            goalWordCount = 9;
            applyGridShape( 2 );
            break;
        case 9:
            goalWordCount = 10;
            applyGridShape( 3 );
            break;
        default:
            //Assert.ASSERT( false, "Level.construct() invalid levelIndex: " + levelIndex );
        }
    }

    /// Apply grid shape.
    private function applyGridShape( shapeIndex:Number ):Void
    {
        switch( shapeIndex )
        {
        case 0:
            gridShape.active[0] = [false,  true,  true,  true, false, false, false];
            gridShape.active[1] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[2] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[3] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[4] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[5] = [false, false,  true, false, false, false, false];
            gridShape.active[6] = [false, false, false, false, false, false, false];
            gridShape.active[7] = [false, false, false, false, false, false, false];
            break;
        case 1:
            gridShape.active[0] = [false,  true,  true,  true, false, false, false];
            gridShape.active[1] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[2] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[3] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[4] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[5] = [ true,  true,  true,  true,  true, false, false];
            gridShape.active[6] = [false, false,  true, false, false, false, false];
            gridShape.active[7] = [false, false, false, false, false, false, false];
            break;
        case 2:
            gridShape.active[0] = [ true,  true, false, false, false, false, false];
            gridShape.active[1] = [ true,  true,  true,  true, false, false, false];
            gridShape.active[2] = [ true,  true,  true,  true,  true,  true, false];
            gridShape.active[3] = [ true,  true,  true,  true,  true,  true, false];
            gridShape.active[4] = [ true,  true,  true,  true,  true,  true, false];
            gridShape.active[5] = [false, false,  true,  true,  true,  true, false];
            gridShape.active[6] = [false, false, false, false,  true,  true, false];
            gridShape.active[7] = [false, false, false, false, false, false, false];
            break;
        case 3:
            gridShape.active[0] = [ true,  true, false, false, false,  true, false];
            gridShape.active[1] = [ true,  true,  true,  true,  true,  true, false];
            gridShape.active[2] = [ true,  true,  true,  true,  true,  true, false];
            gridShape.active[3] = [ true,  true,  true,  true,  true,  true, false];
            gridShape.active[4] = [ true,  true,  true,  true,  true,  true, false];
            gridShape.active[5] = [ true,  true,  true, false,  true,  true, false];
            gridShape.active[6] = [ true, false, false, false, false, false, false];
            gridShape.active[7] = [false, false, false, false, false, false, false];
            break;
        default:
            //Assert.ASSERT( false, "Level.applyGridShape() index invalid: " + shapeIndex );
        }
    }
    /// Apply this level to WaterWords game engine.
    public function apply():Void
    {
        var waterWords:WaterWords = WaterWords.waterWordsInstance();

        // Insert a known word as answer to this level's clue.
        var word:String = waterWords.clue().answer;

        // Choose a random starting tile for the word.
        // In order to find this starting tile, we'll start looking
        // for an active tile at a random point (sheesh).
        var column:Number           = XMath.randomInt( 0, WaterWords.GRID_WIDTH );
        var row:Number              = XMath.randomInt( 0, WaterWords.GRID_HEIGHT );
        var inserted:Boolean        = false;
        var letters:/*Number*/Array = new Array();
        var numChars:Number         = word.length;
        var i:Number;
        var j:Number;

        for( i = 0; i < numChars; i++ )
        {
            letters.push( word.charCodeAt( i ) );
        }

        for( i = 0; i < WaterWords.GRID_WIDTH; i++ )
        {
            for( j = 0; j < WaterWords.GRID_HEIGHT; j++ )
            {
                var gridI:Number = (column + i) % WaterWords.GRID_WIDTH;
                var gridJ:Number = (row + j) % WaterWords.GRID_HEIGHT;

                if( insertWord( gridI, gridJ, letters ) )
                {
                    inserted = true;
                    waterWords.setHint( gridI, gridJ );
                    break;
                }
            }
            if( inserted )
            {
                break;
            }
        }

        //Assert.ASSERT( inserted, "Level.apply() failed to insert word: " + word );
    }

    /// Insert (remaining portion of) word in random path from given coordinates.
    /// Do not loop back over self.
    /// If successful (word can be inserted fully), return true.  False otherwise.
    public function insertWord( gridI:Number, gridJ:Number, letters:/*Number*/Array ):Boolean
    {
        //Assert.ASSERT( letters.length > 0, "Level.insertWord() letters is empty" );

        var waterWords:WaterWords = WaterWords.waterWordsInstance();
        var i:Number;
        var j:Number;
        var tile:Tile = waterWords.tile( gridI, gridJ );

        if( tile.state == Tile.STATE_INACTIVE || tile.traversed )
        {
            return false;
        }
        tile.traversed = true;

        var letter:Number = letters[0];

        ArrayUtils.removeOrdered( letters, 0 );

        if( letters.length == 0 )
        {
            tile.setLetter( letter );
            tile.traversed = false;
            return true; // We're done
        }

        // Try each neighbor, in random(ish) order.
        var firstNeighbor:Number    = XMath.randomInt( 0, WaterWords.NUM_NEIGHBORS );
        var neighborCoord:Vector2D  = new Vector2D();

        for( i = 0; i < WaterWords.NUM_NEIGHBORS; i++ )
        {
            if( waterWords.neighborIndices( gridI, gridJ,
                (firstNeighbor + i) % WaterWords.NUM_NEIGHBORS, neighborCoord ) )
            {
                if( insertWord( neighborCoord.x, neighborCoord.y, letters ) )
                {
                    tile.setLetter( letter );
                    tile.traversed = false;
                    return true;
                }
            }
        }

        // Put our letter back on front of list
        ArrayUtils.insertOrdered( letters, 0, letter );

        tile.traversed = false;
        return false;
    }
};
