!> @file
!! Convolution sofr linear version (with quartic potentials)
!! @author
!!    Copyright (C) 2011-2012 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Calculates the effective filter for the operator [kineticEnergy + (x-x0)^4].
!!   
!! Calling arguments:
!! ==================
!!   Input arguments:
!!     @param hgrid  grid spacing
!!     @param x0     the center of the parabolic potential (x-x0)^2
!!   Output arguments:
!!     @param aeff   the effective filter for <phi|Op|phi>
!!     @param beff   the effective filter for <psi|Op|phi>
!!     @param ceff   the effective filter for <phi|Op|psi>
!!     @param eeff   the effective filter for <psi|Op|psi>
subroutine getEffectiveFilterQuartic(parabPrefac,hgrid, x0, eff, filterCode)
use filterModule
implicit none

! Calling arguments
real(kind=8),intent(in) :: parabPrefac, hgrid, x0
real(kind=8),dimension(lb:ub),intent(out) :: eff
character(len=*) :: filterCode

! Local variables
integer :: i
real(8):: fac, fac2, prefac1, hgrid2, hgrid3, x02, x03
prefac1=-.5d0/hgrid**2
fac=parabPrefac
fac2=parabPrefac*hgrid
hgrid2=hgrid**2
hgrid3=hgrid**3
x02=x0**2
x03=x0**3
! Determine which filter we have to calculate
select case(trim(filterCode))
case('a')
    do i=lb,ub
        eff(i)=prefac1*a(i) + fac2*( hgrid3*a4(i) + 4*hgrid2*x0*a3(i) + 6*hgrid*x02*a2(i) + 4*x03*a1(i))
    end do
    eff(0)=eff(0)+fac*x0**4
case('b')
    do i=lb,ub
        eff(i)=prefac1*b(i) + fac2*( hgrid3*b4(i) + 4*hgrid2*x0*b3(i) + 6*hgrid*x02*b2(i) + 4*x03*b1(i))
    end do
case('c')
    do i=lb,ub
        eff(i)=prefac1*c(i) + fac2*( hgrid3*c4(i) + 4*hgrid2*x0*c3(i) + 6*hgrid*x02*c2(i) + 4*x03*c1(i))
    end do
case('e')
    do i=lb,ub
        eff(i)=prefac1*e(i) + fac2*( hgrid3*e4(i) + 4*hgrid2*x0*e3(i) + 6*hgrid*x02*e2(i) + 4*x03*e1(i))
    end do
    eff(0)=eff(0)+fac*x0**4
case default
    write(*,*) "ERROR: allowed values for 'filterCode' are 'a', 'b', 'c', 'e', whereas we found ", trim(filterCode)
    stop
end select


end subroutine getEffectiveFilterQuartic


!> Calculates the effective filter for the operator [kineticEnergy + (x-x0)^4].
!!   
!! Calling arguments:
!! ==================
!!   Input arguments:
!!     @param hgrid  grid spacing
!!     @param x0     the center of the parabolic potential (x-x0)^2
!!   Output arguments:
!!     @param aeff   the effective filter for <phi|Op|phi>
!!     @param beff   the effective filter for <psi|Op|phi>
!!     @param ceff   the effective filter for <phi|Op|psi>
!!     @param eeff   the effective filter for <psi|Op|psi>


!> Calculates the effective filter for the operator (x-x0)^4
!!   
!! Calling arguments:
!! ==================
!!   Input arguments:
!!     @param hgrid  grid spacing
!!     @param x0     the center of the parabolic potential (x-x0)^2
!!   Output arguments:
!!     @param aeff   the effective filter for <phi|Op|phi>
!!     @param beff   the effective filter for <psi|Op|phi>
!!     @param ceff   the effective filter for <phi|Op|psi>
!!     @param eeff   the effective filter for <psi|Op|psi>
subroutine getFilterQuartic(parabPrefac,hgrid, x0, eff, filterCode)

use filterModule
implicit none

! Calling arguments
real(kind=8),intent(in) :: parabPrefac, hgrid, x0
real(kind=8),dimension(lb:ub),intent(out) :: eff
character(len=*) :: filterCode

! Local variables
integer :: i
real(kind=8) :: fac, fac2,  hgrid2, hgrid3, x02, x03
real(kind=8) :: scale
scale=1.d0
!scale=1.d-1
!scale=0.d-1
!scale=5.d-2
!fac=dble(max(100-int(dble(it)/2.d0),1))*parabPrefac
!fac2=dble(max(100-int(dble(it)/2.d0),1))*parabPrefac*hgrid
fac=parabPrefac*scale
fac2=parabPrefac*hgrid*scale
hgrid2=hgrid**2
hgrid3=hgrid**3
x02=x0**2
x03=x0**3
! Determine which filter we have to calculate
select case(trim(filterCode))
case('a')
    do i=lb,ub
        !eff(i)=prefac1*a(i) + fac2*(hgrid*a2(i)+2*x0*a1(i))
        eff(i) = fac2*( hgrid3*a4(i) + 4*hgrid2*x0*a3(i) + 6*hgrid*x02*a2(i) + 4*x03*a1(i))
    end do
    !eff(0)=eff(0)+fac*x0**2
    eff(0)=eff(0)+fac*x0**4
case('b')
    do i=lb,ub
        !eff(i)=prefac1*b(i) + fac2*(hgrid*b2(i)+2*x0*b1(i))
        eff(i) = fac2*( hgrid3*b4(i) + 4*hgrid2*x0*b3(i) + 6*hgrid*x02*b2(i) + 4*x03*b1(i))
    end do
case('c')
    do i=lb,ub
        !eff(i)=prefac1*c(i) + fac2*(hgrid*c2(i)+2*x0*c1(i))
        eff(i) = fac2*( hgrid3*c4(i) + 4*hgrid2*x0*c3(i) + 6*hgrid*x02*c2(i) + 4*x03*c1(i))
    end do
case('e')
    do i=lb,ub
        !eff(i)=prefac1*e(i) + fac2*(hgrid*e2(i)+2*x0*e1(i))
        eff(i) = fac2*( hgrid3*e4(i) + 4*hgrid2*x0*e3(i) + 6*hgrid*x02*e2(i) + 4*x03*e1(i))
    end do
    !eff(0)=eff(0)+fac*x0**2
    eff(0)=eff(0)+fac*x0**4
case default
    write(*,*) "ERROR: allowed values for 'filterCode' are 'a', 'b', 'c', 'e', whereas we found ", trim(filterCode)
    stop
end select


end subroutine getFilterQuartic


!> Calculates the effective filter for the operator (x-x0)^2
!!   
!! Calling arguments:
!! ==================
!!   Input arguments:
!!     @param hgrid  grid spacing
!!     @param x0     the center of the parabolic potential (x-x0)^2
!!   Output arguments:
!!     @param aeff   the effective filter for <phi|Op|phi>
!!     @param beff   the effective filter for <psi|Op|phi>
!!     @param ceff   the effective filter for <phi|Op|psi>
!!     @param eeff   the effective filter for <psi|Op|psi>
subroutine getFilterQuadratic(parabPrefac,hgrid, x0, eff, filterCode)
use filterModule
implicit none

! Calling arguments
real(kind=8),intent(in) :: parabPrefac, hgrid, x0
real(kind=8),dimension(lb:ub),intent(out) :: eff
character(len=*) :: filterCode

! Local variables
integer :: i
real(kind=8) :: fac, fac2, hgrid2, hgrid3, x02, x03
real(kind=8) :: scale
scale=1.d0
!scale=1.d-1
!scale=0.d-1
!scale=5.d-2
!fac=dble(max(100-int(dble(it)/2.d0),1))*parabPrefac
!fac2=dble(max(100-int(dble(it)/2.d0),1))*parabPrefac*hgrid
fac=parabPrefac*scale
fac2=parabPrefac*hgrid*scale
hgrid2=hgrid**2
hgrid3=hgrid**3
x02=x0**2
x03=x0**3
! Determine which filter we have to calculate
select case(trim(filterCode))
case('a')
    do i=lb,ub
        eff(i) = fac2*( hgrid*a2(i) + 2.d0*x0*a1(i) )
        !eff(i) = fac2*( hgrid3*a4(i) + 4*hgrid2*x0*a3(i) + 6*hgrid*x02*a2(i) + 4*x03*a1(i))
    end do
    eff(0)=eff(0)+fac*x0**2
    !eff(0)=eff(0)+fac*x0**4
case('b')
    do i=lb,ub
        eff(i) = fac2*( hgrid*b2(i) + 2.d0*x0*b1(i) )
        !eff(i) = fac2*( hgrid3*b4(i) + 4*hgrid2*x0*b3(i) + 6*hgrid*x02*b2(i) + 4*x03*b1(i))
    end do
case('c')
    do i=lb,ub
        eff(i) = fac2*( hgrid*c2(i) + 2.d0*x0*c1(i) )
        !eff(i) = fac2*( hgrid3*c4(i) + 4*hgrid2*x0*c3(i) + 6*hgrid*x02*c2(i) + 4*x03*c1(i))
    end do
case('e')
    do i=lb,ub
        eff(i) = fac2*( hgrid*e2(i) + 2.d0*x0*e1(i) )
        !eff(i) = fac2*( hgrid3*e4(i) + 4*hgrid2*x0*e3(i) + 6*hgrid*x02*e2(i) + 4*x03*e1(i))
    end do
    eff(0)=eff(0)+fac*x0**2
    !eff(0)=eff(0)+fac*x0**4
case default
    write(*,*) "ERROR: allowed values for 'filterCode' are 'a', 'b', 'c', 'e', whereas we found ", trim(filterCode)
    stop
end select


end subroutine getFilterQuadratic

