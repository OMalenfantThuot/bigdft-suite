subroutine applylocpotkinall(iproc,norb,norbp,n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nbuf, & 
     hgrid,occup,nseg_c,nseg_f,nvctr_c,nvctr_f,keyg,keyv,&
     ibyz_c,ibxz_c,ibxy_c,ibyz_f,ibxz_f,ibxy_f, & 
     psi,pot,hpsi,epot_sum,ekin_sum,nspin,spinsgn,&
     ibzzx_c,ibyyzz_c,ibxy_ff,ibzzx_f,ibyyzz_f,&
     ibzxx_c,ibxxyy_c,ibyz_ff,ibzxx_f,ibxxyy_f,ibyyzz_r)
  !  Applies the local potential and kinetic energy operator to all wavefunctions belonging to processor
  ! Input: pot,psi
  ! Output: hpsi,epot,ekin
  use module_base
  implicit real(kind=8) (a-h,o-z)
  dimension ibyz_c(2,0:n2,0:n3),ibxz_c(2,0:n1,0:n3),ibxy_c(2,0:n1,0:n2)
  dimension ibyz_f(2,0:n2,0:n3),ibxz_f(2,0:n1,0:n3),ibxy_f(2,0:n1,0:n2)
  dimension occup(norb),pot((2*n1+31)*(2*n2+31)*(2*n3+31)*nspin),spinsgn(norb)
  dimension keyg(2,nseg_c+nseg_f),keyv(nseg_c+nseg_f)
  dimension psi(nvctr_c+7*nvctr_f,norbp)
  dimension hpsi(nvctr_c+7*nvctr_f,norbp)
  character(len=*), parameter :: subname='applylocpotkinall'
  real(kind=8), allocatable :: psir(:),y_c(:,:,:),y_f(:,:,:,:)

  !********************Alexey***************************************************************
  ! for shrink:
  integer ibzzx_c(2,-14:2*n3+16,0:n1) 
  integer ibyyzz_c(2,-14:2*n2+16,-14:2*n3+16)

  integer ibxy_ff(2,nfl1:nfu1,nfl2:nfu2)
  integer ibzzx_f(2,-14+2*nfl3:2*nfu3+16,nfl1:nfu1) 
  integer ibyyzz_f(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16)

  ! for grow:
  integer ibzxx_c(2,0:n3,-14:2*n1+16) ! extended boundary arrays
  integer ibxxyy_c(2,-14:2*n1+16,-14:2*n2+16)

  integer ibyz_ff(2,nfl2:nfu2,nfl3:nfu3)
  integer ibzxx_f(2,nfl3:nfu3,2*nfl1-14:2*nfu1+16)
  integer ibxxyy_f(2,2*nfl1-14:2*nfu1+16,2*nfl2-14:2*nfu2+16)

  ! for real space:
  integer,intent(in):: ibyyzz_r(2,-14:2*n2+16,-14:2*n3+16)

  real(kind=8), dimension(:,:,:), allocatable ::x_c !input 
  real(kind=8), dimension(:,:,:,:), allocatable::x_f,x_fc ! input
  real(kind=8), dimension(:,:,:), allocatable :: x_f1,x_f2,x_f3 ! input
  real(kind=8), dimension(:), allocatable :: w1,w2 

  ! shrink convention: nw1>nw2
  nw1=max((n3+1)*(2*n1+31)*(2*n2+31),&
       (n1+1)*(2*n2+31)*(2*n3+31),&
       2*(nfu1-nfl1+1)*(2*(nfu2-nfl2)+31)*(2*(nfu3-nfl3)+31),&
       2*(nfu3-nfl3+1)*(2*(nfu1-nfl1)+31)*(2*(nfu2-nfl2)+31))

  nw2=max(4*(nfu2-nfl2+1)*(nfu3-nfl3+1)*(2*(nfu1-nfl1)+31),&
       4*(nfu1-nfl1+1)*(nfu2-nfl2+1)*(2*(nfu3-nfl3)+31),&
       (n1+1)*(n2+1)*(2*n3+31),&
       (2*n1+31)*(n2+1)*(n3+1))

  allocate(y_c(0:n1,0:n2,0:n3+ndebug),stat=i_stat)
  call memocc(i_stat,y_c,'y_c',subname)
  allocate(y_f(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3+ndebug),stat=i_stat)
  call memocc(i_stat,y_f,'y_f',subname)
  ! Wavefunction in real space
  allocate(psir((2*n1+31)*(2*n2+31)*(2*n3+31)+ndebug),stat=i_stat)
  call memocc(i_stat,psir,'psir',subname)

  allocate(x_c(0:n1,0:n2,0:n3+ndebug),stat=i_stat)
  call memocc(i_stat,x_c,'x_c',subname)
  allocate(x_f(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3+ndebug),stat=i_stat)
  call memocc(i_stat,x_f,'x_f',subname)
  allocate(w1(nw1+ndebug),stat=i_stat)
  call memocc(i_stat,w1,'w1',subname)

    
  allocate(w2(nw2+ndebug),stat=i_stat)
  call memocc(i_stat,w2,'w2',subname)


  
  allocate(x_f1(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3+ndebug),stat=i_stat)
  call memocc(i_stat,x_f1,'x_f1',subname)
  allocate(x_f2(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3+ndebug),stat=i_stat)
  call memocc(i_stat,x_f2,'x_f2',subname)
  allocate(x_f3(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3+ndebug),stat=i_stat)
  call memocc(i_stat,x_f3,'x_f3',subname)

  call razero((nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1),x_f1)
  call razero((nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1),x_f2)
  call razero((nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1),x_f3)

  call razero((n1+1)*(n2+1)*(n3+1),x_c)
  call razero(7*(nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1),x_f)

  !to be initialised
  call razero((n1+1)*(n2+1)*(n3+1),y_c)
  call razero(7*(nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1),y_f)

  call razero((2*n1+31)*(2*n2+31)*(2*n3+31),psir)

  ekin_sum=0.d0
  epot_sum=0.d0
  do iorb=iproc*norbp+1,min((iproc+1)*norbp,norb)

     if(spinsgn(iorb)>0.0d0) then
        nsoffset=1
     else
        nsoffset=(2*n1+31)*(2*n2+31)*(2*n3+31)+1
     end if
     call applylocpotkinone(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nbuf, & 
          hgrid,nseg_c,nseg_f,nvctr_c,nvctr_f,keyg,keyv,  & 
          ibyz_c,ibxz_c,ibxy_c,ibyz_f,ibxz_f,ibxy_f,y_c,y_f,psir,  &
          psi(1,iorb-iproc*norbp),pot(nsoffset),hpsi(1,iorb-iproc*norbp),epot,ekin, & 
          x_c,x_f1,x_f2,x_f3,x_f,w1,w2,&
          ibzzx_c,ibyyzz_c,ibxy_ff,ibzzx_f,ibyyzz_f,&
          ibzxx_c,ibxxyy_c,ibyz_ff,ibzxx_f,ibxxyy_f,nw1,nw2,ibyyzz_r,1)
     ekin_sum=ekin_sum+occup(iorb)*ekin
     epot_sum=epot_sum+occup(iorb)*epot

  enddo

  i_all=-product(shape(x_f1))*kind(x_f1)
  deallocate(x_f1,stat=i_stat)
  call memocc(i_stat,i_all,'x_f1',subname)

  i_all=-product(shape(x_f2))*kind(x_f2)
  deallocate(x_f2,stat=i_stat)
  call memocc(i_stat,i_all,'x_f2',subname)

  i_all=-product(shape(x_f3))*kind(x_f3)
  deallocate(x_f3,stat=i_stat)
  call memocc(i_stat,i_all,'x_f3',subname)


  i_all=-product(shape(y_c))*kind(y_c)
  deallocate(y_c,stat=i_stat)
  call memocc(i_stat,i_all,'y_c',subname)
  
  i_all=-product(shape(y_f))*kind(y_f)
  deallocate(y_f,stat=i_stat)
  call memocc(i_stat,i_all,'y_f',subname)
  
  i_all=-product(shape(psir))*kind(psir)
  deallocate(psir,stat=i_stat)
  call memocc(i_stat,i_all,'psir',subname)

  i_all=-product(shape(x_c))*kind(x_c)
  deallocate(x_c,stat=i_stat)
  call memocc(i_stat,i_all,'x_c',subname)
 
  i_all=-product(shape(x_f))*kind(x_f)
  deallocate(x_f,stat=i_stat)
  call memocc(i_stat,i_all,'x_f',subname)

  i_all=-product(shape(w1))*kind(w1)
  deallocate(w1,stat=i_stat)
  call memocc(i_stat,i_all,'w1',subname)

  i_all=-product(shape(w2))*kind(w2)
  deallocate(w2,stat=i_stat)
  call memocc(i_stat,i_all,'w2',subname)

END SUBROUTINE applylocpotkinall

subroutine applylocpotkinone(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nbuf, & 
     hgrid,nseg_c,nseg_f,nvctr_c,nvctr_f,keyg,keyv,  & 
     ibyz_c,ibxz_c,ibxy_c,ibyz_f,ibxz_f,ibxy_f, & 
     y_c,y_f,psir,  &
     psi,pot,hpsi,epot,ekin,x_c,x_f1,x_f2,x_f3,x_f,w1,w2,&
     ibzzx_c,ibyyzz_c,ibxy_ff,ibzzx_f,ibyyzz_f,&
     ibzxx_c,ibxxyy_c,ibyz_ff,ibzxx_f,ibxxyy_f,nw1,nw2,ibyyzz_r,nspinor)!
  !  Applies the local potential and kinetic energy operator to one wavefunction 
  ! Input: pot,psi
  ! Output: hpsi,epot,ekin
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nbuf,nw1,nw2
  integer, intent(in) :: nseg_c,nseg_f,nvctr_c,nvctr_f,nspinor
  real(gp), intent(in) :: hgrid
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(2,0:n2,0:n3), intent(in) :: ibyz_c,ibyz_f
  integer, dimension(2,0:n1,0:n3), intent(in) :: ibxz_c,ibxz_f
  integer, dimension(2,0:n1,0:n2), intent(in) :: ibxy_c,ibxy_f
  integer, dimension(2,-14:2*n3+16,0:n1), intent(in) :: ibzzx_c
  integer, dimension(2,-14:2*n2+16,-14:2*n3+16), intent(in) :: ibyyzz_c
  integer, dimension(2,nfl1:nfu1,nfl2:nfu2), intent(in) :: ibxy_ff
  integer, dimension(2,-14+2*nfl3:2*nfu3+16,nfl1:nfu1), intent(in) :: ibzzx_f
  integer, dimension(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16), intent(in) :: ibyyzz_f
  integer, dimension(2,0:n3,-14:2*n1+16), intent(in) :: ibzxx_c
  integer, dimension(2,-14:2*n1+16,-14:2*n2+16), intent(in) :: ibxxyy_c
  integer, dimension(2,nfl2:nfu2,nfl3:nfu3), intent(in) :: ibyz_ff
  integer, dimension(2,nfl3:nfu3,2*nfl1-14:2*nfu1+16), intent(in) :: ibzxx_f
  integer, dimension(2,2*nfl1-14:2*nfu1+16,2*nfl2-14:2*nfu2+16), intent(in) :: ibxxyy_f
  integer, dimension(2,-14:2*n2+16,-14:2*n3+16), intent(in) :: ibyyzz_r
  real(wp), dimension(nvctr_c+7*nvctr_f,nspinor), intent(in) :: psi
  real(wp), dimension((2*n1+31)*(2*n2+31)*(2*n3+31),nspinor), intent(in) :: pot
  real(wp), dimension(nw1,nspinor), intent(inout) :: w1
  real(wp), dimension(nw2,nspinor), intent(inout) :: w2
  real(wp), dimension(0:n1,0:n2,0:n3,nspinor), intent(inout) :: y_c
  real(wp), dimension(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,nspinor), intent(inout) :: y_f
  real(wp), dimension((2*n1+31)*(2*n2+31)*(2*n3+31),nspinor), intent(inout) :: psir
  real(wp), dimension(0:n1,0:n2,0:n3,nspinor), intent(inout) :: x_c
  real(wp), dimension(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,nspinor), intent(inout) :: x_f
  real(wp), dimension(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,NSPINOR),intent(inout) :: x_f1
  real(wp), dimension(nfl2:nfu2,nfl1:nfu1,nfl3:nfu3,NSPINOR),intent(inout) :: x_f2
  real(wp), dimension(nfl3:nfu3,nfl1:nfu1,nfl2:nfu2,NSPINOR),intent(inout) :: x_f3
  real(gp), intent(out) :: epot,ekin
  real(wp), dimension(nvctr_c+7*nvctr_f,nspinor), intent(out) :: hpsi
  !local variables
  integer :: i,idx
  real(gp) :: ekino
  real(wp), dimension(0:3) :: scal

  do i=0,3
     scal(i)=1.0_wp
  enddo

  call razero((2*n1+31)*(2*n2+31)*(2*n3+31)*nspinor,psir)

  do idx=1,nspinor  
     call uncompress_forstandard(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,  & 
          nseg_c,nvctr_c,keyg(1,1),keyv(1),  & 
          nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   &
          scal,psi(1,IDX),psi(nvctr_c+1,IDX),  &
          x_c(0,0,0,idx),x_f(1,nfl1,nfl2,nfl3,idx),&
          x_f1(nfl1,nfl2,nfl3,idx),x_f2(nfl2,nfl1,nfl3,idx),x_f3(nfl3,nfl1,nfl2,idx))
     
     call comb_grow_all(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
          w1(1,IDX),w2(1,IDX), x_c(0,0,0,idx),x_f(1,nfl1,nfl2,nfl3,idx), & 
          psir(1,IDX),ibyz_c,ibzxx_c,ibxxyy_c,ibyz_ff,ibzxx_f,ibxxyy_f,ibyyzz_r)
     
  END DO

  IF (NSPINOR==1) THEN
     if (nbuf.eq.0) then
        call realspace(ibyyzz_r,pot,psir,epot,n1,n2,n3)
     else
        call realspace_nbuf(ibyyzz_r,pot,psir,epot,n1,n2,n3,nbuf)
     endif
  ELSE
     epot=0.0_gp
     call realspaceINPLACE(ibyyzz_r,pot,psir,epot,n1,n2,n3)
  END IF
  
  
  ekin=0.0_gp
  do idx=1,nspinor
     call comb_shrink(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
          w1(1,IDX),w2(1,IDX),psir(1,IDX),&
          ibxy_c,ibzzx_c,ibyyzz_c,ibxy_ff,ibzzx_f,ibyyzz_f,&
          y_c(0,0,0,IDX),y_f(1,nfl1,nfl2,nfl3,IDX))!,ibyz_c,ibyz_f)
     
     call ConvolkineticT(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,  &
          hgrid,ibyz_c,ibxz_c,ibxy_c,ibyz_f,ibxz_f,ibxy_f, &
          x_c(0,0,0,IDX),x_f(1,nfl1,nfl2,nfl3,IDX),y_c(0,0,0,IDX),y_f(1,nfl1,nfl2,nfl3,IDX),EKINO, &
          x_f1(nfl1,nfl2,nfl3,IDX),x_f2(nfl2,nfl1,nfl3,IDX),x_f3(nfl3,nfl1,nfl2,IDX))
     ekin=ekin+ekino
     
     call compress_forstandard(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,  &
          nseg_c,nvctr_c,keyg(1,1),       keyv(1),   &
          nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   &
          scal,y_c(0,0,0,IDX),y_f(1,nfl1,nfl2,nfl3,IDX),hpsi(1,IDX),hpsi(nvctr_c+1,IDX))
  end do
  
end subroutine applylocpotkinone


subroutine applylocpotkinone_per(n1,n2,n3, & 
     hx,hy,hz,nseg_c,nseg_f,nvctr_c,nvctr_f,keyg,keyv,  & 
     psir,psifscf,psifscfk,psig,ww,psi,pot,hpsi,epot,ekin)
  !  Applies the local potential and kinetic energy operator to one wavefunction 
  ! Input: pot,psi
  ! Output: hpsi,epot,ekin
  use module_base
  implicit none
  integer, intent(in) :: n1,n2,n3,nseg_c,nseg_f,nvctr_c,nvctr_f
  real(gp), intent(in) :: hx,hy,hz
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  real(wp), dimension((2*n1+2)*(2*n2+2)*(2*n3+2)), intent(in) :: pot
  real(wp), dimension(nvctr_c+7*nvctr_f), intent(in) :: psi
  real(wp), dimension((2*n1+2)*(2*n2+2)*(2*n3+2)), intent(inout) :: psir,psifscf,psifscfk,ww
  real(wp), dimension(0:n1,2,0:n2,2,0:n3,2), intent(inout) :: psig
  real(gp), intent(out) :: epot,ekin
  real(wp), dimension(nvctr_c+7*nvctr_f), intent(out) :: hpsi
  !local variables
  integer :: i
  real(wp) :: tt
  real(gp) :: v,p
  real(gp), dimension(3) :: hgridh

  ! Wavefunction expressed everywhere in fine scaling functions (for potential and kinetic energy)
  call uncompress_per(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   &
       nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   &
       psi(1),psi(nvctr_c+1),psifscf,psig,ww)

  hgridh(1)=hx*.5_gp
  hgridh(2)=hy*.5_gp
  hgridh(3)=hz*.5_gp

  call convolut_kinetic_per(2*n1+1,2*n2+1,2*n3+1,hgridh,psifscf,psifscfk)

  ekin=0.0_gp
  do i=1,(2*n1+2)*(2*n2+2)*(2*n3+2)
     ekin=ekin+real(psifscf(i),gp)*real(psifscfk(i),gp)
  enddo

  call convolut_magic_n_per(2*n1+1,2*n2+1,2*n3+1,psifscf,psir) 

  epot=0.0_gp
  do i=1,(2*n1+2)*(2*n2+2)*(2*n3+2)
     v=real(pot(i),gp)
     p=real(psir(i),gp)
     tt=pot(i)*psir(i)
     epot=epot+p*v*p
     psir(i)=tt
  enddo

  call convolut_magic_t_per(2*n1+1,2*n2+1,2*n3+1,psir,psifscf)

  do i=1,(2*n1+2)*(2*n2+2)*(2*n3+2)
     psifscf(i)=psifscf(i)+psifscfk(i)
  enddo

  call compress_per(n1,n2,n3,nseg_c,nvctr_c,keyg(1,1),keyv(1),   & 
       nseg_f,nvctr_f,keyg(1,nseg_c+1),keyv(nseg_c+1),   & 
       psifscf,hpsi(1),hpsi(nvctr_c+1),psig,ww)

END SUBROUTINE applylocpotkinone_per

subroutine realspace(ibyyzz_r,pot,psir,epot,n1,n2,n3)
  implicit none
  integer,intent(in)::n1,n2,n3
  integer,intent(in)::ibyyzz_r(2,-14:2*n2+16,-14:2*n3+16)
  real(kind=8),intent(in)::pot(-14:2*n1+16,-14:2*n2+16,-14:2*n3+16)
  real(kind=8),intent(inout)::psir(-14:2*n1+16,-14:2*n2+16,-14:2*n3+16)

  real(kind=8),intent(out)::epot
  real(kind=8) tt
  integer i1,i2,i3

  epot=0.d0
  do i3=-14,2*n3+16
     do i2=-14,2*n2+16
        do i1=max(ibyyzz_r(1,i2,i3)-14,-14),min(ibyyzz_r(2,i2,i3)-14,2*n1+16)
           tt=pot(i1,i2,i3)*psir(i1,i2,i3)
           epot=epot+tt*psir(i1,i2,i3)
           psir(i1,i2,i3)=tt
        enddo
     enddo
  enddo

end subroutine realspace

subroutine realspace_nbuf(ibyyzz_r,pot,psir,epot,nb1,nb2,nb3,nbuf)
  implicit none
  integer,intent(in)::nb1,nb2,nb3,nbuf
  integer,intent(in)::ibyyzz_r(2,-14:2*nb2+16,-14:2*nb3+16)
  real(kind=8),intent(in)::pot(-14:2*nb1+16-4*nbuf,-14:2*nb2+16-4*nbuf,-14:2*nb3+16-4*nbuf)
  real(kind=8),intent(inout)::psir(-14:2*nb1+16,-14:2*nb2+16,-14:2*nb3+16)

  real(kind=8),intent(out)::epot
  real(kind=8) tt,dnrm2
  integer i1,i2,i3

  epot=0.d0
  do i3=-14,2*nb3+16
     if (i3.ge.-14+2*nbuf .and. i3.le.2*nb3+16-2*nbuf) then
        do i2=-14,2*nb2+16
           if (i2.ge.-14+2*nbuf .and. i2.le.2*nb2+16-2*nbuf) then
              do i1=-14+2*nbuf,ibyyzz_r(1,i2,i3)-14-1
                 psir(i1,i2,i3)=0.d0
              enddo
              do i1=max(ibyyzz_r(1,i2,i3)-14,-14+2*nbuf),min(ibyyzz_r(2,i2,i3)-14,2*nb1+16-2*nbuf)
                 tt=pot(i1-2*nbuf,i2-2*nbuf,i3-2*nbuf)*psir(i1,i2,i3)
                 epot=epot+tt*psir(i1,i2,i3)
                 psir(i1,i2,i3)=tt
              enddo
              do i1=ibyyzz_r(2,i2,i3)-14+1,2*nb1+16-2*nbuf
                 psir(i1,i2,i3)=0.d0
              enddo
           else
              do i1=-14,2*nb1+16
                 psir(i1,i2,i3)=0.d0
              enddo
           endif
        enddo
     else
        do i2=-14,2*nb2+16
           do i1=-14,2*nb1+16
              psir(i1,i2,i3)=0.d0
           enddo
        enddo
     endif
  enddo

end subroutine realspace_nbuf


subroutine realspaceINOUT(ibyyzz_r,pot,psirIN,psirOUT,epot,n1,n2,n3)
  implicit none
  integer,intent(in)::n1,n2,n3
  integer,intent(in)::ibyyzz_r(2,-14:2*n2+16,-14:2*n3+16)

  real(kind=8),intent(in)::pot(-14:2*n1+16,-14:2*n2+16,-14:2*n3+16)
  real(kind=8),intent(in)::psirIN(-14:2*n1+16,-14:2*n2+16,-14:2*n3+16)
 real(kind=8),intent(out)::psirOUT(-14:2*n1+16,-14:2*n2+16,-14:2*n3+16)

  real(kind=8),intent(out)::epot
  real(kind=8) tt
  integer i1,i2,i3

  epot=0.d0
  do i3=-14,2*n3+16
     do i2=-14,2*n2+16
        do i1=max(ibyyzz_r(1,i2,i3)-14,-14),min(ibyyzz_r(2,i2,i3)-14,2*n1+16)
           tt=pot(i1,i2,i3)*psirIN(i1,i2,i3)
           epot=epot+tt*psirIN(i1,i2,i3)
           psirOUT(i1,i2,i3)=psirOUT(i1,i2,i3)+tt
        enddo
     enddo
  enddo

end subroutine realspaceINOUT

subroutine realspaceINOUT_nbuf(ibyyzz_r,pot,psirIN,psirOUT,epot,nb1,nb2,nb3,nbuf)
  implicit none
  integer,intent(in)::nb1,nb2,nb3,nbuf
  integer,intent(in)::ibyyzz_r(2,-14:2*nb2+16,-14:2*nb3+16)
  real(kind=8),intent(in)::pot(-14:2*nb1+16-4*nbuf,-14:2*nb2+16-4*nbuf,-14:2*nb3+16-4*nbuf)
  real(kind=8),intent(in)::psirIN(-14:2*nb1+16,-14:2*nb2+16,-14:2*nb3+16)
  real(kind=8),intent(out)::psirOUT(-14:2*nb1+16,-14:2*nb2+16,-14:2*nb3+16)

  real(kind=8),intent(out)::epot
  real(kind=8) tt,dnrm2
  integer i1,i2,i3

  epot=0.d0
  do i3=-14,2*nb3+16
     if (i3.ge.-14+2*nbuf .and. i3.le.2*nb3+16-2*nbuf) then
        do i2=-14,2*nb2+16
           if (i2.ge.-14+2*nbuf .and. i2.le.2*nb2+16-2*nbuf) then
              do i1=-14+2*nbuf,ibyyzz_r(1,i2,i3)-14-1
                 psirOUT(i1,i2,i3)=0.d0
              enddo
              do i1=max(ibyyzz_r(1,i2,i3)-14,-14+2*nbuf),min(ibyyzz_r(2,i2,i3)-14,2*nb1+16-2*nbuf)
                 tt=pot(i1-2*nbuf,i2-2*nbuf,i3-2*nbuf)*psirIN(i1,i2,i3)
                 epot=epot+tt*psirIN(i1,i2,i3)
                 psirOUT(i1,i2,i3)=tt
              enddo
              do i1=ibyyzz_r(2,i2,i3)-14+1,2*nb1+16-2*nbuf
                 psirOUT(i1,i2,i3)=0.d0
              enddo
           else
              do i1=-14,2*nb1+16
                 psirOUT(i1,i2,i3)=0.d0
              enddo
           endif
        enddo
     else
        do i2=-14,2*nb2+16
           do i1=-14,2*nb1+16
              psirOUT(i1,i2,i3)=0.d0
           enddo
        enddo
     endif
  enddo

end subroutine realspaceINOUT_nbuf

subroutine realspaceINPLACE(ibyyzz_r,pot,psir,epot,n1,n2,n3)
  implicit none
  integer,intent(in)::n1,n2,n3
  integer,intent(in)::ibyyzz_r(2,-14:2*n2+16,-14:2*n3+16)

  real(kind=8),intent(in)::pot(-14:2*n1+16,-14:2*n2+16,-14:2*n3+16,4)
  real(kind=8),intent(inout)::psir(-14:2*n1+16,-14:2*n2+16,-14:2*n3+16,4)

  real(kind=8),intent(out)::epot
  real(kind=8) tt11,tt22,tt33,tt44,tt13,tt14,tt23,tt24,tt31,tt32,tt41,tt42
  integer i1,i2,i3

  epot=0.d0
  do i3=-14,2*n3+16
     do i2=-14,2*n2+16
        do i1=max(ibyyzz_r(1,i2,i3)-14,-14),min(ibyyzz_r(2,i2,i3)-14,2*n1+16)
           !diagonal terms
           tt11=pot(i1,i2,i3,1)*psir(i1,i2,i3,1) !p1
           tt22=pot(i1,i2,i3,1)*psir(i1,i2,i3,2) !p2
           tt33=pot(i1,i2,i3,4)*psir(i1,i2,i3,3) !p3
           tt44=pot(i1,i2,i3,4)*psir(i1,i2,i3,4) !p4
           !Rab*Rb
           tt13=pot(i1,i2,i3,2)*psir(i1,i2,i3,3) !p1
           !Iab*Ib
           tt14=pot(i1,i2,i3,3)*psir(i1,i2,i3,4) !p1
           !Rab*Ib
           tt23=pot(i1,i2,i3,2)*psir(i1,i2,i3,4) !p2
           !Iab*Rb
           tt24=pot(i1,i2,i3,3)*psir(i1,i2,i3,3) !p2
           !Rab*Ra
           tt31=pot(i1,i2,i3,2)*psir(i1,i2,i3,1) !p3
           !Iab*Ia
           tt32=pot(i1,i2,i3,3)*psir(i1,i2,i3,2) !p3
           !Rab*Ia
           tt41=pot(i1,i2,i3,2)*psir(i1,i2,i3,2) !p4
           !Iab*Ra
           tt42=pot(i1,i2,i3,3)*psir(i1,i2,i3,1) !p4
           ! Change epot later
           epot=epot+tt11*psir(i1,i2,i3,1)+tt22*psir(i1,i2,i3,2)+tt33*psir(i1,i2,i3,3)+tt44*psir(i1,i2,i3,4)+&
                2.0d0*tt31*psir(i1,i2,i3,3)-2.0d0*tt42*psir(i1,i2,i3,4)+2.0d0*tt41*psir(i1,i2,i3,4)+2.0d0*tt32*psir(i1,i2,i3,3)
!p1=h1p1+h2p3-h3p4
!p2=h1p2+h2p4+h3p3
!p3=h2p1+h3p2+h4p3
!p4=h2p2-h3p1+h4p4
           psir(i1,i2,i3,1)=tt11+tt13-tt14
           psir(i1,i2,i3,2)=tt22+tt23+tt24
           psir(i1,i2,i3,3)=tt33+tt31+tt32
           psir(i1,i2,i3,4)=tt44+tt41-tt42
        enddo
     enddo
  enddo

end subroutine realspaceINPLACE


subroutine applyprojectorsone(ntypes,nat,iatype,psppar,npspcode, &
     nprojel,nproj,nseg_p,keyg_p,keyv_p,nvctr_p,proj,  &
     nseg_c,nseg_f,keyg,keyv,nvctr_c,nvctr_f,psi,hpsi,eproj)
  ! Applies all the projectors onto a single wavefunction
  ! Input: psi_c,psi_f
  ! In/Output: hpsi_c,hpsi_f (both are updated, i.e. not initilized to zero at the beginning)
  implicit real(kind=8) (a-h,o-z)
  dimension psppar(0:4,0:6,ntypes),iatype(nat),npspcode(ntypes)
  dimension keyg(2,nseg_c+nseg_f),keyv(nseg_c+nseg_f)
  dimension psi(nvctr_c+7*nvctr_f),hpsi(nvctr_c+7*nvctr_f)
  dimension nseg_p(0:2*nat),nvctr_p(0:2*nat)
  dimension keyg_p(2,nseg_p(2*nat)),keyv_p(nseg_p(2*nat))
  dimension proj(nprojel)

  ! loop over all projectors
  iproj=0
  eproj=0.d0
  istart_c=1
  do iat=1,nat
     mbseg_c=nseg_p(2*iat-1)-nseg_p(2*iat-2)
     mbseg_f=nseg_p(2*iat  )-nseg_p(2*iat-1)
     jseg_c=nseg_p(2*iat-2)+1
     jseg_f=nseg_p(2*iat-1)+1
     mbvctr_c=nvctr_p(2*iat-1)-nvctr_p(2*iat-2)
     mbvctr_f=nvctr_p(2*iat  )-nvctr_p(2*iat-1)
     ityp=iatype(iat)
     !GTH and HGH pseudopotentials
     do l=1,4
        do i=1,3
           if (psppar(l,i,ityp).ne.0.d0) then
           call applyprojector(l,i,psppar(0,0,ityp),npspcode(ityp),&
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv,keyg,&
                mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyg_p(1,jseg_c),proj(istart_c),&
                psi,hpsi,eproj)
           iproj=iproj+2*l-1
           istart_c=istart_c+(mbvctr_c+7*mbvctr_f)*(2*l-1)

              !start of the routine for projectors application
!!$              do m=1,2*l-1
!!$                 iproj=iproj+1
!!$                 istart_f=istart_c+mbvctr_c
!!$                 call wpdot(  &
!!$                      nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                      keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
!!$                      mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                      keyg_p(1,jseg_c),keyg_p(1,jseg_f),proj(istart_c),proj(istart_f),scpr)
!!$
!!$                 ! ! test (will sometimes give wrong result)
!!$                 ! call wpdot(  &
!!$                 !      mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                 !      keyg_p(1,jseg_c),keyg_p(1,jseg_f),proj(istart_c),proj(istart_f),  &
!!$                 !      nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                 !      keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),tcpr)
!!$                 ! if (scpr.ne.tcpr) then
!!$                 !    print *,'projectors: scpr.ne.tcpr'
!!$                 !    print *,'l,i,m,h_i^l=',l,i,m,psppar(l,i,ityp)
!!$                 !    print *,'scpr,tcpr',scpr,tcpr
!!$                 !    stop 
!!$                 ! end if
!!$                 ! ! testend
!!$                 
!!$                 scprp=scpr*psppar(l,i,ityp)
!!$                 eproj=eproj+scprp*scpr
!!$
!!$                 call waxpy(&
!!$                      scprp,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                      keyg_p(1,jseg_c),keyg_p(1,jseg_f),proj(istart_c),proj(istart_f),  &
!!$                      nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                      keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))
!!$
!!$                 istart_c=istart_f+7*mbvctr_f
!!$              enddo
!!$              if (npspcode(ityp) == 3 .and. l/=4 .and. i/=3) then !HGH case, offdiagonal terms
!!$                 loop_j: do j=i+1,3
!!$                    if (psppar(l,j,ityp) .eq. 0.d0) exit loop_j
!!$                    !calculate the coefficients for the off-diagonal terms
!!$                    if (l==1) then
!!$                       if (i==1) then
!!$                          if (j==2) offdiagcoeff=-0.5d0*sqrt(3.d0/5.d0)
!!$                          if (j==3) offdiagcoeff=0.5d0*sqrt(5.d0/21.d0)
!!$                       else
!!$                          offdiagcoeff=-0.5d0*sqrt(100.d0/63.d0)
!!$                       end if
!!$                    else if (l==2) then
!!$                       if (i==1) then
!!$                          if (j==2) offdiagcoeff=-0.5d0*sqrt(5.d0/7.d0)
!!$                          if (j==3) offdiagcoeff=1.d0/6.d0*sqrt(35.d0/11.d0)
!!$                       else
!!$                          offdiagcoeff=-7.d0/3.d0*sqrt(1.d0/11.d0)
!!$                       end if
!!$                    else if (l==3) then
!!$                       if (i==1) then
!!$                          if (j==2) offdiagcoeff=-0.5d0*sqrt(7.d0/9.d0)
!!$                          if (j==3) offdiagcoeff=0.5d0*sqrt(63.d0/143.d0)
!!$                       else
!!$                          offdiagcoeff=-9.d0*sqrt(1.d0/143.d0)
!!$                       end if
!!$                    end if
!!$                    istart_c_i=istart_c-(2*l-1)*(mbvctr_c+7*mbvctr_f)
!!$                    istart_c_j=istart_c_i+(j-i)*(2*l-1)*(mbvctr_c+7*mbvctr_f)
!!$                    do m=1,2*l-1
!!$                       !starting addresses of the projectors
!!$                       istart_f_j=istart_c_j+mbvctr_c
!!$                       istart_f_i=istart_c_i+mbvctr_c
!!$                       call wpdot(&
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
!!$                            mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_j),proj(istart_f_j),scpr_j)
!!$
!!$                       call wpdot(&
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
!!$                            mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_i),proj(istart_f_i),scpr_i)
!!$
!!$
!!$                       scprp_j=scpr_j*offdiagcoeff*psppar(l,j,ityp)
!!$                       scprp_i=scpr_i*offdiagcoeff*psppar(l,j,ityp)
!!$                       !scpr_i*h_ij*scpr_j+scpr_j*h_ij*scpr_i
!!$                       eproj=eproj+2.d0*scprp_j*scpr_i
!!$
!!$                       !|hpsi>=|hpsi>+h_ij (<p_i|psi>|p_j>+<p_j|psi>|p_i>)
!!$                       call waxpy(&
!!$                            scprp_j,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
!!$                            keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_i),proj(istart_f_i),  &
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))
!!$
!!$                       call waxpy(&
!!$                            scprp_i,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
!!$                            keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_j),proj(istart_f_j),  &
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))
!!$
!!$                       istart_c_j=istart_f_j+7*mbvctr_f
!!$                       istart_c_i=istart_f_i+7*mbvctr_f
!!$                    enddo
!!$                 end do loop_j
!!$              else if (npspcode(ityp) == 10 .and. i/=3) then !HGH-K case, offdiagonal terms
!!$                 loop_jK: do j=i+1,3
!!$                    if (psppar(l,j,ityp) .eq. 0.d0) exit loop_jK
!!$                    istart_c_i=istart_c-(2*l-1)*(mbvctr_c+7*mbvctr_f)
!!$                    istart_c_j=istart_c_i+(j-i)*(2*l-1)*(mbvctr_c+7*mbvctr_f)
!!$                    do m=1,2*l-1
!!$                       !starting addresses of the projectors
!!$                       istart_f_j=istart_c_j+mbvctr_c
!!$                       istart_f_i=istart_c_i+mbvctr_c
!!$                       call wpdot(&
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
!!$                            mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_j),proj(istart_f_j),scpr_j)
!!$
!!$                       call wpdot(&
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
!!$                            mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_i),proj(istart_f_i),scpr_i)
!!$
!!$                       !scpr_i*h_ij*scpr_j+scpr_j*h_ij*scpr_i (with symmetric h_ij)
!!$                       eproj=eproj+2.d0*scpr_i*psppar(l,i+j+1,ityp)*scpr_j
!!$                       scprp_j=scpr_j*psppar(l,i+j+1,ityp)
!!$                       scprp_i=scpr_i*psppar(l,i+j+1,ityp)
!!$
!!$                       !|hpsi>=|hpsi>+h_ij (<p_i|psi>|p_j>+<p_j|psi>|p_i>)
!!$                       call waxpy(&
!!$                            scprp_j,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
!!$                            keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_i),proj(istart_f_i),  &
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))
!!$
!!$                       call waxpy(&
!!$                            scprp_i,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
!!$                            keyv_p(jseg_c),keyv_p(jseg_f),  &
!!$                            keyg_p(1,jseg_c),keyg_p(1,jseg_f),&
!!$                            proj(istart_c_j),proj(istart_f_j),  &
!!$                            nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                            keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))
!!$
!!$                       istart_c_j=istart_f_j+7*mbvctr_f
!!$                       istart_c_i=istart_f_i+7*mbvctr_f
!!$                    enddo
!!$                 end do loop_jK
!!$              end if
           end if
        enddo
     enddo
  enddo
  if (iproj.ne.nproj) stop '1:applyprojectorsone'
  if (istart_c-1.ne.nprojel) stop '2:applyprojectorsone'

end subroutine applyprojectorsone


subroutine applyprojector(l,i,psppar,npspcode,&
     nvctr_c,nvctr_f,nseg_c,nseg_f,keyv,keyg,&
     mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p,keyg_p,proj,psi,hpsi,eproj)
  use module_base
  implicit none
  integer, intent(in) :: i,l,npspcode
  integer, intent(in) :: nvctr_c,nvctr_f,nseg_c,nseg_f,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f
  real(gp), intent(inout) :: eproj
  integer, dimension(nseg_c+nseg_f), intent(in) :: keyv
  integer, dimension(2,nseg_c+nseg_f), intent(in) :: keyg
  integer, dimension(mbseg_c+mbseg_f), intent(in) :: keyv_p
  integer, dimension(2,mbseg_c+mbseg_f), intent(in) :: keyg_p
  real(wp), dimension((mbvctr_c+7*mbvctr_f)*(2*l-1)), intent(in) :: proj
  real(gp), dimension(0:4,0:6), intent(in) :: psppar
  real(wp), dimension(nvctr_c+7*nvctr_f), intent(in) :: psi
  real(wp), dimension(nvctr_c+7*nvctr_f), intent(inout) :: hpsi
  !local variables
  integer :: j,m,istart_c,istart_f,istart_c_i,istart_c_j,istart_f_i,istart_f_j
  real(dp) :: scpr,scprp,scpr_i,scprp_i,scpr_j,scprp_j
  real(gp) :: offdiagcoeff

  istart_c=1
  !start of the routine for projectors application
  do m=1,2*l-1
     istart_f=istart_c+mbvctr_c
     call wpdot(  &
          nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
          keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
          mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(1),keyv_p(mbseg_c+1),  &
          keyg_p(1,1),keyg_p(1,mbseg_c+1),proj(istart_c),proj(istart_f),scpr)

!!$                 ! test (will sometimes give wrong result)
!!$                 call wpdot(  &
!!$                      mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(1),keyv_p(mbseg_c+1),  &
!!$                      keyg_p(1,1),keyg_p(1,mbseg_c+1),proj(istart_c),proj(istart_f),  &
!!$                      nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
!!$                      keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),tcpr)
!!$                 if (scpr.ne.tcpr) then
!!$                    print *,'projectors: scpr.ne.tcpr'
!!$                    print *,'l,i,m,h_i^l=',l,i,m,psppar(l,i)
!!$                    print *,'scpr,tcpr',scpr,tcpr
!!$                    stop 
!!$                 end if
!!$                 ! testend

     scprp=scpr*real(psppar(l,i),dp)
     eproj=eproj+real(scprp,gp)*real(scpr,gp)

     call waxpy(&
          scprp,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(1),keyv_p(mbseg_c+1),  &
          keyg_p(1,1),keyg_p(1,mbseg_c+1),proj(istart_c),proj(istart_f),  &
          nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
          keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))

     istart_c=istart_f+7*mbvctr_f
  enddo
  if (npspcode == 3 .and. l/=4 .and. i/=3) then !HGH case, offdiagonal terms
     loop_j: do j=i+1,3
        if (psppar(l,j) .eq. 0.0_gp) exit loop_j
        !calculate the coefficients for the off-diagonal terms
        if (l==1) then
           if (i==1) then
              if (j==2) offdiagcoeff=-0.5_gp*sqrt(3._gp/5._gp)
              if (j==3) offdiagcoeff=0.5_gp*sqrt(5._gp/21._gp)
           else
              offdiagcoeff=-0.5_gp*sqrt(100._gp/63._gp)
           end if
        else if (l==2) then
           if (i==1) then
              if (j==2) offdiagcoeff=-0.5_gp*sqrt(5._gp/7._gp)
              if (j==3) offdiagcoeff=1._gp/6._gp*sqrt(35._gp/11._gp)
           else
              offdiagcoeff=-7._gp/3._gp*sqrt(1._gp/11._gp)
           end if
        else if (l==3) then
           if (i==1) then
              if (j==2) offdiagcoeff=-0.5_gp*sqrt(7._gp/9._gp)
              if (j==3) offdiagcoeff=0.5_gp*sqrt(63._gp/143._gp)
           else
              offdiagcoeff=-9._gp*sqrt(1._gp/143._gp)
           end if
        end if
        istart_c_i=istart_c-(2*l-1)*(mbvctr_c+7*mbvctr_f)
        istart_c_j=istart_c_i+(j-i)*(2*l-1)*(mbvctr_c+7*mbvctr_f)
        do m=1,2*l-1
           !starting addresses of the projectors
           istart_f_j=istart_c_j+mbvctr_c
           istart_f_i=istart_c_i+mbvctr_c
           call wpdot(&
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
                mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_j),proj(istart_f_j),scpr_j)

           call wpdot(&
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
                mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_i),proj(istart_f_i),scpr_i)


           scprp_j=scpr_j*real(offdiagcoeff*psppar(l,j),dp)
           scprp_i=scpr_i*real(offdiagcoeff*psppar(l,j),dp)
           !scpr_i*h_ij*scpr_j+scpr_j*h_ij*scpr_i
           eproj=eproj+2._gp*real(scpr_j,gp)*&
                offdiagcoeff*psppar(l,j)*scprp_j*real(scpr_i,gp)

           !|hpsi>=|hpsi>+h_ij (<p_i|psi>|p_j>+<p_j|psi>|p_i>)
           call waxpy(&
                scprp_j,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_i),proj(istart_f_i),  &
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))

           call waxpy(&
                scprp_i,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_j),proj(istart_f_j),  &
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))

           istart_c_j=istart_f_j+7*mbvctr_f
           istart_c_i=istart_f_i+7*mbvctr_f
        enddo
     end do loop_j
  else if (npspcode == 10 .and. i/=3) then !HGH-K case, offdiagonal terms
     loop_jK: do j=i+1,3
        if (psppar(l,j) .eq. 0._gp) exit loop_jK
        istart_c_i=istart_c-(2*l-1)*(mbvctr_c+7*mbvctr_f)
        istart_c_j=istart_c_i+(j-i)*(2*l-1)*(mbvctr_c+7*mbvctr_f)
        do m=1,2*l-1
           !starting addresses of the projectors
           istart_f_j=istart_c_j+mbvctr_c
           istart_f_i=istart_c_i+mbvctr_c
           call wpdot(&
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
                mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_j),proj(istart_f_j),scpr_j)

           call wpdot(&
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),psi(1),psi(nvctr_c+1),  &
                mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_i),proj(istart_f_i),scpr_i)

           !scpr_i*h_ij*scpr_j+scpr_j*h_ij*scpr_i (with symmetric h_ij)
           eproj=eproj+2._gp*real(scpr_i,gp)*psppar(l,i+j+1)*real(scpr_j,gp)
           scprp_j=scpr_j*real(psppar(l,i+j+1),dp)
           scprp_i=scpr_i*real(psppar(l,i+j+1),dp)

           !|hpsi>=|hpsi>+h_ij (<p_i|psi>|p_j>+<p_j|psi>|p_i>)
           call waxpy(&
                scprp_j,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_i),proj(istart_f_i),  &
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))

           call waxpy(&
                scprp_i,mbvctr_c,mbvctr_f,mbseg_c,mbseg_f,&
                keyv_p(1),keyv_p(mbseg_c+1),  &
                keyg_p(1,1),keyg_p(1,mbseg_c+1),&
                proj(istart_c_j),proj(istart_f_j),  &
                nvctr_c,nvctr_f,nseg_c,nseg_f,keyv(1),keyv(nseg_c+1),  &
                keyg(1,1),keyg(1,nseg_c+1),hpsi(1),hpsi(nvctr_c+1))

           istart_c_j=istart_f_j+7*mbvctr_f
           istart_c_i=istart_f_i+7*mbvctr_f
        enddo
     end do loop_jK
  end if
end subroutine applyprojector

