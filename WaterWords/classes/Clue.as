/**
* Clue provides a hint and an answer in the form of two strings.
*/
import error.*;

class Clue
{
    // Instance members:

    public var hint:String;
    public var answer:String;

    // Constructor:

    public function Clue( hint:String, answer:String )
    {
        //Assert.ASSERT( hint != undefined, "Clue.Clue() hint is undefined" );
        //Assert.ASSERT( answer != undefined, "Clue.Clue() answer is undefined" );

        this.hint   = hint;
        this.answer = answer;
    }
};
