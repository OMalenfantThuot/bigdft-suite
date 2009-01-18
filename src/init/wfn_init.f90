!!****f* BigDFT/Gaussian_DiagHam
!! DESCRIPTION
!!    Diagonalise the hamiltonian in a basis set of norbe orbitals and select the first
!!    norb eigenvectors. Works also with the spin-polarisation case and perform also the 
!!    treatment of semicore atoms. 
!!    In the absence of norbe parameters, it simply diagonalize the hamiltonian in the given
!!    orbital basis set.
!!    Works for wavefunctions given in a Gaussian basis set provided bt the structure G
!! COPYRIGHT
!!    Copyright (C) 2009 ESRF Grenoble
!! INPUT VARIABLES 
!!
!! INPUT-OUTPUT VARIABLES
!!
!! OUTPUT VARIABLES
!!
!! AUTHOR
!!    Luigi Genovese
!! CREATION DATE
!!    January 2009
!! SOURCE
!! 
subroutine Gaussian_DiagHam(iproc,nproc,natsc,nspin,orbs,G,mpirequests,&
     psigau,hpsigau,orbse,etol,norbsc_arr)
  use module_base
  use module_types
  use module_interfaces, except_this_one => DiagHam
  implicit none
  integer, intent(in) :: iproc,nproc,natsc,nspin
  real(gp), intent(in) :: etol
  type(gaussian_basis), intent(in) :: G
  type(orbitals_data), intent(inout) :: orbs
  type(orbitals_data), intent(in) :: orbse
  integer, dimension(nproc-1), intent(in) :: mpirequests
  integer, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(wp), dimension(orbse%nspinor*G%ncoeff,orbse%norbp), intent(in) :: psigau,hpsigau
  !local variables
  character(len=*), parameter :: subname='Gaussian_DiagHam'
  real(kind=8), parameter :: eps_mach=1.d-12
  logical :: semicore,minimal
  integer :: i,ndim_hamovr,i_all,i_stat,n2hamovr,nsthamovr,ierr,norbi_max,j
  integer :: norbtot,norbtotp,natsceff,norbsc,ndh1,ispin,nvctr,npsidim
  real(gp) :: tolerance
  real(kind=8) :: tt
  integer, dimension(:,:), allocatable :: norbgrp
  real(wp), dimension(:,:), allocatable :: hamovr
  real(wp), dimension(:), pointer :: psiw

  tolerance=etol

  minimal=.true.!present(orbse)

  semicore=.true.!present(norbsc_arr)

  !define the grouping of the orbitals: for the semicore case, follow the semicore atoms,
  !otherwise use the number of orbitals, separated in the spin-polarised case
  !for the spin polarised case it is supposed that the semicore orbitals are disposed equally
  if (semicore) then
     !if (present(orbsv)) then
     !   norbi_max=max(maxval(norbsc_arr),orbsv%norb)
     !else
        norbi_max=maxval(norbsc_arr)
     !end if

     !calculate the dimension of the overlap matrix
     !take the maximum as the two spin dimensions
     ndim_hamovr=0
     do ispin=1,nspin
        ndh1=0
        norbsc=0
        do i=1,natsc+1
           ndh1=ndh1+norbsc_arr(i,ispin)**2
        end do
        ndim_hamovr=max(ndim_hamovr,ndh1)
     end do
     if (natsc > 0) then
        if (nspin == 2) then
           if (sum(norbsc_arr(1:natsc,1)) /= sum(norbsc_arr(1:natsc,2))) then
              write(*,'(1x,a)')&
                'ERROR (DiagHam): The number of semicore orbitals must be the same for both spins'
              stop
           end if
        end if
        norbsc=sum(norbsc_arr(1:natsc,1))
     else
        norbsc=0
     end if

     natsceff=natsc
     allocate(norbgrp(natsceff+1,nspin+ndebug),stat=i_stat)
     call memocc(i_stat,norbgrp,'norbgrp',subname)

     !assign the grouping of the orbitals
     do j=1,nspin
        do i=1,natsceff+1
           norbgrp(i,j)=norbsc_arr(i,j)
        end do
     end do
  else
     !this works also for non spin-polarised since there norbu=norb
     norbi_max=max(orbs%norbu,orbs%norbd) 
     ndim_hamovr=norbi_max**2

     natsceff=0
     allocate(norbgrp(1,nspin+ndebug),stat=i_stat)
     call memocc(i_stat,norbgrp,'norbgrp',subname)

     norbsc=0
     norbgrp(1,1)=orbs%norbu
     if (nspin == 2) norbgrp(1,2)=orbs%norbd

  end if

  !assign total orbital number for calculating the overlap matrix and diagonalise the system

  if(minimal) then
     norbtot=orbse%norb !beware that norbe is equal both for spin up and down
     norbtotp=orbse%norbp !this is coherent with nspin*norbe
     npsidim=orbse%npsidim
  else
     norbtot=orbs%norb
     norbtotp=orbs%norbp
     npsidim=orbs%npsidim
  end if

  allocate(hamovr(nspin*ndim_hamovr,2+ndebug),stat=i_stat)
  call memocc(i_stat,hamovr,'hamovr',subname)

  if (iproc.eq.0) write(*,'(1x,a)',advance='no')&
       'Overlap Matrix...'

  call overlap_and_gather(iproc,nproc,mpirequests,G%ncoeff,natsc,nspin,ndim_hamovr,orbse,&
     norbsc_arr,psigau,hpsigau,hamovr)

  call solve_eigensystem(iproc,orbs%norb,orbs%norbu,orbs%norbd,norbi_max,&
       ndim_hamovr,natsceff,nspin,tolerance,norbgrp,hamovr,orbs%eval)
!!$
!!$  !allocate the pointer for virtual orbitals
!!$  if(present(orbsv) .and. present(psivirt) .and. orbsv%norb > 0) then
!!$     allocate(psivirt(orbsv%npsidim+ndebug),stat=i_stat)
!!$     call memocc(i_stat,psivirt,'psivirt',subname)
!!$  end if
!!$
!!$  if (iproc.eq.0) write(*,'(1x,a)',advance='no')'Building orthogonal Wavefunctions...'
!!$  nvctr=wfd%nvctr_c+7*wfd%nvctr_f
!!$  if (.not. present(orbsv)) then
!!$     call build_eigenvectors(orbs%norbu,orbs%norbd,orbs%norb,norbtot,nvctrp,&
!!$          natsceff,nspin,orbs%nspinor,ndim_hamovr,norbgrp,hamovr,psi,psit)
!!$  else
!!$     call build_eigenvectors(orbs%norbu,orbs%norbd,orbs%norb,norbtot,nvctrp,&
!!$          natsceff,nspin,orbs%nspinor,ndim_hamovr,norbgrp,hamovr,psi,psit,orbsv%norb,psivirt)
!!$  end if
!!$  
!!$  !if(nproc==1.and.nspinor==4) call psitransspi(nvctrp,norbu+norbd,psit,.false.)
!!$     
  i_all=-product(shape(hamovr))*kind(hamovr)
  deallocate(hamovr,stat=i_stat)
  call memocc(i_stat,i_all,'hamovr',subname)
!!$  i_all=-product(shape(norbgrp))*kind(norbgrp)
!!$  deallocate(norbgrp,stat=i_stat)
!!$  call memocc(i_stat,i_all,'norbgrp',subname)
!!$
!!$  if (minimal) then
!!$     !deallocate the old psi
!!$     i_all=-product(shape(psi))*kind(psi)
!!$     deallocate(psi,stat=i_stat)
!!$     call memocc(i_stat,i_all,'psi',subname)
!!$  else if (nproc == 1) then
!!$     !reverse objects for the normal diagonalisation in serial
!!$     !at this stage hpsi is the eigenvectors and psi is the old wavefunction
!!$     !this will restore the correct identification
!!$     nullify(hpsi)
!!$     hpsi => psi
!!$!     if(nspinor==4) call psitransspi(nvctrp,norb,psit,.false.) 
!!$    nullify(psi)
!!$     psi => psit
!!$  end if
!!$
!!$  !orthogonalise the orbitals in the case of semi-core atoms
!!$  if (norbsc > 0) then
     !if(nspin==1) then
     !   call orthon_p(iproc,nproc,norb,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit,nspinor) 
     !else
!!$     call orthon_p(iproc,nproc,orbs%norbu,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit,&
!!$          orbs%nspinor) 
!!$     if(orbs%norbd > 0) then
!!$        call orthon_p(iproc,nproc,orbs%norbd,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,&
!!$             psit(1+nvctrp*orbs%norbu),orbs%nspinor) 
     !   end if
!!$     end if
!!$  end if
!!$
!!$
!!$  if (minimal) then
!!$     allocate(hpsi(orbs%npsidim+ndebug),stat=i_stat)
!!$     call memocc(i_stat,hpsi,'hpsi',subname)
!!$!     hpsi=0.0d0
!!$     if (nproc > 1) then
!!$        !allocate the direct wavefunction
!!$        allocate(psi(orbs%npsidim+ndebug),stat=i_stat)
!!$        call memocc(i_stat,psi,'psi',subname)
!!$     else
!!$        psi => psit
!!$     end if
!!$  end if
!!$
!!$  !this untranspose also the wavefunctions 
!!$  call untranspose_v(iproc,nproc,orbs%norbp,orbs%nspinor,wfd,nvctrp,comms,&
!!$       psit,work=hpsi,outadd=psi(1))
!!$
!!$  if (nproc == 1) then
!!$     nullify(psit)
!!$  end if

end subroutine Gaussian_DiagHam
!!***



!!****f* BigDFT/DiagHam
!! DESCRIPTION
!!    Diagonalise the hamiltonian in a basis set of norbe orbitals and select the first
!!    norb eigenvectors. Works also with the spin-polarisation case and perform also the 
!!    treatment of semicore atoms. 
!!    In the absence of norbe parameters, it simply diagonalize the hamiltonian in the given
!!    orbital basis set.
!! COPYRIGHT
!!    Copyright (C) 2008 CEA Grenoble
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!! INPUT VARIABLES
!!    iproc  process id
!!    nproc  number of mpi processes
!!    natsc  number of semicore atoms for the orthogonalisation treatment
!!           used as a dimension for the array of semicore atoms
!!    nspin  spin polarised id; 1 => non spin-polarised; 2 => spin-polarised (collinear)
!!    norbu  number of up orbitals in the spin-polarised case; for non spin-pol equal to norb
!!    norbd  number of down orbitals in the spin-polarised case; for non spin-pol equal to 0
!!    norb   total number of orbitals of the resulting eigenfunctions
!!    norbp  number of orbitals in parallel. For nproc=1 norbp=norb
!!    nvirte  number of virtual orbitals to be saved as input guess for the Davidson method
!!    nvctrp number of points of the wavefunctions for each orbital in the transposed sense
!!    wfd    data structure of the wavefunction descriptors
!!    norbe  (optional) number of orbitals of the initial set of wavefunction, to be reduced
!!    etol   tolerance for which a degeneracy should be printed. Set to zero if absent
!! INPUT-OUTPUT VARIABLES
!!    psi    wavefunctions. 
!!           If norbe is absent: on input, set of norb wavefunctions, 
!!                               on output eigenfunctions
!!           If norbe is present: on input, set of norbe wavefunctions, 
!!                                on output the first norb eigenfunctions
!!    hpsi   hamiltonian on the wavefunctions
!!           If norbe is absent: on input, set of norb arrays, 
!!                               destroyed on output
!!           If norbe is present: on input, set of norbe wavefunctions, 
!!                                destroyed on output
!! OUTPUT VARIABLES
!!    psit   wavefunctions in the transposed form.
!!           On input: nullified
!!           on Output: transposed wavefunction but only if nproc>1, nullified otherwise
!!    psivirt wavefunctions for input guess of the Davidson method in the transposed form.
!!           On input: nullified
!!           if nvirte >0: on Output transposed wavefunction (if nproc>1), direct otherwise
!!           if nvirte=0: nullified
!!    eval   array of the first norb eigenvalues       
!! AUTHOR
!!    Luigi Genovese
!! CREATION DATE
!!    February 2008
!! SOURCE
!! 
subroutine DiagHam(iproc,nproc,natsc,nspin,orbs,nvctrp,wfd,comms,&
     psi,hpsi,psit,& !mandatory
     orbse,commse,etol,norbsc_arr,orbsv,psivirt) !optional
  use module_base
  use module_types
  use module_interfaces, except_this_one => DiagHam
  implicit none
  integer, intent(in) :: iproc,nproc,natsc,nspin,nvctrp
  type(wavefunctions_descriptors), intent(in) :: wfd
  type(communications_arrays), target, intent(in) :: comms
  type(orbitals_data), intent(inout) :: orbs
  real(wp), dimension(:), pointer :: psi,hpsi,psit
  !optional arguments
  real(gp), optional, intent(in) :: etol
  type(orbitals_data), optional, intent(in) :: orbse,orbsv
  type(communications_arrays), optional, target, intent(in) :: commse
  integer, optional, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(wp), dimension(:), pointer, optional :: psivirt
  !local variables
  character(len=*), parameter :: subname='DiagHam'
  real(kind=8), parameter :: eps_mach=1.d-12
  logical :: semicore,minimal
  integer :: i,ndim_hamovr,i_all,i_stat,n2hamovr,nsthamovr,ierr,norbi_max,j
  integer :: norbtot,norbtotp,natsceff,norbsc,ndh1,ispin,nvctr,npsidim
  real(gp) :: tolerance
  real(kind=8) :: tt
  type(communications_arrays), pointer :: commu
  integer, dimension(:,:), allocatable :: norbgrp
  real(wp), dimension(:,:), allocatable :: hamovr
  real(wp), dimension(:), pointer :: psiw

  !performs some check of the arguments
  if (present(etol)) then
     tolerance=etol
  else
     tolerance=0.0_gp
  end if

  if (present(orbse) .neqv. present(commse)) then
     if (iproc ==0) write(*,'(1x,a)')&
          'ERROR (DiagHam): the variables orbse and commse must be present at the same time'
     stop
  else
     minimal=present(orbse)
  end if

  semicore=present(norbsc_arr)

  !define the grouping of the orbitals: for the semicore case, follow the semocore atoms,
  !otherwise use the number of orbitals, separated in the spin-polarised case
  !fro the spin polarised case it is supposed that the semicore orbitals are disposed equally
  if (semicore) then
     if (present(orbsv)) then
        norbi_max=max(maxval(norbsc_arr),orbsv%norb)
     else
        norbi_max=maxval(norbsc_arr)
     end if

     !calculate the dimension of the overlap matrix
     !take the maximum as the two spin dimensions
     ndim_hamovr=0
     do ispin=1,nspin
        ndh1=0
        norbsc=0
        do i=1,natsc+1
           ndh1=ndh1+norbsc_arr(i,ispin)**2
        end do
        ndim_hamovr=max(ndim_hamovr,ndh1)
     end do
     if (natsc > 0) then
        if (nspin == 2) then
           if (sum(norbsc_arr(1:natsc,1)) /= sum(norbsc_arr(1:natsc,2))) then
              write(*,'(1x,a)')&
                'ERROR (DiagHam): The number of semicore orbitals must be the same for both spins'
              stop
           end if
        end if
        norbsc=sum(norbsc_arr(1:natsc,1))
     else
        norbsc=0
     end if

     natsceff=natsc
     allocate(norbgrp(natsceff+1,nspin+ndebug),stat=i_stat)
     call memocc(i_stat,norbgrp,'norbgrp',subname)

     !assign the grouping of the orbitals
     do j=1,nspin
        do i=1,natsceff+1
           norbgrp(i,j)=norbsc_arr(i,j)
        end do
     end do
  else
     !this works also for non spin-polarised since there norbu=norb
     norbi_max=max(orbs%norbu,orbs%norbd) 
     ndim_hamovr=norbi_max**2

     natsceff=0
     allocate(norbgrp(1,nspin+ndebug),stat=i_stat)
     call memocc(i_stat,norbgrp,'norbgrp',subname)

     norbsc=0
     norbgrp(1,1)=orbs%norbu
     if (nspin == 2) norbgrp(1,2)=orbs%norbd

  end if

  !assign total orbital number for calculating the overlap matrix and diagonalise the system

  if(minimal) then
     norbtot=orbse%norb !beware that norbe is equal both for spin up and down
     norbtotp=orbse%norbp !this is coherent with nspin*norbe
     commu => commse
     npsidim=orbse%npsidim
  else
     norbtot=orbs%norb
     norbtotp=orbs%norbp
     commu => comms
     npsidim=orbs%npsidim
  end if
  if (nproc > 1) then
     allocate(psiw(npsidim+ndebug),stat=i_stat)
     call memocc(i_stat,psiw,'psiw',subname)
  else
     psiw => null()
  end if

  !transpose all the wavefunctions for having a piece of all the orbitals 
  !for each processor
  call transpose_v(iproc,nproc,norbtotp,1,wfd,nvctrp,commu,psi,work=psiw)
  call transpose_v(iproc,nproc,norbtotp,1,wfd,nvctrp,commu,hpsi,work=psiw)

  if (nproc > 1) then
     i_all=-product(shape(psiw))*kind(psiw)
     deallocate(psiw,stat=i_stat)
     call memocc(i_stat,i_all,'psiw',subname)

     n2hamovr=4
     nsthamovr=3
  else
     !allocation values
     n2hamovr=2
     nsthamovr=1
  end if

  allocate(hamovr(nspin*ndim_hamovr,n2hamovr+ndebug),stat=i_stat)
  call memocc(i_stat,hamovr,'hamovr',subname)

  if (iproc.eq.0) write(*,'(1x,a)',advance='no')&
       'Overlap Matrix...'

  call overlap_matrices(norbtot,nvctrp,natsceff,nspin,ndim_hamovr,norbgrp,&
       hamovr(1,nsthamovr),psi,hpsi)

  if (minimal) then
     !deallocate hpsi in the case of a minimal basis
     i_all=-product(shape(hpsi))*kind(hpsi)
     deallocate(hpsi,stat=i_stat)
     call memocc(i_stat,i_all,'hpsi',subname)
  end if

  if (nproc > 1) then
     !reduce the overlap matrix between all the processors
     call MPI_ALLREDUCE(hamovr(1,3),hamovr(1,1),2*nspin*ndim_hamovr,&
          mpidtypw,MPI_SUM,MPI_COMM_WORLD,ierr)
  end if

  call solve_eigensystem(iproc,orbs%norb,orbs%norbu,orbs%norbd,norbi_max,&
       ndim_hamovr,natsceff,nspin,tolerance,norbgrp,hamovr,orbs%eval)

  !in the case of minimal basis allocate now the transposed wavefunction
  !otherwise do it only in parallel
  if (minimal .or. nproc > 1) then
        allocate(psit(orbs%npsidim+ndebug),stat=i_stat)
        call memocc(i_stat,psit,'psit',subname)
  else
     psit => hpsi
  end if
  
  !allocate the pointer for virtual orbitals
  if(present(orbsv) .and. present(psivirt) .and. orbsv%norb > 0) then
     allocate(psivirt(orbsv%npsidim+ndebug),stat=i_stat)
     call memocc(i_stat,psivirt,'psivirt',subname)
  end if

  if (iproc.eq.0) write(*,'(1x,a)',advance='no')'Building orthogonal Wavefunctions...'
  nvctr=wfd%nvctr_c+7*wfd%nvctr_f
  if (.not. present(orbsv)) then
     call build_eigenvectors(orbs%norbu,orbs%norbd,orbs%norb,norbtot,nvctrp,&
          natsceff,nspin,orbs%nspinor,ndim_hamovr,norbgrp,hamovr,psi,psit)
  else
     call build_eigenvectors(orbs%norbu,orbs%norbd,orbs%norb,norbtot,nvctrp,&
          natsceff,nspin,orbs%nspinor,ndim_hamovr,norbgrp,hamovr,psi,psit,orbsv%norb,psivirt)
  end if
  
  !if(nproc==1.and.nspinor==4) call psitransspi(nvctrp,norbu+norbd,psit,.false.)
     
  i_all=-product(shape(hamovr))*kind(hamovr)
  deallocate(hamovr,stat=i_stat)
  call memocc(i_stat,i_all,'hamovr',subname)
  i_all=-product(shape(norbgrp))*kind(norbgrp)
  deallocate(norbgrp,stat=i_stat)
  call memocc(i_stat,i_all,'norbgrp',subname)

  if (minimal) then
     !deallocate the old psi
     i_all=-product(shape(psi))*kind(psi)
     deallocate(psi,stat=i_stat)
     call memocc(i_stat,i_all,'psi',subname)
  else if (nproc == 1) then
     !reverse objects for the normal diagonalisation in serial
     !at this stage hpsi is the eigenvectors and psi is the old wavefunction
     !this will restore the correct identification
     nullify(hpsi)
     hpsi => psi
!     if(nspinor==4) call psitransspi(nvctrp,norb,psit,.false.) 
    nullify(psi)
     psi => psit
  end if

  !orthogonalise the orbitals in the case of semi-core atoms
  if (norbsc > 0) then
!!$     if(nspin==1) then
!!$        call orthon_p(iproc,nproc,norb,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit,nspinor) 
!!$     else
     call orthon_p(iproc,nproc,orbs%norbu,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit,&
          orbs%nspinor) 
     if(orbs%norbd > 0) then
        call orthon_p(iproc,nproc,orbs%norbd,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,&
             psit(1+nvctrp*orbs%norbu),orbs%nspinor) 
!!$        end if
     end if
  end if


  if (minimal) then
     allocate(hpsi(orbs%npsidim+ndebug),stat=i_stat)
     call memocc(i_stat,hpsi,'hpsi',subname)
!     hpsi=0.0d0
     if (nproc > 1) then
        !allocate the direct wavefunction
        allocate(psi(orbs%npsidim+ndebug),stat=i_stat)
        call memocc(i_stat,psi,'psi',subname)
     else
        psi => psit
     end if
  end if

  !this untranspose also the wavefunctions 
  call untranspose_v(iproc,nproc,orbs%norbp,orbs%nspinor,wfd,nvctrp,comms,&
       psit,work=hpsi,outadd=psi(1))

  if (nproc == 1) then
     nullify(psit)
  end if

end subroutine DiagHam
!!***

subroutine overlap_matrices(norbe,nvctrp,natsc,nspin,ndim_hamovr,norbsc_arr,hamovr,psi,hpsi)
  use module_base
  implicit none
  integer, intent(in) :: norbe,nvctrp,natsc,ndim_hamovr,nspin
  integer, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(wp), dimension(nspin*ndim_hamovr,2), intent(out) :: hamovr
  real(wp), dimension(nvctrp,norbe), intent(in) :: psi,hpsi
  !local variables
  integer :: iorbst,imatrst,norbi,i,ispin,j
  real(kind=4) :: t0,t1

  !calculate the overlap matrix for each group of the semicore atoms
  !       hamovr(jorb,iorb,3)=+psit(k,jorb)*hpsit(k,iorb)
  !       hamovr(jorb,iorb,4)=+psit(k,jorb)* psit(k,iorb)
  iorbst=1
  imatrst=1
  do ispin=1,nspin !this construct assumes that the semicore is identical for both the spins
     do i=1,natsc+1
        norbi=norbsc_arr(i,ispin)
        call gemm('T','N',norbi,norbi,nvctrp,1.0_wp,psi(1,iorbst),nvctrp,hpsi(1,iorbst),nvctrp,&
             0.0_wp,hamovr(imatrst,1),norbi)
        call gemm('T','N',norbi,norbi,nvctrp,1.0_wp,psi(1,iorbst),nvctrp,psi(1,iorbst),nvctrp,&
             0.0_wp,hamovr(imatrst,2),norbi)
        iorbst=iorbst+norbi
        imatrst=imatrst+norbi**2
     end do
  end do

end subroutine overlap_matrices

subroutine solve_eigensystem(iproc,norb,norbu,norbd,norbi_max,ndim_hamovr,natsc,nspin,etol,&
     norbsc_arr,hamovr,eval)
  use module_base
  implicit none
  integer, intent(in) :: iproc,norb,norbi_max,ndim_hamovr,natsc,nspin,norbu,norbd
  integer, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(gp), intent(in) :: etol
  real(wp), dimension(nspin*ndim_hamovr,2), intent(inout) :: hamovr
  real(wp), dimension(norb), intent(out) :: eval
  !local variables
  character(len=*), parameter :: subname='solve_eigensystem'
  character(len=64) :: message
  integer :: iorbst,imatrst,norbi,n_lp,info,i_all,i_stat,iorb,i,ndegen,nwrtmsg,jorb,istart,norbj
  integer :: jjorb,jiorb
  real(wp) :: tt
  real(wp), dimension(2) :: preval
  real(wp), dimension(:), allocatable :: work_lp,evale

  !find the eigenfunctions for each group
  n_lp=max(10,4*norbi_max)
  allocate(work_lp(n_lp+ndebug),stat=i_stat)
  call memocc(i_stat,work_lp,'work_lp',subname)
  allocate(evale(nspin*norbi_max+ndebug),stat=i_stat)
  call memocc(i_stat,evale,'evale',subname)

  if (iproc.eq.0) write(*,'(1x,a)')'Linear Algebra...'

  nwrtmsg=0
  ndegen=0

  preval=0.0_wp
  iorbst=1
  imatrst=1
  do i=1,natsc+1
     norbi=norbsc_arr(i,1)

!!$     if (iproc == 0) then
        !write the matrices on a file
      !open(31+2*(i-1))
!!$        tt=0.0_wp
!!$        do jjorb=1,norbi
           !write(31+2*(i-1),'(2000(1pe10.2))')&
           !     (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,1),jiorb=1,norbi)
!!$           write(*,'(i4,2000(1pe15.8))')jjorb,&
!!$                (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,1),jiorb=1,norbi)
!!$           !write(13,'(i4,2000(1pe15.8))')jjorb,&
!!$           !     (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,1),jiorb=1,norbi)
!!$           tt=tt+hamovr(imatrst-1+jjorb+(jjorb-1)*norbi,1)
!!$        end do
!!$        print *,'trace',tt
           !close(31+2*(i-1))
           !open(32+2*(i-1))
!!$        do jjorb=1,norbi
     !write(32+2*(i-1),'(2000(1pe10.2))')&
     !           (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,2),jiorb=1,norbi)
!!$           write(*,'(i4,2000(1pe15.8))')jjorb,&
!!$                (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,2),jiorb=1,norbi)
!!$        end do
           !close(32+2*(i-1))
!!$
!!$     end if
!!$
!!$     !now compare only the overlap
!!$     if (i==natsc+1) stop

     !write(11,*)hamovr(:,1:2)

     call sygv(1,'V','U',norbi,hamovr(imatrst,1),norbi,hamovr(imatrst,2),&
          norbi,evale(1),work_lp(1),n_lp,info)
     if (info /= 0) write(*,*) 'SYGV ERROR',info,i,natsc+1

     !do the diagonalisation separately in case of spin polarization     
     if (nspin==2) then
        norbj=norbsc_arr(i,2)
        call sygv(1,'V','U',norbj,hamovr(imatrst+ndim_hamovr,1),&
             norbj,hamovr(imatrst+ndim_hamovr,2),norbj,evale(norbi+1),work_lp(1),n_lp,info)
        if (info.ne.0) write(*,*) 'SYGV ERROR',info,i,natsc+1
     end if

!!$     if (iproc == 0) then
!!$        !write the matrices on a file
!!$        open(12)
!!$        do jjorb=1,norbi
!!$           do jiorb=1,norbi
!!$              write(12,'(1x,2(i0,1x),2(1pe24.17,1x))')jjorb,jiorb,&
!!$                   hamovr(jjorb+norbi*(jiorb-1),1),hamovr(jjorb+norbi*(jiorb-1),2)
!!$           end do
!!$        end do
!!$        close(12)
!!$        !open(33+2*(i-1))
!!$        !write(33+2*(i-1),'(2000(1pe10.2))')&
!!$        !        (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,1),jiorb=1,norbi)
!!$        !end do
!!$        !close(33+2*(i-1))
!!$        !open(34+2*(i-1))
!!$        !do jjorb=1,norbi
!!$        !   write(34+2*(i-1),'(2000(1pe10.2))')&
!!$        !        (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,2),jiorb=1,norbi)
!!$        !end do
!!$        !close(34+2*(i-1))
!!$
!!$     end if

     !writing rules, control if the last eigenvector is degenerate
     !do this for each spin
     !for each spin it is supposed that only the last group is not completely passed
     !and also that the components of each of the group but the last are the same for up and 
     !down polarisation. Do not work properly in the other cases
     do iorb=1,norbi
        if (nspin==1) then
           if (nwrtmsg==1) then
              if (abs(evale(iorb)-preval(1)) <= etol) then
                 !degeneracy found
                 message='  <- found degeneracy'
                 ndegen=ndegen+1
              else
                 nwrtmsg=0
              end if
           end if
           if (iorb+iorbst-1 == norb) then
              nwrtmsg=1
              message=' <- Last eigenvalue for input wavefunctions'
              preval(1)=evale(iorb)
           end if
           if (iproc.eq.0) then
              if (nwrtmsg == 1) then
                 write(*,'(1x,a,i0,a,1x,1pe21.14,a)') &
                      'evale(',iorb+iorbst-1,')=',evale(iorb),trim(message)
              else
                 write(*,'(1x,a,i0,a,1x,1pe21.14)') &
                      'evale(',iorb+iorbst-1,')=',evale(iorb)
              end if
           end if
        else
           if (nwrtmsg==1) then
              if (abs(evale(iorb)-preval(1)) <= etol .and. &
                   abs(evale(iorb+norbi)-preval(2)) <= etol) then
                 !degeneracy found
                 message='  <-deg->  '
                 !ndegen=ndegen+1 removed, only for non magnetized cases
              else if (abs(evale(iorb)-preval(1)) <= etol) then
                 !degeneracy found
                 message='  <-deg    '
              else if (abs(evale(iorb+norbi)-preval(2)) <= etol) then
                 !degeneracy found
                 message='    deg->  '
              else
                 nwrtmsg=0
              end if
           end if
           if (iorb+iorbst-1 == norbu .and. iorb+iorbst-1 == norbd) then
              nwrtmsg=1
              message='  <-Last-> ' 
              preval(1)=evale(iorb)
              preval(2)=evale(iorb+norbi)
           else if (iorb+iorbst-1 == norbu) then
              nwrtmsg=1
              message='  <-Last   '
              preval(1)=evale(iorb)
           else if (iorb+iorbst-1 == norbd) then
              nwrtmsg=1
              message='    Last-> '
              preval(2)=evale(iorb+norbi)
           end if
           if (iproc == 0) then
              if (nwrtmsg==1) then
                 write(*,'(1x,a,i4,a,1x,1pe21.14,a12,a,i4,a,1x,1pe21.14)') &
                      'evale(',iorb+iorbst-1,',u)=',evale(iorb),message,&
                      'evale(',iorb+iorbst-1,',d)=',evale(iorb+norbi)
              else
                 write(*,'(1x,a,i4,a,1x,1pe21.14,12x,a,i4,a,1x,1pe21.14)') &
                      'evale(',iorb+iorbst-1,',u)=',evale(iorb),&
                      'evale(',iorb+iorbst-1,',d)=',evale(iorb+norbi)
              end if
           end if
        end if
     end do
     if (nspin==1) then
        do iorb=iorbst,min(norbi+iorbst-1,norb)
           eval(iorb)=evale(iorb-iorbst+1)
        end do
     else
        do iorb=iorbst,min(norbi+iorbst-1,norbu)
           eval(iorb)=evale(iorb-iorbst+1)
        end do
        do iorb=iorbst,min(norbi+iorbst-1,norbd)
           eval(iorb+norbu)=evale(iorb-iorbst+1+norbi)
        end do
     end if
     iorbst=iorbst+norbi
     imatrst=imatrst+norbi**2
  end do

  i_all=-product(shape(work_lp))*kind(work_lp)
  deallocate(work_lp,stat=i_stat)
  call memocc(i_stat,i_all,'work_lp',subname)
  i_all=-product(shape(evale))*kind(evale)
  deallocate(evale,stat=i_stat)
  call memocc(i_stat,i_all,'evale',subname)

end subroutine solve_eigensystem

subroutine build_eigenvectors(norbu,norbd,norb,norbe,nvctrp,natsc,nspin,nspinor,&
     ndim_hamovr,norbsc_arr,hamovr,psi,ppsit,nvirte,psivirt)
  use module_base
  implicit none
  !Arguments
  integer, intent(in) :: norbu,norbd,norb,norbe,nvctrp,natsc,nspin,nspinor,ndim_hamovr
  integer, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(wp), dimension(nspin*ndim_hamovr), intent(in) :: hamovr
  real(wp), dimension(nvctrp,norbe), intent(in) :: psi
  real(wp), dimension(nvctrp*nspinor,norb), intent(out) :: ppsit
  integer, intent(in), optional :: nvirte
  real(wp), dimension(:), pointer, optional :: psivirt
  !Local variables
  character(len=*), parameter :: subname='build_eigenvectors'
  integer, parameter :: iunit=1978
  integer :: ispin,iorbst,iorbst2,imatrst,norbsc,norbi,norbj,i,iorb,i_stat,i_all
  logical :: exists
  real(gp) :: mx,my,mz,mnorm,fac,ma,mb,mc,md
  real(wp), dimension(:,:), allocatable :: tpsi

  !perform the vector-matrix multiplication for building the input wavefunctions
  ! ppsit(k,iorb)=+psit(k,jorb)*hamovr(jorb,iorb,1)
  !!     iorbst=1
  !!     imatrst=1
  !!     do i=1,natsc
  !!        norbi=norbsc_arr(i)
  !!        call DGEMM('N','N',nvctrp,norbi,norbi,1.d0,psi(1,iorbst),nvctrp,&
  !!             hamovr(imatrst,1),norbi,0.d0,ppsit(1,iorbst),nvctrp)
  !!        iorbst=iorbst+norbi
  !!        imatrst=imatrst+norbi**2
  !!     end do
  !!     norbi=norbsc_arr(natsc+1)
  !!     norbj=norb-norbsc
  !!     call DGEMM('N','N',nvctrp,norbj,norbi,1.d0,psi(1,iorbst),nvctrp,&
  !!          hamovr(imatrst,1),norbi,0.d0,ppsit(1,iorbst),nvctrp)

  !ppsi(k,iorb)=+psi(k,jorb)*hamovr(jorb,iorb,1)

  !allocate the pointer for virtual orbitals

  if(nspinor==1 .or. nspinor == 2) then
     iorbst=1
     iorbst2=1
     imatrst=1
     do ispin=1,nspin
        norbsc=0
        do i=1,natsc
           norbi=norbsc_arr(i,ispin)
           norbsc=norbsc+norbi
           call gemm('N','N',nvctrp,norbi,norbi,1.0_wp,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.0_wp,ppsit(1,iorbst2),nvctrp)
           iorbst=iorbst+norbi
           iorbst2=iorbst2+norbi
           imatrst=imatrst+norbi**2
        end do
        norbi=norbsc_arr(natsc+1,ispin)
        if(ispin==1) norbj=norbu-norbsc
        if(ispin==2) norbj=norbd-norbsc
        !        write(*,'(1x,a,5i4)') "DIMS:",norbi,norbj,iorbst,imatrst
        !        norbj=norb-norbsc
        if(norbj>0) then
           call gemm('N','N',nvctrp,norbj,norbi,1.0_wp,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.0_wp,ppsit(1,iorbst2),nvctrp)
        end if

        !now store the input wavefunctions for the Davidson treatment
        !we take the rest of the orbitals which are not assigned
        !from the group of non-semicore orbitals
        !the results are orthogonal with each other by construction
        !in the case of semicore atomes the orthogonality is not guaranteed
        if (present(nvirte) .and. nvirte >0) then
           call gemm('N','N',nvctrp,nvirte,norbi,1.0_wp,psi(1,iorbst),nvctrp,&
                hamovr(imatrst+norbi*norbj),norbi,0.0_wp,psivirt(1),nvctrp)
        end if
        iorbst=norbi+norbsc+1 !this is equal to norbe+1
        iorbst2=norbu+1
        imatrst=ndim_hamovr+1
     end do

  else
     allocate(tpsi(nvctrp,norbe+ndebug),stat=i_stat)
     call memocc(i_stat,tpsi,'tpsi',subname)
     iorbst=1
     iorbst2=1
     imatrst=1
     do ispin=1,nspin
        norbsc=0
        do i=1,natsc
           norbi=norbsc_arr(i,ispin)
           norbsc=norbsc+norbi
           call gemm('N','N',nvctrp,norbi,norbi,1.0_wp,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.0_wp,tpsi(1,iorbst2),nvctrp)
           iorbst=iorbst+norbi
           iorbst2=iorbst2+norbi
           imatrst=imatrst+norbi**2
        end do
        norbi=norbsc_arr(natsc+1,ispin)
        if(ispin==1) norbj=norbu-norbsc
        if(ispin==2) norbj=norbd-norbsc
        !        write(*,'(1x,a,5i4)') "DIMS:",norbi,norbj,iorbst,imatrst
        !        norbj=norb-norbsc
        if(norbj>0) then
           call gemm('N','N',nvctrp,norbj,norbi,1.0_wp,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.0_wp,tpsi(1,iorbst2),nvctrp)
        end if
        iorbst=norbi+norbsc+1 !this is equal to norbe+1
        iorbst2=norbu+1
        imatrst=ndim_hamovr+1
     end do
     !here we should put razero
     ppsit=0.0_wp
     inquire(file='moments',exist=exists)
     if (.not.exists) then
        stop 'The file "moments does not exist!'
     endif
     open(unit=iunit,file='moments',form='formatted',action='read',status='old')
     fac=0.5_gp
     do iorb=1,norbu+norbd
        read(unit=iunit,fmt=*,iostat=i_stat) mx,my,mz
        if (i_stat /= 0) then
           write(unit=*,fmt='(a,i0,a,i0,a)') &
                'The file "moments" has the line ',iorb,&
                ' which have not 3 numbers for the orbital ',iorb,'.'
           stop 'The file "moments" is not correct!'
        end if
        mnorm=sqrt(mx**2+my**2+mz**2)
        mx=mx/mnorm
        my=my/mnorm
        mz=mz/mnorm

        ma=0.0_gp
        mb=0.0_gp
        mc=0.0_gp
        md=0.0_gp

        if(mz > 0.0_gp .and. iorb<=norbu) then 
           ma=ma+mz
        else
           mc=mc+abs(mz)
        end if
        if(mx > 0.0_gp .and. iorb<=norbu) then 
           ma=ma+fac*mx
           mb=mb+fac*mx
           mc=mc+fac*mx
           md=md+fac*mx
        else
           ma=ma-fac*abs(mx)
           mb=mb-fac*abs(mx)
           mc=mc+fac*abs(mx)
           md=md+fac*abs(mx)
        end if
        if(my > 0.0_gp .and. iorb<=norbu) then 
           ma=ma+fac*my
           mb=mb-fac*my
           mc=mc+fac*my
           md=md+fac*my
        else
           ma=ma-fac*abs(my)
           mb=mb+fac*abs(my)
           mc=mc+fac*abs(my)
           md=md+fac*abs(my)
        end if
        if(mx==0.0_gp .and. my==0.0_gp .and. mz==0.0_gp) then
           ma=1.0_gp/sqrt(2.0_gp)
           mb=0.0_gp
           mc=1.0_gp/sqrt(2.0_gp)
           md=0.0_gp
        end if
        do i=1,nvctrp
           ppsit(2*i-1,iorb)=real(ma,wp)*tpsi(i,iorb)
           ppsit(2*i,iorb)=real(mb,wp)*tpsi(i,iorb)
           ppsit(2*i+2*nvctrp-1,iorb)=real(mc,wp)*tpsi(i,iorb)
           ppsit(2*i+2*nvctrp,iorb)=real(md,wp)*tpsi(i,iorb)
        end do
     end do
     close(unit=iunit)
    
     i_all=-product(shape(tpsi))*kind(tpsi)
     deallocate(tpsi,stat=i_stat)
     call memocc(i_stat,i_all,'tpsi',subname)
  end if

end subroutine build_eigenvectors

!  call psitospi(iproc,nproc,norbe,norbep,norbsc,nat,&
!       wfd%nvctr_c,wfd%nvctr_f,at%iatype,at%ntypes,&
!       at%iasctype,at%natsc,at%natpol,nspin,spinsgne,otoa,psi)
! Reads magnetic moments from file ('moments') and transforms the
! atomic orbitals to spinors 
! warning: Does currently not work for mx<0
!
subroutine psitospi(iproc,nproc,norbe,norbep,norbsc,&
     & nvctr_c,nvctr_f,nat,iatype,ntypes, &
     iasctype,natsc,natpol,nspin,spinsgne,otoa,psi)
  use module_base
  implicit none
  integer, intent(in) :: norbe,norbep,iproc,nproc,nat
  integer, intent(in) :: nvctr_c,nvctr_f
  integer, intent(in) :: ntypes
  integer, intent(in) :: norbsc,natsc,nspin
  integer, dimension(ntypes), intent(in) :: iasctype
  integer, dimension(norbep), intent(in) :: otoa
  integer, dimension(nat), intent(in) :: iatype,natpol
  integer, dimension(norbe*nspin), intent(in) :: spinsgne
  real(kind=8), dimension(nvctr_c+7*nvctr_f,4*norbep), intent(out) :: psi
  !local variables
  character(len=*), parameter :: subname='psitospi'
  logical :: myorbital,polarised
  integer :: iatsc,i_all,i_stat,ispin,ipolres,ipolorb,nvctr
  integer :: iorb,jorb,iat,ity,i,ictot,inl,l,m,nctot,nterm
  real(kind=8) :: facu,facd
  real(kind=8) :: mx,my,mz,mnorm,fac
  real(kind=8), dimension(:,:), allocatable :: mom,psi_o
  logical, dimension(4) :: semicore
  integer, dimension(2) :: iorbsc,iorbv

  !initialise the orbital counters
  iorbsc(1)=0
  iorbv(1)=norbsc
  !used in case of spin-polarisation, ignored otherwise
  iorbsc(2)=norbe
  iorbv(2)=norbsc+norbe


  if (iproc ==0) then
     write(*,'(1x,a)',advance='no')'Transforming AIO to spinors...'
  end if
  
  nvctr=nvctr_c+7*nvctr_f

  allocate(mom(3,nat+ndebug),stat=i_stat)
  call memocc(i_stat,mom,'mom',subname)

  open(unit=1978,file='moments')
  do i=1,nat
     read(1978,*) mx,my,mz
     mnorm=sqrt(mx**2+my**2+mz**2)
     mom(1,iat)=mx/mnorm
     mom(2,iat)=my/mnorm
     mom(3,iat)=mz/mnorm
  end do
  close(1978)
  fac=0.5d0
  do iorb=norbep*nproc,1,-1
     jorb=iorb-iproc*norbep
!     print *,'Kolla', shape(psi),4*iorb,shape(spinsgne),iorb
     if (myorbital(iorb,nspin*norbe,iproc,nproc)) then
        mx=mom(1,otoa(iorb))
        my=mom(2,otoa(iorb))
        mz=mom(3,otoa(iorb))
        if(spinsgne(jorb)>0.0d0) then
           do i=1,nvctr
              psi(i,iorb*4-3) = (mz+fac*(my+mx))*psi(i,iorb)
              psi(i,iorb*4-2) = fac*(my-mx)*psi(i,iorb)
              psi(i,iorb*4-1) = (fac*(mx-my))*psi(i,iorb)
              psi(i,iorb*4)   = fac*(my-mx)*psi(i,iorb)
           end do
        else
           do i=1,nvctr
              psi(i,iorb*4-3) = (fac*(mx+my))*psi(i,iorb)
              psi(i,iorb*4-2) = -fac*(my+mx)*psi(i,iorb)
              psi(i,iorb*4-1) = -(mz+fac*(my+mx))*psi(i,iorb)
              psi(i,iorb*4)   = -fac*(my-mx)*psi(i,iorb)
           end do
        end if
     end if
!     print *,'OtoA',(otoa(iorb),iorb=1,norbe)

  end do
     i_all=-product(shape(mom))*kind(mom)
     deallocate(mom,stat=i_stat)
     call memocc(i_stat,i_all,'mom',subname)

  if (iproc ==0) then
     write(*,'(1x,a)')'done.'
  end if

END SUBROUTINE psitospi
