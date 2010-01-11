! This contains a series of utilities that could be used by a number
! of program. They suppose very little.

! The subroutine convert_to_chain takes an integer and transforms it into a
! chain of character.

subroutine convert_to_chain(init_number,chain)
  integer, intent(in) :: init_number
  character(len=4), intent(out) :: chain
  character(len=10) :: digits = '0123456789'
  
  integer :: i, decades, divider, remainder,number


  number = init_number
  decades = log10( 1.0d0 * number) + 1

  divider = 1
  do i=2, decades
    divider =  divider * 10 
  enddo
     
  chain = 'AB'
  do i = 1, decades
    remainder = number / divider  + 1
    chain = chain(1:i-1) // digits(remainder:remainder)
    remainder = remainder -1
    number = number - remainder * divider
    divider = divider / 10
  enddo

  write(*,*) 'Chain :', init_number, chain
end subroutine     

! The subroutine center places the center of mass of a 3D vector at (0,0,0)
subroutine center(vector,vecsize)
  integer, intent(IN) :: vecsize
  real(8), dimension(vecsize),intent(inout), target :: vector

  integer :: i, natoms
  real(8), dimension(:), pointer :: x, y, z     ! Pointers for coordinates
  real(8) :: xtotal, ytotal, ztotal

  natoms = vecsize / 3

  ! We first set-up pointers for the x, y, z components 
  x => vector(1:natoms)
  y => vector(natoms+1:2*natoms)
  z => vector(2*natoms+1:3*natoms)

  xtotal = 0.0d0
  ytotal = 0.0d0
  ztotal = 0.0d0

  do i = 1, natoms
    xtotal = xtotal + x(i)
    ytotal = ytotal + y(i)
    ztotal = ztotal + z(i)
  enddo 

  xtotal = xtotal / natoms
  ytotal = ytotal / natoms
  ztotal = ztotal / natoms

  do i = 1, natoms
    x(i) = x(i) - xtotal
    y(i) = y(i) - ytotal
    z(i) = z(i) - ztotal
  end do
end subroutine


! This subroutine computes the distance between two configurations and 
! the number of particles having moved by more than a THRESHOLD

subroutine displacement(posa, posb, delr,npart)
  use defs
  implicit none

  real(8), parameter :: THRESHOLD = 0.1  ! In Angstroems
  
  real(8), dimension(vecsize), intent(in), target :: posa, posb
  integer, intent(out) :: npart
  real(8), intent(out) :: delr

  real(8), dimension(:), pointer :: xa, ya, za, xb, yb, zb

  integer :: i, j
  real(8) :: delx, dely, delz, dr, dr2, delr2, thresh

  ! We first set-up pointers for the x, y, z components for posa and posb
  xa => posa(1:NATOMS)
  ya => posa(NATOMS+1:2*NATOMS)
  za => posa(2*NATOMS+1:3*NATOMS)

  xb => posb(1:NATOMS)
  yb => posb(NATOMS+1:2*NATOMS)
  zb => posb(2*NATOMS+1:3*NATOMS)


  thresh = THRESHOLD 
  delr2 = 0.0d0
  npart = 0

  do i=1, NATOMS
    delx = (xa(i) - xb(i))
    dely = (ya(i) - yb(i))
    delz = (za(i) - zb(i))

    dr2   = delx*delx + dely*dely + delz*delz
    delr2 = delr2 + dr2
    dr = sqrt(dr2) 
! could comment this part if you are not interested in counting the moved atoms 
    if(dr > thresh) then 
       npart = npart + 1
    endif
  end do

  delr = sqrt(delr2)

end subroutine

! Subroutine store
! This subroutine stores the configurations at minima and activated points
! By definition, it uses pos, box and scala
!
subroutine store(fname)
  use defs
  implicit none
  character(len=7 ), intent(in) :: fname
  character(len=20) :: fnamexyz, extension
  integer ierror
  real(8) :: boxl
  integer i, i_ind, j, j_ind, k, jj
  real(8) :: xi, yi, zi, xij, yij, zij, rij2

  ! We first set-up pointers for the x, y, z components for posa and posb

  boxl = box * scala  ! Update the box size
 
  write(*,*) 'Writing to file : ', FCONF
! added by Fedwa El-Mellouhi July 2002, writes the configuration in jmol format 
  extension = '.xyz'
  fnamexyz = fname // extension

  write(*,*) 'Fname     : ', fname
  write(*,*) 'Fname.xyz : ', fnamexyz
   
  open(unit=FCONF,file=fname,status='unknown',action='write',iostat=ierror)
  open(unit=XYZ,file=fnamexyz,status='unknown',action='write',iostat=ierror)

  write(XYZ,*) NATOMS  
  write(XYZ,*) boxl

  write(FCONF,*) 'run_id: ', mincounter
  write(FCONF,*) 'total energy : ', total_energy
  write(FCONF,*) boxl

  do i=1, NATOMS
    write(XYZ,'(1x,A2,3(2x,f16.8))') Atom(i), x(i), y(i), z(i)
    write(FCONF,'(1x,i6,3(2x,f16.8))') type(i), x(i), y(i), z(i)
  end do

  close(FCONF)
  close(XYZ)
  
  return
end subroutine store