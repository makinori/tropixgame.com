/**
* GridShape defines a 2D grid of active and inactive tiles.
*/
import error.*;

class GridShape
{
    // Instance members:

    // 2D array of active flags determines which tiles are part of grid for this level
    // Size is GRID_WIDTH x GRID_HEIGHT;
    public var active:/*Array*/Array;

    // Constructor:

    public function GridShape()
    {
        var i:Number;
        var j:Number;

        active = new Array();
        for( i = 0; i < WaterWords.GRID_WIDTH; i++ )
        {
            active[i] = new Array();
            for( j = 0; j < WaterWords.GRID_HEIGHT; j++ )
            {
                active[i][j] = true;
            }
        }
    }
};
