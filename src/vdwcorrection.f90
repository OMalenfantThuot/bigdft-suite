! -*- mode: F90 ; mode: font-lock ; column-number-mode: true -*-
!================================================================!
!                                                                !
!          Van der Waals empirical correction module             !
!                                                                !
! This module contains subroutines for calculating a Van der     !
! Waals energy correction as a sum of damped London potentials.  !
!----------------------------------------------------------------!
! Written by Quintin Hill in 2007/8 with assistance from         !
! Chris-Kriton Skylaris.                                         !
! Forces added July 2008 by Quintin Hill                         !
! Modified for BigDFT in March/April 2009 by Quintin Hill        !
!================================================================!
! COPYRIGHT                                                      !
! Copyright (C)  2007-2009  Quintin Hill.                        !
! This file is distributed under the terms of the                !
! GNU General Public License either version 2 of the License, or !
! (at your option) any later version, see ~/COPYING file,        !
! http://www.gnu.org/licenses/gpl-2.0.txt (for GPL v2)           !
! or http://www.gnu.org/copyleft/gpl.txt (for latest version).   !
!================================================================!

module vdwcorrection

  use module_base, only: GP

  implicit none

  private

  ! qoh: Structure to store parameters in

  TYPE VDWPARAMETERS
     !qoh: C_6 coefficients
     REAL(kind=GP), DIMENSION(109) :: C6COEFF
     !qoh: R_0 values
     REAL(kind=GP), DIMENSION(109) :: RADZERO
     !qoh: damping coefficient
     REAL(kind=GP), dimension(3) :: DCOEFF
     !qoh: Effective number of electrons
     REAL(kind=GP), DIMENSION(109) :: NEFF
  END TYPE VDWPARAMETERS

  public :: vdwcorrection_calculate_energy
  public :: vdwcorrection_calculate_forces

  ! qoh: Share array of Van der Waals parameters accross module

  type(VDWPARAMETERS) :: vdwparams ! Array of parameters
 

contains

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine vdwcorrection_initializeparams(in)

    !==================================================================!
    ! This subroutine populates the array of Van der Waals parameters  !
    !------------------------------------------------------------------!
    ! Written by Quintin Hill in 2007, with some modifications in 2008 !
    ! Some unoptimised parameters (e.g. for P) were taken from Halgren.!
    ! Journal of the American Chemical Society 114(20), 7827–7843, 1992!
    !==================================================================!

    use module_types, only: input_variables
    implicit none

    type(input_variables), intent(in) :: in

    ! qoh: Initialise the vdwparams array
    vdwparams%c6coeff = 0.0_GP
    vdwparams%neff    = 0.0_GP
    ! qoh: Setting to 1 prevents division by zero
    vdwparams%radzero = 1.0_GP

    ! qoh: Populate the vdwparams array  

    select case (in%ixc)

    case(11)

       pbedamp: select case (in%dispersion)

       case(1) pbedamp

          vdwparams%dcoeff(1)=3.2607_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=2.9239_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.3561_GP
          vdwparams%c6coeff(7)=19.5089_GP
          vdwparams%c6coeff(8)=11.7697_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0368_GP
          vdwparams%radzero(1)=2.9635_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.3610_GP
          vdwparams%radzero(7)=3.5136_GP
          vdwparams%radzero(8)=3.7294_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=5.1033_GP

       case(2) pbedamp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=2.8450_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.3200_GP
          vdwparams%c6coeff(7)=19.4800_GP
          vdwparams%c6coeff(8)=11.7600_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0232_GP
          vdwparams%radzero(1)=3.0000_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.8000_GP
          vdwparams%radzero(7)=3.8000_GP
          vdwparams%radzero(8)=3.8000_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=5.5998_GP

       case(3) pbedamp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0025_GP
          vdwparams%c6coeff(1)=2.9865_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.3784_GP
          vdwparams%c6coeff(7)=19.5223_GP
          vdwparams%c6coeff(8)=11.7733_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0388_GP
          vdwparams%radzero(1)=2.8996_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.0001_GP
          vdwparams%radzero(7)=3.2659_GP
          vdwparams%radzero(8)=3.6630_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=4.7948_GP


       end select pbedamp

    case(15)

       rpbedamp: select case (in%dispersion)

       case(1) rpbedamp

          vdwparams%dcoeff(1)=3.4967_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=3.2054_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.4608_GP
          vdwparams%c6coeff(7)=19.5765_GP
          vdwparams%c6coeff(8)=11.7926_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0465_GP
          vdwparams%radzero(1)=2.8062_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.0375_GP
          vdwparams%radzero(7)=3.2484_GP
          vdwparams%radzero(8)=3.6109_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=4.0826_GP


       case(2) rpbedamp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.9308_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=3.2290_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.4707_GP
          vdwparams%c6coeff(7)=19.5922_GP
          vdwparams%c6coeff(8)=11.8007_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0388_GP
          vdwparams%radzero(1)=2.9406_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.4751_GP
          vdwparams%radzero(7)=3.6097_GP
          vdwparams%radzero(8)=3.7393_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=4.8007_GP



       case(3) rpbedamp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0033_GP
          vdwparams%c6coeff(1)=3.0210_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.3845_GP
          vdwparams%c6coeff(7)=19.5208_GP
          vdwparams%c6coeff(8)=11.7723_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0437_GP
          vdwparams%radzero(1)=2.8667_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=2.9914_GP
          vdwparams%radzero(7)=3.2931_GP
          vdwparams%radzero(8)=3.6758_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=3.9912_GP

       end select rpbedamp

    case(14) 

       revpbedamp: select case (in%dispersion)

       case(1) revpbedamp
          vdwparams%dcoeff(1)=3.4962_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=3.2167_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.4616_GP
          vdwparams%c6coeff(7)=19.5760_GP
          vdwparams%c6coeff(8)=11.7927_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0475_GP
          vdwparams%radzero(1)=2.7985_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.0398_GP
          vdwparams%radzero(7)=3.2560_GP
          vdwparams%radzero(8)=3.6122_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=3.9811_GP


       case(2) revpbedamp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.8282_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=3.1160_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.4184_GP
          vdwparams%c6coeff(7)=19.5513_GP
          vdwparams%c6coeff(8)=11.7867_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0389_GP
          vdwparams%radzero(1)=2.9540_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.5630_GP
          vdwparams%radzero(7)=3.6696_GP
          vdwparams%radzero(8)=3.7581_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=4.7980_GP


       case(3) revpbedamp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0034_GP
          vdwparams%c6coeff(1)=3.0258_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.3854_GP
          vdwparams%c6coeff(7)=19.5210_GP
          vdwparams%c6coeff(8)=11.7724_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0435_GP
          vdwparams%radzero(1)=2.8623_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=2.9923_GP
          vdwparams%radzero(7)=3.2952_GP
          vdwparams%radzero(8)=3.6750_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=3.9910_GP


       end select revpbedamp

    case(200)  ! qoh: FIXME: with proper number for PW91

       pw91damp: select case (in%dispersion)

       case(1) pw91damp

          vdwparams%dcoeff(1)=3.2106_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=2.8701_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.3422_GP
          vdwparams%c6coeff(7)=19.5030_GP
          vdwparams%c6coeff(8)=11.7670_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0346_GP
          vdwparams%radzero(1)=3.0013_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.4423_GP
          vdwparams%radzero(7)=3.5445_GP
          vdwparams%radzero(8)=3.7444_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=5.4111_GP

       case(2) pw91damp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.3102_GP
          vdwparams%dcoeff(3)=23.0000_GP
          vdwparams%c6coeff(1)=2.5834_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.2743_GP
          vdwparams%c6coeff(7)=19.4633_GP
          vdwparams%c6coeff(8)=11.7472_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0233_GP
          vdwparams%radzero(1)=3.0759_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.9644_GP
          vdwparams%radzero(7)=3.8390_GP
          vdwparams%radzero(8)=3.8330_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=5.6250_GP


       case(3) pw91damp

          vdwparams%dcoeff(1)=3.0000_GP
          vdwparams%dcoeff(2)=3.5400_GP
          vdwparams%dcoeff(3)=23.0004_GP
          vdwparams%c6coeff(1)=2.9252_GP
          vdwparams%c6coeff(2)=0.0000_GP
          vdwparams%c6coeff(3)=0.0000_GP
          vdwparams%c6coeff(4)=0.0000_GP
          vdwparams%c6coeff(5)=0.0000_GP
          vdwparams%c6coeff(6)=27.3608_GP
          vdwparams%c6coeff(7)=19.5150_GP
          vdwparams%c6coeff(8)=11.7706_GP
          vdwparams%c6coeff(9)=0.0000_GP
          vdwparams%c6coeff(10)=0.0000_GP
          vdwparams%c6coeff(11)=0.0000_GP
          vdwparams%c6coeff(12)=0.0000_GP
          vdwparams%c6coeff(13)=0.0000_GP
          vdwparams%c6coeff(14)=0.0000_GP
          vdwparams%c6coeff(15)=190.5033_GP
          vdwparams%c6coeff(16)=161.0381_GP
          vdwparams%radzero(1)=2.9543_GP
          vdwparams%radzero(2)=3.0000_GP
          vdwparams%radzero(3)=3.8000_GP
          vdwparams%radzero(4)=3.8000_GP
          vdwparams%radzero(5)=3.8000_GP
          vdwparams%radzero(6)=3.0785_GP
          vdwparams%radzero(7)=3.3119_GP
          vdwparams%radzero(8)=3.6858_GP
          vdwparams%radzero(9)=3.8000_GP
          vdwparams%radzero(10)=3.8000_GP
          vdwparams%radzero(11)=4.8000_GP
          vdwparams%radzero(12)=4.8000_GP
          vdwparams%radzero(13)=4.8000_GP
          vdwparams%radzero(14)=4.8000_GP
          vdwparams%radzero(15)=4.8000_GP
          vdwparams%radzero(16)=4.9014_GP

       end select pw91damp


    case default  

       ! qoh: The damping coefficient for the three damping functions          
       vdwparams%dcoeff(1)=3.0000_GP
       vdwparams%dcoeff(2)=3.5400_GP
       vdwparams%dcoeff(3)=23.0000_GP

       ! qoh:  Values from Wu and Yang in hartree/bohr ^ 6
       vdwparams%c6coeff(1)=2.8450_GP
       vdwparams%c6coeff(2)=0.0000_GP
       vdwparams%c6coeff(3)=0.0000_GP
       vdwparams%c6coeff(4)=0.0000_GP
       vdwparams%c6coeff(5)=0.0000_GP
       vdwparams%c6coeff(6)=27.3200_GP
       vdwparams%c6coeff(7)=19.4800_GP
       vdwparams%c6coeff(8)=11.7600_GP
       ! qoh: C6 from Halgren
       vdwparams%c6coeff(16)=161.0388_GP

       ! qoh: vdw radii from Elstner in Angstrom 
       vdwparams%radzero(1)=3.0000_GP
       vdwparams%radzero(2)=3.0000_GP
       vdwparams%radzero(3)=3.8000_GP
       vdwparams%radzero(4)=3.8000_GP
       vdwparams%radzero(5)=3.8000_GP
       vdwparams%radzero(6)=3.8000_GP
       vdwparams%radzero(7)=3.8000_GP
       vdwparams%radzero(8)=3.8000_GP
       vdwparams%radzero(16)=4.8000_GP

    end select

    ! qoh: Unoptimised parameters from Halgren
    vdwparams%c6coeff(9)=6.2413_GP
    vdwparams%c6coeff(15)=190.5033_GP
    vdwparams%c6coeff(17)=103.5612_GP
    vdwparams%c6coeff(35)=201.8972_GP  

    vdwparams%radzero(9)=3.09_GP 
    vdwparams%radzero(15)=4.8000_GP
    vdwparams%radzero(17)=4.09_GP     
    vdwparams%radzero(35)=4.33_GP   

    ! qoh: Array containing the Neff from Wu and Yang 
    vdwparams%neff(1)=0.5300_GP
    vdwparams%neff(2)=0.0000_GP
    vdwparams%neff(3)=0.0000_GP
    vdwparams%neff(4)=0.0000_GP
    vdwparams%neff(5)=0.0000_GP
    vdwparams%neff(6)=2.0200_GP
    vdwparams%neff(7)=2.5200_GP
    vdwparams%neff(8)=2.6500_GP
    ! qoh: Neff from Halgren
    vdwparams%neff(9)=3.48_GP
    vdwparams%neff(15)=4.5_GP
    vdwparams%neff(16)=4.8_GP
    vdwparams%neff(17)=5.10_GP
    vdwparams%neff(35)=6.00_GP

  end subroutine vdwcorrection_initializeparams

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine vdwcorrection_calculate_energy(dispersion_energy,rxyz,atoms,in,&
       iproc)

    !==================================================================!
    ! This subroutine calculates the dispersion correction to the      !
    ! total energy.                                                    !
    !------------------------------------------------------------------!
    ! Written by Quintin Hill in 2007, with some modifications in 2008 !
    ! Modified for BigDFT in March/April 2009 by Quintin Hill.         !
    !==================================================================!

    use module_types, only: input_variables, atoms_data

    implicit none

    ! Arguments
    type(atoms_data),                 intent(in) :: atoms
    real(gp), dimension(3,atoms%nat), intent(in) :: rxyz
    type(input_variables),            intent(in) :: in
    integer,                          intent(in) :: iproc
    real(kind=GP),                   intent(out) :: dispersion_energy

    ! Internal variables
    integer       :: atom1, atom2   ! atom counters for loops
    integer       :: nzatom1   ! Atomic number of atom 1
    integer       :: nzatom2   ! Atomic number of atom 2
    real(kind=GP) :: distance  ! Distance between pairs of atoms
    real(kind=GP) :: sqdist    ! Square distance between pairs of atoms
    real(kind=GP) :: c6coeff   ! The c6coefficient of the pair
    real(kind=GP) :: damping   ! The damping for the pair

    dispersion_energy = 0.0_GP

    if (in%dispersion /= 0) then 

       call vdwcorrection_initializeparams(in)

       ! qoh: Loop over all distinct pairs of atoms

       do atom1=1,atoms%nat
          do atom2=1,atom1-1

             nzatom1 = atoms%nzatom(atoms%iatype(atom1))
             nzatom2 = atoms%nzatom(atoms%iatype(atom2))

             ! qoh: Calculate c6 coefficient
             c6coeff = vdwcorrection_c6(nzatom1,nzatom2)

             ! qoh: Calculate distance between each pair of atoms
             sqdist=(rxyz(1,atom2) - rxyz(1,atom1))**2 &
                  + (rxyz(2,atom2) - rxyz(2,atom1))**2 &
                  + (rxyz(3,atom2) - rxyz(3,atom1))**2 
             distance = sqrt(sqdist)

             ! qoh : Get damping function
             damping = vdwcorrection_damping(nzatom1,nzatom2,distance,in)

             ! qoh: distance**6 = sqdist**3

             dispersion_energy = dispersion_energy &
                  - (c6coeff * damping / sqdist**3)

          enddo
       enddo

       if (iproc == 0) then
          call vdwcorrection_warnings(atoms,in) 
          write(*,'(1x,a, e12.5,1x,a)') &
               'Dispersion Correction Energy: ', dispersion_energy, 'Hartree'
       end if
    end if

  end subroutine vdwcorrection_calculate_energy

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine vdwcorrection_calculate_forces(vdw_forces,rxyz,atoms,in) 

    !==================================================================!
    ! This subroutine calculates the dispersion correction to the      !
    ! total energy.                                                    !
    !------------------------------------------------------------------!
    ! Written by Quintin Hill in 2007, with some modifications in 2008 !
    ! Modified for BigDFT in March/April 2009 by Quintin Hill.         !
    !==================================================================!

    use module_types, only: input_variables, atoms_data

    implicit none

    ! Arguments

    type(atoms_data),                 intent(in)  :: atoms
    real(GP), dimension(3,atoms%nat), intent(out) :: vdw_forces
    real(GP), dimension(3,atoms%nat), intent(in)  :: rxyz
    type(input_variables),            intent(in)  :: in

    ! Internal variables

    integer       :: atom1,atom2 ! atom counters for loops
    integer       :: nzatom1     ! Atomic number of atom 1
    integer       :: nzatom2     ! Atomic number of atom 2
    real(kind=GP) :: distance    ! Distance between pairs of atoms
    real(kind=GP) :: sqdist      ! Square distance between pairs of atoms
    real(kind=GP) :: c6coeff     ! The c6coefficient of the pair
    real(kind=GP) :: damping     ! The damping for the pair
    real(kind=GP) :: dampingdrv  ! The damping derivative for the pair
    real(kind=GP) :: drvcommon   ! The common part of the derivative

    vdw_forces = 0.0_GP

    if (in%dispersion /= 0) then 

       call vdwcorrection_initializeparams(in)

       ! qoh: Loop over all atoms

       do atom1=1,atoms%nat

          ! qoh: Loop over all other atoms

          do atom2=1,atoms%nat

             if ( atom2 .ne. atom1) then

                nzatom1 = atoms%nzatom(atoms%iatype(atom1))
                nzatom2 = atoms%nzatom(atoms%iatype(atom2))

                ! qoh: Calculate c6 coefficient
                c6coeff = vdwcorrection_c6(nzatom1,nzatom2)

                ! qoh: Calculate distance between each pair of atoms
                sqdist=(rxyz(1,atom2) - rxyz(1,atom1))**2 &
                     + (rxyz(2,atom2) - rxyz(2,atom1))**2 &
                     + (rxyz(3,atom2) - rxyz(3,atom1))**2 
                distance = sqrt(sqdist)

                ! qoh : Get damping function
                damping = vdwcorrection_damping(nzatom1,nzatom2,distance,in)

                dampingdrv = &
                     vdwcorrection_drvdamping(nzatom1,nzatom2,distance,in)

                ! qoh: distance**6 = sqdist**3

                drvcommon = (c6coeff/sqdist**3)*&
                     (dampingdrv-6.0_GP*damping/sqdist)

                ! cks: this is the *negative* of the derivative of the
                ! cks: dispersion energy w.r.t. atomic coordinates
                vdw_forces(:,atom1) = vdw_forces(:,atom1) +drvcommon*&
                     (rxyz(:,atom1) - rxyz(:,atom2))

             end if

          enddo
       enddo
    end if


  end subroutine vdwcorrection_calculate_forces

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  subroutine vdwcorrection_warnings(atoms,in)

    !==================================================================!
    ! This subroutine warns about the use of unoptimised or unavailable!
    ! dispersion parameters.                                           !
    !------------------------------------------------------------------!
    ! Written by Quintin Hill on 13/02/2009.                           !
    ! Quintin Hill added functional check on 23/02/2009.               !
    !==================================================================!

    use module_types, only: input_variables, atoms_data

    implicit none

    type(atoms_data),        intent(in) :: atoms
    type(input_variables),   intent(in) :: in

    logical, save      :: already_warned = .false.
    integer            :: itype ! Type counter
    ! qoh: Atomic numbers of elements with unoptimised dispersion parameters:
    integer, parameter :: unoptimised(4) = (/9,15,17,35/)
    ! qoh: Atomic numbers of elements with optimised dispersion parameters:
    integer, parameter :: optimised(5) = (/1,6,7,8,16/)
    ! qoh: XC functionals with optimised parameters:
    integer, parameter :: xcfoptimised(4) = (/11,14,15,200/)

    if ( already_warned ) return

    ! qoh: Loop over types to check we have parameters
    do itype=1,atoms%ntypes
       if (any(unoptimised == atoms%nzatom(itype)) .and. &
            any(xcfoptimised == in%ixc)) then 
          write(*,'(a,a2)') 'WARNING: Unoptimised dispersion &
               &parameters used for ', atoms%atomnames(itype)
       elseif (.not. any(optimised == atoms%nzatom(itype)) .and. &
            .not. any(unoptimised == atoms%nzatom(itype))) then
          write(*,'(a,a2)') 'WARNING: No dispersion parameters &
               &available for ', atoms%atomnames(itype) 
       end if
    end do

    if (.not. any(xcfoptimised == in%ixc)) &
         write(*,'(a,i2)') 'WARNING: No optimised dispersion parameters &
         &available for ixc=', in%ixc

    already_warned = .true.

  end subroutine vdwcorrection_warnings

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function vdwcorrection_c6(nzatom1,nzatom2)

    !==================================================================!
    ! This function calculates a heteroatomic C_6 coefficient from     !
    ! homoatomic C_6 coefficients using the formula given in Elstner's !
    ! paper (J. Chem. Phys. 114(12), 5149–5155). (Corrected error in   !
    ! the formula appearing in this paper.)                            !
    !------------------------------------------------------------------!
    ! Written by Quintin Hill in 2007, with some modifications in 2008 !
    !==================================================================!

    implicit none

    real(kind=GP):: vdwcorrection_c6
    integer, intent(in) :: nzatom1 ! Atomic number of atom 1
    integer, intent(in) :: nzatom2 ! Atomic number of atom 2
    real(kind=GP) :: c61 ! c6 coefficient of atom 1
    real(kind=GP) :: c62 ! c6 coefficient of atom 2
    real(kind=GP) :: ne1 ! Effective number of electrons for atom 1
    real(kind=GP) :: ne2 ! Effective number of electrons for atom 2
    real(kind=GP), parameter :: third = 1.0_GP/3.0_GP

    ! qoh: Set up shorthands

    c61 = vdwparams%c6coeff(nzatom1)
    c62 = vdwparams%c6coeff(nzatom2)    
    ne1 = vdwparams%neff(nzatom1)
    ne2 = vdwparams%neff(nzatom2)

    if (c61 .lt. epsilon(1.0_GP) .or. c62 .lt.epsilon(1.0_GP) .or. &
         ne1 .lt. epsilon(1.0_GP) .or. ne2 .lt. epsilon(1.0_GP)) then
       vdwcorrection_c6=0.0_GP
    else
       vdwcorrection_c6 = 2.0_GP * (c61**2 * c62**2 * ne1 * ne2)**(third)/&
            (((c61 * ne2**2)**(third)) + ((c62* ne1**2)**(third)))
    end if

  end function vdwcorrection_c6

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function vdwcorrection_damping(nzatom1,nzatom2,separation,in)

    !==================================================================!
    ! This function calculates the damping function specified by       !
    ! in%dispersion:                                                   !
    ! (1) Damping funtion from Elstner                                 !
    !     (J. Chem. Phys. 114(12), 5149-5155).                         !
    ! (2) First damping function from Wu and Yang (I)                  !
    !     (J. Chem. Phys. 116(2), 515-524).                            !
    ! (3) Second damping function from Wu and Yang (II)                !
    !     (J. Chem. Phys. 116(2), 515–524).                            !
    !------------------------------------------------------------------!
    ! Written by Quintin Hill in 2007, with some modifications in 2008 !
    ! Merged into a single function in July 2008                       !
    !==================================================================!

    use module_types, only: input_variables
    implicit none

    real(kind=GP)             :: vdwcorrection_damping
    integer, intent(in)       :: nzatom1 ! Atomic number of atom 1
    integer, intent(in)       :: nzatom2 ! Atomic number of atom 2
    real(kind=GP), intent(in) :: separation
    type(input_variables), intent(in) :: in
    real(kind=GP)             :: radzero
    real(kind=GP)             :: expo ! Exponent
    integer, parameter        :: mexpo(2) = (/4,2/)
    integer, parameter        :: nexpo(2) = (/7,3/)
    integer                   :: mexp
    integer                   :: nexp    

    radzero = vdwcorrection_radzero(nzatom1,nzatom2)

    select case (in%dispersion)
    case(1,2)

       mexp = mexpo(in%dispersion)
       nexp = nexpo(in%dispersion) 

       expo = -vdwparams%dcoeff(in%dispersion)*(separation/radzero)**nexp
       vdwcorrection_damping = ( 1.0_GP - exp(expo))**mexp

    case(3)

       expo = -vdwparams%dcoeff(3)*((separation/radzero)-1.0_GP) 
       vdwcorrection_damping = 1.0_GP/( 1.0_GP + exp(expo))

    case default
       vdwcorrection_damping = 1.0_GP
    end select

  end function vdwcorrection_damping


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function vdwcorrection_drvdamping(nzatom1,nzatom2,separation,in)

    !==================================================================!
    ! This function calculates the derivative with respect to atomic   !
    !cooridinates of the damping function specified by in%dispersion:  !  
    ! (1) Damping funtion from Elstner                                 !
    !     (J. Chem. Phys. 114(12), 5149-5155).                         !
    ! (2) First damping function from Wu and Yang (I)                  !
    !     (J. Chem. Phys. 116(2), 515-524).                            !
    ! (3) Second damping function from Wu and Yang (II)                !
    !     (J. Chem. Phys. 116(2), 515–524).                            !
    ! Note: For simplicity the (r_{A,i}-r_{B_i}) (where i is x,y or z) !
    !       term is omitted here and included in the calling routine.  ! 
    !------------------------------------------------------------------!
    ! Written by Quintin Hill in July 2008.                            !
    !==================================================================!

    use module_types, only: input_variables

    implicit none

    real(kind=GP)                     :: vdwcorrection_drvdamping
    integer,               intent(in) :: nzatom1 ! Atomic number of atom 1
    integer,               intent(in) :: nzatom2 ! Atomic number of atom 2
    real(kind=GP),         intent(in) :: separation
    type(input_variables), intent(in) :: in
    real(kind=GP)                     :: radzero
    real(kind=GP)                     :: expo ! Exponent
    integer, parameter                :: mexpo(2) = (/4,2/)
    integer, parameter                :: nexpo(2) = (/7,3/)
    integer                           :: mexp
    integer                           :: nexp    

    radzero = vdwcorrection_radzero(nzatom1,nzatom2)

    select case (in%dispersion)
    case(1,2)

       mexp = mexpo(in%dispersion)
       nexp = nexpo(in%dispersion)   

       expo = -vdwparams%dcoeff(in%dispersion)*(separation/radzero)**nexp

       vdwcorrection_drvdamping = real((mexp*nexp),kind=GP)*exp(expo)* &
            vdwparams%dcoeff(in%dispersion)*( 1.0_GP - exp(expo))**(mexp-1)*&
            separation**(nexp-2)/radzero**nexp

    case(3)

       expo = -vdwparams%dcoeff(3)*((separation/radzero)-1.0_GP)

       vdwcorrection_drvdamping = vdwparams%dcoeff(3)*exp(expo)/&
            (separation*radzero*( 1.0_GP + exp(expo))**2)

    case default
       vdwcorrection_drvdamping = 0.0_GP
    end select

  end function vdwcorrection_drvdamping

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  function vdwcorrection_radzero(nzatom1,nzatom2)

    !==================================================================!
    ! Function to calculate the R_0 for an atom pair. Uses expression  !
    ! found in Elstner's paper (J. Chem. Phys. 114(12), 5149–5155).    !
    !------------------------------------------------------------------!
    ! Written by Quintin Hill in 2007, with some modifications in 2008 !
    !==================================================================!

    implicit none
    real(kind=GP) :: vdwcorrection_radzero
    integer, intent(in) :: nzatom1 ! Atomic number of atom 1
    integer, intent(in) :: nzatom2 ! Atomic number of atom 2
    REAL(kind=GP), PARAMETER :: ANGSTROM=1.889726313_GP   

    vdwcorrection_radzero = ANGSTROM*(vdwparams%radzero(nzatom1)**3 + &
         vdwparams%radzero(nzatom2)**3)/&
         (vdwparams%radzero(nzatom1)**2 + vdwparams%radzero(nzatom2)**2)

  end function vdwcorrection_radzero

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

end module vdwcorrection
