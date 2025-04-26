/**
* Main entry point.
* Registers derived GameEngine, initializes application.
*/
import framework.*;

class Main
{
	static function main()
	{
		// Initialize application instance
        Application.instance().debug = false;
		Application.instance().init( WaterWords.waterWordsInstance() );
   }
}