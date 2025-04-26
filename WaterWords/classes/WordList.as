/**
* Word list is simply a list of words with a fairly fast
* query for word existence.
*/
import container.*;
import error.*;
import framework.*;

class WordList
{
    // Instance members:

    private var m_word:Array; // Array of strings, but String.split() method complains unless we declare this a plain Array.
    private var m_xml:XML; // Source XML object
    private var m_loaded:Boolean; // If true, we're ready for use.

    // Constructor:

    public function WordList()
    {
        m_word      = new Array();
        m_xml       = new XML();
        m_loaded    = false;
    }

    // Instance methods:

    /// Check for existence of word.
    /// This method uses a reasonably fast binary search so it may be called frequently.
    public function wordExists( word:String ):Boolean
    {
        //Assert.ASSERT( word != undefined, "WordList.wordExists() word is undefined" );
        //Assert.ASSERT( m_word != undefined, "WordList.wordExists() m_word is undefined" );

        var wordLength:Number = word.length;

        if( wordLength == 0 )
        {
            return false;
        }

        var numWords:Number = m_word.length;

        if( numWords == 0 )
        {
            return false;
        }

        // Binary search based on string compare
        var left:Number 	= 0;
        var right:Number 	= numWords - 1;
		var index:Number;
        var equality:Number;
        var char:Number;
        var compWord:String;
        var compWordLength:Number;
        var compChar:Number;
        var i:Number;

        while( left <= right )
        {
            // Test current index
			index			= Math.floor( (left + right) / 2 );
            compWord        = m_word[index];
            compWordLength  = compWord.length;

            // Error checking.  We could remove this if necessary for performance.
            if( compWord == undefined )
            {
                trace( "compWord is undefined" ); // Error in word list
                return false;
            }
            if( compWordLength == 0 )
            {
                trace( "compWord is empty" ); // Error in word list
                return false;
            }

            equality    = 0;
            i           = 0;
            while( true )
            {
                char        = word.charCodeAt( i );
                compChar    = compWord.charCodeAt( i );

                if( char < compChar )
                {
                    equality = -1;
                    break;
                }
                if( char > compChar )
                {
                    equality = 1;
                    break;
                }
                if( i + 1 == wordLength && i + 1 < compWordLength )
                {
                    equality = -1;
                    break;
                }
                if( i + 1 == compWordLength && i + 1 < wordLength )
                {
                    equality = 1;
                    break;
                }

                if( i + 1 == compWordLength && i + 1 == wordLength )
                {
                    return true; // We found equal word
                }
                i++;
            }

            // Modify search range
            if( equality > 0 )
            {
				left = index + 1;
			}
            else
            {
				right = index - 1;
            }
        }

        return false;
    }

    /// Load words.
    public function loadWords( filename:String ):Void
    {
        // Load from XML
        m_loaded            = false;
        m_xml.ignoreWhite   = true;

        var wl:WordList     = this; // Referenced in onLoad function

        m_xml.onLoad =
            function( success:Boolean ):Void
            {
                //Assert.ASSERT( success, "Failed to load XML file for word list: " + filename );
                wl.readXML();
            }
        m_xml.load( filename );
    }

    /// Return true if we are fully loaded.
    public function isLoaded():Boolean
    {
        return m_loaded;
    }

    /// Get percent loaded (from 0 to 1).
    public function percentLoaded():Number
    {
        //Assert.ASSERT( m_xml != undefined, "WordList.percentLoaded() m_xml is undefined" );

        if( m_xml.loaded )
        {
            return 1.0;
        }

        var bytesLoaded:Number  = m_xml.getBytesLoaded();
        var bytesTotal:Number   = m_xml.getBytesTotal();

        if( isNaN( bytesLoaded ) || isNaN( bytesTotal ) || bytesTotal == 0.0 )
        {
            return 0.0;
        }

        return bytesLoaded / bytesTotal;
    }

    /// Read word list from XML, called once XML is fully loaded.
    public function readXML():Void
    {
        //Assert.ASSERT( m_xml != undefined, "WordList.readXML() m_xml is undefined" );
        //Assert.ASSERT( m_xml.loaded, "WordList.readXML() m_xml not loaded" );
        //Assert.ASSERT( m_word != undefined, "WordList.readXML() m_word is undefined" );

        var node:XMLNode;

        for( node = m_xml.firstChild.firstChild; node != null; node = node.nextSibling )
        {
            if( node.nodeName == "words" ) // Read word list, separated by carriage returns.
            {
                m_word = node.firstChild.nodeValue.split( "\r" );
            }
        }
        m_loaded = true;
    }
};
