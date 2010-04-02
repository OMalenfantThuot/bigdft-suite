!!****f* BigDFT/print_logo
!! FUNCTION
!!    Display the logo of BigDFT 
!! COPYRIGHT
!!    Copyright (C) 2007-2010 BigDFT group 
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 
!! SOURCE
!!
subroutine print_logo()
  use module_base
  implicit none
  integer :: length
  character(len = 64) :: fmt

  length = 26 - 6 - len(package_version)
  write(fmt, "(A,I0,A)") "(23x,a,", length, "x,a)"

  write(*,'(23x,a)')'      TTTT         F       DDDDD    '
  write(*,'(23x,a)')'     T    T               D         '
  write(*,'(23x,a)')'    T     T        F     D          '
  write(*,'(23x,a)')'    T    T         F     D        D '
  write(*,'(23x,a)')'    TTTTT          F     D         D'
  write(*,'(23x,a)')'    T    T         F     D         D'
  write(*,'(23x,a)')'    T     T        F     D         D'
  write(*,'(23x,a)')'    T      T       F     D         D'
  write(*,'(23x,a)')'    T     T     FFFF     D         D'
  write(*,'(23x,a)')'    T TTTT         F      D        D'
  write(*,'(23x,a)')'    T             F        D      D '
  write(*,'(23x,a)')'TTTTTTTTT    FFFFF          DDDDDD  ' 
  !write(*,'(23x,a)')'---------------------------------------'
  write(*,'(23x,a)')'  gggggg          iiiii    BBBBBBBBB'
  write(*,'(23x,a)')' g      g        i             B    '
  write(*,'(23x,a)')'g        g      i         BBBB B    '
  write(*,'(23x,a)')'g         g     iiii     B     B    '
  write(*,'(23x,a)')'g         g     i       B      B    '
  write(*,'(23x,a)')'g         g     i        B     B    '
  write(*,'(23x,a)')'g         g     i         B    B    '
  write(*,'(23x,a)')'g         g     i          BBBBB    '
  write(*,'(23x,a)')' g        g     i         B    B    '  
  write(*,'(23x,a)')'          g     i        B     B    ' 
  write(*,'(23x,a)')'         g               B    B     '
  write(*,fmt)      '    ggggg       i         BBBB      ', &
       & '(Ver ' // package_version // ')'
  write(*,'(1x,a)')&
       '------------------------------------------------------------------------------------'
  write(*,'(1x,a)')&
       '|              Daubechies Wavelets for DFT Pseudopotential Calculations            |'
  write(*,'(1x,a)')&
       '------------------------------------------------------------------------------------'
  write(*,'(1x,a)')&
       '                                  The Journal of Chemical Physics 129, 014109 (2008)'
END SUBROUTINE print_logo
!!***

!!****f* BigDFT/read_input_variables
!! FUNCTION
!!    Do all initialisation for all different files of BigDFT. 
!!    Set default values if not any.
!!    Initialize memocc
!! SOURCE
!!
subroutine read_input_variables(iproc,posinp, &
     & file_dft, file_kpt, file_geopt, file_perf, inputs,atoms,rxyz)
  use module_base
  use module_types
  use module_interfaces, except_this_one => read_input_variables

  implicit none

  !Arguments
  character(len=*), intent(in) :: posinp
  character(len=*), intent(in) :: file_dft, file_geopt, file_kpt, file_perf
  integer, intent(in) :: iproc
  type(input_variables), intent(out) :: inputs
  type(atoms_data), intent(out) :: atoms
  real(gp), dimension(:,:), pointer :: rxyz
  !Local variables
  real(gp) :: tt
  integer :: iat

  ! Default
  call default_input_variables(inputs)

  ! Read atomic file
  call read_atomic_file(posinp,iproc,atoms,rxyz)

  ! Read performance input variables (if given)
  call perf_input_variables(iproc,file_perf,inputs)
  ! Read dft input variables
  call dft_input_variables(iproc,file_dft,inputs)
  call update_symmetries(inputs, atoms, rxyz)
  ! Read k-points input variables (if given)
  call kpt_input_variables(iproc,file_kpt,inputs,atoms)
  ! Read geometry optimisation option
  call geopt_input_variables(file_geopt,inputs)

  ! Shake atoms if required.
  if (inputs%randdis > 0.d0) then
     do iat=1,atoms%nat
        if (atoms%ifrztyp(iat) == 0) then
           call random_number(tt)
           rxyz(1,iat)=rxyz(1,iat)+inputs%randdis*tt
           call random_number(tt)
           rxyz(2,iat)=rxyz(2,iat)+inputs%randdis*tt
           call random_number(tt)
           rxyz(3,iat)=rxyz(3,iat)+inputs%randdis*tt
        end if
     enddo
  end if

  !atoms inside the box.
  do iat=1,atoms%nat
     if (atoms%geocode == 'P') then
        rxyz(1,iat)=modulo(rxyz(1,iat),atoms%alat1)
        rxyz(2,iat)=modulo(rxyz(2,iat),atoms%alat2)
        rxyz(3,iat)=modulo(rxyz(3,iat),atoms%alat3)
     else if (atoms%geocode == 'S') then
        rxyz(1,iat)=modulo(rxyz(1,iat),atoms%alat1)
        rxyz(3,iat)=modulo(rxyz(3,iat),atoms%alat3)
     end if
  end do

  !stop the code if it is trying to run GPU with non-periodic boundary conditions
  if (atoms%geocode /= 'P' .and. GPUconv) then
     stop 'GPU calculation allowed only in periodic boundary conditions'
  end if

END SUBROUTINE read_input_variables
!!***

subroutine default_input_variables(inputs)
  use module_base
  use module_types
  implicit none

  type(input_variables), intent(out) :: inputs

  ! Default values.
  nullify(inputs%kpt)
  nullify(inputs%wkpt)
  ! Default abscalc variables
  call abscalc_input_variables_default(inputs)
  ! Default frequencies variables
  call frequencies_input_variables_default(inputs)
  ! Default values for geopt.
  call geopt_input_variables_default(inputs)  
END SUBROUTINE default_input_variables

!!****f* BigDFT/dft_input_variables
!! FUNCTION
!!    Read the input variables needed for the DFT calculation
!!    The variables are divided in two groups:
!!    "cruising" variables -- general DFT run
!!    "brakeing" variables -- for the last run, once relaxation is achieved
!!                            of for a single-point calculation
!!    Every argument should be considered as mandatory
!! SOURCE
!!
subroutine dft_input_variables(iproc,filename,in)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  type(input_variables), intent(out) :: in
  !local variables
  character(len=7) :: string
  character(len=100) :: line
  logical :: exists
  integer :: ierror,ierrfrc,iconv,iblas,iline,initerror,ivrbproj,useGPU

  ! Read the input variables.
  inquire(file=trim(filename),exist=exists)
  if (.not.exists) then
      write(*,*) "The file 'input.dft' does not exist!"
      stop
  end if

  ! Open the file
  open(unit=1,file=filename,status='old')

  !line number, to control the input values
  iline=0
  !grid spacings
  read(1,*,iostat=ierror) in%hx,in%hy,in%hz
  call check()
  !coarse and fine radii around atoms
  read(1,*,iostat=ierror) in%crmult,in%frmult
  call check()
  !XC functional (ABINIT XC codes)
  read(1,*,iostat=ierror) in%ixc
  call check()
  !charged system, electric field (intensity and start-end points)
  call check()
  read(1,*,iostat=ierror) in%ncharge,in%elecfield
  call check()
  read(1,*,iostat=ierror) in%nspin,in%mpol
  call check()
  read(1,*,iostat=ierror) in%gnrm_cv
  call check()
  read(1,*,iostat=ierror) in%itermax,in%nrepmax
  call check()
  read(1,*,iostat=ierror) in%ncong,in%idsx
  call check()
  read(1,*,iostat=ierror) in%dispersion
  call check()
  !read the line for force the CUDA GPU calculation for all processors
  read(1,'(a100)')line
  read(line,*,iostat=ierrfrc) string
  iline=iline+1
  if (ierrfrc == 0 .and. string=='CUDAGPU') then
     call sg_init(GPUshare,useGPU,iproc,initerror)
     if (useGPU == 1) then
        iconv = 1
        iblas = 1
     else
        iconv = 0
        iblas = 0
     end if

     if (initerror == 1) then
        write(*,'(1x,a)')'**** ERROR: S_GPU library init failed, aborting...'
        call MPI_ABORT(MPI_COMM_WORLD,initerror,ierror)
     end if
       
     if (iconv == 1) then
        !change the value of the GPU convolution flag defined in the module_base
        GPUconv=.true.
     end if
     if (iblas == 1) then
        !change the value of the GPU convolution flag defined in the module_base
        GPUblas=.true.
     end if
  end if

  !now the variables which are to be used only for the last run
  read(1,*,iostat=ierror) in%inputPsiId,in%output_wf,in%output_grid
  call check()
  !project however the wavefunction on gaussians if asking to write them on disk
  in%gaussian_help=(in%inputPsiId >= 10)! commented .or. in%output_wf 
  !switch on the gaussian auxiliary treatment 
  !and the zero of the forces
  if (in%inputPsiId == 10) then
     in%inputPsiId=0
  end if
  read(1,*,iostat=ierror) in%rbuf,in%ncongt
  call check()
  in%calc_tail=(in%rbuf > 0.0_gp)

  !davidson treatment
  read(1,*,iostat=ierror) in%norbv,in%nvirt,in%nplot
  call check()

  !electrostatic treatment of the vacancy (experimental)
  !read(1,*,iostat=ierror) in%nvacancy,in%read_ref_den,in%correct_offset,in%gnrm_sw
  !call check()
  in%nvacancy=0
  in%read_ref_den=.false.
  in%correct_offset=.false.
  in%gnrm_sw=0.0_gp

  !verbosity of the output
  read(1,*,iostat=ierror) ivrbproj
  call check()

  !if the verbosity is bigger than 10 apply the projectors
  !in the once-and-for-all scheme, otherwise use the default
  if (ivrbproj > 10) then
     DistProjApply=.false.
     in%verbosity=ivrbproj-10
  else
     in%verbosity=ivrbproj
  end if
!!  !temporary correction
!!  DistProjApply=.false.

  ! Line to disable automatic behaviours (currently only symmetries).
  read(1,*,iostat=ierror) in%disableSym
  call check()

!  if (in%nspin/=1 .and. in%nvirt/=0) then
!     !if (iproc==0) then
!        write(*,'(1x,a)')'ERROR: Davidson treatment allowed only for non spin-polarised systems'
!     !end if
!     stop
!  end if
! 
  close(unit=1,iostat=ierror)

  if (in%nspin/=4 .and. in%nspin/=2 .and. in%nspin/=1) then
     write(*,'(1x,a,i0)')'Wrong spin polarisation id: ',in%nspin
     stop
  end if

  !define whether there should be a last_run after geometry optimization
  !also the mulliken charge population should be inserted
  if (in%calc_tail .or. in%output_wf .or. in%output_grid /= 0 .or. in%norbv /= 0) then
     in%last_run=-1 !last run to be done depending of the external conditions
  else
     in%last_run=0
  end if

contains

  subroutine check()
    iline=iline+1
    if (ierror/=0) then
       !if (iproc == 0) 
             write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE dft_input_variables
!!***


!!****f* BigDFT/geopt_input_variables_default
!! FUNCTION
!!    Assign default values for GEOPT variables
!! SOURCE
!!
subroutine geopt_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in

  !put some fake values for the geometry optimsation case
  in%geopt_approach='SDCG'
  in%ncount_cluster_x=0
  in%frac_fluct=1.0_gp
  in%forcemax=0.0_gp
  in%randdis=0.0_gp
  in%betax=2.0_gp
  in%history = 0
  in%ionmov = -1
  in%dtion = 0.0_gp
  nullify(in%qmass)

END SUBROUTINE geopt_input_variables_default
!!***


!!****f* BigDFT/geopt_input_variables
!! FUNCTION
!!    Read the input variables needed for the geometry optimisation
!!    Every argument should be considered as mandatory
!! SOURCE
!!
subroutine geopt_input_variables(filename,in)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename
  type(input_variables), intent(inout) :: in
  !local variables
  character(len=*), parameter :: subname='geopt_input_variables'
  character(len = 128) :: line
  integer :: i_stat,ierror,iline
  logical :: exists

  inquire(file=filename,exist=exists)
  if (.not. exists) then
     in%ncount_cluster_x=0
     return
  end if

  ! Read the input variables.
  open(unit=1,file=filename,status='old')

  !line number, to control the input values
  iline=0

  read(1,*,iostat=ierror) in%geopt_approach
  call check()
  read(1,*,iostat=ierror) in%ncount_cluster_x
  call check()
  in%forcemax = 0.d0
  read(1, "(A128)", iostat = ierror) line
  if (ierror == 0) then
     read(line,*,iostat=ierror) in%frac_fluct,in%forcemax
     if (ierror /= 0) read(line,*,iostat=ierror) in%frac_fluct
     if (ierror == 0 .and. max(in%frac_fluct, in%forcemax) <= 0.d0) ierror = 1
  end if
  call check()
  read(1,*,iostat=ierror) in%randdis
  call check()
  if (trim(in%geopt_approach) == "AB6MD") then
     read(1,*,iostat=ierror) in%ionmov
     call check()
     read(1,*,iostat=ierror) in%dtion
     call check()
     if (in%ionmov == 6) then
        read(1,*,iostat=ierror) in%mditemp
        call check()
     elseif (in%ionmov > 7) then
        read(1,*,iostat=ierror) in%mditemp, in%mdftemp
        call check()
     end if
     if (in%ionmov == 8) then
        read(1,*,iostat=ierror) in%noseinert
        call check()
     else if (in%ionmov == 9) then
        read(1,*,iostat=ierror) in%friction
        call check()
        read(1,*,iostat=ierror) in%mdwall
        call check()
     else if (in%ionmov == 13) then
        read(1,*,iostat=ierror) in%nnos
        call check()
        allocate(in%qmass(in%nnos+ndebug),stat=i_stat)
        call memocc(i_stat,in%qmass,'in%qmass',subname)
        read(1,*,iostat=ierror) in%qmass
        call check()
        read(1,*,iostat=ierror) in%bmass, in%vmass
        call check()
     end if
  else if (trim(in%geopt_approach) == "DIIS") then
     read(1,*,iostat=ierror) in%betax, in%history
     call check()
  else
     read(1,*,iostat=ierror) in%betax
     call check()
  end if

  close(unit=1,iostat=ierror)

contains

  subroutine check()
    iline=iline+1
    if (ierror/=0) then
       !if (iproc == 0) 
            write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE geopt_input_variables
!!***

subroutine update_symmetries(in, atoms, rxyz)
  use module_base
  use module_types
  use defs_basis
  use ab6_symmetry
  implicit none
  type(input_variables), intent(in) :: in
  type(atoms_data), intent(inout) :: atoms
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
  !local variables
  character(len=*), parameter :: subname='update_symmetries'
  integer :: i_stat, ierr, i_all
  real(gp) :: rprimd(3, 3)
  real(gp), dimension(:,:), allocatable :: xRed

  ! Calculate the symmetries, if needed
  if (atoms%geocode /= 'F') then
     if (.not. in%disableSym) then
        if (atoms%symObj < 0) then
           call ab6_symmetry_new(atoms%symObj)
        end if
        ! New values
        rprimd(:,:) = 0
        rprimd(1,1) = atoms%alat1
        rprimd(2,2) = atoms%alat2
        if (atoms%geocode == 'S') rprimd(2,2) = 1000._gp
        rprimd(3,3) = atoms%alat3
        call ab6_symmetry_set_lattice(atoms%symObj, rprimd, ierr)
        allocate(xRed(3, atoms%nat+ndebug),stat=i_stat)
        call memocc(i_stat,xRed,'xRed',subname)
        xRed(1,:) = modulo(rxyz(1, :) / rprimd(1,1), 1._gp)
        xRed(2,:) = modulo(rxyz(2, :) / rprimd(2,2), 1._gp)
        xRed(3,:) = modulo(rxyz(3, :) / rprimd(3,3), 1._gp)
        call ab6_symmetry_set_structure(atoms%symObj, atoms%nat, atoms%iatype, xRed, ierr)
        i_all=-product(shape(xRed))*kind(xRed)
        deallocate(xRed,stat=i_stat)
        call memocc(i_stat,i_all,'xRed',subname)
        if (atoms%geocode == 'S') then
           call ab6_symmetry_set_periodicity(atoms%symObj, &
                & (/ .true., .false., .true. /), ierr)
        else if (atoms%geocode == 'F') then
           call ab6_symmetry_set_periodicity(atoms%symObj, &
                & (/ .false., .false., .false. /), ierr)
        end if
        if (in%elecfield /= 0) then
           call ab6_symmetry_set_field(atoms%symObj, (/ 0._gp, in%elecfield, 0._gp /), ierr)
        end if
     else
        if (atoms%symObj >= 0) then
           call ab6_symmetry_free(atoms%symObj)
        end if
        call ab6_symmetry_new(atoms%symObj)
        rprimd(1,1) = 0.5d0
        rprimd(2,1) = 1d0
        rprimd(3,1) = 1d0
        rprimd(1,2) = 2d0
        rprimd(2,2) = 0d0
        rprimd(3,2) = 1d0
        rprimd(1,3) = 3d0
        rprimd(2,3) = 0d0
        rprimd(3,3) = 1d0
        call ab6_symmetry_set_lattice(atoms%symObj, rprimd, ierr)
        call ab6_symmetry_set_structure(atoms%symObj, 3, (/ 1,2,3 /), rprimd / 4.d0, ierr)
     end if
  else
     if (atoms%symObj >= 0) then
        call ab6_symmetry_free(atoms%symObj)
     end if
     atoms%symObj = -1
  end if
END SUBROUTINE update_symmetries

!!****f* BigDFT/kpt_input_variables
!! FUNCTION
!!    Read the input variables needed for the k points generation
!! SOURCE
!!
subroutine kpt_input_variables(iproc,filename,in,atoms)
  use module_base
  use module_types
  use defs_basis
  use ab6_symmetry
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: in
  type(atoms_data), intent(in) :: atoms
  !local variables
  logical :: exists
  character(len=*), parameter :: subname='kpt_input_variables'
  character(len = 6) :: type
  integer :: i_stat,ierror,iline,i,nshiftk, ngkpt(3)
  real(gp) :: kptrlen, shiftk(3,8), norm, alat(3)

  ! Set default values.
  in%nkpt = 1

  inquire(file=trim(filename),exist=exists)
  if (.not. exists) then
     ! Set only the gamma point.
     allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%kpt,'in%kpt',subname)
     in%kpt(:, 1) = (/ 0., 0., 0. /)
     allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%wkpt,'in%wkpt',subname)
     in%wkpt(1) = 1.
     return
  !and control whether we are giving k-points to Free BC
  else if (atoms%geocode == 'F') then
     if (iproc==0) write(*,*)&
          ' NONSENSE: Trying to use k-points with Free Boundary Conditions!'
     stop
  end if

  ! Real generation of k-point set.
  open(unit=1,file=filename,status='old')

  !line number, to control the input values
  iline=0

  read(1,*,iostat=ierror) type
  call check()

  if (trim(type) == "auto" .or. trim(type) == "Auto" .or. trim(type) == "AUTO") then
     read(1,*,iostat=ierror) kptrlen
     call check()

     call ab6_symmetry_get_auto_k_grid(atoms%symObj, in%nkpt, in%kpt, in%wkpt, &
          & kptrlen, ierror)
     if (ierror /= AB6_NO_ERROR) then
        if (iproc==0) write(*,*) " ERROR in symmetry library. Error code is ", ierror
        stop
     end if
     ! in%kpt and in%wkpt will be allocated by ab6_symmetry routine.
     call memocc(0,in%kpt,'in%kpt',subname)
     call memocc(0,in%wkpt,'in%wkpt',subname)
  else if (trim(type) == "MPgrid" .or. trim(type) == "mpgrid") then
     read(1,*,iostat=ierror) ngkpt
     call check()
     read(1,*,iostat=ierror) nshiftk
     call check()
     do i = 1, min(nshiftk, 8), 1
        read(1,*,iostat=ierror) shiftk(:, i)
        call check()
     end do

     call ab6_symmetry_get_mp_k_grid(atoms%symObj, in%nkpt, in%kpt, in%wkpt, &
          & ngkpt, nshiftk, shiftk, ierror)
     if (ierror /= AB6_NO_ERROR) then
        if (iproc==0) write(*,*) " ERROR in symmetry library. Error code is ", ierror
        stop
     end if
     ! in%kpt and in%wkpt will be allocated by ab6_symmetry routine.
     call memocc(0,in%kpt,'in%kpt',subname)
     call memocc(0,in%wkpt,'in%wkpt',subname)
  else if (trim(type) == "manual" .or. trim(type) == "Manual") then
     read(1,*,iostat=ierror) in%nkpt
     call check()
     allocate(in%kpt(3, in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%kpt,'in%kpt',subname)
     allocate(in%wkpt(in%nkpt+ndebug),stat=i_stat)
     call memocc(i_stat,in%wkpt,'in%wkpt',subname)
     norm=0.0_gp
     do i = 1, in%nkpt
        read(1,*,iostat=ierror) in%kpt(:, i), in%wkpt(i)
        norm=norm+in%wkpt(i)
        call check()
     end do
     
     ! We normalise the weights.
     in%wkpt(:) = in%wkpt / norm
  end if

  close(unit=1,iostat=ierror)

  ! Convert reduced coordinates into BZ coordinates.
  alat = (/ atoms%alat1, atoms%alat2, atoms%alat3 /)
  if (atoms%geocode == 'S') alat(2) = 1.d0
  do i = 1, in%nkpt, 1
     in%kpt(:, i) = in%kpt(:, i) / alat * two_pi
  end do

contains

  subroutine check()
    iline=iline+1
    if (ierror/=0) then
       !if (iproc == 0) 
            write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE kpt_input_variables
!!***


!!****f* BigDFT/perf_input_variables
!! FUNCTION
!!    Read the input variables which can be used for performances
!! SOURCE
!!
subroutine perf_input_variables(iproc,filename,inputs)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  type(input_variables), intent(inout) :: inputs
  !local variables
  character(len=*), parameter :: subname='perf_input_variables'
  character(len=100) :: line
  logical :: exists
  integer :: iline,ierror,ii

  ! Set default values.
  !Debug option (used for memocc mainly)
  inputs%debug = .false.
  !Cache size for FFT
  inputs%ncache_fft = 8*1024

  !Check if the file is present
  inquire(file=trim(filename),exist=exists)
  if (exists) then
     !Read the file
     open(unit=1,file=filename,status='old')
     !line number, to control the input values
     iline=0
     do 
        read(1,fmt='(a)',iostat=ierror) line
        if (ierror /= 0) then
           !End of file (normally ierror < 0)
           exit
        end if
        call check()
        if (trim(line) == "debug" .or. trim(line) == "Debug" .or. trim(line) == "DEBUG") then
           inputs%debug = .true.
        else if (index(line,"fftcache") /= 0 .or. index(line,"FFTCACHE") /= 0) then
            ii = index(line,"fftcache")  + index(line,"FFTCACHE") + 8 
           read(line(ii:),*) inputs%ncache_fft
        end if
     end do
     close(unit=1,iostat=ierror)
  end if

  ! Set performance variables
  memdebug = inputs%debug
  call set_cache_size(inputs%ncache_fft)

  ! Output
  if (iproc == 0) then
     write(*,*)
     if (exists) then
        write(*, "(1x,a)") "Performance options (file 'input.perf' used):"
     else
        write(*, "(1x,a)") "Performance options (file 'input.perf' not present):"
     end if
     if (inputs%debug) then
        write(*, "(1x,a,3x,a)") "|","'debug' option enabled"
     else
        write(*, "(1x,a,3x,a)") "|","'debug' option disabled"
     end if
     write(*,"(1x,a,3x,a,i0)")  "|","'fftcache' = ",inputs%ncache_fft
     write(*,*)
  end if

contains

  subroutine check()
    iline=iline+1
    if (ierror/=0) then
       !if (iproc == 0) 
            write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE perf_input_variables
!!***


!!****f* BigDFT/free_input_variables
!! FUNCTION
!!  Free all dynamically allocated memory from the input variable structure.
!! SOURCE
!!
subroutine free_input_variables(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(inout) :: in
  character(len=*), parameter :: subname='free_input_variables'
  integer :: i_stat, i_all
  if (associated(in%qmass)) then
     i_all=-product(shape(in%qmass))*kind(in%qmass)
     deallocate(in%qmass,stat=i_stat)
     call memocc(i_stat,i_all,'in%qmass',subname)
  end if
  if (associated(in%kpt)) then
     i_all=-product(shape(in%kpt))*kind(in%kpt)
     deallocate(in%kpt,stat=i_stat)
     call memocc(i_stat,i_all,'in%kpt',subname)
  end if
  if (associated(in%wkpt)) then
     i_all=-product(shape(in%wkpt))*kind(in%wkpt)
     deallocate(in%wkpt,stat=i_stat)
     call memocc(i_stat,i_all,'in%wkpt',subname)
  end if

!!$  if (associated(in%Gabs_coeffs) ) then
!!$     i_all=-product(shape(in%Gabs_coeffs))*kind(in%Gabs_coeffs)
!!$     deallocate(in%Gabs_coeffs,stat=i_stat)
!!$     call memocc(i_stat,i_all,'in%Gabs_coeffs',subname)
!!$  end if

END SUBROUTINE free_input_variables
!!***


!!****f* BigDFT/abscalc_input_variables_default
!! FUNCTION
!!    Assign default values for ABSCALC variables
!! SOURCE
!!
subroutine abscalc_input_variables_default(in)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(out) :: in

  in%c_absorbtion=.false.
  in%potshortcut=0
  in%iat_absorber=0

END SUBROUTINE abscalc_input_variables_default
!!***


!!****f* BigDFT/abscalc_input_variables
!! FUNCTION
!!    Read the input variables needed for the ABSCALC
!!    Every argument should be considered as mandatory
!! SOURCE
!!
subroutine abscalc_input_variables(iproc,filename,in)
  use module_base
  use module_types
  implicit none
  !Arguments
  type(input_variables), intent(inout) :: in
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  !Local variables
  integer, parameter :: iunit = 112
  integer :: ierror,iline, i

  character(len=*), parameter :: subname='abscalc_input_variables'
  integer :: i_stat

  ! Read the input variables.
  open(unit=iunit,file=filename,status='old')

  !line number, to control the input values
  iline=0

  !x-absorber treatment (in progress)

  read(iunit,*,iostat=ierror) in%iabscalc_type
  call check()


  read(iunit,*,iostat=ierror)  in%iat_absorber
  call check()
  read(iunit,*,iostat=ierror)  in%L_absorber
  call check()

  allocate(in%Gabs_coeffs(2*in%L_absorber +1+ndebug),stat=i_stat)
  call memocc(i_stat,in%Gabs_coeffs,'Gabs_coeffs',subname)

  read(iunit,*,iostat=ierror)  (in%Gabs_coeffs(i), i=1,2*in%L_absorber +1 )
  call check()

  read(iunit,*,iostat=ierror)  in%potshortcut
  call check()
  
  read(iunit,*,iostat=ierror)  in%nsteps
  call check()
  
  read(iunit,*,iostat=ierror) in%abscalc_alterpot, in%abscalc_eqdiff 

  if(ierror==0) then
     
  else
     in%abscalc_alterpot=.false.
     in%abscalc_eqdiff =.false.
  endif

  in%c_absorbtion=.true.

  close(unit=iunit)

contains

  subroutine check()
    iline=iline+1
    if (ierror/=0) then
       if (iproc == 0) write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE abscalc_input_variables
!!***


!!****f* BigDFT/frequencies_input_variables_default
!! FUNCTION
!!    Assign default values for frequencies variables
!! DESCRIPTION
!!    freq_alpha: frequencies step for finite difference = alpha*hx, alpha*hy, alpha*hz
!!    freq_order; order of the finite difference (2 or 3 i.e. 2 or 4 points)
!!    freq_method: 1 - systematic moves of atoms over each direction
!! SOURCE
!!
subroutine frequencies_input_variables_default(inputs)
  use module_base
  use module_types
  implicit none
  type(input_variables), intent(out) :: inputs

  inputs%freq_alpha=1.d0/real(64,kind(1.d0))
  inputs%freq_order=2
  inputs%freq_method=1

END SUBROUTINE frequencies_input_variables_default
!!***


!!****f* BigDFT/frequencies_input_variables
!! FUNCTION
!!    Read the input variables needed for the frequencies calculation.
!!    Every argument should be considered as mandatory.
!! SOURCE
!!
subroutine frequencies_input_variables(iproc,filename,in)
  use module_base
  use module_types
  implicit none
  !Arguments
  type(input_variables), intent(inout) :: in
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  !Local variables
  integer, parameter :: iunit=111
  character(len=100) :: line,string
  integer :: ierror,iline

  ! Read the input variables.
  open(unit=iunit,file=filename,status='old')
  !Line number, to control the input values
  iline=0
  !Read in%freq_alpha (possible 1/64)
  read(unit=iunit,fmt="(a)",iostat=ierror) line
  !Transform the line in case there are slashes (to ease the parsing)
  call read_fraction_string(line,in%freq_alpha,ierror)
  if (ierror /= 0) then
     print *,'wrong format of the string: '//string
     ierror=1
  end if
  call check()
  !Read the order of finite difference scheme
  read(unit=iunit,fmt=*,iostat=ierror)  in%freq_order
  if (in%freq_order /= -1 .and. in%freq_order /= 1 &
     & .and. in%freq_order /= 2 .and. in%freq_order /= 3 ) then
     if (iproc==0) write (*,'(1x,a)') 'Only -1, 1, 2 or 3 are possible for the order scheme'
     stop
  end if
  !Read the index of the method
  read(unit=iunit,fmt=*,iostat=ierror)  in%freq_method
  if (in%freq_method /= 1) then
     if (iproc==0) write (*,'(1x,a)') '1 for the method to calculate frequencies.'
     stop
  end if
  call check()

  close(unit=iunit)

  !Message
  if (iproc == 0) then
     write(*,*)
     write(*,'(1x,a,1pg14.6)') '=F= Step size factor',in%freq_alpha
     write(*,'(1x,a,i10)')     '=F= Order scheme    ',in%freq_order
     write(*,'(1x,a,i10)')     '=F= Used method     ',in%freq_method
  end if

contains

  subroutine check()
    implicit none
    iline=iline+1
    if (ierror/=0) then
       if (iproc == 0) write(*,'(1x,a,a,a,i3)') &
            'Error while reading the file "',trim(filename),'", line=',iline
       stop
    end if
  END SUBROUTINE check

END SUBROUTINE frequencies_input_variables
!!***

!!****f* BigDFT/read_atomic_file
!! FUNCTION
!!    Read atomic file
!! SOURCE
!!
subroutine read_atomic_file(file,iproc,atoms,rxyz)
  use module_base
  use module_types
  use module_interfaces, except_this_one => read_atomic_file
  use ab6_symmetry
  implicit none
  character(len=*), intent(in) :: file
  integer, intent(in) :: iproc
  type(atoms_data), intent(inout) :: atoms
  real(gp), dimension(:,:), pointer :: rxyz
  !local variables
  character(len=*), parameter :: subname='read_atomic_file'
  integer :: i_stat, l
  logical :: file_exists
  character(len = 128) :: filename

  file_exists = .false.

  ! Test posinp.xyz
  if (.not. file_exists) then
     inquire(FILE = file//'.xyz', EXIST = file_exists)
     if (file_exists) write(filename, "(A)") file//'.xyz'!"posinp.xyz"
     write(atoms%format, "(A)") "xyz"
  end if
  ! Test posinp.ascii
  if (.not. file_exists) then
     inquire(FILE = file//'.ascii', EXIST = file_exists)
     if (file_exists) write(filename, "(A)") file//'.ascii'!"posinp.ascii"
     write(atoms%format, "(A)") "ascii"
  end if
  ! Test the name directly
  if (.not. file_exists) then
     inquire(FILE = file, EXIST = file_exists)
     if (file_exists) then
         write(filename, "(A)") file
         l = len(file)
         if (file(l-3:l) == ".xyz") then
            write(atoms%format, "(A)") "xyz"
         else if (file(l-5:l) == ".ascii") then
            write(atoms%format, "(A)") "ascii"
         else
            write(*,*) "Atomic input file '" // trim(file) // "', format not recognised."
            write(*,*) " File should be *.ascii or *.xyz."
            stop
         end if
     end if
  end if

  if (.not. file_exists) then
     write(*,*) "Atomic input file not found."
     write(*,*) " Files looked for were '"//file//"'.ascii, '"//file//".xyz' and '"//file//"'."
     stop 
  end if

  open(unit=99,file=trim(filename),status='old')
  if (iproc.eq.0) write(*,*) 'Reading atomic input positions from file:',trim(filename) 

  if (atoms%format == "xyz") then
     read(99,*) atoms%nat,atoms%units

     allocate(rxyz(3,atoms%nat+ndebug),stat=i_stat)
     call memocc(i_stat,rxyz,'rxyz',subname)

     !read atomic positions
     call read_atomic_positions(iproc,99,atoms,rxyz)

  else if (atoms%format == "ascii") then
     !read atomic positions
     call read_ascii_positions(iproc,99,atoms,rxyz)
  end if

  close(99)

  !control atom positions
  call check_atoms_positions(iproc,atoms,rxyz)

  ! We delay the calculation of the symmetries.
  atoms%symObj = -1

END SUBROUTINE read_atomic_file
!!***


!!****f* BigDFT/deallocate_atoms
!! FUNCTION
!!    Deallocate the structure atoms_data.
!! SOURCE
!!
subroutine deallocate_atoms(atoms,subname) 
  use module_base
  use module_types
  use ab6_symmetry
  implicit none
  character(len=*), intent(in) :: subname
  type(atoms_data), intent(inout) :: atoms
  !local variables
  integer :: i_stat, i_all

  !deallocations
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
  if (atoms%symObj >= 0) then
     call ab6_symmetry_free(atoms%symObj)
  end if
END SUBROUTINE deallocate_atoms
!!***


!!****f* BigDFT/deallocate_atoms_scf
!! FUNCTION
!!    Deallocate the structure atoms_data after scf loop.
!! SOURCE
!!
subroutine deallocate_atoms_scf(atoms,subname) 
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: subname
  type(atoms_data), intent(inout) :: atoms
  !local variables
  integer :: i_stat, i_all
  !semicores useful only for the input guess
  i_all=-product(shape(atoms%iasctype))*kind(atoms%iasctype)
  deallocate(atoms%iasctype,stat=i_stat)
  call memocc(i_stat,i_all,'iasctype',subname)
  i_all=-product(shape(atoms%aocc))*kind(atoms%aocc)
  deallocate(atoms%aocc,stat=i_stat)
  call memocc(i_stat,i_all,'aocc',subname)
  i_all=-product(shape(atoms%nzatom))*kind(atoms%nzatom)
  deallocate(atoms%nzatom,stat=i_stat)
  call memocc(i_stat,i_all,'nzatom',subname)
  i_all=-product(shape(atoms%psppar))*kind(atoms%psppar)
  deallocate(atoms%psppar,stat=i_stat)
  call memocc(i_stat,i_all,'psppar',subname)
  i_all=-product(shape(atoms%nelpsp))*kind(atoms%nelpsp)
  deallocate(atoms%nelpsp,stat=i_stat)
  call memocc(i_stat,i_all,'nelpsp',subname)
  i_all=-product(shape(atoms%npspcode))*kind(atoms%npspcode)
  deallocate(atoms%npspcode,stat=i_stat)
  call memocc(i_stat,i_all,'npspcode',subname)
END SUBROUTINE deallocate_atoms_scf
!!***


!!****f* BigDFT/read_atomic_positions
!! FUNCTION
!!    Read atomic positions
!! SOURCE
!!
subroutine read_atomic_positions(iproc,ifile,atoms,rxyz)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc,ifile
  type(atoms_data), intent(inout) :: atoms
  real(gp), dimension(3,atoms%nat), intent(out) :: rxyz
  !local variables
  character(len=*), parameter :: subname='read_atomic_positions'
  character(len=2) :: symbol
  character(len=20) :: tatonam
  character(len=50) :: extra
  character(len=150) :: line
  logical :: lpsdbl
  integer :: iat,ityp,i,ierrsfx,i_stat
! To read the file posinp (avoid differences between compilers)
  real(kind=4) :: rx,ry,rz,alat1,alat2,alat3
! case for which the atomic positions are given whithin general precision
  real(gp) :: rxd0,ryd0,rzd0,alat1d0,alat2d0,alat3d0
  character(len=20), dimension(100) :: atomnames

  allocate(atoms%iatype(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%iatype,'atoms%iatype',subname)
  allocate(atoms%ifrztyp(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%ifrztyp,'atoms%ifrztyp',subname)
  allocate(atoms%natpol(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%natpol,'atoms%natpol',subname)
  allocate(atoms%amu(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%amu,'atoms%amu',subname)

  !controls if the positions are provided with machine precision
  if (atoms%units == 'angstroemd0' .or. atoms%units== 'atomicd0' .or. atoms%units== 'bohrd0') then
     lpsdbl=.true.
  else
     lpsdbl=.false.
  end if

  !this array is useful for frozen atoms
  !no atom is frozen by default
  atoms%ifrztyp(:)=0
  !also the spin polarisation and the charge are is fixed to zero by default
  !this corresponds to the value of 100
  !RULE natpol=charge*1000 + 100 + spinpol
  atoms%natpol(:)=100

  !read from positions of .xyz format, but accepts also the old .ascii format
  read(ifile,'(a150)')line

!!!  !old format, still here for backward compatibility
!!!  !admits only simple precision calculation
!!!  read(line,*,iostat=ierror) rx,ry,rz,tatonam

!!!  !in case of old format, put geocode to F and alat to 0.
!!!  if (ierror == 0) then
!!!     atoms%geocode='F'
!!!     alat1d0=0.0_gp
!!!     alat2d0=0.0_gp
!!!     alat3d0=0.0_gp
!!!  else
  if (lpsdbl) then
     read(line,*,iostat=ierrsfx) tatonam,alat1d0,alat2d0,alat3d0
  else
     read(line,*,iostat=ierrsfx) tatonam,alat1,alat2,alat3
  end if
  if (ierrsfx == 0) then
     if (trim(tatonam)=='periodic') then
        atoms%geocode='P'
     else if (trim(tatonam)=='surface') then 
        atoms%geocode='S'
        atoms%alat2=0.0_gp
     else !otherwise free bc
        atoms%geocode='F'
        atoms%alat1=0.0_gp
        atoms%alat2=0.0_gp
        atoms%alat3=0.0_gp
     end if
     if (.not. lpsdbl) then
        alat1d0=real(alat1,gp)
        alat2d0=real(alat2,gp)
        alat3d0=real(alat3,gp)
     end if
  else
     atoms%geocode='F'
     alat1d0=0.0_gp
     alat2d0=0.0_gp
     alat3d0=0.0_gp
  end if
!!!  end if

  !reduced coordinates are possible only with periodic units
  if (atoms%units == 'reduced' .and. atoms%geocode == 'F') then
     if (iproc==0) write(*,'(1x,a)')&
          'ERROR: Reduced coordinates are not allowed with isolated BC'
  end if

  !convert the values of the cell sizes in bohr
  if (atoms%units=='angstroem' .or. atoms%units=='angstroemd0') then
     ! if Angstroem convert to Bohr
     atoms%alat1=alat1d0/bohr2ang
     atoms%alat2=alat2d0/bohr2ang
     atoms%alat3=alat3d0/bohr2ang
  else if  (atoms%units=='atomic' .or. atoms%units=='bohr'  .or.&
       atoms%units== 'atomicd0' .or. atoms%units== 'bohrd0') then
     atoms%alat1=alat1d0
     atoms%alat2=alat2d0
     atoms%alat3=alat3d0
  else if (atoms%units == 'reduced') then
     !assume that for reduced coordinates cell size is in bohr
     atoms%alat1=real(alat1,gp)
     atoms%alat2=real(alat2,gp)
     atoms%alat3=real(alat3,gp)
  else
     write(*,*) 'length units in input file unrecognized'
     write(*,*) 'recognized units are angstroem or atomic = bohr'
     stop 
  endif

  atoms%ntypes=0
  do iat=1,atoms%nat

     !xyz input file, allow extra information
     read(ifile,'(a150)')line 
     if (lpsdbl) then
        read(line,*,iostat=ierrsfx)symbol,rxd0,ryd0,rzd0,extra
     else
        read(line,*,iostat=ierrsfx)symbol,rx,ry,rz,extra
     end if
     !print *,'extra',iat,extra
     call find_extra_info(line,extra)
     !print *,'then',iat,extra
     call parse_extra_info(iat,extra,atoms)

     tatonam=trim(symbol)
!!!     end if
     if (lpsdbl) then
        rxyz(1,iat)=rxd0
        rxyz(2,iat)=ryd0
        rxyz(3,iat)=rzd0
     else
        rxyz(1,iat)=real(rx,gp)
        rxyz(2,iat)=real(ry,gp)
        rxyz(3,iat)=real(rz,gp)
     end if
     if (atoms%units == 'reduced') then !add treatment for reduced coordinates
        rxyz(1,iat)=modulo(rxyz(1,iat),1.0_gp)
        if (atoms%geocode == 'P') rxyz(2,iat)=modulo(rxyz(2,iat),1.0_gp)
        rxyz(3,iat)=modulo(rxyz(3,iat),1.0_gp)
     else if (atoms%geocode == 'P') then
        rxyz(1,iat)=modulo(rxyz(1,iat),alat1d0)
        rxyz(2,iat)=modulo(rxyz(2,iat),alat2d0)
        rxyz(3,iat)=modulo(rxyz(3,iat),alat3d0)
     else if (atoms%geocode == 'S') then
        rxyz(1,iat)=modulo(rxyz(1,iat),alat1d0)
        rxyz(3,iat)=modulo(rxyz(3,iat),alat3d0)
     end if
 
     do ityp=1,atoms%ntypes
        if (tatonam == atomnames(ityp)) then
           atoms%iatype(iat)=ityp
           goto 200
        endif
     enddo
     atoms%ntypes=atoms%ntypes+1
     if (atoms%ntypes > 100) stop 'more than 100 atomnames not permitted'
     atomnames(ityp)=tatonam
     atoms%iatype(iat)=atoms%ntypes
200  continue

     if (atoms%units=='angstroem' .or. atoms%units=='angstroemd0') then
        ! if Angstroem convert to Bohr
        do i=1,3 
           rxyz(i,iat)=rxyz(i,iat)/bohr2ang
        enddo
     else if (atoms%units == 'reduced') then 
        rxyz(1,iat)=rxyz(1,iat)*atoms%alat1
        if (atoms%geocode == 'P') rxyz(2,iat)=rxyz(2,iat)*atoms%alat2
        rxyz(3,iat)=rxyz(3,iat)*atoms%alat3
     endif
  enddo

  !now that ntypes is determined allocate atoms%atomnames and copy the values
  allocate(atoms%atomnames(atoms%ntypes+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%atomnames,'atoms%atomnames',subname)
  atoms%atomnames(1:atoms%ntypes)=atomnames(1:atoms%ntypes)
END SUBROUTINE read_atomic_positions
!!***


!!****f* BigDFT/check_atoms_positions
!! FUNCTION
!!    Check the position of atoms
!! SOURCE
!!
subroutine check_atoms_positions(iproc,atoms,rxyz)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
  !local variables
  logical :: dowrite
  integer :: iat,nateq,jat,j

  nateq=0
  do iat=1,atoms%nat
     do jat=iat+1,atoms%nat
        if ((rxyz(1,iat)-rxyz(1,jat))**2+(rxyz(2,iat)-rxyz(2,jat))**2+&
             (rxyz(3,iat)-rxyz(3,jat))**2 ==0.0_gp) then
           nateq=nateq+1
           write(*,'(1x,a,2(i0,a,a6,a))')'ERROR: atoms ',iat,&
                ' (',trim(atoms%atomnames(atoms%iatype(iat))),') and ',&
                jat,' (',trim(atoms%atomnames(atoms%iatype(jat))),&
                ') have the same positions'
        end if
     end do
  end do
  if (nateq /= 0) then
     if (iproc == 0) then
        write(*,'(1x,a)')'Control your posinp file, cannot proceed'
        write(*,'(1x,a)',advance='no')&
             'Writing tentative alternative positions in the file posinp_alt...'
        open(unit=9,file='posinp_alt')
        write(9,'(1x,a)')' ??? atomicd0'
        write(9,*)
        do iat=1,atoms%nat
           dowrite=.true.
           do jat=iat+1,atoms%nat
              if ((rxyz(1,iat)-rxyz(1,jat))**2+(rxyz(2,iat)-rxyz(2,jat))**2+&
                   (rxyz(3,iat)-rxyz(3,jat))**2 ==0.0_gp) then
                 dowrite=.false.
              end if
           end do
           if (dowrite) & 
                write(9,'(a2,4x,3(1x,1pe21.14))')trim(atoms%atomnames(atoms%iatype(iat))),&
                (rxyz(j,iat),j=1,3)
        end do
        close(9)
        write(*,'(1x,a)')' done.'
        write(*,'(1x,a)')' Replace ??? in the file heading with the actual atoms number'               
     end if
     stop 'check_atoms_positions'
  end if
END SUBROUTINE check_atoms_positions
!!***


!!****f* BigDFT/find_extra_info
!! FUNCTION
!!    Find extra information
!!
!! SOURCE
!!
subroutine find_extra_info(line,extra)
  implicit none
  character(len=150), intent(in) :: line
  character(len=50), intent(out) :: extra
  !local variables
  logical :: space
  integer :: i,nspace
  i=1
  space=.true.
  nspace=-1
  !print *,'line',line
  find_space : do
     !toggle the space value for each time
     if (line(i:i) == ' ' .neqv. space) then
        nspace=nspace+1
        space=.not. space
     end if
     !print *,line(i:i),nspace
     if (nspace==8) then
        extra=line(i:min(150,i+49))
        exit find_space
     end if
     if (i==150) then
        !print *,'AAA',extra
        extra='nothing'
        exit find_space
     end if
     i=i+1
  end do find_space

END SUBROUTINE find_extra_info
!!***


!!****f* BigDFT/parse_extra_info
!! FUNCTION
!!    Parse extra information
!!
!! SOURCE
!!
subroutine parse_extra_info(iat,extra,atoms)
  use module_types
  implicit none
  !Arguments
  integer, intent(in) :: iat
  character(len=50), intent(in) :: extra
  type(atoms_data), intent(out) :: atoms
  !Local variables
  character(len=4) :: suffix
  logical :: go
  integer :: ierr,ierr1,ierr2,nspol,nchrg,nsgn
  !case with all the information
  !print *,iat,'ex'//trim(extra)//'ex'
  read(extra,*,iostat=ierr)nspol,nchrg,suffix
  if (extra == 'nothing') then !case with empty information
     nspol=0
     nchrg=0
     suffix='    '
  else if (ierr /= 0) then !case with partial information
     read(extra,*,iostat=ierr1)nspol,suffix
     if (ierr1 /=0) then
        call valid_frzchain(trim(extra),go)
        if (go) then
           suffix=trim(extra)
           nspol=0
           nchrg=0
        else
           read(extra,*,iostat=ierr2)nspol
           if (ierr2 /=0) then
              call error
           end if
           suffix='    '
           nchrg=0
        end if
     else
        nchrg=0
        call valid_frzchain(trim(suffix),go)
        if (.not. go) then
           read(suffix,*,iostat=ierr2)nchrg
           if (ierr2 /= 0) then
              call error
           else
              suffix='    '
           end if
        else

        end if
     end if
  end if

  !now assign the array, following the rule
  if(nchrg>=0) then
     nsgn=1
  else
     nsgn=-1
  end if
  atoms%natpol(iat)=1000*nchrg+nsgn*100+nspol

  !print *,'natpol atomic',iat,atoms%natpol(iat),suffix

  !convert the suffix into ifrztyp
  call frozen_ftoi(suffix,atoms%ifrztyp(iat))

!!!  if (trim(suffix) == 'f') then
!!!     !the atom is considered as blocked
!!!     atoms%ifrztyp(iat)=1
!!!  end if

contains

 subroutine error
   !if (iproc == 0) then
      print *,extra
      write(*,'(1x,a,i0,a)')&
           'ERROR in input file for atom number ',iat,&
           ': after 4th column you can put the input polarisation(s) or the frzchain: f,fxz,fy'
   !end if
   stop
 END SUBROUTINE error
  
END SUBROUTINE parse_extra_info
!!***


!!****f* BigDFT/read_ascii_positions
!! FUNCTION
!!    Read atomic positions of ascii files.
!! SOURCE
!!
subroutine read_ascii_positions(iproc,ifile,atoms,rxyz)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc,ifile
  type(atoms_data), intent(inout) :: atoms
  real(gp), dimension(:,:), pointer :: rxyz
  !local variables
  character(len=*), parameter :: subname='read_ascii_positions'
  character(len=2) :: symbol
  character(len=20) :: tatonam
  character(len=50) :: extra
  character(len=150) :: line
  logical :: lpsdbl, reduced
  integer :: iat,ityp,i,i_stat,j,nlines
! To read the file posinp (avoid differences between compilers)
  real(kind=4) :: rx,ry,rz,alat1,alat2,alat3,alat4,alat5,alat6
! case for which the atomic positions are given whithin general precision
  real(gp) :: rxd0,ryd0,rzd0,alat1d0,alat2d0,alat3d0,alat4d0,alat5d0,alat6d0
  character(len=20), dimension(100) :: atomnames
  ! Store the file.
  character(len = 150), dimension(5000) :: lines

  ! First pass to store the file in a string buffer.
  nlines = 1
  do
     read(ifile,'(a150)', iostat = i_stat) lines(nlines)
     if (i_stat /= 0) then
        exit
     end if
     nlines = nlines + 1
     if (nlines > 5000) then
        !if (iproc==0) 
        write(*,*) 'Atomic input file too long (> 5000 lines).'
        stop 
     end if
  end do
  nlines = nlines - 1

  if (nlines < 4) then
     !if (iproc==0) 
      write(*,*) 'Error in ASCII file format, file has less than 4 lines.'
     stop 
  end if

  ! Try to determine the number atoms and the keywords.
  write(atoms%units, "(A)") "bohr"
  reduced = .false.
  atoms%geocode = 'P'
  atoms%nat     = 0
  do i = 4, nlines, 1
     write(line, "(a150)") adjustl(lines(i))
     if (line(1:1) /= '#' .and. line(1:1) /= '!' .and. len(trim(line)) /= 0) then
        atoms%nat = atoms%nat + 1
     else if (line(1:8) == "#keyword" .or. line(1:8) == "!keyword") then
        if (index(line, 'bohr') > 0)        write(atoms%units, "(A)") "bohr"
        if (index(line, 'bohrd0') > 0)      write(atoms%units, "(A)") "bohrd0"
        if (index(line, 'atomic') > 0)      write(atoms%units, "(A)") "atomicd0"
        if (index(line, 'angstroem') > 0)   write(atoms%units, "(A)") "angstroem"
        if (index(line, 'angstroemd0') > 0) write(atoms%units, "(A)") "angstroemd0"
        if (index(line, 'reduced') > 0)     reduced = .true.
        if (index(line, 'periodic') > 0) atoms%geocode = 'P'
        if (index(line, 'surface') > 0)  atoms%geocode = 'S'
        if (index(line, 'freeBC') > 0)   atoms%geocode = 'F'
     end if
  end do

  allocate(atoms%iatype(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%iatype,'atoms%iatype',subname)
  allocate(atoms%ifrztyp(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%ifrztyp,'atoms%ifrztyp',subname)
  allocate(atoms%natpol(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%natpol,'atoms%natpol',subname)
  allocate(atoms%amu(atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%amu,'atoms%amu',subname)
  allocate(rxyz(3,atoms%nat+ndebug),stat=i_stat)
  call memocc(i_stat,rxyz,'rxyz',subname)

  !controls if the positions are provided with machine precision
  if (index(atoms%units, 'd0') > 0) then
     lpsdbl=.true.
  else
     lpsdbl=.false.
  end if

  !this array is useful for frozen atoms
  !no atom is frozen by default
  atoms%ifrztyp(:)=0
  !also the spin polarisation and the charge are is fixed to zero by default
  !this corresponds to the value of 100
  !RULE natpol=charge*1000 + 100 + spinpol
  atoms%natpol(:)=100

  ! Read the box definition
  atoms%alat1 = 0.0_gp
  atoms%alat2 = 0.0_gp
  atoms%alat3 = 0.0_gp
  if (lpsdbl) then
     read(lines(2),*) alat1d0,alat2d0,alat3d0
     read(lines(3),*) alat4d0,alat5d0,alat6d0
     if (alat2d0 /= 0.d0 .or. alat4d0 /= 0.d0 .or. alat5d0 /= 0.d0) then
        !if (iproc==0) 
        write(*,*) 'Only orthorombic boxes are possible.'
        stop 
     end if
     atoms%alat1 = real(alat1d0,gp)
     atoms%alat2 = real(alat3d0,gp)
     atoms%alat3 = real(alat6d0,gp)
  else
     read(lines(2),*) alat1,alat2,alat3
     read(lines(3),*) alat4,alat5,alat6
     if (alat2 /= 0. .or. alat4 /= 0. .or. alat5 /= 0.) then
        !if (iproc==0) 
           write(*,*) 'Only orthorombic boxes are possible.'
        !if (iproc==0) 
           write(*,*) ' but alat2, alat4 and alat5 = ', alat2, alat4, alat5
        stop 
     end if
     atoms%alat1 = real(alat1,gp)
     atoms%alat2 = real(alat3,gp)
     atoms%alat3 = real(alat6,gp)
  end if
  if (atoms%geocode == 'S') then
     atoms%alat2 = 0.0_gp
  else if (atoms%geocode == 'F') then
     atoms%alat1 = 0.0_gp
     atoms%alat2 = 0.0_gp
     atoms%alat3 = 0.0_gp
  end if
  
  !reduced coordinates are possible only with periodic units
  if (reduced .and. atoms%geocode /= 'P') then
     if (iproc==0) write(*,'(1x,a)')&
          'ERROR: Reduced coordinates are only allowed with fully periodic BC'
  end if

  !convert the values of the cell sizes in bohr
  if (atoms%units=='angstroem' .or. atoms%units=='angstroemd0') then
     ! if Angstroem convert to Bohr
     atoms%alat1 = atoms%alat1 / bohr2ang
     atoms%alat2 = atoms%alat2 / bohr2ang
     atoms%alat3 = atoms%alat3 / bohr2ang
  endif

  atoms%ntypes=0
  iat = 1
  do i = 4, nlines, 1
     write(line, "(a150)") adjustl(lines(i))
     if (line(1:1) /= '#' .and. line(1:1) /= '!' .and. len(trim(line)) /= 0) then
        write(extra, "(A)") "nothing"
        if (lpsdbl) then
           read(line,*, iostat = i_stat) rxd0,ryd0,rzd0,symbol,extra
           if (i_stat /= 0) read(line,*) rxd0,ryd0,rzd0,symbol
        else
           read(line,*, iostat = i_stat) rx,ry,rz,symbol,extra
           if (i_stat /= 0) read(line,*) rx,ry,rz,symbol
        end if
        call find_extra_info(line,extra)
        call parse_extra_info(iat,extra,atoms)

        tatonam=trim(symbol)

        if (lpsdbl) then
           rxyz(1,iat)=rxd0
           rxyz(2,iat)=ryd0
           rxyz(3,iat)=rzd0
        else
           rxyz(1,iat)=real(rx,gp)
           rxyz(2,iat)=real(ry,gp)
           rxyz(3,iat)=real(rz,gp)
        end if

        if (reduced) then !add treatment for reduced coordinates
           rxyz(1,iat)=modulo(rxyz(1,iat),1.0_gp)
           rxyz(2,iat)=modulo(rxyz(2,iat),1.0_gp)
           rxyz(3,iat)=modulo(rxyz(3,iat),1.0_gp)
        else if (atoms%geocode == 'P') then
           rxyz(1,iat)=modulo(rxyz(1,iat),atoms%alat1)
           rxyz(2,iat)=modulo(rxyz(2,iat),atoms%alat2)
           rxyz(3,iat)=modulo(rxyz(3,iat),atoms%alat3)
        else if (atoms%geocode == 'S') then
           rxyz(1,iat)=modulo(rxyz(1,iat),atoms%alat1)
           rxyz(3,iat)=modulo(rxyz(3,iat),atoms%alat3)
        end if

        do ityp=1,atoms%ntypes
           if (tatonam == atomnames(ityp)) then
              atoms%iatype(iat)=ityp
              goto 200
           endif
        enddo
        atoms%ntypes=atoms%ntypes+1
        if (atoms%ntypes > 100) stop 'more than 100 atomnames not permitted'
        atomnames(ityp)=tatonam
        atoms%iatype(iat)=atoms%ntypes
200     continue

        if (reduced) then
           rxyz(1,iat)=rxyz(1,iat)*atoms%alat1
           rxyz(2,iat)=rxyz(2,iat)*atoms%alat2
           rxyz(3,iat)=rxyz(3,iat)*atoms%alat3
        else if (atoms%units=='angstroem' .or. atoms%units=='angstroemd0') then
           ! if Angstroem convert to Bohr
           do j=1,3 
              rxyz(j,iat)=rxyz(j,iat) / bohr2ang
           enddo
        endif
        iat = iat + 1
     end if
  enddo

  !now that ntypes is determined allocate atoms%atomnames and copy the values
  allocate(atoms%atomnames(atoms%ntypes+ndebug),stat=i_stat)
  call memocc(i_stat,atoms%atomnames,'atoms%atomnames',subname)
  atoms%atomnames(1:atoms%ntypes)=atomnames(1:atoms%ntypes)
END SUBROUTINE read_ascii_positions
!!***


!!****f* BigDFT/charge_and_spol
!! FUNCTION
!!   Calculate the charge and the spin polarisation to be placed on a given atom
!!   RULE: natpol = c*1000 + sgn(c)*100 + s: charged and polarised atom (charge c, polarisation s)
!! SOURCE
!!
subroutine charge_and_spol(natpol,nchrg,nspol)
  implicit none
  integer, intent(in) :: natpol
  integer, intent(out) :: nchrg,nspol
  !local variables
  integer :: nsgn

  nchrg=natpol/1000
  if (nchrg>=0) then
     nsgn=1
  else
     nsgn=-1
  end if

  nspol=natpol-1000*nchrg-nsgn*100

END SUBROUTINE charge_and_spol
!!***

!!****f* BigDFT/write_atomic_file
!! FUNCTION
!!    Write an atomic file
!! SOURCE
!!
subroutine write_atomic_file(filename,energy,rxyz,atoms,comment)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename,comment
  type(atoms_data), intent(in) :: atoms
  real(gp), intent(in) :: energy
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz

  if (atoms%format == "xyz") then
     call wtxyz(filename,energy,rxyz,atoms,comment)
  else if (atoms%format == "ascii") then
     call wtascii(filename,energy,rxyz,atoms,comment)
  else
     write(*,*) "Error, unknown file format."
     stop
  end if
END SUBROUTINE write_atomic_file
!!***


!!****f* BigDFT/wtxyz
!! FUNCTION
!!   Write xyz atomic file.
!! SOURCE
!!
subroutine wtxyz(filename,energy,rxyz,atoms,comment)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename,comment
  type(atoms_data), intent(in) :: atoms
  real(gp), intent(in) :: energy
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
  !local variables
  character(len=2) :: symbol
  character(len=10) :: name
  character(len=11) :: units
  character(len=50) :: extra
  integer :: iat,j
  real(gp) :: xmax,ymax,zmax,factor

  open(unit=9,file=trim(filename)//'.xyz')
  xmax=0.0_gp
  ymax=0.0_gp
  zmax=0.0_gp

  do iat=1,atoms%nat
     xmax=max(rxyz(1,iat),xmax)
     ymax=max(rxyz(2,iat),ymax)
     zmax=max(rxyz(3,iat),zmax)
  enddo
  if (trim(atoms%units) == 'angstroem' .or. trim(atoms%units) == 'angstroemd0') then
     factor=bohr2ang
     units='angstroemd0'
  else
     factor=1.0_gp
     units='atomicd0'
  end if

  write(9,'(i6,2x,a,2x,1pe24.17,2x,a)') atoms%nat,trim(units),energy,comment

  if (atoms%geocode == 'P') then
     write(9,'(a,3(1x,1pe24.17))')'periodic',&
          atoms%alat1*factor,atoms%alat2*factor,atoms%alat3*factor
  else if (atoms%geocode == 'S') then
     write(9,'(a,3(1x,1pe24.17))')'surface',&
          atoms%alat1*factor,atoms%alat2*factor,atoms%alat3*factor
  else
     write(9,*)'free'
  end if
  do iat=1,atoms%nat
     name=trim(atoms%atomnames(atoms%iatype(iat)))
     if (name(3:3)=='_') then
        symbol=name(1:2)
     else if (name(2:2)=='_') then
        symbol=name(1:1)
     else
        symbol=name(1:2)
     end if

     call write_extra_info(extra,atoms%natpol(iat),atoms%ifrztyp(iat))

     write(9,'(a2,4x,3(1x,1pe24.17),2x,a50)')symbol,(rxyz(j,iat)*factor,j=1,3),extra

  enddo
  close(unit=9)

END SUBROUTINE wtxyz
!!***


!!****f* BigDFT/wtascii
!! FUNCTION
!!   Write ascii file (atomic position). 
!! SOURCE
!!
subroutine wtascii(filename,energy,rxyz,atoms,comment)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename,comment
  type(atoms_data), intent(in) :: atoms
  real(gp), intent(in) :: energy
  real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
  !local variables
  character(len=2) :: symbol
  character(len=50) :: extra
  character(len=10) :: name
  integer :: iat,j
  real(gp) :: xmax,ymax,zmax,factor

  open(unit=9,file=trim(filename)//'.ascii')
  xmax=0.0_gp
  ymax=0.0_gp
  zmax=0.0_gp

  do iat=1,atoms%nat
     xmax=max(rxyz(1,iat),xmax)
     ymax=max(rxyz(2,iat),ymax)
     zmax=max(rxyz(3,iat),zmax)
  enddo
  if (trim(atoms%units) == 'angstroem' .or. trim(atoms%units) == 'angstroemd0') then
     factor=bohr2ang
  else
     factor=1.0_gp
  end if

  write(9, "(A,A)") "# BigDFT file - ", trim(comment)
  write(9, "(3e24.17)") atoms%alat1*factor, 0.d0, atoms%alat2*factor
  write(9, "(3e24.17)") 0.d0,               0.d0, atoms%alat3*factor

  write(9, "(A,A)") "#keyword: ", trim(atoms%units)
  if (atoms%geocode == 'P') write(9, "(A)") "#keyword: periodic"
  if (atoms%geocode == 'S') write(9, "(A)") "#keyword: surface"
  if (atoms%geocode == 'F') write(9, "(A)") "#keyword: freeBC"
  if (energy /= 0.d0) then
     write(9, "(A,e24.17)") "# Total energy (Ht): ", energy
  end if

  do iat=1,atoms%nat
     name=trim(atoms%atomnames(atoms%iatype(iat)))
     if (name(3:3)=='_') then
        symbol=name(1:2)
     else if (name(2:2)=='_') then
        symbol=name(1:1)
     else
        symbol=name(1:2)
     end if

     call write_extra_info(extra,atoms%natpol(iat),atoms%ifrztyp(iat))     

     write(9,'(3(1x,1pe24.17),2x,a2,2x,a50)') (rxyz(j,iat)*factor,j=1,3),symbol,extra
  end do
  close(unit=9)

END SUBROUTINE wtascii
!!***


!!****f* BigDFT/write_extra_info
!! FUNCTION
!!   Write the extra info necessary for the output file
!! SOURCE
!!
subroutine write_extra_info(extra,natpol,ifrztyp)
  use module_base
  implicit none 
  integer, intent(in) :: natpol,ifrztyp
  character(len=50), intent(out) :: extra
  !local variables
  character(len=4) :: frzchain
  integer :: ispol,ichg

  call charge_and_spol(natpol,ichg,ispol)

  call frozen_itof(ifrztyp,frzchain)
  
  !takes into account the blocked atoms and the input polarisation
  if (ispol == 0 .and. ichg == 0 ) then
     write(extra,'(2x,a4)')frzchain
  else if (ispol /= 0 .and. ichg == 0) then
     write(extra,'(i7,2x,a4)')ispol,frzchain
  else if (ichg /= 0) then
     write(extra,'(2(i7),2x,a4)')ispol,ichg,frzchain
  else
     write(extra,'(2x,a4)') ''
  end if
  
END SUBROUTINE write_extra_info
!!***


!!****f* BigDFT/frozen_itof
!! FUNCTION
!!    
!! SOURCE
!!
subroutine frozen_itof(ifrztyp,frzchain)
  implicit none
  integer, intent(in) :: ifrztyp
  character(len=4), intent(out) :: frzchain

  if (ifrztyp == 0) then
     frzchain='    '
  else if (ifrztyp == 1) then
     frzchain='   f'
  else if (ifrztyp == 2) then
     frzchain='  fy'
  else if (ifrztyp == 3) then
     frzchain=' fxz'
  end if
        
END SUBROUTINE frozen_itof
!!***


!!****f* BigDFT/valid_frzchain
!! FUNCTION
!!    
!! SOURCE
!!
subroutine valid_frzchain(frzchain,go)
  implicit none
  character(len=*), intent(in) :: frzchain
  logical, intent(out) :: go

  go= trim(frzchain) == 'f' .or. &
       trim(frzchain) == 'fy' .or. &
       trim(frzchain) == 'fxz'
  
END SUBROUTINE valid_frzchain
!!***


!!****f* BigDFT/frozen_ftoi
!! FUNCTION
!!    
!! SOURCE
!!
subroutine frozen_ftoi(frzchain,ifrztyp)
  implicit none
  character(len=4), intent(in) :: frzchain
  integer, intent(out) :: ifrztyp

  if (trim(frzchain)=='') then
     ifrztyp = 0
  else if (trim(frzchain)=='f') then
     ifrztyp = 1
  else if (trim(frzchain)=='fy') then
     ifrztyp = 2
  else if (trim(frzchain)=='fxz') then
     ifrztyp = 3
  end if
        
END SUBROUTINE frozen_ftoi
!!***


!!****f* BigDFT/frozen_alpha
!! FUNCTION
!!   Calculate the coefficient for moving atoms following the ifrztyp
!! SOURCE
!!
subroutine frozen_alpha(ifrztyp,ixyz,alpha,alphai)
  use module_base
  implicit none
  integer, intent(in) :: ifrztyp,ixyz
  real(gp), intent(in) :: alpha
  real(gp), intent(out) :: alphai
  !local variables
  logical :: move_this_coordinate

  if (move_this_coordinate(ifrztyp,ixyz)) then
     alphai=alpha
  else
     alphai=0.0_gp
  end if
 
END SUBROUTINE frozen_alpha
!!***

!!****f* BigDFT/print_general_parameters
!! FUNCTION
!!    Print all general parameters
!! SOURCE
!!
subroutine print_general_parameters(in,atoms)
  use module_types
  use defs_basis
  use ab6_symmetry
  implicit none
  type(input_variables), intent(in) :: in
  type(atoms_data), intent(in) :: atoms

  integer :: nSym, ierr, ityp, iat, i, lg
  integer :: sym(3, 3, AB6_MAX_SYMMETRIES)
  integer :: symAfm(AB6_MAX_SYMMETRIES)
  real(gp) :: transNon(3, AB6_MAX_SYMMETRIES)
  real(gp) :: genAfm(3)
  character(len=15) :: spaceGroup
  integer :: spaceGroupId, pointGroupMagn
  integer, parameter :: maxLen = 50, width = 24
  character(len = width) :: at(maxLen), fixed(maxLen), add(maxLen)

  ! Output for atoms and k-points
  write(*,'(1x,a)') '---------------------------------------------------------------- Input atomic system'
  write(*, "(A)")   "   Atomic system                  Fixed positions           Additional data"
  do i = 1, maxLen
     write(at(i), "(a)") " "
     write(fixed(i), "(a)") " "
     write(add(i), "(a)") " "
  end do
  write(fixed(1), '(a)') "No fixed atom"
  write(add(1), '(a)') "No symmetry for open BC"
  
  ! The atoms column
  write(at(1), '(a,a)')  "Bound. C.= ", atoms%geocode
  write(at(2), '(a,i5)') "N. types = ", atoms%ntypes
  write(at(3), '(a,i5)') "N. atoms = ", atoms%nat
  lg = 12
  i = 4
  write(at(i),'(a)' )    "Types    = "
  do ityp=1,atoms%ntypes - 1
     if (lg + 4 + len(trim(atoms%atomnames(ityp))) >= width) then
        i = i + 1
        lg = 12
        write(at(i),'(a)') "           "
     end if
     write(at(i)(lg:),'(3a)') "'", trim(atoms%atomnames(ityp)), "', "
     lg = lg + 4 + len(trim(atoms%atomnames(ityp)))
  enddo
  if (lg + 2 + len(trim(atoms%atomnames(ityp))) >= width) then
     i = i + 1
     lg = 12
     write(at(i),'(a)') "           "
  end if
  write(at(i)(lg:),'(3a)') "'", trim(atoms%atomnames(ityp)), "'"

  ! The fixed atom column
  i = 1
  do iat=1,atoms%nat
     if (atoms%ifrztyp(iat)/=0) then
        if (i > maxLen) exit
        write(fixed(i),'(a,i4,a,a,a,i3)') &
             "at.", iat,' (', &
             & trim(atoms%atomnames(atoms%iatype(iat))),&
             ') ',atoms%ifrztyp(iat)
        i = i + 1
     end if
  enddo
  if (i > maxLen) write(fixed(maxLen), '(a)') " (...)"

  ! The additional data column
  if (atoms%geocode /= 'F' .and. .not. in%disableSym) then
     call ab6_symmetry_get_matrices(atoms%symObj, nSym, sym, transNon, symAfm, ierr)
     call ab6_symmetry_get_group(atoms%symObj, spaceGroup, &
          & spaceGroupId, pointGroupMagn, genAfm, ierr)
     if (ierr == AB6_ERROR_SYM_NOT_PRIMITIVE) write(spaceGroup, "(A)") "not prim."
     write(add(1), '(a,i0)')       "N. sym.   = ", nSym
     write(add(2), '(a,a,a)')      "Sp. group = ", trim(spaceGroup)
  else if (atoms%geocode /= 'F' .and. in%disableSym) then
     write(add(1), '(a)')          "N. sym.   = disabled"
     write(add(2), '(a)')          "Sp. group = disabled"
  else
     write(add(1), '(a)')          "N. sym.   = free BC"
     write(add(2), '(a)')          "Sp. group = free BC"
  end if
  i = 3
  if (in%nvirt > 0) then
     write(add(i), '(a,i5,a)')     "Virt. orb.= ", in%nvirt, " orb."
     write(add(i + 1), '(a,i5,a)') "Plot dens.= ", abs(in%nplot), " orb."
  else
     write(add(i), '(a)')          "Virt. orb.= none"
     write(add(i + 1), '(a)')      "Plot dens.= none"
  end if
  i = i + 2
  if (in%nspin==4) then
     write(add(i),'(a)')           "Spin pol. = non-coll."
  else if (in%nspin==2) then
     write(add(i),'(a)')           "Spin pol. = collinear"
  else if (in%nspin==1) then
     write(add(i),'(a)')           "Spin pol. = no"
  end if

  ! Printing
  do i = 1, maxLen
     if (len(trim(at(i))) > 0 .or. len(trim(fixed(i))) > 0 .or. len(trim(add(i))) > 0) then
        write(*,"(1x,a,1x,a,1x,a,1x,a,1x,a)") at(i), "|", fixed(i), "|", add(i)
     end if
  end do

  if (atoms%geocode /= 'F') then
     write(*,'(1x,a)') '--------------------------------------------------------------------------- k-points'
     if (in%disableSym .and. in%nkpt > 1) then
        write(*, "(1x,A)") "WARNING: symmetries have been disabled, k points are not irreductible."
     end if
     write(*, "(1x,a)")    "       red. coordinates         weight      id         BZ coordinates"
     do i = 1, in%nkpt, 1
        write(*, "(1x,3f9.5,2x,f9.5,5x,I3,2x,3f9.5)") &
             & in%kpt(:, i) * (/ atoms%alat1, atoms%alat2, atoms%alat3 /) / two_pi, &
             & in%wkpt(i), i, in%kpt(:, i)
     end do
  end if

  if (in%ncount_cluster_x > 0) then
     write(*,'(1x,a)') '------------------------------------------------------------- Geopt Input Parameters'
     write(*, "(A)")   "       Generic param.              Geo. optim.                MD param."

     write(*, "(1x,a,i7,1x,a,1x,a,1pe7.1,1x,a,1x,a,i7)") &
          & "      Max. steps=", in%ncount_cluster_x, "|", &
          & "Fluct. in forces=", in%frac_fluct,       "|", &
          & "          ionmov=", in%ionmov
     write(*, "(1x,a,a7,1x,a,1x,a,1pe7.1,1x,a,1x,a,0pf7.0)") &
          & "       algorithm=", in%geopt_approach, "|", &
          & "  Max. in forces=", in%forcemax,       "|", &
          & "           dtion=", in%dtion
     if (trim(in%geopt_approach) /= "DIIS") then
        write(*, "(1x,a,1pe7.1,1x,a,1x,a,1pe7.1,1x,a)", advance="no") &
             & "random at.displ.=", in%randdis, "|", &
             & "  steep. descent=", in%betax,   "|"
     else
        write(*, "(1x,a,1pe7.1,1x,a,1x,a,1pe7.1,2x,a,1I2,1x,a)", advance="no") &
             & "random at.displ.=", in%randdis,           "|", &
             & "step=", in%betax, "history=", in%history, "|"
     end if
     if (in%ionmov > 7) then
        write(*, "(1x,a,1f5.0,1x,a,1f5.0)") &
             & "start T=", in%mditemp, "stop T=", in%mdftemp
     else
        write(*,*)
     end if
     
     if (in%ionmov == 8) then
        write(*,*) "TODO: pretty printing!", in%noseinert
     else if (in%ionmov == 9) then
        write(*,*) "TODO: pretty printing!", in%friction
        write(*,*) "TODO: pretty printing!", in%mdwall
     else if (in%ionmov == 13) then
        write(*,*) "TODO: pretty printing!", in%nnos
        write(*,*) "TODO: pretty printing!", in%qmass
        write(*,*) "TODO: pretty printing!", in%bmass, in%vmass
     end if
  end if
END SUBROUTINE print_general_parameters
!!***

!!****f* BigDFT/print_input_parameters
!! FUNCTION
!!    Print all input parameters
!! SOURCE
!!
subroutine print_dft_parameters(in,atoms)
  use module_types
  use defs_basis
  use ab6_symmetry
  implicit none
  type(input_variables), intent(in) :: in
  type(atoms_data), intent(in) :: atoms

  write(*,'(1x,a)')&
       '------------------------------------------------------------------- Input Parameters'
  write(*,'(1x,a)')&
       '    System Choice       Resolution Radii        SCF Iteration      Finite Size Corr.'
  write(*,'(1x,a,f7.3,1x,a,f5.2,1x,a,1pe8.1,1x,a,l4)')&
       'Max. hgrid  =',in%hx,   '|  Coarse Wfs.=',in%crmult,'| Wavefns Conv.=',in%gnrm_cv,&
       '| Calculate=',in%calc_tail
  write(*,'(1x,a,i7,1x,a,f5.2,1x,a,i5,a,i2,1x,a,f4.1)')&
       '       XC id=',in%ixc,     '|    Fine Wfs.=',in%frmult,'| Max. N. Iter.=',in%itermax,&
       'x',in%nrepmax,'| Extension=',in%rbuf
  write(*,'(1x,a,i7,1x,a,1x,a,i8,1x,a,i4)')&
       'total charge=',in%ncharge, '|                   ','| CG Prec.Steps=',in%ncong,&
       '|  CG Steps=',in%ncongt
  write(*,'(1x,a,1pe7.1,1x,a,1x,a,i8)')&
       ' elec. field=',in%elecfield,'|                   ','| DIIS Hist. N.=',in%idsx
  if (in%nspin>=2) then
     write(*,'(1x,a,i7,1x,a)')&
          'Polarisation=',2*in%mpol, '|'
  end if
  if (atoms%geocode /= 'F') then
     write(*,'(1x,a,1x,a,3(1x,1pe12.5))')&
          '  Geom. Code=    '//atoms%geocode//'   |',&
          '  Box Sizes (Bohr) =',atoms%alat1,atoms%alat2,atoms%alat3

  end if
END SUBROUTINE print_dft_parameters
!!***

!!****f* BigDFT/atomic_axpy
!! FUNCTION
!!   Routine for moving atomic positions, takes into account the 
!!   frozen atoms and the size of the cell
!!   synopsis: rxyz=txyz+alpha*sxyz
!!   all the shift are inserted into the box if there are periodic directions
!!   if the atom are frozen they are not moved
!! SOURCE
!!
subroutine atomic_axpy(atoms,txyz,alpha,sxyz,rxyz)
  use module_base
  use module_types
  implicit none
  real(gp), intent(in) :: alpha
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%nat), intent(in) :: txyz,sxyz
  real(gp), dimension(3,atoms%nat), intent(inout) :: rxyz
  !local variables
  integer :: iat
  real(gp) :: alphax,alphay,alphaz

  do iat=1,atoms%nat
     !adjust the moving of the atoms following the frozen direction
     call frozen_alpha(atoms%ifrztyp(iat),1,alpha,alphax)
     call frozen_alpha(atoms%ifrztyp(iat),2,alpha,alphay)
     call frozen_alpha(atoms%ifrztyp(iat),3,alpha,alphaz)

     if (atoms%geocode == 'P') then
        rxyz(1,iat)=modulo(txyz(1,iat)+alphax*sxyz(1,iat),atoms%alat1)
        rxyz(2,iat)=modulo(txyz(2,iat)+alphay*sxyz(2,iat),atoms%alat2)
        rxyz(3,iat)=modulo(txyz(3,iat)+alphaz*sxyz(3,iat),atoms%alat3)
     else if (atoms%geocode == 'S') then
        rxyz(1,iat)=modulo(txyz(1,iat)+alphax*sxyz(1,iat),atoms%alat1)
        rxyz(2,iat)=txyz(2,iat)+alphay*sxyz(2,iat)
        rxyz(3,iat)=modulo(txyz(3,iat)+alphaz*sxyz(3,iat),atoms%alat3)
     else
        rxyz(1,iat)=txyz(1,iat)+alphax*sxyz(1,iat)
        rxyz(2,iat)=txyz(2,iat)+alphay*sxyz(2,iat)
        rxyz(3,iat)=txyz(3,iat)+alphaz*sxyz(3,iat)
     end if
  end do

END SUBROUTINE atomic_axpy
!!***


!!****f* BigDFT/atomic_axpy_forces
!! FUNCTION
!!   Routine for moving atomic positions, takes into account the 
!!   frozen atoms and the size of the cell
!!   synopsis: fxyz=txyz+alpha*sxyz
!!   update the forces taking into account the frozen atoms
!!   do not apply the modulo operation on forces 
!! SOURCE
!!
subroutine atomic_axpy_forces(atoms,txyz,alpha,sxyz,fxyz)
  use module_base
  use module_types
  implicit none
  real(gp), intent(in) :: alpha
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%nat), intent(in) :: txyz,sxyz
  real(gp), dimension(3,atoms%nat), intent(inout) :: fxyz
  !local variables
  integer :: iat
  real(gp) :: alphax,alphay,alphaz
  
  do iat=1,atoms%nat
     !adjust the moving of the forces following the frozen direction
     call frozen_alpha(atoms%ifrztyp(iat),1,alpha,alphax)
     call frozen_alpha(atoms%ifrztyp(iat),2,alpha,alphay)
     call frozen_alpha(atoms%ifrztyp(iat),3,alpha,alphaz)

     fxyz(1,iat)=txyz(1,iat)+alphax*sxyz(1,iat)
     fxyz(2,iat)=txyz(2,iat)+alphay*sxyz(2,iat)
     fxyz(3,iat)=txyz(3,iat)+alphaz*sxyz(3,iat)
  end do
  
END SUBROUTINE atomic_axpy_forces
!!***


!!****f* BigDFT/atomic_dot
!! FUNCTION
!!   Calculate the scalar product between atomic positions by considering
!!   only non-blocked atoms
!! SOURCE
!!
subroutine atomic_dot(atoms,x,y,scpr)
  use module_base
  use module_types
  implicit none
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%nat), intent(in) :: x,y
  real(gp), intent(out) :: scpr
  !local variables
  integer :: iat
  real(gp) :: scpr1,scpr2,scpr3
  real(gp) :: alphax,alphay,alphaz

  scpr=0.0_gp

  do iat=1,atoms%nat
     call frozen_alpha(atoms%ifrztyp(iat),1,1.0_gp,alphax)
     call frozen_alpha(atoms%ifrztyp(iat),2,1.0_gp,alphay)
     call frozen_alpha(atoms%ifrztyp(iat),3,1.0_gp,alphaz)
     scpr1=alphax*x(1,iat)*y(1,iat)
     scpr2=alphay*x(2,iat)*y(2,iat)
     scpr3=alphaz*x(3,iat)*y(3,iat)
     scpr=scpr+scpr1+scpr2+scpr3
  end do
  
END SUBROUTINE atomic_dot
!!***


!!****f* BigDFT/atomic_gemv
!! FUNCTION
!!   z=alpha*A*x + beta* y
!! SOURCE
!!
subroutine atomic_gemv(atoms,m,alpha,A,x,beta,y,z)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: m
  real(gp), intent(in) :: alpha,beta
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%nat), intent(in) :: x
  real(gp), dimension(m), intent(in) :: y
  real(gp), dimension(m,3,atoms%nat), intent(in) :: A
  real(gp), dimension(m), intent(out) :: z
  !local variables
  integer :: iat,i,j
  real(gp) :: mv,alphai
  
  do i=1,m
     mv=0.0_gp
     do iat=1,atoms%nat
        do j=1,3
           call frozen_alpha(atoms%ifrztyp(iat),j,A(i,j,iat),alphai)
           mv=mv+alphai*x(j,iat)
        end do
     end do
     z(i)=alpha*mv+beta*y(i)
  end do

END SUBROUTINE atomic_gemv
!!***


!!****f* BigDFT/move_this_coordinate
!! FUNCTION
!!  The function which controls all the moving positions
!! SOURCE
!!
function move_this_coordinate(ifrztyp,ixyz)
  use module_base
  implicit none
  integer, intent(in) :: ixyz,ifrztyp
  logical :: move_this_coordinate
  
  move_this_coordinate= &
       ifrztyp == 0 .or. &
       (ifrztyp == 2 .and. ixyz /=2) .or. &
       (ifrztyp == 3 .and. ixyz ==2)
       
end function move_this_coordinate
!!***


!!****f* BigDFT/
!! FUNCTION
!!   rxyz=txyz+alpha*sxyz
!! SOURCE
!!
subroutine atomic_coordinate_axpy(atoms,ixyz,iat,t,alphas,r)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: ixyz,iat
  real(gp), intent(in) :: t,alphas
  type(atoms_data), intent(in) :: atoms
  real(gp), intent(out) :: r
  !local variables
  logical :: periodize
  real(gp) :: alat,alphai

  if (ixyz == 1) then
     alat=atoms%alat1
  else if (ixyz == 2) then
     alat=atoms%alat2
  else if (ixyz == 3) then
     alat=atoms%alat3
  else
     alat = -1
     write(0,*) "Internal error"
     stop
  end if
  
  periodize= atoms%geocode == 'P' .or. &
       (atoms%geocode == 'S' .and. ixyz /= 2)

  call frozen_alpha(atoms%ifrztyp(iat),ixyz,alphas,alphai)

  if (periodize) then
     r=modulo(t+alphai,alat)
  else
     r=t+alphai
  end if

END SUBROUTINE atomic_coordinate_axpy
!!***
