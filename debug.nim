import pkg/debug
export debug

proc enteringDebugSection*() {.exportc, dynlib.} =
  ## Provides a way for native debuggers to enable breakpoints, watchpoints, etc
  ## when code of interest is being compiled.
  ## 
  ## Set your debugger to break on entering `nimCompilerIsEnteringDebugSection`
  ## and then execute a desired command.
  discard

proc exitingDebugSection*() {.exportc, dynlib.} =
  ## Provides a way for native debuggers to disable breakpoints, watchpoints, etc
  ## when code of interest is no longer being compiled.
  ## 
  ## Set your debugger to break on entering `exitingDebugSection`
  ## and then execute a desired command.
  discard

from std/os import splitFile, getEnv
from std/strutils import parseInt
var debuggeeTarget* {.exportc, dynlib.} = getEnv("NIM_DEBUGGEE")
  ## module name that we want to debug the compilation of
var debuggeeTargetLine* {.exportc, dynlib.} = getEnv("NIM_DEBUGGEE_LINE", "1").parseInt()
  ## module line that we want to debug the compilation of
