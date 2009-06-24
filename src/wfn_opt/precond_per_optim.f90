!routine used for the k-points, eventually to be used for all cases
subroutine precondition_residue(lr,ncplx,ncong,cprecr,&
     hx,hy,hz,kx,ky,kz,x)
  use module_base
  use module_types
  ! Solves (KE+cprecr*I)*xx=yy by conjugate gradient method
  ! x is the right hand side on input and the solution on output
  implicit none
  integer, intent(in) :: ncong,ncplx
  real(gp), intent(in) :: hx,hy,hz,cprecr,kx,ky,kz
  type(locreg_descriptors), intent(in) :: lr
  real(wp), dimension((lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)*ncplx), intent(inout) :: x
  ! local variables
  character(len=*), parameter :: subname='precondition_residue'
  real(gp), dimension(0:7) :: scal
  real(wp) :: rmr_old,rmr_new,alpha,beta
  integer :: i,i_stat,i_all,icong,idx
  type(workarr_precond) :: w
  real(wp), dimension(:), allocatable :: b,r,d

  !arrays for the CG procedure
  allocate(b(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)+ndebug),stat=i_stat)
  call memocc(i_stat,b,'b',subname)
  allocate(r(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)+ndebug),stat=i_stat)
  call memocc(i_stat,r,'r',subname)
  allocate(d(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f)+ndebug),stat=i_stat)
  call memocc(i_stat,d,'d',subname)

  call allocate_work_arrays(lr%geocode,lr%hybrid_on,ncplx,lr%d,w)

  call precondition_preconditioner(lr,ncplx,hx,hy,hz,scal,cprecr,w,x,b)

  call precond_locham(ncplx,lr,hx,hy,hz,kx,ky,kz,cprecr,x,d,w,scal)

!!$  rmr_new=dot(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),d(1),1,d(1),1)
!!$  write(*,*)'debug1',rmr_new

  r=b-d ! r=b-Ax

  call calculate_rmr_new(lr%geocode,lr%hybrid_on,ncplx,lr%wfd,scal,r,d,rmr_new)
  !stands for
  !d=r
  !rmr_new=dot_product(r,r)


  do icong=1,ncong 
     !write(*,*)icong,rmr_new

     call precond_locham(ncplx,lr,hx,hy,hz,kx,ky,kz,cprecr,d,b,w,scal)! b:=Ad

     !in the complex case these objects are to be supposed real
     alpha=rmr_new/dot(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),d(1),1,b(1),1)

     call axpy(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),alpha,d(1),1,x(1),1)
     call axpy(ncplx*(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f),-alpha,b(1),1,r(1),1)

     if (icong==ncong) exit

     rmr_old=rmr_new	

     call calculate_rmr_new(lr%geocode,lr%hybrid_on,ncplx,lr%wfd,scal,r,b,rmr_new)

     beta=rmr_new/rmr_old

     d=b+beta*d
    
  enddo

  call finalise_precond_residue(lr%geocode,lr%hybrid_on,ncplx,lr%wfd,scal,x)

  i_all=-product(shape(b))*kind(b)
  deallocate(b,stat=i_stat)
  call memocc(i_stat,i_all,'b',subname)
  i_all=-product(shape(r))*kind(r)
  deallocate(r,stat=i_stat)
  call memocc(i_stat,i_all,'r',subname)
  i_all=-product(shape(d))*kind(d)
  deallocate(d,stat=i_stat)
  call memocc(i_stat,i_all,'d',subname)

  call deallocate_work_arrays(lr%geocode,lr%hybrid_on,ncplx,w)

end subroutine precondition_residue

subroutine finalise_precond_residue(geocode,hybrid_on,ncplx,wfd,scal,x)
  use module_base
  use module_types
  implicit none
  character(len=1), intent(in) :: geocode
  logical, intent(in) :: hybrid_on
  integer, intent(in) :: ncplx
  type(wavefunctions_descriptors), intent(in) :: wfd
  real(gp), dimension(0:7), intent(in) :: scal
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,ncplx), intent(inout) :: x
  !local variables
  logical :: noscal
  integer :: idx

  if (geocode == 'F') then
     do idx=1,ncplx
        call wscalv(wfd%nvctr_c,wfd%nvctr_f,scal,x(1,idx),x(wfd%nvctr_c+1,idx))
     end do
  else if (geocode == 'P' .and. .not. hybrid_on) then
     do idx=1,ncplx
        ! x=D^{-1/2}x'
        call wscal_per_self(wfd%nvctr_c,wfd%nvctr_f,scal,x(1,idx),x(wfd%nvctr_c+1,idx))
        !	write(30,*) x
        !	stop
     end do
  else
  end if
end subroutine finalise_precond_residue


subroutine calculate_rmr_new(geocode,hybrid_on,ncplx,wfd,scal,r,b,rmr_new)
  use module_base
  use module_types
  implicit none
  character(len=1), intent(in) :: geocode
  logical, intent(in) :: hybrid_on
  integer, intent(in) :: ncplx
  type(wavefunctions_descriptors), intent(in) :: wfd
  real(gp), dimension(0:7), intent(in) :: scal
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,ncplx), intent(in) :: r
  real(wp), intent(out) :: rmr_new
  real(wp), dimension(wfd%nvctr_c+7*wfd%nvctr_f,ncplx), intent(out) :: b
  !local variables
  logical :: noscal
  integer :: idx

  noscal = ((geocode == 'P' .and. .not. hybrid_on) .or. geocode == 'F')

  if (noscal) then
     call dcopy(ncplx*(wfd%nvctr_c+7*wfd%nvctr_f),r(1,1),1,b(1,1),1) 
     rmr_new=dot(ncplx*(wfd%nvctr_c+7*wfd%nvctr_f),r(1,1),1,r(1,1),1)
  else 
     do idx=1,ncplx
        call wscal_per(wfd%nvctr_c,wfd%nvctr_f,scal,r(1,idx),&
             r(wfd%nvctr_c+1,idx),b(1,idx),b(wfd%nvctr_c+1,idx))
     end do
     rmr_new=dot(ncplx*(wfd%nvctr_c+7*wfd%nvctr_f),r(1,1),1,b(1,1),1)
  end if

end subroutine calculate_rmr_new


subroutine precondition_preconditioner(lr,ncplx,hx,hy,hz,scal,cprecr,w,x,b)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: ncplx
  real(gp), intent(in) :: hx,hy,hz,cprecr
  type(locreg_descriptors), intent(in) :: lr
  type(workarr_precond), intent(inout) :: w
  real(gp), dimension(0:7), intent(inout) :: scal
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,ncplx), intent(inout) ::  x
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,ncplx), intent(out) ::  b
  !local variables
  logical, parameter :: inguess_on=.true.
  !       wavelet and scaling function second derivative filters
  real(wp), parameter :: b2=24.8758460293923314_wp, a2=3.55369228991319019_wp
  integer :: nd1,nd2,nd3,idx,i
  integer :: n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b 
  real(gp) :: fac
  real(wp) :: fac_h,h0,h1,h2,h3,alpha1
  
  if (lr%geocode == 'F') then
     !using hx instead of hgrid for isolated bc
     fac_h=1.0_wp/real(hx,wp)**2
     h0=    1.5_wp*a2*fac_h
     h1=(a2+b2*.5_wp)*fac_h
     h2=(a2*.5_wp+b2)*fac_h
     h3=    1.5_wp*b2*fac_h

     scal(0)=sqrt(1.0_wp/(h0+cprecr)) 
     scal(1)=sqrt(1.0_wp/(h1+cprecr)) 
     scal(2)=sqrt(1.0_wp/(h2+cprecr)) 
     scal(3)=sqrt(1.0_wp/(h3+cprecr))

     do idx=1,ncplx
        if (inguess_on) then
           !the right hand side is temporarily stored in the rpsi array
           !rpsi=hpsi           
           call dcopy(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,x(1,idx),1,b(1,idx),1) 
           !          and preconditioned with d^{-1/2} as usual:
           call wscalv(lr%wfd%nvctr_c,lr%wfd%nvctr_f,scal,b(1,idx),&
                b(lr%wfd%nvctr_c+1,idx))
           !hpsi is now diagonally preconditioned with alexey's old preconditioner;
           !inside the diagonal preconditioner a factor of d^{1/2} was added
           !to make the overall factor d^{-1/2} again

           call prec_diag(lr%d%n1,lr%d%n2,lr%d%n3,hx,lr%wfd%nseg_c,&
                lr%wfd%nvctr_c,lr%wfd%nvctr_f,&
                lr%wfd%keyg,lr%wfd%keyv,x(1,idx),x(lr%wfd%nvctr_c+1,idx),cprecr,scal,a2,b2)

        else
           !assume as input guess x=y
           !hpsi is preconditioned with d^{-1/2} as usual
           call wscalv(lr%wfd%nvctr_c,lr%wfd%nvctr_f,scal,&
                x(1,idx),x(lr%wfd%nvctr_c+1,idx))

           !b=x
           call dcopy(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,x(1,idx),1,b(1,idx),1) 
        endif
     end do

     !initalize to zero the work arrays, probably not needed
     call razero((lr%d%nfu1-lr%d%nfl1+1)*(lr%d%nfu2-lr%d%nfl2+1)*(lr%d%nfu3-lr%d%nfl3+1),&
          w%x_f1)
     call razero((lr%d%nfu1-lr%d%nfl1+1)*(lr%d%nfu2-lr%d%nfl2+1)*(lr%d%nfu3-lr%d%nfl3+1),&
          w%x_f2)
     call razero((lr%d%nfu1-lr%d%nfl1+1)*(lr%d%nfu2-lr%d%nfl2+1)*(lr%d%nfu3-lr%d%nfl3+1),&
          w%x_f3)
     call razero((lr%d%n1+1)*(lr%d%n2+1)*(lr%d%n3+1),w%xpsig_c)
     call razero(7*(lr%d%nfu1-lr%d%nfl1+1)*(lr%d%nfu2-lr%d%nfl2+1)*(lr%d%nfu3-lr%d%nfl3+1),w%xpsig_f)

     call razero((lr%d%n1+1)*(lr%d%n2+1)*(lr%d%n3+1),w%ypsig_c)
     call razero(7*(lr%d%nfu1-lr%d%nfl1+1)*(lr%d%nfu2-lr%d%nfl2+1)*(lr%d%nfu3-lr%d%nfl3+1),w%ypsig_f)

  else if (lr%geocode == 'P') then

     call dimensions_fft(lr%d%n1,lr%d%n2,lr%d%n3,&
          nd1,nd2,nd3,n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b)

     if (ncplx /=2 .and. .not. lr%hybrid_on) then
        call prepare_sdc(lr%d%n1,lr%d%n2,lr%d%n3,&
          w%modul1,w%modul2,w%modul3,w%af,w%bf,w%cf,w%ef,hx,hy,hz)
     end if
     !	initializes the wavelet scaling coefficients	
     call wscal_init_per(scal,hx,hy,hz,cprecr)


     if (lr%hybrid_on) then
        do idx=1,ncplx
           !b=x
           call dcopy(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,x(1,idx),1,b(1,idx),1) 
           
           call prec_fft_fast(lr%d%n1,lr%d%n2,lr%d%n3,&
                lr%wfd%nseg_c,lr%wfd%nvctr_c,lr%wfd%nseg_f,lr%wfd%nvctr_f,&
                lr%wfd%keyg,lr%wfd%keyv, &
                cprecr,hx,hy,hz,x(1,idx),&
                w%kern_k1,w%kern_k2,w%kern_k3,w%z1,w%z3,w%x_c,&
                nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b)
        end do

     else
        ! Array sizes for the real-to-complex FFT: note that n1(there)=n1(here)+1
        ! and the same for lr%d%n2,n3.

        do idx=1,ncplx
           !	scale the r.h.s. that is also the scaled input guess :
           !	b'=D^{-1/2}b
           call wscal_per_self(lr%wfd%nvctr_c,lr%wfd%nvctr_f,scal,&
                x(1,idx),x(lr%wfd%nvctr_c+1,idx))
           !b=x
           call dcopy(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,x(1,idx),1,b(1,idx),1) 

           !if GPU is swithced on and there is no call to GPU preconditioner
           !do not do the FFT preconditioning
           if (.not. GPUconv) then
              !	compute the input guess x via a Fourier transform in a cubic box.
              !	Arrays psifscf and ww serve as work arrays for the Fourier
              fac=1.0_gp/scal(0)**2

              call prec_fft_c(lr%d%n1,lr%d%n2,lr%d%n3,lr%wfd%nseg_c,&
                   lr%wfd%nvctr_c,lr%wfd%nseg_f,lr%wfd%nvctr_f,lr%wfd%keyg,lr%wfd%keyv, &
                   cprecr,hx,hy,hz,x(1,idx),&
                   w%psifscf(1),w%psifscf(lr%d%n1+2),&
                   w%psifscf(lr%d%n1+lr%d%n2+3),w%ww(1),w%ww(nd1b*nd2*nd3*4+1),&
                   w%ww(nd1b*nd2*nd3*4+nd1*nd2*nd3f*4+1),&
                   nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b,fac)
           end if

        end do
     end if


  else if (lr%geocode == 'S') then

     if (ncplx == 1) then
        call prepare_sdc_slab(lr%d%n1,lr%d%n2,lr%d%n3,w%modul1,w%modul3,&
          w%af,w%bf,w%cf,w%ef,hx,hy,hz)
     end if
    
     !	initializes the wavelet scaling coefficients	
     call wscal_init_per(scal,hx,hy,hz,cprecr)
    
     do idx=1,ncplx
        !b=x
        call dcopy(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,x(1,idx),1,b(1,idx),1) 
        
        !	compute the input guess x via a Fourier transform in a cubic box.
        !	Arrays psifscf and ww serve as work arrays for the Fourier
        call prec_fft_slab_fast(lr%d%n1,lr%d%n2,lr%d%n3,lr%wfd%nseg_c,lr%wfd%nvctr_c,&
             lr%wfd%nseg_f,lr%wfd%nvctr_f,lr%wfd%keyg,lr%wfd%keyv, &
             cprecr,hx,hy,hz,x(1,idx),&
             w%psifscf(1),w%psifscf(lr%d%n1+2),w%ww(1),&
             w%ww(2*((lr%d%n1+1)/2+1)*(lr%d%n2+1)*(lr%d%n3+1)+1))
     end do

  end if
  
end subroutine precondition_preconditioner

subroutine allocate_work_arrays(geocode,hybrid_on,ncplx,d,w)
  use module_base
  use module_types
  implicit none
  character(len=1), intent(in) :: geocode
  logical, intent(in) :: hybrid_on
  integer, intent(in) :: ncplx
  type(grid_dimensions), intent(in) :: d
  type(workarr_precond), intent(out) :: w
  !local variables
  character(len=*), parameter :: subname='allocate_work_arrays'
  integer, parameter :: lowfil=-14,lupfil=14
  integer :: i_stat,i_all
  integer :: nd1,nd2,nd3
  integer :: n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b	
  integer :: nf


  if (geocode == 'F') then

     nf=(d%nfu1-d%nfl1+1)*(d%nfu2-d%nfl2+1)*(d%nfu3-d%nfl3+1)
     !allocate work arrays
     allocate(w%xpsig_c(0:d%n1,0:d%n2,0:d%n3+ndebug),stat=i_stat)
     call memocc(i_stat,w%xpsig_c,'xpsig_c',subname)
     allocate(w%xpsig_f(7,d%nfl1:d%nfu1,d%nfl2:d%nfu2,d%nfl3:d%nfu3+ndebug),stat=i_stat)
     call memocc(i_stat,w%xpsig_f,'xpsig_f',subname)
     allocate(w%ypsig_c(0:d%n1,0:d%n2,0:d%n3+ndebug),stat=i_stat)
     call memocc(i_stat,w%ypsig_c,'ypsig_c',subname)
     allocate(w%ypsig_f(7,d%nfl1:d%nfu1,d%nfl2:d%nfu2,d%nfl3:d%nfu3+ndebug),stat=i_stat)
     call memocc(i_stat,w%ypsig_f,'ypsig_f',subname)

     allocate(w%x_f1(nf+ndebug),stat=i_stat)
     call memocc(i_stat,w%x_f1,'x_f1',subname)
     allocate(w%x_f2(nf+ndebug),stat=i_stat)
     call memocc(i_stat,w%x_f2,'x_f2',subname)
     allocate(w%x_f3(nf+ndebug),stat=i_stat)
     call memocc(i_stat,w%x_f3,'x_f3',subname)
    
  else if (geocode == 'P') then
     
     if (hybrid_on) then
          
        call dimensions_fft(d%n1,d%n2,d%n3,&
             nd1,nd2,nd3,n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b)

        nf=(d%nfu1-d%nfl1+1)*(d%nfu2-d%nfl2+1)*(d%nfu3-d%nfl3+1)

        allocate(w%kern_k1(0:d%n1+ndebug),stat=i_stat)
        call memocc(i_stat,w%kern_k1,'kern_k1',subname)
        allocate(w%kern_k2(0:d%n2+ndebug),stat=i_stat)
        call memocc(i_stat,w%kern_k2,'kern_k2',subname)
        allocate(w%kern_k3(0:d%n3+ndebug),stat=i_stat)
        call memocc(i_stat,w%kern_k3,'kern_k3',subname)
        allocate(w%z1(2,nd1b,nd2,nd3,2+ndebug),stat=i_stat) ! work array for fft
        call memocc(i_stat,w%z1,'z1',subname)
        allocate(w%z3(2,nd1,nd2,nd3f,2+ndebug),stat=i_stat) ! work array for fft
        call memocc(i_stat,w%z3,'z3',subname)
        allocate(w%x_c(0:d%n1,0:d%n2,0:d%n3+ndebug),stat=i_stat)
        call memocc(i_stat,w%x_c,'x_c',subname)

        allocate(w%x_f(7,d%nfl1:d%nfu1,d%nfl2:d%nfu2,d%nfl3:d%nfu3+ndebug),stat=i_stat)
        call memocc(i_stat,w%x_f,'x_f',subname)
        allocate(w%x_f1(nf+ndebug),stat=i_stat)
        call memocc(i_stat,w%x_f1,'x_f1',subname)
        allocate(w%x_f2(nf+ndebug),stat=i_stat)
        call memocc(i_stat,w%x_f2,'x_f2',subname)
        allocate(w%x_f3(nf+ndebug),stat=i_stat)
        call memocc(i_stat,w%x_f3,'x_f3',subname)
        allocate(w%y_f(7,d%nfl1:d%nfu1,d%nfl2:d%nfu2,d%nfl3:d%nfu3+ndebug),stat=i_stat)
        call memocc(i_stat,w%y_f,'y_f',subname)

     else 

        if (ncplx == 1) then
           !periodic, not k-points
           allocate(w%modul1(lowfil:d%n1+lupfil+ndebug),stat=i_stat)
           call memocc(i_stat,w%modul1,'modul1',subname)
           allocate(w%modul2(lowfil:d%n2+lupfil+ndebug),stat=i_stat)
           call memocc(i_stat,w%modul2,'modul2',subname)
           allocate(w%modul3(lowfil:d%n3+lupfil+ndebug),stat=i_stat)
           call memocc(i_stat,w%modul3,'modul3',subname)
           allocate(w%af(lowfil:lupfil,3+ndebug),stat=i_stat)
           call memocc(i_stat,w%af,'af',subname)
           allocate(w%bf(lowfil:lupfil,3+ndebug),stat=i_stat)
           call memocc(i_stat,w%bf,'bf',subname)
           allocate(w%cf(lowfil:lupfil,3+ndebug),stat=i_stat)
           call memocc(i_stat,w%cf,'cf',subname)
           allocate(w%ef(lowfil:lupfil,3+ndebug),stat=i_stat)
           call memocc(i_stat,w%ef,'ef',subname)
        end if

        allocate(w%psifscf(ncplx*(2*d%n1+2)*(2*d%n2+2)*(2*d%n3+2)+ndebug),stat=i_stat )
        call memocc(i_stat,w%psifscf,'psifscf',subname)
        allocate(w%ww(ncplx*(2*d%n1+2)*(2*d%n2+2)*(2*d%n3+2)+ndebug),stat=i_stat)
        call memocc(i_stat,w%ww,'ww',subname)

     end if

  else if (geocode == 'S') then

     if (ncplx == 1) then
        allocate(w%modul1(lowfil:d%n1+lupfil+ndebug),stat=i_stat)
        call memocc(i_stat,w%modul1,'modul1',subname)
        allocate(w%modul3(lowfil:d%n3+lupfil+ndebug),stat=i_stat)
        call memocc(i_stat,w%modul3,'modul3',subname)
        allocate(w%af(lowfil:lupfil,3+ndebug),stat=i_stat)
        call memocc(i_stat,w%af,'af',subname)
        allocate(w%bf(lowfil:lupfil,3+ndebug),stat=i_stat)
        call memocc(i_stat,w%bf,'bf',subname)
        allocate(w%cf(lowfil:lupfil,3+ndebug),stat=i_stat)
        call memocc(i_stat,w%cf,'cf',subname)
        allocate(w%ef(lowfil:lupfil,3+ndebug),stat=i_stat)
        call memocc(i_stat,w%ef,'ef',subname)
     end if
        
     allocate(w%psifscf(ncplx*(2*d%n1+2)*(2*d%n2+16)*(2*d%n3+2)+ndebug),stat=i_stat )
     call memocc(i_stat,w%psifscf,'psifscf',subname)
     allocate(w%ww(ncplx*(2*d%n1+2)*(2*d%n2+16)*(2*d%n3+2)+ndebug) ,stat=i_stat)
     call memocc(i_stat,w%ww,'ww',subname)

  end if

end subroutine allocate_work_arrays

subroutine deallocate_work_arrays(geocode,hybrid_on,ncplx,w)
  use module_base
  use module_types
  implicit none
  character(len=1), intent(in) :: geocode
  logical, intent(in) :: hybrid_on
  integer, intent(in) :: ncplx
  type(workarr_precond), intent(out) :: w
  !local variables
  character(len=*), parameter :: subname='deallocate_work_arrays'
  integer :: i_stat,i_all

  if (geocode == 'F') then

     i_all=-product(shape(w%xpsig_c))*kind(w%xpsig_c)
     deallocate(w%xpsig_c,stat=i_stat)
     call memocc(i_stat,i_all,'xpsig_c',subname)
     i_all=-product(shape(w%ypsig_c))*kind(w%ypsig_c)
     deallocate(w%ypsig_c,stat=i_stat)
     call memocc(i_stat,i_all,'ypsig_c',subname)
     i_all=-product(shape(w%xpsig_f))*kind(w%xpsig_f)
     deallocate(w%xpsig_f,stat=i_stat)
     call memocc(i_stat,i_all,'xpsig_f',subname)
     i_all=-product(shape(w%ypsig_f))*kind(w%ypsig_f)
     deallocate(w%ypsig_f,stat=i_stat)
     call memocc(i_stat,i_all,'ypsig_f',subname)
     i_all=-product(shape(w%x_f1))*kind(w%x_f1)
     deallocate(w%x_f1,stat=i_stat)
     call memocc(i_stat,i_all,'x_f1',subname)
     i_all=-product(shape(w%x_f2))*kind(w%x_f2)
     deallocate(w%x_f2,stat=i_stat)
     call memocc(i_stat,i_all,'x_f2',subname)
     i_all=-product(shape(w%x_f3))*kind(w%x_f3)
     deallocate(w%x_f3,stat=i_stat)
     call memocc(i_stat,i_all,'x_f3',subname)

  else if ((geocode == 'P' .and. .not. hybrid_on) .or. geocode == 'S') then

     if (ncplx == 1) then
        i_all=-product(shape(w%modul1))*kind(w%modul1)
        deallocate(w%modul1,stat=i_stat)
        call memocc(i_stat,i_all,'modul1',subname)
        if (geocode /= 'S') then
           i_all=-product(shape(w%modul2))*kind(w%modul2)
           deallocate(w%modul2,stat=i_stat)
           call memocc(i_stat,i_all,'modul2',subname)
        end if
        i_all=-product(shape(w%modul3))*kind(w%modul3)
        deallocate(w%modul3,stat=i_stat)
        call memocc(i_stat,i_all,'modul3',subname)
        i_all=-product(shape(w%af))*kind(w%af)
        deallocate(w%af,stat=i_stat)
        call memocc(i_stat,i_all,'af',subname)
        i_all=-product(shape(w%bf))*kind(w%bf)
        deallocate(w%bf,stat=i_stat)
        call memocc(i_stat,i_all,'bf',subname)
        i_all=-product(shape(w%cf))*kind(w%cf)
        deallocate(w%cf,stat=i_stat)
        call memocc(i_stat,i_all,'cf',subname)
        i_all=-product(shape(w%ef))*kind(w%ef)
        deallocate(w%ef,stat=i_stat)
        call memocc(i_stat,i_all,'ef',subname)
     end if

     i_all=-product(shape(w%psifscf))*kind(w%psifscf)
     deallocate(w%psifscf,stat=i_stat)
     call memocc(i_stat,i_all,'psifscf',subname)
     i_all=-product(shape(w%ww))*kind(w%ww)
     deallocate(w%ww,stat=i_stat)
     call memocc(i_stat,i_all,'ww',subname)

  else if (geocode == 'P' .and. hybrid_on) then

     i_all=-product(shape(w%z1))*kind(w%z1)
     deallocate(w%z1,stat=i_stat)
     call memocc(i_stat,i_all,'z1',subname)
     i_all=-product(shape(w%z3))*kind(w%z3)
     deallocate(w%z3,stat=i_stat)
     call memocc(i_stat,i_all,'z3',subname)
     i_all=-product(shape(w%kern_k1))*kind(w%kern_k1)
     deallocate(w%kern_k1,stat=i_stat)
     call memocc(i_stat,i_all,'kern_k1',subname)
     i_all=-product(shape(w%kern_k2))*kind(w%kern_k2)
     deallocate(w%kern_k2,stat=i_stat)
     call memocc(i_stat,i_all,'kern_k2',subname)
     i_all=-product(shape(w%kern_k3))*kind(w%kern_k3)
     deallocate(w%kern_k3,stat=i_stat)
     call memocc(i_stat,i_all,'kern_k3',subname)
     i_all=-product(shape(w%x_c))*kind(w%x_c)
     deallocate(w%x_c,stat=i_stat)
     call memocc(i_stat,i_all,'x_c',subname)
     i_all=-product(shape(w%x_f))*kind(w%x_f)
     deallocate(w%x_f,stat=i_stat)
     call memocc(i_stat,i_all,'x_f',subname)
     i_all=-product(shape(w%x_f1))*kind(w%x_f1)
     deallocate(w%x_f1,stat=i_stat)
     call memocc(i_stat,i_all,'x_f1',subname)
     i_all=-product(shape(w%x_f2))*kind(w%x_f2)
     deallocate(w%x_f2,stat=i_stat)
     call memocc(i_stat,i_all,'x_f2',subname)
     i_all=-product(shape(w%x_f3))*kind(w%x_f3)
     deallocate(w%x_f3,stat=i_stat)
     call memocc(i_stat,i_all,'x_f3',subname)
     i_all=-product(shape(w%y_f))*kind(w%y_f)
     deallocate(w%y_f,stat=i_stat)
     call memocc(i_stat,i_all,'y_f',subname)


  end if

end subroutine deallocate_work_arrays

subroutine precond_locham(ncplx,lr,hx,hy,hz,kx,ky,kz,&
     cprecr,x,y,w,scal)! y:=Ax
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: ncplx
  real(gp), intent(in) :: hx,hy,hz,cprecr,kx,ky,kz
  type(locreg_descriptors), intent(in) :: lr
  real(gp), dimension(0:7), intent(in) :: scal
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,ncplx), intent(in) ::  x
  type(workarr_precond), intent(inout) :: w
  real(wp), dimension(lr%wfd%nvctr_c+7*lr%wfd%nvctr_f,ncplx), intent(out) ::  y
  !local variables
  integer :: idx,nf

  if (lr%geocode == 'F') then
     do idx=1,ncplx
        call calc_grad_reza(lr%d%n1,lr%d%n2,lr%d%n3,&
             lr%d%nfl1,lr%d%nfu1,lr%d%nfl2,lr%d%nfu2,lr%d%nfl3,lr%d%nfu3, &
             lr%wfd%nseg_c,lr%wfd%nvctr_c,lr%wfd%keyg,lr%wfd%keyv,&
             lr%wfd%nseg_f,lr%wfd%nvctr_f,&
             lr%wfd%keyg(1,lr%wfd%nseg_c+1),lr%wfd%keyv(lr%wfd%nseg_c+1), &
             scal,cprecr,hx,&
             lr%bounds%kb%ibyz_c,lr%bounds%kb%ibxz_c,lr%bounds%kb%ibxy_c,&
             lr%bounds%kb%ibyz_f,lr%bounds%kb%ibxz_f,lr%bounds%kb%ibxy_f,&
             x(1,idx),x(lr%wfd%nvctr_c+1,idx),y(1,idx),y(lr%wfd%nvctr_c+1,idx),&
             w%xpsig_c,w%xpsig_f,w%ypsig_c,w%ypsig_f,&
             w%x_f1,w%x_f2,w%x_f3)
     end do
  else if (lr%geocode == 'P') then
     if (lr%hybrid_on) then

        nf=(lr%d%nfu1-lr%d%nfl1+1)*(lr%d%nfu2-lr%d%nfl2+1)*(lr%d%nfu3-lr%d%nfl3+1)
        do idx=1,ncplx
           call apply_hp_hyb(lr%d%n1,lr%d%n2,lr%d%n3,&
                lr%wfd%nseg_c,lr%wfd%nvctr_c,lr%wfd%nseg_f,lr%wfd%nvctr_f,&
                lr%wfd%keyg,lr%wfd%keyv, &
                cprecr,hx,hy,hz,x(1,idx),y(1,idx),&
                w%x_f,w%x_c,w%x_f1,w%x_f2,w%x_f3,w%y_f,w%z1,&
                lr%d%nfl1,lr%d%nfl2,lr%d%nfl3,lr%d%nfu1,lr%d%nfu2,lr%d%nfu3,nf,&
                lr%bounds%kb%ibyz_f,lr%bounds%kb%ibxz_f,lr%bounds%kb%ibxy_f)
        end do
     else
        if (ncplx == 1) then
           call apply_hp_scal(lr%d%n1,lr%d%n2,lr%d%n3,&
                lr%wfd%nseg_c,lr%wfd%nvctr_c,lr%wfd%nseg_f,&
                lr%wfd%nvctr_f,lr%wfd%keyg,lr%wfd%keyv, &
                cprecr,hx,hy,hz,x,y,w%psifscf,w%ww,w%modul1,w%modul2,w%modul3,&
                w%af,w%bf,w%cf,w%ef,scal) 
        else
           call apply_hp_per_k(lr%d%n1,lr%d%n2,lr%d%n3,&
                lr%wfd%nseg_c,lr%wfd%nvctr_c,lr%wfd%nseg_f,&
             lr%wfd%nvctr_f,lr%wfd%keyg,lr%wfd%keyv, &
             cprecr,hx,hy,hz,kx,ky,kz,x,y,w%psifscf,w%ww,scal) 
        end if
     end if
  else if (lr%geocode == 'S') then
     if (ncplx == 1) then
        call apply_hp_slab_sd(lr%d%n1,lr%d%n2,lr%d%n3,&
             lr%wfd%nseg_c,lr%wfd%nvctr_c,lr%wfd%nseg_f,&
             lr%wfd%nvctr_f,lr%wfd%keyg,lr%wfd%keyv, &
             cprecr,hx,hy,hz,x,y,w%psifscf,w%ww,w%modul1,w%modul3,&
             w%af,w%bf,w%cf,w%ef)
     else
        call apply_hp_slab_k(lr%d%n1,lr%d%n2,lr%d%n3,&
             lr%wfd%nseg_c,lr%wfd%nvctr_c,lr%wfd%nseg_f,&
             lr%wfd%nvctr_f,lr%wfd%keyg,lr%wfd%keyv, &
             cprecr,hx,hy,hz,kx,ky,kz,x,y,w%psifscf,w%ww) 

     end if
   end if
end subroutine precond_locham


subroutine precong_per(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     ncong,cprecr,hx,hy,hz,x)
  use module_base
  ! Solves (KE+cprecr*I)*xx=yy by conjugate gradient method
  ! x is the right hand side on input and the solution on output
  implicit none
  integer, intent(in) :: n1,n2,n3,ncong
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(inout) ::  x(nvctr_c+7*nvctr_f)
  ! local variables
  integer, parameter :: lowfil=-14,lupfil=14
  real(gp) :: scal(0:7),fac
  real(wp) :: rmr_old,rmr_new,alpha,beta
  integer :: i,i_stat,i_all,icong
  real(wp), allocatable :: b(:),r(:),d(:)
  real(wp), allocatable :: psifscf(:),ww(:)
  integer :: nd1,nd2,nd3
  integer :: n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b	
  real(gp), allocatable, dimension(:,:) :: af,bf,cf,ef
  integer, allocatable, dimension(:) :: modul1,modul2,modul3

  ! Array sizes for the real-to-complex FFT: note that n1(there)=n1(here)+1
  ! and the same for n2,n3.
  call dimensions_fft(n1,n2,n3,nd1,nd2,nd3,n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b)

  call allocate_all

  call prepare_sdc(n1,n2,n3,modul1,modul2,modul3,af,bf,cf,ef,hx,hy,hz)
  !	initializes the wavelet scaling coefficients	
  call wscal_init_per(scal,hx,hy,hz,cprecr)

  !	scale the r.h.s. that is also the scaled input guess :
  !	b'=D^{-1/2}b
  call wscal_per_self(nvctr_c,nvctr_f,scal,x(1),x(nvctr_c+1))
  !b=x
  call dcopy(nvctr_c+7*nvctr_f,x,1,b,1) 

  !if GPU is swithced on and there is no call to GPU preconditioner
  !do not do the FFT preconditioning
  if (.not. GPUconv) then
     !	compute the input guess x via a Fourier transform in a cubic box.
     !	Arrays psifscf and ww serve as work arrays for the Fourier
     fac=1.d0/scal(0)**2
     call prec_fft_c(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
          cprecr,hx,hy,hz,x,&
          psifscf(1),psifscf(n1+2),psifscf(n1+n2+3),ww(1),ww(nd1b*nd2*nd3*4+1),&
          ww(nd1b*nd2*nd3*4+nd1*nd2*nd3f*4+1),&
          nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b,fac)
  end if

  call apply_hp_scal(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
       cprecr,hx,hy,hz,x,d,psifscf,ww,modul1,modul2,modul3,af,bf,cf,ef,scal) ! d:=Ax

!!$  x=d
!!$  return

  r=b-d ! r=b-Ax
  d=r
  !rmr_new=dot_product(r,r)
  rmr_new=dot(nvctr_c+7*nvctr_f,r(1),1,r(1),1)

  do icong=1,ncong 
     !write(*,*)icong,rmr_new

     call apply_hp_scal(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
          cprecr,hx,hy,hz,d,b,psifscf,ww,modul1,modul2,modul3,af,bf,cf,ef,scal) ! b:=Ad

     alpha=rmr_new/dot(nvctr_c+7*nvctr_f,d(1),1,b(1),1)

     do i=1,nvctr_c+7*nvctr_f
        x(i)=x(i)+alpha*d(i)
        r(i)=r(i)-alpha*b(i)
     enddo

     if (icong==ncong) exit

     rmr_old=rmr_new	
     rmr_new=dot(nvctr_c+7*nvctr_f,r(1),1,r(1),1)

     beta=rmr_new/rmr_old
     d=r+beta*d
  enddo

  ! x=D^{-1/2}x'
  call wscal_per_self(nvctr_c,nvctr_f,scal,x(1),x(nvctr_c+1))
  !	write(30,*) x
  !	stop

  call deallocate_all

contains
  subroutine allocate_all
    allocate(modul1(lowfil:n1+lupfil+ndebug),stat=i_stat)
    call memocc(i_stat,modul1,'modul1','precong_per')
    allocate(modul2(lowfil:n2+lupfil+ndebug),stat=i_stat)
    call memocc(i_stat,modul2,'modul2','precong_per')
    allocate(modul3(lowfil:n3+lupfil+ndebug),stat=i_stat)
    call memocc(i_stat,modul3,'modul3','precong_per')
    allocate(af(lowfil:lupfil,3+ndebug),stat=i_stat)
    call memocc(i_stat,af,'af','precong_per')
    allocate(bf(lowfil:lupfil,3+ndebug),stat=i_stat)
    call memocc(i_stat,bf,'bf','precong_per')
    allocate(cf(lowfil:lupfil,3+ndebug),stat=i_stat)
    call memocc(i_stat,cf,'cf','precong_per')
    allocate(ef(lowfil:lupfil,3+ndebug),stat=i_stat)
    call memocc(i_stat,ef,'ef','precong_per')

    allocate(b(nvctr_c+7*nvctr_f+ndebug),stat=i_stat)
    call memocc(i_stat,b,'b','precong_per')
    allocate(r(nvctr_c+7*nvctr_f+ndebug),stat=i_stat)
    call memocc(i_stat,r,'r','precong_per')
    allocate(d(nvctr_c+7*nvctr_f+ndebug),stat=i_stat)
    call memocc(i_stat,d,'d','precong_per')
    allocate( psifscf((2*n1+2)*(2*n2+2)*(2*n3+2)+ndebug),stat=i_stat )
    call memocc(i_stat,psifscf,'psifscf','precong_per')
    allocate( ww((2*n1+2)*(2*n2+2)*(2*n3+2)+ndebug) ,stat=i_stat)
    call memocc(i_stat,ww,'ww','precong_per')
  end subroutine allocate_all

  subroutine deallocate_all

    i_all=-product(shape(modul1))*kind(modul1)
    deallocate(modul1,stat=i_stat)
    call memocc(i_stat,i_all,'modul1','last_orthon')

    i_all=-product(shape(modul2))*kind(modul2)
    deallocate(modul2,stat=i_stat)
    call memocc(i_stat,i_all,'modul2','last_orthon')

    i_all=-product(shape(modul3))*kind(modul3)
    deallocate(modul3,stat=i_stat)
    call memocc(i_stat,i_all,'modul3','last_orthon')

    i_all=-product(shape(af))*kind(af)
    deallocate(af,stat=i_stat)
    call memocc(i_stat,i_all,'af','last_orthon')

    i_all=-product(shape(bf))*kind(bf)
    deallocate(bf,stat=i_stat)
    call memocc(i_stat,i_all,'bf','last_orthon')

    i_all=-product(shape(cf))*kind(cf)
    deallocate(cf,stat=i_stat)
    call memocc(i_stat,i_all,'cf','last_orthon')

    i_all=-product(shape(ef))*kind(ef)
    deallocate(ef,stat=i_stat)
    call memocc(i_stat,i_all,'ef','last_orthon')


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

subroutine prec_fft_c(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,hpsi,&
     kern_k1,kern_k2,kern_k3,z1,z3,x_c,&
     nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b,fac)
  ! Solves (KE+cprecr*I)*xx=yy by FFT in a cubic box 
  ! x_c is the right hand side on input and the solution on output
  ! This version uses work arrays kern_k1-kern_k3 and z allocated elsewhere
  use module_base
  implicit none 
  integer, intent(in) :: n1,n2,n3
  integer,intent(in)::nd1,nd2,nd3
  integer,intent(in)::n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b	
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr,fac
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(inout) ::  hpsi(nvctr_c+7*nvctr_f) 

  !work arrays
  real(gp):: kern_k1(0:n1),kern_k2(0:n2),kern_k3(0:n3)
  real(wp),dimension(0:n1,0:n2,0:n3):: x_c! in and out of Fourier preconditioning
  real(wp)::z1(2,nd1b,nd2,nd3,2)! work array
  real(wp)::z3(2,nd1,nd2,nd3f,2)! work array

  call make_kernel(n1,hx,kern_k1)
  call make_kernel(n2,hy,kern_k2)
  call make_kernel(n3,hz,kern_k3)

  call uncompress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

  call hit_with_kernel_fac(x_c,z1,z3,kern_k1,kern_k2,kern_k3,n1+1,n2+1,n3+1,nd1,nd2,nd3,&
       n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b,cprecr,fac)

  call compress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

end subroutine prec_fft_c

subroutine prec_fft_fast(n1,n2,n3,nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,hpsi,&
     kern_k1,kern_k2,kern_k3,z1,z3,x_c,&
     nd1,nd2,nd3,n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b)
  ! Solves (KE+cprecr*I)*xx=yy by FFT in a cubic box 
  ! x_c is the right hand side on input and the solution on output
  ! This version uses work arrays kern_k1-kern_k3 and z allocated elsewhere
  use module_base
  implicit none 
  integer, intent(in) :: n1,n2,n3
  integer,intent(in)::nd1,nd2,nd3
  integer,intent(in)::n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b	
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(inout) ::  hpsi(nvctr_c+7*nvctr_f) 

  !work arrays
  real(gp):: kern_k1(0:n1),kern_k2(0:n2),kern_k3(0:n3)
  real(wp),dimension(0:n1,0:n2,0:n3):: x_c! in and out of Fourier preconditioning
  real(wp)::z1(2,nd1b,nd2,nd3,2)! work array
  real(wp)::z3(2,nd1,nd2,nd3f,2)! work array

  call wscal_f(nvctr_f,hpsi(nvctr_c+1),hx,hy,hz,cprecr)

  call make_kernel(n1,hx,kern_k1)
  call make_kernel(n2,hy,kern_k2)
  call make_kernel(n3,hz,kern_k3)

  call uncompress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

  call  hit_with_kernel(x_c,z1,z3,kern_k1,kern_k2,kern_k3,n1+1,n2+1,n3+1,nd1,nd2,nd3,&
       n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b,cprecr)

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
  real(gp), intent(in) :: hx,hy,hz,cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(inout) ::  hpsi(nvctr_c+7*nvctr_f)
  !local variables
  integer nd1,nd2,nd3,i_stat,i_all
  real(gp), dimension(:), allocatable :: kern_k1,kern_k2,kern_k3
  real(wp), dimension(:,:,:), allocatable :: x_c! in and out of Fourier preconditioning
  real(wp), dimension(:,:,:,:,:), allocatable::z1,z3 ! work array for FFT
  integer::n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b	

  ! Array sizes for the real-to-complex FFT: note that n1(there)=n1(here)+1
  ! and the same for n2,n3.
  call dimensions_fft(n1,n2,n3,nd1,nd2,nd3,n1f,n3f,n1b,n3b,nd1f,nd3f,nd1b,nd3b)

  call allocate_all

  ! diagonally precondition the wavelet part  
  call wscal_f(nvctr_f,hpsi(nvctr_c+1),hx,hy,hz,cprecr)

  call make_kernel(n1,hx,kern_k1)
  call make_kernel(n2,hy,kern_k2)
  call make_kernel(n3,hz,kern_k3)

  call uncompress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

  !	solve the helmholtz equation for the scfunction part  
  call  hit_with_kernel(x_c,z1,z3,kern_k1,kern_k2,kern_k3,n1+1,n2+1,n3+1,nd1,nd2,nd3,&
       n1f,n1b,n3f,n3b,nd1f,nd1b,nd3f,nd3b,cprecr)

  call compress_c(hpsi,x_c,keyg(1,1),keyv(1),nseg_c,nvctr_c,n1,n2,n3)

  call deallocate_all

contains
  subroutine allocate_all
    allocate(kern_k1(0:n1+ndebug),stat=i_stat)
    call memocc(i_stat,kern_k1,'kern_k1','prec_fft')
    allocate(kern_k2(0:n2+ndebug),stat=i_stat)
    call memocc(i_stat,kern_k2,'kern_k2','prec_fft')
    allocate(kern_k3(0:n3+ndebug),stat=i_stat)
    call memocc(i_stat,kern_k3,'kern_k3','prec_fft')
    allocate(z1(2,nd1b,nd2,nd3,2+ndebug),stat=i_stat) ! work array for fft
    call memocc(i_stat,z1,'z1','prec_fft')
    allocate(z3(2,nd1,nd2,nd3f,2+ndebug),stat=i_stat) ! work array for fft
    call memocc(i_stat,z3,'z3','prec_fft')
    allocate(x_c(0:n1,0:n2,0:n3+ndebug),stat=i_stat)
    call memocc(i_stat,x_c,'x_c','prec_fft')
  end subroutine allocate_all
  subroutine deallocate_all
    i_all=-product(shape(z1))*kind(z1)
    deallocate(z1,stat=i_stat)
    call memocc(i_stat,i_all,'z1','last_orthon')

    i_all=-product(shape(z3))*kind(z3)
    deallocate(z3,stat=i_stat)
    call memocc(i_stat,i_all,'z3','last_orthon')

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
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(in) ::  x(nvctr_c+7*nvctr_f)  
  real(wp), intent(out) ::  y(nvctr_c+7*nvctr_f)

  real(gp) hgridh(3)	
  real(wp),dimension((2*n1+2)*(2*n2+2)*(2*n3+2))::ww,psifscf

  call uncompress_per(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   &
       nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   &
       x(1),x(nvctr_c+1),psifscf,ww)

  hgridh(1)=hx*.5_gp
  hgridh(2)=hy*.5_gp
  hgridh(3)=hz*.5_gp
  call convolut_kinetic_per_c(2*n1+1,2*n2+1,2*n3+1,hgridh,psifscf,ww,cprecr)

  call compress_per(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   & 
       nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   & 
       ww,y(1),y(nvctr_c+1),psifscf)
end subroutine apply_hp

subroutine apply_hp_slab_k(n1,n2,n3, &
     nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,kx,ky,kz,x,y,psifscf,ww)
  !	Applies the operator (KE+cprecr*I)*x=y
  !	array x is input, array y is output
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr,kx,ky,kz
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), intent(in) ::  x(nvctr_c+7*nvctr_f,2)  
  real(wp), intent(out) ::  y(nvctr_c+7*nvctr_f,2)
  real(wp), dimension((2*n1+2)*(2*n2+16)*(2*n3+2),2) :: ww,psifscf
  !local variables
  integer :: idx
  real(gp) hgridh(3)	


  ! x: input, ww:work
  ! psifscf: output
  do idx=1,2
     call uncompress_slab(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   &
          nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   &
          x(1,idx),x(nvctr_c+1,idx),psifscf(1,idx),ww(1,idx))
  end do

  !transpose (to be included in the uncompression)
  call transpose_for_kpoints(2,2*n1+2,2*n2+16,2*n3+2,&
       psifscf,ww,.true.)

  hgridh(1)=hx*.5_gp
  hgridh(2)=hy*.5_gp
  hgridh(3)=hz*.5_gp
  ! psifscf: input, ww: output
  call convolut_kinetic_slab_c_k(2*n1+1,2*n2+15,2*n3+1,hgridh,psifscf,ww,cprecr,&
       kx,ky,kz)

  call transpose_for_kpoints(2,2*n1+2,2*n2+16,2*n3+2,&
       ww,psifscf,.false.)

  ! ww:intput, psifscf: work
  ! y:output
  do idx=1,2
     call compress_slab(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),& 
          nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),& 
          ww(1,idx),y(1,idx),y(nvctr_c+1,idx),psifscf(1,idx))
  end do

end subroutine apply_hp_slab_k


subroutine apply_hp_per_k(n1,n2,n3, &
     nseg_c,nvctr_c,nseg_f,nvctr_f,keyg,keyv, &
     cprecr,hx,hy,hz,k1,k2,k3,x,y,psifscf,ww,scal)
  !	Applies the operator (KE+cprecr*I)*x=y
  !	array x is input, array y is output
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3
  integer, intent(in) :: nseg_c,nvctr_c,nseg_f,nvctr_f
  real(gp), intent(in) :: hx,hy,hz,cprecr,k1,k2,k3
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  real(wp), dimension(0:7), intent(in) :: scal
  real(wp), dimension(nvctr_c+7*nvctr_f,2), intent(in) :: x
  real(wp), dimension(nvctr_c+7*nvctr_f,2), intent(in) :: y
  real(wp), dimension((2*n1+2)*(2*n2+2)*(2*n3+2),2) :: ww,psifscf
  !local variables
  integer :: idx
  real(gp) hgridh(3)	
  
  do idx=1,2
     call uncompress_per_scal(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   &
          nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   &
          x(1,idx),x(nvctr_c+1,idx),psifscf(1,idx),ww(1,idx),scal)
  end do

  !transpose (to be included in the uncompression)
  call transpose_for_kpoints(2,2*n1+2,2*n2+2,2*n3+2,&
       psifscf,ww,.true.)
  
  hgridh(1)=hx*.5_gp
  hgridh(2)=hy*.5_gp
  hgridh(3)=hz*.5_gp
  call convolut_kinetic_per_c_k(2*n1+1,2*n2+1,2*n3+1,hgridh,psifscf,ww,cprecr,k1,k2,k3)
  !call convolut_kinetic_per_c(2*n1+1,2*n2+1,2*n3+1,hgridh,psifscf,ww,cprecr)

  call transpose_for_kpoints(2,2*n1+2,2*n2+2,2*n3+2,&
       ww,psifscf,.false.)

  do idx=1,2
     call compress_per_scal(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   & 
          nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   & 
          ww(1,idx),y(1,idx),y(nvctr_c+1,idx),psifscf(1,idx),scal)
  end do
end subroutine apply_hp_per_k



subroutine wscal_f(mvctr_f,psi_f,hx,hy,hz,c)
  ! multiplies a wavefunction psi_c,psi_f (in vector form) with a scaling vector (scal)
  use module_base
  implicit none
  integer,intent(in)::mvctr_f
  real(gp),intent(in)::c,hx,hy,hz

  real(wp)::psi_f(7,mvctr_f)
  real(gp)::scal(7),hh(3)
  !WAVELET AND SCALING FUNCTION SECOND DERIVATIVE FILTERS, diagonal elements
  real(gp),PARAMETER::B2=24.8758460293923314_gp,A2=3.55369228991319019_gp

  integer i

  hh(1)=.5_gp/hx**2
  hh(2)=.5_gp/hy**2
  hh(3)=.5_gp/hz**2

  scal(1)=1._gp/(b2*hh(1)+a2*hh(2)+a2*hh(3)+c)       !  2 1 1
  scal(2)=1._gp/(a2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  1 2 1
  scal(3)=1._gp/(b2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  2 2 1
  scal(4)=1._gp/(a2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  1 1 2
  scal(5)=1._gp/(b2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  2 1 2
  scal(6)=1._gp/(a2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  1 2 2
  scal(7)=1._gp/(b2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  2 2 2

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

subroutine wscal_per_self(mvctr_c,mvctr_f,scal,psi_c,psi_f)
  ! multiplies a wavefunction psi_c,psi_f (in vector form) with a scaling vector (scal)
  use module_base
  implicit none
  integer,intent(in)::mvctr_c,mvctr_f
  real(gp),intent(in)::scal(0:7)
  real(wp),intent(inout)::psi_c(mvctr_c),psi_f(7,mvctr_f)

  integer i

  do i=1,mvctr_c
     psi_c(i)=psi_c(i)*scal(0)           !  1 1 1
  enddo

  do i=1,mvctr_f
     psi_f(1,i)=psi_f(1,i)*scal(1)       !  2 1 1
     psi_f(2,i)=psi_f(2,i)*scal(2)       !  1 2 1
     psi_f(3,i)=psi_f(3,i)*scal(3)       !  2 2 1
     psi_f(4,i)=psi_f(4,i)*scal(4)       !  1 1 2
     psi_f(5,i)=psi_f(5,i)*scal(5)       !  2 1 2
     psi_f(6,i)=psi_f(6,i)*scal(6)       !  1 2 2
     psi_f(7,i)=psi_f(7,i)*scal(7)       !  2 2 2
  enddo

end subroutine wscal_per_self

subroutine wscal_per(mvctr_c,mvctr_f,scal,psi_c_in,psi_f_in,psi_c_out,psi_f_out)
  ! multiplies a wavefunction psi_c,psi_f (in vector form) with a scaling vector (scal)
  use module_base
  implicit none
  integer,intent(in)::mvctr_c,mvctr_f
  real(gp),intent(in)::scal(0:7)
  real(wp),intent(in)::psi_c_in(mvctr_c),psi_f_in(7,mvctr_f)
  real(wp),intent(out)::psi_c_out(mvctr_c),psi_f_out(7,mvctr_f)

  integer i

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
  use module_base
  implicit none
  real(wp), intent(in) :: c,hx,hy,hz
  real(wp), dimension(0:7), intent(out) :: scal
  !local variables
  real(wp), parameter :: b2=24.8758460293923314d0,a2=3.55369228991319019d0
  real(gp) :: hh(3)

  hh(1)=.5_wp/hx**2
  hh(2)=.5_wp/hy**2
  hh(3)=.5_wp/hz**2

  scal(0)=1._wp/sqrt(a2*hh(1)+a2*hh(2)+a2*hh(3)+c)       !  1 1 1
  scal(1)=1._wp/sqrt(b2*hh(1)+a2*hh(2)+a2*hh(3)+c)       !  2 1 1
  scal(2)=1._wp/sqrt(a2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  1 2 1
  scal(3)=1._wp/sqrt(b2*hh(1)+b2*hh(2)+a2*hh(3)+c)       !  2 2 1
  scal(4)=1._wp/sqrt(a2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  1 1 2
  scal(5)=1._wp/sqrt(b2*hh(1)+a2*hh(2)+b2*hh(3)+c)       !  2 1 2
  scal(6)=1._wp/sqrt(a2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  1 2 2
  scal(7)=1._wp/sqrt(b2*hh(1)+b2*hh(2)+b2*hh(3)+c)       !  2 2 2

end subroutine wscal_init_per


