!> @file
!! Include fortran file for f_malloc routines
!! @author
!!    Copyright (C) 2012-2013 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
     m%rank=size(shape(src))
     m%shape(1:m%rank)=shape(src)
     m%lbounds(1:m%rank)=lbound(src)
     m%ubounds(1:m%rank)=ubound(src)
     m%srcdata_add=f_loc(src)

