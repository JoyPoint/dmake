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