dmake
================================================================================
A Make engine for the D Programming Language.  Supports configuration via D code
or Make code.

### Requirements
The D programming language compiler.  It requires that `rdmd` is in your path.

### Usage

Create the file `make.d`, then run `dmake`.

### Installation: Windows

Create the file "dmake.bat" somewhere in your PATH and copy the following to it:
```
@rdmd -I<path-to-dmake-library> make.d %*
```
If `<path-to-dmake-library>` is in the same location as dmake.bat, you can use:
```
@rdmd -I%~dp0 make.d %*
```

### Installation: Linux, OSx, etc.

Create the file "dmake" somwhere in your PATH and add this to it:
```
#!/bin/bash
rdmd -I<path-to-dmake-library> make.d $@
```
also make sure the file is executable, i.e. `chmod +x dmake`


### No Install

dmake can also be invoked directly with no installation like this:
```
> rdmd -I<path-to-dmake-library> make.d <args>...
```


#### Example
```D
import dmakelib;

void main(string[] args)
{
    declare("DCOMPILER", program("dmd"));

    addRule(exe("helloWorld"), file("helloWorld.d"), [
        shell("$(DCOMPILER) helloWorld.d")
    ]);

    addRule(target("clean"), null, [
        //remove("*.exe", "*.obj"),
        shell("del *.exe *.obj"),
    ]);

    run(args);
}
```

Every dmake file imports `dmakelib`.

> Note: you can also create/run multiple make engines using a LocalMakeEngine.

#### More Information

The make features and syntax is based off the Digital Mars
[MAKE](http://www.digitalmars.com/ctg/make.html) program.

Extra Features:
* supports forward references
