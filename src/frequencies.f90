!!****p* BigDFT/frequencies
!! DESCRIPTION
!!  Calculate vibrational frequencies by frozen phonon approximation.
!!  Use a file 'frequencies.res' to restart calculations.
!!
!! COPYRIGHT
!!    Copyright (C) 2009 CEA, UNIBAS
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 
!!
!! SOURCE
!!
program frequencies

  use module_base
  use module_types
  use module_interfaces
  use ab6_symmetry

  implicit none
  real(dp), parameter :: Ha_cmm1=219474.6313705_dp  ! 1 Hartree, in cm^-1 (from abinit 5.7.x)
  real(dp), parameter :: amu_emass=1.660538782d-27/9.10938215d-31 ! 1 atomic mass unit, in electronic mass
  character(len=*), parameter :: subname='frequencies'
  character(len=2) :: cc
  !File units
  integer, parameter :: u_restart=10,u_hessian=20
  integer :: iproc,nproc,iat,jat,i,j,i_stat,i_all,ierr,infocode,ity
  real(gp) :: etot,etot_m,etot_p,sumx,sumy,sumz,alat,alpha,dd,rmass
  !input variables
  type(atoms_data) :: atoms
  type(input_variables) :: inputs
  type(restart_objects) :: rst
  ! atomic coordinates, forces
  real(gp), dimension(:,:), allocatable :: fxyz,rpos,fpos_m,fpos_p
  real(gp), dimension(:,:), pointer :: rxyz
  ! hessian, eigenvectors
  real(gp), dimension(:,:), allocatable :: hessian,vector_l,vector_r
  real(gp), dimension(:), allocatable :: eigen_r,eigen_i
  ! logical: .true. if already calculated
  logical, dimension(:,:,:), allocatable :: moves
  real(gp), dimension(:,:,:,:), allocatable :: forces
  real(gp), dimension(3) :: h_grid
  integer :: jm
 
  ! Start MPI in parallel version
  !in the case of MPIfake libraries the number of processors is automatically adjusted
  call MPI_INIT(ierr)
  call MPI_COMM_RANK(MPI_COMM_WORLD,iproc,ierr)
  call MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)

  !initialize memory counting
  call memocc(0,iproc,'count','start')

  !welcome screen
  if (iproc==0) call print_logo()

  ! Read all input files.
  call read_input_variables(iproc, "posinp", "input.dft", "input.kpt", &
       & "input.geopt", inputs, atoms, rxyz)

  ! allocations
  allocate(fxyz(3,atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,fxyz,'fxyz',subname)

  call init_restart_objects(atoms,rst,subname)

  call call_bigdft(nproc,iproc,atoms,rxyz,inputs,etot,fxyz,rst,infocode)

  if (iproc ==0 ) write(*,"(1x,a,2i5)") 'Wavefunction Optimization Finished, exit signal=',infocode

  if (iproc.eq.0) then
     sumx=0.d0
     sumy=0.d0
     sumz=0.d0
     write(*,'(1x,a,19x,a)') 'Final values of the Forces for each atom'
     do iat=1,atoms%nat
        write(*,'(1x,i5,1x,a6,3(1x,1pe12.5))') &
             iat,trim(atoms%atomnames(atoms%iatype(iat))),(fxyz(j,iat),j=1,3)
        sumx=sumx+fxyz(1,iat)
        sumy=sumy+fxyz(2,iat)
        sumz=sumz+fxyz(3,iat)
     enddo
     if (.not. inputs%gaussian_help .or. .true.) then !zero of the forces calculated
        write(*,'(1x,a)')'the sum of the forces is'
        write(*,'(1x,a16,3x,1pe16.8)')'x direction',sumx
        write(*,'(1x,a16,3x,1pe16.8)')'y direction',sumy
        write(*,'(1x,a16,3x,1pe16.8)')'z direction',sumz
     end if
  endif

  allocate(rpos(3,atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,rpos,'rpos',subname)
  allocate(fpos_m(3,atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,fpos_m,'fpos_m',subname)
  allocate(fpos_p(3,atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,fpos_p,'fpos_p',subname)
  allocate(hessian(3*atoms%nat,3*atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,hessian,'hessian',subname)
  allocate(moves(2,3,atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,moves,'moves',subname)
  allocate(forces(2,3,atoms%nat,3*atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,forces,'forces',subname)

  !initialise the moves to false
  moves=.false.

! Move to alpha*h_grid
  alpha=1.d0/real(64,kind(1.d0))
! Initialize the hessian
  hessian = 0.d0
! Initialize h_grid
  h_grid(1) = inputs%hx
  h_grid(2) = inputs%hy
  h_grid(3) = inputs%hz

  if (iproc ==0 ) then
     write(*,"(1x,a)") '=Frequencies calculation='
     !This file is used as a restart
     open(unit=u_restart,file='frequencies.res',status="unknown",form="unformatted")
     !This file contains the hessian for post-processing
     open(unit=u_hessian,file='hessian.dat',status="unknown")
     write(u_hessian,'(a,3(1pe20.10))') '#step=',alpha*inputs%hx,alpha*inputs%hy,alpha*inputs%hz
     write(u_hessian,'(a,100(1pe20.10))') '#--',etot,alpha*inputs%hx,alpha*inputs%hy,alpha*inputs%hz,fxyz
  end if

  do iat=1,atoms%nat

     if (atoms%ifrztyp(iat) == 1) then
        if (iproc==0) write(*,"(1x,a,i0,a)") '=F:The atom ',iat,' is frozen.'
        cycle
     end if

     do i=1,3
        if (i==1) then
           alat=atoms%alat1
           cc(2:2)='x'
        else if (i==2) then
           alat=atoms%alat2
           cc(2:2)='y'
        else
           alat=atoms%alat3
           cc(2:2)='z'
        end if
        do j=-1,1,2
           !-1-> 1, 1 -> 2, y = ( x + 3 ) / 2
           jm = (j+3)/2
           if (moves(jm,i,iat)) then
               !This move is already done.
               cycle
           end if
           if (j==-1) then
              cc(1:1)='-'
           else
              cc(1:1)='+'
           end if
           !Displacement
           dd=real(j,gp)*alpha*h_grid(i)
           !We copy atomic positions
           rpos=rxyz
           if (iproc==0) then
               write(*,"(1x,a,i0,a,a,a,1pe20.10,a)") &
               '=F:Move the atom ',iat,' in the direction ',cc,' by ',dd,' bohr'
           end if
           if (atoms%geocode == 'P') then
              rpos(i,iat)=modulo(rxyz(i,iat)+dd,alat)
           else if (atoms%geocode == 'S') then
              rpos(i,iat)=modulo(rxyz(i,iat)+dd,alat)
           else
              rpos(i,iat)=rxyz(i,iat)+dd
           end if
           inputs%inputPsiId=1
           inputs%output_grid=0
           inputs%output_wf=.false.
           if (j==-1) then
              call call_bigdft(nproc,iproc,atoms,rpos,inputs,etot_m,fpos_m,rst,infocode)
              if (iproc==0) write(u_restart) 1,i,iat,fpos_m
              moves(1,i,iat) = .true.
           else
              call call_bigdft(nproc,iproc,atoms,rpos,inputs,etot_p,fpos_p,rst,infocode)
              if (iproc==0) write(u_restart) 2,i,iat,fpos_p
              moves(2,i,iat) = .true.
           end if
        end do
        ! Build the hessian
        do jat=1,atoms%nat
           rmass = amu_emass*sqrt(atoms%amu(atoms%iatype(iat))*atoms%amu(atoms%iatype(jat)))
           do j=1,3
              !force is -dE/dR
              dd = - (fpos_p(j,jat) - fpos_m(j,jat))/(2.d0*alpha*h_grid(i))
              !if (abs(dd).gt.1.d-10) then
              hessian(3*(jat-1)+j,3*(iat-1)+i) = dd/rmass
              !end if
           end do
        end do
        if (iproc == 0) write(u_hessian,'(i0,1x,i0,1x,100(1pe20.10))') i,iat,hessian(:,3*(iat-1)+i)
     end do
  end do

  close(unit=u_restart)
  close(unit=u_hessian)

  !deallocations
  i_all=-product(shape(rpos))*kind(rpos)
  deallocate(rpos,stat=i_stat)
  call memocc(i_stat,i_all,'rpos',subname)
  i_all=-product(shape(fpos_m))*kind(fpos_m)
  deallocate(fpos_m,stat=i_stat)
  call memocc(i_stat,i_all,'fpos_m',subname)
  i_all=-product(shape(fpos_p))*kind(fpos_p)
  deallocate(fpos_p,stat=i_stat)
  call memocc(i_stat,i_all,'fpos_p',subname)

  !allocations
  allocate(eigen_r(3*atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,eigen_r,'eigen_r',subname)
  allocate(eigen_i(3*atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,eigen_i,'eigen_i',subname)
  allocate(vector_r(3*atoms%nat,3*atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,vector_r,'vector_r',subname)
  allocate(vector_l(3*atoms%nat,3*atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,vector_l,'vector_l',subname)

  !Diagonalise the hessian matrix
  call solve(hessian,3*atoms%nat,eigen_r,eigen_i,vector_l,vector_r)

  if (iproc==0) then
     write(*,'(1x,a,1x,100(1pe20.10))') '=F: eigenvalues (real)      =',eigen_r(1:3*atoms%nat)
     write(*,'(1x,a,1x,100(1pe20.10))') '=F: eigenvalues (imaginary) =',eigen_i(1:3*atoms%nat)
     do i=1,3*atoms%nat
        if (eigen_r(i)<0.0_dp) then
           eigen_r(i)=-sqrt(-eigen_r(i))
       else
           eigen_r(i)= sqrt( eigen_r(i))
       end if
     end do
     write(*,'(1x,a,1x,100(1pe20.10))') '=F: frequencies (Hartree)   =',eigen_r(1:3*atoms%nat)
     write(*,'(1x,a,1x,100(f13.2))') '=F: frequencies (cm-1)      =',eigen_r(1:3*atoms%nat)*Ha_cmm1
     !Build frequencies.xyz
     open(unit=15,file='frequencies.xyz',status="unknown")
     do i=1,3*atoms%nat
         write(15,'(1x,i0,1x,1pe20.10,a)') atoms%nat,eigen_r(i)
         write(15,'(1x,a)') 'Frequency'
         do iat=1,atoms%nat
            ity=atoms%iatype(iat)
            do j=1,3
                write(15,'(1x,a,1x,100(1pe20.10))') &
                  atoms%atomnames(ity),vector_l(3*(iat-1)+j,i)
            end do
         end do
         !Blank line
         write(15,*)
     end do
     close(unit=15)
  end if

  !Deallocations
  i_all=-product(shape(atoms%ifrztyp))*kind(atoms%ifrztyp)
  deallocate(atoms%ifrztyp,stat=i_stat)
  call memocc(i_stat,i_all,'atoms%ifrztyp',subname)
  i_all=-product(shape(atoms%iatype))*kind(atoms%iatype)
  deallocate(atoms%iatype,stat=i_stat)
  call memocc(i_stat,i_all,'atoms%iatype',subname)
  i_all=-product(shape(atoms%natpol))*kind(atoms%natpol)
  deallocate(atoms%natpol,stat=i_stat)
  call memocc(i_stat,i_all,'atoms%natpol',subname)
  i_all=-product(shape(atoms%atomnames))*kind(atoms%atomnames)
  deallocate(atoms%atomnames,stat=i_stat)
  call memocc(i_stat,i_all,'atoms%atomnames',subname)
  i_all=-product(shape(atoms%amu))*kind(atoms%amu)
  deallocate(atoms%amu,stat=i_stat)
  call memocc(i_stat,i_all,'atoms%amu',subname)
  if (atoms%symObj >= 0) call ab6_symmetry_free(atoms%symObj)

  call free_restart_objects(rst,subname)

  i_all=-product(shape(rxyz))*kind(rxyz)
  deallocate(rxyz,stat=i_stat)
  call memocc(i_stat,i_all,'rxyz',subname)
  i_all=-product(shape(fxyz))*kind(fxyz)
  deallocate(fxyz,stat=i_stat)
  call memocc(i_stat,i_all,'fxyz',subname)

  i_all=-product(shape(hessian))*kind(hessian)
  deallocate(hessian,stat=i_stat)
  call memocc(i_stat,i_all,'hessian',subname)
  i_all=-product(shape(eigen_r))*kind(eigen_r)
  deallocate(eigen_r,stat=i_stat)
  call memocc(i_stat,i_all,'eigen_r',subname)
  i_all=-product(shape(eigen_i))*kind(eigen_i)
  deallocate(eigen_i,stat=i_stat)
  call memocc(i_stat,i_all,'eigen_i',subname)
  i_all=-product(shape(vector_l))*kind(vector_l)
  deallocate(vector_l,stat=i_stat)
  call memocc(i_stat,i_all,'vector_l',subname)
  i_all=-product(shape(vector_r))*kind(vector_r)
  deallocate(vector_r,stat=i_stat)
  call memocc(i_stat,i_all,'vector_r',subname)
  i_all=-product(shape(moves))*kind(moves)
  deallocate(moves,stat=i_stat)
  call memocc(i_stat,i_all,'moves',subname)
  i_all=-product(shape(forces))*kind(forces)
  deallocate(forces,stat=i_stat)
  call memocc(i_stat,i_all,'forces',subname)

  call free_input_variables(inputs)

  !finalize memory counting
  call memocc(0,0,'count','stop')

  if (nproc > 1) call MPI_FINALIZE(ierr)

contains

  subroutine solve(hessian,n,eigen_r,eigen_i,vector_l,vector_r)
    implicit none
    integer, intent(in) :: n
    real(gp), intent(inout) :: hessian(n,n)
    real(gp), intent(out) :: eigen_r(n),eigen_i(n),vector_l(n,n),vector_r(n,n)
    !Local variables
    integer :: info,lwork
    real(gp), dimension(:), allocatable :: work

    lwork=6*n
    allocate(work(lwork+ndebug),stat=i_stat)
    call memocc(i_stat,work,'work',subname)

    call dgeev('V','V',n,hessian,n,eigen_r,eigen_i,vector_l,n,vector_r,n,work,lwork,info)

    if (info /= 0) then
       write(*,'(1x,a,i0)') 'Error from the routine dgeev: info=',info
    end if
    i_all=-product(shape(work))*kind(work)
    deallocate(work,stat=i_stat)
    call memocc(i_stat,i_all,'work',subname)

  END SUBROUTINE solve

END PROGRAM frequencies
!!***
