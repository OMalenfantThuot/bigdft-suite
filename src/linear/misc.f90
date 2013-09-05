!> @file 
!!   Miscellaneous routines for linear toolbox
!! @author
!!   Copyright (C) 2011-2012 BigDFT group 
!!   This file is distributed under the terms of the
!!   GNU General Public License, see ~/COPYING file
!!   or http://www.gnu.org/copyleft/gpl.txt .
!!   For the list of contributors, see ~/AUTHORS 
 

!> Plots the orbitals
subroutine plotOrbitals(iproc, orbs, lzd, phi, nat, rxyz, hxh, hyh, hzh, it)
use module_base
use module_types
implicit none

! Calling arguments
integer :: iproc
type(orbitals_data), intent(inout) :: orbs
type(local_zone_descriptors), intent(in) :: lzd
real(kind=8), dimension((lzd%glr%wfd%nvctr_c+7*lzd%glr%wfd%nvctr_f)*orbs%nspinor*orbs%norbp) :: phi
integer :: nat
real(kind=8), dimension(3,nat) :: rxyz
real(kind=8) :: hxh, hyh, hzh
integer :: it

integer :: ix, iy, iz, ix0, iy0, iz0, iiAt, jj, iorb, i1, i2, i3, istart, ii, istat, iat
integer :: unit1, unit2, unit3, unit4, unit5, unit6, unit7, unit8, unit9, unit10, unit11, unit12
integer :: ixx, iyy, izz, maxid, i
real(kind=8) :: dixx, diyy, dizz, prevdiff, maxdiff, diff, dnrm2
real(kind=8), dimension(:), allocatable :: phir
real(kind=8),dimension(3) :: rxyzdiff
real(kind=8),dimension(3,11) :: rxyzref
integer,dimension(4) :: closeid
type(workarr_sumrho) :: w
character(len=10) :: c1, c2, c3
character(len=50) :: file1, file2, file3, file4, file5, file6, file7, file8, file9, file10, file11, file12
logical :: dowrite

allocate(phir(lzd%glr%d%n1i*lzd%glr%d%n2i*lzd%glr%d%n3i), stat=istat)

call initialize_work_arrays_sumrho(lzd%glr,w)

istart=0

unit1 =20*iproc+3
unit2 =20*iproc+4
unit3 =20*iproc+5
unit4 =20*iproc+6
unit5 =20*iproc+7
unit6 =20*iproc+8
unit7 =20*iproc+9
unit8 =20*iproc+10
unit9 =20*iproc+11
unit10=20*iproc+12
unit11=20*iproc+13
unit12=20*iproc+14

!write(*,*) 'write, orbs%nbasisp', orbs%norbp
    orbLoop: do iorb=1,orbs%norbp
        !!phir=0.d0
        call to_zero(lzd%glr%d%n1i*lzd%glr%d%n2i*lzd%glr%d%n3i, phir(1))
        call daub_to_isf(lzd%glr,w,phi(istart+1),phir(1))
        iiAt=orbs%inwhichlocreg(orbs%isorb+iorb)
        ix0=nint(rxyz(1,iiAt)/hxh)
        iy0=nint(rxyz(2,iiAt)/hyh)
        iz0=nint(rxyz(3,iiAt)/hzh)

        ! Search the four closest atoms
        prevdiff=1.d-5 ! the same atom
        do i=1,4
            do iat=1,nat
                rxyzdiff(:)=rxyz(:,iat)-rxyz(:,iiat)
                diff=dnrm2(3,rxyzdiff,1)
                if (diff<maxdiff .and. diff>prevdiff) then
                    maxdiff=diff
                    maxid=iat
                end if
            end do
            closeid(i)=maxid
            prevdiff=maxdiff*1.00001d0 !just to be sure that not twice the same is chosen
        end do

        jj=0
        write(c1,'(i5.5)') iproc
        write(c2,'(i5.5)') iorb
        write(c3,'(i5.5)') it
        file1='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_x'
        file2='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_y'
        file3='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_z'
        file4='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_pxpypz'
        file5='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_mxpypz'
        file6='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_mxmypz'
        file7='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_pxmypz'
        file8='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_1st'
        file9='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_2nd'
        file10='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_3rd'
        file11='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_4th'
        file12='orbs_'//trim(c1)//'_'//trim(c2)//'_'//trim(c3)//'_info'
        open(unit=unit1, file=trim(file1))
        open(unit=unit2, file=trim(file2))
        open(unit=unit3, file=trim(file3))
        open(unit=unit4, file=trim(file4))
        open(unit=unit5, file=trim(file5))
        open(unit=unit6, file=trim(file6))
        open(unit=unit7, file=trim(file7))
        open(unit=unit8, file=trim(file8))
        open(unit=unit9, file=trim(file9))
        open(unit=unit10, file=trim(file10))
        open(unit=unit11, file=trim(file11))
        open(unit=unit12, file=trim(file12))
        
        !write(unit1,'(a,3i8)') '# ix0, iy0, iz0 ',ix0,iy0,iz0
        !write(unit2,'(a,3i8)') '# ix0, iy0, iz0 ',ix0,iy0,iz0
        !write(unit3,'(a,3i8)') '# ix0, iy0, iz0 ',ix0,iy0,iz0
        !write(unit4,'(a,3i8)') '# ix0, iy0, iz0 ',ix0,iy0,iz0
        !write(unit5,'(a,3i8)') '# ix0, iy0, iz0 ',ix0,iy0,iz0
        !write(unit6,'(a,3i8)') '# ix0, iy0, iz0 ',ix0,iy0,iz0
        !write(unit7,'(a,3i8)') '# ix0, iy0, iz0 ',ix0,iy0,iz0

        do i3=1,lzd%glr%d%n3i
            do i2=1,lzd%glr%d%n2i
                do i1=1,lzd%glr%d%n1i
                   jj=jj+1
                   ! z component of point jj
                   iz=jj/(lzd%glr%d%n2i*lzd%glr%d%n1i)
                   ! Subtract the 'lower' xy layers
                   ii=jj-iz*(lzd%glr%d%n2i*lzd%glr%d%n1i)
                   ! y component of point jj
                   iy=ii/lzd%glr%d%n1i
                   ! Subtract the 'lower' y rows
                   ii=ii-iy*lzd%glr%d%n1i
                   ! x component
                   ix=ii
!if(phir(jj)>1.d0) write(*,'(a,3i7,es15.6)') 'WARNING: ix, iy, iz, phir(jj)', ix, iy, iz, phir(jj)
                   ixx=ix-ix0
                   iyy=iy-iy0
                   izz=iz-iz0
                   dixx=dble(ixx)
                   diyy=dble(iyy)
                   dizz=dble(izz)

                   ! Write along x-axis
                   if(iy==ix0 .and. iz==iz0) write(unit1,*) ix, phir(jj)

                   ! Write along y-axis
                   if(ix==ix0 .and. iz==iz0) write(unit2,*) iy, phir(jj)

                   ! Write along z-axis
                   if(ix==ix0 .and. iy==iy0) write(unit3,*) iz, phir(jj)

                   ! Write diagonal in octant +x,+y,+z
                   if (ixx==iyy .and. ixx==izz .and. iyy==izz) then
                       write(unit4,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                   ! Write diagonal in octant -x,+y,+z
                   if (-ixx==iyy .and. -ixx==izz .and. iyy==izz) then
                       write(unit5,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                   ! Write diagonal in octant -x,-y,+z
                   if (-ixx==-iyy .and. -ixx==izz .and. -iyy==izz) then
                       write(unit6,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                   ! Write diagonal in octant +x,-y,+z
                   if (ixx==-iyy .and. ixx==izz .and. -iyy==izz) then
                       write(unit7,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                   ! Write along line in direction of the closest atom
                   dowrite=gridpoint_close_to_straightline(ix, iy, iz, &
                       rxyz(1,iiat), rxyz(1,closeid(1)), hxh, hyh, hzh)
                   if (dowrite) then
                       write(unit8,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                   ! Write along line in direction of the second closest atom
                   dowrite=gridpoint_close_to_straightline(ix, iy, iz, &
                       rxyz(1,iiat), rxyz(1,closeid(2)), hxh, hyh, hzh)
                   if (dowrite) then
                       write(unit9,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                   ! Write along line in direction of the third closest atom
                   dowrite=gridpoint_close_to_straightline(ix, iy, iz, &
                       rxyz(1,iiat), rxyz(1,closeid(3)), hxh, hyh, hzh)
                   if (dowrite) then
                       write(unit10,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                   ! Write along line in direction of the fourth closest atom
                   dowrite=gridpoint_close_to_straightline(ix, iy, iz, &
                       rxyz(1,iiat), rxyz(1,closeid(4)), hxh, hyh, hzh)
                   if (dowrite) then
                       write(unit11,*) sqrt(dixx**2+diyy**2+dizz**2)*dsign(1.d0,dizz), phir(jj)
                   end if

                end do
            end do
        end do

        ! Write the positions of the atoms, following the same order as above.
        ! For each grid point, write those atoms which lie in the plane
        ! perpendicular to the axis under consideration.

        ! Along the x axis
        rxyzref(1,1)=rxyz(1,iiat)+1.d0 ; rxyzref(2,1)=rxyz(2,iiat) ; rxyzref(3,1)=rxyz(3,iiat)

        ! Along the y axis
        rxyzref(1,2)=rxyz(1,iiat) ; rxyzref(2,2)=rxyz(2,iiat)+1.d0 ; rxyzref(3,2)=rxyz(3,iiat)

        ! Along the z axis
        rxyzref(1,3)=rxyz(1,iiat) ; rxyzref(2,3)=rxyz(2,iiat) ; rxyzref(3,3)=rxyz(3,iiat)+1.d0

        ! Along the diagonal in the octant +x,+y,+z
        rxyzref(1,4)=rxyz(1,iiat)+1.d0 ; rxyzref(2,4)=rxyz(2,iiat)+1.d0 ; rxyzref(3,4)=rxyz(3,iiat)+1.d0

        ! Along the diagonal in the octant -x,+y,+z
        rxyzref(1,5)=rxyz(1,iiat)-1.d0 ; rxyzref(2,5)=rxyz(2,iiat)+1.d0 ; rxyzref(3,5)=rxyz(3,iiat)+1.d0

        ! Along the diagonal in the octant -x,-y,+z
        rxyzref(1,6)=rxyz(1,iiat)-1.d0 ; rxyzref(2,6)=rxyz(2,iiat)-1.d0 ; rxyzref(3,6)=rxyz(3,iiat)+1.d0

        ! Along the diagonal in the octant +x,-y,+z
        rxyzref(1,7)=rxyz(1,iiat)+1.d0 ; rxyzref(2,7)=rxyz(2,iiat)-1.d0 ; rxyzref(3,7)=rxyz(3,iiat)+1.d0

        ! Along the line in direction of the closest atom
        rxyzref(:,8)=rxyz(1,closeid(1))

        ! Along the line in direction of the second closest atom
        rxyzref(:,9)=rxyz(1,closeid(2))

        ! Along the line in direction of the third closest atom
        rxyzref(:,10)=rxyz(1,closeid(3))

        ! Along the line in direction of the fourth closest atom
        rxyzref(:,11)=rxyz(1,closeid(4))

        do iat=1,nat
             write(unit11,'(12es12.3)') base_point(rxyz(:,iiat), rxyzref(:,1), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,2), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,3), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,4), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,5), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,6), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,7), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,8), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,9), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,10), rxyz(:,iat)), &
                                        base_point(rxyz(:,iiat), rxyzref(:,11), rxyz(:,iat))
        end do


        close(unit=unit1)
        close(unit=unit2)
        close(unit=unit3)
        close(unit=unit4)
        close(unit=unit5)
        close(unit=unit6)
        close(unit=unit7)
        close(unit=unit8)
        close(unit=unit9)
        close(unit=unit10)
        close(unit=unit11)

        istart=istart+(lzd%glr%wfd%nvctr_c+7*lzd%glr%wfd%nvctr_f)*orbs%nspinor

    end do orbLoop

call deallocate_work_arrays_sumrho(w)
deallocate(phir, stat=istat)


contains

  function gridpoint_close_to_straightline(ix, iy, iz, a, b, hxh, hyh, hzh)
    ! Checks whether the grid point (ix,iy,iz) is close to the straight line
    ! going through the points a and b.
    !! IGNORE THIS "Close" means that the point is closest to the line in that plane which is
    !! "most orthogonal" (the angle between the line and the plane normal is
    !! minimal) to the line.
    
    ! Calling arguments
    integer,intent(in) :: ix, iy, iz
    real(kind=8),dimension(3),intent(in) :: a, b
    real(kind=8),intent(in) :: hxh, hyh, hzh
    logical :: gridpoint_close_to_straightline

    ! Local variables
    real(kind=8),dimension(3) :: rxyz
    real(kind=8) :: dist, hh, threshold
    
    !!! Determine which plane is "most orthogonal" to the straight line
    !!xx(1)=1.d0 ; xx(2)=0.d0 ; xx(3)=0.d0
    !!yy(1)=0.d0 ; yy(2)=1.d0 ; yy(3)=0.d0
    !!zz(1)=0.d0 ; zz(2)=0.d0 ; zz(3)=1.d0
    !!bma=b-a
    !!abs_bma=dnrm2(3,bma,1)
    !!! angle between line and xy plane
    !!cosangle(1)=ddot(3,bma,1,zz,1)/dnrm2(bma)
    !!! angle between line and xz plane
    !!cosangle(2)=ddot(3,bma,1,yy,1)/dnrm2(bma)
    !!! angle between line and yz plane
    !!cosangle(3)=ddot(3,bma,1,xx,1)/dnrm2(bma)
    !!plane=minloc(cosangle)

    ! Calculate the shortest distance between the grid point (ix,iy,iz) and the
    ! straight line through the points a and b.
    rxyz = ix*hxh + iy*hyh + iz*hzh
    dist=get_distance(a, b, rxyz)

    ! Calculate the threshold, given by sqrt(2*(hh/2)**2)
    hh = (hxh+hyh+hzh)/3.d0
    threshold=sqrt(hh*2/2)

    ! Check whether the point is close
    if (dist<threshold) then
        gridpoint_close_to_straightline=.true.
    else
        gridpoint_close_to_straightline=.false.
    end if

  end function gridpoint_close_to_straightline

  function get_distance(a, b, c)
    ! Calculate the shortest distance between point C and the 
    ! straight line trough the points A and B.

    ! Calling arguments
    real(kind=8),dimension(3),intent(in) :: a, b, c
    real(kind=8) :: get_distance

    ! Local variables
    real(kind=8),dimension(3) :: cma, bma, cmacbma
    real(kind=8) :: abs_cmacbma, abs_bma, dnrm2

    cma=c-a 
    bma=b-a
    cmacbma=cross_product(cma,bma)
    abs_cmacbma=dnrm2(3,cmacbma,1)
    abs_bma=dnrm2(3,bma,1)
    get_distance=abs_cmacbma/abs_bma

  end function get_distance


  function cross_product(a,b)
    ! Calculates the crosss product of the two vectors a and b.

    ! Calling arguments
    real(kind=8),dimension(3),intent(in) :: a, b
    real(kind=8),dimension(3) :: cross_product

    cross_product(1) = a(2)*b(3) - a(3)*b(2)
    cross_product(2) = a(3)*b(1) - a(1)*b(3)
    cross_product(3) = a(1)*b(2) - a(2)*b(1)

  end function cross_product



  function base_point(a, b, c)
    ! Determine the base point of the perpendicular of the point C with respect
    ! to the vector going through the points A and B.

    ! Calling arguments
    real(kind=8),dimension(3),intent(in) :: a, b, c
    real(kind=8),dimension(3) :: base_point

    base_point(1) = (a(1)*c(1)-b(1)*c(1))/(a(1)-b(1))
    base_point(2) = (a(2)*c(2)-b(2)*c(2))/(a(2)-b(2))
    base_point(3) = (a(3)*c(3)-b(3)*c(3))/(a(3)-b(3))

  end function base_point


end subroutine plotOrbitals



subroutine plotGrid(iproc, norb, nspinor, nspin, orbitalNumber, llr, glr, atoms, rxyz, hx, hy, hz)
  use module_base
  use module_types
  implicit none
  
  ! Calling arguments
  integer, intent(in) :: iproc, norb, nspinor, nspin, orbitalNumber
  type(locreg_descriptors), intent(in) :: llr, glr
  type(atoms_data), intent(in) ::atoms
  real(kind=8), dimension(3,atoms%astruct%nat), intent(in) :: rxyz
  real(kind=8), intent(in) :: hx, hy, hz
  
  ! Local variables
  integer :: iseg, jj, j0, j1, ii, i3, i2, i0, i1, i, ishift, iat, ldim, gdim, jjj, istat
  character(len=10) :: num
  character(len=20) :: filename
  real(kind=8), dimension(:), allocatable :: lphi, phi


    ldim=llr%wfd%nvctr_c+7*llr%wfd%nvctr_f
    gdim=glr%wfd%nvctr_c+7*glr%wfd%nvctr_f
    allocate(lphi(ldim), stat=istat)
    allocate(phi(gdim), stat=istat)
    lphi=1.d0
    !!phi=0.d0
    call to_zero(gdim, phi(1))
    call Lpsi_to_global2(iproc, ldim, gdim, norb, nspinor, nspin, glr, llr, lphi, phi)
  
    write(num,'(i0)') orbitalNumber
    filename='orbital_'//trim(num)
  
    open(unit=2000+iproc,file=trim(filename)//'.xyz',status='unknown')
    !write(2000+iproc,*) llr%wfd%nvctr_c+llr%wfd%nvctr_f+atoms%astruct%nat,' atomic'
    write(2000+iproc,*) glr%wfd%nvctr_c+glr%wfd%nvctr_f+llr%wfd%nvctr_c+llr%wfd%nvctr_f+atoms%astruct%nat,' atomic'
    if (atoms%astruct%geocode=='F') then
       write(2000+iproc,*)'complete simulation grid with low and high resolution points'
    else if (atoms%astruct%geocode =='S') then
       write(2000+iproc,'(a,2x,3(1x,1pe24.17))')'surface',atoms%astruct%cell_dim(1),atoms%astruct%cell_dim(2),&
            atoms%astruct%cell_dim(3)
    else if (atoms%astruct%geocode =='P') then
       write(2000+iproc,'(a,2x,3(1x,1pe24.17))')'periodic',atoms%astruct%cell_dim(1),atoms%astruct%cell_dim(2),&
            atoms%astruct%cell_dim(3)
    end if

   do iat=1,atoms%astruct%nat
      write(2000+iproc,'(a6,2x,3(1x,e12.5),3x)') trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat))),&
           rxyz(1,iat),rxyz(2,iat),rxyz(3,iat)
   end do

  
    jjj=0
    do iseg=1,glr%wfd%nseg_c
       jj=glr%wfd%keyvloc(iseg)
       j0=glr%wfd%keygloc(1,iseg)
       j1=glr%wfd%keygloc(2,iseg)
       ii=j0-1
       i3=ii/((glr%d%n1+1)*(glr%d%n2+1))
       ii=ii-i3*(glr%d%n1+1)*(glr%d%n2+1)
       i2=ii/(glr%d%n1+1)
       i0=ii-i2*(glr%d%n1+1)
       i1=i0+j1-j0
       do i=i0,i1
           jjj=jjj+1
           if(phi(jjj)==1.d0) write(2000+iproc,'(a4,2x,3(1x,e10.3))') '  lg ',&
                real(i,kind=8)*hx,real(i2,kind=8)*hy,real(i3,kind=8)*hz
           write(2000+iproc,'(a4,2x,3(1x,e10.3))') '  g ',real(i,kind=8)*hx,&
                real(i2,kind=8)*hy,real(i3,kind=8)*hz
       enddo
    enddo

    ishift=glr%wfd%nseg_c  
    ! fine part
    do iseg=1,glr%wfd%nseg_f
       jj=glr%wfd%keyvloc(ishift+iseg)
       j0=glr%wfd%keygloc(1,ishift+iseg)
       j1=glr%wfd%keygloc(2,ishift+iseg)
       ii=j0-1
       i3=ii/((glr%d%n1+1)*(glr%d%n2+1))
       ii=ii-i3*(glr%d%n1+1)*(glr%d%n2+1)
       i2=ii/(glr%d%n1+1)
       i0=ii-i2*(glr%d%n1+1)
       i1=i0+j1-j0
       do i=i0,i1
          jjj=jjj+1
          if(phi(jjj)==1.d0) write(2000+iproc,'(a4,2x,3(1x,e10.3))') '  lG ',real(i,kind=8)*hx,real(i2,kind=8)*hy,real(i3,kind=8)*hz
          write(2000+iproc,'(a4,2x,3(1x,e10.3))') '  G ',real(i,kind=8)*hx,real(i2,kind=8)*hy,real(i3,kind=8)*hz
          jjj=jjj+6
       enddo
    enddo
  
    close(unit=2000+iproc)

end subroutine plotGrid



subroutine local_potential_dimensions(Lzd,orbs,ndimfirstproc)
  use module_base
  use module_types
  use module_xc
  implicit none
  integer, intent(in) :: ndimfirstproc
  type(local_zone_descriptors), intent(inout) :: Lzd
  type(orbitals_data), intent(inout) :: orbs
  !local variables
  character(len=*), parameter :: subname='local_potential_dimensions'
  logical :: newvalue
  integer :: i_all,i_stat,ii,iilr,ilr,iorb,iorb2,nilr,ispin
  integer, dimension(:,:), allocatable :: ilrtable
  
  if(Lzd%nlr > 1) then
     allocate(ilrtable(orbs%norbp,2),stat=i_stat)
     call memocc(i_stat,ilrtable,'ilrtable',subname)
     !call to_zero(orbs%norbp*2,ilrtable(1,1))
     ilrtable=0
     ii=0
     do iorb=1,orbs%norbp
        newvalue=.true.
        !localization region to which the orbital belongs
        ilr = orbs%inwhichlocreg(iorb+orbs%isorb)
        !spin state of the orbital
        if (orbs%spinsgn(orbs%isorb+iorb) > 0.0_gp) then
           ispin = 1       
        else
           ispin=2
        end if
        !check if the orbitals already visited have the same conditions
        loop_iorb2: do iorb2=1,orbs%norbp
           if(ilrtable(iorb2,1) == ilr .and. ilrtable(iorb2,2)==ispin) then
              newvalue=.false.
              exit loop_iorb2
           end if
        end do loop_iorb2
        if (newvalue) then
           ii = ii + 1
           ilrtable(ii,1)=ilr
           ilrtable(ii,2)=ispin    !SOMETHING IS NOT WORKING IN THE CONCEPT HERE... ispin is not a property of the locregs, but of the orbitals
        end if
     end do
     !number of inequivalent potential regions
     nilr = ii

     !calculate the dimension of the potential in the gathered form
     lzd%ndimpotisf=0
     do iilr=1,nilr
        ilr=ilrtable(iilr,1)
        do iorb=1,orbs%norbp
           !put the starting point
           if (orbs%inWhichLocreg(iorb+orbs%isorb) == ilr) then
              !assignment of ispot array to the value of the starting address of inequivalent
              orbs%ispot(iorb)=lzd%ndimpotisf + 1
              if(orbs%spinsgn(orbs%isorb+iorb) <= 0.0_gp) then
                 orbs%ispot(iorb)=lzd%ndimpotisf + &
                      1 + lzd%llr(ilr)%d%n1i*lzd%llr(ilr)%d%n2i*lzd%llr(ilr)%d%n3i
              end if
           end if
        end do
        lzd%ndimpotisf = lzd%ndimpotisf + &
             lzd%llr(ilr)%d%n1i*lzd%llr(ilr)%d%n2i*lzd%llr(ilr)%d%n3i*orbs%nspin
     end do
     !part which refers to exact exchange (only meaningful for one region)
     if (xc_exctXfac() /= 0.0_gp) then
        lzd%ndimpotisf = lzd%ndimpotisf + &
             max(max(lzd%llr(ilr)%d%n1i*lzd%llr(ilr)%d%n2i*lzd%llr(ilr)%d%n3i*orbs%norbp,ndimfirstproc*orbs%norb),1)
     end if

  else 
     allocate(ilrtable(1,2),stat=i_stat)
     call memocc(i_stat,ilrtable,'ilrtable',subname)
     nilr = 1
     ilrtable=1

     !calculate the dimension of the potential in the gathered form
     lzd%ndimpotisf=0
     do iorb=1,orbs%norbp
        !assignment of ispot array to the value of the starting address of inequivalent
        orbs%ispot(iorb)=lzd%ndimpotisf + 1
        if(orbs%spinsgn(orbs%isorb+iorb) <= 0.0_gp) then
           orbs%ispot(iorb)=lzd%ndimpotisf + &
                1 + lzd%Glr%d%n1i*lzd%Glr%d%n2i*lzd%Glr%d%n3i
        end if
     end do
     lzd%ndimpotisf = lzd%ndimpotisf + &
          lzd%Glr%d%n1i*lzd%Glr%d%n2i*lzd%Glr%d%n3i*orbs%nspin
          
     !part which refers to exact exchange (only meaningful for one region)
     if (xc_exctXfac() /= 0.0_gp) then
        lzd%ndimpotisf = lzd%ndimpotisf + &
             max(max(lzd%Glr%d%n1i*lzd%Glr%d%n2i*lzd%Glr%d%n3i*orbs%norbp,ndimfirstproc*orbs%norb),1)
     end if


  end if


  i_all=-product(shape(ilrtable))*kind(ilrtable)
  deallocate(ilrtable,stat=i_stat)
  call memocc(i_stat,i_all,'ilrtable',subname)

end subroutine local_potential_dimensions



subroutine print_orbital_distribution(iproc, nproc, orbs)
use module_base
use module_types
implicit none

integer, intent(in) :: iproc, nproc
type(orbitals_data), intent(in) :: orbs

! Local variables
integer :: jproc, len1, len2, space1, space2
logical :: written

write(*,'(1x,a)') '------------------------------------------------------------------------------------'
written=.false.
write(*,'(1x,a)') '>>>> Partition of the basis functions among the processes.'
do jproc=1,nproc-1
    if(orbs%norb_par(jproc,0)<orbs%norb_par(jproc-1,0)) then
        len1=1+ceiling(log10(dble(jproc-1)+1.d-5))+ceiling(log10(dble(orbs%norb_par(jproc-1,0)+1.d-5)))
        len2=ceiling(log10(dble(jproc)+1.d-5))+ceiling(log10(dble(nproc-1)+1.d-5))+&
             ceiling(log10(dble(orbs%norb_par(jproc,0)+1.d-5)))
        if(len1>=len2) then
            space1=1
            space2=1+len1-len2
        else
            space1=1+len2-len1
            space2=1
        end if
        write(*,'(4x,a,2(i0,a),a,a)') '| Processes from 0 to ',jproc-1,' treat ',&
            orbs%norb_par(jproc-1,0), ' orbitals,', repeat(' ', space1), '|'
        write(*,'(4x,a,3(i0,a),a,a)')  '| processes from ',jproc,' to ',nproc-1,' treat ', &
            orbs%norb_par(jproc,0),' orbitals.', repeat(' ', space2), '|'
        written=.true.
        exit
    end if
end do
if(.not.written) then
    write(*,'(4x,a,2(i0,a),a,a)') '| Processes from 0 to ',nproc-1, &
        ' treat ',orbs%norbp,' orbitals. |'!, &
end if
write(*,'(1x,a)') '-----------------------------------------------'

!!written=.false.
!!write(*,'(1x,a)') '>>>> Partition of the basis functions including the derivatives among the processes.'
!!do jproc=1,nproc-1
!!    if(derorbs%norb_par(jproc,0)<derorbs%norb_par(jproc-1,0)) then
!!        len1=1+ceiling(log10(dble(jproc-1)+1.d-5))+ceiling(log10(dble(derorbs%norb_par(jproc-1,0)+1.d-5)))
!!        len2=ceiling(log10(dble(jproc)+1.d-5))+ceiling(log10(dble(nproc-1)+1.d-5))+&
!!             ceiling(log10(dble(derorbs%norb_par(jproc,0)+1.d-5)))
!!        if(len1>=len2) then
!!            space1=1
!!            space2=1+len1-len2
!!        else
!!            space1=1+len2-len1
!!            space2=1
!!        end if
!!        write(*,'(4x,a,2(i0,a),a,a)') '| Processes from 0 to ',jproc-1,' treat ',&
!!            derorbs%norb_par(jproc-1,0), ' orbitals,', repeat(' ', space1), '|'
!!        write(*,'(4x,a,3(i0,a),a,a)')  '| processes from ',jproc,' to ',nproc-1,' treat ', &
!!            derorbs%norb_par(jproc,0),' orbitals.', repeat(' ', space2), '|'
!!        written=.true.
!!        exit
!!    end if
!!end do
!!if(.not.written) then
!!    write(*,'(4x,a,2(i0,a),a,a)') '| Processes from 0 to ',nproc-1, &
!!        ' treat ',derorbs%norbp,' orbitals. |'
!!end if
!!write(*,'(1x,a)') '------------------------------------------------------------------------------------'


end subroutine print_orbital_distribution

