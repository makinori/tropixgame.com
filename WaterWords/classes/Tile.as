/**
* One space in grid.
*/
import error.*;
import framework.*;
import math.*;
import text.*;
import video.*;

class Tile
{
    // Class members:

    // enum State
    static public var STATE_ACTIVE:Number   = 0; // Tile is ready to be used.
    static public var STATE_INACTIVE:Number = 1;  // Not part of this level.
    static public var STATE_MAX:Number      = 2; // Last entry.

    // Instance members:

    public var state:Number;
    public var stateTime:Number;
    public var traversed:Boolean; // Temporary flag.
    public var x:Number; // World x position.
    public var y:Number; // World y position.

    private var m_letter:Number; // Our letter, stored as what Flash calls a charCode (16-bit Latin-1 unicode, I believe).
    private var m_selected:Boolean; // This is (partly) redundant with WaterWords::m_selection array, but it helps during rendering.
    private var m_swapping:Boolean; // True if we are currently swapping and should render with a swap image.
    private var m_bodyImage:Billboard2D; // Bubble.
    private var m_swapImage:Billboard2D; // Swap symbol.
    private var m_text:Text; // Displays our letter.

    // Constructor:

    public function Tile()
    {
        reset();
        x           = 0.0;
        y           = 0.0;
    }

    // Instance methods:

    public function update( deltaTime:Number ):Void
    {
        //Assert.ASSERT( m_bodyImage != undefined, "Tile.update() m_bodyImage is undefined" );

        stateTime += deltaTime;

        // Update renderables (scale, etc)

        // Wiggle only when selected to reduce performance impact.
        if( m_selected )
        {
            // Add some "wiggle" to the bubbles, offset uniquely per letter.
            var waterWords:WaterWords   = WaterWords.waterWordsInstance();
            var scaleOffset:Number      = 
                Math.sin( (3.0 * waterWords.gameTime()) + (m_letter) ) * 0.05;

            // Image doesn't reach edges, so scale up a little.
            var scale:Number        = WaterWords.TILE_RADIUS * 2.1;
            var screenPos:Vector2D  = waterWords.camera().toScreen( new Vector2D( x, y ) );

            m_bodyImage.setScale( scale + scaleOffset, scale + scaleOffset );
            m_bodyImage.setPosition( screenPos.x, screenPos.y );
        }
    }

    /// Create renderables for this tile.
    public function createRenderables( layer:Layer ):Void
    {
        //Assert.ASSERT( layer != undefined, "Tile.createRenderables() layer is undefined" );
        //Assert.ASSERT( m_bodyImage == undefined, "Tile.createRenderables() m_bodyImage is already defined" );
        //Assert.ASSERT( m_text == undefined, "Tile.createRenderables() m_text is already defined" );
        //Assert.ASSERT( m_letter != 0, "Tile.createRenderables() m_letter is 0" );

        var scale:Number    = WaterWords.TILE_RADIUS * 2 * WaterWords.TILE_IMAGE_SCALE;

        // Body
        m_bodyImage = layer.attachMovie( (m_selected ? "bubbleFullSelected.png" : "bubbleFull.png"), "tileBubble" );
        m_bodyImage.setScale( scale, scale );

        // Swap
        if( m_swapping )
        {
            m_swapImage = layer.attachMovie( "swapBody.png", "swapBody" );
        }

        // Letter
        m_text      = new Text( layer.createTextField(), "MinyaBold.ttf", 24, 0x000000, "center" );
        m_text.setText( String.fromCharCode( m_letter ) );

        positionRenderables();
    }

    /// Cleanup renderables for this tile.
    public function cleanupRenderables():Void
    {
        if( m_bodyImage )
        {
            m_bodyImage.removeMovieClip();
            m_bodyImage = undefined;
        }
        if( m_swapImage )
        {
            m_swapImage.removeMovieClip();
            m_swapImage = undefined;
        }
        if( m_text )
        {
            m_text.removeTextField();
            m_text = undefined;
        }
    }

    /// Position renderables.
    public function positionRenderables():Void
    {
        var screenPos:Vector2D = GameEngine.instance().camera().toScreen( new Vector2D( x, y ) );

        if( m_bodyImage != undefined )
        {
            m_bodyImage.setPosition( screenPos.x, screenPos.y );
        }
        if( m_swapImage != undefined )
        {
            m_swapImage.setPosition( screenPos.x, screenPos.y );
        }
        if( m_text != undefined )
        {
            m_text.setPosition( screenPos.x, screenPos.y );
        }
    }

    public function setState( state:Number ):Void
    {
        //Assert.ASSERT( state < STATE_MAX );

        if( this.state == state )
        {
            return;
        }

        this.state  = state;
        stateTime   = 0.0;
    }

    /// Set our letter.  Updates existing renderables.
    public function setLetter( letter:Number ):Void
    {
        m_letter = letter;
        if( m_text != undefined )
        {
            m_text.setText( String.fromCharCode( m_letter ) );
        }
    }

    /// Get our letter.
    public function letter():Number
    {
        return m_letter;
    }

    /// Select or deselect.  Will recreate renderables if necessary.
    public function setSelected( selected:Boolean, layer:Layer ):Void
    {
        //Assert.ASSERT( layer != undefined, "Tile.setSelected() layer is undefined" );

        if( m_selected == selected )
        {
            return;
        }
        m_selected = selected;
        cleanupRenderables();
        createRenderables( layer );
    }
    public function isSelected():Boolean
    {
        return m_selected;
    }

    /// Begin or end swapping.  Will recreate renderables if necessary.
    public function setSwapping( swapping:Boolean, layer:Layer ):Void
    {
        //Assert.ASSERT( layer != undefined, "Tile.setSwapping() layer is undefined" );

        if( m_swapping == swapping )
        {
            return;
        }
        m_swapping = swapping;
        cleanupRenderables();
        createRenderables( layer );
    }

    /// Undo any alterations to this tile, but preserve position.
    public function reset():Void
    {
        state	    = STATE_INACTIVE;
        stateTime   = 0.0;
        traversed   = false;
        m_letter    = 0;
        m_selected  = false;
        m_swapping  = false;
    }
};
