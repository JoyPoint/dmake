/**
unittests are put in a seperate file so that the dmake
source can be copied to other projects without having to also
copy the unittests
**/
import std.stdio;
import dmakelib;

unittest
{
    assert(!isMakeVar(""));
    assert(!isMakeVar("$"));
    assert(isMakeVar("$A"));
    assert(!isMakeVar("$AB"));
    assert(isMakeVar("$(A)"));
    assert(isMakeVar("$(AB)"));
    assert(isMakeVar("$(ABC_DEF)"));
    assert(!isMakeVar("$(ABC_DEF)C"));
}

int main()
{
    {
        auto engine = new LocalMakeEngine();
        engine.putCode(__LINE__,`
pvs:
#	Command1
#	Command2
    Command3
#	Command4
#	Command5
`);
        engine.resolveReferences();
        //engine.run();
    }

    void testError(uint line, string code)
    {
        // Test on the global make engine
        gmake.reset();
        gmake.putCode(line, code);
        try
        {
            gmake.resolveReferences();
            //gmake.run();
            assert(0, "expected exception but didn't get one");
        }
        catch(MakeException e)
        {
            writefln("Caught expected exception: %s", e.msg);
        }

        // Test on a local make engine
        {
            auto engine = new LocalMakeEngine();
            engine.putCode(line, code);
            try
            {
                engine.resolveReferences();
                //engine.run();
                assert(0, "expected exception but didn't get one");
            }
            catch(MakeException e)
            {
                writefln("Caught expected exception: %s", e.msg);
            }
        }
    }

    // Recursive definitions
    testError(__LINE__,`
A=$(B)
B=$(A)
$(A):
    `);
    testError(__LINE__,`
A=$(B)
B=$(C)
C=$(A)
$(A):
    `);
    testError(__LINE__,`
$@: hello
`);

    auto engine = new LocalMakeEngine();
    engine.putCode(__LINE__, `
TESTVAR=A
TESTVAR1 = B
  TESTVAR2 = C
   TESTVAR3= C
   TESTVAR4  =C
`);
    engine.putCode(__LINE__, `
# All of the following vars should become "A B C"
TEST_LINE_CONT1=A \
                 B \
                 C
TEST_LINE_CONT2=A \
                 # Should still work\
                 B \
                 C
TEST_LINE_CONT3=A#\
                 B #\
                 C#
TEST_LINE_CONT4=A  #\
                 B #  \
                 C
# comment with unnecessary \
TEST_LINE_CONT5=A B \
C\

TESTVAR1 = B
  TESTVAR2 = C
   TESTVAR3= C
   TESTVAR4  =C
`);
    engine.resolveReferences();
    //engine.run();
    return 0;
}
