from __future__ import print_function
# You can register a handler that will be called when a symlink
# Can't be created or deleted.
def handle_autobuild_error(input_path, exception):
    pass

def project_builder(project):
    """
    Build the project indicated by the input.
    A temporary directory is created next to the source directory
    of the project, therefore the builder should have writing permission to it.
    """
    from sphinx_multibuild import SphinxMultiBuilder
    from os import path as p
    projpath=p.abspath(project)
    source=p.join(projpath,'source')
    tmp=p.join(projpath,'tmp')
    build=p.join(projpath,'build')
    print('Creating builder for package: ',project)
    # Instantiate multi builder. The last two params are optional.
    return SphinxMultiBuilder(# input directories
        [source],
        # Temp directory where symlinks are placed.
        tmp,
        # Output directory
        build,
        # Sphinx arguments, this doesn't include the in-
        # and output directory and filenames argments.
        ["-M", "html", "-c", source],
        # Specific files to build(optional).
        #["index.rst"],
        # Callback that will be called when symlinking
        # error occurs during autobuilding. (optional)
        #handle_autobuild_error
        )


if __name__=='__main__':
	import logging
	import time
	import sys,os
	
	# Package respects loglevel set by application. Info prints out change events
	# in input directories and warning prints exception that occur during symlink
	# creation/deletion.
	loglevel = logging.INFO
	logging.basicConfig(format='%(message)s', level=loglevel)
	
	
	builder = build_project('futile')
	# build once
	builder.build()
	
	# start autobuilding on change in any input directory until ctrl+c is pressed.
	builder.start_autobuilding()
	try:
	    while True:
	        time.sleep(1)
	except KeyboardInterrupt:
	    builder.stop_autobuilding()
	
	# return the last exit code sphinx build returned had as program exit code.
	sys.exit(builder.get_last_exit_code())
	
