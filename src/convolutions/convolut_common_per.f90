!>   Analysis wavelet transformation in periodic BC
!!   The input array y is NOT overwritten
!!
!! @author
!!    Copyright (C) 2007-2011 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS 
!!
!!
subroutine analyse_per(n1,n2,n3,ww,y,x)
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:2*n2+1,0:2*n3+1,0:2*n1+1), intent(inout) :: ww
  real(wp), dimension(0:2*n1+1,0:2*n2+1,0:2*n3+1), intent(inout) :: y
  real(wp), dimension(0:n1,2,0:n2,2,0:n3,2), intent(out) :: x
  !local variables
  integer :: nt

  ! I1,I2,I3 -> I2,I3,i1
  nt=(2*n2+2)*(2*n3+2)
  call  ana_rot_per(n1,nt,y,x)
  ! I2,I3,i1 -> I3,i1,i2
  nt=(2*n3+2)*(2*n1+2)
  call  ana_rot_per(n2,nt,x,ww)
  ! I3,i1,i2 -> i1,i2,i3
  nt=(2*n1+2)*(2*n2+2)
  call  ana_rot_per(n3,nt,ww,x)

END SUBROUTINE analyse_per



subroutine analyse_per_self(n1,n2,n3,y,x)
  ! Analysis wavelet transformation  in periodic BC
  ! The input array y is overwritten
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:2*n1+1,0:2*n2+1,0:2*n3+1), intent(inout) :: y
  real(wp), dimension(0:n1,2,0:n2,2,0:n3,2), intent(out) :: x
  !local variables
  integer :: nt

  ! I1,I2,I3 -> I2,I3,i1
  nt=(2*n2+2)*(2*n3+2)
  call  ana_rot_per(n1,nt,y,x)
  ! I2,I3,i1 -> I3,i1,i2
  nt=(2*n3+2)*(2*n1+2)
  call  ana_rot_per(n2,nt,x,y)
  ! I3,i1,i2 -> i1,i2,i3
  nt=(2*n1+2)*(2*n2+2)
  call  ana_rot_per(n3,nt,y,x)

END SUBROUTINE analyse_per_self


subroutine synthese_per(n1,n2,n3,ww,x,y)
  ! A synthesis wavelet transformation  in periodic BC
  ! The input array x is not overwritten
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:n1,2,0:n2,2,0:n3,2), intent(in) :: x
  real(wp), dimension(0:2*n2+1,0:2*n3+1,0:2*n1+1), intent(inout) :: ww
  real(wp), dimension(0:2*n1+1,0:2*n2+1,0:2*n3+1), intent(inout) :: y
  !local variables
  integer :: nt

  ! i1,i2,i3 -> i2,i3,I1
  nt=(2*n2+2)*(2*n3+2)
  call  syn_rot_per(n1,nt,x,y) 
  ! i2,i3,I1 -> i3,I1,I2
  nt=(2*n3+2)*(2*n1+2)
  call  syn_rot_per(n2,nt,y,ww)
  ! i3,I1,I2  -> I1,I2,I3
  nt=(2*n1+2)*(2*n2+2)
  call  syn_rot_per(n3,nt,ww,y)

END SUBROUTINE synthese_per


subroutine synthese_per_self(n1,n2,n3,x,y)
  ! A synthesis wavelet transformation in periodic BC
  ! The input array x is  overwritten
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:n1,2,0:n2,2,0:n3,2), intent(in) :: x
  real(wp), dimension(0:2*n1+1,0:2*n2+1,0:2*n3+1), intent(inout) :: y
  !local variables
  integer :: nt

  ! i1,i2,i3 -> i2,i3,I1
  nt=(2*n2+2)*(2*n3+2)
  call  syn_rot_per(n1,nt,x,y) 
  ! i2,i3,I1 -> i3,I1,I2
  nt=(2*n3+2)*(2*n1+2)
  call  syn_rot_per(n2,nt,y,x)
  ! i3,I1,I2  -> I1,I2,I3
  nt=(2*n1+2)*(2*n2+2)
  call  syn_rot_per(n3,nt,x,y)

END SUBROUTINE synthese_per_self


! Applies the magic filter matrix in periodic BC ( no transposition)
! The input array x is not overwritten
! this routine is modified to accept the GPU convolution if it is the case
subroutine convolut_magic_n_per(n1,n2,n3,x,y,ww)
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:n1,0:n2,0:n3), intent(in) :: x
  real(wp), dimension(0:n1,0:n2,0:n3), intent(out) :: y
  !local variables
  character(len=*), parameter :: subname='convolut_magic_n_per'
  integer, parameter :: lowfil=-8,lupfil=7 !for GPU computation
  integer :: ndat
  real(wp), dimension(0:n1,0:n2,0:n3):: ww ! work array
  
  !  (i1,i2*i3) -> (i2*i3,I1)
     ndat=(n2+1)*(n3+1)
     call convrot_n_per(n1,ndat,x,y)
     !  (i2,i3*I1) -> (i3*i1,I2)
     ndat=(n3+1)*(n1+1)
     call convrot_n_per(n2,ndat,y,ww)
     !  (i3,I1*I2) -> (iI*I2,I3)
     ndat=(n1+1)*(n2+1)
     call convrot_n_per(n3,ndat,ww,y)
END SUBROUTINE convolut_magic_n_per


! Applies the magic filter matrix in periodic BC ( no transposition)
! The input array x is overwritten in the usual case
! this routine is modified to accept the GPU convolution if it is the case
subroutine convolut_magic_n_per_self(n1,n2,n3,x,y)
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:n1,0:n2,0:n3), intent(in) :: x
  real(wp), dimension(0:n1,0:n2,0:n3), intent(inout) :: y
  !local variables
  character(len=*), parameter :: subname='convolut_magic_n_per'
  integer, parameter :: lowfil=-8,lupfil=7 !for GPU computation
  integer :: ndat

  !  (i1,i2*i3) -> (i2*i3,I1)
  ndat=(n2+1)*(n3+1)
  call convrot_n_per(n1,ndat,x,y)
  !  (i2,i3*I1) -> (i3*i1,I2)
  ndat=(n3+1)*(n1+1)
  call convrot_n_per(n2,ndat,y,x)
  !  (i3,I1*I2) -> (iI*I2,I3)
  ndat=(n1+1)*(n2+1)
  call convrot_n_per(n3,ndat,x,y)

END SUBROUTINE convolut_magic_n_per_self


! Applies the magic filter matrix transposed in periodic BC 
! The input array x is overwritten
! this routine is modified to accept the GPU convolution if it is the case
subroutine convolut_magic_t_per_self(n1,n2,n3,x,y)
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:n1,0:n2,0:n3), intent(inout) :: x
  real(wp), dimension(0:n1,0:n2,0:n3), intent(out) :: y
  !local variables
  character(len=*), parameter :: subname='convolut_magic_t_per'
  integer, parameter :: lowfil=-7,lupfil=8
  integer :: ndat
  
  !  (I1,I2*I3) -> (I2*I3,i1)
  ndat=(n2+1)*(n3+1)
  call convrot_t_per(n1,ndat,x,y)
  !  (I2,I3*i1) -> (I3*i1,i2)
  ndat=(n3+1)*(n1+1)
  call convrot_t_per(n2,ndat,y,x)
  !  (I3,i1*i2) -> (i1*i2,i3)
  ndat=(n1+1)*(n2+1)
  call convrot_t_per(n3,ndat,x,y)

END SUBROUTINE convolut_magic_t_per_self





! Applies the magic filter matrix transposed  in periodic BC
! The input array x is not overwritten
! this routine is modified to accept the GPU convolution if it is the case
subroutine convolut_magic_t_per(n1,n2,n3,x,y)
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(wp), dimension(0:n1,0:n2,0:n3), intent(inout) :: x
  real(wp), dimension(0:n1,0:n2,0:n3), intent(out) :: y
  !local variables
  character(len=*), parameter :: subname='convolut_magic_t_per'
  integer, parameter :: lowfil=-7,lupfil=8
  integer :: ndat,i_stat,i_all
  real(wp), dimension(:,:,:), allocatable :: ww

  allocate(ww(0:n1,0:n2,0:n3+ndebug),stat=i_stat)
  call memocc(i_stat,ww,'ww',subname)

  !  (I1,I2*I3) -> (I2*I3,i1)
  ndat=(n2+1)*(n3+1)
  call convrot_t_per(n1,ndat,x,y)
  !  (I2,I3*i1) -> (I3*i1,i2)
  ndat=(n3+1)*(n1+1)
  call convrot_t_per(n2,ndat,y,ww)
  !  (I3,i1*i2) -> (i1*i2,i3)
  ndat=(n1+1)*(n2+1)
  call convrot_t_per(n3,ndat,ww,y)

  i_all=-product(shape(ww))*kind(ww)
  deallocate(ww,stat=i_stat)
  call memocc(i_stat,i_all,'ww',subname)

END SUBROUTINE convolut_magic_t_per

