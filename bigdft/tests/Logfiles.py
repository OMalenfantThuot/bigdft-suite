import yaml

EVAL = "eval"
SETUP = "let"
INITIALIZATION = "globals"

PRE_POST = [EVAL, SETUP, INITIALIZATION]

ENERGY = "BigDFT.energy"
FERMI_LEVEL= "BigDFT.ef"
NUMBER_OF_ATOMS = 'BigDFT.nat'
EIGENVALUES = 'BigDFT.evals'
KPOINTS = 'BigDFT.kpts'
ASTRUCT = 'BigDFT.astruct'

#Builtin pathes to define the search paths
BUILTIN={ENERGY: [["Last Iteration", "FKS"],["Last Iteration", "EKS"], ["Energy (Hartree)"]],
         FERMI_LEVEL: [["Ground State Optimization", -1, "Fermi Energy"]],
         NUMBER_OF_ATOMS: [ ['Atomic System Properties','Number of atoms']],
         ASTRUCT: [ ['Atomic structure']],
         EIGENVALUES: [ ["Complete list of energy eigenvalues"], [ "Ground State Optimization", -1, "Orbitals"],
                        ["Ground State Optimization",-1,"Hamiltonian Optimization",-1,"Subspace Optimization","Orbitals"] ],
         KPOINTS: [["K points"]]}

def get_log(f):
    "Transform a logfile into a python dictionary"
    return yaml.load(open(f, "r").read(), Loader = yaml.CLoader)

def get_logs(files):
   logs=[]
   for filename in files:
     try:
        logs+=[yaml.load(open(filename, "r").read(), Loader = yaml.CLoader)]
     except:
        try: 
            logs+=yaml.load_all(open(filename, "r").read(), Loader = yaml.CLoader)
        except:
            logs+=[None]
            print "warning, skipping logfile",filename
   return logs

# this is a tentative function written to extract information from the runs
def document_quantities(doc,to_extract):
  analysis={}
  for quantity in to_extract:
    if quantity in PRE_POST: continue
    #follow the levels indicated to find the quantity
    field=to_extract[quantity]
    if type(field) is not type([]) is not type({}) and field in BUILTIN:
        paths=BUILTIN[field]
    else:
        paths=[field]
    #now try to find the first of the different alternatives
    for path in paths:
      #print path,BUILTIN,BUILTIN.keys(),field in BUILTIN,field
      value=doc
      for key in path:
        #as soon as there is a problem the quantity is null
        try:
          value=value[key]
        except:
          value=None
          break
      if value is not None: break        
    analysis[quantity]=value
  return analysis    

def perform_operations(variables,ops,debug=False):
##    glstr=''
##    if globs is not None:
##        for var in globs:
##            glstr+= "global "+var+"\n"
##        if debug: print '###Global Strings: \n',glstr
##    #first evaluate the given variables
    for key in variables:
        command=key+"="+str(variables[key])
        if debug: print command
        exec(command)
        #then evaluate the given expression
    if debug: print ops
    #exec(glstr+ops, globals(), locals())
    exec(ops, globals(), locals())

def process_logfiles(files,instructions,debug=False):
    import sys
    glstr='global __LAST_FILE__ \n'
    glstr+='__LAST_FILE__='+str(len(files))+'\n'
    if INITIALIZATION in instructions:
        for var in instructions[INITIALIZATION]:
            glstr+= "global "+var+"\n"
            glstr+= var +" = "+ str(instructions[INITIALIZATION][var])+"\n"
            #exec var +" = "+ str(instructions[INITIALIZATION][var])
    exec(glstr, globals(), locals())
    for f in files:
        sys.stderr.write("#########processing "+f+"\n")
        datas=get_logs([f])
        for doc in datas:
            doc_res=document_quantities(doc,instructions)
            #print doc_res,instructions
            if EVAL in instructions: perform_operations(doc_res,instructions[EVAL],debug=debug)


class Logfile():
    def __init__(self,filename=None,dictionary=None,filename_list=None,label=None):
        "Import a Logfile from a filename in yaml format"
        filelist=None
        self.label=label
        if filename is not None: 
            if self.label is None: self.label=filename
            filelist=[filename]
        elif filename_list is not None:
            if self.label is None: self.label=filename_list[0]
            filelist=filename_list
        if filelist:
            dicts=get_logs(filelist)
        elif dictionary:
            dicts=[dictionary]
        if len(dicts)==1:
            self._initialize_class(dicts[0])
        else:
            self._instances=[ Logfile(dictionary=d,label='log'+str(i)) for i,d in enumerate(dicts)]
            #then we should find the best values for the dictionary
            print 'Found',len(self._instances),'different runs'
            import numpy
            #initalize the class with the dictionary corresponding to the lower value of the energy
            ens=[l.energy for l in self._instances] 
            self.reference_log=numpy.argmin(ens)
            #print 'Energies',ens
            
    def __getitem__(self,index):
        if hasattr(self,'_instances'):
            return self._instances[index]
        else:
            print 'index not available'
            raise 
    def _initialize_class(self,d):
        self.log=d
        #here we should initialize different instances of the logfile class again
        items=['energy','nat','kpts','ef','evals','astruct']
        sublog=document_quantities(self.log,{val: 'BigDFT.'+val for val in items})
        for att in sublog:
            val=sublog[att]
            if val is not None: setattr(self,att,val)
        #then postprocess the paticular cases
        if hasattr(self,'kpts'):
            self.nkpt=len(self.kpts)
            if hasattr(self,'evals'): self.evals=self.get_bz(self.evals,self.kpts)
        elif hasattr(self,'evals'):
            import DoS
            self.evals=[DoS.BandArray(self.evals),]
    def get_bz(self,ev,kpts):
        evals=[]
        import DoS
        for i,kp in enumerate(kpts):
            evals.append(DoS.BandArray(ev,ikpt=i+1,kpt=kp['Rc'],kwgt=kp['Wgt']))
        return evals
    def get_dos(self,label=None):
        "Get the density of states from the logfile"
        import DoS
        lbl=self.label if label is None else label
        return DoS.DoS(bandarrays=self.evals,label=lbl,units='AU',fermi_level=-0.5)#self.fermi_energy)
    def get_brillouin_zone(self):
        "Returns an instance of the BrillouinZone class, useful for band strucure"
        import DoS
        if self.nkpt==1: 
            print 'WARNING: Brillouin Zone plot cannot be defined properly with only one k-point'
            #raise
        mesh=self.log['kpt']['ngkpt']
	if isinstance(mesh,int): mesh=[mesh,]*3
        return DoS.BrillouinZone(self.astruct,mesh,self.evals)	        
