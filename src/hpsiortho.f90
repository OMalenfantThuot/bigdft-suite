subroutine HamiltonianApplication(geocode,iproc,nproc,at,hx,hy,hz,&
     norb,norbp,occup,n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,wfd,bounds,nlpspd,proj,&
     ngatherarr,ndimpot,potential,psi,hpsi,ekin_sum,epot_sum,eproj_sum,nspin,nspinor,spinsgn)
  use module_types
  implicit none
  include 'mpif.h'
  type(atoms_data), intent(in) :: at
  type(wavefunctions_descriptors), intent(in) :: wfd
  type(nonlocal_psp_descriptors), intent(in) :: nlpspd
  type(convolutions_bounds), intent(in) :: bounds
  character(len=1), intent(in) :: geocode
  integer, intent(in) :: iproc,nproc,n1,n2,n3,norb,norbp,ndimpot
  integer, intent(in) :: nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nspin,nspinor
  real(kind=8), intent(in) :: hx,hy,hz
  integer, dimension(0:nproc-1,2), intent(in) :: ngatherarr 
  real(kind=8), dimension(norb), intent(in) :: occup,spinsgn
  real(kind=8), dimension(nlpspd%nprojel), intent(in) :: proj
  real(kind=8), dimension(wfd%nvctr_c+7*wfd%nvctr_f,nspinor*norbp), intent(in) :: psi
  real(kind=8), dimension(max(ndimpot,1),nspin), intent(in), target :: potential
  real(kind=8), intent(out) :: ekin_sum,epot_sum,eproj_sum
  real(kind=8), dimension(wfd%nvctr_c+7*wfd%nvctr_f,nspinor*norbp), intent(out) :: hpsi
  !local variables
  integer :: i_all,i_stat,ierr,iorb,n1i,n2i,n3i
  integer :: nw1,nw2,nsoffset,oidx,ispin
  real(kind=8) :: ekin,epot,eproj
  real(kind=8), dimension(3,2) :: wrkallred
  real(kind=8), dimension(:,:), allocatable :: w1,w2,psir
  !for the periodic BC case, these arrays substitute 
  !psifscf,psifscfk,psig,ww respectively
  real(kind=8), dimension(:,:,:,:), allocatable ::x_c,y_c,x_f1,x_f2,x_f3
  real(kind=8), dimension(:,:,:,:,:), allocatable::x_f,x_fc,y_f
  real(kind=8), dimension(:,:), pointer :: pot

  !debug
  integer :: nvctrp
  real(kind=8) :: DDOT

  call timing(iproc,'ApplyLocPotKin','ON')
  nvctrp=wfd%nvctr_c+7*wfd%nvctr_f

 
!  print *,'HamApp',iproc,(sum(potential(:,ispin)),ispin=1,nspinor)
    ! local potential and kinetic energy for all orbitals belonging to iproc
  if (iproc==0) then
     write(*,'(1x,a)',advance='no')&
          'Hamiltonian application...'
  end if

!write(*,'(a,2i6,30f12.5)') 'Into HamApp', shape(psi),(sum(psi(:,iorb)),iorb=1,norbp*nspinor)


  select case(geocode)
     case('F')
        n1i=2*n1+31
        n2i=2*n2+31
        n3i=2*n3+31

        !dimensions of work arrays
        ! shrink convention: nw1>nw2
        nw1=max((n3+1)*(2*n1+31)*(2*n2+31),&
             (n1+1)*(2*n2+31)*(2*n3+31),&
             2*(nfu1-nfl1+1)*(2*(nfu2-nfl2)+31)*(2*(nfu3-nfl3)+31),&
             2*(nfu3-nfl3+1)*(2*(nfu1-nfl1)+31)*(2*(nfu2-nfl2)+31))

        nw2=max(4*(nfu2-nfl2+1)*(nfu3-nfl3+1)*(2*(nfu1-nfl1)+31),&
             4*(nfu1-nfl1+1)*(nfu2-nfl2+1)*(2*(nfu3-nfl3)+31),&
             (n1+1)*(n2+1)*(2*n3+31),&
             (2*n1+31)*(n2+1)*(n3+1))

        !allocation of work arrays
        allocate(y_c(0:n1,0:n2,0:n3,nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(y_c))*kind(y_c),'y_c','hamiltonianapplication')
        allocate(y_f(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(y_f))*kind(y_f),'y_f','hamiltonianapplication')
        allocate(x_c(0:n1,0:n2,0:n3,nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(x_c))*kind(x_c),'x_c','hamiltonianapplication')
        allocate(x_f(7,nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,nspinor),stat=i_stat)! work
        call memocc(i_stat,product(shape(x_f))*kind(x_f),'x_f','hamiltonianapplication')
        allocate(w1(nw1,nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(w1))*kind(w1),'w1','hamiltonianapplication')
        allocate(w2(nw2,nspinor),stat=i_stat) ! work
        call memocc(i_stat,product(shape(w2))*kind(w2),'w2','hamiltonianapplication')
        allocate(x_f1(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(x_f1))*kind(x_f1),'x_f1','hamiltonianapplication')
        allocate(x_f2(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(x_f2))*kind(x_f2),'x_f2','hamiltonianapplication')
        allocate(x_f3(nfl1:nfu1,nfl2:nfu2,nfl3:nfu3,nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(x_f3))*kind(x_f3),'x_f3','hamiltonianapplication')

        !initialisation of the work arrays
        call razero((nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1)*nspinor,x_f1)
        call razero((nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1)*nspinor,x_f2)
        call razero((nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1)*nspinor,x_f3)
        call razero((n1+1)*(n2+1)*(n3+1)*nspinor,x_c)
        call razero(7*(nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1)*nspinor,x_f)
        call razero((n1+1)*(n2+1)*(n3+1)*nspinor,y_c)
        call razero(7*(nfu1-nfl1+1)*(nfu2-nfl2+1)*(nfu3-nfl3+1)*nspinor,y_f)

     case('S')
        n1i=2*n1+2
        n2i=2*n2+31
        n3i=2*n3+2
     case('P')
        n1i=2*n1+2
        n2i=2*n2+2
        n3i=2*n3+2

        !allocation of work arrays
        allocate(x_c(n1i,n2i,n3i,nspinor),stat=i_stat) !this is psifscf
        call memocc(i_stat,product(shape(x_c))*kind(x_c),'x_c','hamiltonianapplication')
        allocate(y_c(n1i,n2i,n3i,nspinor),stat=i_stat) !this is psifscfk
        call memocc(i_stat,product(shape(y_c))*kind(y_c),'y_c','hamiltonianapplication')
        allocate(x_f1(n1i,n2i,n3i,nspinor),stat=i_stat) !this is psig
        call memocc(i_stat,product(shape(x_f1))*kind(x_f1),'x_f1','hamiltonianapplication')
        allocate(x_f2(n1i,n2i,n3i,nspinor),stat=i_stat) !this is ww
        call memocc(i_stat,product(shape(x_f2))*kind(x_f2),'x_f2','hamiltonianapplication')

  end select

  !then build the potential on the whole simulation box
  if (nproc > 1) then
     allocate(pot(n1i*n2i*n3i,nspin),stat=i_stat)
     call memocc(i_stat,product(shape(pot))*kind(pot),'pot','hamiltonianapplication')

     do ispin=1,nspin
        call MPI_ALLGATHERV(potential(1,ispin),ndimpot,&
             MPI_DOUBLE_PRECISION,pot(1,ispin),ngatherarr(0,1),&
             ngatherarr(0,2),MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     end do
  else
     pot => potential
  end if

!  print *,'HamApp pot',iproc,(sum(pot(:,ispin)),ispin=1,nspinor)
!     print *,'Start',shape(psi)
!     print '(a,30f10.4)','p', (DDOT(nvctrp*nspinor,psi(1,iorb),1,psi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,30f10.4)','hp', (DDOT(nvctrp*nspinor,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor,nspinor)


  ! Wavefunction in real space
  allocate(psir(n1i*n2i*n3i,nspinor),stat=i_stat)
  call memocc(i_stat,product(shape(psir))*kind(psir),'psir','hamiltonianapplication')

  call razero(n1i*n2i*n3i*nspinor,psir)

  ekin_sum=0.d0
  epot_sum=0.d0
!  print *,"IORB",iproc*norbp+1,min((iproc+1)*norbp,norb)
  do iorb=iproc*norbp+1,min((iproc+1)*norbp,norb)

     oidx=(iorb-1)*nspinor+1-iproc*norbp*nspinor
!     print *,"OIDX,nspinor",iorb,oidx,nspinor,nspin,product(shape(w1))
     if(spinsgn(iorb)>0.0d0) then
        nsoffset=1
     else
        nsoffset=2
     end if
     if(nspinor==4) nsoffset=1

     select case(geocode)
        case('F')
           call applylocpotkinone(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,0, &
                hx,wfd%nseg_c,wfd%nseg_f,wfd%nvctr_c,wfd%nvctr_f,wfd%keyg,wfd%keyv,&
                bounds%kb%ibyz_c,bounds%kb%ibxz_c,bounds%kb%ibxy_c,&
                bounds%kb%ibyz_f,bounds%kb%ibxz_f,bounds%kb%ibxy_f,y_c,y_f,psir, &
                psi(1,oidx),pot(1,nsoffset),hpsi(1,oidx),epot,ekin,&
                x_c,x_f1,x_f2,x_f3,x_f,w1,w2,&
                bounds%sb%ibzzx_c,bounds%sb%ibyyzz_c,&
                bounds%sb%ibxy_ff,bounds%sb%ibzzx_f,bounds%sb%ibyyzz_f,&
                bounds%gb%ibzxx_c,bounds%gb%ibxxyy_c,&
                bounds%gb%ibyz_ff,bounds%gb%ibzxx_f,bounds%gb%ibxxyy_f,nw1,nw2,bounds%ibyyzz_r,nspinor)
        case('P')
           call applylocpotkinone_per(n1,n2,n3,hx,hy,hz,wfd%nseg_c,wfd%nseg_f,&
                wfd%nvctr_c,wfd%nvctr_f,wfd%keyg,wfd%keyv,& 
                psir,x_c,y_c,x_f1,x_f2,psi(1,oidx),pot(1,nsoffset),&
                hpsi(1,oidx),epot,ekin) 
        end select

     ekin_sum=ekin_sum+occup(iorb)*ekin
     epot_sum=epot_sum+occup(iorb)*epot

  enddo
!  write(*,'(a,30f16.8)') 'Exit LocPot', (sum(hpsi(:,iorb)),iorb=1,norbp*nspinor)
!     print *,'After locpot'
!     print '(a,30f10.4)','p', (DDOT(nvctrp*nspinor,psi(1,iorb),1,psi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,30f10.4)','hp', (DDOT(nvctrp*nspinor,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor,nspinor)


!  print *,'locpot done',iproc,epot_sum,ekin_sum
  !deallocations of work arrays
  i_all=-product(shape(psir))*kind(psir)
  deallocate(psir,stat=i_stat)
  call memocc(i_stat,i_all,'psir','hamiltonianapplication')

  i_all=-product(shape(x_c))*kind(x_c)
  deallocate(x_c,stat=i_stat)
  call memocc(i_stat,i_all,'x_c','hamiltonianapplication')
  i_all=-product(shape(y_c))*kind(y_c)
  deallocate(y_c,stat=i_stat)
  call memocc(i_stat,i_all,'y_c','hamiltonianapplication')
  i_all=-product(shape(x_f1))*kind(x_f1)
  deallocate(x_f1,stat=i_stat)
  call memocc(i_stat,i_all,'x_f1','hamiltonianapplication')
  i_all=-product(shape(x_f2))*kind(x_f2)
  deallocate(x_f2,stat=i_stat)
  call memocc(i_stat,i_all,'x_f2','hamiltonianapplication')

  if (geocode == 'F') then
     i_all=-product(shape(x_f3))*kind(x_f3)
     deallocate(x_f3,stat=i_stat)
     call memocc(i_stat,i_all,'x_f3','hamiltonianapplication')
     i_all=-product(shape(y_f))*kind(y_f)
     deallocate(y_f,stat=i_stat)
     call memocc(i_stat,i_all,'y_f','hamiltonianapplication')
     i_all=-product(shape(x_f))*kind(x_f)
     deallocate(x_f,stat=i_stat)
     call memocc(i_stat,i_all,'x_f','hamiltonianapplication')
     i_all=-product(shape(w1))*kind(w1)
     deallocate(w1,stat=i_stat)
     call memocc(i_stat,i_all,'w1','hamiltonianapplication')
     i_all=-product(shape(w2))*kind(w2)
     deallocate(w2,stat=i_stat)
     call memocc(i_stat,i_all,'w2','hamiltonianapplication')
  end if

  if (nproc > 1) then
     i_all=-product(shape(pot))*kind(pot)
     deallocate(pot,stat=i_stat)
     call memocc(i_stat,i_all,'pot','hamiltonianapplication')
  else
     nullify(pot)
  end if

  call timing(iproc,'ApplyLocPotKin','OF')

  ! apply all PSP projectors for all orbitals belonging to iproc
  call timing(iproc,'ApplyProj     ','ON')

  eproj_sum=0.d0
  ! loop over all my orbitals
  do iorb=iproc*norbp*nspinor+1,min((iproc+1)*norbp,norb)*nspinor
!     print *,'call projone',iorb,iorb-iproc*norbp*nspinor,(iorb-1)/nspinor+1
     call applyprojectorsone(at%ntypes,at%nat,at%iatype,at%psppar,at%npspcode, &
          nlpspd%nprojel,nlpspd%nproj,nlpspd%nseg_p,nlpspd%keyg_p,nlpspd%keyv_p,nlpspd%nvctr_p,&
          proj,wfd%nseg_c,wfd%nseg_f,wfd%keyg,wfd%keyv,wfd%nvctr_c,wfd%nvctr_f,  & 
          psi(1,iorb-iproc*norbp*nspinor),hpsi(1,iorb-iproc*norbp*nspinor),eproj)
        eproj_sum=eproj_sum+occup((iorb-1)/nspinor+1)*eproj
!          write(*,*) 'iorb,eproj',iorb,eproj
  enddo

  call timing(iproc,'ApplyProj     ','OF')

  if (nproc > 1) then
     wrkallred(1,2)=ekin_sum 
     wrkallred(2,2)=epot_sum 
     wrkallred(3,2)=eproj_sum
     call MPI_ALLREDUCE(wrkallred(1,2),wrkallred(1,1),3,&
          MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
     ekin_sum=wrkallred(1,1)
     epot_sum=wrkallred(2,1)
     eproj_sum=wrkallred(3,1) 
  endif
!     print *,'After proj'
!     print '(a,30f10.4)','p', (DDOT(nvctrp*nspinor,psi(1,iorb),1,psi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,30f10.4)','hp', (DDOT(nvctrp*nspinor,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor,nspinor)

!  write(*,*) 'Exit HamApp', (sum(hpsi(:,iorb)),iorb=1,norbp*nspinor),shape(hpsi)

end subroutine HamiltonianApplication


subroutine hpsitopsi(iter,iproc,nproc,norb,norbp,occup,hgrid,n1,n2,n3,&
     nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nvctrp,wfd,kbounds,&
     eval,ncong,mids,idsx,ads,energy,energy_old,alpha,gnrm,scprsum,&
     psi,psit,hpsi,psidst,hpsidst,nspin,nspinor,spinsgn)
  use module_types
  implicit none
  type(kinetic_bounds), intent(in) :: kbounds
  type(wavefunctions_descriptors), intent(in) :: wfd
  integer, intent(in) :: iter,iproc,nproc,n1,n2,n3,norb,norbp,ncong,mids,idsx
  integer, intent(in) :: nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nvctrp,nspin,nspinor
  real(kind=8), intent(in) :: hgrid,energy,energy_old
  real(kind=8), dimension(norb), intent(in) :: occup,eval,spinsgn
  real(kind=8), intent(inout) :: alpha
  real(kind=8), intent(inout) :: gnrm,scprsum
  real(kind=8), dimension(:,:), pointer :: psi,psit,hpsi
  real(kind=8), dimension(:,:,:), pointer :: psidst,hpsidst,ads
  !local variables
  include 'mpif.h'
  real(kind=8), parameter :: eps_mach=1.d-12
  integer :: ierr,ind,i1,i2,iorb,k,norbu,norbd,i_stat,i_all,oidx,sidx
  real(kind=8) :: tt,scpr,dnrm2,scprpart,cprecr
  real(kind=8), dimension(:), allocatable :: zalpha
  real(kind=8) :: DDOT

  if (iproc==0) then
     write(*,'(1x,a)',advance='no')&
          'done, orthoconstraint...'
  end if
!     print *,'Start hpsitopsi',shape(hpsi)
!     print '(a,30f10.4)','p', (DDOT(nvctrp*nspinor,psi(1,iorb),1,psi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,30f10.4)','hp', (DDOT(nvctrp*nspinor,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor,nspinor)

  !Calculate no. up and dw orbitals for spin-polarized starting guess
  norbu=0
  norbd=0
  do iorb=1,norb
     if(spinsgn(iorb)>0.0d0) norbu=norbu+1
     if(spinsgn(iorb)<0.0d0) norbd=norbd+1
  end do
  !write(*,'(1x,a,3i4,30f6.2)')'Spins: ',norb,norbu,norbd,(spinsgn(iorb),iorb=1,norb)

 ! write(*,*) 'Enter Ortho', iproc,(sum(hpsi(:,nproc*iorb-1:nproc*iorb)),iorb=1,norbp*nspinor),shape(hpsi)

  ! Apply  orthogonality constraints to all orbitals belonging to iproc
  if (nproc > 1) then
     !transpose the hpsi wavefunction
     !here psi is used as a work array
     call timing(iproc,'Un-TransSwitch','ON')
     call switch_waves(iproc,nproc,norb,norbp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,hpsi,psi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')
     !here hpsi is the transposed array
     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(psi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,  &
          hpsi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')
     !end of transposition
  else
     psit => psi
  end if

!  print *,'constraining',norb,iproc
  if(nspin==1.or.nspinor==4) then
     call orthoconstraint_p(iproc,nproc,norb,occup,nvctrp,psit,hpsi,scprsum,nspinor)
  else
     call orthoconstraint_p(iproc,nproc,norbu,occup,nvctrp,psit,hpsi,scprsum,nspinor)
     scprpart=0.0d0
     if(norbd>0) then
        scprpart=scprsum 
        call orthoconstraint_p(iproc,nproc,norbd,occup(norbu+1),nvctrp,psit(1,norbu+1),hpsi(1,norbu+1),scprsum,nspinor)
     end if
     scprsum=scprsum+scprpart
  end if
  if (nproc > 1) then
     !retranspose the hpsi wavefunction
     !here psi is used as a work array
     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(hpsi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,  &
          psi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')
     !here hpsi is the direct array
     call timing(iproc,'Un-TransSwitch','ON')
     call unswitch_waves(iproc,nproc,norb,norbp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,psi,hpsi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')
     !end of retransposition
  end if
!  write(*,'(a,30f16.8)') 'Exit Ortho',(abs(hpsi(iorb,1)),iorb=1,5)
!     print *,'After orthocon'
!     print '(a,30f10.4)','p', (DDOT(nvctrp*nspinor,psi(1,iorb),1,psi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,30f10.4)','hp', (DDOT(nvctrp*nspinor,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor,nspinor)

!!$  else
!!$     if(nspin==1) then
!!$        call orthoconstraint(norb,occup,nvctrp,psi,hpsi,scprsum)
!!$     else
!!$        call orthoconstraint(norbu,occup,nvctrp,psi,hpsi,scprsum)
!!$        scprpart=0.0d0
!!$        if(norbd>0) then
!!$           scprpart=scprsum 
!!$           call orthoconstraint(norbd,occup(norbu+1),nvctrp,psi(1,norbu+1),hpsi(1,norbu+1),scprsum)
!!$        end if
!!$        scprsum=scprsum+scprpart
!!$     end if
!!$  endif

!  print *,'gradient'
  ! norm of gradient
  gnrm=0.d0
!  if(nspinor==4.and.nproc==1) call psitransspi(nvctrp,norb,hpsi
  do iorb=iproc*norbp+1,min((iproc+1)*norbp,norb)

     oidx=(iorb-1)*nspinor+1-iproc*norbp*nspinor

     if(norb==norbp) then
        !psi not transposed in serial mode
        i1=1
        i2=oidx
     else
        !starting address of the direct array in transposed form
        call trans_address(norbp*nspinor,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,1,oidx,i1,i2)
    end if

     scpr=dnrm2((wfd%nvctr_c+7*wfd%nvctr_f)*nspinor,hpsi(i1,i2),1)
     !scpr=dnrm2(nvctr_c+7*nvctr_f,hpsi(1,iorb-iproc*norbp),1)
     !lines for writing the residue following the orbitals
     !if (iorb <=5) write(83,*)iter,iorb,scpr
     gnrm=gnrm+scpr**2
  enddo
  if (nproc > 1) then
     tt=gnrm
     call MPI_ALLREDUCE(tt,gnrm,1,MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
  endif
  gnrm=sqrt(gnrm/real(norb,kind=8))

  call timing(iproc,'Precondition  ','ON')
  if (iproc==0) then
     write(*,'(1x,a)',advance='no')&
          'done, preconditioning...'
  end if

  !   write(*,'(10f10.6)') (eval(iorb),iorb=1,norb)
  ! Preconditions all orbitals belonging to iproc
!  print *,'preconding',shape(hpsi),shape(psi)
!  print *,' '
!  write(*,'(a,i3,30f16.8)') 'Enter PreCo', iproc,(sum(hpsi(:,nproc*iorb-1:nproc*iorb)),iorb=1,norbp*nspinor)
!  print *,''
!     print *,'Pre PC hpsi',((abs(hpsi(iorb,1))),iorb=1,5)
  do iorb=iproc*norbp+1,min((iproc+1)*norbp,norb)
     
     oidx=(iorb-1)*nspinor+1-iproc*norbp*nspinor
     
     do sidx=oidx,oidx+nspinor-1
        if(norb==norbp) then
           !psi not transposed in serial mode
           i1=1
           i2=sidx
        else
           !starting address of the direct array in transposed form
           call trans_address(norbp,nvctrp*nspinor,nspinor*(wfd%nvctr_c+7*wfd%nvctr_f),1,sidx,i1,i2)
!           print *,'TrAdd',iproc,'   ',iorb,sidx,i1,i2
        end if
        
        cprecr=-eval(iorb)
        !       write(*,*) 'cprecr',iorb,cprecr!
        !     do sidx=1,nspinor
        
        call precong(sidx,n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3, &
             wfd%nseg_c,wfd%nvctr_c,wfd%nseg_f,wfd%nvctr_f,wfd%keyg,wfd%keyv, &
             ncong,cprecr,hgrid,kbounds%ibyz_c,kbounds%ibxz_c,kbounds%ibxy_c,&
             kbounds%ibyz_f,kbounds%ibxz_f,kbounds%ibxy_f,hpsi(i1,i2))
        
        
     end do
  enddo
!     print *,'Post PC hpsi',((abs(hpsi(iorb,1))),iorb=1,5)

! write(*,'(a,i3,30f16.8)') 'Exit PreCo', iproc,(sum(hpsi(:,nproc*iorb-1:nproc*iorb)),iorb=1,norbp*nspinor)
!     print *,'After precong', shape(psi),shape(hpsi),shape(psit)
!     print '(a,30f8.4)','p', (DDOT(nvctrp*nspinor,psi(1,iorb),1,psi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,30f8.4)','hp', (DDOT(nvctrp*nspinor,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,90f8.4)','pt', (DDOT(nvctrp,psit(1,iorb),1,psit(1,iorb),1),iorb=1,norb*nspinor)
!     print '(a,90f8.4)','hp', (DDOT(nvctrp,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor)


!!$  call preconditionall(iproc,nproc,norb,norbp,n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,hgrid, &
!!$       ncong,wfd%nseg_c,wfd%nseg_f,wfd%nvctr_c,wfd%nvctr_f,wfd%keyg,wfd%keyv,eval,&
!!$       kbounds%ibyz_c,kbounds%ibxz_c,kbounds%ibxy_c,&
!!$       kbounds%ibyz_f,kbounds%ibxz_f,kbounds%ibxy_f,hpsi)

  if (iproc==0) then
     write(*,'(1x,a)')&
          'done.'
  end if
  call timing(iproc,'Precondition  ','OF')
!  write(*,'(a,12f10.4)') 'psi pupd',(100*psit(k,1),k=1,5),(100*psi(k,1),k=1,5)
!  print *,DDOT(nvctrp*nspinor,hpsi(1,1),1,hpsi(1,1),1),DDOT(nvctrp*nspinor,psi(1,1),1,psi(1,1),1)
!  print *,'SDing'
  !apply the minimization method (DIIS or steepest descent)
  if (idsx.gt.0) then
     if (nproc > 1) then
        !transpose the hpsi wavefunction into the diis array

        !here psi is used as a work array
        call timing(iproc,'Un-TransSwitch','ON')
        call switch_waves(iproc,nproc,norb,norbp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,hpsi,psi)
        call timing(iproc,'Un-TransSwitch','OF')
        call timing(iproc,'Un-TransComm  ','ON')
        call MPI_ALLTOALL(psi,nvctrp*norbp,MPI_DOUBLE_PRECISION,  &
             hpsidst(1,1,mids),nvctrp*norbp,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
        call timing(iproc,'Un-TransComm  ','OF')
        !end of transposition

        call timing(iproc,'Diis          ','ON')
        do iorb=1,norb
           do k=1,nvctrp*nspinor
              psidst(k,iorb,mids)= psit(k,iorb) 
           enddo
        enddo

        !call diisstp(norb,norbp,nproc,iproc,  &
        !     ads,iter,mids,idsx,nvctrp,psit,psidst,hpsidst)
     else
        call timing(iproc,'Diis          ','ON')
        if(nspinor==4) call psitransspi(nvctrp,norb,psit,.true.)
        if(nspinor==4) call psitransspi(nvctrp,norb,hpsi,.true.)
!        write(*,'(a,12f10.4)') 'psi trans',(100*psit(k,1),k=1,5),(100*hpsi(k,1),k=1,5)
        do iorb=1,norb*nspinor
           do k=1,nvctrp
              psidst(k,iorb,mids)= psit(k,iorb)
              hpsidst(k,iorb,mids)=hpsi(k,iorb)
           enddo
        enddo
     endif
!     print *,'Pre DIIS' ,shape(psi),shape(hpsidst),shape(psit)
!     print '(a,30f10.4)','p', (DDOT(nvctrp*nspinor,psi(1,iorb),1,psi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,30f10.4)','hp', (DDOT(nvctrp*nspinor,hpsidst(1,iorb,mids),1,hpsidst(1,iorb,mids),1), &
!          iorb=1,norb*nspinor,nspinor)

     call diisstp(norb,norbp,nproc,iproc, nspinor,  &
          ads,iter,mids,idsx,nvctrp,psit,psidst,hpsidst)
     !    write(*,*) 'psi update done',iproc

!        write(*,'(a,10f10.4)') 'diis a',(100*psit(k,1),k=1,5),(100*hpsi(k,1),k=1,5)
  else

     ! update all wavefunctions with the preconditioned gradient
     if (energy.gt.energy_old) then
        alpha=max(.125d0,.5d0*alpha)
        if (alpha.eq..125d0) write(*,*) 'Convergence problem or limit'
     else
        alpha=min(1.05d0*alpha,1.d0)
     endif
     if (iproc.eq.0) write(*,'(1x,a,1pe11.3)') 'alpha=',alpha

!     print *,'SD psi',((abs(psit(iorb,1))),iorb=1,5)
!     print '(a,30f10.4)','SD hpsi',((abs(hpsi(iorb,1))),iorb=1,5)
!     print *,'transping'
     if (nproc > 1) then
        !transpose the hpsi wavefunction
        !here psi is used as a work array
        call timing(iproc,'Un-TransSwitch','ON')
        call switch_waves(iproc,nproc,norb,norbp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,hpsi,psi,nspinor)
        call timing(iproc,'Un-TransSwitch','OF')
        !here hpsi is the transposed array
        call timing(iproc,'Un-TransComm  ','ON')
        call MPI_ALLTOALL(psi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,  &
             hpsi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
        call timing(iproc,'Un-TransComm  ','OF')
        !end of transposition
     else if(nspinor==4) then
 !       call psitransspi(nvctrp,norb,hpsi,.true.)
 !       call psitransspi(nvctrp,norb,psit,.true.) ! needed?
     endif

!     print *,'updating',shape(psi),shape(hpsi),shape(psit),nvctrp,norb*nspinor
     call timing(iproc,'Diis          ','ON')

        do iorb=1,norb*nspinor
           call DAXPY(nvctrp,-alpha,hpsi(1,iorb),1,psit(1,iorb),1)
        enddo
     endif

  call timing(iproc,'Diis          ','OF')

  if (iproc==0) then
     write(*,'(1x,a)',advance='no')&
          'Orthogonalization...'
  end if
!  write(*,'(a,10f10.4)') 'psit portho',(100*psit(k,1),k=1,5)

!     print *,'Into orthogonalization'
!     print '(a,30f10.4)','p1', (sum(abs(psit(:,iorb:iorb+3)))/100.0,iorb=1,norb*nspinor,4) ! (DDOT(nvctrp,psit(1,iorb),1,psit(1,iorb),1),iorb=1,norb*nspinor-3,nspinor)
!     print '(a,30f10.4)','p1', (DDOT(nvctrp,psit(1,iorb),1,psit(1,iorb),1),iorb=1,norb*nspinor-3,nspinor)
!     print '(a,30f10.4)','p2', (DDOT(nvctrp,psit(1,iorb),1,psit(1,iorb),1),iorb=2,norb*nspinor-3,nspinor)
!     print '(a,30f10.4)','p3', (DDOT(nvctrp,psit(1,iorb),1,psit(1,iorb),1),iorb=3,norb*nspinor-3,nspinor)
!     print '(a,30f10.4)','p4', (DDOT(nvctrp,psit(1,iorb),1,psit(1,iorb),1),iorb=4,norb*nspinor-3,nspinor)
!     print *,'Into orthogonalization'
!     print '(a,30f10.4)','hp', (DDOT(nvctrp*nspinor,hpsi(1,iorb),1,hpsi(1,iorb),1),iorb=1,norb*nspinor,nspinor)
!     print '(a,90f10.4)','pt', (DDOT(2*nvctrp,psit(1,iorb),1,psit(1,iorb),1),iorb=2,norb*nspinor-1,2)
        if(nspinor==4) call psitransspi(nvctrp,norb,psit,.true.)
!     print '(a,30f10.4)','p1', (sum(abs(psi(:,iorb:iorb+3)))/100,iorb=1,norb*nspinor,4)
!     print '(a,30f10.4)','p1', (DDOT(nvctrp,psit(1,1),2,psit(1,iorb),2),iorb=1,norb*nspinor,4)
!     print '(a,30f10.4)','p2', (DDOT(nvctrp,psit(2,1),2,psit(2,iorb),2),iorb=1,norb*nspinor,4)
!     print '(a,30f10.4)','p3', (DDOT(nvctrp,psit(1,5),2,psit(1,iorb),2),iorb=1,norb*nspinor,4)
!     print '(a,30f10.4)','p4', (DDOT(nvctrp,psit(2,5),2,psit(2,iorb),2),iorb=1,norb*nspinor,4)
!     print *,''
!     print '(a,90f10.4)','p', (DDOT(nvctrp,psit(1,iorb),2,psit(1,iorb),2),iorb=1,norb*nspinor,2)
!!        if(nspinor==4) call psitransspi(nvctrp,norb,psit,.false.)
!     print '(a,90f20.14)','d', (DDOT(nvctrp,psit(1,5),2,psit(1,3),2)), (DDOT(nvctrp,psit(1,1),2,psit(1,3),2))

  if(nspin==1.or.nspinor==4) then
     call orthon_p(iproc,nproc,norb,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit,nspinor)
  else
     call orthon_p(iproc,nproc,norbu,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit,nspinor)
     if(norbd>0) then
        call orthon_p(iproc,nproc,norbd,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit(1,norbu+1),nspinor)
     end if
  end if
     !       call checkortho_p(iproc,nproc,norb,nvctrp,psit)

  if (nproc > 1) then
     !here hpsi is used as a work array
     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(psit,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,  &
          hpsi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')
     call timing(iproc,'Un-TransSwitch','ON')
     call unswitch_waves(iproc,nproc,norb,norbp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,hpsi,psi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')
     !end of retransposition
  else

!     if(nspinor==4) call psitransspi(nvctrp,norb,psit,.false.)
     nullify(psit)
     if(nspinor==4) call psitransspi(nvctrp,norb,psi,.false.)
     if(nspinor==4) call psitransspi(nvctrp,norb,hpsi,.false.)
!!$     if(nspin==1) then
!!$        call orthon(norb,nvctrp,psi)
!!$        !          call checkortho(norb,nvctrp,psi)
!!$     else
!!$        call orthon(norbu,nvctrp,psi)
!!$        !          call checkortho(norbu,nvctrp,psi)
!!$        if(norbd>0) then
!!$           call orthon(norbd,nvctrp,psi(1,norbu+1))
!!$        end if
!!$        !          call checkortho(norbd,nvctrp,psi(1,norbu+1))
!!$     end if
  endif

  if (iproc==0) then
     write(*,'(1x,a)')&
          'done.'
  end if

!     print *,'Final psi',((abs(psi(iorb,1))),iorb=1,5)
!     print *,'Final hpsi',((abs(hpsi(iorb,1))),iorb=1,5)

! write(*,'(a,i3,30f16.8)') 'Exit OrthoN', iproc,(sum(psi(:,nproc*iorb-1:nproc*iorb)),iorb=1,norbp*nspinor)

end subroutine hpsitopsi

!calculate the address to start from for calculating the 
!norm of the residue if hpsi is allocated in the transposed way
!it can be eliminated when including all this procedure in a subroutine
subroutine trans_address(norbp,nvctrp,nvctr,i,iorb,i1,i2)
  implicit none
  integer, intent(in) :: norbp,nvctrp,nvctr,i,iorb
  integer, intent(out) :: i1,i2
  !local variables
  integer :: ind
!  if (nproc > 1) then
  ind=i+nvctr*(iorb-1)
  i1=mod(ind-1,nvctrp)+1
  i2=(ind-i1)/nvctrp+1
!!$  else
!!$     i1=1
!!$     i2=iorb
!!$  end if
end subroutine trans_address



subroutine first_orthon(iproc,nproc,parallel,norbu,norbd,norb,norbp,nvctr_c,nvctr_f,nvctrp,&
     nspin,psi,hpsi,psit)
  implicit none
  include 'mpif.h'
  logical, intent(in) :: parallel
  integer, intent(in) :: iproc,nproc,norbu,norbd,norb,norbp,nvctr_c,nvctr_f,nvctrp,nspin
  real(kind=8), dimension(:,:) , pointer :: psi,hpsi,psit
  !local variables
  integer :: i_all,i_stat,ierr,nspinor,iorb

  if(nspin==4) then
     nspinor=4
  else
     nspinor=1
  end if
  
!  print *,'first ortho',nspinor,parallel,shape(psi)
  if (parallel) then
     !allocate hpsi array (used also as transposed)
     !allocated in the transposed way such as 
     !it can also be used as the transposed hpsi
     allocate(hpsi(nvctrp,nspinor*norbp*nproc),stat=i_stat)
     call memocc(i_stat,product(shape(hpsi))*kind(hpsi),'hpsi','first_orthon')

     write(*,'(a,i3,30f10.5)') 'SWI',iproc,(sum(psi(1:nvctrp,iorb)),iorb=1,norbp*nspinor)
     !transpose the psi wavefunction
     !here hpsi is used as a work array
     call timing(iproc,'Un-TransSwitch','ON')
     call switch_waves(iproc,nproc,norb,norbp,nvctr_c,nvctr_f,nvctrp,psi,hpsi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')
     !allocate transposed principal wavefunction
!     allocate(psit(nvctrp,nspinor*norbp*nproc),stat=i_stat)
     allocate(psit(nvctrp,nspinor*norbp*nproc),stat=i_stat)
     call memocc(i_stat,product(shape(psit))*kind(psit),'psit','first_orthon')
     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(hpsi,nvctrp*nspinor*norbp,MPI_DOUBLE_PRECISION,  &
          psit,nvctrp*nspinor*norbp,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')
     !end of transposition

     if(nspin==1.or.nspinor==4) then
        call orthon_p(iproc,nproc,norb,nvctrp,nvctr_c+7*nvctr_f,psit,nspinor) 
     else
        call orthon_p(iproc,nproc,norbu,nvctrp,nvctr_c+7*nvctr_f,psit,nspinor) 
        if(norbd>0) then
           call orthon_p(iproc,nproc,norbd,nvctrp,nvctr_c+7*nvctr_f,psit(1,norbu+1),nspinor) 
        end if
     end if
     !call checkortho_p(iproc,nproc,norb,norbp,nvctrp,psit)

     !retranspose the psit wavefunction into psi
     !here hpsi is used as a work array
     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(psit,nvctrp*nspinor*norbp,MPI_DOUBLE_PRECISION,  &
          hpsi,nvctrp*nspinor*norbp,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')
     call timing(iproc,'Un-TransSwitch','ON')
     call unswitch_waves(iproc,nproc,norb,norbp,nvctr_c,nvctr_f,nvctrp,hpsi,psi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')
     !end of retransposition
     write(*,'(a,i3,30f10.5)') 'U-SWI',iproc,(sum(psi(1:nvctrp,iorb)),iorb=1,norbp*nspinor)
  else
     if(nspin==1.or.nspinor==4) then
        call orthon(norb,nvctrp,psi,nspinor)
        !call checkortho(norb,norbp,nvctrp,psi)
     else
        call orthon(norbu,nvctrp,psi,nspinor)
        !call checkortho(norbu,nvctrp,psi)
        if(norbd>0) then
           call orthon(norbd,nvctrp,psi(1,norbu+1),nspinor)
           !call checkortho(norbd,nvctrp,psi(1,norbu+1))
        end if
     end if
     !allocate hpsi array
!     print *,'Alloc HPSI',nvctr_c+7*nvctr_f,nspin,nspinor,norbp
     allocate(hpsi(nvctr_c+7*nvctr_f,nspinor*norbp),stat=i_stat)
     call memocc(i_stat,product(shape(hpsi))*kind(hpsi),'hpsi','first_orthon')
  endif

end subroutine first_orthon

! transform to KS orbitals and deallocate hpsi wavefunction (and also psit in parallel)
subroutine last_orthon(iproc,nproc,parallel,norbu,norbd,norb,norbp,nvctr_c,nvctr_f,nvctrp,&
     nspin,psi,hpsi,psit,occup,evsum,eval)
  implicit none
  include 'mpif.h'
  logical, intent(in) :: parallel
  integer, intent(in) :: iproc,nproc,norbu,norbd,norb,norbp,nvctr_c,nvctr_f,nvctrp,nspin
  real(kind=8), dimension(norb), intent(in) :: occup
  real(kind=8), intent(out) :: evsum
  real(kind=8), dimension(norb), intent(out) :: eval
  real(kind=8), dimension(:,:) , pointer :: psi,hpsi,psit
  !local variables
  integer :: i_all,i_stat,ierr,iorb,jorb,nspinor
  real(kind=8) :: evpart

  if(nspin==4) then
     nspinor=4
  else
     nspinor=1
  end if

  if (parallel) then

     !transpose the hpsi wavefunction
     !here psi is used as a work array
     call timing(iproc,'Un-TransSwitch','ON')
     call switch_waves(iproc,nproc,norb,norbp,nvctr_c,nvctr_f,nvctrp,hpsi,psi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')
     !here hpsi is the transposed array
     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(psi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,  &
          hpsi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')
     !end of transposition
     if(nspin==1.or.nspinor==4) then
        call KStrans_p(iproc,nproc,norb,norbp*nproc,nvctrp,occup,hpsi,psit,evsum,eval,nspinor)
     else
        call KStrans_p(iproc,nproc,norbu,norbu,nvctrp,occup,hpsi,psit,evsum,eval,nspinor)
        evpart=evsum
        if(norbd>0) then
           call KStrans_p(iproc,nproc,norbd,norbd,nvctrp,occup(norbu+1),&
                hpsi(1,norbu+1),psit(1,norbu+1),evsum,eval(norbu+1),nspinor)
           evsum=evsum+evpart
        end if
     end if

     !retranspose the psit wavefunction into psi
     !here hpsi is used as a work array
     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(psit,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,  &
          hpsi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')
     call timing(iproc,'Un-TransSwitch','ON')
     call unswitch_waves(iproc,nproc,norb,norbp,nvctr_c,nvctr_f,nvctrp,hpsi,psi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')
     !end of retransposition

     i_all=-product(shape(psit))*kind(psit)
     deallocate(psit,stat=i_stat)
     call memocc(i_stat,i_all,'psit','last_orthon')

  else
     if(nspin==1) then
        call KStrans(norb,nvctrp,occup,hpsi,psi,evsum,eval,nspinor)
     else if(nspin==4) then
        call KStrans(norb,nvctrp,occup,hpsi,psi,evsum,eval,nspinor)
     else
        call KStrans(norbu,nvctrp,occup,hpsi,psi,evsum,eval,nspinor)
        evpart=evsum
        if(norbd>0) then
           call KStrans(norbd,nvctrp,occup(norbu+1),hpsi(1,norbu+1),psi(1,norbu+1),&
                evsum,eval(norbu+1),nspinor)
           evsum=evsum+evpart
        end if
     end if
  endif

  !print the found eigenvalues
  if (iproc == 0) then
     write(*,'(1x,a)')&
          '-------------------------------------------------------------- Kohn-Sham Eigenvalues'
     if (nspin==1.or.nspinor==4) then
        do iorb=1,norb!/2
!!$           jorb=norb/2+iorb
!!$           write(*,'(1x,a,i4,a,1x,1pe21.14,17x,a,i4,a,1x,1pe21.14)') &
!!$                'eval(',iorb,')=',eval(iorb),'eval(',jorb,')=',eval(jorb)
!!$        end do
!!$        if (2*norb/2 /= norb) then
!!$           write(*,'(1x,a,i4,a,1x,1pe21.14)') 'eval(',norb/2+1,')=',eval(norb/2+1)
!!$        end if
           write(*,'(1x,a,i4,a,1x,1pe21.14)') 'eval(',iorb,')=',eval(iorb)
        end do
     else
        do iorb=1,min(norbu,norbd)
           jorb=norbu+iorb
           write(*,'(1x,a,i4,a,1x,1pe21.14,14x,a,i4,a,1x,1pe21.14)') &
                'eval(',iorb,',u)=',eval(iorb),'eval(',iorb,',d)=',eval(jorb)
        end do
        if (norbu > norbd) then
           do iorb=norbd+1,norbu
              write(*,'(1x,a,i4,a,1x,1pe21.14)') 'eval(',iorb,',u)=',eval(iorb)
           end do
        else if (norbd > norbu) then
           do iorb=2*norbu+1,norbu+norbd
              write(*,'(48x,a,i0,a,1x,1pe21.14)') 'eval(',iorb-norbu,',d)=',eval(iorb)
           end do
        end if
     end if
  end if

  i_all=-product(shape(hpsi))*kind(hpsi)
  deallocate(hpsi,stat=i_stat)
  call memocc(i_stat,i_all,'hpsi','last_orthon')

end subroutine last_orthon
