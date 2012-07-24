!> @file 
!!   energy and forces in linear
!! @author
!!   Copyright (C) 2011-2012 BigDFT group 
!!   This file is distributed under the terms of the
!!   GNU General Public License, see ~/COPYING file
!!   or http://www.gnu.org/copyleft/gpl.txt .
!!   For the list of contributors, see ~/AUTHORS 
 

!> Calculates the potential and energy and writes them. This is subroutine is copied
!! from cluster.
!!
!! Calling arguments:
!! ==================
!!  Input arguments:
!!  -----------------
!!     @param iproc       process ID
!!     @param nproc       total number of processes
!!     @param n3d         ??
!!     @param n3p         ??
!!     @param Glr         type describing the localization region
!!     @param orbs        type describing the physical orbitals psi
!!     @param atoms       type containing the parameters for the atoms
!!     @param in          type  containing some very general parameters
!!     @param lin         type containing parameters for the linear version
!!     @param psi         the physical orbitals
!!     @param rxyz        atomic positions
!!     @param rhopot      the charge density
!!     @param nscatterarr ??
!!     @param nlpspd      ??
!!     @param proj        ??
!!     @param pkernelseq  ??
!!     @param radii_cf    coarse and fine radii around the atoms
!!     @param irrzon      ??
!!     @param phnons      ??
!!     @param pkernel     ??
!!     @param pot_ion     the ionic potential
!!     @param rhocore     ??
!!     @param potxc       ??
!!     @param PSquiet     flag to control the output from the Poisson solver
!!     @param eion        ionic energy
!!     @param edisp       dispersion energy
!!     @param fion        ionic forces
!!     @param fdisp       dispersion forces
!!  Input / Output arguments
!!  ------------------------
!!     @param rhopot      the charge density
!!  Output arguments:
!!  -----------------
subroutine updatePotential(ixc,nspin,denspot,ehart,eexcu,vexcu)

use module_base
use module_types
use module_interfaces, exceptThisOne => updatePotential
use Poisson_Solver
implicit none

! Calling arguments
integer, intent(in) :: ixc,nspin
type(DFT_local_fields), intent(inout) :: denspot
real(kind=8),intent(out) :: ehart, eexcu, vexcu

! Local variables
character(len=*), parameter :: subname='updatePotential'
logical :: nullifyVXC
integer :: istat, iall
real(dp), dimension(6) :: xcstr

nullifyVXC=.false.

if(nspin==4) then
   !this wrapper can be inserted inside the poisson solver 
   call PSolverNC(denspot%pkernel%geocode,'D',denspot%pkernel%iproc,denspot%pkernel%nproc,&
        denspot%dpbox%ndims(1),denspot%dpbox%ndims(2),denspot%dpbox%ndims(3),&
        denspot%dpbox%n3d,ixc,&
        denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
        denspot%rhov,denspot%pkernel%kernel,denspot%V_ext,ehart,eexcu,vexcu,0.d0,.true.,4)
else
   if (.not. associated(denspot%V_XC)) then   
      !Allocate XC potential
      if (denspot%dpbox%n3p >0) then
         allocate(denspot%V_XC(denspot%dpbox%ndims(1),denspot%dpbox%ndims(2),denspot%dpbox%n3p,nspin+ndebug),stat=istat)
         call memocc(istat,denspot%V_XC,'denspot%V_XC',subname)
      else
         allocate(denspot%V_XC(1,1,1,1+ndebug),stat=istat)
         call memocc(istat,denspot%V_XC,'denspot%V_XC',subname)
      end if
      nullifyVXC=.true.
   end if

   call XC_potential(denspot%pkernel%geocode,'D',denspot%pkernel%iproc,denspot%pkernel%nproc,&
        denspot%pkernel%mpi_comm,&
        denspot%dpbox%ndims(1),denspot%dpbox%ndims(2),denspot%dpbox%ndims(3),ixc,&
        denspot%dpbox%hgrids(1),denspot%dpbox%hgrids(2),denspot%dpbox%hgrids(3),&
        denspot%rhov,eexcu,vexcu,nspin,denspot%rho_C,denspot%V_XC,xcstr)
   
   call H_potential('D',denspot%pkernel,denspot%rhov,denspot%V_ext,ehart,0.0_dp,.true.,&
        quiet=denspot%PSquiet) !optional argument
   
   !sum the two potentials in rhopot array
   !fill the other part, for spin, polarised
   if (nspin == 2) then
      call dcopy(denspot%dpbox%ndims(1)*denspot%dpbox%ndims(2)*denspot%dpbox%n3p,denspot%rhov(1),1,&
           denspot%rhov(1+denspot%dpbox%ndims(1)*denspot%dpbox%ndims(2)*denspot%dpbox%n3p),1)
   end if
   !spin up and down together with the XC part
   call axpy(denspot%dpbox%ndims(1)*denspot%dpbox%ndims(2)*denspot%dpbox%n3p*nspin,1.0_dp,denspot%V_XC(1,1,1,1),1,&
        denspot%rhov(1),1)
   
   if (nullifyVXC) then
      iall=-product(shape(denspot%V_XC))*kind(denspot%V_XC)
      deallocate(denspot%V_XC,stat=istat)
      call memocc(istat,iall,'denspot%V_XC',subname)
   end if

end if

END SUBROUTINE updatePotential
