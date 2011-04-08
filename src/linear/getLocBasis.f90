subroutine getLinearPsi(iproc, nproc, nspin, Glr, orbs, comms, at, lin, rxyz, rxyzParab, &
    nscatterarr, ngatherarr, nlpspd, proj, rhopot, GPU, input, pkernelseq, phi, psi, psit, &
    infoBasisFunctions, n3p, n3d, irrzon, phnons, pkernel, pot_ion, rhocore, potxc, PSquiet, ebsMod, coeff)
!
! Purpose:
! ========
!   This subroutine creates the orbitals psi out of a linear combination of localized basis functions
!   phi. To do so, it proceeds as follows:
!    1. Create the basis functions (with subroutine 'getLocalizedBasis')
!    2. Write the Hamiltonian in this new basis.
!    3. Diagonalize this Hamiltonian matrix.
!    4. Build the new linear combinations. 
!   The basis functions are localized by adding a confining quartic potential to the ordinary DFT 
!   Hamiltonian. There is no self consistency cycle for the potential, i.e. the basis functionsi
!   are optimized with a fixed potential.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc           process ID
!     nproc           total number of processes
!     nspin           npsin==1 -> closed shell; npsin==2 -> spin polarized
!     Glr             type describing the localization region
!     orbs            type describing the physical orbitals psi
!     comms           type containing the communication parameters for the physical orbitals psi
!     at              type containing the paraneters for the atoms
!     lin             type containing parameters for the linear version
!     rxyz            the atomic positions
!     rxyzParab       the center of the confinement potential (at the moment identical rxyz)
!     nscatterarr     ???
!     ngatherarr      ???
!     nlpsp           ???
!     proj            ???
!     rhopot          the charge density
!     GPU             parameters for GPUs
!     input           type containing some very general parameters
!     pkernelseq      ???
!     n3p             ???
!  Input/Output arguments
!  ---------------------
!     phi             the localized basis functions. It is assumed that they have been initialized
!                     somewhere else
!   Output arguments
!   ----------------
!     psi             the physical orbitals, which will be a linear combinations of the localized
!                     basis functions phi
!     psit            psi transposed
!     infoBasisFunctions  indicated wheter the basis functions converged to the specified limit (value is 0)
!                         or whether the iteration stopped due to the iteration limit (value is -1). This info
!                         is returned by 'getLocalizedBasis'
!
use module_base
use module_types
use module_interfaces, exceptThisOne => getLinearPsi
use Poisson_Solver
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc, nspin, n3p, n3d
type(locreg_descriptors),intent(in):: Glr
type(orbitals_data),intent(in) :: orbs
type(communications_arrays),intent(in) :: comms
type(atoms_data),intent(in):: at
type(linearParameters),intent(in):: lin
type(input_variables),intent(in):: input
real(8),dimension(3,at%nat),intent(in):: rxyz, rxyzParab
integer,dimension(0:nproc-1,4),intent(in):: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
integer,dimension(0:nproc-1,2),intent(in):: ngatherarr
type(nonlocal_psp_descriptors),intent(in):: nlpspd
real(wp),dimension(nlpspd%nprojel),intent(in):: proj
real(dp),dimension(max(Glr%d%n1i*Glr%d%n2i*n3p,1)*input%nspin),intent(inout) :: rhopot
type(GPU_pointers),intent(inout):: GPU
integer, dimension(lin%as%size_irrzon(1),lin%as%size_irrzon(2),lin%as%size_irrzon(3)),intent(in) :: irrzon 
real(dp), dimension(lin%as%size_phnons(1),lin%as%size_phnons(2),lin%as%size_phnons(3)),intent(in) :: phnons 
real(dp), dimension(lin%as%size_pkernel),intent(in):: pkernel
real(wp), dimension(lin%as%size_pot_ion),intent(inout):: pot_ion
!real(wp), dimension(lin%as%size_rhocore):: rhocore 
real(wp), dimension(:),pointer,intent(in):: rhocore                  
real(wp), dimension(lin%as%size_potxc(1),lin%as%size_potxc(2),lin%as%size_potxc(3),lin%as%size_potxc(4)),intent(inout):: potxc
real(dp),dimension(:),pointer,intent(in):: pkernelseq
real(8),dimension(lin%orbs%npsidim),intent(inout):: phi
real(8),dimension(orbs%npsidim),intent(out):: psi, psit
integer,intent(out):: infoBasisFunctions
character(len=3),intent(in):: PSquiet
real(8),intent(out):: ebsMod
real(8),dimension(lin%orbs%norb,orbs%norb),intent(in out):: coeff

! Local variables 
integer:: istat, iall 
real(8),dimension(:),allocatable:: hphi, eval 
real(8),dimension(:,:),allocatable:: HamSmall
real(8),dimension(:,:,:),allocatable:: matrixElements
real(8),dimension(:),pointer:: phiWork 
real(8)::epot_sum,ekin_sum,eexctX,eproj_sum, ddot, trace 
real(wp),dimension(:),pointer:: potential 
character(len=*),parameter:: subname='getLinearPsi' 

real(8):: hxh, hyh, hzh, ehart, eexcu, vexcu
integer:: iorb, jorb, it, istart
character(len=11):: procName, orbNumber, orbName
  
  allocate(hphi(lin%orbs%npsidim), stat=istat) 
  call memocc(istat, hphi, 'hphi', subname)
  allocate(phiWork(max(size(phi),size(psi))), stat=istat)
  call memocc(istat, phiWork, 'phiWork', subname)
  allocate(matrixElements(lin%orbs%norb,lin%orbs%norb,2), stat=istat)
  call memocc(istat, matrixElements, 'matrixElements', subname)
  allocate(eval(lin%orbs%norb), stat=istat)
  call memocc(istat, eval, 'eval', subname)
  
  
  call getLocalizedBasis(iproc, nproc, at, orbs, Glr, input, lin, rxyz, nspin, nlpspd, proj, &
      nscatterarr, ngatherarr, rhopot, GPU, pkernelseq, phi, hphi, trace, rxyzParab, &
      infoBasisFunctions)
write(procName,'(i0)') iproc
do iorb=1,lin%orbs%norbp
  write(orbNumber,'(i0)') iorb
  orbName='orb_'//trim(procName)//'_'//trim(orbNumber)
  istart=1
  call plot_wfSquare_cube(orbName, at, Glr, input%hx, input%hy, input%hz, rxyz, phi(istart), 'comment')
  istart=istart+Glr%wfd%nvctr_c+7*Glr%wfd%nvctr_f
end do

  if(iproc==0) write(*,'(x,a)') '----------------------------------- Determination of the orbitals in this new basis.'

  if(trim(lin%getCoeff)=='min') then

      if(iproc==0) write(*,'(x,a)',advance='no') 'Hamiltonian application...'
      call HamiltonianApplicationConfinement(iproc,nproc,at,lin%orbs,lin,input%hx,input%hy,input%hz,rxyz,&
           nlpspd,proj,Glr,ngatherarr,Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),&
           rhopot(1),&
           phi(1),hphi(1),ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU, rxyzParab, pkernel=pkernelseq)
      if(iproc==0) write(*,'(x,a)') 'done.'

      call getMatrixElements(iproc, nproc, Glr, lin, phi, hphi, matrixElements)

      ! Initialize the coefficient vector at random. 
      call random_number(coeff)

      if(iproc==0) write(*,'(x,a)',advance='no') 'Optimizing coefficients...'
      call optimizeCoefficients(iproc, orbs, lin, matrixElements, coeff)
!!!! THIS IS A TEST !!!!
 call modifiedBSEnergyModified(nspin, orbs, lin, coeff, matrixElements, ebsMod)
 if(iproc==0) write(*,'(a,es15.6)') 'ebsMod from sub', ebsMod
 do it=1,50
    call getLocalizedBasisNew(iproc, nproc, at, orbs, Glr, input, lin, rxyz, nspin, nlpspd, &
        proj, nscatterarr, ngatherarr, rhopot, GPU, pkernelseq, phi, hphi, trace, rxyzParab, coeff, &
        infoBasisFunctions)
  call HamiltonianApplicationConfinement(iproc,nproc,at,lin%orbs,lin,input%hx,input%hy,input%hz,rxyz,&
       nlpspd,proj,Glr,ngatherarr,Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),&
       rhopot(1),&
       phi(1),hphi(1),ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU, rxyzParab, pkernel=pkernelseq)
  call getMatrixElements(iproc, nproc, Glr, lin, phi, hphi, matrixElements)
  call optimizeCoefficients(iproc, orbs, lin, matrixElements, coeff)
 call modifiedBSEnergyModified(nspin, orbs, lin, coeff, matrixElements, ebsMod)
 if(iproc==0) write(*,'(a,es15.6)') 'ebsMod from sub', ebsMod
  call buildWavefunctionModified(iproc, nproc, orbs, lin%orbs, comms, lin%comms, phi, psi, coeff)
!! ONLY FOR DEBUGGING
!allocate the potential in the full box
call full_local_potential(iproc,nproc,Glr%d%n1i*Glr%d%n2i*n3p,Glr%d%n1i*Glr%d%n2i*Glr%d%n3i,input%nspin,&
         orbs%norb,orbs%norbp,ngatherarr,rhopot,potential)
call untranspose_v(iproc, nproc, orbs, Glr%wfd, comms, psi, work=phiWork)
call HamiltonianApplication(iproc,nproc,at,orbs,input%hx,input%hy,input%hz,rxyz,&
     nlpspd,proj,Glr,ngatherarr,potential,&
     psi(1),hphi(1),ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU,pkernel=pkernelseq)
if(iproc==0) write(*,'(x,a,es18.10)') 'ebs', ekin_sum+epot_sum+eproj_sum
!deallocate potential
call free_full_potential(nproc,potential,subname)
!! ONLY FOR DEBUGGING
 end do
!!!!!!!!!!!!!!!!!!!!!!!!

  else if(trim(lin%getCoeff)=='diag') then
  
      !allocate the potential in the full box
      call full_local_potential(iproc,nproc,Glr%d%n1i*Glr%d%n2i*n3p,Glr%d%n1i*Glr%d%n2i*Glr%d%n3i,input%nspin,&
           lin%orbs%norb,lin%orbs%norbp,ngatherarr,rhopot,potential)
      
      call HamiltonianApplication(iproc,nproc,at,lin%orbs,input%hx,input%hy,input%hz,rxyz,&
           nlpspd,proj,Glr,ngatherarr,potential,&
           phi(1),hphi(1),ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU,pkernel=pkernelseq)
      if(iproc==0) write(*,'(x,a)', advance='no') 'done.'
      
      !deallocate potential
      call free_full_potential(nproc,potential,subname)

  end if
  
  
  call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
  call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)
  
  allocate(HamSmall(lin%orbs%norb,lin%orbs%norb), stat=istat)
  call memocc(istat, HamSmall, 'HamSmall', subname)
  
  if(trim(lin%getCoeff)=='diag') then
      call transformHam(iproc, nproc, lin%orbs, lin%comms, phi, hphi, HamSmall)
      if(iproc==0) write(*,'(a)', advance='no') ' Diagonalization... '
      call diagonalizeHamiltonian(iproc, nproc, lin%orbs, HamSmall, eval)
      call dcopy(lin%orbs%norb*orbs%norb, HamSmall(1,1), 1, coeff(1,1), 1)
      !do iorb=1,lin%orbs%norb
      !    write(300+iproc,*) (HamSmall(iorb,jorb), jorb=1,orbs%norb)
      !end do
      if(iproc==0) write(*,'(a)') 'done.'
  end if

  
  if(iproc==0) write(*,'(x,a)', advance='no') 'Building linear combinations... '
  if(trim(lin%getCoeff)=='diag') then
      call buildWavefunction(iproc, nproc, orbs, lin%orbs, comms, lin%comms, phi, psi, HamSmall)
  else if(trim(lin%getCoeff)=='min') then
      call buildWavefunctionModified(iproc, nproc, orbs, lin%orbs, comms, lin%comms, phi, psi, coeff)
  else
      if(iproc==0) write(*,'(a,a,a)') "ERROR: lin%getCoeff can have the values 'diag' or 'min' , &
          & but we found '", lin%getCoeff, "'."
      stop
  end if

  
  call dcopy(orbs%npsidim, psi, 1, psit, 1)
  if(iproc==0) write(*,'(a)') 'done.'
  
  
  call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
  call untranspose_v(iproc, nproc, orbs, Glr%wfd, comms, psi, work=phiWork)


  
  
  iall=-product(shape(phiWork))*kind(phiWork)
  deallocate(phiWork, stat=istat)
  call memocc(istat, iall, 'phiWork', subname)
  
  iall=-product(shape(hphi))*kind(hphi)
  deallocate(hphi, stat=istat)
  call memocc(istat, iall, 'hphi', subname)
  
  iall=-product(shape(HamSmall))*kind(HamSmall)
  deallocate(HamSmall, stat=istat)
  call memocc(istat, iall, 'HamSmall', subname)
  
  iall=-product(shape(eval))*kind(eval)
  deallocate(eval, stat=istat)
  call memocc(istat, iall, 'eval', subname)

  iall=-product(shape(matrixElements))*kind(matrixElements)
  deallocate(matrixElements, stat=istat)
  call memocc(istat, iall, 'matrixElements', subname)

end subroutine getLinearPsi








subroutine getLocalizedBasis(iproc, nproc, at, orbs, Glr, input, lin, rxyz, nspin, nlpspd, &
    proj, nscatterarr, ngatherarr, rhopot, GPU, pkernelseq, phi, hphi, trH, rxyzParabola, &
    infoBasisFunctions)
!
! Purpose:
! ========
!   Calculates the localized basis functions phi. These basis functions are obtained by adding a
!   quartic potential centered on the atoms to the ordinary Hamiltonian. The eigenfunctions are then
!   determined by minimizing the trace until the gradient norm is below the convergence criterion.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc           process ID
!     nproc           total number of processes
!     at              type containing the paraneters for the atoms
!     orbs            type describing the physical orbitals psi
!     Glr             type describing the localization region
!     input           type containing some very general parameters
!     lin             type containing parameters for the linear version
!     rxyz            the atomic positions
!     nspin           npsin==1 -> closed shell; npsin==2 -> spin polarized
!     nlpsp           ???
!     proj            ???
!     nscatterarr     ???
!     ngatherarr      ???
!     rhopot          the charge density
!     GPU             parameters for GPUs
!     pkernelseq      ???
!     rxyzParab       the center of the confinement potential (at the moment identical rxyz)
!     n3p             ???
!  Input/Output arguments
!  ---------------------
!     phi             the localized basis functions. It is assumed that they have been initialized
!                     somewhere else
!   Output arguments
!   ----------------
!     hphi            the modified Hamiltonian applied to phi
!     trH             the trace of the Hamiltonian
!     infoBasisFunctions  indicates wheter the basis functions converged to the specified limit (value is 0)
!                         or whether the iteration stopped due to the iteration limit (value is -1). This info
!                         is returned by 'getLocalizedBasis'
!
! Calling arguments:
!   Input arguments
!   Output arguments
!    phi   the localized basis functions
!
use module_base
use module_types
use module_interfaces, except_this_one => getLocalizedBasis
!  use Poisson_Solver
!use allocModule
implicit none

! Calling arguments
integer:: iproc, nproc, infoBasisFunctions
type(atoms_data), intent(in) :: at
type(orbitals_data):: orbs
type(locreg_descriptors), intent(in) :: Glr
type(input_variables):: input
type(linearParameters):: lin
real(8),dimension(3,at%nat):: rxyz, rxyzParabola
integer:: nspin
type(nonlocal_psp_descriptors), intent(in) :: nlpspd
real(wp), dimension(nlpspd%nprojel), intent(in) :: proj
integer, dimension(0:nproc-1,4), intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
integer, dimension(0:nproc-1,2), intent(in) :: ngatherarr 
real(dp), dimension(*), intent(inout) :: rhopot
type(GPU_pointers), intent(inout) :: GPU
real(dp), dimension(:), pointer :: pkernelseq
real(8),dimension(lin%orbs%npsidim):: phi, hphi
real(8):: trH

! Local variables
real(8) ::epot_sum, ekin_sum, eexctX, eproj_sum
real(8):: tt, ddot, fnrm, fnrmMax, meanAlpha, gnrm, gnrm_zero, gnrmMax
integer:: iorb, icountSDSatur, icountSwitch, idsx, icountDIISFailureTot, icountDIISFailureCons, itBest
integer:: istat, istart, ierr, ii, it, nbasisPerAtForDebug, ncong, iall, nvctrp
real(8),dimension(:),allocatable:: hphiold, alpha, fnrmOldArr, lagMatDiag
real(8),dimension(:,:),allocatable:: HamSmall, fnrmArr, fnrmOvrlpArr
real(8),dimension(:),pointer:: phiWork
logical:: quiet, allowDIIS, startWithSD, adapt
character(len=*),parameter:: subname='getLocalizedBasis'
character(len=1):: message
type(diis_objects):: diisLIN

real(8),dimension(:,:),allocatable:: lagMult
real(8),dimension(:,:,:),allocatable:: ovrlp
integer:: jstart, jorb

allocate(lagMult(lin%orbs%norb,lin%orbs%norb), stat=istat)
lagMult=1.d-1
allocate(ovrlp(lin%orbs%norb,lin%orbs%norb,2), stat=istat)

allocate(lagMatDiag(lin%orbs%norb), stat=istat)

  ! Allocate all local arrays
  call allocateLocalArrays()
  
  ! Initialize the DIIS parameters 
  icountSDSatur=0
  icountSwitch=0
  icountDIISFailureTot=0
  icountDIISFailureCons=0
  call initializeDIISParameters(lin%DIISHistMax)
  if(lin%startWithSD) then
      allowDIIS=.false.
      diisLIN%switchSD=.false.
      startWithSD=.true.
  else
      allowDIIS=.true.
      startWithSD=.false.
  end if
  
  if(iproc==0) write(*,'(x,a)') '======================== Creation of the basis functions... ========================'

  ! Assign the step size for SD iterations.
  alpha=lin%alphaSD
  adapt=.false.
  iterLoop: do it=1,lin%nItMax
      fnrmMax=0.d0
      fnrm=0.d0
  
      if (iproc==0) then
          write( *,'(1x,a,i0)') repeat('-',77 - int(log(real(it))/log(10.))) // ' iter=', it
      endif
  
      ! Orthonormalize the orbitals.
      if(iproc==0) then
          write(*,'(x,a)', advance='no') 'Orthonormalization... '
      end if
      call orthogonalize(iproc, nproc, lin%orbs, lin%comms, Glr%wfd, phi, input)

      ! Untranspose phi
      call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
  
  
      ! Calculate the unconstrained gradient.
      if(iproc==0) then
          write(*,'(a)', advance='no') 'Hamiltonian application... '
      end if
      call HamiltonianApplicationConfinement(iproc,nproc,at,lin%orbs,lin,input%hx,input%hy,input%hz,rxyz,&
           nlpspd,proj,Glr,ngatherarr,Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),&
           rhopot(1),&
           phi(1),hphi(1),ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU, rxyzParabola, pkernel=pkernelseq)
  
  
      ! Apply the orthoconstraint to the gradient. This subroutine also calculates the trace trH.
      if(iproc==0) then
          write(*,'(a)', advance='no') 'orthoconstraint... '
      end if
      call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)
      call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
      call orthoconstraintNotSymmetric(iproc, nproc, lin%orbs, lin%comms, Glr%wfd, phi, hphi, trH, lagMatDiag)
!!if(iproc==0) then
!!    write(*,*) 'lagMatDiag'
!!    do iorb=1,lin%orbs%norb
!!        write(*,*) lagMatDiag(iorb)
!!    end do
!!end if
  
  
      ! Calculate the norm of the gradient (fnrmArr) and determine the angle between the current gradient and that
      ! of the previous iteration (fnrmOvrlpArr).
      nvctrp=lin%comms%nvctr_par(iproc,1) ! 1 for k-point
      istart=1
      do iorb=1,lin%orbs%norb
          if(it>1) fnrmOvrlpArr(iorb,2)=ddot(nvctrp*orbs%nspinor, hphi(istart), 1, hphiold(istart), 1)
          fnrmArr(iorb,2)=ddot(nvctrp*orbs%nspinor, hphi(istart), 1, hphi(istart), 1)
          istart=istart+nvctrp*orbs%nspinor
      end do
      call mpi_allreduce(fnrmArr(1,2), fnrmArr(1,1), lin%orbs%norb, mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
      call mpi_allreduce(fnrmOvrlpArr(1,2), fnrmOvrlpArr(1,1), lin%orbs%norb, mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
  
      ! Keep the gradient for the next iteration.
      if(it>1) then
          call dcopy(lin%orbs%norb, fnrmArr(1,1), 1, fnrmOldArr(1), 1)
      end if
  
      ! Determine the gradient norm and its maximal component. In addition, adapt the
      ! step size for the steepest descent minimization (depending on the angle 
      ! between the current gradient and the one from the previous iteration).
      ! This is of course only necessary if we are using steepest descent and not DIIS.
      do iorb=1,lin%orbs%norb
          fnrm=fnrm+fnrmArr(iorb,1)
          if(fnrmArr(iorb,1)>fnrmMax) fnrmMax=fnrmArr(iorb,1)
          if(it>1 .and. diisLIN%idsx==0 .and. .not.diisLIN%switchSD) then
          ! Adapt step size for the steepest descent minimization.
              tt=fnrmOvrlpArr(iorb,1)/sqrt(fnrmArr(iorb,1)*fnrmOldArr(iorb))
              if(tt>.7d0) then
                  alpha(iorb)=alpha(iorb)*1.05d0
              else
                  alpha(iorb)=alpha(iorb)*.5d0
              end if
          end if
      end do
      fnrm=sqrt(fnrm)
      fnrmMax=sqrt(fnrmMax)
      ! Copy the gradient (will be used in the next iteration to adapt the step size).
      call dcopy(lin%orbs%norb*nvctrp*orbs%nspinor, hphi(1), 1, hphiold(1), 1)
  
      ! Untranspose hphi.
      call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)

  
      ! Adapt the preconditioning constant
      if(fnrmMax<1.d-9) then
          if(.not.adapt .and. iproc==0) then
              write(*,'(x,a)') 'Adapting the preconditioning constant from now on'
              adapt=.true.
          end if
          do iorb=1,lin%orbs%norb
              lin%orbs%eval(iorb)=lagMatDiag(iorb)
          end do
      end if
  

      ! Precondition the gradient
      if(iproc==0) then
          write(*,'(a)') 'preconditioning. '
      end if
      gnrm=1.d3 ; gnrm_zero=1.d3
      call choosePreconditioner(iproc, nproc, lin%orbs, lin, Glr, input%hx, input%hy, input%hz, &
          lin%nItPrecond, hphi, at%nat, rxyz, at, it)

      ! Determine the mean step size for steepest descent iterations.
      tt=sum(alpha)
      meanAlpha=tt/dble(lin%orbs%norb)
  
      ! Write some informations to the screen.
      if(iproc==0) write(*,'(x,a,i6,2es15.7,f17.10)') 'iter, fnrm, fnrmMax, trace', it, fnrm, fnrmMax, trH
      if(iproc==0) write(1000,'(i6,2es15.7,f18.10,es12.4)') it, fnrm, fnrmMax, trH, meanAlpha
      if(fnrmMax<lin%convCrit .or. it>=lin%nItMax) then
          if(it>=lin%nItMax) then
              if(iproc==0) write(*,'(x,a,i0,a)') 'WARNING: not converged within ', it, &
                  ' iterations! Exiting loop due to limitations of iterations.'
              if(iproc==0) write(*,'(x,a,2es15.7,f12.7)') 'Final values for fnrm, fnrmMax, trace: ', fnrm, fnrmMax, trH
              infoBasisFunctions=1
          else
              if(iproc==0) then
                  write(*,'(x,a,i0,a,2es15.7,f12.7)') 'converged in ', it, ' iterations.'
                  write (*,'(x,a,2es15.7,f12.7)') 'Final values for fnrm, fnrmMax, trace: ', fnrm, fnrmMax, trH
              end if
              infoBasisFunctions=0
          end if
          if(iproc==0) write(*,'(x,a)') '============================= Basis functions created. ============================='
          call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
          if(lin%plotBasisFunctions) then
              call plotOrbitals(iproc, lin%orbs, Glr, phi, at%nat, rxyz, lin%onWhichAtom, .5d0*input%hx, &
                  .5d0*input%hy, .5d0*input%hz, 1)
          end if
          exit iterLoop
      end if
  
  
      call DIISorSD()
      if(iproc==0) then
          if(diisLIN%idsx>0) then
              write(*,'(x,3(a,i0))') 'DIIS informations: history length=',diisLIN%idsx, ', consecutive failures=', &
                  icountDIISFailureCons, ', total failures=', icountDIISFailureTot
          else
              if(allowDIIS) then
                  message='y'
              else
                  message='n'
              end if
              write(*,'(x,a,es9.3,a,i0,a,a)') 'steepest descent informations: mean alpha=', meanAlpha, &
              ', consecutive successes=', icountSDSatur, ', DIIS=', message
          end if
      end if
      if(.not. diisLIN%switchSD) call improveOrbitals()
  
  
  end do iterLoop


  call deallocateLocalArrays()

contains

    subroutine initializeDIISParameters(idsxHere)
    ! Purpose:
    ! ========
    !   Initializes all parameters needed for the DIIS procedure.
    !
    ! Calling arguments
    !   idsx    DIIS history length
    !
    implicit none
    
    ! Calling arguments
    integer:: idsxHere

      diisLIN%switchSD=.false.
      diisLIN%idiistol=0
      diisLIN%mids=1
      diisLIN%ids=0
      diisLIN%idsx=idsxHere
      diisLIN%energy_min=1.d10
      diisLIN%energy_old=1.d10
      diisLIN%energy=1.d10
      diisLIN%alpha=2.d0
      call allocate_diis_objects(diisLIN%idsx, lin%orbs%npsidim, 1, diisLIN, subname) ! 1 for k-points

    end subroutine initializeDIISParameters


    subroutine DIISorSD()
    !
    ! Purpose:
    ! ========
    !   This subroutine decides whether one should use DIIS or variable step size
    !   steepest descent to improve the orbitals. In the beginning we start with DIIS
    !   with history length lin%DIISHistMax. If DIIS becomes unstable, we switch to
    !   steepest descent. If the steepest descent iterations are successful, we switch
    !   back to DIIS, but decrease the DIIS history length by one. However the DIIS
    !   history length is limited to be larger or equal than lin%DIISHistMin.
    !


      ! First there are some checks whether the force is small enough to allow DIIS.

      ! Decide whether the force is small eneough to allow DIIS
      if(fnrmMax<lin%startDIIS .and. .not.allowDIIS) then
          allowDIIS=.true.
          if(iproc==0) write(*,'(x,a)') 'The force is small enough to allow DIIS.'
          ! This is to get the correct DIIS history 
          ! (it is chosen as max(lin%DIISHistMin,lin%DIISHistMax-icountSwitch).
          icountSwitch=icountSwitch-1
      else if(fnrmMax>lin%startDIIS .and. allowDIIS) then
          allowDIIS=.false.
          if(iproc==0) write(*,'(x,a)') 'The force is too large to allow DIIS.'
      end if    

      ! Switch to SD if the flag indicating that we should start with SD is true.
      ! If this is the case, this flag is set to false, since this flag concerns only the beginning.
      if(startWithSD .and. diisLIN%idsx>0) then
          call deallocate_diis_objects(diisLIN, subname)
          diisLIN%idsx=0
          diisLIN%switchSD=.false.
          startWithSD=.false.
      end if

      ! Decide whether we should switch from DIIS to SD in case we are using DIIS and it 
      ! is not allowed.
      if(.not.startWithSD .and. .not.allowDIIS .and. diisLIN%idsx>0) then
          if(iproc==0) write(*,'(x,a,es10.3)') 'The force is too large, switch to SD with stepsize', alpha(1)
          call deallocate_diis_objects(diisLIN, subname)
          diisLIN%idsx=0
          diisLIN%switchSD=.true.
      end if

      ! If we swicthed to SD in the previous iteration, reset this flag.
      if(diisLIN%switchSD) diisLIN%switchSD=.false.

      ! Now come some checks whether the trace is descreasing or not. This further decides
      ! whether we should use DIIS or SD.

      ! Determine wheter the trace is decreasing (as it should) or increasing.
      ! This is done by comparing the current value with diisLIN%energy_min, which is
      ! the minimal value of the trace so far.
      if(trH<=diisLIN%energy_min) then
          ! Everything ok
          diisLIN%energy_min=trH
          diisLIN%switchSD=.false.
          itBest=it
          icountSDSatur=icountSDSatur+1
          icountDIISFailureCons=0

          ! If we are using SD (i.e. diisLIN%idsx==0) and the trace has been decreasing
          ! for at least 10 iterations, switch to DIIS. However the history length is decreased.
          if(icountSDSatur>=10 .and. diisLIN%idsx==0 .and. allowDIIS) then
              icountSwitch=icountSwitch+1
              idsx=max(lin%DIISHistMin,lin%DIISHistMax-icountSwitch)
              if(idsx>0) then
                  if(iproc==0) write(*,'(x,a,i0)') 'switch to DIIS with new history length ', idsx
                  call initializeDIISParameters(idsx)
                  icountDIISFailureTot=0
                  icountDIISFailureCons=0
              end if
          end if
      else
          ! The trace is growing.
          ! Count how many times this occurs and (if we are using DIIS) switch to SD after 3 
          ! total failures or after 2 consecutive failures.
          icountDIISFailureCons=icountDIISFailureCons+1
          icountDIISFailureTot=icountDIISFailureTot+1
          icountSDSatur=0
          if((icountDIISFailureCons>=2 .or. icountDIISFailureTot>=3) .and. diisLIN%idsx>0) then
              ! Switch back to SD. The initial step size is 1.d0.
              alpha=lin%alphaSD
              if(iproc==0) then
                  if(icountDIISFailureCons>=2) write(*,'(x,a,i0,a,es10.3)') 'DIIS failed ', &
                      icountDIISFailureCons, ' times consecutievly. Switch to SD with stepsize', alpha(1)
                  if(icountDIISFailureTot>=3) write(*,'(x,a,i0,a,es10.3)') 'DIIS failed ', &
                      icountDIISFailureTot, ' times in total. Switch to SD with stepsize', alpha(1)
              end if
              ! Try to get back the orbitals of the best iteration. This is possible if
              ! these orbitals are still present in the DIIS history.
              if(it-itBest<diisLIN%idsx) then
                 if(iproc==0) then
                     if(iproc==0) write(*,'(x,a,i0,a)')  'Recover the orbitals from iteration ', &
                         itBest, ' which are the best so far.'
                 end if
                 ii=modulo(diisLIN%mids-(it-itBest),diisLIN%mids)
                 nvctrp=lin%comms%nvctr_par(iproc,1) ! 1 for k-point
                 call dcopy(lin%orbs%norb*nvctrp, diisLIN%psidst(ii*nvctrp*lin%orbs%norb+1), 1, phi(1), 1)
              end if
              call deallocate_diis_objects(diisLIN, subname)
              diisLIN%idsx=0
              diisLIN%switchSD=.true.
          end if
      end if

    end subroutine DIISorSD


    subroutine improveOrbitals()
    !
    ! Purpose:
    ! ========
    !   This subroutine improves the basis functions by following the gradient 
    ! For DIIS 
    if (diisLIN%idsx > 0) then
       diisLIN%mids=mod(diisLIN%ids,diisLIN%idsx)+1
       diisLIN%ids=diisLIN%ids+1
    end if

    ! Follow the gradient using steepest descent.
    ! The same, but transposed
    call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)
    
    ! steepest descent
    if(diisLIN%idsx==0) then
        istart=1
        nvctrp=lin%comms%nvctr_par(iproc,1) ! 1 for k-point
        do iorb=1,lin%orbs%norb
            call daxpy(nvctrp*orbs%nspinor, -alpha(iorb), hphi(istart), 1, phi(istart), 1)
            istart=istart+nvctrp*orbs%nspinor
        end do
    else
        ! DIIS
        quiet=.true. ! less output
        call psimix(iproc, nproc, lin%orbs, lin%comms, diisLIN, hphi, phi, quiet)
    end if
    end subroutine improveOrbitals



    subroutine allocateLocalArrays()
    !
    ! Purpose:
    ! ========
    !   This subroutine allocates all local arrays.
    !

      allocate(hphiold(lin%orbs%npsidim), stat=istat)
      call memocc(istat, hphiold, 'hphiold', subname)

      allocate(alpha(lin%orbs%norb), stat=istat)
      call memocc(istat, alpha, 'alpha', subname)

      allocate(fnrmArr(lin%orbs%norb,2), stat=istat)
      call memocc(istat, fnrmArr, 'fnrmArr', subname)

      allocate(fnrmOldArr(lin%orbs%norb), stat=istat)
      call memocc(istat, fnrmOldArr, 'fnrmOldArr', subname)

      allocate(fnrmOvrlpArr(lin%orbs%norb,2), stat=istat)
      call memocc(istat, fnrmOvrlpArr, 'fnrmOvrlpArr', subname)

      allocate(phiWork(size(phi)), stat=istat)
      call memocc(istat, phiWork, 'phiWork', subname)
      
    

    end subroutine allocateLocalArrays


    subroutine deallocateLocalArrays()
    !
    ! Purpose:
    ! ========
    !   This subroutine deallocates all local arrays.
    !

      iall=-product(shape(hphiold))*kind(hphiold)
      deallocate(hphiold, stat=istat)
      call memocc(istat, iall, 'hphiold', subname)
      
      iall=-product(shape(alpha))*kind(alpha)
      deallocate(alpha, stat=istat)
      call memocc(istat, iall, 'alpha', subname)

      iall=-product(shape(fnrmArr))*kind(fnrmArr)
      deallocate(fnrmArr, stat=istat)
      call memocc(istat, iall, 'fnrmArr', subname)

      iall=-product(shape(fnrmOldArr))*kind(fnrmOldArr)
      deallocate(fnrmOldArr, stat=istat)
      call memocc(istat, iall, 'fnrmOldArr', subname)

      iall=-product(shape(fnrmOvrlpArr))*kind(fnrmOvrlpArr)
      deallocate(fnrmOvrlpArr, stat=istat)
      call memocc(istat, iall, 'fnrmOvrlpArr', subname)

      iall=-product(shape(phiWork))*kind(phiWork)
      deallocate(phiWork, stat=istat)
      call memocc(istat, iall, 'phiWork', subname)
      
      ! if diisLIN%idsx==0, these arrays have already been deallocated
      if(diisLIN%idsx>0 .and. lin%DIISHistMax>0) call deallocate_diis_objects(diisLIN,subname)

    end subroutine deallocateLocalArrays


end subroutine getLocalizedBasis






subroutine transformHam(iproc, nproc, orbs, comms, phi, hphi, HamSmall)
!
! Purpose:
! =======
!   Builds the Hamiltonian in the basis of the localized basis functions phi. To do so, it gets all basis
!   functions |phi_i> and H|phi_i> and then calculates H_{ij}=<phi_i|H|phi_j>. The basis functions phi are
!   provided in the transposed form.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc      process ID
!     nproc      total number of processes
!     orbs       type describing the basis functions psi
!     comms      type containing the communication parameters for the physical orbitals phi
!     phi        basis functions 
!     hphi       the Hamiltonian applied to the basis functions 
!   Output arguments:
!   -----------------
!     HamSmall   Hamiltonian in small basis
!
use module_base
use module_types
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc
type(orbitals_data), intent(in) :: orbs
type(communications_arrays), intent(in) :: comms
real(8),dimension(sum(comms%nvctr_par(iproc,1:orbs%nkptsp))*orbs%nspinor,orbs%norb), intent(in) :: phi, hphi
real(8),dimension(orbs%norb,orbs%norb),intent(out):: HamSmall

! Local variables
integer:: istat, ierr, nvctrp, iall
real(8),dimension(:,:),allocatable:: HamTemp
character(len=*),parameter:: subname='transformHam'



  ! Allocate a temporary array if there are several MPI processes
  if(nproc>1) then
      allocate(HamTemp(orbs%norb,orbs%norb), stat=istat)
      call memocc(istat, HamTemp, 'HamTemp', subname)
  end if
  
  ! nvctrp is the amount of each phi hold by the current process
  nvctrp=sum(comms%nvctr_par(iproc,1:orbs%nkptsp))*orbs%nspinor
  
  ! Build the Hamiltonian. In the parallel case, each process writes its Hamiltonian in HamTemp
  ! and a mpi_allreduce sums up the contribution from all processes.
  if(nproc==1) then
      call dgemm('t', 'n', orbs%norb, orbs%norb, nvctrp, 1.d0, phi(1,1), nvctrp, &
                 hphi(1,1), nvctrp, 0.d0, HamSmall(1,1), orbs%norb)
  else
      call dgemm('t', 'n', orbs%norb, orbs%norb, nvctrp, 1.d0, phi(1,1), nvctrp, &
                 hphi(1,1), nvctrp, 0.d0, HamTemp(1,1), orbs%norb)
  end if
  if(nproc>1) then
      call mpi_allreduce(HamTemp(1,1), HamSmall(1,1), orbs%norb**2, mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
  end if
  
  if(nproc>1) then
     iall=-product(shape(HamTemp))*kind(HamTemp)
     deallocate(HamTemp,stat=istat)
     call memocc(istat, iall, 'HamTemp', subname)
  end if

end subroutine transformHam




subroutine diagonalizeHamiltonian(iproc, nproc, orbs, HamSmall, eval)
!
! Purpose:
! ========
!   Diagonalizes the Hamiltonian HamSmall and makes sure that all MPI processes give
!   the same result. This is done by requiring that the first entry of each vector
!   is positive.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc     process ID
!     nproc     number of MPI processes
!     orbs      type describing the physical orbitals psi
!   Input / Putput arguments
!     HamSmall  on input: the Hamiltonian
!               on exit: the eigenvectors
!   Output arguments
!     eval      the associated eigenvalues 
!
use module_base
use module_types
implicit none

! Calling arguments
integer:: iproc, nproc
type(orbitals_data), intent(inout) :: orbs
real(8),dimension(orbs%norb, orbs%norb):: HamSmall
real(8),dimension(orbs%norb):: eval

! Local variables
integer:: lwork, info, istat, iall, i, iorb, jorb
real(8),dimension(:),allocatable:: work
character(len=*),parameter:: subname='diagonalizeHamiltonian'

  ! Get the optimal work array size
  lwork=-1 
  allocate(work(1), stat=istat)
  call memocc(istat, work, 'work', subname)
  call dsyev('v', 'l', orbs%norb, HamSmall(1,1), orbs%norb, eval(1), work(1), lwork, info) 
  lwork=work(1) 

  ! Deallocate the work array ane reallocate it with the optimal size
  iall=-product(shape(work))*kind(work)
  deallocate(work, stat=istat) ; if(istat/=0) stop 'ERROR in deallocating work' 
  call memocc(istat, iall, 'work', subname)
  allocate(work(lwork), stat=istat) ; if(istat/=0) stop 'ERROR in allocating work' 
  call memocc(istat, work, 'work', subname)

  ! Diagonalize the Hamiltonian
  call dsyev('v', 'l', orbs%norb, HamSmall(1,1), orbs%norb, eval(1), work(1), lwork, info) 

  ! Deallocate the work array.
  iall=-product(shape(work))*kind(work)
  deallocate(work, stat=istat) ; if(istat/=0) stop 'ERROR in deallocating work' 
  call memocc(istat, iall, 'work', subname)
  
  ! Make sure that the eigenvectors are the same for all MPI processes. To do so, require that 
  ! the first entry of each vector is positive.
  do iorb=1,orbs%norb
      if(HamSmall(1,iorb)<0.d0) then
          do jorb=1,orbs%norb
              HamSmall(jorb,iorb)=-HamSmall(jorb,iorb)
          end do
      end if
  end do


end subroutine diagonalizeHamiltonian





subroutine buildWavefunction(iproc, nproc, orbs, orbsLIN, comms, commsLIN, phi, psi, HamSmall)
!
! Purpose:
! =======
!   Builds the physical orbitals psi as a linear combination of the basis functions phi. The coefficients
!   for this linear combination are obtained by diagonalizing the Hamiltonian matrix HamSmall.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc      process ID
!     nproc      total number of processes
!     orbs       type describing the physical orbitals psi
!     orbsLIN    type describing the basis functions phi
!     comms      type containing the communication parameters for the physical orbitals psi
!     commsLIN   type containing the communication parameters for the basis functions phi
!     phi        the basis functions 
!     HamSmall   the  Hamiltonian matrix
!   Output arguments:
!   -----------------
!     psi        the physical orbitals 
!

use module_base
use module_types
implicit none

! Calling arguments
integer:: iproc, nproc
type(orbitals_data), intent(in) :: orbs
type(orbitals_data), intent(in) :: orbsLIN
type(communications_arrays), intent(in) :: comms
type(communications_arrays), intent(in) :: commsLIN
real(8),dimension(sum(commsLIN%nvctr_par(iproc,1:orbsLIN%nkptsp))*orbsLIN%nspinor,orbsLIN%norb) :: phi
real(8),dimension(sum(comms%nvctr_par(iproc,1:orbs%nkptsp))*orbs%nspinor,orbs%norb) :: psi
real(8),dimension(orbsLIN%norb,orbsLIN%norb):: HamSmall

! Local variables
integer:: nvctrp


  nvctrp=sum(comms%nvctr_par(iproc,1:orbs%nkptsp))*orbs%nspinor
  call dgemm('n', 'n', nvctrp, orbs%norb, orbsLIN%norb, 1.d0, phi(1,1), nvctrp, HamSmall(1,1), &
             orbsLIN%norb, 0.d0, psi(1,1), nvctrp)
  

end subroutine buildWavefunction





subroutine buildWavefunctionModified(iproc, nproc, orbs, orbsLIN, comms, commsLIN, phi, psi, coeff)
!
! Purpose:
! =======
!   Builds the physical orbitals psi as a linear combination of the basis functions phi. The coefficients
!   for this linear combination are obtained by diagonalizing the Hamiltonian matrix HamSmall.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc      process ID
!     nproc      total number of processes
!     orbs       type describing the physical orbitals psi
!     orbsLIN    type describing the basis functions phi
!     comms      type containing the communication parameters for the physical orbitals psi
!     commsLIN   type containing the communication parameters for the basis functions phi
!     phi        the basis functions 
!     coeff      the coefficients for the linear combination
!   Output arguments:
!   -----------------
!     psi        the physical orbitals 
!

use module_base
use module_types
implicit none

! Calling arguments
integer:: iproc, nproc
type(orbitals_data), intent(in) :: orbs
type(orbitals_data), intent(in) :: orbsLIN
type(communications_arrays), intent(in) :: comms
type(communications_arrays), intent(in) :: commsLIN
real(8),dimension(sum(commsLIN%nvctr_par(iproc,1:orbsLIN%nkptsp))*orbsLIN%nspinor,orbsLIN%norb) :: phi
real(8),dimension(sum(comms%nvctr_par(iproc,1:orbs%nkptsp))*orbs%nspinor,orbs%norb) :: psi
real(8),dimension(orbsLIN%norb,orbs%norb):: coeff

! Local variables
integer:: nvctrp


  nvctrp=sum(comms%nvctr_par(iproc,1:orbs%nkptsp))*orbs%nspinor
  call dgemm('n', 'n', nvctrp, orbs%norb, orbsLIN%norb, 1.d0, phi(1,1), nvctrp, coeff(1,1), &
             orbsLIN%norb, 0.d0, psi(1,1), nvctrp)
  

end subroutine buildWavefunctionModified


subroutine getMatrixElements(iproc, nproc, Glr, lin, phi, hphi, matrixElements)
!
! Purpose:
! ========
!
! Calling arguments:
! ==================
!
use module_base
use module_types
use module_interfaces
implicit none

! Calling arguments
integer,intent(in):: iproc, nproc
type(locreg_descriptors),intent(in):: Glr
type(linearParameters),intent(in):: lin
real(8),dimension(lin%orbs%npsidim),intent(inout):: phi, hphi
real(8),dimension(lin%orbs%norb,lin%orbs%norb,2),intent(out):: matrixElements

! Local variables
integer:: istart, jstart, nvctrp, iorb, jorb, istat, iall, ierr
real(8):: ddot
real(8),dimension(:),pointer:: phiWork
character(len=*),parameter:: subname='getMatrixELements'


  allocate(phiWork(lin%orbs%npsidim), stat=istat)
  call memocc(istat, phiWork, 'phiWork', subname)


  call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
  call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)

  matrixElements=0.d0

  ! Calculate <phi_i|H_j|phi_j>
  nvctrp=sum(lin%comms%nvctr_par(iproc,1:lin%orbs%nkptsp))*lin%orbs%nspinor
  jstart=1
  do jorb=1,lin%orbs%norb
      istart=1
      do iorb=1,lin%orbs%norb
          matrixElements(iorb,jorb,2)=ddot(nvctrp, phi(istart), 1, hphi(jstart), 1)
          istart=istart+nvctrp
      end do
      jstart=jstart+nvctrp
  end do
  call mpi_allreduce(matrixElements(1,1,2), matrixElements(1,1,1), lin%orbs%norb**2, &
      mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
!!if(iproc==0) then
!!    write(*,*) 'matrix Elements'
!!    do iorb=1,lin%orbs%norb
!!        write(*,'(80es9.2)') (matrixElements(iorb,jorb,1), jorb=1,lin%orbs%norb)
!!    end do
!!end if


  call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
  call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)

  iall=-product(shape(phiWork))*kind(phiWork)
  deallocate(phiWork)
  call memocc(istat, iall, 'phiWork', subname)


  !!! Calculate the modified band structure energy
  !!tt=0.d0
  !!do iorb=1,orbs%norb
  !!    do jorb=1,orbsLIN%norb
  !!        do korb=1,orbsLIN%norb
  !!            tt=tt+HamSmall(korb,iorb)*HamSmall(jorb,iorb)*matrixElements(korb,jorb,1)
  !!        end do
  !!    end do
  !!end do
  !!if(present(ebs_mod)) then
  !!    if(nspin==1) ebs_mod=2.d0*tt ! 2 for closed shell
  !!end if



end subroutine getMatrixElements





subroutine modifiedBSEnergy(nspin, orbs, lin, HamSmall, matrixElements, ebsMod)
!
! Purpose:
! ========
!
! Calling arguments:
! ==================
!
use module_base
use module_types
implicit none

! Calling arguments
integer,intent(in):: nspin
type(orbitals_data),intent(in) :: orbs
type(linearParameters),intent(in):: lin
real(8),dimension(lin%orbs%norb,lin%orbs%norb),intent(in):: HamSmall, matrixElements
real(8),intent(out):: ebsMod

! Local variables
integer:: iorb, jorb, korb
real(8):: tt

  ! Calculate the modified band structure energy
  tt=0.d0
  do iorb=1,orbs%norb
      do jorb=1,lin%orbs%norb
          do korb=1,lin%orbs%norb
              tt=tt+HamSmall(korb,iorb)*HamSmall(jorb,iorb)*matrixElements(korb,jorb)
          end do
      end do
  end do
  if(nspin==1) then
      ebsMod=2.d0*tt ! 2 for closed shell
  else
      ebsMod=tt
  end if



end subroutine modifiedBSEnergy





subroutine modifiedBSEnergyModified(nspin, orbs, lin, coeff, matrixElements, ebsMod)
!
! Purpose:
! ========
!
! Calling arguments:
! ==================
!
use module_base
use module_types
implicit none

! Calling arguments
integer,intent(in):: nspin
type(orbitals_data),intent(in) :: orbs
type(linearParameters),intent(in):: lin
real(8),dimension(lin%orbs%norb,orbs%norb),intent(in):: coeff
real(8),dimension(lin%orbs%norb,lin%orbs%norb),intent(in):: matrixElements
real(8),intent(out):: ebsMod

! Local variables
integer:: iorb, jorb, korb
real(8):: tt

  ! Calculate the modified band structure energy
  tt=0.d0
  do iorb=1,orbs%norb
      do jorb=1,lin%orbs%norb
          do korb=1,lin%orbs%norb
              tt=tt+coeff(korb,iorb)*coeff(jorb,iorb)*matrixElements(korb,jorb)
          end do
      end do
  end do
  if(nspin==1) then
      ebsMod=2.d0*tt ! 2 for closed shell
  else
      ebsMod=tt
  end if



end subroutine modifiedBSEnergyModified












subroutine optimizeCoefficients(iproc, orbs, lin, matrixElements, coeff)
!
! Purpose:
! ========
!   Determines the optimal coefficients which minimize the modified band structure energy, i.e.
!   E = sum_{i}sum_{k,l}c_{ik}c_{il}<phi_k|H_l|phi_l>.
!   This is done by a steepest descen minimization using the gradient of the above expression with
!   respect to the coefficients c_{ik}.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc            process ID
!     orbs             type describing the physical orbitals psi
!     lin              type containing parameters for the linear version
!     matrixElements   contains the matrix elements <phi_k|H_l|phi_l>
!   Output arguments:
!   -----------------
!     coeff            the optimized coefficients 
use module_base
use module_types
implicit none

! Calling arguments
integer:: iproc
type(orbitals_data):: orbs
type(linearParameters):: lin
real(8),dimension(lin%orbs%norb,lin%orbs%norb):: matrixElements
real(8),dimension(lin%orbs%norb,orbs%norb):: coeff

! Local variables
integer:: it, iorb, jorb, k, l, istat, iall, korb, ierr
real(8):: tt, fnrm, ddot, dnrm2, meanAlpha, cosangle, ebsMod
real(8),dimension(:,:),allocatable:: grad, gradOld, lagMat
real(8),dimension(:),allocatable:: alpha
character(len=*),parameter:: subname='optimizeCoefficients'
logical:: converged


allocate(grad(lin%orbs%norb,orbs%norb), stat=istat)
call memocc(istat, grad, 'grad', subname)
allocate(gradOld(lin%orbs%norb,orbs%norb), stat=istat)
call memocc(istat, gradOld, 'gradOld', subname)
allocate(lagMat(orbs%norb,orbs%norb), stat=istat)
call memocc(istat, lagMat, 'lagMat', subname)
allocate(alpha(orbs%norb), stat=istat)
call memocc(istat, alpha, 'alpha', subname)

! Do everything only on the root and then broadcast to all processes.
processIf: if(iproc==0) then
    

    ! Orthogonalize (Gram-Schmidt)
    do iorb=1,orbs%norb
        do jorb=1,iorb-1
            tt=ddot(lin%orbs%norb, coeff(1,iorb), 1, coeff(1,jorb), 1)
            call daxpy(lin%orbs%norb, -tt, coeff(1,jorb), 1, coeff(1,iorb), 1)
        end do
        tt=dnrm2(lin%orbs%norb, coeff(1,iorb), 1)
        call dscal(lin%orbs%norb, 1/tt, coeff(1,iorb), 1)
    end do
    
    ! Initial step size
    alpha=5.d-3

    converged=.false.

    ! The optimization loop
    iterLoop: do it=1,lin%nItCoeff

        ! Calculate the gradient.
        meanAlpha=0.d0
        grad=0.d0
        do iorb=1,orbs%norb
            do l=1,lin%orbs%norb
                do k=1,lin%orbs%norb
                    grad(l,iorb)=grad(l,iorb)+coeff(k,iorb)*(matrixElements(k,l)+matrixElements(l,k))
                end do
            end do
            if(it>1) then
                cosangle=ddot(lin%orbs%norb, grad(1,iorb), 1, gradOld(1,iorb), 1)
                cosangle=cosangle/dnrm2(lin%orbs%norb, grad(1,iorb), 1)
                cosangle=cosangle/dnrm2(lin%orbs%norb, gradOld(1,iorb), 1)
                if(cosangle>.8d0) then
                    alpha(iorb)=alpha(iorb)*1.05d0
                else
                    alpha(iorb)=alpha(iorb)*.5d0
                end if
            end if
            call dcopy(lin%orbs%norb, grad(1,iorb), 1, gradOld(1,iorb), 1)
            meanAlpha=meanAlpha+alpha(iorb)
        end do
        meanAlpha=meanAlpha/orbs%norb
    
    
        ! Orthoconstraint on gradient
        lagMat=0.d0
        do iorb=1,orbs%norb
            do jorb=1,orbs%norb
                do k=1,lin%orbs%norb
                    lagMat(iorb,jorb)=lagMat(iorb,jorb)+coeff(k,iorb)*grad(k,jorb)
                end do
            end do
        end do
        do iorb=1,orbs%norb
            do k=1,lin%orbs%norb
                do jorb=1,orbs%norb
                    grad(k,iorb)=grad(k,iorb)-.5d0*(lagMat(iorb,jorb)*coeff(k,jorb)+lagMat(jorb,iorb)*coeff(k,jorb))
                end do
            end do
        end do
    
        
        ! Improve the coefficients.
        fnrm=0.d0
        do iorb=1,orbs%norb
            fnrm=fnrm+dnrm2(lin%orbs%norb, grad(1,iorb), 1)
            do l=1,lin%orbs%norb
                coeff(l,iorb)=coeff(l,iorb)-alpha(iorb)*grad(l,iorb)
            end do
        end do
    
        ! Calculate the modified band structure energy
        ebsMod=0.d0
        do iorb=1,orbs%norb
            do jorb=1,lin%orbs%norb
                do korb=1,lin%orbs%norb
                    ebsMod=ebsMod+coeff(korb,iorb)*coeff(jorb,iorb)*matrixElements(korb,jorb)
                end do
            end do
        end do
    
        ! Multiply the energy with a factor of 2 due to closed-shell
        if(iproc==0) write(*,'(x,a,4x,i0,es12.4,3x,es10.3, es19.9)') 'iter, fnrm, meanAlpha, Energy', it, fnrm, meanAlpha, 2.d0*ebsMod
        !if(iproc==0) write(99,'(i0,es12.4,3x,es10.3, es15.5)')  it, fnrm, meanAlpha, 2.d0*ebsMod
        
        ! Orthogonalize (Gram-Schmidt)
        do iorb=1,orbs%norb
            do jorb=1,iorb-1
                tt=ddot(lin%orbs%norb, coeff(1,iorb), 1, coeff(1,jorb), 1)
                call daxpy(lin%orbs%norb, -tt, coeff(1,jorb), 1, coeff(1,iorb), 1)
            end do
            tt=dnrm2(lin%orbs%norb, coeff(1,iorb), 1)
            call dscal(lin%orbs%norb, 1/tt, coeff(1,iorb), 1)
        end do
        if(fnrm<lin%convCritCoeff) then
            if(iproc==0) write(*,'(x,a,i0,a)') 'converged in ', it, ' iterations.'
            if(iproc==0) write(*,'(3x,a,2es14.5)') 'Final values for fnrm, Energy:', fnrm, 2.d0*ebsMod
            converged=.true.
            exit
        end if
    end do iterLoop

    if(.not.converged) then
        if(iproc==0) write(*,'(x,a,i0,a)') 'WARNING: not converged within ', it, &
            ' iterations! Exiting loop due to limitations of iterations.'
        if(iproc==0) write(*,'(x,a,2es15.7,f12.7)') 'Final values for fnrm, Energy: ', fnrm, 2.d0*ebsMod
    end if
end if processIf


! Now broadcast the result to all processes
call mpi_bcast(coeff(1,1), lin%orbs%norb*orbs%norb, mpi_double_precision, 0, mpi_comm_world, ierr)

iall=-product(shape(grad))*kind(grad)
deallocate(grad, stat=istat)
call memocc(istat, iall, 'grad', subname)

iall=-product(shape(gradOld))*kind(gradOld)
deallocate(gradOld, stat=istat)
call memocc(istat, iall, 'gradOld', subname)

iall=-product(shape(lagMat))*kind(lagMat)
deallocate(lagMat, stat=istat)
call memocc(istat, iall, 'lagMat', subname)

iall=-product(shape(alpha))*kind(alpha)
deallocate(alpha, stat=istat)
call memocc(istat, iall, 'alpha', subname)

end subroutine optimizeCoefficients







subroutine getLocalizedBasisNew(iproc, nproc, at, orbs, Glr, input, lin, rxyz, nspin, nlpspd, &
    proj, nscatterarr, ngatherarr, rhopot, GPU, pkernelseq, phi, hphi, trH, rxyzParabola, coeff, &
    infoBasisFunctions)
!
! Purpose:
! ========
!   Calculates the localized basis functions phi. These basis functions are obtained by adding a
!   quartic potential centered on the atoms to the ordinary Hamiltonian. The eigenfunctions are then
!   determined by minimizing the trace until the gradient norm is below the convergence criterion.
!
! Calling arguments:
! ==================
!   Input arguments:
!   ----------------
!     iproc           process ID
!     nproc           total number of processes
!     at              type containing the paraneters for the atoms
!     orbs            type describing the physical orbitals psi
!     Glr             type describing the localization region
!     input           type containing some very general parameters
!     lin             type containing parameters for the linear version
!     rxyz            the atomic positions
!     nspin           npsin==1 -> closed shell; npsin==2 -> spin polarized
!     nlpsp           ???
!     proj            ???
!     nscatterarr     ???
!     ngatherarr      ???
!     rhopot          the charge density
!     GPU             parameters for GPUs
!     pkernelseq      ???
!     rxyzParab       the center of the confinement potential (at the moment identical rxyz)
!     n3p             ???
!  Input/Output arguments
!  ---------------------
!     phi             the localized basis functions. It is assumed that they have been initialized
!                     somewhere else
!   Output arguments
!   ----------------
!     hphi            the modified Hamiltonian applied to phi
!     trH             the trace of the Hamiltonian
!     infoBasisFunctions  indicates wheter the basis functions converged to the specified limit (value is 0)
!                         or whether the iteration stopped due to the iteration limit (value is -1). This info
!                         is returned by 'getLocalizedBasis'
!
! Calling arguments:
!   Input arguments
!   Output arguments
!    phi   the localized basis functions
!
use module_base
use module_types
use module_interfaces, except_this_one => getLocalizedBasisNew
!  use Poisson_Solver
!use allocModule
implicit none

! Calling arguments
integer:: iproc, nproc, infoBasisFunctions
type(atoms_data), intent(in) :: at
type(orbitals_data):: orbs
type(locreg_descriptors), intent(in) :: Glr
type(input_variables):: input
type(linearParameters):: lin
real(8),dimension(3,at%nat):: rxyz, rxyzParabola
integer:: nspin
type(nonlocal_psp_descriptors), intent(in) :: nlpspd
real(wp), dimension(nlpspd%nprojel), intent(in) :: proj
integer, dimension(0:nproc-1,4), intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
integer, dimension(0:nproc-1,2), intent(in) :: ngatherarr 
real(dp), dimension(*), intent(inout) :: rhopot
type(GPU_pointers), intent(inout) :: GPU
real(dp), dimension(:), pointer :: pkernelseq
real(8),dimension(lin%orbs%npsidim):: phi, hphi
real(8),dimension(lin%orbs%norb,orbs%norb):: coeff
real(8):: trH

! Local variables
real(8) ::epot_sum, ekin_sum, eexctX, eproj_sum
real(8):: tt, ddot, fnrm, fnrmMax, meanAlpha, gnrm, gnrm_zero, gnrmMax
integer:: iorb, icountSDSatur, icountSwitch, idsx, icountDIISFailureTot, icountDIISFailureCons, itBest
integer:: istat, istart, ierr, ii, it, nbasisPerAtForDebug, ncong, iall, nvctrp
real(8),dimension(:),allocatable:: hphiold, alpha, fnrmOldArr
real(8),dimension(:,:),allocatable:: HamSmall, fnrmArr, fnrmOvrlpArr
real(8),dimension(:),pointer:: phiWork
logical:: quiet, allowDIIS, startWithSD
character(len=*),parameter:: subname='getLocalizedBasis'
character(len=1):: message
type(diis_objects):: diisLIN

real(8),dimension(:,:),allocatable:: lagMult
real(8),dimension(:,:,:),allocatable:: ovrlp
integer:: jstart, jorb, lorb, korb, kstart, lstart, lorb2, centralAt, jproc, centralAtPrev
real(8),dimension(:),allocatable:: phiGrad, hphi2, phiGradold, lagMatDiag
real(8):: ebsMod, tt2, matEl
!real(8),dimension(:,:),allocatable:: coeff

!allocate(coeff(lin%orbs%norb,orbs%norb), stat=istat) ; if(istat/=0) stop 'ERROR in allocating coeff'

allocate(lagMult(lin%orbs%norb,lin%orbs%norb), stat=istat)
lagMult=1.d-1
allocate(ovrlp(lin%orbs%norb,lin%orbs%norb,2), stat=istat)
allocate(lagMatDiag(lin%orbs%norb), stat=istat)

  allocate(phiGrad(lin%orbs%npsidim), stat=istat) ; if(istat/=0) stop 'ERROR in allocating phiGrad'
  allocate(hphi2(lin%orbs%npsidim), stat=istat)
  allocate(phiGradold(lin%orbs%npsidim), stat=istat)

  ! Allocate all local arrays
  call allocateLocalArrays()
  
  ! Initialize the DIIS parameters 
  icountSDSatur=0
  icountSwitch=0
  icountDIISFailureTot=0
  icountDIISFailureCons=0
  call initializeDIISParameters(lin%DIISHistMax)
  if(lin%startWithSD) then
      allowDIIS=.false.
      diisLIN%switchSD=.false.
      startWithSD=.true.
  else
      allowDIIS=.true.
      startWithSD=.false.
  end if
  
  if(iproc==0) write(*,'(x,a)') '======================== Creation of the basis functions... ========================'

  ! The basis functions phi are provided in direct (i.e. not transposed) form, but the loop iterLoop
  !  expects them to be transposed.
  call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)

  ! Assign the step size for SD iterations.
  alpha=lin%alphaSD
  iterLoop: do it=1,lin%nItMax
      fnrmMax=0.d0
      fnrm=0.d0
  
      if (iproc==0) then
          write( *,'(1x,a,i0)') repeat('-',77 - int(log(real(it))/log(10.))) // ' iter=', it
      endif
  
      ! Orthonormalize the orbitals.
      if(iproc==0) then
          write(*,'(x,a)', advance='no') 'Orthonormalization... '
      end if
      call orthogonalize(iproc, nproc, lin%orbs, lin%comms, Glr%wfd, phi, input)

      ! Untranspose phi
      call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
  
  
      ! Calculate the unconstrained gradient.
      if(iproc==0) then
          write(*,'(a)', advance='no') 'Hamiltonian application... '
      end if
      call HamiltonianApplicationConfinement(iproc,nproc,at,lin%orbs,lin,input%hx,input%hy,input%hz,rxyz,&
           nlpspd,proj,Glr,ngatherarr,Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),&
           rhopot(1),&
           phi(1),hphi(1),ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU, rxyzParabola, pkernel=pkernelseq)
  
      ! Calculate the modified gradient
      call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)
      call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
      nvctrp=lin%comms%nvctr_par(iproc,1) ! 1 for k-point
      lstart=1
      phiGrad=0.d0
      ebsMod=0.d0
      lorb=0
      centralAtPrev=-1
      do jproc=0,nproc-1
          do lorb2=1,lin%orbs%norb_par(jproc)
              lorb=lorb+1
              if(iproc==jproc) centralAt=lin%onWhichAtom(lorb2)
              call mpi_bcast(centralAt, 1, mpi_integer, jproc, mpi_comm_world, ierr)
         !if(iproc==0) write(*,*) 'lorb, centralAt', lorb, centralAt
              ! Apply H_l to all orbitals (also those not centered on atom lin%onWhichAtom(lorb).
              ! CAN BE IMPROVED IF SEVERAL BASIS FUNCTIONS ARE CENTERD ON THE SAME ATOM
              if(centralAt/=centralAtPrev) then ! otherwise we have the same Hamiltonian and hence the same hphi2
                  call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
                  call HamiltonianApplicationConfinement(iproc,nproc,at,lin%orbs,lin,input%hx,input%hy,input%hz,rxyz,&
                       nlpspd,proj,Glr,ngatherarr,Glr%d%n1i*Glr%d%n2i*nscatterarr(iproc,2),&
                       rhopot(1),&
                       phi(1),hphi2(1),ekin_sum,epot_sum,eexctX,eproj_sum,nspin,GPU, rxyzParabola, &
                       pkernel=pkernelseq, centralAtom=centralAt)
                  call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
              end if
              centralAtPrev=centralAt
              call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi2, work=phiWork)
              kstart=1
              do korb=1,lin%orbs%norb
                  do iorb=1,orbs%norb
                      tt=coeff(lorb,iorb)*coeff(korb,iorb)
                      call daxpy(nvctrp, tt, hphi2(kstart), 1, phiGrad(lstart), 1)
                      call daxpy(nvctrp, tt, hphi(kstart), 1, phiGrad(lstart), 1)
                      !matEl=ddot(nvctrp, phi(kstart), 1, phiGrad(lstart), 1)
                      matEl=ddot(nvctrp, phi(kstart), 1, hphi(lstart), 1)
                      tt2=matEl
                      call mpi_allreduce(tt2, matEl, 1, mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
                      ebsMod=ebsMod+tt*matEl
                  end do
                  kstart=kstart+nvctrp
              end do  
              call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi2, work=phiWork)
              lstart=lstart+nvctrp
          end do
      end do
!!!!!!! DEBUG
!!phiGrad=hphi
!!!!!!!!!!!!!
!!do iorb=1,orbs%norb
!!    write(*,*) 'iproc, ddot', iproc, ddot(lin%orbs%norb, coeff(1,iorb), 1, coeff(1,iorb), 1)
!!end do

      ! Apply the orthoconstraint to the gradient. This subroutine also calculates the trace trH.
      if(iproc==0) then
          write(*,'(a)', advance='no') 'orthoconstraint... '
      end if
      !call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)
      !call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
      !call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phiGrad, work=phiWork)
      !call orthoconstraintNotSymmetric(iproc, nproc, lin%orbs, lin%comms, Glr%wfd, phi, hphi, trH, lagMatDiag)
      call orthoconstraintNotSymmetric(iproc, nproc, lin%orbs, lin%comms, Glr%wfd, phi, phiGrad, trH, lagMatDiag)
  
  
      ! Calculate the norm of the gradient (fnrmArr) and determine the angle between the current gradient and that
      ! of the previous iteration (fnrmOvrlpArr).
      nvctrp=lin%comms%nvctr_par(iproc,1) ! 1 for k-point
      istart=1
      do iorb=1,lin%orbs%norb
          !if(it>1) fnrmOvrlpArr(iorb,2)=ddot(nvctrp*orbs%nspinor, hphi(istart), 1, hphiold(istart), 1)
          !fnrmArr(iorb,2)=ddot(nvctrp*orbs%nspinor, hphi(istart), 1, hphi(istart), 1)
          if(it>1) fnrmOvrlpArr(iorb,2)=ddot(nvctrp*orbs%nspinor, phiGrad(istart), 1, phiGradold(istart), 1)
          fnrmArr(iorb,2)=ddot(nvctrp*orbs%nspinor, phiGrad(istart), 1, phiGrad(istart), 1)
          istart=istart+nvctrp*orbs%nspinor
      end do
      call mpi_allreduce(fnrmArr(1,2), fnrmArr(1,1), lin%orbs%norb, mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
      call mpi_allreduce(fnrmOvrlpArr(1,2), fnrmOvrlpArr(1,1), lin%orbs%norb, mpi_double_precision, mpi_sum, mpi_comm_world, ierr)
  
      ! Keep the gradient for the next iteration.
      if(it>1) then
          call dcopy(lin%orbs%norb, fnrmArr(1,1), 1, fnrmOldArr(1), 1)
      end if
  
      ! Determine the gradient norm and its maximal component. In addition, adapt the
      ! step size for the steepest descent minimization (depending on the angle 
      ! between the current gradient and the one from the previous iteration).
      ! This is of course only necessary if we are using steepest descent and not DIIS.
      do iorb=1,lin%orbs%norb
          fnrm=fnrm+fnrmArr(iorb,1)
          if(fnrmArr(iorb,1)>fnrmMax) fnrmMax=fnrmArr(iorb,1)
          if(it>1 .and. diisLIN%idsx==0 .and. .not.diisLIN%switchSD) then
          ! Adapt step size for the steepest descent minimization.
              tt=fnrmOvrlpArr(iorb,1)/sqrt(fnrmArr(iorb,1)*fnrmOldArr(iorb))
              if(tt>.7d0) then
                  alpha(iorb)=alpha(iorb)*1.05d0
              else
                  alpha(iorb)=alpha(iorb)*.5d0
              end if
          end if
      end do
      fnrm=sqrt(fnrm)
      fnrmMax=sqrt(fnrmMax)
!! ATTENTION
!alpha=lin%alphaSD
!!!!!!!!!!!!

      ! Copy the gradient (will be used in the next iteration to adapt the step size).
      !call dcopy(lin%orbs%norb*nvctrp*orbs%nspinor, hphi(1), 1, hphiold(1), 1)
      call dcopy(lin%orbs%norb*nvctrp*orbs%nspinor, phiGrad(1), 1, phiGradold(1), 1)
  
      ! Untranspose hphi.
      !call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)
      call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phiGrad, work=phiWork)
  
  
      ! Precondition the gradient
      if(iproc==0) then
          write(*,'(a)') 'preconditioning. '
      end if
      gnrm=1.d3 ; gnrm_zero=1.d3
      !call choosePreconditioner(iproc, nproc, lin%orbs, lin, Glr, input%hx, input%hy, input%hz, &
      !    lin%nItPrecond, hphi, at%nat, rxyz, at, it)
      call choosePreconditioner(iproc, nproc, lin%orbs, lin, Glr, input%hx, input%hy, input%hz, &
          lin%nItPrecond, phiGrad, at%nat, rxyz, at, it)

      ! Determine the mean step size for steepest descent iterations.
      tt=sum(alpha)
      meanAlpha=tt/dble(lin%orbs%norb)
  
      ! Write some informations to the screen.
      if(iproc==0) write(*,'(x,a,i6,2es15.7,2f14.7)') 'iter, fnrm, fnrmMax, trace, ebsMod', it, fnrm, fnrmMax, trH, ebsMod
      if(iproc==0) write(2000,'(i6,2es15.7,2f15.7,es12.4)') it, fnrm, fnrmMax, trH, ebsMod, meanAlpha
      if(fnrmMax<lin%convCrit .or. it>=lin%nItMax) then
          if(it>=lin%nItMax) then
              if(iproc==0) write(*,'(x,a,i0,a)') 'WARNING: not converged within ', it, &
                  ' iterations! Exiting loop due to limitations of iterations.'
              if(iproc==0) write(*,'(x,a,2es15.7,f12.7)') 'Final values for fnrm, fnrmMax, trace: ', fnrm, fnrmMax, trH
              infoBasisFunctions=1
          else
              if(iproc==0) then
                  write(*,'(x,a,i0,a,2es15.7,f12.7)') 'converged in ', it, ' iterations.'
                  write (*,'(x,a,2es15.7,f12.7)') 'Final values for fnrm, fnrmMax, trace: ', fnrm, fnrmMax, trH
              end if
              infoBasisFunctions=0
          end if
          if(iproc==0) write(*,'(x,a)') '============================= Basis functions created. ============================='
          call untranspose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phi, work=phiWork)
          if(lin%plotBasisFunctions) then
              call plotOrbitals(iproc, lin%orbs, Glr, phi, at%nat, rxyz, lin%onWhichAtom, .5d0*input%hx, &
                  .5d0*input%hy, .5d0*input%hz, 1)
          end if
          exit iterLoop
      end if
  
  
      call DIISorSD()
      if(iproc==0) then
          if(diisLIN%idsx>0) then
              write(*,'(x,3(a,i0))') 'DIIS informations: history length=',diisLIN%idsx, ', consecutive failures=', &
                  icountDIISFailureCons, ', total failures=', icountDIISFailureTot
          else
              if(allowDIIS) then
                  message='y'
              else
                  message='n'
              end if
              write(*,'(x,a,es9.3,a,i0,a,a)') 'steepest descent informations: mean alpha=', meanAlpha, &
              ', consecutive successes=', icountSDSatur, ', DIIS=', message
          end if
      end if
      if(.not. diisLIN%switchSD) call improveOrbitals()
  
  
  end do iterLoop


  call deallocateLocalArrays()

contains

    subroutine initializeDIISParameters(idsxHere)
    ! Purpose:
    ! ========
    !   Initializes all parameters needed for the DIIS procedure.
    !
    ! Calling arguments
    !   idsx    DIIS history length
    !
    implicit none
    
    ! Calling arguments
    integer:: idsxHere

      diisLIN%switchSD=.false.
      diisLIN%idiistol=0
      diisLIN%mids=1
      diisLIN%ids=0
      diisLIN%idsx=idsxHere
      diisLIN%energy_min=1.d10
      diisLIN%energy_old=1.d10
      diisLIN%energy=1.d10
      diisLIN%alpha=2.d0
      call allocate_diis_objects(diisLIN%idsx, lin%orbs%npsidim, 1, diisLIN, subname) ! 1 for k-points

    end subroutine initializeDIISParameters


    subroutine DIISorSD()
    !
    ! Purpose:
    ! ========
    !   This subroutine decides whether one should use DIIS or variable step size
    !   steepest descent to improve the orbitals. In the beginning we start with DIIS
    !   with history length lin%DIISHistMax. If DIIS becomes unstable, we switch to
    !   steepest descent. If the steepest descent iterations are successful, we switch
    !   back to DIIS, but decrease the DIIS history length by one. However the DIIS
    !   history length is limited to be larger or equal than lin%DIISHistMin.
    !


      ! First there are some checks whether the force is small enough to allow DIIS.

      ! Decide whether the force is small eneough to allow DIIS
      if(fnrmMax<lin%startDIIS .and. .not.allowDIIS) then
          allowDIIS=.true.
          if(iproc==0) write(*,'(x,a)') 'The force is small enough to allow DIIS.'
          ! This is to get the correct DIIS history 
          ! (it is chosen as max(lin%DIISHistMin,lin%DIISHistMax-icountSwitch).
          icountSwitch=icountSwitch-1
      else if(fnrmMax>lin%startDIIS .and. allowDIIS) then
          allowDIIS=.false.
          if(iproc==0) write(*,'(x,a)') 'The force is too large to allow DIIS.'
      end if    

      ! Switch to SD if the flag indicating that we should start with SD is true.
      ! If this is the case, this flag is set to false, since this flag concerns only the beginning.
      if(startWithSD .and. diisLIN%idsx>0) then
          call deallocate_diis_objects(diisLIN, subname)
          diisLIN%idsx=0
          diisLIN%switchSD=.false.
          startWithSD=.false.
      end if

      ! Decide whether we should switch from DIIS to SD in case we are using DIIS and it 
      ! is not allowed.
      if(.not.startWithSD .and. .not.allowDIIS .and. diisLIN%idsx>0) then
          if(iproc==0) write(*,'(x,a,es10.3)') 'The force is too large, switch to SD with stepsize', alpha(1)
          call deallocate_diis_objects(diisLIN, subname)
          diisLIN%idsx=0
          diisLIN%switchSD=.true.
      end if

      ! If we swicthed to SD in the previous iteration, reset this flag.
      if(diisLIN%switchSD) diisLIN%switchSD=.false.

      ! Now come some checks whether the trace is descreasing or not. This further decides
      ! whether we should use DIIS or SD.

      ! Determine wheter the trace is decreasing (as it should) or increasing.
      ! This is done by comparing the current value with diisLIN%energy_min, which is
      ! the minimal value of the trace so far.
      if(trH<=diisLIN%energy_min) then
          ! Everything ok
          diisLIN%energy_min=trH
          diisLIN%switchSD=.false.
          itBest=it
          icountSDSatur=icountSDSatur+1
          icountDIISFailureCons=0

          ! If we are using SD (i.e. diisLIN%idsx==0) and the trace has been decreasing
          ! for at least 10 iterations, switch to DIIS. However the history length is decreased.
          if(icountSDSatur>=10 .and. diisLIN%idsx==0 .and. allowDIIS) then
              icountSwitch=icountSwitch+1
              idsx=max(lin%DIISHistMin,lin%DIISHistMax-icountSwitch)
              if(idsx>0) then
                  if(iproc==0) write(*,'(x,a,i0)') 'switch to DIIS with new history length ', idsx
                  call initializeDIISParameters(idsx)
                  icountDIISFailureTot=0
                  icountDIISFailureCons=0
              end if
          end if
      else
          ! The trace is growing.
          ! Count how many times this occurs and (if we are using DIIS) switch to SD after 3 
          ! total failures or after 2 consecutive failures.
          icountDIISFailureCons=icountDIISFailureCons+1
          icountDIISFailureTot=icountDIISFailureTot+1
          icountSDSatur=0
          if((icountDIISFailureCons>=2 .or. icountDIISFailureTot>=3) .and. diisLIN%idsx>0) then
              ! Switch back to SD. The initial step size is 1.d0.
              alpha=lin%alphaSD
              if(iproc==0) then
                  if(icountDIISFailureCons>=2) write(*,'(x,a,i0,a,es10.3)') 'DIIS failed ', &
                      icountDIISFailureCons, ' times consecutievly. Switch to SD with stepsize', alpha(1)
                  if(icountDIISFailureTot>=3) write(*,'(x,a,i0,a,es10.3)') 'DIIS failed ', &
                      icountDIISFailureTot, ' times in total. Switch to SD with stepsize', alpha(1)
              end if
              ! Try to get back the orbitals of the best iteration. This is possible if
              ! these orbitals are still present in the DIIS history.
              if(it-itBest<diisLIN%idsx) then
                 if(iproc==0) then
                     if(iproc==0) write(*,'(x,a,i0,a)')  'Recover the orbitals from iteration ', &
                         itBest, ' which are the best so far.'
                 end if
                 ii=modulo(diisLIN%mids-(it-itBest),diisLIN%mids)
                 nvctrp=lin%comms%nvctr_par(iproc,1) ! 1 for k-point
                 call dcopy(lin%orbs%norb*nvctrp, diisLIN%psidst(ii*nvctrp*lin%orbs%norb+1), 1, phi(1), 1)
              end if
              call deallocate_diis_objects(diisLIN, subname)
              diisLIN%idsx=0
              diisLIN%switchSD=.true.
          end if
      end if

    end subroutine DIISorSD


    subroutine improveOrbitals()
    !
    ! Purpose:
    ! ========
    !   This subroutine improves the basis functions by following the gradient 
    ! For DIIS 
    if (diisLIN%idsx > 0) then
       diisLIN%mids=mod(diisLIN%ids,diisLIN%idsx)+1
       diisLIN%ids=diisLIN%ids+1
    end if

    ! Follow the gradient using steepest descent.
    ! The same, but transposed
    !call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, hphi, work=phiWork)
    call transpose_v(iproc, nproc, lin%orbs, Glr%wfd, lin%comms, phiGrad, work=phiWork)
    
    ! steepest descent
    if(diisLIN%idsx==0) then
        istart=1
        nvctrp=lin%comms%nvctr_par(iproc,1) ! 1 for k-point
        do iorb=1,lin%orbs%norb
            !call daxpy(nvctrp*orbs%nspinor, -alpha(iorb), hphi(istart), 1, phi(istart), 1)
            call daxpy(nvctrp*orbs%nspinor, -alpha(iorb), phiGrad(istart), 1, phi(istart), 1)
            istart=istart+nvctrp*orbs%nspinor
        end do
    else
        ! DIIS
        quiet=.true. ! less output
        !call psimix(iproc, nproc, lin%orbs, lin%comms, diisLIN, hphi, phi, quiet)
        call psimix(iproc, nproc, lin%orbs, lin%comms, diisLIN, phiGrad, phi, quiet)
    end if
    end subroutine improveOrbitals



    subroutine allocateLocalArrays()
    !
    ! Purpose:
    ! ========
    !   This subroutine allocates all local arrays.
    !

      allocate(hphiold(lin%orbs%npsidim), stat=istat)
      call memocc(istat, hphiold, 'hphiold', subname)

      allocate(alpha(lin%orbs%norb), stat=istat)
      call memocc(istat, alpha, 'alpha', subname)

      allocate(fnrmArr(lin%orbs%norb,2), stat=istat)
      call memocc(istat, fnrmArr, 'fnrmArr', subname)

      allocate(fnrmOldArr(lin%orbs%norb), stat=istat)
      call memocc(istat, fnrmOldArr, 'fnrmOldArr', subname)

      allocate(fnrmOvrlpArr(lin%orbs%norb,2), stat=istat)
      call memocc(istat, fnrmOvrlpArr, 'fnrmOvrlpArr', subname)

      allocate(phiWork(size(phi)), stat=istat)
      call memocc(istat, phiWork, 'phiWork', subname)
      
    

    end subroutine allocateLocalArrays


    subroutine deallocateLocalArrays()
    !
    ! Purpose:
    ! ========
    !   This subroutine deallocates all local arrays.
    !

      iall=-product(shape(hphiold))*kind(hphiold)
      deallocate(hphiold, stat=istat)
      call memocc(istat, iall, 'hphiold', subname)
      
      iall=-product(shape(alpha))*kind(alpha)
      deallocate(alpha, stat=istat)
      call memocc(istat, iall, 'alpha', subname)

      iall=-product(shape(fnrmArr))*kind(fnrmArr)
      deallocate(fnrmArr, stat=istat)
      call memocc(istat, iall, 'fnrmArr', subname)

      iall=-product(shape(fnrmOldArr))*kind(fnrmOldArr)
      deallocate(fnrmOldArr, stat=istat)
      call memocc(istat, iall, 'fnrmOldArr', subname)

      iall=-product(shape(fnrmOvrlpArr))*kind(fnrmOvrlpArr)
      deallocate(fnrmOvrlpArr, stat=istat)
      call memocc(istat, iall, 'fnrmOvrlpArr', subname)

      iall=-product(shape(phiWork))*kind(phiWork)
      deallocate(phiWork, stat=istat)
      call memocc(istat, iall, 'phiWork', subname)
      
      ! if diisLIN%idsx==0, these arrays have already been deallocated
      if(diisLIN%idsx>0 .and. lin%DIISHistMax>0) call deallocate_diis_objects(diisLIN,subname)

    end subroutine deallocateLocalArrays


end subroutine getLocalizedBasisNew
