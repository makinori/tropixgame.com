/**
* WaterWords game engine.
*/
import audio.*;
import container.*;
import drop.*;
import error.*;
import framework.*;
import gui.*;
import math.*;
import particleSystem.*;
import text.*;
import video.*;

/*
IMPROVE:
- Adjust color of score drops.
- Bubble intro animation.
*/

class WaterWords extends GameEngine
{
	// Class members:

	static private var  s_waterWordsInstance:WaterWords; // Singleton

    // enum State
	static public var	STATE_LOADING_WORD_LIST:Number 	    = 0;
	static public var	STATE_NORMAL:Number 		        = 1;
	static public var   STATE_LEVEL_COMPLETE:Number         = 2;
	static public var   STATE_STAGE_COMPLETE:Number         = 3;
	static public var   STATE_LOADING:Number                = 4; // Loading next level, only used if needed
    static public var   STATE_MAX:Number                    = 5;

    static public var   NUM_LEVELS:Number                   = 10;
    static public var   NUM_BACKGROUNDS:Number              = 1;
    static public var   NUM_CLUES:Number                    = 82;
    static public var   TILE_RADIUS:Number                  = 0.7;
    static public var   TILE_IMAGE_SCALE:Number             = 1.05;
    static public var   SWAP_HANDLE_RADIUS:Number           = 18.0; // Screen space.
    static public var   INITIAL_SWAPS:Number                = 1;
    static public var   GRID_WIDTH:Number                   = 8; // Max tiles in row.
    static public var   GRID_HEIGHT:Number                  = 7; // Max tiles in column.
    static public var   MIN_WORD_LENGTH:Number              = 3;
    static public var   MAX_WORD_LENGTH:Number              = 20;
    static public var   NUM_NEIGHBORS:Number                = 6; // Hex grid.
    static public var   NEW_SWAP_MIN_LENGTH:Number          = 5;
    static public var   MAX_SWAPS:Number                    = 3;

	// Instance members:

	public var  layerFish:Layer; // Fish.
	public var  layerTiles:Layer; // Tiles.
	public var  layerConnectors:Layer; // Connecting arrows.
	public var  layerSwaps:Layer; // Swaps.
	public var  layerScore:Layer; // Score drops and found word highlights.
	public var  layerBonusFound:Layer; // "Bonus found" popup.
    public var  screenMouse:Vector2D; // Mouse position in screen space.
    public var  worldMouse:Vector2D; // Mouse position in world space.

    private var	m_state:Number;
    private var m_stateTime:Number;
    private var m_wordList:WordList; // Our word list.
    private var m_letterPool:String; // Pool of weighted random letters.
    private var m_grid:/*Array*/Array; // 2D array of tiles, size GRID_WIDTH x GRID_HEIGHT;
    private var m_selection:/*Vector2D*/Array; // List of grid indices in order selected.
    private var m_mouseOver:Vector2D; // Indices of tile under mouse.  -1, -1 indicates none.
    private var m_dragSelected:Boolean; // Set to true when we "drag-select" a word.
    private var m_level:Level; // Required, assigned in levelInit.  Owned as part of m_level array.
    private var m_lastWordFound:Number;
    private var m_foundWord:/*String*/Array; // List of words found by player so far.
    private var m_wordFindTime:Number; // Time most recent word was found
    private var m_hint:Vector2D; // Grid indices of first letter in goal word
    private var m_bestWord:String; // In this level.
    private var m_bestWordScore:Number; // In this level.
    private var m_longestWord:String; // In this level.
    private var m_bonusFound:Boolean;
    private var m_clue:/*Clue*/Array; // List of available hint/answer pairs from which bonus word will be chosen.  Owned.
    private var m_clueAvailable:/*Number*/Array; // List of available clue indices (those not yet used this game).  Draw from this randomly, without replacement.
    private var m_clueIndex:Number; // Index of clue on current level.
    private var m_swap:/*Swap*/Array; // Owned.
    private var m_activeSwap:Swap; // Optional, points to member of m_swap.
    private var m_swapSource:Tile; // Optional.
    private var m_swapDestination:Tile; // Optional.
    private var m_swapCOR:Vector2D; // World position center of rotation for swapping tiles.
    private var m_swapOffset:Vector2D; // Offset from swap COR to position of swapSource.
    private var m_buttonPlay:TropixButton; // Play button on title page.
    private var m_textLoadingWordList:Text; // "Loading word list..." text on title page.
    private var m_buttonHome:TropixButton; // Home button on game page.
    private var m_buttonHint:TropixButton; // Hint button on game page.
    private var m_buttonSubmit:TropixButton; // Hint button on game page.
    private var m_clueDisplay:Text; // Displays current clue, if not already solved.
    private var m_foundWordDisplay:/*Text*/Array; // Displays words found so far, or empty index such as 1) or 2).
    private var m_stageAndLevelDisplay:Text; // Displays current stage and level index.
    private var m_scoreDisplay:Text; // Displays current score.
    private var m_currentWordDisplay:Text; // Displays current word as we build it.
    private var m_currentWordScoreDisplay:Text; // Displays score for current word when valid.
    private var m_tileConnector:/*Billboard2D*/Array; // Arrows connecting tiles.
    private var m_school:/*School*/Array; // Schools of fish.

    // Constructor is private, as we are a singleton.  Call instance() instead.
	private function WaterWords()
	{
        super( NUM_LEVELS, true );

        screenMouse         = new Vector2D( 0, 0 );
        worldMouse          = new Vector2D( 0, 0 );

		m_state             = STATE_LOADING_WORD_LIST;
        m_stateTime         = 0.0;
        m_wordList          = new WordList();
        m_selection         = new Array();
        m_mouseOver         = new Vector2D( -1, -1 );
        m_dragSelected      = false;
        m_level             = new Level();
        m_lastWordFound     = 0;
        m_foundWord         = new Array();
        m_foundWordDisplay  = new Array();
        m_wordFindTime      = 0.0;
        m_hint              = new Vector2D( -1, -1 );
        m_bestWord          = "";
        m_bestWordScore     = 0;
        m_longestWord       = "";
        m_bonusFound        = false;
        m_clue              = new Array();
        m_clueAvailable     = new Array();
        m_clueIndex         = 0;
        m_swap              = new Array();
        m_swapCOR           = new Vector2D( 0, 0 );
        m_swapOffset        = new Vector2D( 0, 0 );
        m_tileConnector     = new Array();
        m_school            = new Array();
	}

    // Class methods:

    /// Return WaterWords instance.  This will also be registered as the GameEngine instance.
	static public function waterWordsInstance():WaterWords
	{
		if( s_waterWordsInstance == undefined )
		{
			s_waterWordsInstance = new WaterWords();
		}
		return s_waterWordsInstance;
	}

    /// Configure billboard for "letterBubbleRise" animation at given time t.
	static public function animateLetterBubbleRise( t:Number, b:Billboard2D, scale:Number ):Void
	{
        //Assert.ASSERT( b != undefined, "WaterWords.letterBubbleRiseScale() b is undefined" );

        var s:Number    = scale;
        var x:Number    = Math.cos( t * 3.0 ) * (1 - t) * 10;
        var y:Number    = Math.sin( t * 3.0 ) * (1 - t) * 10;

        if( t < .8 )
        {
            s *= XMath.easeOutRatio( t / .8 ) * 1.2;
        }
        else
        {
            s *= 1.0 + ((1.0 - XMath.easeRatio( (t - .8) / .2 )) * .2);
        }
        b.setScale( s, s );
        b.setPosition( x, y );
	}

    // Instance methods:

    // GameEngine interface:

    public function createGameLayersBelowHUD( layer:video.Layer ):Void
    {
        layerFish       = layer.attachLayer( "layerFish" );
		layerTiles      = layer.attachLayer( "layerTiles" );
        layerConnectors = layer.attachLayer( "layerConnectors" );
		layerSwaps      = layer.attachLayer( "layerSwaps" );
    }

    public function createGameLayersAboveHUD( layer:video.Layer ):Void
    {
        layerScore      = layer.attachLayer( "layerScore" );
        layerBonusFound = layer.attachLayer( "layerBonusFound" );
    }

    public function exitGameLayers():Void
    {
        layerFish.exit();
        layerTiles.exit();
        layerConnectors.exit();
        layerSwaps.exit();
        layerScore.exit();
        layerBonusFound.exit();
    }

    public function enterGameLayers():Void
    {
        layerFish.enter();
        layerTiles.enter();
        layerConnectors.enter();
        layerSwaps.enter();
        layerScore.enter();

        // Popup pages do not enter automatically.
    }

	public function engineInit( layer:video.Layer ):Void
	{
        //Assert.ASSERT( layer != undefined, "WaterWords.engineInit() layer undefined" );

        setGameCenter( new Vector2D( 410.0, 235.0 ) );

        super.engineInit( layer );

        // Seed random number generator from clock.
        var date:Date = new Date();

        XMath.seedRand( date.getMilliseconds() );

        // Define particle systems
        Factory.defineBubbleSplatWhite();
        Factory.defineExplodeSparkle();
        Factory.defineLightRays();
        Factory.defineSandDollarFireworks();

        // Begin loading word list.
        m_wordList.loadWords( "words.xml" );
        setState( STATE_LOADING_WORD_LIST );

        // Begin loading sounds (important sounds first)
        Player.loadSounds(
            [
                "pop", "sounds/pop.mp3",
                "waterdrop2", "sounds/waterdrop2.mp3",
                "drip", "sounds/drip.mp3",
                "tap", "sounds/tap.mp3",
                "zip", "sounds/zip.mp3",
                "zipDown", "sounds/zipDown.mp3",

                "wave", "sounds/wave.mp3",
                "chime", "sounds/chime.mp3",
                "kaching", "sounds/kaching.mp3",
                "levelComplete", "sounds/levelComplete.mp3",

                "bird9", "sounds/bird9.mp3",
                "jungleBird", "sounds/jungleBird.mp3",
                "jungleCuckoo", "sounds/jungleCuckoo.mp3",
                "jungleSounds", "sounds/jungleSounds.mp3",
                "jungleSounds5", "sounds/jungleSounds5.mp3"
            ]
        );

        // Define and activate soundscape.
        // Sounds will not actually start playing until fully loaded.
        // This is JungleBeach.
        var soundscape:Soundscape = Soundscape.instance();

        soundscape.createElement( "wave", 6.0, 12.0, 0.2, 0.5, -1.0, 1.0 );
        soundscape.createElement( "jungleCuckoo", 20.0, 120.0, 0.7, 1.0, -1.0, 1.0 );
        soundscape.createElement( "jungleSounds5", 20.0, 200.0, 0.7, 1.0, -1.0, 1.0 );
        soundscape.createElement( "jungleSounds", 30.0, 200.0, 0.7, 1.0, -1.0, 1.0 );
        soundscape.createElement( "jungleBird", 40.0, 600.0, 0.7, 1.0, -1.0, 1.0 );
        soundscape.createElement( "bird9", 20.0, 120.0, 0.7, 1.0, -1.0, 1.0 );
        soundscape.activate();

        // Construct pages
        var b:Billboard2D;
        var popup:Billboard2D;
        var text:Text;
        var button:TropixButton;
        var position:Vector2D = new Vector2D( 0, 0 );

        // Fish
        m_school.push( new School( layerFish, "fishBlue.png", "fishBlueShadow.png", 4, -15.0, 15.0, -15.0, 15.0 ) );
        m_school.push( new School( layerFish, "fishOrange.png", "fishOrangeShadow.png", 4, -15.0, 15.0, -15.0, 15.0 ) );

        // HUD
        {
            // Frame
            b = layerHUD.attachMovie( "frame.png", "frame" );
            b.setPosition( 110, 225 );

            // Naviagtion (home and hint buttons)
            m_buttonHome = TropixButton.create( layerHUD, Localization.string( "Home button" ) );
            m_buttonHome.setPosition( 55, 460 );
            m_buttonHome.setButtonScale( 0.8, 0.8, 0.8, 0.8, 0.77, 0.77 );
            m_buttonHome.setOnRelease( function() { GameEngine.instance().goHome(); } );

            m_buttonHint = TropixButton.create( layerHUD, Localization.string( "Hint button" ) );
            m_buttonHint.setPosition( 165, 460 );
            m_buttonHint.setButtonScale( 0.8, 0.8, 0.8, 0.8, 0.77, 0.77 );
            m_buttonHint.setOnRelease( function() { WaterWords.waterWordsInstance().showHint( true ); } );

            // Clue display
            m_clueDisplay = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 18, 0xffffff, "center" );
            m_clueDisplay.setPosition( 410, 30 );

            // Current word display
            // IMPROVE - Better font
            m_currentWordDisplay = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 24, 0xffffff, "center" );
            m_currentWordDisplay.setPosition( 410, 60 );

            // Current word score display
            // IMPROVE - Better font
            m_currentWordScoreDisplay = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 14, 0xffffff, "center" );
            m_currentWordScoreDisplay.setPosition( 410, 85 );

            // Submit button
            m_buttonSubmit = TropixButton.create( layerHUD, Localization.string( "Submit button" ) );
            m_buttonSubmit.setPosition( 410, 120 );
            m_buttonSubmit.setOnRelease(
                function()
                {
                    if( WaterWords.waterWordsInstance().hasSelection() )
                    {
                        WaterWords.waterWordsInstance().submitSelection();
                    }
                }
            );

            // Stage and level display
            text = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 16, 0xffffff, "left" );
            text.setPosition( 18, 26 ); // Art-dependent
            text.setAlignment( 0, 0.5 );
            // "Level:"
            text.setText( Localization.string( "Level label" ) );

            m_stageAndLevelDisplay = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 16, 0xffffff, "left" );
            m_stageAndLevelDisplay.setPosition( 90, 26 ); // Art-dependent
            m_stageAndLevelDisplay.setAlignment( 0, 0.5 );

            // Score display
            text = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 20, 0xffffff, "left" );
            text.setPosition( 18, 44 ); // Art-dependent
            text.setAlignment( 0, 0.5 );
            // "Score:"
            text.setText( Localization.string( "Score label" ) );

            m_scoreDisplay = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 20, 0xffffff, "left" );
            m_scoreDisplay.setPosition( 90, 43 ); // Art-dependent
            m_scoreDisplay.setAlignment( 0, 0.5 );

            // Swap label
            text = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 18, 0xffffff, "right" );
            text.setText( Localization.string( "Swap label" ) );
            text.setAlignment( 1.0, 0.5 );
            text.setPosition( 385, 410 );
        }

        // "Bonus found" popup
        {
            // Background rectangle (black)
            b = layerBonusFound.createEmptyMovie( "rectangle" );
            b.movieClip().moveTo( 105, 139 );
            b.movieClip().beginFill( 0x3171AE, 100 );
            b.movieClip().lineTo( 540, 139 );
            b.movieClip().lineTo( 540, 335 );
            b.movieClip().lineTo( 105, 335 );
            b.movieClip().endFill();

            b = layerBonusFound.attachMovie( "popup.png", "popup" );
            b.setPosition( 320, 240 );

            b = layerBonusFound.attachMovie( "scrollSmall.png", "scrollSmall" );
            b.setPosition( 320, 130 );

            b = layerBonusFound.attachMovie( "textBonusFound.png", "bonusFound" );
            b.setPosition( 330, 130 );

            var hintText:Text = new Text( layerBonusFound.createTextField(), "MinyaBold.ttf", 18, 0xffffff, "center" );

            hintText.setPosition( 320, 200 );

            var answerText:Text = new Text( layerBonusFound.createTextField(), "MinyaBold.ttf", 18, 0xffffff, "center" );

            answerText.setPosition( 320, 230 );

            text = new Text( layerBonusFound.createTextField(), "MinyaBold.ttf", 24, 0xffffff, "center" );
            text.setText( "+" + XMath.commaString( "1000" ) );
            text.setPosition( 320, 260 );

            button = TropixButton.create( layerBonusFound, Localization.string( "OK button" ) );
            button.setPosition( 320, 300 );
            button.setOnRelease( function() { WaterWords.waterWordsInstance().hideBonusFound(); } );

            layerBonusFound.setOnEnter( 
                function()
                {
                    // Update text
                    hintText.setText( WaterWords.waterWordsInstance().clue().hint + "..." );
                    answerText.setText( WaterWords.waterWordsInstance().clue().answer );
                }
            );
            layerBonusFound.exit();
        }

        // Stage intro
        PageFactory.buildStageIntro( layerStageIntro,
            function() { return GameEngine.instance().stageIndex(); } );

        // Level complete
        PageFactory.buildLevelComplete( layerLevelComplete,
            function() { GameEngine.instance().nextLevel(); },
            function() { GameEngine.instance().download(); } );

        // Stage complete
        PageFactory.buildStageComplete( layerStageComplete,
            function() { GameEngine.instance().nextStage(); },
            function() { GameEngine.instance().download(); } );

        // Load letter pool
        m_letterPool        = Localization.string( "Letter pool" );

        // Create tile grid
        var i:Number;
        var j:Number;

        m_grid = new Array();
        for( i = 0; i < GRID_WIDTH; i++ )
        {
            m_grid[i] = new Array();
            for( j = 0; j < GRID_HEIGHT; j++ )
            {
                m_grid[i][j] = new Tile();
            }
        }

        // Get clues from localization
        for( i = 0; i < NUM_CLUES; i++ )
        {
            m_clue.push( new Clue( Localization.string( "hint " + (i + 1) ),
                                   Localization.string( "answer " + (i + 1) ) ) );
        }
    }

    public function buildTitlePage( layer:video.Layer ):Void
    {
        var b:Billboard2D;
        var button:TropixButton;
        var text:Text;

        // Title
        b = layer.attachMovie( "title.jpg", "background" );
        b.setCentered( false );

        text = new Text( layer.createTextField(), "MinyaBold.ttf", 24, 0xffffff, "left" );
        text.setAlignment( 0.0, 0.5 );
        text.setPosition( 30, 170 );
        text.setText( Localization.string( "Help line 1" ) );

        text = new Text( layer.createTextField(), "MinyaBold.ttf", 24, 0xffffff, "left" );
        text.setAlignment( 0.0, 0.5 );
        text.setPosition( 230, 330 );
        text.setText( Localization.string( "Help line 2" ) );

        m_textLoadingWordList = new Text( layer.createTextField(), "MinyaBold.ttf", 18, 0x81B5D8, "left" );
        m_textLoadingWordList.setAlignment( 0.0, 0.5 );
        m_textLoadingWordList.setText( Localization.string( "Loading word list label" ) );
        m_textLoadingWordList.setPosition( 380, 435 );

        m_buttonPlay = TropixButton.createRound( layer, "textPlay.png" );
        m_buttonPlay.setPosition( 560, 435 );
        m_buttonPlay.setOnRelease(
            function()
            {
                Application.instance().setState( Application.STATE_GAME );
            }
        )
        m_buttonPlay.setVisible( false );

        button = TropixButton.create( layer, Localization.string( "Options button" ) );
        button.setPosition( 100, 450 );
        button.setOnRelease( function() { Application.instance().showOptions(); } );

        // "Connect letters" elements for onUpdate function:
        var i:Number;
        var bubble:/*Billboard2D*/Array = new Array();
        var bubblePosition:Array        =
        [
            [424, 205],
            [444, 171],
            [486, 171],
            [508, 205],
            [550, 205]
        ];
        var word:String                 = Localization.string( "5-letter help word" );
        var letter:/*Text*/Array        = new Array();
        var arrow:/*Billboard2D*/Array  = new Array();
        var arrowPosition:Array         =
        [
            [435, 189],
            [466, 172],
            [498, 188],
            [528, 206]
        ];
        var connectAnimationTime:Number = 0.0;
        var connectAnimationStep:Number = 0;

        for( i = 0; i < 5; i++ )
        {
            b = layer.attachMovie( "bubbleFull.png", "bubble" + i );
            b.setScale( 1.4, 1.4 );
            b.setPosition( bubblePosition[i][0], bubblePosition[i][1] );
            bubble.push( b );

            text = new Text( layer.createTextField(), "MinyaBold.ttf", 24, 0x000000, "center" );
            text.setText( word.charAt( i ) );
            text.setPosition( bubblePosition[i][0], bubblePosition[i][1] );
        }
        for( i = 0; i < 4; i++ )
        {
            if( i == 3 )
            {
                b = layer.attachMovie( "tileConnector1.png", "arrow0" );
            }
            else
            {
                b = layer.attachMovie( "tileConnector" + i + ".png", "arrow0" );
            }
            b.setPosition( arrowPosition[i][0], arrowPosition[i][1] );
            b.setScale( 0.9, 0.9 );
            b.setVisible( false );
            arrow.push( b );
        }

        layer.setOnUpdate(
            function( deltaTime:Number ):Void
            {
                WaterWords.waterWordsInstance().checkWordListLoad();

                // Animate connecting letter
                connectAnimationTime += deltaTime;
                if( (connectAnimationStep < 5 && connectAnimationTime > 0.5) ||
                    (connectAnimationTime > 1.5) )
                {
                    connectAnimationTime = 0.0;
                    connectAnimationStep++;
                    switch( connectAnimationStep )
                    {
                    case 0:
                        break;
                    case 1:
                        layer.reattachMovie( bubble[0], "bubbleFullSelected.png" );
                        break;
                    case 2:
                        layer.reattachMovie( bubble[1], "bubbleFullSelected.png" );
                        arrow[0].setVisible( true );
                        break;
                    case 3:
                        layer.reattachMovie( bubble[2], "bubbleFullSelected.png" );
                        arrow[1].setVisible( true );
                        break;
                    case 4:
                        layer.reattachMovie( bubble[3], "bubbleFullSelected.png" );
                        arrow[2].setVisible( true );
                        break;
                    case 5:
                        layer.reattachMovie( bubble[4], "bubbleFullSelected.png" );
                        arrow[3].setVisible( true );
                        break;
                    default:
                        for( i = 0; i < 5; i++ )
                        {
                            layer.reattachMovie( bubble[i], "bubbleFull.png" );
                        }
                        for( i = 0; i < 4; i++ )
                        {
                            arrow[i].setVisible( false );
                        }
                        connectAnimationStep = 0;
                        break;
                    }
                }
            }
        );
    }

    public function checkWordListLoad():Void
    {
        if( m_state == STATE_LOADING_WORD_LIST )
        {
            if( m_wordList.isLoaded() )
            {
                setState( STATE_NORMAL );
                m_textLoadingWordList.setVisible( false );
                m_buttonPlay.setVisible( true );
            }
            else
            {
                m_textLoadingWordList.setText( Localization.string( "Loading word list label" ) +
                    Math.floor( m_wordList.percentLoaded() * 100 ) + "%" );
            }
        }
    }

	public function levelInit():Void
	{
        setGameTime( 0.0 );
        setScore( 0 );

        // Cleanup existing level
        unapplyLevel();

        // Create initial swaps
        var i:Number;
        var j:Number;

        for( i = 0; i < INITIAL_SWAPS; i++ )
        {
            addSwap();
        }

        // Construct new level
        m_level.construct( levelIndex() );

        // Initialize grid with random letters, activating only those tiles that are
        // included in this level.
        for( i = 0; i < GRID_WIDTH; i++ )
        {
            for( j = 0; j < GRID_HEIGHT; j++ )
            {
                var t:Tile      = m_grid[i][j];

                // Cleanup
                t.cleanupRenderables();
                t.reset();

                // If tile is inactive in this level, we're done.
                if( !m_level.gridShape.active[i][j] )
                {
                    continue;
                }

                // Activate tile.
                var v:Vector2D  = worldPosition( i, j );

                t.setState( Tile.STATE_ACTIVE );
                t.setLetter( randomLetter() );
                t.x = v.x;
                t.y = v.y;
            }
        }

        // Choose clue
        nextClue();

        // Apply level
        applyLevel();

        // Create tile renderables
        for( i = 0; i < GRID_WIDTH; i++ )
        {
            for( j = 0; j < GRID_HEIGHT; j++ )
            {
                var t:Tile = m_grid[i][j];

                if( t.state == Tile.STATE_ACTIVE )
                {
                    t.createRenderables( layerTiles );
                }
            }
        }

        // Update HUD
        m_clueDisplay.setText( clue().hint );
        m_clueDisplay.setVisible( true );
        m_buttonHint.setDim( false );
        m_buttonSubmit.setDim( true );
        m_stageAndLevelDisplay.setText( (stageIndex() + 1) + "-" + (levelIndex() + 1) );
        m_currentWordDisplay.setText( "" );
        m_currentWordScoreDisplay.setText( "" );
        updateFoundWordDisplay();

        setState( STATE_NORMAL );
    }

    public function levelRestart():Void
    {
        levelInit();
    }

    public function waitForLoad():Void
    {
        super.waitForLoad();

        setState( STATE_LOADING );
    }

	public function update( deltaTime:Number ):Void
	{
        m_stateTime += deltaTime;

        setGameTime( gameTime() + deltaTime );

        // GameEngine states
        if( m_state == STATE_LEVEL_COMPLETE )
        {
            // Show level complete page after allowing "level complete!" text to float away
            if( m_stateTime > 2.5 && !layerLevelComplete.isVisible() )
            {
                showLevelComplete();
            }
        }
        else if( m_state == STATE_STAGE_COMPLETE )
        {
            // Show stage complete page after allowing "level complete!" text to float away
            if( m_stateTime > 2.5 && !layerStageComplete.isVisible() )
            {
                showStageComplete();
            }
        }
        else if( m_state == STATE_LOADING )
        {
            // Transition to next level if done loading
            if( m_backgroundAttached.isVisible() || m_backgroundLoaded.isLoaded() )
            {
                nextLevel();
            }
        }

        // WaterWords states
        if( m_state == STATE_NORMAL )
        {
            // Update swaps
            updateSwaps( deltaTime );

            // Update grid.
            // NOTE - We could optimize this traversal.
            var i:Number;
            var j:Number;
            var t:Tile;

            for( i = 0; i < GRID_WIDTH; i++ )
            {
                for( j = 0; j < GRID_HEIGHT; j++ )
                {
                    t = m_grid[i][j];
                    if( t.state != Tile.STATE_INACTIVE )
                    {
                        t.update( deltaTime );
                    }
                }
            }

            // Position swapping tiles
            if( hasSwapSource() && hasSwapDestination() )
            {
                updateSwappingTiles( deltaTime );
            }
        }

        // Update fish
        var length:Number = m_school.length;
        var i:Number;

        for( i = 0; i < length; i++ )
        {
            m_school[i].update( deltaTime );
        }

        // Update layers
        layerScore.update( deltaTime );

        updateLayers( deltaTime );

        super.update( deltaTime ); // Call parent class method
    }

    public function handleEvent( event:Event ):Boolean
    {
        //Assert.ASSERT( event != undefined, "WaterWords.handleEvent() event is undefined" );

        super.handleEvent( event );

        // Do not handle events while modal popups are visible.
        if( layerDebug.isVisible() )
        {
            return false;
        }
        if( layerStageIntro.isVisible() && layerStageIntro.visibleTime() < 1.5 )
        {
            return false;
        }
        if( layerBonusFound.isVisible() )
        {
            return false;
        }

        // We only need to handle events during normal play
        if( m_state != STATE_NORMAL )
        {
            return false;
        }

        // Submit button consumes other events
        if( m_buttonSubmit.intersects( event.position.x, event.position.y ) ||
            m_buttonSubmit.isPressed() )
        {
            return false;
        }

        screenMouse.copy( event.position );
        worldMouse = camera().toWorld( screenMouse );

        switch( event.type )
        {
        case Event.TYPE_MOUSE_MOVE:
            {
                var coord:Vector2D = new Vector2D();

                // Find tile under mouse (may be none)
                findMouseOver();

                if( !isSwapping() )
                {
                    // Add to or remove from selection via drag
                    if( !event.mousePressed || !hasSelection() )
                    {
                        break;
                    }
                    if( hasMouseOver() )
                    {
                        var lastSelection:Vector2D = m_selection[m_selection.length - 1];

                        if( !lastSelection.equals( m_mouseOver ) )
                        {
                            if( selectTile( m_mouseOver.x, m_mouseOver.y ) )
                            {
                                m_dragSelected = true;
                            }
                        }
                    }
                    return true;
                }
            }
            break;
        case Event.TYPE_MOUSE_PRESS:
        case Event.TYPE_MOUSE_DOUBLE_CLICK:
            // Check for click on swap inventory
            if( checkClickedSwapInventory() )
            {
                return true;
            }

            // Find tile under mouse (may be none)
            findMouseOver();

            // Select a tile to swap or append to word, or submit selection
            if( hasMouseOver() )
            {
                if( isSwapping() && !hasSwapDestination() )
                {
                    selectSwapTile( m_mouseOver.x, m_mouseOver.y );
                }
                else
                {
                    selectTile( m_mouseOver.x, m_mouseOver.y );
                    m_dragSelected = false;
                }
                return true;
            }
            else
            {
                // Send unhandled mouse presses to fish schools
                var length:Number = m_school.length;
                var i:Number;

                for( i = 0; i < length; i++ )
                {
                    m_school[i].attractFish( worldMouse.x, worldMouse.y );
                }
            }

            if( isSwapping() )
            {
                cancelSwap();
            }

            resetSelection();
            m_dragSelected = false;
            break;
        case Event.TYPE_MOUSE_RELEASE:
            if( isSwapping() && hasSwapSource() && !hasSwapDestination() )
            {
                if( hasMouseOver() && mouseOver() != swapSource() )
                {
                    selectSwapTile( m_mouseOver.x, m_mouseOver.y );
                }
            }
            else
            {
                // Submit selection if we "drag-selected"
                if( m_dragSelected )
                {
                    submitSelection();
                }
                m_dragSelected = false;
            }
            break;
        }

        return false;
	}

    public function backgroundIndex( levelIndex:Number ):Number
    {
        return levelIndex % NUM_BACKGROUNDS;
    }

    public function setScore( score:Number ):Void
    {
        super.setScore( score );
        m_scoreDisplay.setText( XMath.commaString( "" + score ) );
    }

    // WaterWords interface:

    public function setState( state:Number ):Void
    {
        //Assert.ASSERT( state < STATE_MAX, "WaterWords.setState() invalid state: " + state );

        if( m_state == state )
            return;

        m_state     = state;
        m_stateTime = 0.0;

        switch( m_state )
        {
        case STATE_NORMAL:
            layerBackground.enter();
            layerHUD.enter();
            enterGameLayers();
            layerEffects.enter();
            layerEffects2.enter();

            layerLevelComplete.exit();
            layerStageComplete.exit();
            layerLoading.exit();
            break;
        case STATE_LEVEL_COMPLETE:
            levelCompleteEffects();
            break;
        case STATE_STAGE_COMPLETE:
            stageCompleteEffects();
            break;
        }
    }

    public function state():Number              { return m_state; }
    public function stateTime():Number          { return m_stateTime; }

    /// Apply current level description.
    public function applyLevel():Void
    {
        // Apply level.
        m_level.apply( this );

        // Adjust camera to center playing area
        centerCamera();
    }

    /// Unapply level.
    public function unapplyLevel():Void
    {
        resetMouseOver();
        m_dragSelected      = false;
        resetSelection();
        m_activeSwap        = undefined;
        m_swapSource        = undefined;
        m_swapDestination   = undefined;
        m_bestWord          = "";
        m_bestWordScore     = 0;
        m_longestWord       = "";
        m_bonusFound        = false;
        m_foundWord.length  = 0;
        updateFoundWordDisplay();

        var length:Number = m_swap.length;
        var i:Number;

        for( i = 0; i < length; i++ )
        {
            m_swap[i].cleanupRenderables();
        }
        m_swap.length       = 0;
    }

    /// Get reference to tile at given coordinates.  Asserts success.
    public function tile( gridI:Number, gridJ:Number ):Tile
    {
        //Assert.ASSERT( gridI < GRID_WIDTH && gridJ < GRID_HEIGHT, "WaterWords.tile() gridI,J invalid" );
        //Assert.ASSERT( m_grid[gridI][gridJ] != undefined, "WaterWords.tile() requested tile is undefined" );
        return m_grid[gridI][gridJ];
    }

    /// Choose new clue index randomly without replacement.
    public function nextClue():Void
    {
        //Assert.ASSERT( m_clue.length > 0, "WaterWords.nextClue() no clues exist" );

        // Rebuild index pool if drained.
        if( m_clueAvailable.length == 0 )
        {
            var i:Number;

            for( i = 0; i < NUM_CLUES; i++ )
            {
                m_clueAvailable.push( i );
            }
        }

        // Choose index, remove it from pool.
        var arrayIndex:Number = XMath.randomInt( 0, m_clueAvailable.length - 1 );

        m_clueIndex = m_clueAvailable[arrayIndex];

        ArrayUtils.removeOrdered( m_clueAvailable, arrayIndex );
    }

    /// Get reference to current clue.
    public function clue():Clue
    {
        //Assert.ASSERT( m_clueIndex < m_clue.length, "WaterWords.clue() clue index invalid: " + m_clueIndex );
        //Assert.ASSERT( m_clue[m_clueIndex] != undefined, "WaterWords.clue() m_clue[" + m_clueIndex + "] is undefined" );
        return m_clue[m_clueIndex];
    }

    /// Return a random letter drawn from our letter pool.
    public function randomLetter():Number
    {
        //Assert.ASSERT( m_letterPool.length > 0, "WaterWords.randomLetter() letter pool is empty" );
        return m_letterPool.charCodeAt( XMath.randomInt( 0, m_letterPool.length - 1 ) );
    }

    /// Returns true if requested neighbor is part of grid (state not considered).
    /// Fills in coord with indices of requested neighbor if valid.
    public function neighborIndices( gridI:Number, gridJ:Number,
                                     neighbor:Number, coord:Vector2D ):Boolean
    {
        //Assert.ASSERT( gridI < GRID_WIDTH && gridJ < GRID_HEIGHT, "WaterWords.neighborIndices() gridI,J invalid" );
        //Assert.ASSERT( neighbor < NUM_NEIGHBORS, "WaterWords.neighborIndices() neighbor invalid" );

        // Find neighbor coordinates
        var i:Number    = -1;
        var j:Number    = -1;

        if( gridJ % 2 == 0 ) // Even row
        {
            var neighborCoord:/*Array*/Array =
            [
                [0,  1], [1,  0], [0, -1], [-1, -1], [-1, 0], [-1, 1]
            ];
            i = gridI + neighborCoord[neighbor][0];
            j = gridJ + neighborCoord[neighbor][1];
        }
        else // Odd row
        {
            var neighborCoord:/*Array*/Array =
            [
                [1,  1], [1,  0], [1, -1], [0, -1], [-1, 0], [0, 1]
            ];
            i = gridI + neighborCoord[neighbor][0];
            j = gridJ + neighborCoord[neighbor][1];
        }

        if( i >= 0 && i < GRID_WIDTH && j >= 0 && j < GRID_HEIGHT )
        {
            coord.x = i;
            coord.y = j;
            return true;
        }

        return false;
    }

    /// Get neighbor relationship (0 through 5), based on given coordinates and offset.
    /// This is the inverse operation of neighborIndices.
    /// Asserts success.
    public function whichNeighbor( gridI:Number, gridJ:Number,
                                   neighborI:Number, neighborJ:Number ):Number
    {
        var n:Number;

        if( gridJ % 2 == 0 ) // Even row
        {
            var neighborCoord:/*Array*/Array =
            [
                [0,  1], [1,  0], [0, -1], [-1, -1], [-1, 0], [-1, 1]
            ];
            for( n = 0; n < NUM_NEIGHBORS; n++ )
            {
                if( neighborI == gridI + neighborCoord[n][0] &&
                    neighborJ == gridJ + neighborCoord[n][1] )
                {
                    return n;
                }
            }
            //Assert.ASSERT( false, "WaterWords.whichNeighbor() neighbor not found" );
            return 0;
        }
        else // Odd row
        {
            var neighborCoord:/*Array*/Array =
            [
                [1,  1], [1,  0], [1, -1], [0, -1], [-1, 0], [0, 1]
            ];
            for( n = 0; n < NUM_NEIGHBORS; n++ )
            {
                if( neighborI == gridI + neighborCoord[n][0] &&
                    neighborJ == gridJ + neighborCoord[n][1] )
                {
                    return n;
                }
            }
            //Assert.ASSERT( false, "WaterWords.whichNeighbor() neighbor not found" );
            return 0;
        }
    }

    /// Set hint coordinates.
    public function setHint( hintI:Number, hintJ:Number ):Void
    {
        m_hint.x = hintI;
        m_hint.y = hintJ;
    }

    /// Help the user out by showing a hint.
    public function showHint( show:Boolean ):Void
    {
        // If user asks to show hint, reset selection 
        // to ensure hint tile is plainly visible.
        if( show )
        {
            resetSelection();
        }

        // Show drops highlighting hint bubble
        if( show )
        {
            var layer:Layer                 = layerEffects;
            var screenPos:Vector2D          = camera().toScreen( worldPosition( m_hint.x, m_hint.y ) );
            var drop:Drop                   = new Drop( layer  );
            var b:Billboard2D               = layer.attachMovie( "hintHighlight.png", "hintHighlight" );

            drop.setBillboard( b );
            drop.setPosition( screenPos.x, screenPos.y );
            drop.scaleFunc  =
                function( d:Drop, deltaTime:Number, scale:Vector2D )
                {
                    scale.x = 1.0 + (drop.age / drop.lifespan);
                    scale.y = scale.x;
                }
            drop.updateFunc =
                function( d:Drop, deltaTime:Number )
                {
                    d.billboard.movieClip()._alpha = 100 * (1 - (drop.age / drop.lifespan));
                }
            drop.lifespan   = 1.1;
            layer.ownRenderable( drop );

            drop    = new Drop( layer  );
            b       = layer.attachMovie( "hintHighlight.png", "hintHighlight" );
            drop.setBillboard( b );
            drop.setPosition( screenPos.x, screenPos.y );
            drop.lifespan   = .5;
            drop.updateFunc =
                function( d:Drop, deltaTime:Number )
                {
                    d.billboard.movieClip()._alpha = 100 * (1 - (drop.age / drop.lifespan));
                }
            layer.ownRenderable( drop );

            Player.playSound( "drip", 1, 0 );
        }
    }

    /// Get word so far.
    public function currentWord():String
    {
        var word:String     = "";
        var length:Number   = m_selection.length;
        var i:Number;

        for( i = 0; i < length; i++ )
        {
            word += String.fromCharCode( selectedTile( i ).letter() );
        }

        return word;
    }

    /// Get points for word so far.
    public function currentWordScore():Number
    {
        var points:Number = m_selection.length * 5;

        return points * points; // Points are exponential with word length
    }

    /// Check validity of given string.
    public function isAWord( word:String ):Boolean
    {
        //Assert.ASSERT( word != undefined, "WaterWords.isAWord() word is undefined" );
        //Assert.ASSERT( m_wordList != undefined, "WaterWords.isAWord() m_wordList is undefined" );
        //Assert.ASSERT( m_wordList.isLoaded(), "WaterWords.isAWord() m_wordList is not yet loaded" );
        return m_wordList.wordExists( word );
    }

    /// Return true if we have selected tile(s).
    public function hasSelection():Boolean
    {
        return m_selection.length > 0;
    }

    /// Return true if we have a mouseOver tile.
    public function hasMouseOver():Boolean
    {
        return (m_mouseOver.x >= 0 && m_mouseOver.y >= 0);
    }

    /// Get mouseOver tile.  Asserts success.
    public function mouseOver():Tile
    {
        //Assert.ASSERT( hasMouseOver(), "WaterWords.mouseOver() does not have a mouseOver" );
        return m_grid[m_mouseOver.x][m_mouseOver.y];
    }

    /// Reset mouse over.
    public function resetMouseOver():Void
    {
        m_mouseOver.x = -1;
        m_mouseOver.y = -1;
    }

    /// Submit selection for word test.
    public function submitSelection():Void
    {
        //Assert.ASSERT( hasSelection(), "WaterWords.submitSelection() does not have a selection" );

        // Check if selection is a word
        var word:String = currentWord();

        if( isAWord( word ) )
        {
            // Record word as found
            var alreadyFound:Boolean    = false;
            var foundWordIndex:Number   = 0;
            var numFoundWords:Number    = m_foundWord.length;
            var wordScore:Number        = currentWordScore();

            while( foundWordIndex < numFoundWords )
            {
                if( m_foundWord[foundWordIndex] == word )
                {
                    alreadyFound = true;
                    break;
                }
                foundWordIndex++;
            }
            if( alreadyFound ) // Already found word recreated
            {
                Player.playSound( "tap", 1.0, 0.0 );
            }
            else // New word created
            {
                newWordCreated( word );
            }

            // Create a drop to highlight word in found word list, whether new or not.
            {
                var layer:Layer     = layerScore; // Keep it below "bonus found" popup
                var pos:Vector2D    = foundWordListPosition( foundWordIndex );
                var text:Text       = new Text( layer.createTextField(), "MinyaBold.ttf", 18, 0x01F9FF, "left" );
                var drop:Drop       = new Drop( layer  );

                text.setPosition( pos.x, pos.y );
                text.setText( "" + (foundWordIndex + 1) + ") " + word );
                text.setAlignment( 0.0, 0.5 );
                drop.setText( text );
                drop.position.copy( pos );
                drop.fadeOut        = true;
                drop.lifespan       = 2;
                layer.ownRenderable( drop );
            }

            // Record word find data for display in list
            m_lastWordFound = foundWordIndex;
            m_wordFindTime  = gameTime();

            // Level-complete criteria: find goal number of words.
            // If word is clue answer, show "clue found page", otherwise check for level complete.
            if( word != clue().answer )
            {
                if( isLevelComplete() )
                {
                    if( levelIndex() + 1 < NUM_LEVELS )
                    {
                        setState( STATE_LEVEL_COMPLETE );
                    }
                    else
                    {
                        setState( STATE_STAGE_COMPLETE );
                    }
                }
            }
        }
        else
        {
            // Alert player re invalid word
            Player.playSound( "tap", 1.0, 0.0 );
        }

        // Reset selection
        resetSelection();
    }

    /// Callback when a new word is created.
    private function newWordCreated( word:String ):Void
    {
        //Assert.ASSERT( word != undefined, "WaterWords.newWordCreated() word is undefined" );

        var wordScore:Number = currentWordScore();

        m_foundWord.push( word );
        updateFoundWordDisplay();

        if( word.length > m_longestWord.length )
        {
            m_longestWord = word;
        }
        if( wordScore > m_bestWordScore )
        {
            m_bestWord      = word;
            m_bestWordScore = wordScore;
        }

        // Add points.
        setScore( score() + wordScore );

        // Create score drop next to new entry in found word list.
        {
            var index:Number    = m_foundWord.length - 1;
            var layer:Layer     = layerScore; // Keep it below "bonus found" popup
            var pos:Vector2D    = foundWordListPosition( index );
            var text:Text       = new Text( layer.createTextField(), "MinyaBold.ttf", 18, 0xffffff, "center" );
            var drop:Drop       = new Drop( layer  );

            pos.x += m_foundWordDisplay[index].width() + 40.0;
            text.setPosition( pos.x, pos.y );
            text.setText( "+" + XMath.commaString( "" + wordScore ) );
            drop.setText( text );
            drop.position.copy( pos );
            drop.scaleFunc      = Drop.scaleOscillateInQuick;
            drop.translateFunc  = Drop.translateLift;
            drop.fadeOut        = true;
            drop.lifespan       = 2;
            layer.ownRenderable( drop );
        }

        // Show "bonus found" page
        if( !m_bonusFound && word == clue().answer )
        {
            setScore( score() + 1000 );
            Player.playSound( "chime", 1.0, 0.0 );
            layerBonusFound.enter();
            m_bonusFound = true;
            m_buttonHint.setDim( true );
            m_clueDisplay.setVisible( false );
        }
        else
        {
            Player.playSound( "pop", 1.0, 0.0 );
        }

        // If word is long enough, award with another swap
        if( word.length >= NEW_SWAP_MIN_LENGTH && m_swap.length < MAX_SWAPS )
        {
            addSwap();
        }
    }

    /// Hide "bonus found" popup and check for level complete.
    public function hideBonusFound():Void
    {
        layerBonusFound.exit();
        if( isLevelComplete() )
        {
            if( levelIndex() + 1 < NUM_LEVELS )
            {
                setState( STATE_LEVEL_COMPLETE );
            }
            else
            {
                setState( STATE_STAGE_COMPLETE );
            }
        }
    }

    /// Update found word display from our list.
    private function updateFoundWordDisplay():Void
    {
        //Assert.ASSERT( m_foundWord != undefined, "WaterWords.updateFoundWordDisplay() m_foundWord is undefined" );
        //Assert.ASSERT( m_foundWordDisplay != undefined, "WaterWords.updateFoundWordDisplay() m_foundWordDisplay is undefined" );

        var displayLength:Number    = m_foundWordDisplay.length;
        var numFoundWords:Number    = m_foundWord.length;
        var text:String             = "";
        var i:Number;

        // Clear existing list
        for( i = 0; i < displayLength; i++ )
        {
            m_foundWordDisplay[i].removeTextField();
        }
        m_foundWordDisplay.length = 0;

        // Create new list
        for( i = 0; i < m_level.goalWordCount; i++ )
        {
            var v:Vector2D = foundWordListPosition( i );

            text = "" + (i + 1) + ") ";
            if( i < numFoundWords )
            {
                text += m_foundWord[i];
            }

            m_foundWordDisplay[i] = new Text( layerHUD.createTextField(), "MinyaBold.ttf", 18, 0xffffff, "left" );
            m_foundWordDisplay[i].setAlignment( 0.0, 0.5 );
            m_foundWordDisplay[i].setText( text );
            m_foundWordDisplay[i].setPosition( v.x, v.y );
        }
    }

    /// Return true if level is complete.
    public function isLevelComplete():Boolean
    {
        return (m_foundWord.length >= m_level.goalWordCount);
    }

    /// Get average word length so far.
    public function averageFoundWordLength():Number
    {
        var numFoundWords:Number = m_foundWord.length;

        if( numFoundWords == 0 )
            return 0.0;

        var result:Number = 0.0;
        var i:Number;

        for( i = 0; i < numFoundWords; i++ )
        {
            result += m_foundWord[i].length;
        }

        result /= numFoundWords;
        return result;
    }

    /// Return true if we have an active swap.
    public function isSwapping():Boolean
    {
        return m_activeSwap != undefined;
    }

    /// Get active swap.  Asserts success.
    public function activeSwap():Swap
    {
        //Assert.ASSERT( m_activeSwap != undefined, "WaterWords.activeSwap() m_activeSwap is undefined" );
        return m_activeSwap;
    }

    /// Begin/cancel/end swap mode.
    public function beginSwap( index:Number ):Void
    {
        if( isSwapping() )
        {
            cancelSwap();
            return;
        }

        m_activeSwap = m_swap[index];
        m_activeSwap.setState( Swap.STATE_CURSOR );

        resetSelection();
        m_swapSource        = undefined;
        m_swapDestination   = undefined;
    }
    public function cancelSwap():Void
    {
        Player.playSound( "zipDown", 1.0, 0.0 );

        m_activeSwap.x = screenMouse.x;
        m_activeSwap.y = screenMouse.y;
        m_activeSwap.setState( Swap.STATE_DOCKED );

        if( m_swapSource != undefined )
        {
            m_swapSource.setSwapping( false, layerTiles );
        }
        if( m_swapDestination != undefined )
        {
            m_swapDestination.setSwapping( false, layerTiles );
        }

        m_activeSwap        = undefined;
        m_swapSource        = undefined;
        m_swapDestination   = undefined;
    }
    public function endSwap():Void
    {
        m_swapSource        = undefined;
        m_swapDestination   = undefined;

        // Remove active swap from swap inventory.
        var length:Number = m_swap.length;
        var i:Number;

        for( i = 0; i < length; i++ )
        {
            if( m_swap[i] == m_activeSwap )
            {
                ArrayUtils.removeOrdered( m_swap, i );
                m_activeSwap.cleanupRenderables();
                m_activeSwap = undefined;
                return;
            }
        }
        //Assert.ASSERT( false, "WaterWords.endSwap() failed to find active swap in swap inventory" );
    }

    /// Access swap tiles.
    public function hasSwapSource():Boolean
    {
        return m_swapSource != undefined;
    }
    public function swapSource():Tile
    {
        //Assert.ASSERT( m_swapSource != undefined, "WaterWords.swapSource() m_swapSource is undefined" );
        return m_swapSource;
    }
    public function hasSwapDestination():Boolean
    {
        return m_swapDestination != undefined;
    }
    public function swapDestination():Tile
    {
        //Assert.ASSERT( m_swapDestination != undefined, "WaterWords.swapDestination() m_swapDestination is undefined" );
        return m_swapDestination;
    }

    /// Append a new swap to the inventory.
    public function addSwap():Void
    {
        var s:Swap      = new Swap();
        var v:Vector2D  = swapInventoryPosition( m_swap.length );

        s.x     = v.x;
        s.y     = v.y;
        s.destX = v.x;
        s.destY = v.y;
        s.createRenderables( layerSwaps );
        m_swap.push( s );
    }

    /// Get world position of tile at given indices.
    /// Indices need not be valid.
    public function worldPosition( gridI:Number, gridJ:Number ):Vector2D
    {
        // NOTE - It's ok if indices are out of bounds.
        var x:Number = gridI;

        if( gridJ % 2 == 1 ) // Odd rows are offset horizontally
        {
            x += 0.5;
        }

        // All rows are offset vertically (because of packing)
        var VERTICAL_PACK:Number    = 0.866;
        var y:Number                = gridJ * VERTICAL_PACK;

        return new Vector2D( x * TILE_RADIUS * 2.0, y * TILE_RADIUS * 2.0 );
    }

    /// Center camera.
    public function centerCamera():Void
    {
        // Find min and max position of non-empty level slots
        var minI:Number = GRID_WIDTH - 1;
        var maxI:Number = 0;
        var minJ:Number = GRID_HEIGHT - 1;
        var maxJ:Number = 0;
        var i:Number;
        var j:Number;

        for( i = 0; i < GRID_WIDTH; i++ )
        {
            for( j = 0; j < GRID_HEIGHT; j++ )
            {
                if( m_grid[i][j].state == Tile.STATE_ACTIVE )
                {
                    minI = Math.min( minI, i );
                    maxI = Math.max( maxI, i );
                    minJ = Math.min( minJ, j );
                    maxJ = Math.max( maxJ, j );
                }
            }
        }

        // Handle empty level (shouldn't happen)
        if( maxI < minI )
        {
            maxI = minI = (GRID_WIDTH / 2);
        }
        if( maxJ < minJ )
        {
            maxJ = minJ = (GRID_HEIGHT / 2);
        }

        var levelCenter:Vector2D    = new Vector2D( (minI + maxI) * 0.5, (minJ + maxJ) * 0.5 );
        var tileRadius:Number       = camera().widthToScreen( TILE_RADIUS );

        levelCenter.scale( tileRadius * 2.0 );

        camera().setScreenPosition( Vector2D.difference( gameCenter(), levelCenter ) );
    }

    /// Find tile under mouse.  Sets m_mouseOver to indices of intersecting tile,
    /// or (-1, -1) if no intersection occurs.
    public function findMouseOver():Void
    {
        // NOTE - We could optimize this.
        var i:Number;
        var j:Number;
        var tile:Tile;

        m_mouseOver.x = -1;
        m_mouseOver.y = -1;

        for( i = 0; i < GRID_WIDTH; i++ )
        {
            for( j = 0; j < GRID_HEIGHT; j++ )
            {
                tile = m_grid[i][j];
                if( tile.state != Tile.STATE_ACTIVE )
                {
                    continue;
                }

                var dX:Number   = tile.x - worldMouse.x;
                var dY:Number   = tile.y - worldMouse.y;

                if( (dX * dX) + (dY * dY) <= TILE_RADIUS * TILE_RADIUS )
                {
                    m_mouseOver.x = i;
                    m_mouseOver.y = j;
                    return;
                }
            }
        }
    }

    /// Return pointer to selected tile at given selection index.
    public function selectedTile( index:Number ):Tile
    {
        //Assert.ASSERT( index < m_selection.length, "WaterWords.selectedTile() index invalid: " + index );

        var p:Vector2D = m_selection[index];

        //Assert.ASSERT( p.x >= 0 && p.x < GRID_WIDTH, "WaterWords.selectedTile() p invalid: " + p.toString() );
        //Assert.ASSERT( p.y >= 0 && p.y < GRID_HEIGHT, "WaterWords.selectedTile() p invalid: " + p.toString() );

        return m_grid[p.x][p.y];
    }

    /// Add to selection.  Creates tile connector billboard.
    public function addToSelection( gridI:Number, gridJ:Number ):Void
    {
        //Assert.ASSERT( gridI < GRID_WIDTH, "WaterWords.addToSelection() gridI invalid: " + gridI );
        //Assert.ASSERT( gridJ < GRID_HEIGHT, "WaterWords.addToSelection() gridJ invalid: " + gridJ );

        m_selection.push( new Vector2D( gridI, gridJ ) );

        // Update current word display
        updateCurrentWordDisplay();

        // Create tile connector billboard.
        var length:Number = m_selection.length;

        if( length > 1 )
        {
            var coordA:Vector2D = m_selection[length - 2];
            var coordB:Vector2D = m_selection[length - 1];
            var tileA:Tile      = m_grid[coordA.x][coordA.y];
            var tileB:Tile      = m_grid[coordB.x][coordB.y];
            var n:Number        = whichNeighbor( coordA.x, coordA.y, coordB.x, coordB.y );
            var b:Billboard2D   = layerConnectors.attachMovie( "tileConnector" + n + ".png", "tileConnector" );
            var posX:Number     = (tileA.x + tileB.x) * .5;
            var posY:Number     = (tileA.y + tileB.y) * .5;

            var screenPos:Vector2D  = camera().toScreen( new Vector2D( posX, posY ) );

            b.setPosition( screenPos.x, screenPos.y );
            m_tileConnector.push( b );
        }
    }

    /// Clear selection record.
    public function resetSelection():Void
    {
        if( m_selection.length == 0 )
        {
            return;
        }

        //Assert.ASSERT( m_tileConnector.length + 1 == m_selection.length, "WaterWords.resetSelection() length mismatch" );

        var length:Number = m_selection.length;
        var i:Number;

        for( i = 0; i < length; i++ )
        {
            // Deselect tile.
            selectedTile( i ).setSelected( false, layerTiles );

            // Remove tile connector billboard.
            if( i + 1 < length )
            {
                m_tileConnector[i].removeMovieClip();
            }
        }
        m_selection.length      = 0;
        m_tileConnector.length  = 0;

        // Update current word display
        updateCurrentWordDisplay();
    }

    /// Update current word and current word score displays.
    private function updateCurrentWordDisplay():Void
    {
        var word:String = currentWord();

        m_currentWordDisplay.setText( word );
        if( isAWord( word ) )
        {
            m_buttonSubmit.setDim( false );

            // Update displayed word score
            var text:String = XMath.commaString( "" + currentWordScore() );

            m_currentWordScoreDisplay.setText( "+" + text );
        }
        else
        {
            m_buttonSubmit.setDim( true );
            m_currentWordScoreDisplay.setText( "" );
        }
    }

    /// Add to, remove from, or submit selection.
    /// Returns true if tile is selected, false if some number of tiles are
    /// deselected or if no change is made to selection or if selection is submitted
    /// as a word.
    public function selectTile( gridI:Number, gridJ:Number ):Boolean
    {
        //Assert.ASSERT( gridI < GRID_WIDTH, "WaterWords.selectTile() gridI invalid: " + gridI );
        //Assert.ASSERT( gridJ < GRID_HEIGHT, "WaterWords.selectTile() gridJ invalid: " + gridJ );

        Player.playSound( "waterdrop2", 1.0, 0.0 );

        var t:Tile = m_grid[gridI][gridJ];

        // If tile is not yet selected, select it.
        if( !t.isSelected() )
        {
            if( !hasSelection() )
            {
                addToSelection( gridI, gridJ );
                t.setSelected( true, layerTiles );
                return true;
            }

            // If selection is already of max length, we can't add to it.
            if( m_selection.length == MAX_WORD_LENGTH )
            {
                Player.playSound( "tap", 1.0, 0.0 );
                return false;
            }

            // If we have already started building a word, tile must be a 
            // neighbor of the last tile in our word.
            if( neighborsSelection( gridI, gridJ ) )
            {
                addToSelection( gridI, gridJ );
                t.setSelected( true, layerTiles );
                return true;
            }

            // If newly selected tile does not neightbor last tile of existing
            // selection, clear selection and start new word.
            resetSelection();
            addToSelection( gridI, gridJ );
            t.setSelected( true, layerTiles );
            return false;
        }

        // If tile is already selected, find index of tile in word
        var selectionIndex:Number   = -1;
        var numSelectedTiles:Number = m_selection.length;
        var i:Number;

        for( i = 0; i < numSelectedTiles; i++ )
        {
            var p:Vector2D = m_selection[i];

            if( p.x == gridI && p.y == gridJ )
            {
                selectionIndex = i;
            }
        }

        //Assert.ASSERT( selectionIndex >= 0 && selectionIndex < numSelectedTiles, "WaterWords.selectTile() selectionIndex invalid: " + selectionIndex );

        // If tile is last tile (re-clicked), submit word.
        if( selectionIndex > 0 && selectionIndex == numSelectedTiles - 1 )
        {
            submitSelection();
            return false;
        }

        // Otherwise deselect up to and including position of tile in word.
        var cutTiles:Number = numSelectedTiles - selectionIndex;

        for( i = 0; i < cutTiles; i++ )
        {
            selectedTile( selectionIndex + i ).setSelected( false, layerTiles );
        }
        for( i = 0; i < cutTiles; i++ )
        {
            m_selection.pop();
            if( m_tileConnector.length > 0 )
            {
                m_tileConnector[m_tileConnector.length - 1].removeMovieClip();
                m_tileConnector.pop();
            }
        }

        // Update current word display
        updateCurrentWordDisplay();

        if( !hasSelection() )
        {
            m_dragSelected = false;
        }

        return false;
    }

    /// Select swap tile (source or destination).
    public function selectSwapTile( gridI:Number, gridJ:Number ):Void
    {
        //Assert.ASSERT( gridI < GRID_WIDTH, "WaterWords.selectSwapTile() gridI invalid: " + gridI );
        //Assert.ASSERT( gridJ < GRID_HEIGHT, "WaterWords.selectSwapTile() gridJ invalid: " + gridJ );

        // Select source or destination for swap
        if( hasSwapSource() )
        {
            m_swapDestination = m_grid[gridI][gridJ];

            if( swapSource() == swapDestination() )
            {
                cancelSwap();
            }
            else
            {
                Player.playSound( "zip", 1.0, 0.0 );
                m_activeSwap.setState( Swap.STATE_SWAPPING );

                // Record center of rotation and offset for swap animation.
                m_swapCOR.set( m_swapSource.x + m_swapDestination.x, m_swapSource.y + m_swapDestination.y );
                m_swapCOR.scale( 0.5 );
                m_swapOffset.set( m_swapSource.x - m_swapCOR.x, m_swapSource.y - m_swapCOR.y );

                m_swapDestination.setSwapping( true, layerTiles );
            }
        }
        else
        {
            Player.playSound( "zip", 1.0, 0.0 );
            m_swapSource = m_grid[gridI][gridJ];
            m_swapSource.setSwapping( true, layerTiles );
        }
    }

    /// Return true if given grid coordinates are neighbor of last letter in selection.
    /// Asserts existence of selection.
    public function neighborsSelection( gridI:Number, gridJ:Number ):Boolean
    {
        //Assert.ASSERT( hasSelection(), "WaterWords.neighborsSelection() has no selection" );

        var p:Vector2D              = m_selection[m_selection.length - 1];
        var neighborCoord:Vector2D  = new Vector2D();
        var i:Number;

        // Dumb but easy - check each neighbor.
        // NOTE - We could optimize this.
        for( i = 0; i < NUM_NEIGHBORS; i++ )
        {
            if( !neighborIndices( gridI, gridJ, i, neighborCoord ) )
            {
                continue;
            }

            if( neighborCoord.x == p.x && neighborCoord.y == p.y )
            {
                return true;
            }
        }

        return false;
    }

    /// Get position of swap inventory icon.
    public function swapInventoryPosition( index:Number ):Vector2D
    {
        var SWAP_START_X:Number = gameCenter().x;
        var SWAP_Y:Number       = 410.0;
        var SWAP_SPACING:Number = 40.0;

        return new Vector2D( SWAP_START_X + (SWAP_SPACING * index), SWAP_Y );
    }

    /// Check for clicking swap icon, given screen space mouse position.
    /// If clicked returns true and begins swap process.
    public function checkClickedSwapInventory():Boolean
    {
        var length:Number = m_swap.length;
        var i:Number;

        for( i = 0; i < length; i++ )
        {
            var s:Swap = m_swap[i];

            if( s.state != Swap.STATE_MOUSE_OVER )
            {
                continue;
            }

            var dX:Number = s.x - screenMouse.x;
            var dY:Number = s.y - screenMouse.y;

            if( (dX * dX) + (dY * dY) < SWAP_HANDLE_RADIUS * SWAP_HANDLE_RADIUS )
            {
                beginSwap( i );
                return true;
            }
        }
        return false;
    }

    /// Get screen position of index in "found words" list.
    public function foundWordListPosition( index:Number ):Vector2D
    {
        var START_X:Number      = 20.0;
        var START_Y:Number      = 90.0;
        var Y_SPACING:Number    = 25.0;

        return new Vector2D( START_X, START_Y + (index * Y_SPACING) );
    }

    /// Update swap objects.
    public function updateSwaps( deltaTime:Number ):Void
    {
        var length:Number = m_swap.length;
        var i:Number;

        for( i = 0; i < length; i++ )
        {
            var s:Swap      = m_swap[i];
            var v:Vector2D  = swapInventoryPosition( i );

            switch( s.state )
            {
            case Swap.STATE_RISING:
            case Swap.STATE_DOCKED:
            case Swap.STATE_MOUSE_OVER:
                s.destX = v.x;
                s.destY = v.y;
                break;
            case Swap.STATE_CURSOR:
                s.x     = screenMouse.x;
                s.y     = screenMouse.y;
                s.destX = s.x;
                s.destY = s.y;
                break;
            case Swap.STATE_SWAPPING:
                break;
            }

            s.update( deltaTime );
        }

        // Check for swap completion
        if( isSwapping() && m_activeSwap.state == Swap.STATE_SWAPPING )
        {
            var SWAP_DURATION:Number = 1.0;

            if( m_activeSwap.stateTime > SWAP_DURATION )
            {
                var src:Tile    = swapSource();
                var dst:Tile    = swapDestination();
                var tmp:Number  = src.letter();

                // Snap tiles to original positions and swap their letters
                src.setLetter( dst.letter() );
                dst.setLetter( tmp );

                src.x = m_swapCOR.x + m_swapOffset.x;
                src.y = m_swapCOR.y + m_swapOffset.y;
                dst.x = m_swapCOR.x - m_swapOffset.x;
                dst.y = m_swapCOR.y - m_swapOffset.y;

                src.setSwapping( false, layerTiles );
                dst.setSwapping( false, layerTiles );

                endSwap();
            }
        }
    }

    private function updateSwappingTiles( deltaTime:Number ):Void
    {
        //Assert.ASSERT( hasSwapSource() && hasSwapDestination(), "WaterWords.updateSwappingTiles() missing swap tile(s)" )

        // Rotate about center
        var src:Tile        = swapSource();
        var dst:Tile        = swapDestination();
        var offset:Vector2D = new Vector2D( m_swapOffset.x, m_swapOffset.y );

        offset.rotate( XMath.easeRatio( m_activeSwap.stateTime ) * 180.0 );

        src.x = m_swapCOR.x + offset.x;
        src.y = m_swapCOR.y + offset.y;
        src.positionRenderables();

        dst.x = m_swapCOR.x - offset.x;
        dst.y = m_swapCOR.y - offset.y;
        dst.positionRenderables();
    }
}
