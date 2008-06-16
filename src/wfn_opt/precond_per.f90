subroutine precong_per(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     ncong,cprecr,hx,hy,hz,x)
  use module_base
  ! Solves (KE+cprecr*I)*xx=yy by conjugate gradient method
  ! x is the right hand side on input and the solution on output
  implicit none
  integer, intent(in) :: n1,n2,n3,ncong
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz
  real(wp), intent(in) :: cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(inout) ::  x(nvctr_c+7*nvctr_f)
  ! local variables
  real*8::scal(0:8)
  real*8::rmr,rmr_new,alpha,beta
  integer i,i_stat,i_all
  real(kind=8),allocatable::b(:),r(:),d(:)
  real*8,allocatable::psifscf(:),ww(:)

  call allocate_all

  !	initializes the wavelet scaling coefficients	
  call wscal_init_per(scal,hx,hy,hz,cprecr)
  b=x

  !	compute the input guess x via a Fourier transform in a cubic box.
  !	Arrays psifscf and ww serve as work arrays for the Fourier
  call prec_fft_fast(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
       cprecr,hx,hy,hz,x,&
       psifscf(1),psifscf(n1+2),psifscf(n1+n2+3),ww(1),ww(4*(n1+2)*(n2+2)*(n3+2)+1))

  call apply_hp(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
       cprecr,hx,hy,hz,x,d,psifscf,ww) ! d:=Ax
  r=b-d

  call wscal_per(nvctr_c,nvctr_f,scal,r(1),r(nvctr_c+1),d(1),d(nvctr_c+1))
  rmr=dot_product(r,d)
  do i=1,ncong 
     !		write(*,*)i,sqrt(rmr)

     call apply_hp(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
          cprecr,hx,hy,hz,d,b,psifscf,ww) ! b:=Ad

     alpha=rmr/dot_product(d,b)
     x=x+alpha*d
     r=r-alpha*b

     call wscal_per(nvctr_c,nvctr_f,scal,r(1),r(nvctr_c+1),b(1),b(nvctr_c+1))
     rmr_new=dot_product(r,b)

     beta=rmr_new/rmr
     d=b+beta*d
     rmr=rmr_new
  enddo

  call deallocate_all

contains

  subroutine allocate_all
    allocate(b(nvctr_c+7*nvctr_f),stat=i_stat)
    call memocc(i_stat,product(shape(b))*kind(b),'b','precong_per')
    allocate(r(nvctr_c+7*nvctr_f),stat=i_stat)
    call memocc(i_stat,product(shape(r))*kind(r),'r','precong_per')
    allocate(d(nvctr_c+7*nvctr_f),stat=i_stat)
    call memocc(i_stat,product(shape(d))*kind(d),'','precong_per')
    allocate( psifscf((2*n1+2)*(2*n2+2)*(2*n3+2)),stat=i_stat )
    call memocc(i_stat,product(shape(psifscf))*kind(psifscf),'psifscf','precong_per')
    allocate( ww((2*n1+2)*(2*n2+2)*(2*n3+2)) ,stat=i_stat)
    call memocc(i_stat,product(shape(ww))*kind(ww),'ww','precong_per')
  end subroutine allocate_all

  subroutine deallocate_all
    i_all=-product(shape(psifscf))*kind(psifscf)
    deallocate(psifscf,stat=i_stat)
    call memocc(i_stat,i_all,'psifscf','last_orthon')

    i_all=-product(shape(ww))*kind(ww)
    deallocate(ww,stat=i_stat)
    call memocc(i_stat,i_all,'ww','last_orthon')

    i_all=-product(shape(b))*kind(b)
    deallocate(b,stat=i_stat)
    call memocc(i_stat,i_all,'b','last_orthon')

    i_all=-product(shape(r))*kind(r)
    deallocate(r,stat=i_stat)
    call memocc(i_stat,i_all,'r','last_orthon')

    i_all=-product(shape(d))*kind(d)
    deallocate(d,stat=i_stat)
    call memocc(i_stat,i_all,'d','last_orthon')
  end subroutine deallocate_all
end subroutine precong_per


subroutine prec_fft_fast(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,hpsi,&
     kern_k1,kern_k2,kern_k3,z,x_c)
  ! Solves (KE+cprecr*I)*xx=yy by FFT in a cubic box 
  ! x_c is the right hand side on input and the solution on output
  ! This version uses work arrays kern_k1-kern_k3 and z allocated elsewhere
  implicit none 
  integer, intent(in) :: n1,n2,n3
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(kind=8), intent(in) :: hx,hy,hz,cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(kind=8), intent(inout) ::  hpsi(nvctr_c+7*nvctr_f) 

  !work arrays
  real(kind=8):: kern_k1(0:n1),kern_k2(0:n2),kern_k3(0:n3)
  real(kind=8),dimension(0:n1,0:n2,0:n3):: x_c! in and out of Fourier preconditioning
  real(kind=8)::z(2,n1+2,n2+2,n3+2,2) ! work array for FFT

  call wscal_f(nvctr_f,hpsi(nvctr_c+1),hx,hy,hz,cprecr)

  call make_kernel(n1,hx,kern_k1)
  call make_kernel(n2,hy,kern_k2)
  call make_kernel(n3,hz,kern_k3)

  call uncompress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

  call  hit_with_kernel(x_c,z,kern_k1,kern_k2,kern_k3,n1,n2,n3,n1+2,n2+2,n3+2,cprecr)

  call   compress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

end subroutine prec_fft_fast

subroutine prec_fft(n1,n2,n3, &
     nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,hpsi)
  ! Solves (KE+cprecr*I)*xx=yy by conjugate gradient method
  ! hpsi is the right hand side on input and the solution on output
  use module_base
  implicit none 
  integer, intent(in) :: n1,n2,n3
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(kind=8), intent(in) :: hx,hy,hz,cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(kind=8), intent(inout) ::  hpsi(nvctr_c+7*nvctr_f)
  !local variables
  integer nd1,nd2,nd3,i_stat,i_all
  real(kind=8), dimension(:), allocatable :: kern_k1,kern_k2,kern_k3
  real(kind=8), dimension(:,:,:), allocatable :: x_c! in and out of Fourier preconditioning
  real(kind=8), dimension(:,:,:,:,:), allocatable::z(:,:,:,:,:) ! work array for FFT
  nd1=n1+2;		nd2=n2+2;	nd3=n3+2

  call allocate_all

  ! diagonally precondition the wavelet part  
  call wscal_f(nvctr_f,hpsi(nvctr_c+1),hx,hy,hz,cprecr)

  call make_kernel(n1,hx,kern_k1)
  call make_kernel(n2,hy,kern_k2)
  call make_kernel(n3,hz,kern_k3)

  call uncompress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

  !	solve the helmholtz equation for the scfunction part  
  call  hit_with_kernel(x_c,z,kern_k1,kern_k2,kern_k3,n1,n2,n3,nd1,nd2,nd3,cprecr)

  call   compress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

  call deallocate_all

contains
  subroutine allocate_all
    allocate(kern_k1(0:n1),stat=i_stat)
    call memocc(i_stat,product(shape(kern_k1))*kind(kern_k1),'kern_k1','prec_fft')
    allocate(kern_k2(0:n2),stat=i_stat)
    call memocc(i_stat,product(shape(kern_k2))*kind(kern_k2),'kern_k2','prec_fft')
    allocate(kern_k3(0:n3),stat=i_stat)
    call memocc(i_stat,product(shape(kern_k3))*kind(kern_k3),'kern_k3','prec_fft')
    allocate(z(2,nd1,nd2,nd3,2),stat=i_stat) ! work array for fft
    call memocc(i_stat,product(shape(z))*kind(z),'z','prec_fft')
    allocate(x_c(0:n1,0:n2,0:n3),stat=i_stat)
    call memocc(i_stat,product(shape(x_c))*kind(x_c),'x_c','prec_fft')
  end subroutine allocate_all
  subroutine deallocate_all
    i_all=-product(shape(z))*kind(z)
    deallocate(z,stat=i_stat)
    call memocc(i_stat,i_all,'z','last_orthon')

    i_all=-product(shape(kern_k1))*kind(kern_k1)
    deallocate(kern_k1,stat=i_stat)
    call memocc(i_stat,i_all,'kern_k1','last_orthon')

    i_all=-product(shape(kern_k2))*kind(kern_k2)
    deallocate(kern_k2,stat=i_stat)
    call memocc(i_stat,i_all,'kern_k2','last_orthon')

    i_all=-product(shape(kern_k3))*kind(kern_k3)
    deallocate(kern_k3,stat=i_stat)
    call memocc(i_stat,i_all,'kern_k3','last_orthon')

    i_all=-product(shape(x_c))*kind(x_c)
    deallocate(x_c,stat=i_stat)
    call memocc(i_stat,i_all,'x_c','last_orthon')

  end subroutine deallocate_all
end subroutine prec_fft


subroutine apply_hp(n1,n2,n3, &
     nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,x,y,psifscf,ww)
  !	Applies the operator (KE+cprecr*I)*x=y
  !	array x is input, array y is output
  implicit none
  integer, intent(in) :: n1,n2,n3
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(kind=8), intent(in) :: hx,hy,hz,cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(kind=8), intent(in) ::  x(nvctr_c+7*nvctr_f)  
  real(kind=8), intent(out) ::  y(nvctr_c+7*nvctr_f)

  real*8 hgridh(3)	
  real*8,dimension((2*n1+2)*(2*n2+2)*(2*n3+2))::ww,psifscf
  call uncompress_per(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   &
       nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   &
       x(1),x(nvctr_c+1),psifscf,ww)

  hgridh(1)=hx*.5d0
  hgridh(2)=hy*.5d0
  hgridh(3)=hz*.5d0
  call convolut_kinetic_per_c(2*n1+1,2*n2+1,2*n3+1,hgridh,psifscf,ww,cprecr)

  call compress_per(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   & 
       nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   & 
       ww,y(1),y(nvctr_c+1),psifscf)
end subroutine apply_hp

subroutine uncompress_c(hpsi,x_c,keyg_c,keyv_c,nseg_c,nvctr_c,n1,n2,n3)
  implicit none
  integer,intent(in)::n1,n2,n3
  integer,intent(in)::nseg_c,nvctr_c
  real*8,intent(in)::hpsi(nvctr_c)
  integer,intent(in)::keyg_c(2,nseg_c),keyv_c(nseg_c)

  real*8,intent(out)::x_c(0:n1,0:n2,0:n3)

  integer iseg,jj,j0,j1,ii,i3,i2,i0,i1,i

  x_c=0.d0
  do iseg=1,nseg_c
     jj=keyv_c(iseg)
     j0=keyg_c(1,iseg)
     j1=keyg_c(2,iseg)

     ii=j0-1
     i3=ii/((n1+1)*(n2+1))
     ii=ii-i3*(n1+1)*(n2+1)
     i2=ii/(n1+1)
     i0=ii-i2*(n1+1)
     i1=i0+j1-j0

     do i=i0,i1
        x_c(i,i2,i3)=hpsi(i-i0+jj)
     enddo
  enddo
end subroutine uncompress_c

subroutine compress_c(hpsi,y_c,keyg_c,keyv_c,nseg_c,nvctr_c,n1,n2,n3)
  implicit none
  integer,intent(in)::n1,n2,n3
  integer,intent(in)::nseg_c,nvctr_c
  integer,intent(in)::keyg_c(2,nseg_c),keyv_c(nseg_c)
  real*8,intent(in)::y_c(0:n1,0:n2,0:n3)

  real*8,intent(out)::hpsi(nvctr_c)

  integer iseg,jj,j0,j1,ii,i3,i2,i0,i1,i

  ! coarse part
  do iseg=1,nseg_c
     jj=keyv_c(iseg)
     j0=keyg_c(1,iseg)
     j1=keyg_c(2,iseg)
     ii=j0-1
     i3=ii/((n1+1)*(n2+1))
     ii=ii-i3*(n1+1)*(n2+1)
     i2=ii/(n1+1)
     i0=ii-i2*(n1+1)
     i1=i0+j1-j0
     do i=i0,i1
        hpsi(i-i0+jj)=y_c(i,i2,i3)
     enddo
  enddo

end subroutine compress_c


subroutine wscal_f(mvctr_f,psi_f,hx,hy,hz,c)
  ! multiplies a wavefunction psi_c,psi_f (in vector form) with a scaling vector (scal)
  implicit real(kind=8) (a-h,o-z)
  real*8,intent(in)::c,hx,hy,hz
  dimension psi_f(7,mvctr_f),scal(7),hh(3)
  !WAVELET AND SCALING FUNCTION SECOND DERIVATIVE FILTERS, diagonal elements
  PARAMETER(B2=24.8758460293923314D0,A2=3.55369228991319019D0)

  hh(1)=.5d0/hx**2
  hh(2)=.5d0/hy**2
  hh(3)=.5d0/hz**2

  scal(1)=1.d0/(b2*hh(1)+a2*hh(2)+a2*hh(3)+c)       !  2 1 1
  scal(2)=1.d0/(a2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  1 2 1
  scal(3)=1.d0/(b2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  2 2 1
  scal(4)=1.d0/(a2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  1 1 2
  scal(5)=1.d0/(b2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  2 1 2
  scal(6)=1.d0/(a2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  1 2 2
  scal(7)=1.d0/(b2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  2 2 2

  do i=1,mvctr_f
     psi_f(1,i)=psi_f(1,i)*scal(1)       !  2 1 1
     psi_f(2,i)=psi_f(2,i)*scal(2)       !  1 2 1
     psi_f(3,i)=psi_f(3,i)*scal(3)       !  2 2 1
     psi_f(4,i)=psi_f(4,i)*scal(4)       !  1 1 2
     psi_f(5,i)=psi_f(5,i)*scal(5)       !  2 1 2
     psi_f(6,i)=psi_f(6,i)*scal(6)       !  1 2 2
     psi_f(7,i)=psi_f(7,i)*scal(7)       !  2 2 2
  enddo

end subroutine wscal_f


subroutine wscal_per(mvctr_c,mvctr_f,scal,psi_c_in,psi_f_in,psi_c_out,psi_f_out)
  ! multiplies a wavefunction psi_c,psi_f (in vector form) with a scaling vector (scal)
  implicit real(kind=8) (a-h,o-z)
  real*8,intent(in)::psi_c_in(mvctr_c),psi_f_in(7,mvctr_f),scal(0:8)
  real*8,intent(out)::psi_c_out(mvctr_c),psi_f_out(7,mvctr_f)

  do i=1,mvctr_c
     psi_c_out(i)=psi_c_in(i)*scal(0)           !  1 1 1
  enddo

  do i=1,mvctr_f
     psi_f_out(1,i)=psi_f_in(1,i)*scal(1)       !  2 1 1
     psi_f_out(2,i)=psi_f_in(2,i)*scal(2)       !  1 2 1
     psi_f_out(3,i)=psi_f_in(3,i)*scal(3)       !  2 2 1
     psi_f_out(4,i)=psi_f_in(4,i)*scal(4)       !  1 1 2
     psi_f_out(5,i)=psi_f_in(5,i)*scal(5)       !  2 1 2
     psi_f_out(6,i)=psi_f_in(6,i)*scal(6)       !  1 2 2
     psi_f_out(7,i)=psi_f_in(7,i)*scal(7)       !  2 2 2
  enddo

end subroutine wscal_per


subroutine wscal_init_per(scal,hx,hy,hz,c)
  !	initialization for the array scal in the subroutine wscal_per 	
  implicit none
  real*8,intent(in)::c,hx,hy,hz
  real*8,PARAMETER::B2=24.8758460293923314D0,A2=3.55369228991319019D0
  real*8,intent(out)::scal(0:8)
  real*8::hh(3)

  hh(1)=.5d0/hx**2
  hh(2)=.5d0/hy**2
  hh(3)=.5d0/hz**2

  scal(0)=1.d0/(a2*hh(1)+a2*hh(2)+a2*hh(3)+c)       !  1 1 1
  scal(1)=1.d0/(b2*hh(1)+a2*hh(2)+a2*hh(3)+c)       !  2 1 1
  scal(2)=1.d0/(a2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  1 2 1
  scal(3)=1.d0/(b2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  2 2 1
  scal(4)=1.d0/(a2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  1 1 2
  scal(5)=1.d0/(b2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  2 1 2
  scal(6)=1.d0/(a2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  1 2 2
  scal(7)=1.d0/(b2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  2 2 2

end subroutine wscal_init_per


