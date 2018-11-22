"""
This module is related to the usage of BigDFT with Fragment-related Quantities.
Input as well as Logfiles might be processed with the classes and methods provided by it.

"""

from futile.Utils import write as safe_print
try:
    from collections.abc import MutableMapping, MutableSequence
except:
    from collections import MutableMapping, MutableSequence


class Lattice():
    """
    Defines the fundamental objects to deal with periodic systems
    """

    def __init__(self, vectors):
        self.vectors = vectors

    def grid(self, origin=[0.0, 0.0, 0.0], extremes=None, radius=None):
        "produces a set of translation vectors from a given origin"
        import numpy as np
        transl = []
        g = [[], [], []]  # the grid of discrete translations
        if extremes is not None:
            # print extremes
            for i, d in enumerate(extremes):
                for k in range(d[0], d[1] + 1):
                    g[i].append(k)
            # print g
            for i in g[0]:
                arri = np.array(self.vectors[0]) * i
                for j in g[1]:
                    arrj = np.array(self.vectors[1]) * j + arri
                    for k in g[2]:
                        arrk = np.array(self.vectors[2]) * k + arrj
                        vect = np.array(origin) + arrk
                        app = True
                        if radius is not None:
                            app = np.linalg.norm(arrk) < radius
                        if app:
                            transl.append(vect)
        return transl


class RotoTranslation():
    "Define a transformation which can be applied to a group of atoms"

    def __init__(self, pos1, pos2):
        try:
            import wahba
            self.R, self.t, self.J = wahba.rigid_transform_3D(pos1, pos2)
        except Exception(e):
            safe_print('Error', e)
            self.R, self.t, self.J = (None, None, 1.0e10)

    def dot(self, pos):
        "Apply the rototranslations on the set of positions provided by pos"
        import wahba as w
        import numpy as np
        if self.t is None:
            res = w.apply_R(self.R, pos)
        elif self.R is None:
            res = w.apply_t(self.t, pos)
        else:
            res = w.apply_Rt(self.R, self.t, pos)
        return res

    def invert(self):
        self.t = -self.t
        if self.R is not None:
            self.R = self.R.T


class Translation(RotoTranslation):
    def __init__(self, t):
        import numpy
        self.R = None
        self.t = numpy.mat(t).reshape(3, 1)
        self.J = 0.0


class Rotation(RotoTranslation):
    def __init__(self, R):
        self.t = None
        self.R = R
        self.J = 0.0


class Fragment(MutableSequence):
    """
    Introduce the concept of fragment. This is a subportion of the system
    (it may also coincide with the system itself) that is made of atoms.
    Such fragment might have quantities associated to it, like its
    electrostatic multipoles (charge, dipole, etc.) and also geometrical
    information (center of mass, principla axis etc.). A Fragment might also
    be rototranslated and combined with other moieteies to form a
    :class:`System`.

    atomlist (list): list of atomic dictionaries defining the fragment
    xyzfile (XYZReader): an XYZ file to read from.

    .. todo::
       Define and describe if this API is also suitable for solid-state fragments

    """

    def __init__(self, atomlist=None, xyzfile=None):
        from Atom import Atom
        self.atoms = []

        # insert atoms.
        if atomlist and isinstance(atomlist, list):
            for atom in atomlist:
                self.append(Atom(atom))
        elif xyzfile and isinstance(xyzfile, XYZReader):
            xyzfile.open()
            for line in xyzfile:
                self.append(Atom(line))
            xyzfile.close()

        # Values
        self.purity_indicator = None
        self.q0 = None
        self.q1 = None
        self.q2 = None

    def __len__(self):
        return len(self.atoms)

    def __delitem__(self, index):
        self.atoms.__delitem__(index)

    def insert(self, index, value):
        from Atom import Atom
        self.atoms.insert(index, Atom(value))

    def __setitem__(self, index, value):
        from Atom import Atom
        self.atoms.__setitem__(index, Atom(value))

    def __getitem__(self, index):
        # If they ask for only one atom, then we return it as an atom.
        # but if it's a range we return a ``Fragment`` with those atoms in it.
        if isinstance(index, slice):
            return Fragment(atomlist=self.atoms.__getitem__(index))
        else:
            return self.atoms.__getitem__(index)

    @property
    def centroid(self):
        """
        The center of a fragment.
        """
        from numpy import mean, ravel
        pos = [at.get_position() for at in self]
        return ravel(mean(pos, axis=0))

    @property
    def center_of_charge(self, zion):
        """
        The charge center which depends both on the position and net charge
        of each atom.
        """
        from numpy import array
        cc = array([0.0, 0.0, 0.0])
        qtot = 0.0
        for at in self:
            netcharge = at.q0
            zcharge = zion[at.sym]
            elcharge = zcharge - netcharge
            cc += elcharge * array(at.get_position())
            qtot += elcharge
        return cc / qtot

    def d0(self, center=None):
        """
        Fragment dipole, calculated only from the atomic charges.

        Args:
          center (list):
        """
        from numpy import zeros, array
        # one might added a treatment for non-neutral fragments
        # but if the center of charge is used the d0 value is zero
        if center is not None:
            cxyz = center
        else:
            cxyz = self.centroid

        d0 = zeros(3)
        found = False
        for at in self:
            if self.q0 is not None:
                found = True
                d0 += at.q0[0] * (array(atom.get_position()) - cxyz)

        if found:
            return d0
        else:
            return None

    def d1(self, center=None):
        """
        Fragment dipole including the atomic dipoles.
        """
        from numpy import zeros
        d1 = zeros(3)
        dtot = self.d0(center)
        if dtot is None:
            return dtot

        found = False
        for at in self:
            if at.q1 is not None:
                found = True
                d1 += at.q1

        if found:
            return d1 + dtot
        else:
            return None
        pass

    def ellipsoid(self, center=0.0):
        import numpy as np
        I = np.mat(np.zeros(9).reshape(3, 3))
        for at in self:
            rxyz = at.get_position() - center
            I[0, 0] += rxyz[0]**2  # rxyz[1]**2+rxyz[2]**2
            I[1, 1] += rxyz[1]**2  # rxyz[0]**2+rxyz[2]**2
            I[2, 2] += rxyz[2]**2  # rxyz[1]**2+rxyz[0]**2
            I[0, 1] += rxyz[1] * rxyz[0]
            I[1, 0] += rxyz[1] * rxyz[0]
            I[0, 2] += rxyz[2] * rxyz[0]
            I[2, 0] += rxyz[2] * rxyz[0]
            I[1, 2] += rxyz[2] * rxyz[1]
            I[2, 1] += rxyz[2] * rxyz[1]
        return I

    @property
    def external_potential(self):
        """
        Transform the fragment information into a dictionary ready to be
        put as an external potential.
        """
        return [at.external_potential for at in self]

    def line_up(self):
        """
        Align the principal axis of inertia of the fragments along the
        coordinate axis. Also shift the fragment such as its centroid is zero.
        """
        from numpy.linalg import eig
        Shift = Translation(self.centroid)
        Shift.invert()
        self.transform(Shift)
        # now the centroid is zero
        I = self.ellipsoid()
        w, v = eig(I)
        Redress = Rotation(v.T)
        self.transform(Redress)
        # now the principal axis of inertia are on the coordinate axis

    @property
    def qcharge(self):
        netcharge = self.q0
        for at in self:
            zcharge = at["nzion"]
            netcharge += zcharge
        return netcharge

    def transform(self, Rt):  # R=None,t=None):
        """
        Apply a rototranslation of the fragment positions
        """
        import numpy as np
        for at in self:
            at.set_position(Rt.dot(at.get_position()))
        #import wahba as w,numpy as np
        # if t is None:
        #    self.positions=w.apply_R(R,self.positions)
        # elif R is None:
        #    self.positions=w.apply_t(t,self.positions)
        # else:
        #    self.positions=w.apply_Rt(R,t,self.positions)
        # further treatments have to be added for the atomic multipoles
        # they should be transfomed accordingly, up the the dipoles at least


class System(MutableMapping):
    """
    A system is defined by a collection of Fragments.

    It might be given by one single fragment
    """

    def __init__(self, *args, **kwargs):
        self.store = dict()
        self.update(dict(*args, **kwargs))

    def dict(self):
        """
        Convert to a dictionary.
        """
        return self.store

    def __getitem__(self, key):
        return self.store[self.__keytransform__(key)]

    def __setitem__(self, key, value):
        self.store[self.__keytransform__(key)] = value

    def __delitem__(self, key):
        del self.store[self.__keytransform__(key)]

    def __iter__(self):
        return iter(self.store)

    def __len__(self):
        return len(self.store)

    def __keytransform__(self, key):
        return key

    @property
    def centroid(self):
        """
        Center of mass of the system
        """
        from numpy import mean
        mean([frag.centroid in self], axis=0)

    @property
    def central_fragment(self):
        """
        Returns the fragment whose center of mass is closest to the centroid
        """
        import numpy as np
        CMs = [frag.centroid in self]
        return np.argmin([np.dot(dd, dd.T) for dd in (CMs - self.centroid)])

    def plot_purity(ax):
        """
        Plot the purity values of the fragments in this system.
        This assumes they have already been set.

        Args:
          axs: the axs we we should plot on.
        """
        pvals = [frag.purity_indicator for frag in self.values()]
        ax.plot(pvals, 'x--')

        axs.set_xticks(range(len(self.keys())))
        axs.set_xticklabels(self.keys(), rotation=90)
        axs.set_xlabel("Fragment", fontsize=12)
        axs.set_ylabel("Purity Values", fontsize=12)

    @property
    def q0(self):
        """
        Provides the global monopole of the system given as a sum of the
        monopoles of the atoms.
        """
        if len(self) == 0:
            return None
        return sum(filter(None, [frag.q0 for frag in self]))


if __name__ == "__main__":
    from XYZ import XYZReader, XYZWriter
    from os.path import join
    from os import system
    from copy import deepcopy

    safe_print("Read in an xyz file and build from a list.")
    atom_list = []
    with XYZReader(join("Database", "XYZs", "SiO.xyz")) as reader:
        for at in reader:
            atom_list.append(at)
    frag1 = Fragment(atomlist=atom_list)
    for at in frag1:
        safe_print(at.sym, at.get_position())
    safe_print("Centroid", frag1.centroid)
    safe_print()

    safe_print("Build from an xyz file directory.")
    reader = XYZReader(join("Database", "XYZs", "Si4.xyz"))
    frag2 = Fragment(xyzfile=reader)
    for at in frag2:
        safe_print(at.sym, at.get_position())
    safe_print()

    safe_print("We can combine two fragments with +=")
    frag3 = deepcopy(frag1)
    frag3 += frag2
    for at in frag3:
        print(at.sym, at.get_position())
    safe_print("Length of frag3", len(frag3))
    safe_print()

    safe_print("Since we can iterate easily, we can also write easily.")
    with XYZWriter("test.xyz", len(frag3), "angstroem") as writer:
        for at in frag3:
            writer.write(at)
    system("cat test.xyz")
    safe_print()

    safe_print("We can also extract using the indices")
    print(dict(frag3[0]))
    sub_frag = frag3[1:3]
    for at in sub_frag:
        print(dict(at))
    safe_print()

    safe_print("Now we move on to testing the system class.")
    safe_print("We might first begin in the easiest way.")
    sys = System(frag1=frag1, frag2=frag2)
    for at in sys["frag1"]:
        print(dict(at))
    for at in sys["frag2"]:
        print(dict(at))
    safe_print()

    safe_print("What if we want to combine two fragments together?")
    sys["frag1"] += sys.pop("frag2")
    for at in sys["frag1"]:
        print(dict(at))
    print("frag2" in sys)
    safe_print()

    safe_print("What if I want to split a fragment by atom indices?")
    temp_frag = sys.pop("frag1")
    sys["frag1"], sys["frag2"] = temp_frag[0:3], temp_frag[3:]
    for at in sys["frag1"]:
        print(dict(at))
    for at in sys["frag2"]:
        print(dict(at))
    safe_print()

    safe_print("Construct a system from an XYZ file.")
    fname = join("Database", "XYZs", "BH2.xyz")
    sys2 = System(frag1=Fragment(xyzfile=XYZReader(fname)))

    safe_print("Split it to fragments")
    sys2["frag1"], sys2["frag2"] = sys2["frag1"][0:1], sys2["frag1"][1:]

    safe_print("And write to file")
    with XYZWriter("test.xyz", len(frag3), "angstroem") as writer:
        for fragid, frag in sys2.items():
            for at in frag:
                writer.write(at)
    system("cat test.xyz")
