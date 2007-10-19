subroutine comb_shrink(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,w1,w2,y,&
     ibxy_c,ibzzx_c,ibyyzz_c,ibxy_f,ibzzx_f,ibyyzz_f,xc,xf,ibyz_c,ibyz_f)
  ! In 3d,			
  ! Applies the magic filter transposed, then analysis wavelet transformation.
  ! The size of the data is forced to shrink
  ! The input array y is not overwritten

  implicit none
  integer n1,n2,n3,i1,i2,i3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3
  real*8 y( -14:2*n1+16,-14:2*n2+16,-14:2*n3+16) ! input
  !    real*8 w1( 2,           -14:2*n2+16,-14:2*n3+16,0:n1)!  work 
  !	real*8 w2( 4,                       -14:2*n3+16,0:n1,0:n2)
  real*8 w1(max(2*(2*(nfu2-nfl2)+31)*(2*(nfu3-nfl3)+31)*(nfu1-nfl1+1),&
       (2*n2+31)*(2*n3+31)*(n1+1)))
  real*8 w2( max(4*(2*(nfu3-nfl3)+31)*(nfu1-nfl1+1)*(nfu2-nfl2+1),&
       (2*n3+31)*(n1+1)*(n2+1)))

  real*8 xf(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3),xc(0:n1,0:n2,0:n3)! work arrays

  !	boundary arrays
  integer ibxy_c(2,0:n1,0:n2) 
  integer ibzzx_c(2,-14:2*n3+16,0:n1) 
  integer ibyyzz_c(2,-14:2*n2+16,-14:2*n3+16)

  integer ibxy_f(2,nfl1:nfu1,nfl2:nfu2)
  integer ibzzx_f(2,-14+2*nfl3:2*nfu3+16,nfl1:nfu1)
  integer ibyyzz_f(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16)

  integer,dimension(2,0:n2,0:n3)::ibyz_c,ibyz_f

  !	perform the combined transform	
  call comb_shrink_loc_c(0,n1,0,n2,0,n3,w1,w2,y,xc,1,1,1,&
       ibxy_c,ibzzx_c,ibyyzz_c) ! for scfunctions
  !	for wavelets:

  call comb_shrink_loc_f(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,w1,w2,y,xf,&
       ibxy_f,ibzzx_f,ibyyzz_f)

end subroutine comb_shrink


subroutine comb_shrink_loc_f(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,w1,w2,y,x,&
     ibxy,ibzzx,ibyyzz)
  ! In 3d,			
  ! Applies the magic filter transposed, then analysis wavelet transformation.
  ! The output is only the l1,l2,l3 wavelet component
  ! The size of the data is forced to shrink
  ! The input array y is not overwritten
  implicit real*8 (a-h,o-z)
  real*8 y(-14:2*n1+16,-14:2*n2+16,         -14:2*n3+16) ! input
  real*8 w1(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16,nfl1:nfu1)!work
  real*8 w2(4,-14+2*nfl3:2*nfu3+16,nfl1:nfu1,nfl2:nfu2)
  real*8 x(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3)!output

  integer ibxy(2,nfl1:nfu1,nfl2:nfu2)
  integer ibzzx(2,-14+2*nfl3:2*nfu3+16,nfl1:nfu1)
  integer ibyyzz(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16)

  m1=nfu1-nfl1
  m2=nfu2-nfl2
  m3=nfu3-nfl3

  ! I1,I2,I3 -> I2,I3,i1
  call comb_rot_shrink_loc_1(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,y,w1,ibyyzz)

  ! I2,I3,i1 -> I3,i1,i2
  nt=(2*m3+31)*(m1+1)
  call comb_rot_shrink_loc_2(nt,w1,w2,nfl2,nfu2,ibzzx)

  ! I3,i1,i2 -> i1,i2,i3
  nt=(m1+1)*(m2+1)
  call comb_rot_shrink_loc_3(nt,w2,x,nfl3,nfu3,ibxy)
  return
END SUBROUTINE comb_shrink_loc_f



subroutine comb_shrink_loc_c(nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,w1,w2,y,x,l1,l2,l3,&
     ibxy,ibzzx,ibyyzz)
  ! In 3d,			
  ! Applies the magic filter transposed, then analysis wavelet transformation.
  ! The output is only the l1,l2,l3 wavelet component
  ! The size of the data is forced to shrink
  ! The input array y is not overwritten
  implicit real*8 (a-h,o-z)
  real*8 y(-14+2*nfl1:2*nfu1+16,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16)!input
  real*8 w1(-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16,nfl1:nfu1)!work
  real*8 w2(-14+2*nfl3:2*nfu3+16,nfl1:nfu1,nfl2:nfu2)
  real*8 x(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3)!output

  integer ibxy(2,nfl1:nfu1,nfl2:nfu2)
  integer ibzzx(2,-14+2*nfl3:2*nfu3+16,nfl1:nfu1)
  integer ibyyzz(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16)

  m1=nfu1-nfl1
  m2=nfu2-nfl2
  m3=nfu3-nfl3

  ! I1,I2,I3 -> I2,I3,i1
  nt=(2*m2+31)*(2*m3+31)
  call comb_rot_shrink_loc(nt,y,w1,l1,nfl1,nfu1,ibyyzz)

  ! I2,I3,i1 -> I3,i1,i2
  nt=(2*m3+31)*(m1+1)
  call comb_rot_shrink_loc(nt,w1,w2,l2,nfl2,nfu2,ibzzx)

  ! I3,i1,i2 -> i1,i2,i3
  nt=(m1+1)*(m2+1)
  call comb_rot_shrink_loc(nt,w2,x,l3,nfl3,nfu3,ibxy)

  return
END SUBROUTINE comb_shrink_loc_c

subroutine comb_rot_shrink_loc(ndat,x,y,icf,nfl,nfu,ib)
! In one dimension,	
! Applies the magic filter transposed, then analysis wavelet transformation.
! The size of the data is forced to shrink
	implicit real*8 (a-h,o-z)
	integer,parameter:: lowfil2=-14,lupfil2=16
	dimension x(lowfil2+2*nfl:2*nfu+lupfil2,ndat),y(ndat,nfl:nfu)
	integer ib(2,ndat)
	include 'v.f90'

	open(unit=10,file='simple_shrink.flop')
	nflop=0
	! count the flops:
	do j=1,ndat
		   do i=ib(1,j),ib(2,j)
		     do l=lowfil2+2*i,lupfil2+2*i
				nflop=nflop+2
		     enddo
		   enddo
	enddo

	! the convolution itself:
    call system_clock(ncount0,ncount_rate,ncount_max)
	do j=1,ndat
	   do i=ib(1,j),ib(2,j)
	     ci=0.d0
	     do l=lowfil2+2*i,lupfil2+2*i
	       ci=ci+fil2(l-2*i,icf)*x(l,j)
	     enddo
	     y(j,i)=ci
	   enddo
	enddo
	   
    call system_clock(ncount1,ncount_rate,ncount_max)
    tel=dble(ncount1-ncount0)/dble(ncount_rate)

	write(10,*) tel, 1.d-6*nflop/tel
end

subroutine comb_rot_shrink_loc_1(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,x,y,ib)
! In one dimension,	
! Applies the magic filter transposed, then analysis wavelet transformation.
! The size of the data is forced to shrink
	implicit real*8 (a-h,o-z)
	integer,parameter:: lowfil2=-14,lupfil2=16
	real*8 x(-14:2*n1+16,-14:2*n2+16,         -14:2*n3+16) ! input
    real*8 y(2,     -14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16,nfl1:nfu1)! output
	integer ib(2, -14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16)
	include 'v.f90'

	nflop=0
	open(unit=20,file='tree_shrink.flop')
    call system_clock(ncount0,ncount_rate,ncount_max)

	do j2=-14+2*nfl2,2*nfu2+16
		do j3=-14+2*nfl3,2*nfu3+16
		   do i=ib(1,j2,j3),ib(2,j2,j3)
		     ci1=0.d0
		     ci2=0.d0
			 nflop=nflop+(lupfil2-lowfil2+1)*2*2
		     do l=lowfil2+2*i,lupfil2+2*i
		       ci1=ci1+fil2(l-2*i,1)*x(l,j2,j3)
		       ci2=ci2+fil2(l-2*i,2)*x(l,j2,j3)
		     enddo
		     y(1,j2,j3,i)=ci1
		     y(2,j2,j3,i)=ci2
		   enddo
	    enddo
	enddo

    call system_clock(ncount1,ncount_rate,ncount_max)
    tel=dble(ncount1-ncount0)/dble(ncount_rate)
	write(20,*) tel, 1.d-6*nflop/tel

end


subroutine comb_rot_shrink_loc_2(ndat,x,y,nfl,nfu,ib)
! In one dimension,	
! Applies the magic filter transposed, then analysis wavelet transformation.
! The size of the data is forced to shrink
	implicit real*8 (a-h,o-z)
	integer,parameter:: lowfil2=-14,lupfil2=16
	dimension x(2,lowfil2+2*nfl:2*nfu+lupfil2,ndat),y(2,2,ndat,nfl:nfu)
	integer ib(2,ndat)
	include 'v.f90'

	nflop=0
	open(unit=20,file='tree_shrink.flop')
    call system_clock(ncount0,ncount_rate,ncount_max)

	do j=1,ndat
	   do i=ib(1,j),ib(2,j)
		 ci11=0.d0
		 ci12=0.d0
		 ci21=0.d0
		 ci22=0.d0

		 nflop=nflop+(lupfil2-lowfil2+1)*2*4
	     do l=lowfil2+2*i,lupfil2+2*i
		   ci11=ci11+fil2(l-2*i,1)*x(1,l,j)
		   ci12=ci12+fil2(l-2*i,2)*x(1,l,j)
		   ci21=ci21+fil2(l-2*i,1)*x(2,l,j)
		   ci22=ci22+fil2(l-2*i,2)*x(2,l,j)
	     enddo
		 y(1,1,j,i)=ci11
		 y(1,2,j,i)=ci12
		 y(2,1,j,i)=ci21
		 y(2,2,j,i)=ci22
	   enddo
	enddo

    call system_clock(ncount1,ncount_rate,ncount_max)
    tel=dble(ncount1-ncount0)/dble(ncount_rate)
	write(20,*) tel, 1.d-6*nflop/tel
	   
end



subroutine comb_rot_shrink_loc_3(ndat,x,y,nfl,nfu,ib)
! In one dimension,	
! Applies the magic filter transposed, then analysis wavelet transformation.
! The size of the data is forced to shrink
	implicit real*8 (a-h,o-z)
	integer,parameter:: lowfil2=-14,lupfil2=16
	dimension x(2,2,lowfil2+2*nfl:2*nfu+lupfil2,ndat),y(7,ndat,nfl:nfu)
	integer ib(2,ndat)
	include 'v.f90'

	nflop=0
	open(unit=20,file='tree_shrink.flop')
    call system_clock(ncount0,ncount_rate,ncount_max)

	do j=1,ndat
	   do i=ib(1,j),ib(2,j)
		 ci112=0.d0
		 ci121=0.d0
		 ci122=0.d0
		 ci211=0.d0
		 ci212=0.d0
		 ci221=0.d0
		 ci222=0.d0

		 nflop=nflop+(lupfil2-lowfil2+1)*2*7
	     do l=lowfil2+2*i,lupfil2+2*i
		     ci112=ci112+fil2(l-2*i,2)*x(1,1,l,j)
		     ci121=ci121+fil2(l-2*i,1)*x(1,2,l,j)
		     ci122=ci122+fil2(l-2*i,2)*x(1,2,l,j)
		     ci211=ci211+fil2(l-2*i,1)*x(2,1,l,j)
		     ci212=ci212+fil2(l-2*i,2)*x(2,1,l,j)
		     ci221=ci221+fil2(l-2*i,1)*x(2,2,l,j)
		     ci222=ci222+fil2(l-2*i,2)*x(2,2,l,j)
	     enddo
        	y(1,j,i)=ci211
    		y(2,j,i)=ci121	
    		y(3,j,i)=ci221	
    		y(4,j,i)=ci112	
    		y(5,j,i)=ci212	
    		y(6,j,i)=ci122	
    		y(7,j,i)=ci222	
	   enddo
	enddo

    call system_clock(ncount1,ncount_rate,ncount_max)
    tel=dble(ncount1-ncount0)/dble(ncount_rate)
	write(20,*) tel, 1.d-6*nflop/tel
	   
end




