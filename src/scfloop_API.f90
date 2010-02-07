!!****m* BigDFT/scfloop_API
!! FUNCTION
!!  Self-Consistent Loop API
!!
!! COPYRIGHT
!!    Copyright (C) 2007-2009 CEA, UNIBAS
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 
!!
!! SOURCE
!!
module scfloop_API

  use module_base
  use module_types

  implicit none

  ! Storage of required variables for a SCF loop calculation.
  logical :: scfloop_initialised = .false.
  integer :: scfloop_nproc
  type(atoms_data), pointer :: scfloop_at
  type(input_variables), pointer :: scfloop_in
  type(restart_objects), pointer :: scfloop_rst

  public :: scfloop_init
!!!  public :: scfloop_finalise
contains

  subroutine scfloop_init(nproc_, at_, in_, rst_)
    integer, intent(in) :: nproc_
    type(atoms_data), intent(in), target :: at_
    type(input_variables), intent(in), target :: in_
    type(restart_objects), intent(in), target :: rst_

    scfloop_nproc = nproc_
    scfloop_at => at_
    scfloop_in => in_
    scfloop_rst => rst_

    scfloop_initialised = .true.
  end subroutine scfloop_init

!!!  subroutine scfloop_finalise()
!!!  end subroutine scfloop_finalise
end module scfloop_API
!!***

subroutine scfloop_main(acell, epot, fcart, grad, itime, me, natom, rprimd, xred)
  use scfloop_API
  use module_base
  use module_types
  use module_interfaces

  implicit none

  integer, intent(in) :: natom, itime, me
  real(dp), intent(out) :: epot
  real(dp), intent(in) :: acell(3)
  real(dp), intent(in) :: rprimd(3,3), xred(3,natom)
  real(dp), intent(out) :: fcart(3, natom), grad(3, natom)

  character(len=*), parameter :: subname='scfloop_main'
  integer :: infocode, i, i_stat, i_all
  real(dp) :: favg(3)
  real(dp), allocatable :: xcart(:,:)

  if (.not. scfloop_initialised) then
     write(0,*) "No previous call to scfloop_init(). On strike, refuse to work."
     stop
  end if

  if (me == 0) then
     write( *,'(1x,a,1x,i0)') &
          & 'SCFloop API, call force calculation step=', itime
  end if

  ! We transfer acell into at
  scfloop_at%alat1 = acell(1)
  scfloop_at%alat2 = rprimd(2,2)
  scfloop_at%alat3 = acell(3)

  scfloop_in%inputPsiId=1
  ! need to transform xred into xcart
  allocate(xcart(3, scfloop_at%nat+ndebug),stat=i_stat)
  call memocc(i_stat,xcart,'xcart',subname)
  do i = 1, scfloop_at%nat, 1
     xcart(:, i) = xred(:, i) * acell(:)
  end do

  scfloop_in%inputPsiId = 1
  call call_bigdft(scfloop_nproc,me,scfloop_at,xcart,scfloop_in,epot,grad,scfloop_rst,infocode)

  ! need to transform the forces into reduced ones.
  favg(:) = real(0, dp)
  do i = 1, scfloop_at%nat, 1
     fcart(:, i) = grad(:, i)
     favg(:) = favg(:) + fcart(:, i) / real(natom, dp)
     grad(:, i) = -grad(:, i) / acell(:)
  end do
  do i = 1, scfloop_at%nat, 1
     fcart(:, i) = fcart(:, i) - favg(:)
  end do

  i_all=-product(shape(xcart))*kind(xcart)
  deallocate(xcart,stat=i_stat)
  call memocc(i_stat,i_all,'xcart',subname)
end subroutine scfloop_main

subroutine scfloop_output(acell, epot, ekin, fred, itime, me, natom, rprimd, vel, xred)
  use scfloop_API
  use module_base
  use module_types
  use module_interfaces

  implicit none

  integer, intent(in) :: natom, itime, me
  real(dp), intent(in) :: epot, ekin
  real(dp), intent(in) :: acell(3)
  real(dp), intent(in) :: rprimd(3,3), xred(3,natom)
  real(dp), intent(in) :: fred(3, natom), vel(3, natom)

  character(len=*), parameter :: subname='scfloop_output'
  character(len = 4) :: fn4
  character(len = 40) :: comment
  integer :: i, i_stat, i_all
  real :: fnrm
  real(dp), allocatable :: xcart(:,:)

  if (me /= 0) return

  fnrm = real(0, dp)
  ! need to transform xred into xcart
  allocate(xcart(3, scfloop_at%nat+ndebug),stat=i_stat)
  call memocc(i_stat,xcart,'xcart',subname)
  do i = 1, scfloop_at%nat, 1
     xcart(:, i) = xred(:, i) * acell(:)
     fnrm = fnrm + fred(1, i) * acell(1) * fred(1, i) * acell(1) + &
          & fred(2, i) * acell(2) * fred(2, i) * acell(2) + &
          & fred(3, i) * acell(3) * fred(3, i) * acell(3)
  end do

  write(fn4,'(i4.4)') itime
  write(comment,'(a,1pe10.3)')'AB6MD:fnrm= ', sqrt(fnrm)
  call write_atomic_file('posout_'//fn4, epot + ekin, xcart, scfloop_at, trim(comment))

  !write velocities
  write(comment,'(a,i6.6)')'Timestep= ',itime
  call wtvel('velocities.xyz',vel,atoms,comment)

  i_all=-product(shape(xcart))*kind(xcart)
  deallocate(xcart,stat=i_stat)
  call memocc(i_stat,i_all,'xcart',subname)
end subroutine scfloop_output

!!****f* BigDFT/read_velocities
!! FUNCTION
!!    Read atomic positions
!! SOURCE
!!
subroutine read_velocities(iproc,filename,atoms,vxyz)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename
  integer, intent(in) :: iproc
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%nat), intent(out) :: vxyz
  !local variables
  character(len=*), parameter :: subname='read_velocities'
  character(len=2) :: symbol
  character(len=20) :: tatonam,units
  character(len=50) :: extra
  character(len=150) :: line
  logical :: lpsdbl,exists
  integer :: iat,ityp,i,ierrsfx,i_stat
! To read the file posinp (avoid differences between compilers)
  real(kind=4) :: rx,ry,rz,alat1,alat2,alat3
! case for which the atomic positions are given whithin general precision
  real(gp) :: rxd0,ryd0,rzd0,alat1d0,alat2d0,alat3d0
  character(len=20), dimension(100) :: atomnames

  !inquire whether the input file is present, otherwise put velocities to zero
  inquire(file=filename,exist=exists)
  if (.not. exists) then  
     call razero(3*atoms%nat,vxyz)
  end if

  !controls if the positions are provided with machine precision
  if (atoms%units== 'atomicd0' .or. atoms%units== 'bohrd0') then
     lpsdbl=.true.
  else
     lpsdbl=.false.
  end if

  open(unit=99,file=trim(filename),status='old')

  read(99,*) nat,units
 
  !check whether the number of atoms is different 
  if (nat /= atoms%nat) then
     if (iproc ==0) write(*,*)' ERROR: the number of atoms in the velocities is different'
     stop
  end if

  !read from positions of .xyz format, but accepts also the old .ascii format
  read(99,'(a150)')line

  if (lpsdbl) then
     read(line,*,iostat=ierrsfx) tatonam,alat1d0,alat2d0,alat3d0
  else
     read(line,*,iostat=ierrsfx) tatonam,alat1,alat2,alat3
  end if

  !convert the values of the cell sizes in bohr
  if (units=='angstroem' .or. units=='angstroemd0') then
  else if  (units=='atomic' .or. units=='bohr'  .or.&
       units== 'atomicd0' .or. units== 'bohrd0') then
  else if (units == 'reduced') then
     !assume that for reduced coordinates cell size is in bohr
  else
     write(*,*) 'length units in input file unrecognized'
     write(*,*) 'recognized units are angstroem or atomic = bohr'
     stop 
  endif
  do iat=1,atoms%nat
     !xyz input file, allow extra information
     read(99,'(a150)')line 
     if (lpsdbl) then
        read(line,*,iostat=ierrsfx)symbol,vxd0,vyd0,vzd0
     else
        read(line,*,iostat=ierrsfx)symbol,vx,vy,vz
     end if
     tatonam=trim(symbol)
     if (lpsdbl) then
        vxyz(1,iat)=vxd0
        vxyz(2,iat)=vyd0
        vxyz(3,iat)=vzd0
     else
        vxyz(1,iat)=real(vx,gp)
        vxyz(2,iat)=real(vy,gp)
        vxyz(3,iat)=real(vz,gp)
     end if
 
     if (units=='angstroem' .or. units=='angstroemd0') then
        ! if Angstroem convert to Bohr
        do i=1,3 
           vxyz(i,iat)=vxyz(i,iat)/bohr2ang
        enddo
     else if (units == 'reduced') then 
        vxyz(1,iat)=vxyz(1,iat)*atoms%alat1
        if (atoms%geocode == 'P') vxyz(2,iat)=vxyz(2,iat)*atoms%alat2
        vxyz(3,iat)=vxyz(3,iat)*atoms%alat3
     endif
  enddo

  close(unit=99)
end subroutine read_velocities
!!***

subroutine wtvel(filename,vxyz,atoms,comment)
  use module_base
  use module_types
  implicit none
  character(len=*), intent(in) :: filename,comment
  type(atoms_data), intent(in) :: atoms
  real(gp), dimension(3,atoms%nat), intent(in) :: vxyz
  !local variables
  character(len=2) :: symbol
  character(len=10) :: name
  character(len=11) :: units
  character(len=50) :: extra
  integer :: iat,j
  real(gp) :: factor

  open(unit=9,file=trim(filename))
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

     write(9,'(a2,4x,3(1x,1pe24.17))')symbol,(vxyz(j,iat)*factor,j=1,3)

  enddo

  close(unit=9)
end subroutine wtvel
