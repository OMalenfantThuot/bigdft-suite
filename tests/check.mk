# Generic part, of the testing Makefiles.
# Possible calls are:
#  make in: generate all input dirs.
#  make failed-check: run check again on all directories with missing report
#                     or failed report.
#  make X.in: generate input dir for directory X.
#  make X.check: generate a report for directory X (if not already existing).
#  make X.recheck: force the creation of the report in directory X.
#  make X.clean: clean the given directory X.
#  make X.diff: make the difference between the output and the reference (with DIFF envvar)
#  make X.updateref: update the reference with the output (prompt the overwrite)

if USE_MPI
  mpirun_message = mpirun
else
  mpirun_message =
endif
if USE_OCL
oclrun_message = oclrun
accel_in_message = in_message
else
oclrun_message =
accel_in_message =
endif

if BUILD_LIBYAML
LD_LIBRARY_PATH := ${LD_LIBRARY_PATH}:$(abs_top_builddir)/yaml-0.1.4/src/.libs
PYTHONPATH := ${PYTHONPATH}:`ls -d $(abs_top_builddir)/PyYAML-3.10/build/lib.*`
endif

AM_FCFLAGS = -I$(top_builddir)/src -I$(top_builddir)/src/PSolver -I$(top_builddir)/src/modules @LIBABINIT_INCLUDE@ @LIBXC_INCLUDE@

PSPS = psppar.H \
       psppar.C \
       psppar.Li \
       psppar.Ca \
       psppar.Mn \
       psppar.N \
       psppar.Si \
       HGH/psppar.H \
       HGH/psppar.Na \
       HGH/psppar.Cl \
       HGH/psppar.O \
       HGH/psppar.Si \
       HGH/psppar.Fe \
       HGH/psppar.Mg \
       HGH/psppar.Ag \
       HGH/psppar.N \
       HGH/psppar.C \
       HGH-K/psppar.H \
       HGH-K/psppar.Si \
       HGH-K/psppar.N \
       HGH-K/psppar.O \
       HGH-K/psppar.Ti \
       extra/psppar.H \
       Xabs/psppar.Fe

INS = $(TESTDIRS:=.in)
RUNS = $(TESTDIRS:=.run)
CHECKS = $(TESTDIRS:=.check) $(TESTDIRS:=.yaml-check)
DIFFS = $(TESTDIRS:=.diff)
UPDATES = $(TESTDIRS:=.updateref)
FAILEDCHECKS = $(TESTDIRS:=.recheck)
CLEANS = $(TESTDIRS:=.clean)

in: $(INS)

check: $(CHECKS) report

diff: $(DIFFS)

update-references: $(UPDATES)

clean: $(CLEANS)

distclean: $(CLEANS)
	rm -rf Makefile

failed-check: $(FAILEDCHECKS) report

report:
	@if test $(MAKELEVEL) = 0 ; then	export PYTHONPATH=${PYTHONPATH}; export LD_LIBRARY_PATH=${LD_LIBRARY_PATH} ;python $(top_srcdir)/tests/report.py ; fi

%.memguess.out: $(abs_top_builddir)/src/memguess $(abs_top_builddir)/src/bigdft-tool
	$(abs_top_builddir)/src/bigdft-tool -n 1 > $@
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.out.out: $(abs_top_builddir)/src/bigdft
	@name=`basename $@ .out.out | sed "s/[^_]*_\?\(.*\)$$/\1/"` ; \
	if test -n "$$name" ; then file=$$name.perf ; else file=input.perf ; fi ; \
	if test -f accel.perf && ! grep -qs ACCEL $$file ; then \
	   if test -f $$file ; then cp $$file $$file.bak ; fi ; \
	   cat accel.perf >> $$file ; \
	fi ; \
	echo outdir ./ >> $$file ; \
	$(run_parallel) $(abs_top_builddir)/src/bigdft $$name > $@ ; \
	if test -f $$file.bak ; then mv $$file.bak $$file ; else rm -f $$file ; fi
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.geopt.mon.out: $(abs_top_builddir)/src/bigdft
	$(MAKE) -f ../Makefile $*.out.out && mv geopt.mon $@
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.dipole.dat.out: %.out.out
	$(run_parallel) $(abs_top_builddir)/src/tools/bader/bader data/electronic_density.cube > bader.out && mv dipole.dat $@
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.freq.out: $(abs_top_builddir)/src/frequencies
	name=`basename $@ .freq.out | sed "s/[^_]*_\?\(.*\)$$/\1/"` ; \
	if test -n "$$name" ; then file=$$name.perf ; else file=input.perf ; fi ; \
	if test -f accel.perf && ! grep -qs ACCEL $$file ; then \
	   if test -f $$file ; then cp $$file $$file.bak ; fi ; \
	   cat accel.perf >> $$file ; \
	fi ; \
	echo outdir ./ >> $$file ; \
	$(run_parallel) $(abs_top_builddir)/src/frequencies > $@
	if test -f $$file.bak ; then mv $$file.bak $$file ; else rm -f $$file ; fi ;\
	name=`basename $@ .freq.out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.NEB.out: $(abs_top_builddir)/src/NEB NEB_include.sh NEB_driver.sh
	rm -f triH.NEB.it*
	$(abs_top_builddir)/src/NEB < input | tee $@
	cat triH.NEB.0*/log.yaml > log.yaml
	rm -rf triH.NEB.0*
	rm -f gen_output_file velocities_file
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.splsad.out: $(abs_top_builddir)/src/splsad
	$(run_parallel) $(abs_top_builddir)/src/splsad > $@
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.minhop.out: $(abs_top_builddir)/src/global
	$(run_parallel) $(abs_top_builddir)/src/global > $@
	mv log-mdinput.yaml log.yaml
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.xabs.out: $(abs_top_builddir)/src/abscalc
	name=`basename $@ .xabs.out` ; \
	$(abs_top_builddir)/src/abscalc $$name > $@
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"
%.b2w.out: $(abs_top_builddir)/src/BigDFT2Wannier
	$(run_parallel) $(abs_top_builddir)/src/bigdft $$name > $@
	$(run_parallel) $(abs_top_builddir)/src/BigDFT2Wannier $$name > $@
	name=`basename $@ .out` ; \
	$(MAKE) -f ../Makefile $$name".post-out"

$(PSPS):
	ln -fs $(abs_top_srcdir)/utils/PSPfiles/$@ 

%.clean:
	@dir=`basename $@ .clean` ; \
	rm -f $$dir.* ; \
    if test x"$(srcdir)" = x"." ; then \
	   cd $$dir ; \
	   for i in psppar.* ; do \
	       if test -L $i ; then \
	          rm -f $i ; \
	       fi ; \
	   done ; \
       rm -f *.out *.mon *.report default* *.prc; \
	   rm -fr data data-*; rm -f accel.perf; \
	   rm -f velocities.xyz pdos.dat td_spectra.txt ; \
	   rm -f bfgs_eigenvalues.dat frequencies.res frequencies.xyz hessian.dat ; \
	   rm -f *.NEB.dat *.NEB.int *.NEB.restart *.NEB.log ; \
	   rm -f electronic_density.cube ACF.dat AVF.dat BCF.dat ; \
	   rm -f anchorpoints* fort.* nogt.* path*.xyz vogt.* ; \
	   rm -f latest.pos.force.*.dat fort.* CPUlimit test ; \
	   rm -f cheb_spectra_* alphabeta* b2B_xanes.* local_potentialb2B* ; \
	   $(MAKE) -f ../Makefile $$dir".post-clean"; \
    else \
       rm -rf $$dir ; \
    fi ; \
    echo "Clean in "$$dir

%.post-in: ;
%.psp: ;
%.post-clean: ;
%.post-out: ;

in_message:
	@if test -n "$(run_ocl)" ; then \
	  echo "==============================================" ; \
	  echo "Will generate a 'input.perf' file to force OCL" ; \
	  echo "==============================================" ; \
	fi

$(INS): in_message
	@dir=`basename $@ .in` ; \
        if ! test x"$(srcdir)" = x"." ; then \
          if [ ! -d $$dir ] ; then mkdir $$dir ; fi ; \
          for i in $(srcdir)/$$dir/* ; do cp -f $$i $$dir; done ; \
        fi ; \
	if test -n "$(accel_in_message)" -a -n "$(run_ocl)" ; then \
	  echo "ACCEL OCLGPU" > $$dir/accel.perf ; \
	fi ; \
        cd $$dir && $(MAKE) -f ../Makefile $$dir".psp"; \
        $(MAKE) -f ../Makefile $$dir".post-in"; \
        echo "Input prepared in "$$dir" dir. make $$dir.run available"
	touch $@

run_message:
	@if test -n "$(run_parallel)" ; then \
	  echo "==============================================" ; \
	  echo "Will run tests in parallel with '$$run_parallel'" ; \
	  echo "==============================================" ; \
	fi

%.run: %.in run_message
	@dir=`basename $@ .run` ; \
        runs="$(srcdir)/$$dir/*.ref" ; \
	tgts=`for r in $$runs ; do echo $$(basename $$r .ref)".out"; done` ; \
        cd $$dir && $(MAKE) -f ../Makefile $$tgts ; \
        echo "Tests have run in "$$dir" dir. make $$dir.check available"
	touch $@

%.check: %.run %.yaml-check
	@dir=`basename $@ .check` ; \
        chks="$(srcdir)/$$dir/*.ref" ; \
	tgts=`for c in $$chks ; do echo $$(basename $$c .ref)".report"; done` ; \
        cd $$dir && $(MAKE) -f ../Makefile $$tgts
	touch $@

%.yaml-check: %.run
	@dir=`basename $@ .yaml-check` ; \
        chks="$(srcdir)/$$dir/*.ref.yaml" ; \
	tgts=`for c in $$chks ; do echo $$(basename $$c .ref.yaml)".report.yaml"; done` ; \
        cd $$dir && $(MAKE) -f ../Makefile $$tgts
	touch $@


%.diff: %.run
	@dir=`basename $@ .diff` ; \
        chks="$(srcdir)/$$dir/*.ref" ; \
	for c in $$chks ; do $$DIFF $$c $$dir/$$(basename $$c .ref)".out";\
	done ; \
        ychks="$(srcdir)/$$dir/*.ref.yaml" ; \
	for c in $$ychks ; do name=`basename $$c .out.ref.yaml | sed "s/[^_]*_\?\(.*\)$$/\1/"`  ;\
	if test -n "$$name" ; then \
	$$DIFF $$c $$dir/log-$$name.yaml;\
	else \
	$$DIFF $$c $$dir/log.yaml;\
	fi ;\
	done ; \
	touch $@

%.updateref: #%.run %.diff
	@dir=`basename $@ .updateref` ; \
        chks="$(srcdir)/$$dir/*.ref" ; \
	for c in $$chks ; do echo "Update reference with " $$dir/$$(basename $$c .ref)".out"; \
	                     cp -vi $$dir/$$(basename $$c .ref)".out"  $$c;\
	done ; \
        ychks="$(srcdir)/$$dir/*.ref.yaml" ; \
	for c in $$ychks ; do name=`basename $$c .out.ref.yaml | sed "s/[^_]*_\?\(.*\)$$/\1/"`  ;\
	if test -n "$$name" ; then \
	echo "Update reference with " $$dir/log-$$name.yaml; \
	                     cp -vi $$dir/log-$$name.yaml $$c;\
	else \
	echo "Update reference with " $$dir/log.yaml; \
	                     cp -vi $$dir/log.yaml $$c;\
	fi ;\
	done ; \
	touch $@

%.recheck: %.in
	@dir=`basename $@ .recheck` ; \
        refs="$$dir/*.ref" ; \
	for r in $$refs ; do \
	  rep=`basename $$r .ref`".report" ; \
	  if ! grep -qs "succeeded\|passed" $$dir/$$rep ; then \
	    target=` basename $$r .ref` ; \
	    rm -f $$dir/$$target".out" $$dir/$$target".report" ; \
	    cd $$dir && $(MAKE) -f ../Makefile $$target".out" $$target".report" && cd - ; \
	  fi \
	done
	touch $*".check"

# Avoid copying in dist the builddir files.
distdir: $(DISTFILES)
	@srcdirstrip=`echo "$(srcdir)" | sed 's/[].[^$$\\*]/\\\\&/g'`; \
	topsrcdirstrip=`echo "$(top_srcdir)" | sed 's/[].[^$$\\*]/\\\\&/g'`; \
	list='$(DISTFILES)'; \
	  dist_files=`for file in $$list; do echo $$file; done | \
	  sed -e "s|^$$srcdirstrip/||;t" \
	      -e "s|^$$topsrcdirstrip/|$(top_builddir)/|;t"`; \
	case $$dist_files in \
	  */*) $(MKDIR_P) `echo "$$dist_files" | \
			   sed '/\//!d;s|^|$(distdir)/|;s,/[^/]*$$,,' | \
			   sort -u` ;; \
	esac; \
	for file in $$dist_files; do \
	  d=$(srcdir); \
	  if test -d $$d/$$file; then \
	    dir=`echo "/$$file" | sed -e 's,/[^/]*$$,,'`; \
	    if test -d "$(distdir)/$$file"; then \
	      find "$(distdir)/$$file" -type d ! -perm -700 -exec chmod u+rwx {} \;; \
	    fi; \
	    if test -d $(srcdir)/$$file && test $$d != $(srcdir); then \
	      cp -fpR $(srcdir)/$$file "$(distdir)$$dir" || exit 1; \
	      find "$(distdir)/$$file" -type d ! -perm -700 -exec chmod u+rwx {} \;; \
	    fi; \
	    cp -fpR $$d/$$file "$(distdir)$$dir" || exit 1; \
	  else \
	    test -f "$(distdir)/$$file" \
	    || cp -p $$d/$$file "$(distdir)/$$file" \
	    || exit 1; \
	  fi; \
	done

# Doc messages.
all:
	@if test $(MAKELEVEL) = 0 ; then $(MAKE) foot_message ; fi

head_message:
	@echo "========================================================="
	@echo " This is a directory for tests. Beside the 'make check'"
	@echo " one can use the following commands:"
	@echo "  make in:           generate all input dirs."
	@echo "  make failed-check: run check again on all directories"
	@echo "                     with missing report or failed report."
	@echo "  make X.in:         generate input dir for directory X."
	@echo "  make X.check:      generate a report for directory X"
	@echo "                     (if not already existing)."
	@echo "  make X.recheck:    force the creation of the report in"
	@echo "                     directory X."
	@echo "  make X.clean:      clean the given directroy X."
	@echo "  make X.diff:       make the difference between output"
	@echo "                     and the reference (with DIFF envvar)"
	@echo "  make X.updateref   update the reference with the output"
	@echo "                     (prompt the overwrite)"	

mpirun: head_message
	@echo ""
	@echo " Use the environment variable run_parallel"
	@echo "     ex: export run_parallel='mpirun -np 2'  "

oclrun: head_message $(mpirun_message)
	@echo ""
	@echo " Use the environment variable run_ocl"
	@echo "     ex: export run_ocl='on' to use OpenCL acceleration"

foot_message: $(mpirun_message) $(oclrun_message) head_message
	@echo "========================================================="

