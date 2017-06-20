/**
Features:
* Supports forward references
* Detects recursive definitions
* Custom Log Callbacks
*/
module dmakelib;

static import std.stdio, std.file, std.path;

import std.file : timeLastModified;
import std.string : indexOf, lineSplitter, stripRight;
import std.array  : replace, Appender, appender;
import std.algorithm : max, min, canFind;
import std.format : formattedWrite;
import std.process   : environment, spawnShell, wait;
import std.typecons  : Yes, No, Flag;
import std.algorithm : swap;
import std.conv   : text;
import std.datetime : SysTime;

alias Overwrite = Flag!"overwrite";

alias GlobalMakeTemplate = MakeEngineTemplate!(Yes.global);
alias GlobalMakeEngine = MakeEngineTemplate!(Yes.global).MakeEngine;
alias LocalMakeEngine = MakeEngineTemplate!(No.global).MakeEngine;

/**
  The global gshared instance of the make engine.  Use this
  if you only require one instance of the MakeEngine.
  TODO: May not need this
*/
alias gmake = GlobalMakeEngine.globalMakeEngine;

void loadCommandLineVars(string[]* args)
{
    gmake.loadCommandLineVars(args);
}
ref MakeOptions makeOptions()
{
    return GlobalMakeEngine.globalMakeEngine.makeOptions;
}

// alias this doesn't seem to work at the module level,
// so for now I have to define each alias another wy
//    alias gmake this;
// this alias idea also doesn't work
//    alias define        = &gmake.define;
//    alias defineFile    = &gmake.defineFile;
//    alias defineProgram = &gmake.defineProgram;
// this didn't work either
//    immutable define        = GlobalMakeEngine.globalMakeEngine.define;
//    immutable defineProgram = GlobalMakeEngine.globalMakeEngine.defineProgram;
//    immutable defineFile    = GlobalMakeEngine.globalMakeEngine.defineFile;
// this works, but too verbose, I don't like it

void dump()
{
    gmake.dump();
}

bool isDefined(string varName)
{
    return gmake.isDefined(varName);
}
auto getSymbol(string varName)
{
    return gmake.getSymbol(varName);
}

auto declare(string varName, BuildObject defaultValue)
{
    return gmake.declare(varName, defaultValue);
}
auto declare(string varName, string defaultValue)
{
    return gmake.declare(varName, defaultValue);
}

auto define(string varName, BuildObject value)
{
    return gmake.define(varName, value);
}
auto define(string varName, string value)
{
    return gmake.define(varName, value);
}

auto var(string varName)
{
    return gmake.var(varName);
}
auto thing(string value)
{
    return gmake.thing(value);
}
auto target(string name)
{
    return gmake.target(name);
}
auto program(T...)(T args)
{
    return gmake.program!T(args);
}
auto exe(T...)(T args)
{
    return gmake.exe!T(args);
}
auto path(T...)(T args)
{
    return gmake.path!T(args);
}
auto file(T...)(T args)
{
    return gmake.file!T(args);
}
auto list(T...)(T args)
{
    return gmake.list!T(args);
}
auto shell(string command, Flag!"failOnNonZeroExitCode" failOnNonZeroExitCode = Yes.failOnNonZeroExitCode)
{
    return gmake.shell(command, failOnNonZeroExitCode);
}
/*
auto defineProgram(Overwrite overwrite = Overwrite.yes, T...)(string varName, T args)
{
    return gmake.defineProgram!overwrite(varName, args);
}
auto createFile(T...)(T args)
{
    return gmake.createFile(args);
}
auto defineFile(Overwrite overwrite = Overwrite.yes, T...)(string varName, T args)
{
    return gmake.defineFile!overwrite(varName, args);
}
auto definePath(Overwrite overwrite = Overwrite.yes, T...)(string varName, T args)
{
    return gmake.definePath!overwrite(varName, args);
}
auto createList(T...)(T args)
{
    return gmake.createList!T(args);
}
auto defineList(string varName, BuildObject[] objects...)
{
    return gmake.defineList(varName, objects);
}
auto phony(string name)
{
    return new Phony(name);
}

auto createCommand(string command)
{
    return gmake.createCommand(command);
}
*/

void addRule(BuildObject targets, BuildObject deps, Command[] commands,
    string filename = __FILE__, uint line = __LINE__)
{
    gmake.addRule(targets, deps, commands, filename, line);
}

void putCode(uint codeLineOffset, string code, string filename = __FILE__)
{
    gmake.putCode(codeLineOffset, code, filename);
}
void putMakefile(string filename)
{
    gmake.putMakefile(filename);
}
/*
auto createUserTarget(string value)
{
    return gmake.createUserTarget(value);
}
auto createUserTargets(string[] values...)
{
    return gmake.createUserTargets(values);
}
*/

int run(string[] commandLineArgs)
{
    return gmake.run(commandLineArgs);
}
int runTargets(string[] targets)
{
    return gmake.runTargets(targets);
}
int run(BuildObject[] targets = null)
{
    return gmake.run(targets);
}


class MakeException : Exception
{
    this(string msg = null, string file = __FILE__, uint line = __LINE__,
        Throwable next = null) pure nothrow @nogc @safe
    {
        super(msg, file, line, next);
    }
}

interface IFileOrPath
{
    @property string fileOrPathName();
}
interface IPath
{
    @property string pathName();
}
interface IFile
{
    @property string fileName();
}

string fixPlatformSeparators(string path)
{
    version(Windows)
    {
        return path.replace("/", "\\");
    }
    else
    {
        return path;
    }
}

// returns: true if it contains a path separator ('/' or '\')
bool checkAndNormalizePotentialFilename(string* normalized, string name)
{
    version(Windows)
    {
        foreach(i; 0..name.length)
        {
            if(name[i] == '/')
            {
                auto buildString = new char[name.length];
                foreach(j, c; name)
                {
                    if(c == '/')
                    {
                        buildString[j] = '\\';
                    }
                    else
                    {
                        buildString[j] = c;
                    }
                }
                *normalized = cast(string)buildString;
                return true;
            }
        }
        *normalized = name;
        return false;
    }
    else
    {
        *normalized = name;
        return name.canFind("/");
    }
}

char[] join(T)(string seperator, T[] objects, string function(T obj) stringGetter)
{
    size_t size = 0;
    foreach(i, object; objects)
    {
        if(i > 0) size += seperator.length;
        size += stringGetter(object).length;
    }
    auto combined = new char[size];
    size_t offset = 0;
    foreach(i, object; objects)
    {
        if(i > 0)
        {
            combined[offset..offset+seperator.length] = seperator[];
            offset += seperator.length;
        }
        auto value = stringGetter(object);
        combined[offset..offset+value.length] = value[];
        offset += value.length;
    }
    assert(offset == size);
    return combined;
}
T passThrough(T)(T value) { return value; }

string buildRawPath(T...)(T args)
{
    string[T.length] argStrings;
    foreach(i, argType; T)
    {
        static if( is( T[i] == IPath ) )
        {
            argStrings[i] = args[i].pathName;
        }
        else static if( is( T[i] == IFileOrPath ) )
        {
            argStrings[i] = args[i].fileOrPathName;
        }
        else static if( is( T[i] == string ) )
        {
            argStrings[i] = fixPlatformSeparators(args[i]);
        }
        else static assert(0, "unhandled buildPath2 type "~T.stringof);
    }
    return cast(string)join("/", argStrings, &passThrough!string);
}
string buildRawFile(T...)(T args)
{
    string lastPart;
    static if( is( T[$-1] == immutable(IFile) ) )
    {
        lastPart = args[$-1].fileName;
    }
    else static if( is( T[$-1] == IFileOrPath ) )
    {
        lastPart = args[$-1].fileOrPathName;
    }
    else static if( is( T[$-1] == string ) )
    {
        lastPart = fixPlatformSeparators(args[$-1]);
    }
    else static assert(0, "unhandled buildFile type "~T.stringof);

    static if(T.length == 1)
    {
        return lastPart;
    }
    else
    {
        return buildRawPath(args[0..$-1], lastPart);
    }
}

auto skipWhitespace(inout(char)* parsePtr, const char* limit)
{
    for(;parsePtr < limit; parsePtr++)
    {
        char c = *parsePtr;
        if(c != ' ' && c != '\t')
        {
            break;
        }
    }
    return parsePtr;
}
auto tillCommentOrLimit(inout(char)* parsePtr, const char* limit)
{
    for(;parsePtr < limit; parsePtr++)
    {
        char c = *parsePtr;
        if(c == '#') break;
    }
    return parsePtr;
}

bool validVarNameChar(char c)
{
    return
        (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') ||
        (c >= 'a' && c <= 'z') ||
        c == '_';
}

bool isMakeVar(const(char)[] str)
{
    if(str.length >= 2 && str[0] == '$')
    {
        if(str.length == 2)
        {
            return true;
        }
        if(str[1] == '(' && str[$-1] == ')')
        {

            foreach(c; str[2..$-1])
            {
                if(!validVarNameChar(c))
                {
                    return false;
                }
            }
            return true;
        }
    }
    return false;
}

auto fileLocation(string filename, uint lineNumber)
{
    static struct FileLocation
    {
        string filename;
        uint lineNumber;
        void toString(scope void delegate(const(char)[]) sink) const
        {
            sink(filename);
            formattedWrite(sink, "(%s)", lineNumber);
        }
    }
    return FileLocation(filename, lineNumber);
}

struct MakeOptions
{
    void delegate(const(char)[] message) logSink;

    bool logSymbolOverrides;
    /*
    void delegate(const(char)[]) logger()
    {
        if(loggerDelegate is null)
        {
            loggerDelegate = &std.stdio.stdout.writeln!(const(char)[]);
        }
        return loggerDelegate;
    }
    */
}

struct MakeRule
{
    string filename;
    uint lineNumber;
    BuildObject targets;
    BuildObject deps;
    Command[] commands;

    @property auto location() const
    {
        return fileLocation(filename, lineNumber);
    }
}

class Command
{
    @property abstract string getRaw();
    abstract string getProcessed(MakeRule* rule);
    abstract void run(MakeRule* rule);
}

class BuildObject
{
    @property abstract inout(BuildObjectList) tryAsList() inout;
    @property abstract inout(SingleBuildObject) asSingle() inout;

    abstract int opApply(int delegate(SingleBuildObject) handler);

    void handleDeclare(string other)
    {
        // DO NOTHING FOR NOW
    }
    void handleDeclare(BuildObject other)
    {
        // DO NOTHING FOR NOW
    }
    void overrideValue(string newValue)
    {
        // DO NOTHING FOR NOW
    }

    abstract string getRawValue();

    abstract BuildObject resolveReferences(MakeRule* ruleContext);

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: Need to make this return a BuildObject that
    //       may be different from the current BuildObject
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    abstract string resolveAsMacro();
    abstract void resolveMacros();

    bool targetCheckHasBeenCached = false;
    SysTime cachedTargetCheck;
    abstract void removeTargetCheckCachedValue();
    final SysTime targetCheck()
    {
        if(!targetCheckHasBeenCached)
        {
            cachedTargetCheck = targetCheckImpl();
            targetCheckHasBeenCached = true;
        }
        return cachedTargetCheck;
    }
    // Return: SysTime.max if it needs to be built, or, return the SysTime that it was last built
    abstract SysTime targetCheckImpl();

    abstract bool targetIs(BuildObject other);

    abstract void toString(scope void delegate(const(char)[]) sink) const;

    static string staticGetRawValue(BuildObject obj)
    {
        return obj.getRawValue();
    }
    static string staticResolveAsMacro(BuildObject obj)
    {
        return obj.resolveAsMacro();
    }
}

class BuildObjectList : BuildObject
{
    BuildObject[] objects;
    string combinedRawValues;
    string cachedCombinedProcessedValues;

    this(BuildObject[] objects)
    {
        this.objects = objects;
    }
    @property final override inout(BuildObjectList) tryAsList() inout
    {
        return this;
    }
    @property final override inout(SingleBuildObject) asSingle() inout
    {
        assert(0);
    }
    final override int opApply(int delegate(SingleBuildObject) handler)
    {
        int result = 0;
        foreach(object; objects)
        {
            result = object.opApply(handler);
            if(result)
            {
                break;
            }
        }
        return result;
    }
    override string getRawValue()
    {
        if(combinedRawValues == null)
        {
            combinedRawValues = cast(string)join(" ", objects,
                &BuildObject.staticGetRawValue);
        }
        return combinedRawValues;
    }
    final override BuildObject resolveReferences(MakeRule* ruleContext)
    {
        foreach(i; 0..objects.length)
        {
            objects[i] = objects[i].resolveReferences(ruleContext);
        }
        return this;
    }
    override string resolveAsMacro()
    {
        if(cachedCombinedProcessedValues == null)
        {
            cachedCombinedProcessedValues = cast(string)join(" ",
                objects, &BuildObject.staticResolveAsMacro);
        }
        return cachedCombinedProcessedValues;
    }
    override void resolveMacros()
    {
        foreach(object; objects)
        {
            object.resolveMacros();
        }
    }
    final override void removeTargetCheckCachedValue()
    {
        foreach(object; objects)
        {
            object.removeTargetCheckCachedValue();
        }
    }
    override SysTime targetCheckImpl()
    {
        SysTime oldestModifyTime = SysTime.max;
        foreach(object; objects)
        {
            auto modifyTime = object.targetCheck();
            if(modifyTime == SysTime.max)
            {
                return SysTime.max;
            }
            oldestModifyTime = min(modifyTime, oldestModifyTime);
        }
        return oldestModifyTime;
    }
    override bool targetIs(BuildObject other)
    {
        foreach(object; objects)
        {
            if(targetIs(other))
            {
                return true;
            }
        }
        return false;
    }
    override void toString(scope void delegate(const(char)[]) sink) const
    {
        foreach(i, object; objects)
        {
            if(i > 0) sink(" ");
            object.toString(sink);
        }
    }
}

class SingleBuildObject : BuildObject
{
    @property final override inout(BuildObjectList) tryAsList() inout
    {
        return null;
    }
    @property final override inout(SingleBuildObject) asSingle() inout
    {
        return this;
    }
    final override int opApply(int delegate(SingleBuildObject) handler)
    {
        return handler(this);
    }
    final override void removeTargetCheckCachedValue()
    {
        this.targetCheckHasBeenCached = false;
    }
    @property abstract string targetDescription();
}

// NOTE: not sure if I should support macros inside environment variables.  It's easy
//       to do but unusual.  For now it's not supported.
class BuildUnprocessedValue : SingleBuildObject
{
    string value;
    this(string value)
    {
        this.value = value;
    }
    /*
    static if(global == Yes.global)
    {
        this(string value)
        {
            this.value = value;
        }
        this(MakeEngine engine, string value)
        {
            this.value = value;
        }
    }
    else
    {
        MakeEngine engine;
        this(MakeEngine engine, string value)
        {
            super(engine);
            this.value = value;
        }
    }
    */
    @property override string targetDescription()
    {
        return value;
    }
    override string getRawValue()
    {
        return value;
    }
    override string resolveAsMacro()
    {
        return value;
    }
    override void resolveMacros()
    {
    }
    override SysTime targetCheckImpl()
    {
        return targetCheckFile(value);
    }
    override bool targetIs(BuildObject other)
    {
        // TODO: currently isn't handling '*' and other types of rules
        //import std.stdio;
        //writefln("targetIs (%s) comparing with (%s)", other.resolveAsMacro(), value);
        return value == other.resolveAsMacro();
    }
    override void toString(scope void delegate(const(char)[]) sink) const
    {
        printWithQuotesIfHasSpace(value, sink);
    }
}

class EnvironmentVariable : BuildUnprocessedValue
{
    this(string value)
    {
        super(value);
    }
    final override BuildObject resolveReferences(MakeRule* ruleContext)
    {
        return this;
    }
}
class TargetsReference : BuildObject
{
    __gshared static TargetsReference instance = new TargetsReference();
    private this()
    {
    }
    final override BuildObject resolveReferences(MakeRule* ruleContext)
    {
        return ruleContext.targets;
    }
    override string getRawValue() { return "$@"; }
    @property final override inout(BuildObjectList) tryAsList() inout
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    @property final override inout(SingleBuildObject) asSingle() inout
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    final override int opApply(int delegate(SingleBuildObject) handler)
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    final override void removeTargetCheckCachedValue()
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    override string resolveAsMacro()
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    final @property string processedValue()
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    override void resolveMacros()
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    override SysTime targetCheckImpl()
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    override bool targetIs(BuildObject other)
    {
        assert(0, "code bug: cannot call this method on an TargetsReference");
    }
    override void toString(scope void delegate(const(char)[]) sink) const
    {
        sink("$@");
    }
}

enum BuildObjectType
{
    program,
}

template MakeEngineTemplate(Flag!"global" global)
{
    static if(global == Yes.global)
    {
        alias engine = MakeEngine.globalMakeEngine;
    }

    class MakeEngine
    {
        static if(global == Yes.global)
        {
            __gshared static MakeEngine globalMakeEngine = new MakeEngine();
        }

        enum CodeState
        {
            unprocessed, pass1Complete, pass2Complete
        }
        struct CodeBlock
        {
            string code;
            string filename;
            uint codeLineOffset;
            this(string code, string filename, uint codeLineOffset) immutable
            {
                this.code = code;
                this.filename = filename;
                this.codeLineOffset = codeLineOffset;
            }
            auto location(uint lineOffset) const
            {
                return fileLocation(filename, codeLineOffset + lineOffset);
            }
        }

        MakeOptions makeOptions;
        BuildObject[string] symbolTable; // use setSymbol/getSymbol to access
        private Appender!(CodeBlock[]) codeBlocks;
        private Appender!(MakeRule[]) rulesAppender;
        private Appender!(string[]) macroResolutionStack;
        this()
        {
        }
        void reset()
        {
            makeOptions = makeOptions.init;
            symbolTable = symbolTable.init;
            this.codeBlocks.clear();
            this.rulesAppender.clear();
            this.macroResolutionStack.clear();
        }
        void log(T...)(const(char)[] fmt, T args)
        {
            auto logSink = makeOptions.logSink;
            bool flushStdout = false;
            if(logSink is null)
            {
                logSink = &std.stdio.stdout.write!(const(char)[]);
                flushStdout = true;
            }
            formattedWrite(logSink, fmt, args);
            formattedWrite(logSink, "\n");
            if(flushStdout)
            {
                std.stdio.stdout.flush();
            }
        }

        void dump()
        {
            log("---------------------------");
            log("Symbol Table");
            log("---------------------------");
            foreach(entry; symbolTable.byKeyValue)
            {
                log("%s: (Type=%s) %s", entry.key, typeid(entry.value), entry.value);
            }
            foreach(ref rule; rulesAppender.data)
            {
                log("--------------------------");
                log("Targets:");
                foreach(target; rule.targets)
                {
                    log("    %s > %s", target.getRawValue(), target.resolveAsMacro());
                }
                if(rule.deps is null)
                {
                    log("Deps: (none)");
                }
                else
                {
                    log("Deps:");
                    foreach(dep; rule.deps)
                    {
                        log("    %s > %s", dep.getRawValue(), dep.resolveAsMacro());
                    }
                }
                if(rule.commands is null)
                {
                    log("Commands: (none)");
                }
                else
                {
                    log("Commands:");
                    foreach(command; rule.commands)
                    {
                        log("  RAW      : %s", command.getRaw);
                        log("  PROCESSED: %s", command.getProcessed(&rule));
                    }
                }
            }
        }

        void loadCommandLineVars(string[]* args)
        {
            int newLength = 0;
            foreach(i; 0..(*args).length)
            {
                auto arg = (*args)[i];
                auto equalIndex = indexOf(arg, '=');
                if(equalIndex == -1)
                {
                    (*args)[newLength++] = arg;
                }
                else
                {
                    auto varName = arg[0..equalIndex];
                    auto varValue = arg[equalIndex+1..$];
                    auto existing = tryGetSymbol(varName);
                    if(existing)
                    {
                        existing.overrideValue(varValue);
                    }
                    else
                    {
                        setSymbol(varName, new CommandLineValue(this, varValue));
                    }
                }
            }
            *args = (*args)[0..newLength];
        }

        bool isDefined(string varName)
        {
            return tryGetSymbol(varName) !is null;
        }
        auto getSymbol(string varName)
        {
            auto result = tryGetSymbol(varName);
            if(result is null)
            {
                log("Error: symbol %s is not defined", MacroNameFormat(varName));
                throw new MakeException();
            }
            return result;
        }
        auto tryGetSymbol(string varName)
        {
            auto buildObject = symbolTable.get(varName, null);
            if(!buildObject)
            {
                auto env = environment.get(varName);
                if(env)
                {
                    buildObject = new EnvironmentVariable(env);
                    symbolTable[varName] = buildObject;
                }
            }
            return buildObject;
        }
        private void setSymbol(string varName, BuildObject object, Overwrite overwrite = Overwrite.yes)
        {
            if(!overwrite)
            {
                if(tryGetSymbol(varName))
                {
                    return;
                }
            }
            else if(makeOptions.logSymbolOverrides)
            {
                auto existing = tryGetSymbol(varName);
                if(existing)
                {
                    log("%s has been overriden:", MacroNameFormat(varName));
                    log("  old: %s", ShortString!30(existing.getRawValue));
                    log("  new: %s", ShortString!30(object.getRawValue));
                }
            }
            symbolTable[varName] = object;
        }

        private string resolveMacro(string macroName)
        {
            auto resolved = tryResolveMacro(macroName);
            if(resolved is null)
            {
                log("Error: macro %s is undefined", MacroNameFormat(macroName));
                throw new MakeException();
            }
            return resolved;
        }
        private string tryResolveMacro(string macroName)
        {
            foreach_reverse(i, resolving; macroResolutionStack.data)
            {
                if(macroName.length == resolving.length &&
                   macroName[] == resolving[])
                {
                    // TODO: need to provide error context
                    log("Error: circular reference detected:");
                    foreach(stackMacro; macroResolutionStack.data[i..$])
                    {
                        log(" %s ->", MacroNameFormat(stackMacro));
                    }
                    log("  %s ---^", MacroNameFormat(macroName));
                    throw new MakeException();
                }
            }
            auto buildObject = tryGetSymbol(macroName);
            if(buildObject is null)
            {
                // TODO: need to provide error context
                //log("Error: macro %s is undefined", MacroNameFormat(macroName));
                //throw new MakeException();
                return null;
            }
            {
                macroResolutionStack.put(macroName);
                scope(exit) macroResolutionStack.shrinkTo(macroResolutionStack.data.length-1);

                return buildObject.resolveAsMacro();
            }
        }

        auto declare(string varName, BuildObject defaultValue)
        {
            auto existing = tryGetSymbol(varName);
            if(existing)
            {
                existing.handleDeclare(defaultValue);
            }
            else
            {
                setSymbol(varName, defaultValue);
            }
        }
        auto declare(string varName, string defaultValue)
        {
            auto existing = tryGetSymbol(varName);
            if(existing)
            {
                existing.handleDeclare(defaultValue);
            }
            else
            {
                setSymbol(varName, new GenericDlangDefine(this, defaultValue));
            }
        }

        auto define(string varName, string value/*, Overwrite overwrite = Overwrite.yes*/)
        {
            auto genericDefine = new GenericDlangDefine(this, value);
            setSymbol(varName, genericDefine, Overwrite.yes);
            return genericDefine;
        }
        auto define(string varName, BuildObject value/*, Overwrite overwrite = Overwrite.yes*/)
        {
            setSymbol(varName, value, Overwrite.yes);
            return value;
        }

        /*
        auto createUserTarget(string value)
        {
            return new UserTarget(this, value);
        }
        auto createUserTargets(string[] values...)
        {
            UserTarget[] targets = new UserTarget[values.length];
            foreach(i, value; values)
            {
                targets[i] = new UserTarget(this, value);
            }
            return targets;
        }
        */

        auto var(string varName)
        {
            return new UnresolvedVariable(this, varName);
        }
        auto thing(string value)
        {
            return new GenericDlangDefine(this, value);
        }
        auto target(string name)
        {
            return new NamedTarget(this, name);
        }

        auto program(T...)(T args)
        {
            return new Program(this, buildRawFile(args));
        }
        auto exe(T...)(T args)
        {
            string rawFile;
            version(Windows)
            {
                rawFile = buildRawFile(args, ".exe");
            }
            else
            {
                rawFile = buildRawFile(args);
            }
            return new Program(this, rawFile);
        }
        /*
        auto defineProgram(Overwrite overwrite = Overwrite.yes, T...)(string varName, T args)
        {
            auto program = program(args);
            setSymbol(varName, program, overwrite);
            return program;
        }
        */

        auto file(T...)(T args)
        {
            return new FileObject(this, buildRawFile(args));
        }
        /*
        auto defineFile(Overwrite overwrite = Overwrite.yes, T...)(string varName, T args)
        {
            auto file = createFile(args);
            setSymbol(varName, file);
            return file;
        }
        */

        auto path(T...)(T args)
        {
            return new Path(this, buildRawPath(args));
        }
        /*
        auto definePath(Overwrite overwrite = Overwrite.yes, T...)(string varName, T args)
        {
            auto path = createPath(args);
            setSymbol(varName, path);
            return path;
        }
        */

        auto list(T...)(T args)
        {
            auto objects = new BuildObject[args.length];
            foreach(i, arg; args)
            {
                objects[i] = arg;
            }
            return new BuildObjectList(objects);
        }
        /*
        auto defineList(string varName, BuildObject[] objects...)
        {
            auto list = new BuildObjectList(this, objects);
            setSymbol(varName, list);
            return list;
        }
        */

        auto shell(string command, Flag!"failOnNonZeroExitCode" failOnNonZeroExitCode = Yes.failOnNonZeroExitCode)
        {
            return new EngineCommand(this, command, failOnNonZeroExitCode);
        }

        void addRule(BuildObject targets, BuildObject deps, Command[] commands,
            string filename = __FILE__, uint line = __LINE__)
        {
            rulesAppender.put(MakeRule(filename, line, targets, deps, commands));
        }

        void putMakefile(string filename)
        {
            // TODO: If the filename has an unresolved macro, should try to process this later
            auto code = readFile(processFileName(filename));
            codeBlocks.put(immutable CodeBlock(code, filename, 0));
            parse(&codeBlocks.data[$-1]);
        }
        void putCode(uint codeLineOffset, string code, string filename = __FILE__)
        {
            codeBlocks.put(immutable CodeBlock(code, filename, codeLineOffset));
            parse(&codeBlocks.data[$-1]);
        }

        private string process(string raw, MakeRule* ruleContext)
        {
            auto dollarIndex = raw.indexOf("$");
            if(dollarIndex == -1)
            {
                return raw;
            }

            auto processed = appender!(char[])();
            processed.reserve(raw.length*3);
            size_t readOffset = 0;

            while(true)
            {
                processed.put(raw[readOffset..dollarIndex]);
                readOffset = dollarIndex + 1;
                if(readOffset == raw.length)
                {
                    // TODO: need to put a file location
                    log("Error: variable \"%s\" cannot end with '$'", Escaped(raw));
                    throw new MakeException();
                }
                if(raw[readOffset] != '(')
                {
                    if(validVarNameChar(raw[readOffset]))
                    {
                        processed.put(resolveMacro(raw[readOffset..readOffset+1]));
                        readOffset++;
                    }
                    else if(raw[readOffset] == '@')
                    {
                        if(!ruleContext)
                        {
                            // TODO: need to put a file location
                            log("Error: cannot use special $@ variable in this context");
                            throw new MakeException();
                        }
                        processed.put(ruleContext.targets.resolveAsMacro());
                        readOffset++;
                    }
                    else
                    {
                        // TODO: need to put a file location
                        log("Error: invalid macro sequence \"%s\"", Escaped(raw[dollarIndex..$]));
                        throw new MakeException();
                    }
                }
                else
                {
                    readOffset++;
                    auto nameOffset = readOffset;
                    for(;; readOffset++)
                    {
                        if(readOffset >= raw.length)
                        {
                            // TODO: need to put a file location
                            log("Error: variable \"%s\" ended inside macro", Escaped(raw));
                            throw new MakeException();
                        }
                        if(raw[readOffset] == ')')
                        {
                            break;
                        }
                        if(!validVarNameChar(raw[readOffset]))
                        {
                            // TODO: need to put a file location
                            log("Error: invalid macro sequence \"%s\"", Escaped(raw[nameOffset..$]));
                            throw new MakeException();
                        }
                    }
                    processed.put(resolveMacro(raw[nameOffset..readOffset]));
                    readOffset++;
                }
                dollarIndex = raw[readOffset..$].indexOf("$");
                if(dollarIndex == -1)
                {
                    break;
                }
                dollarIndex += readOffset;
            }
            if(readOffset < raw.length)
            {
                processed.put(raw[readOffset..$]);
            }
            return processed.data.idup;
        }
        string processDlangDefine(string rawDefine)
        {
            return process(rawDefine, null);
        }
        string processFileName(string rawFile)
        {
            return process(rawFile, null);
        }
        string processCommand(string rawCommand, MakeRule* ruleContext)
        {
            return process(rawCommand, ruleContext);
        }
        string processPathName(string rawPath)
        {
            return process(rawPath, null);
        }
        string processUserTarget(string rawTarget)
        {
            return process(rawTarget, null);
        }
        string processCodeDefinedValue(string rawValue)
        {
            return process(rawValue, null);
        }

        private void parse(const(CodeBlock)* codeBlock)
        {
            uint lineNumber = 1;

            immutable(char)* firstSplicedLineStart = null;
            uint spliceLineNumber = 0;
            auto lineSplicer = appender!(char[]);

            auto objectAppender = appender!(Object[]);
            BuildObject currentTargets = null;
            BuildObject currentDeps    = null;
            uint currentRuleLineNumber;

            void addCurrentRule()
            {
                rulesAppender.put(MakeRule(codeBlock.filename, currentRuleLineNumber,
                    currentTargets, currentDeps, (cast(Command[])objectAppender.data).dup));
                objectAppender.clear();
                currentDeps = null;
                currentTargets = null;
            }

            foreach(line; lineSplitter(codeBlock.code))
            {
                //log("[DEBUG] %s \"%s\"", lineNumber, line);

                if(lineSplicer.data.length)
                {

                }
                else if(line.length > 0 && line[$-1] == '\\')
                {
                    firstSplicedLineStart = line.ptr;
                    spliceLineNumber = lineNumber;
                }
                else
                {
                    goto SKIP_SPLICE;
                }

                {
                    auto limit = line.ptr + line.length;
                    auto spliceLimit = limit;
                    auto spliceStart = skipWhitespace(line.ptr, limit);
                    auto parsePtr = spliceStart;
                    for(;parsePtr < limit; parsePtr++)
                    {
                        if(*parsePtr == '#')
                        {
                            spliceLimit = parsePtr;
                            break;
                        }
                    }
                    bool keepSplicing;
                    if(line.length > 0 && line[$-1] == '\\')
                    {
                        keepSplicing = true;
                        if(spliceLimit == limit)
                        {
                            spliceLimit = limit-1;
                        }
                    }
                    else
                    {
                        keepSplicing = false;
                    }

                    if(spliceLimit > spliceStart)
                    {
                        if(lineSplicer.data.length)
                        {
                            lineSplicer.put(' ');
                        }
                        lineSplicer.put(spliceStart[0..spliceLimit-spliceStart]);
                    }
                    if(keepSplicing) goto NEXT_LINE;

                    line = lineSplicer.data.idup;
                    lineSplicer.clear();
                    limit = line.ptr + line.length;
                    swap(lineNumber, spliceLineNumber);
                    parsePtr = skipWhitespace(line.ptr, limit);
                }

              SKIP_SPLICE:
                {
                    //log("[DEBUG] %s \"%s\"", lineNumber, Escaped(line));
                    auto limit = line.ptr + line.length;
                    auto parsePtr = line.ptr;
                    auto contentStart = skipWhitespace(parsePtr, limit);

                    if(currentTargets)
                    {
                        /*
                        special case: continue commands if the line is commented, i.e.

                        target: deps
                            command1
                        #   command2
                            command3
                        */
                        if(contentStart > parsePtr || (line.length > 0 && line[0] == '#'))
                        {
                            auto contentLimit = tillCommentOrLimit(contentStart, limit);
                            auto command = contentStart[0..contentLimit-contentStart].stripRight();
                            if(command.length)
                            {
                                objectAppender.put(new EngineCommand(this, command, Yes.failOnNonZeroExitCode));
                            }
                            goto NEXT_LINE;
                        }
                        addCurrentRule();
                    }
                    else
                    {
                        parsePtr = contentStart;
                    }

                    if(parsePtr >= limit|| *parsePtr == '#')
                    {
                        goto NEXT_LINE;
                    }

                    void parseMacro()
                    {
                        auto varNameLimit = contentStart;
                        for(;varNameLimit < parsePtr; varNameLimit++)
                        {
                            auto c = *varNameLimit;
                            if(!validVarNameChar(c))
                            {
                                if(parsePtr != skipWhitespace(varNameLimit, parsePtr))
                                {
                                    log("%s Error: invalid macro name \"%s\"",
                                        codeBlock.location(lineNumber),
                                        Escaped(contentStart[0..parsePtr-contentStart]));
                                    throw new MakeException();
                                }
                                break;
                            }
                        }
                        if(contentStart == varNameLimit)
                        {
                            log("%s Error: missing macro name to the left of '='",
                                codeBlock.location(lineNumber));
                            throw new MakeException();
                        }
                        auto varName = contentStart[0..varNameLimit-contentStart];
                        parsePtr++;
                        parsePtr = skipWhitespace(parsePtr, limit);
                        auto valueStart = parsePtr;
                        for(;parsePtr < limit;parsePtr++)
                        {
                            if(*parsePtr == '#') break;
                        }
                        auto value = valueStart[0..parsePtr-valueStart].stripRight;
                        //log("[DEBUG] VARNAME \"%s\" = \"%s\"", varName, value);
                        setSymbol(varName, new CodeDefinedValue(this, value));
                    }
                    void parseTargetDeps()
                    {
                        currentRuleLineNumber = lineNumber;
                        parseObjects(codeBlock, lineNumber, objectAppender, contentStart, parsePtr, Yes.parsingTargets);
                        if(objectAppender.data.length == 0)
                        {
                            log("%s Error: missing targets to the left of ':'",
                                codeBlock.location(lineNumber));
                            throw new MakeException();
                        }
                        currentTargets = objectAppender.createBuildObjectAndClear();

                        parseObjects(codeBlock, lineNumber, objectAppender, parsePtr+1, limit, No.parsingTargets);
                        currentDeps = objectAppender.createBuildObjectAndClear();
                    }
                    for(;;)
                    {
                        if(*parsePtr == '=')
                        {
                            parseMacro();
                            break;
                        }
                        if(*parsePtr == ':')
                        {
                            parseTargetDeps();
                            break;
                        }
                        parsePtr++;
                        if(parsePtr >= limit)
                        {
                            log("%s Error: expected 'MACRO =' or 'TARGETS :' but got neither",
                                codeBlock.location(lineNumber));
                            throw new MakeException();
                        }
                    }
                }

              NEXT_LINE:
                if(firstSplicedLineStart && lineSplicer.data.length == 0)
                {
                    firstSplicedLineStart = null;
                    lineNumber = spliceLineNumber;
                }
                lineNumber++;
            }

            if(currentTargets)
            {
                addCurrentRule();
            }
        }
        private void parseObjects(T)(const(CodeBlock)* codeBlock, uint lineNumber,
            T sink, immutable(char)* parsePtr, immutable char* limit, Flag!"parsingTargets" parsingTargets)
        {
            for(;;)
            {
                parsePtr = skipWhitespace(parsePtr, limit);
                if(parsePtr >= limit || *parsePtr == '#') return;
                auto start = parsePtr;
                for(;;)
                {
                    parsePtr++;
                    if(parsePtr >= limit) break;
                    char c = *parsePtr;
                    if(c == '#' || c == ' ' || c == '\t') break;
                }

                auto value = start[0..parsePtr-start];
                if(isMakeVar(value))
                {
                    if(value == "$@")
                    {
                        if(parsingTargets)
                        {
                            log("%s Error: cannot use $@ in a list of targets", codeBlock.location(lineNumber));
                            throw new MakeException();
                        }
                        sink.put(TargetsReference.instance);
                    }
                    else
                    {
                        sink.put(new UnresolvedVariable(this, value));
                    }
                }
                else
                {
                    if(value.canFind('\\'))
                    {
                        log("%s Error: values cannot contain the backslash '\\' character, use '/' file path seperators", codeBlock.location(lineNumber));
                        throw new MakeException();
                    }

                    string normalized;
                    // TODO: if it contains a '/' or '\' then I can probably assume it is a FileOrPath
                    if(checkAndNormalizePotentialFilename(&normalized, value))
                    {
                        sink.put(new FileOrPath(this, normalized));
                    }
                    else
                    {
                        sink.put(new CodeDefinedValue(this, normalized));
                    }
                }
            }
        }

        void resolveReferences()
        {
            resolveReferences(rulesAppender.data);
        }

        private void resolveReferences(MakeRule[] rules)
        {
            foreach(ref rule; rules)
            {
                rule.targets = rule.targets.resolveReferences(&rule);
                rule.targets.resolveMacros();
                if(rule.deps)
                {
                    rule.deps = rule.deps.resolveReferences(&rule);
                    rule.deps.resolveMacros();
                }
                foreach(ref command; rule.commands)
                {
                    command.getProcessed(&rule);
                }
            }
        }

        // TODO: add support for VAR=VALUE
        int run(string[] commandLineArgs)
        {
            assert(commandLineArgs.length >= 1, "commandLineArgs must have at least 1 argument");
            return runTargets(commandLineArgs[1..$]);
        }
        int runTargets(string[] targets)
        {
            BuildObject[] targetObjects;
            if(targets.length == 0)
            {
                targetObjects = null;
            }
            else
            {
                targetObjects = new BuildObject[targets.length];
                foreach(i, target; targets)
                {
                    targetObjects[i] = new UserTarget(this, target);
                }
            }
            return run(targetObjects);
        }
        int run(BuildObject[] targets = null)
        {
            auto rules = rulesAppender.data;

            try
            {
                resolveReferences(rules);

                bool builtSomething;

                if(targets.length == 0)
                {
                    if(rules.length == 0)
                    {
                        builtSomething = false;
                    }
                    else
                    {
                        //log("Making %s default target(s): %s", rules[0].targets.length, rules[0].targets);
                        builtSomething = build(rules, &rules[0]);
                    }
                }
                else
                {
                    builtSomething = false;
                    foreach(target; targets)
                    {
                        auto builtTarget = build(rules, target);
                        builtSomething = builtSomething || builtTarget;
                    }
                }
                if(!builtSomething)
                {
                    log("Nothing to build");
                }
                return 0; // success
            }
            catch(MakeException e)
            {
                //log("%s", e);
                // error already logged
                return 1; // fail
            }
        }


        // Returns: true if it built the rule
        bool build(MakeRule[] rules, BuildObject buildTarget)
        {
            bool builtSomething = false;
            foreach(singleTarget; buildTarget)
            {
                if(build(rules, singleTarget))
                {
                    builtSomething = true;
                }
            }
            return builtSomething;
        }
        bool build(MakeRule[] rules, SingleBuildObject buildTarget)
        {
            //log("[debug] build %s (type=%s)", buildTarget, typeid(buildTarget));
            SysTime modifyTime = buildTarget.targetCheck();
            if(modifyTime != SysTime.max)
            {
                return false;
            }

            // Search all rules that have this as a target
            foreach(ref rule; rules)
            {
                if(rule.targets.targetIs(buildTarget))
                {
                    return build(rules, &rule);
                }
            }
            log("Error: no rule to make %s", buildTarget.targetDescription);
            throw new MakeException();
        }


        // Returns: true if it built the rule
        bool build(MakeRule[] rules, MakeRule* rule)
        {
            bool buildThisRule = false;

            if(rule.deps)
            {
                buildThisRule = build(rules, rule.deps);
            }

            // If none of the dependencies were built, check if
            // this rule needs to be built.
            if(!buildThisRule)
            {
                // Get the oldest target
                SysTime oldestTarget = rule.targets.targetCheck();
                if(oldestTarget == SysTime.max)
                {
                    buildThisRule = true;
                }
                else
                {
                    foreach(dep; rule.deps)
                    {
                        SysTime modifyTime = dep.targetCheck();
                        if(modifyTime > oldestTarget)
                        {
                            buildThisRule = true;
                            break;
                        }
                    }
                }
            }

            if(buildThisRule)
            {
                //log("[DEBUG] building %s", rule.targets);
                foreach(ref command; rule.commands)
                {
                    command.run(rule);
                }

                // TODO: !!!!!!!!!!!!!!!!!!!!!!!!!!!
                // TODO: !!!!!!!!!!!!!!!!!!!!!!!!!!!
                // TODO: !!!!!!!!!!!!!!!!!!!!!!!!!!!
                // TODO: !!!!!!!!!!!!!!!!!!!!!!!!!!!
                // TODO: !!!!!!!!!!!!!!!!!!!!!!!!!!!
                // Check the target if it is the target type is valid like
                //       file or directory
                // Check that the commands actually built the targets
                version(CheckTargets)
                {
                    foreach(target; rule.targets)
                    {
                        target.removeTargetCheckCachedValue();
                        auto modifyTime = target.targetCheck();
                        if(modifyTime == SysTime.max)
                        {
                            log("Error: rule did not build target %s", target);
                            throw new MakeException();
                        }
                    }
                }
            }

            return buildThisRule;
        }
    }

    class EngineBuildObject : SingleBuildObject
    {
        static if(global == No.global)
        {
            MakeEngine engine;
            this(MakeEngine engine)
            {
                this.engine = engine;
            }
        }
    }
    class UnresolvedVariable : EngineBuildObject
    {
        string rawVariableReference;
        string varName;

        private enum constructorCode =
        q{
            assert(rawVariableReference[0] == '$');
            this.rawVariableReference = rawVariableReference;
            if(rawVariableReference[1] == '(')
            {
                assert(rawVariableReference[$-1] == ')');
                this.varName = rawVariableReference[2..$-1];
            }
            else
            {
                assert(rawVariableReference.length == 2);
                this.varName = rawVariableReference[1..2];
            }
        };
        static if(global == Yes.global)
        {
            this(string rawVariableReference)
            {
                mixin(constructorCode);
            }
            // This construct is only here right now
            // so I can use the same code for both types
            // of make engines to construct BuildValueObjects
            this(MakeEngine ignoreMe, string rawVariableReference)
            {
                this(rawVariableReference);
            }
        }
        else
        {
            this(MakeEngine engine, string rawVariableReference)
            {
                super(engine);
                mixin(constructorCode);
            }
        }
        final override BuildObject resolveReferences(MakeRule* ruleContext)
        {
            auto currentObject = engine.getSymbol(varName);
            if(currentObject == this)
            {
                auto newObject = new CodeDefinedValue(engine, rawVariableReference);
                engine.setSymbol(varName, newObject);
                return newObject;
            }

            // TODO: this may result in infinite recursion
            return currentObject.resolveReferences(ruleContext);
        }
        override string getRawValue()
        {
            return rawVariableReference;
        }
        override string resolveAsMacro()
        {
            assert(0, "code bug: cannot call this method on an UnresolvedVariable");
        }
        final @property string processedValue()
        {
            assert(0, "code bug: cannot call this method on an UnresolvedVariable");
        }
        override void resolveMacros()
        {
            assert(0, "code bug: cannot call this method on an UnresolvedVariable");
        }
        @property override string targetDescription()
        {
            assert(0, "code bug: cannot call this method on an UnresolvedVariable");
        }
        override SysTime targetCheckImpl()
        {
            assert(0, "code bug: cannot call this method on an UnresolvedVariable");
        }
        override bool targetIs(BuildObject other)
        {
            assert(0, "code bug: cannot call this method on an UnresolvedVariable");
        }
        override void toString(scope void delegate(const(char)[]) sink) const
        {
            sink(rawVariableReference);
        }
    }
    mixin template ValueConstructor()
    {
        static if(global == Yes.global)
        {
            this(string rawValue)
            {
                super(rawValue);
            }
            // This construct is only here right now
            // so I can use the same code for both types
            // of make engines to construct BuildValueObjects
            this(MakeEngine ignoreMe, string rawValue)
            {
                super(rawValue);
            }
        }
        else
        {
            this(MakeEngine engine, string rawValue)
            {
                super(engine, rawValue);
            }
        }
    }
    class BuildValueObject : EngineBuildObject
    {
        static if(global == Yes.global)
        {
            this(string rawValue)
            {
                this.rawValue = rawValue;
            }
        }
        else
        {
            this(MakeEngine engine, string rawValue)
            {
                super(engine);
                this.rawValue = rawValue;
            }
        }
        string rawValue;
        protected string cachedProcessedValue;
        override string getRawValue()
        {
            return rawValue;
        }
        override string resolveAsMacro()
        {
            return processedValue();
        }
        final @property string processedValue()
        {
            if(cachedProcessedValue.length == 0)
            {
                cachedProcessedValue = processRawValue();
            }
            return cachedProcessedValue;
        }
        protected abstract string processRawValue();
        override void resolveMacros()
        {
            processedValue();
        }
        override bool targetIs(BuildObject other)
        {
            // TODO: currently isn't handling '*' and other types of rules
            //import std.stdio;
            //writefln("targetIs (%s) comparing with (%s)", other.resolveAsMacro(), resolveAsMacro());
            return resolveAsMacro() == other.resolveAsMacro();
        }
        override void toString(scope void delegate(const(char)[]) sink) const
        {
            printWithQuotesIfHasSpace(rawValue, sink);
        }
    }
    class UserTarget : BuildValueObject
    {
        mixin ValueConstructor;
        final override BuildObject resolveReferences(MakeRule* ruleContext)
        {
            return this;
        }
        final protected override string processRawValue()
        {
            return engine.processUserTarget(rawValue);
        }
        @property override string targetDescription()
        {
            return processedValue();
        }
        override SysTime targetCheckImpl()
        {
            return targetCheckFile(processedValue());
        }
    }
    class CodeDefinedValue : BuildValueObject
    {
        mixin ValueConstructor;
        final override BuildObject resolveReferences(MakeRule* ruleContext)
        {
            return this;
        }
        final protected override string processRawValue()
        {
            return engine.processCodeDefinedValue(rawValue);
        }
        @property override string targetDescription()
        {
            return processedValue();
        }
        override SysTime targetCheckImpl()
        {
            return targetCheckFile(processedValue());
        }
    }
    class CommandLineValue : BuildValueObject
    {
        mixin ValueConstructor;
        final override BuildObject resolveReferences(MakeRule* ruleContext)
        {
            return this;
        }
        final protected override string processRawValue()
        {
            return engine.processCodeDefinedValue(rawValue);
        }
        @property override string targetDescription()
        {
            return processedValue();
        }
        override SysTime targetCheckImpl()
        {
            return targetCheckFile(processedValue());
        }
    }
    class GenericDlangDefine : BuildValueObject
    {
        mixin ValueConstructor;
        final override BuildObject resolveReferences(MakeRule* ruleContext)
        {
            return this;
        }
        @property override string targetDescription()
        {
            return processedValue();
        }
        final protected override string processRawValue()
        {
            return engine.processDlangDefine(rawValue);
        }
        override SysTime targetCheckImpl()
        {
            return targetCheckFile(processedValue());
        }
    }
    class NamedTarget : BuildValueObject
    {
        mixin ValueConstructor;
        final override BuildObject resolveReferences(MakeRule* ruleContext)
        {
            return this;
        }
        @property override string targetDescription()
        {
            return processedValue();
        }
        final protected override string processRawValue()
        {
            return engine.processDlangDefine(rawValue);
        }
        override SysTime targetCheckImpl()
        {
            // TODO: should this have logic to only return this once?
            return SysTime.max; // always needs to be built
        }
    }
    class FilePathCommon : BuildValueObject
    {
        mixin ValueConstructor;
        final override BuildObject resolveReferences(MakeRule* ruleContext)
        {
            return this;
        }
        final auto exists()
        {
            return std.file.exists(processedValue);
        }
        final auto dirName()
        {
            return std.path.dirName(processedValue);
        }
    }
    class FileOrPath : FilePathCommon, IFileOrPath
    {
        mixin ValueConstructor;
        @property string fileOrPathName() { return rawValue; }
        final protected override string processRawValue()
        {
            return engine.processPathName(rawValue);
        }
        @property override string targetDescription()
        {
            return processedValue();
        }
        override SysTime targetCheckImpl()
        {
            return targetCheckFile(processedValue());
        }
    }
    class FileObject : FilePathCommon, IFile
    {
        mixin ValueConstructor;
        @property string fileName() { return rawValue; }
        final protected override string processRawValue()
        {
            return engine.processFileName(rawValue);
        }
        @property override string targetDescription()
        {
            return processedValue();
        }
        override SysTime targetCheckImpl()
        {
            return targetCheckFile(processedValue());
        }
    }
    class Program : FileObject
    {
        mixin ValueConstructor;
    }
    class Path : FilePathCommon, IPath
    {
        mixin ValueConstructor;
        @property string pathName() { return rawValue; }
        final protected override string processRawValue()
        {
            return engine.processPathName(rawValue);
        }
        void createIfDoesNotExist()
        {
            if(exists())
            {
                engine.log("%s already exists", processedValue);
            }
            else
            {
                engine.log("mkdir %s", processedValue);
                std.file.mkdir(processedValue);
            }
        }
        @property override string targetDescription()
        {
            return "directory " ~ processedValue();
        }
        override SysTime targetCheckImpl()
        {
            return std.file.exists(processedValue()) ? SysTime.min : SysTime.max;
        }
    }
    class EngineCommand : Command
    {
        string raw;
        Flag!"failOnNonZeroExitCode" failOnNonZeroExitCode;
        private string processed;
        static if(global == Yes.global)
        {
            this(string raw, Flag!"failOnNonZeroExitCode" failOnNonZeroExitCode)
            {
                this.raw = raw;
                this.failOnNonZeroExitCode = failOnNonZeroExitCode;
            }
            // This construct is only here right now
            // so I can use the same code for both types
            // of make engines to construct BuildValueObjects
            this(MakeEngine ignoreMe, string raw, Flag!"failOnNonZeroExitCode" failOnNonZeroExitCode)
            {
                this.raw = raw;
                this.failOnNonZeroExitCode = failOnNonZeroExitCode;
            }
        }
        else
        {
            MakeEngine engine;
            this(MakeEngine engine, string raw, Flag!"failOnNonZeroExitCode" failOnNonZeroExitCode)
            {
                this.engine = engine;
                this.raw = raw;
                this.failOnNonZeroExitCode = failOnNonZeroExitCode;
            }
        }
        @property final override string getRaw()
        {
            return raw;
        }
        final override string getProcessed(MakeRule* ruleContext)
        {
            if(processed is null)
            {
                processed = engine.processCommand(raw, ruleContext);
            }
            return processed;
        }
        final override void run(MakeRule* rule)
        {
            //engine.log("%s", raw);
            auto processedCommandText = getProcessed(rule);
            engine.log("%s", processedCommandText);
            auto pid = spawnShell(processedCommandText);
            auto exitCode = wait(pid);
            if(failOnNonZeroExitCode && exitCode != 0)
            {
                engine.log("Error: %s failed (exit code %s)", processedCommandText.peelProgram, exitCode);
                throw new MakeException();
            }
        }
    }

    BuildObject createBuildObjectAndClear(Appender!(Object[]) objectAppender)
    {
        auto length = objectAppender.data.length;
        BuildObject result;
        if(length == 0)
        {
            result = null;
        }
        else if(length == 1)
        {
            result = cast(BuildObject) objectAppender.data[0];
        }
        else
        {
            result = new BuildObjectList((cast(BuildObject[]) objectAppender.data).dup);
        }
        objectAppender.clear();
        return result;
    }
}

SysTime targetCheckFile(string filename)
{
    return timeLastModified(filename, SysTime.max);
}

string peelProgram(string str)
{
    for(int i = 0; i < str.length; i++)
    {
        if(str[i] == ' ' || str[i] == '\t')
        {
            return str[0..i];
        }
        if(str[i] == '"')
        {
            for(;;)
            {
                i++;
                if(i >= str.length) return str;
                if(str[i] == '"')
                {
                    return str[0..i+1];
                }
            }
        }
    }
    return str;
}

void printWithQuotesIfHasSpace(const(char)[] arg, scope void delegate(const(char)[]) sink)
{
    if(arg.indexOf(' ') == -1)
    {
        sink(arg);
    }
    else
    {
        sink("\"");
        sink(arg);
        sink("\"");
    }
}
@property auto quoteIfHasSpace(const(char)[] arg)
{
    struct ToStringType
    {
        const(char)[] arg;
        void toString(scope void delegate(const(char)[]) sink) const
        {
            printWithQuotesIfHasSpace(arg, sink);
        }
    }
    return ToStringType(arg);
}
struct MacroNameFormat
{
    const(char)[] macroName;
    void toString(scope void delegate(const(char)[]) sink) const
    {
        if(macroName.length == 1)
        {
            sink("$");
            sink(macroName);
        }
        else
        {
            sink("$(");
            sink(macroName);
            sink(")");
        }
    }
}
struct ShortString(size_t maxLength = 15)
{
    const(char)[] str;
    void toString(scope void delegate(const(char)[]) sink) const
    {
        if(str.length <= maxLength)
        {
            sink(str);
        }
        else
        {
            sink(str[0..maxLength-3]);
            sink("...");
        }
    }
}
char hexchar(ubyte b) in { assert(b <= 0x0F); } body
{
    return cast(char)(b + ((b <= 9) ? '0' : ('A'-10)));
}
struct Escaped
{
    const(char)* str;
    const char* limit;
    this(const(char)[] str)
    {
        this.str = str.ptr;
        this.limit = str.ptr + str.length;
    }
    void toString(scope void delegate(const(char)[]) sink) const
    {
        const(char) *print = str;
        const(char) *ptr = str;
      CHUNK_LOOP:
        for(;ptr < limit;ptr++)
        {
            char c = *ptr;
            if(c < ' ' || c > '~') // if not human readable
            {
                if(ptr > print)
                {
                    sink(print[0..ptr-print]);
                }
                if(c == '\r') sink("\\r");
                else if(c == '\t') sink("\\t");
                else if(c == '\n') sink("\\n");
                else {
                    char[4] buffer;
                    buffer[0] = '\\';
                    buffer[1] = 'x';
                    buffer[2] = hexchar(c>>4);
                    buffer[3] = hexchar(c&0xF);
                    sink(buffer);
                }
                print = ptr + 1;
            }
        }
        if(ptr > print)
        {
            sink(print[0..ptr-print]);
        }
    }
}

string readFile(const(char)[] filename)
{
    std.stdio.File file = std.stdio.File(filename, "rb");
    auto filesize = file.size();
    if(filesize+1 > size_t.max)
    {
        assert(0, text(filename, ": file is too large ", filesize, " > ", size_t.max));
    }
    auto contents = new char[cast(size_t)(filesize+1)]; // add 1 for '\0'
    auto readSize = file.rawRead(contents).length;
    assert(filesize == readSize, text("rawRead only read ", readSize, " bytes of ", filesize, " byte file"));
    contents[cast(size_t)filesize] = '\0';
    return cast(string)contents[0..$-1];
}