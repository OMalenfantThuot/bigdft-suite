!perform a set of non-blocking send-receive operations
subroutine nonblocking_transposition(iproc,nproc,ncmpts,norblt,nspinor,&
     psi,norb_par,mpirequests)
  use module_base
  implicit none
  integer, intent(in) :: iproc,nproc,ncmpts,norblt,nspinor
  integer, dimension(0:nproc-1), intent(in) :: norb_par
  real(wp), dimension(ncmpts,norblt*nspinor), intent(inout) :: psi
  integer, dimension(nproc-1), intent(out) :: mpirequests
  !local variables
  integer :: jproc,ierr,isorb

  !the first process does not receive data
  isorb=0
  do jproc=1,iproc
     call MPI_IRECV(psi(1,nspinor*min(isorb+1,norblt)),nspinor*norb_par(jproc-1)*ncmpts,&
          mpidtypw,jproc-1,iproc+nproc*(jproc-1),MPI_COMM_WORLD,mpirequests(jproc),ierr)
     isorb=isorb+norb_par(jproc-1)
  end do

  isorb=0
  do jproc=1,iproc
     isorb=isorb+norb_par(jproc-1)
  end do
  !the last process does not send data
  do jproc=iproc+1,nproc-1
     call MPI_ISEND(psi(1,nspinor*min(isorb+1,norblt)),nspinor*norb_par(iproc)*ncmpts,&
          mpidtypw,jproc,jproc+nproc*iproc,MPI_COMM_WORLD,mpirequests(jproc),ierr)
  end do
  
end subroutine nonblocking_transposition

subroutine overlap_and_gather(iproc,nproc,mpirequests,ncmpts,natsc,nspin,ndimovrlp,orbs,&
     norbsc_arr,psi,hpsi,ovrlp)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: iproc,nproc,ncmpts,nspin,ndimovrlp,natsc
  type(orbitals_data), intent(in) :: orbs
  integer, dimension(nproc-1), intent(in) :: mpirequests
  integer, dimension((natsc+1)*nspin), intent(in) :: norbsc_arr
  real(wp), dimension(orbs%nspinor*ncmpts,orbs%isorb+orbs%norbp), intent(in) :: psi
  real(wp), dimension(orbs%nspinor*ncmpts,orbs%norbp), intent(in) :: hpsi
  real(wp), dimension(nspin*ndimovrlp,2), intent(out) :: ovrlp
  !local variables
  character(len=*), parameter :: subname='overlap_and_gather'
  integer :: ierr,iorb,jorb,imatrst,isorb,i_all,i_stat,jproc,norblt,i,ipos,nwrkdim
  integer :: iind,jind,iarr,iarrsum,ispin,norbi
  !integer, dimension(MPI_STATUS_SIZE) :: mpistatuses
  integer, dimension(:,:), allocatable :: mpicd
  real(wp), dimension(:), allocatable :: overlaps

  !at this point all the communicated objects before should have been received
  !control that, calculate the overlap matrices and gather the results
  !dimension of the overlap work array
  nwrkdim=max(orbs%norb*(orbs%norb+1),2*(orbs%isorb+orbs%norbp)*orbs%norbp)
  allocate(overlaps(nwrkdim+ndebug),stat=i_stat)
  call memocc(i_stat,overlaps,'overlaps',subname)


  !control that all the non-blocking communications are finished
  call MPI_WAITALL(nproc-1,mpirequests,MPI_STATUSES_IGNORE,ierr)
  
  !calculate a piece of psipsi and hpsipsi overlap matrix (Lower triangular)
  !non-balanced distribution, i.e. the last processor calculates the max number of lines
  !while the first calculates only the on-site part of the overlap
  !the overlap should be calculated differently for complex/spinorial wavefunctions
  norblt=orbs%isorb+orbs%norbp
  if (orbs%norbp /= 0) then
     call gemm('T','N',norblt,orbs%norbp,ncmpts,1.0_wp,psi(1,1),ncmpts,hpsi(1,1),ncmpts,&
          0.0_wp,overlaps(1),norblt)
     !the psi overlap must be calculated by using gaussian overlap
     call gemm('T','N',orbs%isorb+orbs%norbp,orbs%norbp,ncmpts,&
          1.0_wp,psi(1,1),ncmpts,psi(1,orbs%isorb+1),ncmpts,&
          0.0_wp,overlaps(norblt*orbs%norbp+1),norblt)
  end if

  imatrst=0
  ipos=0
  do i=1,2
     !reorder the overlap array
     do iorb=1,orbs%norbp
        do jorb=1,iorb+orbs%isorb
           ipos=ipos+1
           overlaps(ipos)=overlaps(jorb+norblt*(iorb-1)+imatrst)
        end do
     end do
     imatrst=imatrst+norblt*orbs%norbp
  end do
  !shift the position of the values for gathering the orbitals
  imatrst=orbs%isorb*(orbs%isorb+1)
  do i=ipos,1,-1
     overlaps(i+imatrst)=overlaps(i)
  end do

  !here we gather the different contributions on the 
  !processors which have some orbital onsite.
  !at the end each processor have all the Lower Triangular part of the overlap matrix
  if (nproc > 1 ) then
     !build the counts and displacement arrays
     allocate(mpicd(0:nproc-1,2+ndebug),stat=i_stat)
     call memocc(i_stat,mpicd,'mpicd',subname)

     !count
     mpicd(0,1)=orbs%norb_par(0)*(orbs%norb_par(0)+1)
     !displacement
     mpicd(0,2)=0
     isorb=orbs%norb_par(0)
     do jproc=1,nproc-1
        !count
        mpicd(jproc,1)=(isorb+orbs%norb_par(jproc))*(isorb+orbs%norb_par(jproc)+1)-&
             isorb*(isorb+1)
        !displacements
        mpicd(jproc,2)=mpicd(jproc-1,2)+mpicd(jproc-1,1)
        isorb=isorb+orbs%norb_par(jproc)
     end do

     call MPI_ALLGATHERV(MPI_IN_PLACE,0,mpidtypw,overlaps,mpicd(0,1),mpicd(0,2),&
          mpidtypw,MPI_COMM_WORLD,ierr)

     i_all=-product(shape(mpicd))*kind(mpicd)
     deallocate(mpicd,stat=i_stat)
     call memocc(i_stat,i_all,'mpicd',subname)
  end if

  !fill the final array with the values of the overlap matrix
  !in an ordered, LT disposition
  isorb=0
  ipos=0
  !iterators for the semicore arrays
  iarr=1
  iarrsum=0
  imatrst=0
  do jproc=0,nproc-1
     do i=1,2
        do iorb=isorb+1,isorb+orbs%norb_par(jproc)
           !determine the index of the overlap in the semicore arrangement
           if (iorb > norbsc_arr(iarr)+iarrsum) then
              iarrsum=iarrsum+norbsc_arr(iarr)
              imatrst=imatrst+norbsc_arr(iarr)**2
              iarr=iarr+1
           end if
           norbi=norbsc_arr(iarr)
           iind=iorb-iarrsum
           do jorb=1,iorb !this is LT, can switch to UT
              ipos=ipos+1
              jind=jorb-iarrsum
              if (jind > 0 .and. jind <= iind) then
                 ovrlp(imatrst+jind+norbi*(iind-1),i)=overlaps(ipos)
              end if
              !ovrlp(jorb,iorb,i)=overlaps(ipos)
              !ovrlp(jorb+(iorb-1)*orbs%norbp,i)=overlaps(ipos)
           end do
        end do
     end do
     isorb=isorb+orbs%norb_par(jproc)
  end do

  !fill the final array with the values of the overlap matrix
  !for each group of the semicore atoms
  !put them in the UT disposition
  imatrst=0
  do ispin=1,nspin !this assumes that the semicore is identical for both the spins
     do i=1,natsc+1
        norbi=norbsc_arr(i+(ispin-1)*(natsc+1))
        if (iproc == 0) then
           print *,'tt'
           do jorb=1,norbi
              write(*,'(i4,2000(1pe15.8))')jorb,&
                   (ovrlp(imatrst+iorb+norbi*(jorb-1),1),iorb=1,jorb)
           end do
           do jorb=1,norbi
              write(*,'(i4,2000(1pe15.8))')jorb,&
                   (ovrlp(imatrst+iorb+norbi*(jorb-1),2),iorb=1,jorb)
           end do
        end if
        imatrst=imatrst+norbi**2
     end do
  end do

  i_all=-product(shape(overlaps))*kind(overlaps)
  deallocate(overlaps,stat=i_stat)
  call memocc(i_stat,i_all,'overlaps',subname)


end subroutine overlap_and_gather


!overlap matrix between two different basis structures
subroutine gaussian_overlap(A,B,ovrlp)
  use module_base
  use module_types
  implicit none
  type(gaussian_basis), intent(in) :: A,B
  real(gp), dimension(A%ncoeff,B%ncoeff) :: ovrlp 
  !only lower triangular part for A%ncoeff=B%ncoeff
  !local variables
  integer, parameter :: niw=18,nrw=6
  integer :: ishell,iexpo,icoeff,ishellB,iexpoB,icoeffB,iat,jat,isat,isatB,jsat,jshell
  integer :: jstart,iovrlp,jovrlp,jcoeff,jexpo
  integer :: ngA,ngB,lA,lB,mA,mB
  real(gp) :: dx,dy,dz
  integer, dimension(niw) :: iw
  real(gp), dimension(nrw) :: rw

  iovrlp=0
  ishell=0
  iexpo=1
  icoeff=1

  !loop on each shell (intensive calculation)
  do iat=1,A%nat
     do isat=1,A%nshell(iat)
        ishell=ishell+1
        ngA=A%ndoc(ishell)
        lA=A%nam(ishell)
        do mA=1,2*lA-1
           iovrlp=iovrlp+1

           jovrlp=0
           jshell=0
           jexpo=1
           jcoeff=1

           do jat=1,B%nat
              dx=B%rxyz(1,jat)-A%rxyz(1,iat)
              dy=B%rxyz(2,jat)-A%rxyz(2,iat)
              dz=B%rxyz(3,jat)-A%rxyz(3,iat)
              do jsat=1,B%nshell(jat)
                 jshell=jshell+1
                 ngB=B%ndoc(jshell)
                 lB=B%nam(jshell)
                 do mB=1,2*lB-1
                    jovrlp=jovrlp+1
                    if (jovrlp >= iovrlp .and. A%ncoeff == B%ncoeff) then
                       call gbasovrlp(A%xp(iexpo),A%psiat(iexpo),&
                            B%xp(jexpo),B%psiat(jexpo),&
                            ngA,ngB,lA,mA,lB,mB,dx,dy,dz,&
                            niw,nrw,iw,rw,ovrlp(iovrlp,jovrlp))
                    end if
                 end do
                 jexpo=jexpo+ngB
                 jcoeff=jcoeff+2*lB-1
              end do
           end do
        end do
        iexpo=iexpo+ngA
        icoeff=icoeff+2*lA-1
     end do
  end do

  call gaudim_check(iexpo,icoeff,ishell,A%nexpo,A%ncoeff,A%nshltot)
  call gaudim_check(jexpo,jcoeff,jshell,B%nexpo,B%ncoeff,B%nshltot)
  
end subroutine gaussian_overlap

!calculates the scalar product between two shells
!by considering only the nonzero coefficients
!actual building block for calculating overlap matrix
!inserted work arrays for calculation
subroutine gbasovrlp(expo1,coeff1,expo2,coeff2,ng1,ng2,l1,m1,l2,m2,dx,dy,dz,&
     niw,nrw,iw,rw,ovrlp)
  use module_base
  implicit none
  integer, intent(in) :: ng1,ng2,l1,m1,l2,m2,niw,nrw
  real(gp), intent(in) :: dx,dy,dz
  integer, dimension(niw) :: iw
  real(gp), dimension(nrw) :: rw
  real(gp), dimension(ng1), intent(in) :: expo1,coeff1
  real(gp), dimension(ng2), intent(in) :: expo2,coeff2
  real(gp), intent(out) :: ovrlp
  !local variables
  integer :: i1,i2
  real(gp) :: a1,a2,c1,c2,govrlpr

  ovrlp=0.d0
  do i1=1,ng1
     a1=expo1(i1)
     a1=0.5_gp/a1**2
     c1=coeff1(i1)
     do i2=1,ng2
        a2=expo2(i2)
        a2=0.5_gp/a2**2
        c2=coeff2(i2)
        call gprod(a1,a2,dx,dy,dz,l1,m1,l2,m2,niw,nrw,iw,rw,govrlpr)
        govrlpr=c1*govrlpr*c2
        !print *,c1,c2,govrlpr
        ovrlp=ovrlp+govrlpr
     end do
  end do
  
end subroutine gbasovrlp


!overlap kinetic matrix between two different basis structures
!the kinetic operator is applicated on the A basis structure
subroutine kinetic_overlap(A,B,ovrlp)
  use module_base
  use module_types
  implicit none
  type(gaussian_basis), intent(in) :: A,B
  real(gp), dimension(A%ncoeff,B%ncoeff) :: ovrlp 
  !only lower triangular part for A%ncoeff=B%ncoeff
  !local variables
  integer, parameter :: niw=18,nrw=6
  integer :: ishell,iexpo,icoeff,ishellB,iexpoB,icoeffB,iat,jat,isat,isatB,jsat,jshell
  integer :: jstart,iovrlp,jovrlp,jcoeff,jexpo
  integer :: ngA,ngB,lA,lB,mA,mB
  real(gp) :: dx,dy,dz
  integer, dimension(niw) :: iw
  real(gp), dimension(nrw) :: rw

  iovrlp=0
  ishell=0
  iexpo=1
  icoeff=1

  !loop on each shell (intensive calculation)
  do iat=1,A%nat
     do isat=1,A%nshell(iat)
        ishell=ishell+1
        ngA=A%ndoc(ishell)
        lA=A%nam(ishell)
        do mA=1,2*lA-1
           iovrlp=iovrlp+1

           jovrlp=0
           jshell=0
           jexpo=1
           jcoeff=1

           do jat=1,B%nat
              dx=B%rxyz(1,jat)-A%rxyz(1,iat)
              dy=B%rxyz(2,jat)-A%rxyz(2,iat)
              dz=B%rxyz(3,jat)-A%rxyz(3,iat)
              do jsat=1,B%nshell(jat)
                 jshell=jshell+1
                 ngB=B%ndoc(jshell)
                 lB=B%nam(jshell)
                 do mB=1,2*lB-1
                    jovrlp=jovrlp+1
                    if (jovrlp >= iovrlp .and. A%ncoeff == B%ncoeff) then
                       call kineticovrlp(A%xp(iexpo),A%psiat(iexpo),&
                            B%xp(jexpo),B%psiat(jexpo),&
                            ngA,ngB,lA,mA,lB,mB,dx,dy,dz,&
                            niw,nrw,iw,rw,ovrlp(iovrlp,jovrlp))
                    end if
                 end do
                 jexpo=jexpo+ngB
                 jcoeff=jcoeff+2*lB-1
              end do
           end do
        end do
        iexpo=iexpo+ngA
        icoeff=icoeff+2*lA-1
     end do
  end do

  call gaudim_check(iexpo,icoeff,ishell,A%nexpo,A%ncoeff,A%nshltot)
  call gaudim_check(jexpo,jcoeff,jshell,B%nexpo,B%ncoeff,B%nshltot)
  
end subroutine kinetic_overlap

!calculates the scalar product between two shells
!by considering only the nonzero coefficients
!actual building block for calculating overlap matrix
!inserted work arrays for calculation
subroutine kineticovrlp(expo1,coeff1,expo2,coeff2,ng1,ng2,l1,m1,l2,m2,dx,dy,dz,&
     niw,nrw,iw,rw,ovrlp)
  use module_base
  implicit none
  integer, intent(in) :: ng1,ng2,l1,m1,l2,m2,niw,nrw
  real(gp), intent(in) :: dx,dy,dz
  integer, dimension(niw) :: iw
  real(gp), dimension(nrw) :: rw
  real(gp), dimension(ng1), intent(in) :: expo1,coeff1
  real(gp), dimension(ng2), intent(in) :: expo2,coeff2
  real(gp), intent(out) :: ovrlp
  !local variables
  integer :: i1,i2
  real(gp) :: a1,a2,c1,c2,govrlpr

  ovrlp=0.d0
  do i1=1,ng1
     a1=expo1(i1)
     a1=0.5_gp/a1**2
     c1=coeff1(i1)
     do i2=1,ng2
        a2=expo2(i2)
        a2=0.5_gp/a2**2
        c2=coeff2(i2)
        call kinprod(a1,a2,dx,dy,dz,l1,m1,l2,m2,niw,nrw,iw,rw,govrlpr)
        govrlpr=c1*govrlpr*c2
        !print *,c1,c2,govrlpr
        ovrlp=ovrlp+govrlpr
     end do
  end do
  
end subroutine kineticovrlp


!overlap kinetic matrix between two different basis structures
!the kinetic operator is applicated on the A basis structure
subroutine potential_overlap(A,B,pot,n1,n2,n3,hx,hy,hz,ovrlp)
  use module_base
  use module_types
  implicit none
  integer, intent(in) :: n1,n2,n3
  real(gp), intent(in) :: hx,hy,hz
  type(gaussian_basis), intent(in) :: A,B
  real(wp), dimension(0:n1,0:n2,0:n3), intent(in) :: pot
  real(gp), dimension(A%ncoeff,B%ncoeff), intent(out) :: ovrlp 
  !only lower triangular part for A%ncoeff=B%ncoeff
  !local variables 
 integer, parameter :: niw=18,nrw=6
  integer :: ishell,iexpo,icoeff,ishellB,iexpoB,icoeffB,iat,jat,isat,isatB,jsat,jshell
  integer :: jstart,iovrlp,jovrlp,jcoeff,jexpo
  integer :: ngA,ngB,lA,lB,mA,mB
  real(gp) :: rxa,rya,rza,rxb,ryb,rzb
  integer, dimension(niw) :: iw
  real(gp), dimension(nrw) :: rw

  iovrlp=0
  ishell=0
  iexpo=1
  icoeff=1

  !loop on each shell (intensive calculation)
  do iat=1,A%nat
     do isat=1,A%nshell(iat)
        ishell=ishell+1
        ngA=A%ndoc(ishell)
        lA=A%nam(ishell)
        do mA=1,2*lA-1
           iovrlp=iovrlp+1

           jovrlp=0
           jshell=0
           jexpo=1
           jcoeff=1

           !here one may insert jat=iat if gaussians do not overlap
           do jat=1,B%nat
              rxa=A%rxyz(1,iat)
              rya=A%rxyz(2,iat)
              rza=A%rxyz(3,iat)

              rxb=B%rxyz(1,jat)
              ryb=B%rxyz(2,jat)
              rzb=B%rxyz(3,jat)

              do jsat=1,B%nshell(jat)
                 jshell=jshell+1
                 ngB=B%ndoc(jshell)
                 lB=B%nam(jshell)
                 do mB=1,2*lB-1
                    jovrlp=jovrlp+1
                    if (jovrlp >= iovrlp .and. A%ncoeff == B%ncoeff) then
                       call locpotovrlp(n1,n2,n3,pot,hx,hy,hz,A%xp(iexpo),A%psiat(iexpo),&
                            B%xp(jexpo),B%psiat(jexpo),&
                            ngA,ngB,lA,mA,lB,mB,rxa,rya,rza,rxb,ryb,rzb,niw,nrw,iw,rw,&
                            ovrlp(iovrlp,jovrlp))
                    end if
                 end do
                 jexpo=jexpo+ngB
                 jcoeff=jcoeff+2*lB-1
              end do
           end do
        end do
        iexpo=iexpo+ngA
        icoeff=icoeff+2*lA-1
     end do
  end do

  call gaudim_check(iexpo,icoeff,ishell,A%nexpo,A%ncoeff,A%nshltot)
  call gaudim_check(jexpo,jcoeff,jshell,B%nexpo,B%ncoeff,B%nshltot)
  
end subroutine potential_overlap


!!$!calculate the potential overlap via a successive application of a one dimensional
!!$!integration. Store the values for the remaining dimensions in the work array
!!$subroutine onedim_potovrlp
!!$  use module_base
!!$  implicit none
!!$  integer, intent(in) :: n,dat
!!$  
!!$  !local variables
!!$  ovrlp=0.d0
!!$  do ii1=1,ng1
!!$     a1=expo1(ii1)
!!$     a1=0.5_gp/a1**2
!!$     c1=coeff1(ii1)
!!$     do ii2=1,ng2
!!$        a2=expo2(ii2)
!!$        a2=0.5_gp/a2**2
!!$        c2=coeff2(ii2)
!!$        !calculate overall factor given by product of gaussian
!!$        exp_new=a1*a2/(a1+a2)
!!$        expn=exp_new*(ra-rb)**2
!!$        factor=c1*c2*exp(-expn)
!!$        ovrlp=0.0_gp
!!$        if (factor > 1.e-8_gp) then
!!$           xmean=rmean(a1,a2,ra,rb)
!!$           cutoff=5._gp*sqrt(0.5_gp/(a1+a2))
!!$           !limits for integration of the potential
!!$           is=floor((xmean-cutoff)/hgrid)
!!$           ie=ceiling((xmean+cutoff)/hgrid)
!!$        
!!$           povrlp=0.0_gp
!!$           do i=is,ie
!!$              call ind_gauss(.false.,i,0,n,j,go)
!!$              if (gox) then
!!$                 x=real(i,gp)*hgrid-xmean
!!$                 xa=real(i,gp)*hgrid-ra
!!$                 xb=real(i,gp)*hgrid-rb
!!$                 prodgaus=exp(-(a1+a2)*x**2)
!!$                 polb=0.0_gp
!!$                 do iii2=1,n2
!!$                    polb=polb+fb*(xb**q)
!!$                 end do
!!$                 pola=0.0_gp
!!$                 do iii1=1,n1
!!$                    pola=pola+fa*(xa**p)
!!$                 end do
!!$                 prodgaus=prodgaus*pola*polb
!!$                 povrlp=povrlp+pot(j1,j2,j3)*prodgaus
!!$              end if
!!$           enddo
!!$        end if
!!$        ovrlp=ovrlp+factor*povrlp
!!$     end do
!!$  end do
!!$  
!!$
!!$end subroutine onedim_potovrlp

subroutine locpotovrlp(n1i,n2i,n3i,pot,hx,hy,hz,expo1,coeff1,expo2,coeff2,&
     ng1,ng2,l1,m1,l2,m2,rxa,rya,rza,rxb,ryb,rzb,niw,nrw,iw,rw,ovrlp)
  use module_base
  implicit none
  integer, intent(in) :: ng1,ng2,l1,m1,l2,m2,niw,nrw,n1i,n2i,n3i
  real(gp), intent(in) :: rxa,rya,rza,rxb,ryb,rzb,hx,hy,hz
  integer, dimension(niw) :: iw
  real(gp), dimension(nrw) :: rw
  real(gp), dimension(ng1), intent(in) :: expo1,coeff1
  real(gp), dimension(ng2), intent(in) :: expo2,coeff2
  real(wp), dimension(n1i,n2i,n3i), intent(in) :: pot
  real(gp), intent(out) :: ovrlp
  !local variables
  integer, parameter :: nx=3
  logical :: gox,goy,goz
  integer :: ii1,ii2,j1,j2,j3,i1,i2,i3,isx,isy,isz,iex,iey,iez
  integer :: iii1,iii2,iii3,px,py,pz,qx,qy,qz,n1,n2
  real(gp) :: a1,a2,c1,c2,rmean,xmean,ymean,zmean,prodgau,cutoff,xa,ya,za,xb,yb,zb,polynom
  real(gp) :: pola,polb,prodgaus,rx,ry,rz,nexp,expx,expy,expz,factor,fa,fb,povrlp,x,y,z


  !calculates the polynomials which multiply each product of gaussians
  call calc_coeff_inguess(l1,m1,nx,n1,&
       iw(1),iw(nx+1),iw(2*nx+1),rw(1))
  call calc_coeff_inguess(l2,m2,nx,n2,&
       iw(3*nx+1),iw(4*nx+1),iw(5*nx+1),rw(n1+1))


  ovrlp=0.0_gp
  do ii1=1,ng1
     a1=expo1(ii1)
     a1=0.5_gp/a1**2
     c1=coeff1(ii1)
     do ii2=1,ng2
        a2=expo2(ii2)
        a2=0.5_gp/a2**2
        c2=coeff2(ii2)
        !calculate overall factor given by product of gaussian
        nexp=a1*a2/(a1+a2)
        expx=nexp*(rxa-rxb)**2
        expy=nexp*(rya-ryb)**2
        expz=nexp*(rza-rzb)**2
        factor=c1*c2*exp(-expx-expy-expz)
        povrlp=0.0_gp
        if (factor > 1.e-8_gp) then

           xmean=rmean(a1,a2,rxa,rxb)
           ymean=rmean(a1,a2,rya,ryb)
           zmean=rmean(a1,a2,rza,rzb)
           cutoff=10._gp*sqrt(0.5_gp/(a1+a2))
           !limits for integration of the potential
           isx=floor((xmean-cutoff)/hx)
           isy=floor((ymean-cutoff)/hy)
           isz=floor((zmean-cutoff)/hz)

           iex=ceiling((xmean+cutoff)/hx)
           iey=ceiling((ymean+cutoff)/hy)
           iez=ceiling((zmean+cutoff)/hz)
         
           do i3=isz,iez
              call ind_gauss(.false.,i3,1,n3i,j3,goz) 
              if (goz) then
                 z=real(i3,gp)*hz-zmean
                 za=real(i3,gp)*hz-rza
                 zb=real(i3,gp)*hz-rzb
                 do i2=isy,iey
                    call ind_gauss(.false.,i2,1,n2i,j2,goy)
                    if (goy) then
                       y=real(i2,gp)*hy-ymean
                       ya=real(i2,gp)*hy-rya
                       yb=real(i2,gp)*hy-ryb
                       do i1=isx,iex
                          call ind_gauss(.false.,i1,1,n1i,j1,gox)
                          if (gox) then
                             x=real(i1,gp)*hx-xmean
                             xa=real(i1,gp)*hx-rxa
                             xb=real(i1,gp)*hx-rxb
                             polb=0.0_gp
                             do iii2=1,n2
                                qx=iw(3*nx+iii2)
                                qy=iw(4*nx+iii2)
                                qz=iw(5*nx+iii2)
                                fb=rw(n1+iii2)
                                polb=polb+polynom(fb,xb,yb,zb,qx,qy,qz)
                                !fb*(xb**qx)*(yb**qy)*(zb**qz)
                             end do
                             pola=0.0_gp
                             do iii1=1,n1
                                px=iw(iii1)
                                py=iw(nx+iii1)
                                pz=iw(2*nx+iii1)
                                fa=rw(iii1)
                                pola=pola+polynom(fa,xa,ya,za,px,py,pz)
                                !fa*(xa**px)*(ya**py)*(za**pz)
                             end do
                             prodgaus=exp(-(a1+a2)*(x**2+y**2+z**2))*pola*polb
                             povrlp=povrlp+pot(j1,j2,j3)*prodgaus
                          end if
                          !write(17,*)gox,i1,i2,i3,j1,j2,j3,isx,iex,pola,polb,prodgaus,pot(j1,j2,j3)
                       enddo
                    end if
                 enddo
              end if
           end do
        end if
        !print *,'limits:',isx,isy,isz,iex,iey,iez,xmean,ymean,zmean,povrlp
        ovrlp=ovrlp+factor*povrlp*hx*hy*hz
     end do
  end do
  
end subroutine locpotovrlp

function polynom(f,x,y,z,lx,ly,lz)
  use module_base
  implicit none
  integer, intent(in) :: lx,ly,lz
  real(gp), intent(in) :: f,x,y,z
  real(gp) :: polynom
  
  polynom=f
  if (lx /=0) then
     polynom=polynom*x**lx
  end if
  if (ly /=0) then
     polynom=polynom*y**ly
  end if
  if (lz /=0) then
     polynom=polynom*z**lz
  end if
  
end function polynom

function rmean(a1,a2,r1,r2)
  use module_base
  implicit none
  real(gp), intent(in) :: a1,a2,r1,r2
  real(gp) :: rmean
  
  rmean=a1*r1+a2*r2
  rmean=rmean/(a1+a2)

end function rmean

subroutine ind_gauss(periodic,i,is,n,j,go)
  implicit none
  logical, intent(in) :: periodic
  integer, intent(in) :: i,n,is
  logical, intent(out) :: go
  integer, intent(out) :: j

  if (periodic .and. is == 1) then
     go=.true.
     j=modulo(i,n+1)
  else if (.not. periodic) then
     j=i+15
     if (i >= is-15 .and. i <= n+is-16) then
        go=.true.
     else
        go=.false.
     end if
  else
     j=i
     if (i >= is .and. i <= n+is) then
        go=.true.
     else
        go=.false.
     end if
  end if

end subroutine ind_gauss
