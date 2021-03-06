# Run this makefile from the Nim repo root.

nim = nim
testcase = r --mm:arc t.nim
nim_debug_opts = \
	--import:$(PWD)/.debug/debug.nim \
	--warning:UnusedImport:off \
	--hint:XDeclaredButNotUsed:off \
	--styleCheck:off \
	-d:nimDebug --debugger:native -d:nimDebugUtils -d:debug \
	-d:leanCompiler -d:nimDebugUtils -d:stacktraceMsgs -d:nimCompilerStacktraceHints
nim_fast_opts = \
	-d:danger --stacktrace:off --panics:on --passC:"-flto -march=native" --passL:"-flto"

bin/nim_temp: FORCE
	$(nim) c --out:$(@) $(nim_debug_opts) compiler/nim

bin/nim_fast: FORCE
	$(nim) c --out:$(@) $(nim_fast_opts) compiler/nim

bin/nim_memtest: FORCE
	$(nim) c --out:$(@) -d:leanCompiler --debugger:native -d:useMalloc --stacktrace:on -d:release compiler/nim

bin/nim_callgrind: FORCE
	$(nim) c --out:$(@) -d:leanCompiler --debugger:native --stacktrace:on -d:release compiler/nim

nimcache/nim.memtest.log: bin/nim_memtest
	valgrind --suppressions=.debug/memtest.supp --log-file=$(@) bin/nim_memtest $(testcase)

nimcache/nim.callgrind.log: bin/nim_callgrind
	valgrind --tool=callgrind --callgrind-out-file=$(@) bin/nim_callgrind $(testcase)
	callgrind_annotate --auto=yes $(@)

nimcache/nim.callgrind.svg: nimcachenimcache/nim.callgrind.log
	gprof2dot -f callgrind nimcache/nim.callgrind | dot -Tsvg -o $(@)
	echo "$(PWD)/nimcache/nim.callgrind.svg"

nim_gdb.so: nim_gdb.nim
	nim c --app:lib --threads:on --out:$(@) nim_gdb.nim

.vscode:
	mkdir -p .vscode; cd .vscode && \
	ln -sf ../.debug/vscode/* .

config.nims:
	ln -s .debug/nim_$(@) $(@)

.PHONEY: FORCE memtest callgrind prepare
FORCE:
memtest: nimcache/nim.memtest.log
callgrind: nimcache/nim.callgrind.log

# Link and patch some files to make using these tools easier.
prepare: .vscode config.nims
