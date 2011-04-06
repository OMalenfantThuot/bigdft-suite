!> @file
!! Routines to read NetCDF (ETSF) format
!! @author
!!    Copyright (C) 2009-2011 BigDFT group 
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 

!>   Read a ETSF (NETCDF) file containing wavefunctions.
!!    coordinates_of_grid_points is used to store the geometric
!!   position of coefficients of wavelets i, as integer in
!!   dtset%wvl%ni(:) dimensions.
!!   coefficients_of_wavefunctions is used to store the psi values for
!!   each wavelet.
subroutine read_waves_etsf(iproc,filename,orbs,n1,n2,n3,hx,hy,hz,at,rxyz_old,rxyz,  & 
     wfd,psi)
  use module_base
  use module_types

  use etsf_io_low_level
  use etsf_io

  implicit none

  integer, intent(in) :: iproc,n1,n2,n3
  real(gp), intent(in) :: hx,hy,hz
  type(wavefunctions_descriptors), intent(in) :: wfd
  type(orbitals_data), intent(inout) :: orbs
  type(atoms_data), intent(in) :: at
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  real(gp), dimension(3,at%nat), intent(out) :: rxyz_old
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,orbs%norbp*orbs%nspinor), intent(out) :: psi
  character(len = *), intent(in) :: filename
  ! Local variables
  character(len = *), parameter :: subname = "read_waves_etsf"
  integer, pointer :: nvctr_old(:)
  integer :: iCoeff, iFine, n1_old, n2_old, n3_old, nvctr_c_old, nvctr_f_old
  integer :: i, iorb, ncid, iGrid, diGrid, nspin, ispin
  integer :: nb1, nb2, nb3, i_all, i_stat, ncount1,ncount_rate,ncount_max, ncount2
  integer :: start(6), count(6), coord(3)
  real :: tr0,tr1
  real(gp) :: hx_old, hy_old, hz_old
  real(gp) :: displ,tel
  real(wp) :: fv(7)
  logical :: perx, pery, perz
  integer, dimension(:,:), allocatable :: gcoord
  double precision, dimension(:,:,:), allocatable :: eigen
  real(wp), dimension(:,:,:), allocatable :: psifscf
  real(wp), dimension(:,:,:,:,:,:), allocatable :: psigold
  type(etsf_io_low_error) :: error
  logical :: lstat

  call cpu_time(tr0)
  call system_clock(ncount1,ncount_rate,ncount_max)

  ! We open the ETSF file
  call etsf_io_low_open_read(ncid, filename, lstat, error_data = error)
  if (.not. lstat) call etsf_error(error)

  ! We read the basis set description and the atomic definition.
  call etsf_read_descr(ncid, n1_old, n2_old, n3_old, hx_old, hy_old, hz_old, &
       & rxyz_old, at%nat, nvctr_old, nvctr_c_old, nvctr_f_old)

  !conditions for periodicity in the three directions
  call calc_displ(at, rxyz, rxyz_old, displ, perx, pery, perz)

  nspin = 1
  if (orbs%norbd /= 0) nspin = 2

  start(:) = 1
  count(:) = 0
  if (abs(hx_old - hx) < 1e-6 .and. abs(hy_old - hy) < 1e-6 .and. abs(hz_old - hz) < 1e-6 .and. &
       & nvctr_c_old == wfd%nvctr_c .and. nvctr_f_old == wfd%nvctr_f .and. & 
       & n1_old == n1 .and. n2_old == n2 .and. n3_old == n3 .and. displ <= 1.d-3) then
     if (iproc == 0) write(*,*) 'wavefunctions need NO reformatting'

     do iorb = 1, orbs%norbp*orbs%nspinor, 1
        ! Read one spinor.
        start(3) = modulo(iorb - 1, orbs%nspinor) + 1
        count(3) = 1
        ! Read one orbital.
        start(4) = modulo(orbs%isorb + (iorb - 1) / orbs%nspinor, orbs%norb) + 1
        count(4) = 1
        ! Read one kpoint.
        start(5) = (orbs%isorb + (iorb - 1) / orbs%nspinor) / orbs%norb + 1
        count(5) = 1
        ! Write one spin.
        start(6) = 1
        if (start(4) > orbs%norbu) then
           start(6) = 2
           start(4) = start(4) - orbs%norbu
        end if
        count(6) = 1

        iFine = wfd%nvctr_c + 1
        iCoeff = 1
        iGrid = 1
        do
           if (iGrid > wfd%nvctr_c) exit
           diGrid = 0
           do
              if (nvctr_old(iGrid + diGrid) /= 1 .or. &
                   & iGrid + diGrid == wfd%nvctr_c) exit
              diGrid = diGrid + 1
           end do
           ! Read diGrid + 1 coeff.
           start(2) = iCoeff
           count(2) = diGrid + 1
           call etsf_io_low_read_var(ncid, "coefficients_of_wavefunctions", &
                & psi(iGrid:iGrid + diGrid, iorb), lstat, error_data = error, start = start, count = count)
           if (.not. lstat) call etsf_error(error)
           iCoeff  = iCoeff + diGrid + 1
           
           if (nvctr_old(iGrid + diGrid) == 8) then
              ! Write seven coeff.
              start(2) = iCoeff
              count(2) = 7
              call etsf_io_low_read_var(ncid, "coefficients_of_wavefunctions", &
                   & psi(iFine:iFine+6, iorb), lstat, error_data = error, start = start, count = count)
              if (.not. lstat) call etsf_error(error)
              iCoeff = iCoeff + 7
              iFine  = iFine + 7
           end if
           iGrid = iGrid + diGrid + 1
        end do
     end do
!!$     write(33 + iproc,"(G18.10)") psi
  else
     if (iproc == 0) then
        write(*,*) 'wavefunctions need reformatting'
        if (hx_old /= hx .or. hy_old /= hy .or. hz_old /= hz) &
             & write(*,*) 'because hgrid_old /= hgrid',hx_old,hy_old,hz_old,hx,hy,hz
        if (nvctr_c_old /= wfd%nvctr_c) &
             & write(*,*) 'because nvctr_c_old /= nvctr_c',nvctr_c_old,wfd%nvctr_c
        if (nvctr_f_old /= wfd%nvctr_f) &
             & write(*,*) 'because nvctr_f_old /= nvctr_f',nvctr_f_old,wfd%nvctr_f
        if (n1_old /= n1  .or. n2_old /= n2 .or. n3_old /= n3 ) &
             & write(*,*) 'because cell size has changed',n1_old,n1,n2_old,n2,n3_old,n3
        if (displ > 1.d-3 ) &
             & write(*,*) 'because of large displacement of molecule'
     end if

     ! We read the coordinates of grid points.
     allocate(gcoord(3,nvctr_c_old+ndebug),stat=i_stat)
     call memocc(i_stat,gcoord,'gcoord',subname)
     call etsf_io_low_read_var(ncid, "coordinates_of_basis_grid_points", &
          & gcoord, lstat, error_data = error)
     if (.not. lstat) call etsf_error(error)

     !buffers realted to periodicity
     !WARNING: the boundary conditions are not assumed to change between new and old
     call ext_buffers_coarse(perx,nb1)
     call ext_buffers_coarse(pery,nb2)
     call ext_buffers_coarse(perz,nb3)

     allocate(psifscf(-nb1:2*n1+1+nb1,-nb2:2*n2+1+nb2,-nb3:2*n3+1+nb3+ndebug),stat=i_stat)
     call memocc(i_stat,psifscf,'psifscf',subname)

     allocate(psigold(0:n1_old,2,0:n2_old,2,0:n3_old,2+ndebug),stat=i_stat)
     call memocc(i_stat,psigold,'psigold',subname)
     call razero(8*(n1_old+1)*(n2_old+1)*(n3_old+1),psigold)

     do iorb = 1, orbs%norbp*orbs%nspinor, 1
        ! We read the coefficients.
        ! Read one spinor.
        start(3) = modulo(iorb - 1, orbs%nspinor) + 1
        count(3) = 1
        ! Read one orbital.
        start(4) = modulo(orbs%isorb + (iorb - 1) / orbs%nspinor, orbs%norb) + 1
        count(4) = 1
        ! Read one kpoint.
        start(5) = (orbs%isorb + (iorb - 1) / orbs%nspinor) / orbs%norb + 1
        count(5) = 1
        ! Write one spin.
        start(6) = 1
        if (start(4) > orbs%norbu) then
           start(6) = 2
           start(4) = start(4) - orbs%norbu
        end if
        count(6) = 1

        ! We transfer the coefficients in psigold.
        iCoeff = 1
        do i = 1, nvctr_c_old, 1
           coord = gcoord(:, i)
           start(2) = iCoeff
           count(2) = 1
           call etsf_io_low_read_var(ncid, "coefficients_of_wavefunctions", &
                & psigold(coord(1), 1, coord(2), 1, coord(3), 1), &
                & lstat, error_data = error, start = start, count = count)
           if (.not. lstat) call etsf_error(error)
           iCoeff = iCoeff + 1
           if (nvctr_old(i) == 8) then
              start(2) = iCoeff
              count(2) = 7
              call etsf_io_low_read_var(ncid, "coefficients_of_wavefunctions", &
                   & fv, lstat, error_data = error, start = start, count = count)
              if (.not. lstat) call etsf_error(error)
              psigold(coord(1), 2, coord(2), 1, coord(3), 1) = fv(1)
              psigold(coord(1), 1, coord(2), 2, coord(3), 1) = fv(2)
              psigold(coord(1), 2, coord(2), 2, coord(3), 1) = fv(3)
              psigold(coord(1), 1, coord(2), 1, coord(3), 2) = fv(4)
              psigold(coord(1), 2, coord(2), 1, coord(3), 2) = fv(5)
              psigold(coord(1), 1, coord(2), 2, coord(3), 2) = fv(6)
              psigold(coord(1), 2, coord(2), 2, coord(3), 2) = fv(7)
              iCoeff = iCoeff + 7
           end if
        end do

        call reformatonewave(iproc,displ,wfd,at,hx_old,hy_old,hz_old,n1_old,n2_old,n3_old,&
             rxyz_old,psigold,hx,hy,hz,n1,n2,n3,rxyz,psifscf,psi(1,iorb))
     end do

     i_all=-product(shape(psigold))*kind(psigold)
     deallocate(psigold,stat=i_stat)
     call memocc(i_stat,i_all,'psigold',subname)

     i_all=-product(shape(gcoord))*kind(gcoord)
     deallocate(gcoord,stat=i_stat)
     call memocc(i_stat,i_all,'gcoord',subname)

     i_all=-product(shape(psifscf))*kind(psifscf)
     deallocate(psifscf,stat=i_stat)
     call memocc(i_stat,i_all,'psifscf',subname)
  end if

  i_all=-product(shape(nvctr_old))*kind(nvctr_old)
  deallocate(nvctr_old,stat=i_stat)
  call memocc(i_stat,i_all,'nvctr_old',subname)

  ! We read the eigenvalues.
  if (nspin == 1) then
     call etsf_io_low_read_var(ncid, "eigenvalues", &
          & orbs%eval, lstat, error_data = error)
     if (.not. lstat) call etsf_error(error)
  else
     allocate(eigen(max(orbs%norbu, orbs%norbd), &
          & orbs%nkpts, nspin + ndebug),stat=i_stat)
     call memocc(i_stat,eigen,'eigen',subname)
     call etsf_io_low_read_var(ncid, "eigenvalues", &
          & eigen, lstat, error_data = error)
     if (.not. lstat) call etsf_error(error)
     do i = 1, orbs%norb*orbs%nkpts, 1
        ispin = 1
        iorb = modulo(i - 1, orbs%norb) + 1
        if (iorb > orbs%norbu) then
           ispin = 2
           iorb = iorb - orbs%norbu
        end if
        orbs%eval(i) = eigen(iorb, (i - 1) / orbs%norb + 1, ispin)
     end do
     i_all=-product(shape(eigen))*kind(eigen)
     deallocate(eigen,stat=i_stat)
     call memocc(i_stat,i_all,'eigen',subname)
  end if

  ! We close the file.
  call etsf_io_low_close(ncid, lstat, error)
  if (.not. lstat) call etsf_error(error)

  call cpu_time(tr1)
  call system_clock(ncount2,ncount_rate,ncount_max)
  tel=dble(ncount2-ncount1)/dble(ncount_rate)
  write(*,'(a,i4,2(1x,e10.3))') '- READING WAVES TIME',iproc,tr1-tr0,tel

contains

  subroutine etsf_error(error)
    type(etsf_io_low_error), intent(in) :: error
    
    integer :: ierr
    character(len=etsf_io_low_error_len)  :: errmess

    call etsf_io_low_error_to_str(errmess, error)
    write(0,"(A)") trim(errmess)
    call MPI_ABORT(MPI_COMM_WORLD, ierr)
  END SUBROUTINE etsf_error

  subroutine general_error(error)
    character(len = *), intent(in) :: error
    
    integer :: ierr

    write(0,"(A)") error
    call MPI_ABORT(MPI_COMM_WORLD, ierr)
  END SUBROUTINE general_error

  subroutine etsf_read_descr(ncid, n1_old, n2_old, n3_old, hx_old, hy_old, hz_old, &
       & rxyz_old, nat, nvctr_old, nvctr_c_old, nvctr_f_old)
    integer, intent(in) :: nat, ncid
    integer, intent(out) :: n1_old, n2_old, n3_old, nvctr_c_old, nvctr_f_old
    real(gp), intent(out) :: hx_old, hy_old, hz_old
    real(gp), dimension(3,nat), intent(out) :: rxyz_old
    integer, pointer :: nvctr_old(:)

    type(etsf_dims) :: dims
    logical :: lstat
    type(etsf_io_low_error) :: error
    real(dp) :: rprimd(3,3)
    integer :: iat, i_stat

    call etsf_io_dims_get(ncid, dims, lstat, error)
    if (.not. lstat) call etsf_error(error)
    ! Sanity checks
    if (dims%number_of_atoms /= nat) call general_error("Mismatch in number of atoms")
    ! The number of grid steps.
    n1_old = dims%number_of_grid_points_vector1
    n2_old = dims%number_of_grid_points_vector2
    n3_old = dims%number_of_grid_points_vector3
    ! The hgrid parameters.
    call etsf_io_low_read_var(ncid, "primitive_vectors", &
         & rprimd, lstat, error_data = error)
    if (.not. lstat) call etsf_error(error)
    hx_old = rprimd(1,1) / n1_old
    hy_old = rprimd(2,2) / n2_old
    hz_old = rprimd(3,3) / n3_old
    ! The old atomic coordinates.
    call etsf_io_low_read_var(ncid, "reduced_atom_positions", &
         & rxyz_old, lstat, error_data = error)
    if (.not. lstat) call etsf_error(error)
    do iat = 1, nat, 1
       rxyz_old(1, iat) = rxyz_old(1, iat) * rprimd(1, 1)
       rxyz_old(2, iat) = rxyz_old(2, iat) * rprimd(2, 2)
       rxyz_old(3, iat) = rxyz_old(3, iat) * rprimd(3, 3)
    end do
    ! The number of coarse and fine grid points.
    allocate(nvctr_old(dims%max_number_of_basis_grid_points+ndebug),stat=i_stat)
    call memocc(i_stat,nvctr_old,'nvctr_old',subname)
    call etsf_io_low_read_var(ncid, "number_of_coefficients_per_grid_point", &
         & nvctr_old, lstat, error_data = error)
    if (.not. lstat) call etsf_error(error)
    nvctr_c_old = dims%max_number_of_basis_grid_points
    nvctr_f_old = 0
    do i = 1, dims%max_number_of_basis_grid_points, 1
       if (nvctr_old(i) > 1) nvctr_f_old = nvctr_f_old + 1
    end do
  END SUBROUTINE etsf_read_descr

  subroutine calc_displ(at, rxyz, rxyz_old, displ, perx, pery, perz)
    type(atoms_data), intent(in) :: at
    real(gp), intent(in) :: rxyz_old(3,at%nat), rxyz(3, at%nat)
    logical, intent(out) :: perx, pery, perz
    real(gp), intent(out) :: displ

    integer :: iat
    real(gp) :: tx,ty,tz,mindist

    perx=(at%geocode /= 'F')
    pery=(at%geocode == 'P')
    perz=(at%geocode /= 'F')

    tx=0.0_gp 
    ty=0.0_gp
    tz=0.0_gp
    do iat=1,at%nat
       tx=tx+mindist(perx,at%alat1,rxyz(1,iat),rxyz_old(1,iat))**2
       ty=ty+mindist(pery,at%alat2,rxyz(2,iat),rxyz_old(2,iat))**2
       tz=tz+mindist(perz,at%alat3,rxyz(3,iat),rxyz_old(3,iat))**2
    enddo
    displ=sqrt(tx+ty+tz)
  END SUBROUTINE calc_displ
END SUBROUTINE read_waves_etsf


!>   Write a ETSF file containing wavefunctions.
!!   Write a NetCDF file.
!!    coordinates_of_grid_points is used to store the geometric
!!   position of coefficients of wavelets i, as integer in
!!   (/ n1, n2, n3 /) dimensions.
!!   coefficients_of_wavefunctions is used to store the psi values for
!!   each wavelet.
subroutine write_waves_etsf(iproc,filename,orbs,n1,n2,n3,hx,hy,hz,at,rxyz,wfd,psi)
  use module_types
  use module_base

  use etsf_io_low_level
  use etsf_io

  implicit none

  integer, intent(in) :: iproc,n1,n2,n3
  real(gp), intent(in) :: hx,hy,hz
  type(atoms_data), intent(in) :: at
  type(orbitals_data), intent(in) :: orbs
  type(wavefunctions_descriptors), intent(in) :: wfd
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,orbs%norbp*orbs%nspinor), intent(in) :: psi
  character(len = *), intent(in) :: filename

  type(etsf_io_low_error) :: error
  logical :: lstat
  integer :: ncid, ierr, nproc
  integer :: i_all, i_stat, ncount1,ncount_rate,ncount_max, ncount2, i
  integer :: iCoeff, iFine, iGrid, iorb, diGrid
  integer :: start(6), count(6)
  real :: tr0,tr1
  integer, allocatable :: nvctr(:)
  integer, allocatable :: gcoord(:,:)
  real(gp) :: tel
  logical, parameter :: sequential = .false.
  character(len = *), parameter :: subname = "write_waves_etsf"

  integer :: iproc_writing

  call MPI_COMM_SIZE(MPI_COMM_WORLD,nproc,ierr)

  ! nvctr array will contains the number of coeff per grid point,
  ! required by all processors.
  allocate(nvctr(wfd%nvctr_c),stat=i_stat)
  call memocc(i_stat,nvctr,'nvctr',subname)
  allocate(gcoord(3, wfd%nvctr_c),stat=i_stat)
  call memocc(i_stat,gcoord,'gcoord',subname)
  call build_grid(n1, n2, n3, nvctr, gcoord, wfd)

  ! Only the master proc create the file.
  if (iproc == 0) then
     call cpu_time(tr0)
     call system_clock(ncount1,ncount_rate,ncount_max)

     call etsf_io_low_open_create(ncid, filename, 1.3, lstat, &
          & title = "BigDFT wavefunctions", error_data = error, &
          & overwrite = .true., with_etsf_header = .true.)
     if (.not. lstat) call etsf_error(error)

     call etsf_write_global(ncid,orbs, n1,n2,n3,hx,hy,hz,rxyz,at,wfd,gcoord,nvctr)

     ! We close the file.
     call etsf_io_low_close(ncid, lstat, error)
     if (.not. lstat) call etsf_error(error)
  end if

  i_all=-product(shape(gcoord))*kind(gcoord)
  deallocate(gcoord)
  call memocc(i_stat,i_all,'gcoord',subname)

  iproc_writing = 0

  ! Now that the file is created and writable, we call the writing routines.
  if (sequential) then
     do i = 0, iproc - 1, 1
        call MPI_BARRIER(MPI_COMM_WORLD, ierr)
     end do
  else
     call MPI_BARRIER(MPI_COMM_WORLD, ierr)
  end if

  call etsf_io_low_open_modify(ncid, filename, lstat, error_data = error)
  if (.not. lstat) call etsf_error(error)
  call etsf_io_low_set_write_mode(ncid, lstat, error)
  if (.not. lstat) call etsf_error(error)

  start(:) = 1
  count(:) = 0
!!$  write(23 + iproc, "(G18.10)") psi
  do iorb = 1, orbs%norbp*orbs%nspinor, 1
     ! Write one spinor.
     start(3) = modulo(iorb - 1, orbs%nspinor) + 1
     count(3) = 1
     ! Write one orbital.
     start(4) = modulo(orbs%isorb + (iorb - 1) / orbs%nspinor, orbs%norb) + 1
     count(4) = 1
     ! Write one kpoint.
     start(5) = (orbs%isorb + (iorb - 1) / orbs%nspinor) / orbs%norb + 1
     count(5) = 1
     ! Write one spin.
     start(6) = 1
     if (start(4) > orbs%norbu) then
        start(6) = 2
        start(4) = start(4) - orbs%norbu
     end if
     count(6) = 1

     ! iCoeff is the index of the coefficient we are writing in ETSF
     iCoeff  = 1
     ! iFine is the index of the fine part in psi
     iFine = wfd%nvctr_c + 1
     ! iGrid runs on all grid points.
     iGrid = 1
     do
        if (iGrid > wfd%nvctr_c) exit
        diGrid = 0
        do
           if (nvctr(iGrid + diGrid) /= 1 .or. iGrid + diGrid == wfd%nvctr_c) exit
           diGrid = diGrid + 1
        end do
        ! Write diGrid + 1 coeff.
        start(2) = iCoeff
        count(2) = diGrid + 1
        call etsf_io_low_write_var(ncid, "coefficients_of_wavefunctions", &
             & psi(iGrid:iGrid + diGrid, iorb), lstat, error_data = error, start = start, count = count)
        if (.not. lstat) call etsf_error(error)
        iCoeff  = iCoeff + diGrid + 1

        if (nvctr(iGrid + diGrid) == 8) then
           ! Write seven coeff.
           start(2) = iCoeff
           count(2) = 7
           call etsf_io_low_write_var(ncid, "coefficients_of_wavefunctions", &
                & psi(iFine:iFine+6, iorb), lstat, error_data = error, start = start, count = count)
           if (.not. lstat) call etsf_error(error)
           iCoeff = iCoeff + 7
           iFine  = iFine  + 7
        end if
        iGrid = iGrid + diGrid + 1
     end do
  end do
  i_all=-product(shape(nvctr))*kind(nvctr)
  deallocate(nvctr)
  call memocc(i_stat,i_all,'nvctr',subname)

  call etsf_io_low_close(ncid, lstat, error)
  if (.not. lstat) call etsf_error(error)

  ! We wait for all procs to write their waves.
  if (sequential) then
     do i = iproc, nproc - 1, 1
        call MPI_BARRIER(MPI_COMM_WORLD, ierr)
     end do
  else
     call MPI_BARRIER(MPI_COMM_WORLD, ierr)
  end if

  if (iproc == 0) then
     call cpu_time(tr1)
     call system_clock(ncount2,ncount_rate,ncount_max)
     tel=dble(ncount2-ncount1)/dble(ncount_rate)
     write(*,'(a,i4,2(1x,e10.3))') '- WRITING WAVES TIME',iproc,tr1-tr0,tel
  end if

contains

  subroutine etsf_error(error)
    type(etsf_io_low_error), intent(in) :: error
    
    integer :: ierr
    character(len=etsf_io_low_error_len)  :: errmess

    call etsf_io_low_error_to_str(errmess, error)
    write(0,"(A)") "Error: ETSF_IO error for proc", iproc
    write(0,"(A)") trim(errmess)
    call MPI_ABORT(MPI_COMM_WORLD, ierr)
  END SUBROUTINE etsf_error

  subroutine etsf_write_global(ncid,orbs, n1,n2,n3,hx,hy,hz,rxyz,at,wfd,gcoord,nvctr)
    integer, intent(in) :: ncid, n1, n2, n3
    real(gp), intent(in) :: hx, hy, hz
    type(atoms_data), intent(in) :: at
    type(orbitals_data), intent(in) :: orbs
    type(wavefunctions_descriptors), intent(in) :: wfd
    real(gp), intent(in) :: rxyz(3,at%nat)
    integer, target, intent(in) :: nvctr(wfd%nvctr_c)
    integer, target, intent(in) :: gcoord(3,wfd%nvctr_c)

    type(etsf_dims) :: dims
    type(etsf_geometry) :: geo
    type(etsf_basisdata) :: basis
    type(etsf_electrons) :: elec
    integer :: i_all, i_stat, iat, i, ispin, iorb
    double precision, target :: rprimd(3,3)
    double precision, allocatable, target :: xred(:,:)
    double precision, dimension(:), allocatable, target :: znucl
    character(len=etsf_chemlen), allocatable, dimension(:), target :: spnames
    logical :: lstat
    type(etsf_io_low_error) :: error

    ! Unused dims, to be removed later
    dims%number_of_components = etsf_no_dimension
    dims%number_of_atom_species = etsf_no_dimension
    dims%max_number_of_angular_momenta = etsf_no_dimension
    dims%max_number_of_projectors = etsf_no_dimension
    dims%number_of_coefficients_dielectric_function = etsf_no_dimension
    dims%number_of_frequencies_dielectric_function = etsf_no_dimension
    dims%number_of_qpoints_dielectric_function = etsf_no_dimension
    dims%number_of_qpoints_gamma_limit = etsf_no_dimension
    dims%number_of_symmetry_operations = etsf_no_dimension
    dims%real_or_complex_gw_corrections = etsf_no_dimension
    dims%real_or_complex_wavefunctions = etsf_no_dimension
    dims%real_or_complex_density = etsf_no_dimension
    dims%real_or_complex_potential = etsf_no_dimension

    ! Specific dims of interest.
    dims%real_or_complex_coefficients = 1
    dims%max_number_of_coefficients = wfd%nvctr_c+7*wfd%nvctr_f
    dims%number_of_spinor_components = orbs%nspinor
    dims%max_number_of_states = max(orbs%norbu, orbs%norbd)
    dims%number_of_kpoints = orbs%nkpts
    if (orbs%norbd > 0) then
       dims%number_of_spins = 2
    else
       dims%number_of_spins = 1
    end if

    dims%max_number_of_basis_grid_points = wfd%nvctr_c
    dims%number_of_localization_regions = 1

    dims%number_of_atoms               = at%nat
    dims%number_of_atom_species        = at%ntypes
    dims%number_of_grid_points_vector1 = n1
    dims%number_of_grid_points_vector2 = n2
    dims%number_of_grid_points_vector3 = n3

    ! We write the dimensions to the file.
    call etsf_io_dims_def(ncid, dims, lstat, error)
    if (.not. lstat) call etsf_error(error)

    ! We set up the required variables.
    call etsf_io_geometry_def(ncid, lstat, error, &
         & flags = etsf_geometry_primitive_vectors + etsf_geometry_atom_species + &
         & etsf_geometry_red_at_pos + etsf_geometry_atomic_numbers + &
         & etsf_geometry_chemical_symbols)
    if (.not. lstat) call etsf_error(error)
    call etsf_io_basisdata_def(ncid, lstat, error, &
         & flags = etsf_basisdata_coord_grid + etsf_basisdata_n_coeff_grid)
    if (.not. lstat) call etsf_error(error)
    call etsf_io_electrons_def(ncid, lstat, error, flags = etsf_electrons_eigenvalues)
    if (.not. lstat) call etsf_error(error)
    call etsf_io_main_def(ncid, lstat, error, flags = etsf_main_wfs_coeff)
    if (.not. lstat) call etsf_error(error)

    ! We write the global informations.
    ! Geometry
    rprimd = reshape((/ (hx * n1),0.0_gp,0.0_gp, &
         & 0.0_gp,(hy * n2),0.0_gp, &
         & 0.0_gp,0.0_gp,(hz * n3) /), (/ 3, 3 /))
    allocate(xred(3, at%nat),stat=i_stat)
    call memocc(i_stat,xred,'xred',subname)
    do iat = 1, at%nat, 1
       xred(:, iat) = rxyz(:, iat) / (/ hx * n1, hy * n2, hz * n3 /)
    end do
    allocate(znucl(at%ntypes),stat=i_stat)
    call memocc(i_stat,znucl,'znucl',subname)
    znucl = real(at%nzatom)
    allocate(spnames(at%ntypes),stat=i_stat)
    call memocc(i_stat,spnames,'spnames',subname)
    do iat = 1, at%ntypes, 1
       call nzsymbol(at%nzatom(iat), spnames(iat))
    end do
    geo%chemical_symbols       => spnames
    geo%atom_species           => at%iatype
    geo%atomic_numbers         => znucl
    geo%reduced_atom_positions => xred
    geo%primitive_vectors      => rprimd
    call etsf_io_geometry_put(ncid, geo, lstat, error)
    if (.not. lstat) call etsf_error(error)
    i_all=-product(shape(xred))*kind(xred)
    deallocate(xred)
    call memocc(i_stat,i_all,'xred',subname)
    i_all=-product(shape(znucl))*kind(znucl)
    deallocate(znucl)
    call memocc(i_stat,i_all,'znucl',subname)
    i_all=-product(shape(spnames))*kind(spnames)
    deallocate(spnames)
    call memocc(i_stat,i_all,'spnames',subname)
    ! The eigenvalues
    if (dims%number_of_spins == 1) then
       elec%eigenvalues%data1D => orbs%eval
    else
       allocate(elec%eigenvalues%data3D(dims%max_number_of_states, &
            & dims%number_of_kpoints, dims%number_of_spins + ndebug),stat=i_stat)
       call memocc(i_stat,elec%eigenvalues%data3D,'elec%eigenvalues%data3D',subname)
       elec%eigenvalues%data3D = 999.
       do i = 1, orbs%norb*orbs%nkpts, 1
          ispin = 1
          iorb = modulo(i - 1, orbs%norb) + 1
          if (iorb > orbs%norbu) then
             ispin = 2
             iorb = iorb - orbs%norbu
          end if
          elec%eigenvalues%data3D(iorb, (i - 1) / orbs%norb + 1, ispin) = orbs%eval(i)
       end do
    end if
    call etsf_io_electrons_put(ncid, elec, lstat, error)
    if (.not. lstat) call etsf_error(error)
    if (dims%number_of_spins /= 1) then
       i_all=-product(shape(elec%eigenvalues%data3D))*kind(elec%eigenvalues%data3D)
       deallocate(elec%eigenvalues%data3D)
       call memocc(i_stat,i_all,'elec%eigenvalues%data3D',subname)
    end if
    ! Basis set
    basis%coordinates_of_basis_grid_points%data2D => gcoord
    basis%number_of_coefficients_per_grid_point%data1D => nvctr
    call etsf_io_basisdata_put(ncid, basis, lstat, error)
    if (.not. lstat) call etsf_error(error)
  END SUBROUTINE etsf_write_global

  subroutine build_grid(n1,n2,n3,nvctr, gcoord, wfd)
    integer, intent(in) :: n1, n2, n3
    type(wavefunctions_descriptors), intent(in) :: wfd
    integer, intent(out) :: nvctr(wfd%nvctr_c)
    integer, intent(out) :: gcoord(3,wfd%nvctr_c)

    integer :: i_stat, i_all, ii, i0, i1, i2, i3, jj, j0, j1, iGrid, i, iseg
    integer, allocatable :: coeff_map(:,:,:)

    ! Will store the grid index for a given geometric point
    allocate(coeff_map(0:n1, 0:n2, 0:n3),stat=i_stat)
    call memocc(i_stat,coeff_map,'coeff_map',subname)
    ! coarse part
    coeff_map = 0
    do iseg = 1, wfd%nseg_c
       jj = wfd%keyv(iseg)
       j0 = wfd%keyg(1, iseg)
       j1 = wfd%keyg(2, iseg)
       ii = j0 - 1
       i3 = ii / ((n1 + 1) * (n2 + 1))
       ii = ii - i3 * (n1 + 1) * (n2 + 1)
       i2 = ii / (n1 + 1)
       i0 = ii - i2 * (n1 + 1)
       i1 = i0 + j1 - j0
       do i = i0, i1
          iGrid = i - i0 + jj
          coeff_map(i, i2, i3) = iGrid
          gcoord(:, iGrid) = (/ i, i2, i3 /)
          nvctr(iGrid) = 1
       end do
    end do
    ! fine part
    do iseg = 1, wfd%nseg_f
       jj = wfd%keyv(wfd%nseg_c + iseg)
       j0 = wfd%keyg(1, wfd%nseg_c + iseg)
       j1 = wfd%keyg(2, wfd%nseg_c + iseg)
       ii = j0 - 1
       i3 = ii / ((n1 + 1) * (n2 + 1))
       ii = ii - i3 * (n1 + 1) * (n2 + 1)
       i2 = ii / (n1 + 1)
       i0 = ii - i2 * (n1 + 1)
       i1 = i0 + j1 - j0
       do i = i0, i1
          iGrid = coeff_map(i , i2 , i3)
          nvctr(iGrid) = nvctr(iGrid) + 7
       end do
    end do

    i_all=-product(shape(coeff_map))*kind(coeff_map)
    deallocate(coeff_map)
    call memocc(i_stat,i_all,'coeff_map',subname)
  END SUBROUTINE build_grid
END SUBROUTINE write_waves_etsf