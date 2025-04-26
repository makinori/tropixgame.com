import audio.*;
/**
* Swap is a powerup object allowing user to switch 
* two letters in the grid.
* Swap acts an clickable icon when docked.
*/
import audio.*;
import error.*;
import framework.*;
import math.*;
import text.*;
import video.*;

class Swap
{
    // Class members:

    // enum State
    static public var STATE_RISING:Number       = 0; // Appearing into inventory.
    static public var STATE_DOCKED:Number       = 1; // Sitting in inventory.
    static public var STATE_MOUSE_OVER:Number   = 2; // Highlighted in inventory.
    static public var STATE_CURSOR:Number       = 3; // Attached to cursor, in process of selecting source and destination.
    static public var STATE_SWAPPING:Number     = 4; // Animating swap.

    // Instance members:

    public var state:Number;
    public var stateTime:Number;
    public var x:Number; // Screen x position.
    public var y:Number; // Screen y position.
    public var destX:Number; // Screen destination x position.
    public var destY:Number; // Screen destination y position.

    private var m_bubbleImage:Billboard2D; // Rising bubble.
    private var m_bodyImage:Billboard2D; // Swap body.
    private var m_glowImage:Billboard2D; // Background glow.

    // Constructor:

    public function Swap()
    {
        state       = STATE_RISING;
        stateTime   = 0.0;
        x           = 0.0;
        y           = 0.0;
        destX       = 0.0;
        destY       = 0.0;
    }

    // Instance methods:

    public function update( deltaTime:Number ):Void
    {
        stateTime += deltaTime;

        // Animate towards destination position (in all states)
        {
            var deltaX:Number   = destX - x;
            var deltaY:Number   = destY - y;
            var SPEED:Number    = 300.0;
            var speed:Number    = SPEED * deltaTime;
            var magSqr:Number   = (deltaX * deltaX) + (deltaY * deltaY);

            if( magSqr > speed * speed )
            {
                var mag:Number = Math.sqrt( magSqr );

                deltaX = (deltaX / mag) * speed;
                deltaY = (deltaY / mag) * speed;
            }
            x += deltaX;
            y += deltaY;
        }

        // Check for mouseover
        var waterWords:WaterWords   = WaterWords.waterWordsInstance();
        var mouseOver:Boolean       = false;
        var toMouse:Vector2D        = Vector2D.difference( waterWords.screenMouse, new Vector2D( x, y ) );
        var scale:Number            = 0.5;

        if( toMouse.magnitudeSquared() < WaterWords.SWAP_HANDLE_RADIUS * WaterWords.SWAP_HANDLE_RADIUS )
        {
            mouseOver   = true;
        }

        switch( state )
        {
        case STATE_RISING:
            {
                var RISE_DURATION:Number = 1.0;

                if( stateTime > RISE_DURATION )
                {
                    m_bodyImage.setVisible( true );
                    setState( STATE_DOCKED );

                    // Effects
                    Player.playSound( "pop", 1.0, 0.0 );
                    waterWords.effectSystem( "bubbleSplatWhite", x, y );
                }
                else
                {
                    m_bodyImage.setVisible( false );
                    WaterWords.animateLetterBubbleRise( stateTime, m_bubbleImage, .8 );
                }
            }
            break;
        case STATE_DOCKED:
            if( mouseOver )
            {
                setState( STATE_MOUSE_OVER );
            }
            break;
        case STATE_MOUSE_OVER:
            scale = 0.85;
            if( !mouseOver )
            {
                setState( STATE_DOCKED );
            }
            break;
        case STATE_CURSOR:
            scale = 1.0;
            break;
        case STATE_SWAPPING:
            m_bodyImage.setVisible( false );
            break;
        }

        // Render glow skeleton behind docked swap icon
        m_glowImage.setVisible( state == STATE_DOCKED || state == STATE_MOUSE_OVER );

        // Scale up on mouse over
        m_glowImage.setScale( scale * 1.5, scale * 1.5 );
        m_bodyImage.setScale( scale, scale );

        // Position renderables
        positionRenderables();
    }

    /// Create renderables for this swap.
    public function createRenderables( layer:Layer ):Void
    {
        //Assert.ASSERT( layer != undefined, "Swap.createRenderables() layer is undefined" );
        //Assert.ASSERT( m_bodyImage == undefined, "Swap.createRenderables() m_bodyImage is already defined" );
        //Assert.ASSERT( m_glowImage == undefined, "Swap.createRenderables() m_glowImage is already defined" );

        if( state == STATE_RISING )
        {
            m_bubbleImage = layer.attachMovie( "bubbleFull.png", "swapBubble" );
        }
        m_glowImage = layer.attachMovie( "starBurst.png", "swapGlow" );
        m_bodyImage = layer.attachMovie( "swapBody.png", "swapBody" );

        positionRenderables();
    }

    /// Cleanup renderables for this tile.
    public function cleanupRenderables():Void
    {
        if( m_bubbleImage )
        {
            m_bubbleImage.removeMovieClip();
            m_bubbleImage = undefined;
        }
        if( m_bodyImage )
        {
            m_bodyImage.removeMovieClip();
            m_bodyImage = undefined;
        }
        if( m_glowImage )
        {
            m_glowImage.removeMovieClip();
            m_glowImage = undefined;
        }
    }

    /// Position renderables.
    public function positionRenderables():Void
    {
        if( m_bubbleImage != undefined )
        {
            m_bubbleImage.setPosition( x, y );
        }
        if( m_bodyImage != undefined )
        {
            m_bodyImage.setPosition( x, y );
        }
        if( m_glowImage != undefined )
        {
            m_glowImage.setPosition( x + 1, y );
        }
    }

    public function setState( state:Number ):Void
    {
        if( this.state == state )
        {
            return;
        }

        this.state  = state;
        stateTime   = 0.0;

        // Remove bubble image if necessary.
        if( state != STATE_RISING && m_bubbleImage != undefined )
        {
            m_bubbleImage.removeMovieClip();
            m_bubbleImage = undefined;
        }
    }
};
