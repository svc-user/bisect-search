# bisect-search
grep-like utility for use with `git bisect run` that sets the correct exit codes for git bisect to pick up.

## What it solves

From the [git bisect run](https://git-scm.com/docs/git-bisect#_bisect_run) documentation we can see that the `run` subcommand expects a return code indicating wether a commit is bad/new or good/old.

For powershell on windows this is not straightforward to set the exit code correctly using scripts, so I made a binary, which works much better with git 🤷‍♂️

## How to use

`bisect-search` is simply a tool that opens a file, searches for a string and sets exit code 0/1/125/255 depending on whether there's a match, the file is missing or something went wrong.

Running `bisect-search.exe` with no arguments prints the help
```
----------------------------------------------------------------
Search a file for a string and set a return code for git bisect.
----------------------------------------------------------------
        --inverse, -i    Inverse the exit code so that a match indicates a bad/newer commit.
                (default: false)
        --verbose        Print debug output when executed.
                (default: false)
        --file, -f <string value>        Relative or absolute path of file to search in.
        --string, -s <string value>      String to search for in the given file.
```

To use it with `git bisect` simply run `git bisect run .\bisect-search.exe -f .\my-changed-file.zig -s "string to search for"`.

## Return codes
 * If the search string is found return **0** (good/old commit). If `--inverse` is set returns **1** (bad/new commit).
 * Is the file not found `bisect-search` returns **125** which tells git to skip the commit.
 * If something goes wrong a return code **255** is set, aborting `git bisect run`.