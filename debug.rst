=========================================
    Internals of the Nim Compiler
=========================================


:Author: Andreas Rumpf
:Version: |nimversion|

.. default-role:: code

Debugging the compiler
======================


Bisecting for regressions
-------------------------

There are often times when there is a bug that is caused by a regression in the
compiler or stdlib. Bisecting the Nim repo commits is a usefull tool to identify
what commit introduced the regression.

Even if it's not known whether a bug is caused by a regression, bisection can reduce
debugging time by ruling it out. If the bug is found to be a regression, then you
focus on the changes introduced by that one specific commit.

`koch temp`:cmd: returns 125 as the exit code in case the compiler
compilation fails. This exit code tells `git bisect`:cmd: to skip the
current commit:

.. code:: cmd

  git bisect start bad-commit good-commit
  git bisect run ./koch temp -r c test-source.nim

You can also bisect using custom options to build the compiler, for example if
you don't need a debug version of the compiler (which runs slower), you can replace
`./koch temp`:cmd: by explicit compilation command, see `Bootstrapping the compiler`_.


Building an instrumented compiler
---------------------------------

Considering that a useful method of debugging the compiler is inserting debug
logging, or changing code and then observing the outcome of a testcase, it is
fastest to build a compiler that is instrumented for debugging from an
existing release build. `koch temp`:cmd: provides a convenient method of doing
just that.

By default running `koch temp`:cmd: will build a lean version of the compiler
with `-d:debug`:option: enabled. The compiler is written to `bin/nim_temp` by
default. A lean version of the compiler lacks JS and documentation generation.

`bin/nim_temp` can be directly used to run testcases, or used with testament
with `testament --nim:bin/nim_temp r tests/category/tsometest`:cmd:.

`koch temp`:cmd: will build the temporary compiler with the `-d:debug`:option:
enabled. Here are compiler options that are of interest for debugging:

* `-d:debug`:option:\: enables `assert` statements and stacktraces and all
  runtime checks
* `--opt:speed`:option:\: build with optimizations enabled
* `--debugger:native`:option:\: enables `--debuginfo --lineDir:on`:option: for using
  a native debugger like GDB, LLDB or CDB
* `-d:nimDebug`:option: cause calls to `quit` to raise an assertion exception
* `-d:nimDebugUtils`:option:\: enables various debugging utilities;
  see `compiler/debugutils`
* `-d:stacktraceMsgs -d:nimCompilerStacktraceHints`:option:\: adds some additional
  stacktrace hints; see https://github.com/nim-lang/Nim/pull/13351
* `-u:leanCompiler`:option:\: enable JS and doc generation

Another method to build and run the compiler is directly through `koch`:cmd:\:

.. code:: cmd

  koch temp [options] c test.nim

  # (will build with js support)
  koch temp [options] js test.nim

  # (will build with doc support)
  koch temp [options] doc test.nim

Debug logging
-------------

"Printf debugging" is still the most appropriate way to debug many problems
arising in compiler development. The typical usage of breakpoints to debug
the code is often less practical, because almost all of the code paths in the
compiler will be executed hundreds of times before a particular section of the
tested program is reached where the newly developed code must be activated.

To work-around this problem, you'll typically introduce an if statement in the
compiler code detecting more precisely the conditions where the tested feature
is being used. One very common way to achieve this is to use the `mdbg` condition,
which will be true only in contexts, processing expressions and statements from
the currently compiled main module:

.. code-block:: nim

  # inside some compiler module
  if mdbg:
    debug someAstNode

Using the `isCompilerDebug`:nim: condition along with inserting some statements
into the testcase provides more granular logging:

.. code-block:: nim

  # compilermodule.nim
  if isCompilerDebug():
    debug someAstNode

  # testcase.nim
  proc main =
    {.define(nimCompilerDebug).}
    let a = 2.5 * 3
    {.undef(nimCompilerDebug).}

Logging can also be scoped to a specific filename as well. This will of course
match against every module with that name.

.. code-block:: nim

  if `??`(conf, n.info, "module.nim"):
    debug(n)

The above examples also makes use of the `debug`:nim: proc, which is able to
print a human-readable form of an arbitrary AST tree. Other common ways to print
information about the internal compiler types include:

.. code-block:: nim

  # pretty print PNode

  # pretty prints the Nim ast
  echo renderTree(someNode)

  # pretty prints the Nim ast, but annotates symbol IDs
  echo renderTree(someNode, {renderIds})

  # pretty print ast as JSON
  debug(someNode)

  # print as YAML
  echo treeToYaml(config, someNode)


  # pretty print PType

  # print type name
  echo typeToString(someType)

  # pretty print as JSON
  debug(someType)

  # print as YAML
  echo typeToYaml(config, someType)


  # pretty print PSym

  # print the symbol's name
  echo symbol.name.s

  # pretty print as JSON
  debug(symbol)

  # print as YAML
  echo symToYaml(config, symbol)


  # pretty print TLineInfo
  lineInfoToStr(lineInfo)


  # print the structure of any type
  repr(someVar)

Here are some other helpful utilities:

.. code-block:: nim

  # how did execution reach this location?
  writeStackTrace()

These procs may not already be imported by the module you're editing.
You can import them directly for debugging:

.. code-block:: nim

  from astalgo import debug
  from types import typeToString
  from renderer import renderTree
  from msgs import `??`

Native debugging
----------------

Stepping through the compiler with a native debugger is a very powerful tool to
both learn and debug it. However, there is still the need to constrain when
breakpoints are triggered. The same methods as in `Debug logging`_ can be applied
here when combined with calls to the debug helpers `enteringDebugSection()`:nim:
and `exitingDebugSection()`:nim:.

#. Compile the temp compiler with `--debugger:native -d:nimDebugUtils`:option:
#. Set your desired breakpoints or watchpoints.
#. Configure your debugger:
  * GDB: execute `source tools/compiler.gdb` at startup
  * LLDB execute `command source tools/compiler.lldb` at startup
#. Use one of the scoping helpers like so:

.. code-block:: nim

  if isCompilerDebug():
    enteringDebugSection()
  else:
    exitingDebugSection()

A caveat of this method is that all breakpoints and watchpoints are enabled or
disabled. Also, due to a bug, only breakpoints can be constrained for LLDB.
