#!/usr/bin/env python



BIGDFT_CFG='BIGDFT_CONFIGURE_FLAGS'
CLEAN=' clean '
CLEANONE=' cleanone '
UNINSTALL=' uninstall '
LIST=' list '
BUILD=' build '
TINDERBOX=' tinderbox -o build '
DOT=' dot | dot -Tpng > buildprocedure.png '
DIST=' distone bigdft-suite '
RCFILE='buildrc'

CHECKMODULES= ['flib','bigdft']
MAKEMODULES= ['flib','libABINIT','bigdft']

#allowed actions and corresponfing description
ACTIONS={'build':
         'Compiles and install the code with the given configuration',
         'make':
         'Recompiles the bigdft internal branches, skip configuring step',
         'clean':
         'Clean the branches for a fresh reinstall',
         'autogen':
         'Perform the autogen in the modules which need that. For developers only',
         'dist':
         'Creates a tarfile for the bigdft-suite tailored to reproduce the compilation options specified',
         'check':
         'Perform check in the bigdft branches, skip external libraries',
         'dry_run':
         'Visualize the list of modules that will be compiled with the provided configuration in the buildprocedure.png file'}


class BigDFTInstaller():
    def __init__(self,action,rcfile,verbose):
        import os
        self.action=action
        self.verbose=verbose
        #look where we are
        self.srcdir = os.path.dirname(__file__)
        #look the builddir
        self.builddir=os.getcwd()
        #look if we are building from a branch
        bigdftdir=os.path.join(self.srcdir,'bigdft')
        self.branch=os.path.isfile(os.path.join(bigdftdir,'branchfile'))
        
        if os.path.abspath(self.srcdir) == os.path.abspath(self.builddir):
            print 50*'-'
            print "ERROR: BigDFT Installer works better with a build directory different from the source directory, install from another directory"
            print "SOLUTION: Create a separate directory and invoke this script from it"
            print 50*'-'
            exit(1)
        #hostname
        self.hostname=os.uname()[1]

        #rcfile
        self.get_rcfile(rcfile)
        
        #jhbuild script
        self.jhb=os.path.join(self.srcdir,'jhbuild.py ')
        if self.rcfile != '': self.jhb += '-f '+self.rcfile

        self.print_present_configuration()
                            
        #now get the list of modules that has to be treated with the given command
        self.modulelist=self.get_output(self.jhb + LIST).split('\n')
        print " List of modules to be treated:",self.modulelist
        
        #then choose the actions to be taken
        getattr(self,action)()


    def get_rcfile(self,rcfile):
        import os
        #determine the rcfile
        if rcfile is not None:
            self.rcfile=rcfile
        else:
            self.rcfile=RCFILE
        #see if it exists where specified
        if os.path.exists(self.rcfile): return
        #otherwise search again in the rcfiles
        rcdir=os.path.join(self.srcdir,'rcfiles')
        self.rcfile=os.path.join(rcdir,self.rcfile)
        if os.path.exists(self.rcfile): return
        #see if the environment variables BIGDFT_CFG is present
        self.rcfile = ''
        if BIGDFT_CFG in os.environ.keys(): return
        #otherwise search for rcfiles similar to hostname and propose a choice
        rcs=[]
        for file in os.listdir(rcdir):
            testname=os.path.basename(file)
            base=os.path.splitext(testname)[0]
            if base in self.hostname or self.hostname in base: rcs.append(file)
        if len(rcs)==1:
            self.rcfile=os.path.join(rcdir,rcs[0])
        elif len(rcs) > 0:
            print 'No valid configuration file specified, found various that matches the hostname'
            print 'In the directory "'+rcdir+'"'
            print 'Choose among the following options'
            for i,rc in enumerate(rcs):
                print str(i+1)+'. '+rc
            while True:
                choice=raw_input('Pick your choice (q to quit) ')
                if choice == 'q': exit(0)
                try:
                    ival=int(choice)
                    if (ival <= 0): raise
                    ch=rcs[ival-1]
                    break
                except:
                    print 'The choice must be a valid integer among the above'                  
            self.rcfile=os.path.join(rcdir,ch)
        elif len(rcs) == 0:
            print 'No valid configuration file provided and '+BIGDFT_CFG+' variable not present, exiting...'
            exit(1)
        
    def __dump(self,*msg):
        if self.verbose:
            for m in msg:
                print m

    def print_present_configuration(self):
        import  os
        print 'Configuration chosen for the Installer:'
        print ' Hostname:',self.hostname
        print ' Source directory:',os.path.abspath(self.srcdir)
        print ' Compiling from a branch:',self.branch
        print ' Build directory:',os.path.abspath(self.builddir)
        print ' Action chosen:',self.action
        print ' Verbose:',self.verbose
        print ' Configuration options:'
        if self.rcfile=='':
            print '  Source: Environment variable "'+BIGDFT_CFG+'"'
	    print '  Value:'+os.environ[BIGDFT_CFG]
        else:
            print '  Source: Configuration file "'+os.path.abspath(self.rcfile)+'"'
        while True:
            ok = raw_input('Do you want to continue (y/n)? ')
            if ok == 'n' or ok=='N':
                exit(0)
            elif ok != 'y' and ok != 'Y':
                print 'Please answer y or n'
            else:
                break
                
    def selected(self,l):
        return [val for val in l if val in self.modulelist]

    def shellaction(self,path,modules,action):
        import os
        for mod in self.selected(modules):
            directory=os.path.join(path,mod)
            here = os.getcwd()
            if os.path.isdir(directory):
                self.__dump('Treating directory '+directory)
                os.chdir(directory)
                os.system(action)
                os.chdir(here)
                self.__dump('done.')
            else:
                print 'Cannot perform action "',action,'" on module "',mod,'" directory not present in the build'
    
    def get_output(self,cmd):
        import subprocess
        self.__dump('executing:',cmd)
        proc=subprocess.Popen(cmd,stdout=subprocess.PIPE,shell=True)
        (out, err) = proc.communicate()
        self.__dump("program output:", out)
        return out.rstrip('\n')

    def removefile(self,pattern,dirname,names):
        import os,fnmatch
        "Return the files given by the pattern"
        for name in names:
            if fnmatch.fnmatch(name,pattern):
                self.__dump('removing',os.path.join(dirname,name))
                os.remove(os.path.join(dirname,name))

    def autogen(self):
        self.shellaction(self.srcdir,self.modulelist,'autoreconf -fi')

    def check(self):
        self.shellaction('.',CHECKMODULES,'make check')

    def make(self):
        self.shellaction('.',MAKEMODULES,'make -j6 && make install')
        
    def dist(self):
        self.shellaction('.',self.modulelist,'make dist')
        self.get_output(self.jhb+DIST)
                                
    def build(self):
        "Build the bigdft module with the options provided by the rcfile"
        import os
        #in the case of a nonbranch case, like a dist build, force checkout
        #should the make would not work
        if self.branch:
            co=''
        else:
            co='-C'        
        if (self.verbose): 
            os.system(self.jhb+BUILD+co)
        else:
            os.system(self.jhb+TINDERBOX+co)

    def clean(self):#clean files
        import os
        for mod in self.selected(MAKEMODULES):
            self.get_output(self.jhb+UNINSTALL+mod)
            self.get_output(self.jhb+CLEANONE+mod)
            #here we should eliminate residual .mod files
            os.path.walk(mod,self.removefile,"*.mod")
            os.path.walk(mod,self.removefile,"*.MOD")
        #self.get_output(self.jhb+CLEAN)

    def dry_run(self):
        self.get_output(self.jhb+DOT)

    def rcfile_from_env(self):
        "Build the rcfile information from the chosen "+BIGDFT_CFG+" environment variable"
        import os
        if os.path.isfile(self.rcfile) and not os.path.isfile(RCFILE):
            from shutil import copyfile
            copyfile(self.rcfile,RCFILE)
            return
        if BIGDFT_CFG not in os.environ.keys() or os.path.isfile(RCFILE): return
        print 'The suite has been built without configuration file.'
        rclist=[]
        rclist.append("modules = ['bigdft',]")
        sep='"""'
        confline=sep+os.environ[BIGDFT_CFG]+sep    
        for mod in self.modulelist:
            rclist.append("module_autogenargs['"+mod+"']="+confline)
        #then write the file
        rcfile=open(RCFILE,'w')
        for item in rclist:
            rcfile.write("%s\n" % item)
            rcfile.write("\n")
        rcfile.close()
        print 'Your used configuration options have been saved in the file "'+RCFILE+'"'
        print 'Such file will be used for next builds, you might also save it in the "rcfiles/"'
        print 'Directory of the source for future use. The name might contain the hostname'
        
    def __del__(self):
        print 50*'-'
        print 'Thank you for using the Installer of BigDFT suite.'
        print 'The action considered was:',self.action
        if self.action == 'build': self.rcfile_from_env()



#now follows the available actions, argparse might be called
import argparse
parser = argparse.ArgumentParser(description='BigDFT suite Installer',
                                 epilog='For more information, visit www.bigdft.org')
parser.add_argument('-f','--file',
                   help='Use an alternative configuration file instead of the default given by the environment variable '+BIGDFT_CFG)
parser.add_argument('-d','--verbose',action='store_true',
                   help='Verbose output')

parser.add_argument('action',choices=[act for act in ACTIONS],
                   help='Define the installer action to be taken')
args = parser.parse_args()

BigDFTInstaller(args.action,args.file,args.verbose)
