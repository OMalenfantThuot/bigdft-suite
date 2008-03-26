subroutine createWavefunctionsDescriptors(iproc,nproc,geocode,n1,n2,n3,output_grid,&
     hx,hy,hz,atoms,alat1,alat2,alat3,rxyz,radii_cf,crmult,frmult,&
     wfd,nvctrp,norb,norbp,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,bounds,nspinor)
  !calculates the descriptor arrays keyg and keyv as well as nseg_c,nseg_f,nvctr_c,nvctr_f,nvctrp
  !calculates also the bounds arrays needed for convolutions

  use module_types

  implicit none
  !Arguments
  type(atoms_data), intent(in) :: atoms
  character(len=1), intent(in) :: geocode
  logical, intent(in) :: output_grid
  integer, intent(in) :: iproc,nproc,n1,n2,n3,norb,norbp,nspinor
  integer, intent(in) :: nfl1,nfu1,nfl2,nfu2,nfl3,nfu3
  real(kind=8), intent(in) :: hx,hy,hz,crmult,frmult,alat1,alat2,alat3
  real(kind=8), dimension(3,atoms%nat), intent(in) :: rxyz
  real(kind=8), dimension(atoms%ntypes,2), intent(in) :: radii_cf
  type(wavefunctions_descriptors) , intent(out) :: wfd
  !boundary arrays
  type(convolutions_bounds), intent(out) :: bounds
  integer, intent(out) :: nvctrp
  !Local variables
  real(kind=8), parameter :: eps_mach=1.d-12
  integer :: iat,i1,i2,i3,norbme,norbyou,jpst,jproc,i_all,i_stat
  real(kind=8) :: tt
  logical, dimension(:,:,:), allocatable :: logrid_c,logrid_f

  !allocate kinetic bounds, only for free BC
  if (geocode == 'F') then
     allocate(bounds%kb%ibyz_c(2,0:n2,0:n3),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%kb%ibyz_c))*kind(bounds%kb%ibyz_c),'ibyz_c','crtwvfnctsdescriptors')
     allocate(bounds%kb%ibxz_c(2,0:n1,0:n3),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%kb%ibxz_c))*kind(bounds%kb%ibxz_c),'ibxz_c','crtwvfnctsdescriptors')
     allocate(bounds%kb%ibxy_c(2,0:n1,0:n2),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%kb%ibxy_c))*kind(bounds%kb%ibxy_c),'ibxy_c','crtwvfnctsdescriptors')
     allocate(bounds%kb%ibyz_f(2,0:n2,0:n3),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%kb%ibyz_f))*kind(bounds%kb%ibyz_f),'ibyz_f','crtwvfnctsdescriptors')
     allocate(bounds%kb%ibxz_f(2,0:n1,0:n3),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%kb%ibxz_f))*kind(bounds%kb%ibxz_f),'ibxz_f','crtwvfnctsdescriptors')
     allocate(bounds%kb%ibxy_f(2,0:n1,0:n2),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%kb%ibxy_f))*kind(bounds%kb%ibxy_f),'ibxy_f','crtwvfnctsdescriptors')
  end if

  if (iproc.eq.0) then
     write(*,'(1x,a)')&
          '------------------------------------------------- Wavefunctions Descriptors Creation'
  end if

  ! determine localization region for all orbitals, but do not yet fill the descriptor arrays
  allocate(logrid_c(0:n1,0:n2,0:n3),stat=i_stat)
  call memocc(i_stat,product(shape(logrid_c))*kind(logrid_c),'logrid_c','crtwvfnctsdescriptors')
  allocate(logrid_f(0:n1,0:n2,0:n3),stat=i_stat)
  call memocc(i_stat,product(shape(logrid_f))*kind(logrid_f),'logrid_f','crtwvfnctsdescriptors')

  ! coarse grid quantities
  call fill_logrid(geocode,n1,n2,n3,0,n1,0,n2,0,n3,0,atoms%nat,atoms%ntypes,atoms%iatype,rxyz, & 
       radii_cf(1,1),crmult,hx,hy,hz,logrid_c)
  call num_segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_c,wfd%nseg_c,wfd%nvctr_c)
  if (iproc.eq.0) write(*,'(2(1x,a,i10))') &
       'Coarse resolution grid: Number of segments= ',wfd%nseg_c,'points=',wfd%nvctr_c

  if (geocode == 'F') then
     call make_bounds(n1,n2,n3,logrid_c,bounds%kb%ibyz_c,bounds%kb%ibxz_c,bounds%kb%ibxy_c)
  end if

  ! fine grid quantities
  call fill_logrid(geocode,n1,n2,n3,0,n1,0,n2,0,n3,0,atoms%nat,atoms%ntypes,atoms%iatype,rxyz, & 
       radii_cf(1,2),frmult,hx,hy,hz,logrid_f)
  call num_segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_f,wfd%nseg_f,wfd%nvctr_f)
  if (iproc.eq.0) write(*,'(2(1x,a,i10))') &
       '  Fine resolution grid: Number of segments= ',wfd%nseg_f,'points=',wfd%nvctr_f
  if (geocode == 'F') then
     call make_bounds(n1,n2,n3,logrid_f,bounds%kb%ibyz_f,bounds%kb%ibxz_f,bounds%kb%ibxy_f)
  end if

  ! Create the file grid.xyz to visualize the grid of functions
  if (iproc ==0 .and. output_grid) then
     open(unit=22,file='grid.xyz',status='unknown')
     write(22,*) wfd%nvctr_c+wfd%nvctr_f,' atomic'
     write(22,*)'complete simulation grid with low ang high resolution points'
     do iat=1,atoms%nat
        write(22,'(a6,2x,3(1x,e12.5),3x)') &
             trim(atoms%atomnames(atoms%iatype(iat))),rxyz(1,iat),rxyz(2,iat),rxyz(3,iat)
     enddo
     do i3=0,n3  
        do i2=0,n2  
           do i1=0,n1
              if (logrid_c(i1,i2,i3))&
                   write(22,'(a4,2x,3(1x,e10.3))') &
                   '  g ',real(i1,kind=8)*hx,real(i2,kind=8)*hy,real(i3,kind=8)*hz
           enddo
        enddo
     end do
     do i3=0,n3 
        do i2=0,n2 
           do i1=0,n1
              if (logrid_f(i1,i2,i3))&
                   write(22,'(a4,2x,3(1x,e10.3))') &
                   '  G ',real(i1,kind=8)*hx,real(i2,kind=8)*hy,real(i3,kind=8)*hz
           enddo
        enddo
     enddo
     close(22)
  endif

  ! allocations for arrays holding the wavefunctions and their data descriptors
  call allocate_wfd(wfd,'crtwvfnctsdescriptors')

  ! now fill the wavefunction descriptor arrays
  ! coarse grid quantities
  call segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_c,wfd%nseg_c,wfd%keyg(1,1),wfd%keyv(1))

  ! fine grid quantities
  call segkeys(n1,n2,n3,0,n1,0,n2,0,n3,logrid_f,wfd%nseg_f,wfd%keyg(1,wfd%nseg_c+1), &
       & wfd%keyv(wfd%nseg_c+1))

  i_all=-product(shape(logrid_c))*kind(logrid_c)
  deallocate(logrid_c,stat=i_stat)
  call memocc(i_stat,i_all,'logrid_c','crtwvfnctsdescriptors')
  i_all=-product(shape(logrid_f))*kind(logrid_f)
  deallocate(logrid_f,stat=i_stat)
  call memocc(i_stat,i_all,'logrid_f','crtwvfnctsdescriptors')

  !distribution of wavefunction arrays between processors
  norbme=max(min((iproc+1)*norbp,norb)-iproc*norbp,0)
  !write(*,'(a,i0,a,i0,a)') '- iproc ',iproc,' treats ',norbme,' orbitals '
  if (iproc == 0 .and. nproc>1) then
     jpst=0
     do jproc=0,nproc-2
        norbme=max(min((jproc+1)*norbp,norb)-jproc*norbp,0)
        norbyou=max(min((jproc+2)*norbp,norb)-(jproc+1)*norbp,0)
        if (norbme /= norbyou) then
           !this is a screen output that must be modified
           write(*,'(3(a,i0),a)')&
                ' Processes from ',jpst,' to ',jproc,' treat ',norbme,' orbitals '
           jpst=jproc+1
        end if
     end do
     write(*,'(3(a,i0),a)')&
          ' Processes from ',jpst,' to ',nproc-1,' treat ',norbyou,' orbitals '
  end if

  tt=dble(wfd%nvctr_c+7*wfd%nvctr_f)/dble(nproc)
  nvctrp=int((1.d0-eps_mach*tt) + tt)

  if (iproc.eq.0) write(*,'(1x,a,i0)') &
       'Wavefunction memory occupation per orbital (Bytes): ',&
       nvctrp*nproc*8*nspinor !

  !for free BC admits the bounds arrays
  if (geocode == 'F') then

     !allocate grow, shrink and real bounds
     allocate(bounds%gb%ibzxx_c(2,0:n3,-14:2*n1+16),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%gb%ibzxx_c))*kind(bounds%gb%ibzxx_c),'ibzxx_c','crtwvfnctsdescriptors')
     allocate(bounds%gb%ibxxyy_c(2,-14:2*n1+16,-14:2*n2+16),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%gb%ibxxyy_c))*kind(bounds%gb%ibxxyy_c),'ibxxyy_c','crtwvfnctsdescriptors')
     allocate(bounds%gb%ibyz_ff(2,nfl2:nfu2,nfl3:nfu3),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%gb%ibyz_ff))*kind(bounds%gb%ibyz_ff),'ibyz_ff','crtwvfnctsdescriptors')
     allocate(bounds%gb%ibzxx_f(2,nfl3:nfu3,2*nfl1-14:2*nfu1+16),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%gb%ibzxx_f))*kind(bounds%gb%ibzxx_f),'ibzxx_f','crtwvfnctsdescriptors')
     allocate(bounds%gb%ibxxyy_f(2,2*nfl1-14:2*nfu1+16,2*nfl2-14:2*nfu2+16),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%gb%ibxxyy_f))*kind(bounds%gb%ibxxyy_f),'ibxxyy_f','crtwvfnctsdescriptors')

     allocate(bounds%sb%ibzzx_c(2,-14:2*n3+16,0:n1),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%sb%ibzzx_c))*kind(bounds%sb%ibzzx_c),'ibzzx_c','crtwvfnctsdescriptors')
     allocate(bounds%sb%ibyyzz_c(2,-14:2*n2+16,-14:2*n3+16),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%sb%ibyyzz_c))*kind(bounds%sb%ibyyzz_c),'ibyyzz_c','crtwvfnctsdescriptors')
     allocate(bounds%sb%ibxy_ff(2,nfl1:nfu1,nfl2:nfu2),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%sb%ibxy_ff))*kind(bounds%sb%ibxy_ff),'ibxy_ff','crtwvfnctsdescriptors')
     allocate(bounds%sb%ibzzx_f(2,-14+2*nfl3:2*nfu3+16,nfl1:nfu1),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%sb%ibzzx_f))*kind(bounds%sb%ibzzx_f),'ibzzx_f','crtwvfnctsdescriptors')
     allocate(bounds%sb%ibyyzz_f(2,-14+2*nfl2:2*nfu2+16,-14+2*nfl3:2*nfu3+16),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%sb%ibyyzz_f))*kind(bounds%sb%ibyyzz_f),'ibyyzz_f','crtwvfnctsdescriptors')

     allocate(bounds%ibyyzz_r(2,-14:2*n2+16,-14:2*n3+16),stat=i_stat)
     call memocc(i_stat,product(shape(bounds%ibyyzz_r))*kind(bounds%ibyyzz_r),'ibyyzz_r','crtwvfnctsdescriptors')

     call make_all_ib(n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
          bounds%kb%ibxy_c,bounds%sb%ibzzx_c,bounds%sb%ibyyzz_c,&
          bounds%kb%ibxy_f,bounds%sb%ibxy_ff,bounds%sb%ibzzx_f,bounds%sb%ibyyzz_f,&
          bounds%kb%ibyz_c,bounds%gb%ibzxx_c,bounds%gb%ibxxyy_c,&
          bounds%kb%ibyz_f,bounds%gb%ibyz_ff,bounds%gb%ibzxx_f,bounds%gb%ibxxyy_f,&
          bounds%ibyyzz_r)

  end if

END SUBROUTINE createWavefunctionsDescriptors

!pass to implicit none while inserting types on this routine
subroutine createProjectorsArrays(geocode,iproc,n1,n2,n3,rxyz,at,&
     radii_cf,cpmult,fpmult,hx,hy,hz,nlpspd,proj)
  use module_types
  implicit none
  type(atoms_data), intent(in) :: at
  character(len=1), intent(in) :: geocode
  integer, intent(in) :: iproc,n1,n2,n3
  real(kind=8), intent(in) :: cpmult,fpmult,hx,hy,hz
  real(kind=8), dimension(3,at%nat), intent(in) :: rxyz
  real(kind=8), dimension(at%ntypes,2), intent(in) :: radii_cf
  type(nonlocal_psp_descriptors), intent(out) :: nlpspd
  real(kind=8), dimension(:), pointer :: proj
  !local variables
  integer, parameter :: nterm_max=10 !if GTH nterm_max=3
  integer :: nl1,nl2,nl3,nu1,nu2,nu3,mseg,mvctr,mproj,istart,istart_c,istart_f,mvctr_c,mvctr_f
  integer :: nl1_c,nl1_f,nl2_c,nl2_f,nl3_c,nl3_f,nu1_c,nu1_f,nu2_c,nu2_f,nu3_c,nu3_f
  integer :: iat,i_stat,i_all,i,l,m,iproj,ityp,nterm,iseg,nwarnings,natyp
  real(kind=8) :: fpi,factor,scpr,gau_a,rx,ry,rz,radmin
  real(kind=8), dimension(nterm_max) :: fac_arr
  integer, dimension(nterm_max) :: lx,ly,lz
  logical, dimension(:,:,:), allocatable :: logrid

  if (iproc.eq.0) then
     write(*,'(1x,a)')&
          '------------------------------------------------------------ PSP Projectors Creation'
     write(*,'(1x,a4,4x,a4,2(1x,a))')&
          'Type','Name','Number of atoms','Number of projectors'
  end if

  allocate(nlpspd%nseg_p(0:2*at%nat),stat=i_stat)
  call memocc(i_stat,product(shape(nlpspd%nseg_p))*kind(nlpspd%nseg_p),&
       'nseg_p','createprojectorsarrays')
  allocate(nlpspd%nvctr_p(0:2*at%nat),stat=i_stat)
  call memocc(i_stat,product(shape(nlpspd%nvctr_p))*kind(nlpspd%nvctr_p),&
       'nvctr_p','createprojectorsarrays')
  allocate(nlpspd%nboxp_c(2,3,at%nat),stat=i_stat)
  call memocc(i_stat,product(shape(nlpspd%nboxp_c))*kind(nlpspd%nboxp_c),&
       'nboxp_c','createprojectorsarrays')
  allocate(nlpspd%nboxp_f(2,3,at%nat),stat=i_stat)
  call memocc(i_stat,product(shape(nlpspd%nboxp_f))*kind(nlpspd%nboxp_f),&
       'nboxp_f','createprojectorsarrays')

  ! determine localization region for all projectors, but do not yet fill the descriptor arrays
  allocate(logrid(0:n1,0:n2,0:n3),stat=i_stat)
  call memocc(i_stat,product(shape(logrid))*kind(logrid),'logrid','createprojectorsarrays')

  nlpspd%nseg_p(0)=0 
  nlpspd%nvctr_p(0)=0 

  istart=1
  nlpspd%nproj=0

  if (iproc ==0) then
     !print the number of projectors to be created
     do ityp=1,at%ntypes
        call numb_proj(ityp,at%ntypes,at%psppar,at%npspcode,mproj)
        natyp=0
        do iat=1,at%nat
           if (at%iatype(iat) == ityp) natyp=natyp+1
        end do
        write(*,'(1x,i4,2x,a6,1x,i15,i21)')&
             ityp,trim(at%atomnames(ityp)),natyp,mproj
     end do
  end if

  do iat=1,at%nat

     call numb_proj(at%iatype(iat),at%ntypes,at%psppar,at%npspcode,mproj)
     if (mproj.ne.0) then 

        !if (iproc.eq.0) write(*,'(1x,a,2(1x,i0))')&
        !     'projector descriptors for atom with mproj ',iat,mproj
        nlpspd%nproj=nlpspd%nproj+mproj

        ! coarse grid quantities
        call  pregion_size(geocode,rxyz(1,iat),radii_cf(at%iatype(iat),2),cpmult, &
             hx,hy,hz,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3)

        nlpspd%nboxp_c(1,1,iat)=nl1
        nlpspd%nboxp_c(1,2,iat)=nl2       
        nlpspd%nboxp_c(1,3,iat)=nl3       

        nlpspd%nboxp_c(2,1,iat)=nu1
        nlpspd%nboxp_c(2,2,iat)=nu2
        nlpspd%nboxp_c(2,3,iat)=nu3

        !now control the 

        call fill_logrid(geocode,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,0,1,  &
             at%ntypes,at%iatype(iat),rxyz(1,iat),radii_cf(1,2),cpmult,hx,hy,hz,logrid)
        call num_segkeys(n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,logrid,mseg,mvctr)

        nlpspd%nseg_p(2*iat-1)=nlpspd%nseg_p(2*iat-2) + mseg
        nlpspd%nvctr_p(2*iat-1)=nlpspd%nvctr_p(2*iat-2) + mvctr
        istart=istart+mvctr*mproj

        ! fine grid quantities
        call  pregion_size(geocode,rxyz(1,iat),radii_cf(at%iatype(iat),2),fpmult,&
             hx,hy,hz,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3)

        nlpspd%nboxp_f(1,1,iat)=nl1
        nlpspd%nboxp_f(1,2,iat)=nl2
        nlpspd%nboxp_f(1,3,iat)=nl3

        nlpspd%nboxp_f(2,1,iat)=nu1
        nlpspd%nboxp_f(2,2,iat)=nu2
        nlpspd%nboxp_f(2,3,iat)=nu3

        call fill_logrid(geocode,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,0,1,  &
             at%ntypes,at%iatype(iat),rxyz(1,iat),radii_cf(1,2),fpmult,hx,hy,hz,logrid)
        call num_segkeys(n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,logrid,mseg,mvctr)
        !if (iproc.eq.0) write(*,'(1x,a,2(1x,i0))') 'mseg,mvctr, fine  projectors ',mseg,mvctr
        nlpspd%nseg_p(2*iat)=nlpspd%nseg_p(2*iat-1) + mseg
        nlpspd%nvctr_p(2*iat)=nlpspd%nvctr_p(2*iat-1) + mvctr

        istart=istart+7*mvctr*mproj

     else  !(atom has no nonlocal PSP, e.g. H)
        nlpspd%nseg_p(2*iat-1)=nlpspd%nseg_p(2*iat-2) 
        nlpspd%nvctr_p(2*iat-1)=nlpspd%nvctr_p(2*iat-2) 
        nlpspd%nseg_p(2*iat)=nlpspd%nseg_p(2*iat-1) 
        nlpspd%nvctr_p(2*iat)=nlpspd%nvctr_p(2*iat-1) 
     endif
  enddo

  if (iproc.eq.0) then
     write(*,'(44x,a)') '------'
     write(*,'(1x,a,i21)') 'Total number of projectors =',nlpspd%nproj
  end if

  ! allocations for arrays holding the projectors and their data descriptors
  allocate(nlpspd%keyg_p(2,nlpspd%nseg_p(2*at%nat)),stat=i_stat)
  call memocc(i_stat,product(shape(nlpspd%keyg_p))*kind(nlpspd%keyg_p),&
       'keyg_p','createprojectorsarrays')
  allocate(nlpspd%keyv_p(nlpspd%nseg_p(2*at%nat)),stat=i_stat)
  call memocc(i_stat,product(shape(nlpspd%keyv_p))*kind(nlpspd%keyv_p),&
       'keyv_p','createprojectorsarrays')
  nlpspd%nprojel=istart-1
  allocate(proj(nlpspd%nprojel),stat=i_stat)
  call memocc(i_stat,product(shape(proj))*kind(proj),'proj','createprojectorsarrays')


  ! After having determined the size of the projector descriptor arrays fill them
  istart_c=1
  do iat=1,at%nat
     call numb_proj(at%iatype(iat),at%ntypes,at%psppar,at%npspcode,mproj)
     if (mproj.ne.0) then 

        ! coarse grid quantities
        nl1=nlpspd%nboxp_c(1,1,iat) 
        nl2=nlpspd%nboxp_c(1,2,iat) 
        nl3=nlpspd%nboxp_c(1,3,iat) 

        nu1=nlpspd%nboxp_c(2,1,iat)
        nu2=nlpspd%nboxp_c(2,2,iat)
        nu3=nlpspd%nboxp_c(2,3,iat)
        call fill_logrid(geocode,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,0,1,  &
             at%ntypes,at%iatype(iat),rxyz(1,iat),radii_cf(1,2),cpmult,hx,hy,hz,logrid)

        iseg=nlpspd%nseg_p(2*iat-2)+1
        mseg=nlpspd%nseg_p(2*iat-1)-nlpspd%nseg_p(2*iat-2)

        call segkeys(n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,  & 
             logrid,mseg,nlpspd%keyg_p(1,iseg),nlpspd%keyv_p(iseg))

        ! fine grid quantities
        nl1=nlpspd%nboxp_f(1,1,iat)
        nl2=nlpspd%nboxp_f(1,2,iat)
        nl3=nlpspd%nboxp_f(1,3,iat)

        nu1=nlpspd%nboxp_f(2,1,iat)
        nu2=nlpspd%nboxp_f(2,2,iat)
        nu3=nlpspd%nboxp_f(2,3,iat)
        call fill_logrid(geocode,n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,0,1,  &
             at%ntypes,at%iatype(iat),rxyz(1,iat),radii_cf(1,2),fpmult,hx,hy,hz,logrid)
        iseg=nlpspd%nseg_p(2*iat-1)+1
        mseg=nlpspd%nseg_p(2*iat)-nlpspd%nseg_p(2*iat-1)
        call segkeys(n1,n2,n3,nl1,nu1,nl2,nu2,nl3,nu3,  & 
             logrid,mseg,nlpspd%keyg_p(1,iseg),nlpspd%keyv_p(iseg))

     endif
  enddo

  if (iproc.eq.0 .and. nlpspd%nproj /=0) write(*,'(1x,a)',advance='no') &
       'Calculating wavelets expansion of projectors...'
  !warnings related to the projectors norm
  nwarnings=0
  radmin=1.d10
  !allocate these vectors up to the maximum size we can get

  iproj=0
  fpi=(4.d0*atan(1.d0))**(-.75d0)
  do iat=1,at%nat
     rx=rxyz(1,iat) 
     ry=rxyz(2,iat) 
     rz=rxyz(3,iat)
     ityp=at%iatype(iat)

     !decide the loop bounds
     do l=1,4 !generic case, also for HGHs (for GTH it will stop at l=2)
        do i=1,3 !generic case, also for HGHs (for GTH it will stop at i=2)
           if (at%psppar(l,i,ityp).ne.0.d0) then
              gau_a=at%psppar(l,0,ityp)
              factor=sqrt(2.d0)*fpi/(sqrt(gau_a)**(2*(l-1)+4*i-1))
              do m=1,2*l-1
                 mvctr_c=nlpspd%nvctr_p(2*iat-1)-nlpspd%nvctr_p(2*iat-2)
                 mvctr_f=nlpspd%nvctr_p(2*iat  )-nlpspd%nvctr_p(2*iat-1)
                 istart_f=istart_c+mvctr_c
                 nl1_c=nlpspd%nboxp_c(1,1,iat)
                 nl2_c=nlpspd%nboxp_c(1,2,iat)
                 nl3_c=nlpspd%nboxp_c(1,3,iat)
                 nl1_f=nlpspd%nboxp_f(1,1,iat)
                 nl2_f=nlpspd%nboxp_f(1,2,iat)
                 nl3_f=nlpspd%nboxp_f(1,3,iat)

                 nu1_c=nlpspd%nboxp_c(2,1,iat)
                 nu2_c=nlpspd%nboxp_c(2,2,iat)
                 nu3_c=nlpspd%nboxp_c(2,3,iat)
                 nu1_f=nlpspd%nboxp_f(2,1,iat)
                 nu2_f=nlpspd%nboxp_f(2,2,iat)
                 nu3_f=nlpspd%nboxp_f(2,3,iat)

                 call calc_coeff_proj(l,i,m,nterm_max,nterm,lx,ly,lz,fac_arr)

                 fac_arr(1:nterm)=factor*fac_arr(1:nterm)

                 call crtproj(geocode,iproc,nterm,n1,n2,n3,nl1_c,nu1_c,nl2_c,nu2_c,nl3_c,nu3_c, &
                      & nl1_f,nu1_f,nl2_f,nu2_f,nl3_f,nu3_f,radii_cf(at%iatype(iat),2), & 
                      & cpmult,fpmult,hx,hy,hz,gau_a,fac_arr,rx,ry,rz,lx,ly,lz, & 
                      & mvctr_c,mvctr_f,proj(istart_c), &
                      & proj(istart_f))

                 iproj=iproj+1
                 ! testing
                 call wnrm(mvctr_c,mvctr_f,proj(istart_c), &
                      & proj(istart_f),scpr)
                 if (abs(1.d0-scpr).gt.1.d-2) then
                    if (abs(1.d0-scpr).gt.1.d-1) then
                       if (iproc == 0) then
                          write(*,'(1x,a)')'error found!'
                          write(*,'(1x,a,i4,a,a6,a,i1,a,i1,a,f4.3)')&
                               'The norm of the nonlocal PSP for atom n=',iat,&
                               ' (',trim(at%atomnames(at%iatype(iat))),&
                               ') labeled by l=',l,' m=',m,' is ',scpr
                          write(*,'(1x,a)')&
                               'while it is supposed to be about 1.0. Control PSP data or reduce grid spacing.'
!!$                          write(*,'(1x,a,f6.3,a)')&
!!$                               'It should be of the order of the hardest PSP radius (here',&
!!$                               gau_a,').'
                       end if
                       stop
                    else
                       nwarnings=nwarnings+1
                       radmin=min(radmin,gau_a)
                    end if
!!$                    print *,'norm projector for atom ',trim(at%atomnames(at%iatype(iat))),&
!!$                         'iproc,l,i,rl,scpr=',iproc,l,i,gau_a,scpr
!!$                    stop 'norm projector'
                 end if

                 ! testing end
                 istart_c=istart_f+7*mvctr_f
                 if (istart_c.gt.istart) stop 'istart_c > istart'

                 !do iterm=1,nterm
                 !   if (iproc.eq.0) write(*,'(1x,a,i0,1x,a,1pe10.3,3(1x,i0))') &
                 !        'projector: iat,atomname,gau_a,lx,ly,lz ', & 
                 !        iat,trim(at%atomnames(at%iatype(iat))),gau_a,lx(iterm),ly(iterm),lz(iterm)
                 !enddo


              enddo
           endif
        enddo
     enddo
  enddo
  if (iproj.ne.nlpspd%nproj) stop 'incorrect number of projectors created'
  ! projector part finished
  if (iproc == 0 .and. nlpspd%nproj /=0) then
     if (nwarnings == 0) then
        write(*,'(1x,a)')'done.'
     else
        write(*,'(1x,a,i0,a)')'found ',nwarnings,' warnings.'
        write(*,'(1x,a)')'Some projectors may be too rough.'
        write(*,'(1x,a,f6.3)')&
             'Consider the possibility of reducing hgrid for having a more accurate run.'
     end if
  end if

  i_all=-product(shape(logrid))*kind(logrid)
  deallocate(logrid,stat=i_stat)
  call memocc(i_stat,i_all,'logrid','createprojectorsarrays')

END SUBROUTINE createProjectorsArrays

subroutine import_gaussians(geocode,iproc,nproc,at,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3, & 
     norb,norbp,occup,n1,n2,n3,nvctrp,hx,hy,hz,rxyz,rhopot,pot_ion,wfd,bounds,nlpspd,proj,& 
     pkernel,ixc,psi,psit,hpsi,eval,accurex,datacode,nscatterarr,ngatherarr,nspin,spinsgn)

  use module_interfaces, except_this_one => import_gaussians
  use module_types
  use Poisson_Solver

  implicit none
  include 'mpif.h'
  type(atoms_data), intent(in) :: at
  type(wavefunctions_descriptors), intent(in) :: wfd
  type(convolutions_bounds), intent(in) :: bounds
  type(nonlocal_psp_descriptors), intent(in) :: nlpspd
  character(len=1), intent(in) :: geocode,datacode
  integer, intent(in) :: iproc,nproc,norb,norbp,n1,n2,n3,ixc
  integer, intent(in) :: nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nvctrp,nspin
  real(kind=8), intent(in) :: hx,hy,hz
  integer, dimension(0:nproc-1,4), intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
  integer, dimension(0:nproc-1,2), intent(in) :: ngatherarr 
  real(kind=8), dimension(norb), intent(in) :: spinsgn,occup
  real(kind=8), dimension(3,at%nat), intent(in) :: rxyz
  real(kind=8), dimension(nlpspd%nprojel), intent(in) :: proj
  real(kind=8), dimension(*), intent(in) :: pkernel
  real(kind=8), dimension(*), intent(inout) :: rhopot,pot_ion
  real(kind=8), intent(out) :: accurex
  real(kind=8), dimension(norb), intent(out) :: eval
  real(kind=8), dimension(:,:), pointer :: psi,psit,hpsi

  !local variables
  integer :: i,iorb,i_stat,i_all,ierr,info,jproc,n_lp,jorb,n1i,n2i,n3i
  real(kind=8) :: hxh,hyh,hzh,tt,eks,eexcu,vexcu,epot_sum,ekin_sum,ehart,eproj_sum
  real(kind=8), dimension(:), allocatable :: work_lp,pot,ones
  real(kind=8), dimension(:,:), allocatable :: hamovr

  if (iproc.eq.0) then
     write(*,'(1x,a)')&
          '--------------------------------------------------------- Import Gaussians from CP2K'
  end if


  if (nspin /= 1) then
     if (iproc==0) write(*,'(1x,a)')&
          'Gaussian importing is possible only for non-spin polarised calculations'
     stop
  end if

  hxh=.5d0*hx
  hyh=.5d0*hy
  hzh=.5d0*hz

  !calculate dimension of the interpolating scaling function grid
  select case(geocode)
     case('F')
        n1i=2*n1+31
        n2i=2*n2+31
        n3i=2*n3+31
     case('S')
        n1i=2*n1+2
        n2i=2*n2+31
        n3i=2*n3+2
     case('P')
        n1i=2*n1+2
        n2i=2*n2+2
        n3i=2*n3+2
  end select


  !allocate the wavefunction in the transposed way to avoid allocations/deallocations
  allocate(psi(nvctrp,norbp*nproc),stat=i_stat)
  call memocc(i_stat,product(shape(psi))*kind(psi),'psi','import_gaussians')

  !read the values for the gaussian code and insert them on psi 
  call gautowav(geocode,iproc,nproc,at%nat,at%ntypes,norb,norbp,n1,n2,n3,&
       nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
       wfd%nvctr_c,wfd%nvctr_f,wfd%nseg_c,wfd%nseg_f,wfd%keyg,wfd%keyv,&
       at%iatype,occup,rxyz,hx,hy,hz,psi,eks)

!!$  !!plot the initial gaussian wavefunctions
!!$  !do i=2*iproc+1,2*iproc+2
!!$  !   iounit=15+3*(i-1)
!!$  !   print *,'iounit',iounit,'-',iounit+2
!!$  !   call plot_wf(iounit,n1,n2,n3,hgrid,nseg_c,nvctr_c,keyg,keyv,nseg_f,nvctr_f,  & 
!!$  !        rxyz(1,1),rxyz(2,1),rxyz(3,1),psi(:,i-2*iproc:i-2*iproc), & 
!!$          ibyz_c,ibzxx_c,ibxxyy_c,ibyz_ff,ibzxx_f,ibxxyy_f,ibyyzz_r,&
!!$          nfl1,nfu1,nfl2,nfu2,nfl3,nfu3)
!!$  !end do


  ! resulting charge density and potential
  allocate(ones(norb),stat=i_stat)
  call memocc(i_stat,product(shape(ones))*kind(ones),'ones','import_gaussians')
  ones(:)=1.0d0

  call sumrho(geocode,iproc,nproc,norb,norbp,n1,n2,n3,hxh,hyh,hzh,&
       occup,wfd,psi,rhopot,n1i*n2i*nscatterarr(iproc,1),nscatterarr,1,1,ones,&
       nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,bounds)

  call PSolver(geocode,datacode,iproc,nproc,n1i,n2i,n3i,ixc,hxh,hyh,hzh,&
       rhopot,pkernel,pot_ion,ehart,eexcu,vexcu,0.d0,.true.,1)

  !allocate the wavefunction in the transposed way to avoid allocations/deallocations
  allocate(hpsi(nvctrp,norbp*nproc),stat=i_stat)
  call memocc(i_stat,product(shape(hpsi))*kind(hpsi),'hpsi','import_gaussians')

  call HamiltonianApplication(geocode,iproc,nproc,at,hx,hy,hz,&
       norb,norbp,occup,n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,wfd,bounds,nlpspd,proj,&
       ngatherarr,n1i*n2i*nscatterarr(iproc,2),&
       rhopot(1+n1i*n2i*nscatterarr(iproc,4)),&
       psi,hpsi,ekin_sum,epot_sum,eproj_sum,1,1,ones)

  i_all=-product(shape(ones))*kind(ones)
  deallocate(ones,stat=i_stat)
  call memocc(i_stat,i_all,'ones','import_gaussians')


  accurex=abs(eks-ekin_sum)
  if (iproc.eq.0) write(*,'(1x,a,2(f19.10))') 'done. ekin_sum,eks:',ekin_sum,eks

  if (iproc.eq.0) then
     write(*,'(1x,a,3(1x,1pe18.11))') 'ekin_sum,epot_sum,eproj_sum',  & 
          ekin_sum,epot_sum,eproj_sum
     write(*,'(1x,a,3(1x,1pe18.11))') '   ehart,   eexcu,    vexcu',ehart,eexcu,vexcu
  endif

  !after having applied the hamiltonian to all the atomic orbitals
  !we split the semicore orbitals from the valence ones
  !this is possible since the semicore orbitals are the first in the 
  !order, so the linear algebra on the transposed wavefunctions 
  !may be splitted

  if (iproc.eq.0) write(*,'(1x,a)',advance='no')&
       'Imported Wavefunctions Orthogonalization:'

  call DiagHam(iproc,nproc,at%natsc,nspin,1,norb,0,norb,norbp,nvctrp,wfd,&
       psi,hpsi,psit,eval)

  if (iproc.eq.0) write(*,'(1x,a)')'done.'

END SUBROUTINE import_gaussians

subroutine input_wf_diag(geocode,iproc,nproc,at,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
     norb,norbp,n1,n2,n3,nvctrp,hx,hy,hz,rxyz,rhopot,pot_ion,wfd,bounds,nlpspd,proj,  &
     pkernel,ixc,psi,hpsi,psit,eval,accurex,datacode,nscatterarr,ngatherarr,nspin,spinsgn)
  ! Input wavefunctions are found by a diagonalization in a minimal basis set
  ! Each processors write its initial wavefunctions into the wavefunction file
  ! The files are then read by readwave
  use module_interfaces, except_this_one => input_wf_diag
  use module_types
  use Poisson_Solver
  implicit none
  include 'mpif.h'
  type(atoms_data), intent(in) :: at
  type(wavefunctions_descriptors), intent(in) :: wfd
  type(nonlocal_psp_descriptors), intent(in) :: nlpspd
  type(convolutions_bounds), intent(in) :: bounds
  character(len=1), intent(in) :: datacode,geocode
  integer, intent(in) :: iproc,nproc,norb,norbp,n1,n2,n3,ixc
  integer, intent(in) :: nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,nvctrp
  integer, intent(inout) :: nspin
  real(kind=8), intent(in) :: hx,hy,hz
  integer, dimension(0:nproc-1,4), intent(in) :: nscatterarr !n3d,n3p,i3s+i3xcsh-1,i3xcsh
  integer, dimension(0:nproc-1,2), intent(in) :: ngatherarr 
  real(kind=8), dimension(norb), intent(in) :: spinsgn
  real(kind=8), dimension(3,at%nat), intent(in) :: rxyz
  real(kind=8), dimension(nlpspd%nprojel), intent(in) :: proj
  real(kind=8), dimension(*), intent(in) :: pkernel
  real(kind=8), dimension(*), intent(inout) :: rhopot,pot_ion
  real(kind=8), intent(out) :: accurex
  real(kind=8), dimension(norb), intent(out) :: eval
  real(kind=8), dimension(:,:), pointer :: psi,hpsi,psit
  !local variables
  real(kind=8), parameter :: eps_mach=1.d-12
  logical :: parallel
  integer, parameter :: ngx=31
  integer :: i,iorb,iorbsc,imatrsc,iorbst,imatrst,i_stat,i_all,ierr,info,jproc,jpst,norbeyou
  integer :: norbe,norbep,norbi,norbj,norbeme,ndim_hamovr,n_lp,norbi_max,norbsc,n1i,n2i,n3i
  integer :: ispin,norbu,norbd,iorbst2,ist,n2hamovr,nsthamovr,nspinor
  real(kind=8) :: hxh,hyh,hzh,tt,eks,eexcu,vexcu,epot_sum,ekin_sum,ehart,eproj_sum,etol
  logical, dimension(:,:), allocatable :: scorb
  integer, dimension(:), allocatable :: ng
  integer, dimension(:,:), allocatable :: nl,norbsc_arr
  real(kind=8), dimension(:), allocatable :: work_lp,pot,evale,occupe,spinsgne
  real(kind=8), dimension(:,:), allocatable :: xp,occupat,hamovr!,psi,hpsi
  real(kind=8), dimension(:,:,:), allocatable :: psiat
  !real(kind=8), dimension(:,:), pointer :: psi,hpsi


  !Calculate no. up and down orbitals for spin-polarized starting guess
  norbu=0
  norbd=0
  do iorb=1,norb
     if(spinsgn(iorb)>0.0d0) norbu=norbu+1
     if(spinsgn(iorb)<0.0d0) norbd=norbd+1
  end do
  if(nspin==4) then
     nspinor=4
     nspin=2
  else
     nspinor=1
  end if
  !calculate dimension of the interpolating scaling function grid
  select case(geocode)
     case('F')
        n1i=2*n1+31
        n2i=2*n2+31
        n3i=2*n3+31
     case('S')
        n1i=2*n1+2
        n2i=2*n2+31
        n3i=2*n3+2
     case('P')
        n1i=2*n1+2
        n2i=2*n2+2
        n3i=2*n3+2
  end select


  allocate(xp(ngx,at%ntypes),stat=i_stat)
  call memocc(i_stat,product(shape(xp))*kind(xp),'xp','input_wf_diag')
  allocate(psiat(ngx,5,at%ntypes),stat=i_stat)
  call memocc(i_stat,product(shape(psiat))*kind(psiat),'psiat','input_wf_diag')
  allocate(occupat(5,at%ntypes),stat=i_stat)
  call memocc(i_stat,product(shape(occupat))*kind(occupat),'occupat','input_wf_diag')
  allocate(ng(at%ntypes),stat=i_stat)
  call memocc(i_stat,product(shape(ng))*kind(ng),'ng','input_wf_diag')
  allocate(nl(4,at%ntypes),stat=i_stat)
  call memocc(i_stat,product(shape(nl))*kind(nl),'nl','input_wf_diag')
  allocate(scorb(4,at%natsc),stat=i_stat)
  call memocc(i_stat,product(shape(scorb))*kind(scorb),'scorb','input_wf_diag')

  allocate(norbsc_arr(at%natsc+1,nspin),stat=i_stat)
  call memocc(i_stat,product(shape(norbsc_arr))*kind(norbsc_arr),'norbsc_arr','input_wf_diag')

  if (iproc.eq.0) then
     write(*,'(1x,a)')&
          '------------------------------------------------------- Input Wavefunctions Creation'
  end if

  !Generate the input guess via the inguess_generator
  call readAtomicOrbitals(iproc,ngx,xp,psiat,occupat,ng,nl,at%nzatom,at%nelpsp,at%psppar,&
       & at%npspcode,norbe,norbsc,at%atomnames,at%ntypes,at%iatype,at%iasctype,at%nat,at%natsc,&
       nspin,scorb,norbsc_arr)

  !  allocate wavefunctions and their occupation numbers
  allocate(occupe(nspin*norbe),stat=i_stat)
  call memocc(i_stat,product(shape(occupe))*kind(occupe),'occupe','input_wf_diag')
  !the number of orbitals to be considered is doubled in the case of a spin-polarised calculation
  tt=dble(nspin*norbe)/dble(nproc)
  norbep=int((1.d0-eps_mach*tt) + tt)

  if (iproc == 0 .and. nproc>1) then
     jpst=0
     do jproc=0,nproc-2
        norbeme=max(min((jproc+1)*norbep,nspin*norbe)-jproc*norbep,0)
        norbeyou=max(min((jproc+2)*norbep,nspin*norbe)-(jproc+1)*norbep,0)
        if (norbeme /= norbeyou) then
           !this is a screen output that must be modified
           write(*,'(3(a,i0),a)')&
                ' Processes from ',jpst,' to ',jproc,' treat ',norbeme,' inguess orbitals '
           jpst=jproc+1
        end if
     end do
     write(*,'(3(a,i0),a)')&
          ' Processes from ',jpst,' to ',nproc-1,' treat ',norbeyou,' inguess orbitals '
  end if

  hxh=.5d0*hx
  hyh=.5d0*hy
  hzh=.5d0*hz

  parallel=(nproc > 1)

  
  !allocate the wavefunction in the transposed way to avoid allocations/deallocations
  allocate(psi(nvctrp,norbep*nproc*nspinor),stat=i_stat)
  call memocc(i_stat,product(shape(psi))*kind(psi),'psi','input_wf_diag')
  
  ! Create input guess orbitals
  call createAtomicOrbitals(geocode,iproc,nproc,at%atomnames,&
       at%nat,rxyz,norbe,norbep,norbsc,occupe,occupat,ngx,xp,psiat,ng,nl,&
       wfd%nvctr_c,wfd%nvctr_f,n1,n2,n3,hx,hy,hz,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,&
       wfd%nseg_c,wfd%nseg_f,wfd%keyg,wfd%keyv,at%iatype,at%ntypes,&
       at%iasctype,at%natsc,at%nspinat,nspin,psi,eks,scorb)
  
!!$  !!plot the initial LCAO wavefunctions
!!$  !do i=2*iproc+1,2*iproc+2
!!$  !   iounit=15+3*(i-1)
!!$  !   print *,'iounit',iounit,'-',iounit+2
!!$  !   call plot_wf(iounit,n1,n2,n3,hgrid,nseg_c,nvctr_c,keyg,keyv,nseg_f,nvctr_f,  & 
!!$  !        rxyz(1,1),rxyz(2,1),rxyz(3,1),psi(:,i-2*iproc:i-2*iproc), &
!!$          ibyz_c,ibzxx_c,ibxxyy_c,ibyz_ff,ibzxx_f,ibxxyy_f,ibyyzz_r,&
!!$          nfl1,nfu1,nfl2,nfu2,nfl3,nfu3)
!!$  !end do


  i_all=-product(shape(scorb))*kind(scorb)
  deallocate(scorb,stat=i_stat)
  call memocc(i_stat,i_all,'scorb','input_wf_diag')
  i_all=-product(shape(xp))*kind(xp)
  deallocate(xp,stat=i_stat)
  call memocc(i_stat,i_all,'xp','input_wf_diag')
  i_all=-product(shape(psiat))*kind(psiat)
  deallocate(psiat,stat=i_stat)
  call memocc(i_stat,i_all,'psiat','input_wf_diag')
  i_all=-product(shape(occupat))*kind(occupat)
  deallocate(occupat,stat=i_stat)
  call memocc(i_stat,i_all,'occupat','input_wf_diag')
  i_all=-product(shape(ng))*kind(ng)
  deallocate(ng,stat=i_stat)
  call memocc(i_stat,i_all,'ng','input_wf_diag')
  i_all=-product(shape(nl))*kind(nl)
  deallocate(nl,stat=i_stat)
  call memocc(i_stat,i_all,'nl','input_wf_diag')


  ! resulting charge density and potential
  allocate(spinsgne(nspin*norbe),stat=i_stat)
  call memocc(i_stat,product(shape(spinsgne))*kind(spinsgne),'spinsgne','input_wf_diag')
  ist=1
  do ispin=1,nspin
     spinsgne(ist:ist+norbe-1)=real(1-2*(ispin-1),kind=8)
     ist=norbe+1
  end do
    
  call sumrho(geocode,iproc,nproc,nspin*norbe,norbep,n1,n2,n3,hxh,hyh,hzh,occupe,  & 
       wfd,psi,rhopot,n1i*n2i*nscatterarr(iproc,1),nscatterarr,nspin,1,spinsgne, &
       nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,bounds)

  
  call PSolver('F',datacode,iproc,nproc,n1i,n2i,n3i,ixc,hxh,hyh,hzh,&
       rhopot,pkernel,pot_ion,ehart,eexcu,vexcu,0.d0,.true.,nspin)
  

  !allocate the wavefunction in the transposed way to avoid allocations/deallocations
  allocate(hpsi(nvctrp,norbep*nproc),stat=i_stat)
  call memocc(i_stat,product(shape(hpsi))*kind(hpsi),'hpsi','input_wf_diag')
  
  call HamiltonianApplication(geocode,iproc,nproc,at,hx,hy,hz,&
       nspin*norbe,norbep,occupe,n1,n2,n3,nfl1,nfu1,nfl2,nfu2,nfl3,nfu3,wfd,bounds,nlpspd,proj,&
       ngatherarr,n1i*n2i*nscatterarr(iproc,2),rhopot(1+n1i*n2i*nscatterarr(iproc,4)),&
       psi,hpsi,ekin_sum,epot_sum,eproj_sum,nspin,1,spinsgne)

  i_all=-product(shape(spinsgne))*kind(spinsgne)
  deallocate(spinsgne,stat=i_stat)
  call memocc(i_stat,i_all,'spinsgne','input_wf_diag')

  i_all=-product(shape(occupe))*kind(occupe)
  deallocate(occupe,stat=i_stat)
  call memocc(i_stat,i_all,'occupe','input_wf_diag')

  accurex=abs(eks-ekin_sum)
  !tolerance for comparing the eigenvalues in the case of degeneracies
  etol=accurex/real(norbe,kind=8)
  if (iproc.eq.0) write(*,'(1x,a,2(f19.10))') 'done. ekin_sum,eks:',ekin_sum,eks
  if (iproc.eq.0) then
     write(*,'(1x,a,3(1x,1pe18.11))') 'ekin_sum,epot_sum,eproj_sum',  & 
          ekin_sum,epot_sum,eproj_sum
     write(*,'(1x,a,3(1x,1pe18.11))') '   ehart,   eexcu,    vexcu',ehart,eexcu,vexcu
  endif


  !after having applied the hamiltonian to all the atomic orbitals
  !we split the semicore orbitals from the valence ones
  !this is possible since the semicore orbitals are the first in the 
  !order, so the linear algebra on the transposed wavefunctions 
  !may be splitted

  if (iproc.eq.0) write(*,'(1x,a)',advance='no')&
       'Input Wavefunctions Orthogonalization:'

  call DiagHam(iproc,nproc,at%natsc,nspin,nspinor,norbu,norbd,norb,norbp,nvctrp,wfd,&
       psi,hpsi,psit,eval,norbe,norbep,etol,norbsc_arr)
 
!  print *,'AFT DiagHam',iproc,(sum(psi(:,iorb)),iorb=1,norbp*nspinor)

  i_all=-product(shape(norbsc_arr))*kind(norbsc_arr)
  deallocate(norbsc_arr,stat=i_stat)
  call memocc(i_stat,i_all,'norbsc_arr','input_wf_diag')

  if(nspinor==4) nspin=4

!  if(nspin==4) then
!     call psitospi(iproc,nproc,norbe,norbep,norbsc,nat,&
!          wfd%nvctr_c,wfd%nvctr_f,at%iatype,at%ntypes,&
!          at%iasctype,at%natsc,at%nspinat,nspin,spinsgne,psi)
!  end if


  if (iproc.eq.0) write(*,'(1x,a)')'done.'

end subroutine input_wf_diag

!!****f* BigDFT/DiagHam
!! NAME
!!    DiagHam
!!
!! FUNCTION
!!    Diagonalise the hamiltonian in a basis set of norbe orbitals and select the first
!!    norb eigenvectors. Works also with the spin-polarisation case and perform also the 
!!    treatment of semicore atoms. 
!!    In the absence of norbe parameters, it simply diagonalize the hamiltonian in the given
!!    orbital basis set.
!!
!! COPYRIGHT
!!    Copyright (C) 2008 CEA Grenoble
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!
!! INPUT VARIABLES
!!    iproc  process id
!!    nproc  number of mpi processes
!!    natsc  number of semicore atoms for the orthogonalisation treatment
!!           used as a dimension for the array of semicore atoms
!!    nspin  spin polarised id; 1 => non spin-polarised; 2 => spin-polarised (collinear)
!!    norbu  number of up orbitals in the spin-polarised case; for non spin-pol equal to norb
!!    norbd  number of down orbitals in the spin-polarised case; for non spin-pol equal to 0
!!    norb   total number of orbitals of the resulting eigenfunctions
!!    norbp  number of orbitals in parallel. For nproc=1 norbp=norb
!!    nvctrp number of points of the wavefunctions for each orbital in the transposed sense
!!    wfd    data structure of the wavefunction descriptors
!!    norbe  (optional) number of orbitals of the initial set of wavefunction, to be reduced
!!    etol   tolerance for which a degeneracy should be printed. Set to zero if absent
!!
!! INPUT-OUTPUT VARIABLES
!!    psi    wavefunctions. 
!!           If norbe is absent: on input, set of norb wavefunctions, 
!!                               on output eigenfunctions
!!           If norbe is present: on input, set of norbe wavefunctions, 
!!                                on output the first norb eigenfunctions
!!    hpsi   hamiltonian on the wavefunctions
!!           If norbe is absent: on input, set of norb arrays, 
!!                               destroyed on output
!!           If norbe is present: on input, set of norbe wavefunctions, 
!!                                destroyed on output
!!
!! OUTPUT VARIABLES
!!    psit   wavefunctions in the transposed form.
!!           On input: nullified
!!           on Output: transposed wavefunction but only if nproc>1, nullified otherwise
!!    eval   array of the first norb eigenvalues       
!!    
!!
!!
!! WARNING
!!
!! AUTHOR
!!    Luigi Genovese
!! CREATION DATE
!!    February 2008
!!
!! SOURCE
!! 
subroutine DiagHam(iproc,nproc,natsc,nspin,nspinor,norbu,norbd,norb,norbp,nvctrp,wfd,&
     psi,hpsi,psit,eval,& !mandatory
     norbe,norbep,etol,norbsc_arr) !optional
  use module_types
  implicit none
  type(wavefunctions_descriptors), intent(in) :: wfd
  integer, intent(in) :: iproc,nproc,natsc,nspin,nspinor,norb,norbu,norbd,norbp,nvctrp
  real(kind=8), dimension(norb), intent(out) :: eval
  real(kind=8), dimension(:,:), pointer :: psi,hpsi,psit
  !optional arguments
  integer, optional, intent(in) :: norbe,norbep
  real(kind=8), optional, intent(in) :: etol
  integer, optional, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
   !real(kind=8), optional, dimension(:,:), pointer :: ppsi
  !local variables
  include 'mpif.h'
  logical :: semicore,minimal
  integer :: i,ndim_hamovr,i_all,i_stat,n2hamovr,nsthamovr,ierr,norbi_max
  integer :: norbtot,norbtotp,natsceff,norbsc,ndh1,ispin,nvctr
  real(kind=8) :: tolerance
  integer, dimension(:,:), allocatable :: norbgrp
  real(kind=8), dimension(:,:), allocatable :: hamovr
  real(kind=8), dimension(:,:), pointer :: psiw


  !performs some check of the arguments
  if (present(etol)) then
     tolerance=etol
  else
     tolerance=0.d0
  end if

  if (present(norbe) .neqv. present(norbep)) then
     if (iproc ==0) write(*,'(1x,a)')&
          'ERROR (DiagHam): the variables norbe and norbep must be present at the same time'
     stop
  else
     minimal=present(norbe)
  end if

  semicore=present(norbsc_arr)

  !define the grouping of the orbitals: for the semicore case, follow the semocore atoms,
  !otherwise use the number of orbitals, separated in the spin-polarised case
  !fro the spin polarised case it is supposed that the semicore orbitals are disposed equally
  if (semicore) then
     norbi_max=maxval(norbsc_arr)

     !calculate the dimension of the overlap matrix
     !take the maximum as the two spin dimensions
     ndim_hamovr=0
     do ispin=1,nspin
        ndh1=0
        norbsc=0
        do i=1,natsc+1
           ndh1=ndh1+norbsc_arr(i,ispin)**2
        end do
        ndim_hamovr=max(ndim_hamovr,ndh1)
     end do
     if (natsc > 0) then
        if (nspin == 2) then
           if (sum(norbsc_arr(1:natsc,1)) /= sum(norbsc_arr(1:natsc,2))) then
              write(*,'(1x,a)')&
                'ERROR (DiagHam): The number of semicore orbitals must be the same for both spins'
              stop
           end if
        end if
        norbsc=sum(norbsc_arr(1:natsc,1))
     else
        norbsc=0
     end if

     natsceff=natsc
     allocate(norbgrp(natsceff+1,nspin),stat=i_stat)
     call memocc(i_stat,product(shape(norbgrp))*kind(norbgrp),'norbgrp','diagham')

     !assign the grouping of the orbitals
     norbgrp=norbsc_arr
  else
     norbi_max=max(norbu,norbd) !this works also for non spin-polarised since there norbu=norb
     ndim_hamovr=norbi_max**2

     natsceff=0
     allocate(norbgrp(1,nspin),stat=i_stat)
     call memocc(i_stat,product(shape(norbgrp))*kind(norbgrp),'norbgrp','diagham')

     norbsc=0
     norbgrp(1,1)=norbu
     if (nspin == 2) norbgrp(1,2)=norbd

  end if

  !assign total orbital number for calculating the overlap matrix and diagonalise the system
  if(minimal) then
     norbtot=nspin*norbe !beware that norbe is equal both for spin up and down
     norbtotp=norbep !this is coherent with nspin*norbe
  else
     norbtot=norb
     norbtotp=norbp
  end if

  if (nproc > 1) then
     !transpose all the wavefunctions for having a piece of all the orbitals 
     !for each processor
     allocate(psiw(nvctrp,norbtotp*nproc),stat=i_stat)
     call memocc(i_stat,product(shape(psiw))*kind(psiw),'psiw','diagham')

     call switch_waves(iproc,nproc,norbtot,norbtotp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,psi,psiw,1)
     call MPI_ALLTOALL(psiw,nvctrp*norbtotp,MPI_DOUBLE_PRECISION,  &
          psi,nvctrp*norbtotp,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)

     call switch_waves(iproc,nproc,norbtot,norbtotp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,hpsi,psiw,1)
     call MPI_ALLTOALL(psiw,nvctrp*norbtotp,MPI_DOUBLE_PRECISION,  &
          hpsi,nvctrp*norbtotp,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)

     i_all=-product(shape(psiw))*kind(psiw)
     deallocate(psiw,stat=i_stat)
     call memocc(i_stat,i_all,'psiw','diagham')
     !end of transposition

     !allocation values
     n2hamovr=4
     nsthamovr=3
  else
     !allocation values
     n2hamovr=2
     nsthamovr=1
  end if

  allocate(hamovr(nspin*ndim_hamovr,n2hamovr),stat=i_stat)
  call memocc(i_stat,product(shape(hamovr))*kind(hamovr),'hamovr','diagham')

  if (iproc.eq.0) write(*,'(1x,a)',advance='no')&
       'Overlap Matrix...'

  call overlap_matrices(nproc,norbtotp,nvctrp,natsceff,nspin,ndim_hamovr,norbgrp,&
       hamovr(1,nsthamovr),psi,hpsi)

  if (minimal) then
     !deallocate hpsi in the case of a minimal basis
     i_all=-product(shape(hpsi))*kind(hpsi)
     deallocate(hpsi,stat=i_stat)
     call memocc(i_stat,i_all,'hpsi','diagham')
  end if

  if (nproc > 1) then
     !reduce the overlap matrix between all the processors
     call MPI_ALLREDUCE(hamovr(1,3),hamovr(1,1),2*nspin*ndim_hamovr,&
          MPI_DOUBLE_PRECISION,MPI_SUM,MPI_COMM_WORLD,ierr)
  end if

  call solve_eigensystem(iproc,norb,norbu,norbd,norbi_max,ndim_hamovr,natsceff,nspin,tolerance,&
       norbgrp,hamovr,eval)

  !in the case of minimal basis allocate now the transposed wavefunction
  !otherwise do it only in parallel
  if (minimal .or. nproc > 1) then
        allocate(psit(nvctrp,nspinor*norbp*nproc),stat=i_stat)
        call memocc(i_stat,product(shape(psit))*kind(psit),'psit','diagham')
  else
     psit => hpsi
  end if

  if (iproc.eq.0) write(*,'(1x,a)',advance='no')'Building orthogonal Wavefunctions...'

  nvctr=wfd%nvctr_c+7*wfd%nvctr_f
  call build_eigenvectors(nproc,norbu,norbd,norbp,norbtotp,nvctrp,nvctr,natsceff,nspin,nspinor, &
       ndim_hamovr,norbgrp,hamovr,psi,psit)

  i_all=-product(shape(hamovr))*kind(hamovr)
  deallocate(hamovr,stat=i_stat)
  call memocc(i_stat,i_all,'hamovr','diagham')
  i_all=-product(shape(norbgrp))*kind(norbgrp)
  deallocate(norbgrp,stat=i_stat)
  call memocc(i_stat,i_all,'norbgrp','diagham')

  if (minimal) then
     !deallocate the old psi
     i_all=-product(shape(psi))*kind(psi)
     deallocate(psi,stat=i_stat)
     call memocc(i_stat,i_all,'psi','diagham')
  else if (nproc == 1) then
     !reverse objects for the normal diagonalisation in serial
     !at this stage hpsi is the eigenvectors and psi is the old wavefunction
     !this will restore the correct identification
     nullify(hpsi)
     hpsi => psi
     nullify(psi)
     psi => psit
  end if

  !orthogonalise the orbitals in the case of semi-core atoms
  if (norbsc > 0) then
     if(nspin==1) then
        call orthon_p(iproc,nproc,norb,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit) 
     else
        call orthon_p(iproc,nproc,norbu,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit) 
        if(norbd>0) then
           call orthon_p(iproc,nproc,norbd,nvctrp,wfd%nvctr_c+7*wfd%nvctr_f,psit(1,norbu+1)) 
        end if
     end if
  end if

  if (minimal) then
     allocate(hpsi(nvctrp,norbp*nproc*nspinor),stat=i_stat)
     call memocc(i_stat,product(shape(hpsi))*kind(hpsi),'hpsi','diagham')
!     hpsi=0.0d0
  end if

  if (nproc > 1) then

     call timing(iproc,'Un-TransComm  ','ON')
     call MPI_ALLTOALL(psit,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,  &
          hpsi,nvctrp*norbp*nspinor,MPI_DOUBLE_PRECISION,MPI_COMM_WORLD,ierr)
     call timing(iproc,'Un-TransComm  ','OF')

     if (minimal) then
        !allocate the direct wavefunction
        allocate(psi(nvctrp,norbp*nproc*nspinor),stat=i_stat)
        call memocc(i_stat,product(shape(psi))*kind(psi),'psi','diagham')
!        psi=0.0d0
     end if
     
!     print *,'UnSwiWa',iproc,nproc,norb,norbp,wfd%nvctr_c+7*wfd%nvctr_f,nvctrp
     call timing(iproc,'Un-TransSwitch','ON')
     call unswitch_waves(iproc,nproc,norb,norbp,wfd%nvctr_c,wfd%nvctr_f,nvctrp,hpsi,psi,nspinor)
     call timing(iproc,'Un-TransSwitch','OF')

  else
     if (minimal) psi => psit
     !for the moment we can leave things like that
     nullify(psit)
  end if
!  print *,'Exit DiagHam',shape(psi),shape(hpsi),nspinor
end subroutine DiagHam
!!***

subroutine overlap_matrices(nproc,norbep,nvctrp,natsc,nspin,ndim_hamovr,norbsc_arr,hamovr,psi,hpsi)
  implicit none
  integer, intent(in) :: nproc,norbep,nvctrp,natsc,ndim_hamovr,nspin
  integer, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(kind=8), dimension(nspin*ndim_hamovr,2), intent(out) :: hamovr
  real(kind=8), dimension(nvctrp,norbep*nproc), intent(in) :: psi,hpsi
  !local variables
  integer ::iorbst,imatrst,norbi,i,ispin

  !calculate the overlap matrix for each group of the semicore atoms
  !       hamovr(jorb,iorb,3)=+psit(k,jorb)*hpsit(k,iorb)
  !       hamovr(jorb,iorb,4)=+psit(k,jorb)* psit(k,iorb)
  iorbst=1
  imatrst=1
  do ispin=1,nspin !this construct assumes that the semicore is identical for both the spins
     do i=1,natsc+1
        norbi=norbsc_arr(i,ispin)
        !print *,norbi,norbi,nvctrp,iorbst,imatrst
        call DGEMM('T','N',norbi,norbi,nvctrp,1.d0,psi(1,iorbst),nvctrp,hpsi(1,iorbst),nvctrp,&
             0.d0,hamovr(imatrst,1),norbi)
        call DGEMM('T','N',norbi,norbi,nvctrp,1.d0,psi(1,iorbst),nvctrp,psi(1,iorbst),nvctrp,&
             0.d0,hamovr(imatrst,2),norbi)
        iorbst=iorbst+norbi
        imatrst=imatrst+norbi**2
     end do
  end do
  
end subroutine overlap_matrices

subroutine solve_eigensystem(iproc,norb,norbu,norbd,norbi_max,ndim_hamovr,natsc,nspin,etol,&
     norbsc_arr,hamovr,eval)
  implicit none
  integer, intent(in) :: iproc,norb,norbi_max,ndim_hamovr,natsc,nspin,norbu,norbd
  integer, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(kind=8), intent(in) :: etol
  real(kind=8), dimension(nspin*ndim_hamovr,2), intent(inout) :: hamovr
  real(kind=8), dimension(norb), intent(out) :: eval
  !local variables
  character(len=64) :: message
  integer :: iorbst,imatrst,norbi,n_lp,info,i_all,i_stat,iorb,i,ndegen,nwrtmsg,jorb,istart,norbj
  real(kind=8) :: tt,sum
  real(kind=8), dimension(2) :: preval
  real(kind=8), dimension(:), allocatable :: work_lp,evale,randarr


  !found the eigenfunctions for each group
  n_lp=max(10,4*norbi_max)
  allocate(work_lp(n_lp),stat=i_stat)
  call memocc(i_stat,product(shape(work_lp))*kind(work_lp),'work_lp','solve_eigensystem')
  allocate(evale(nspin*norbi_max),stat=i_stat)
  call memocc(i_stat,product(shape(evale))*kind(evale),'evale','solve_eigensystem')

  if (iproc.eq.0) write(*,'(1x,a)')'Linear Algebra...'

  nwrtmsg=0
  ndegen=0

  preval=0.d0
  iorbst=1
  imatrst=1
  do i=1,natsc+1
     norbi=norbsc_arr(i,1)

     call DSYGV(1,'V','U',norbi,hamovr(imatrst,1),norbi,hamovr(imatrst,2),&
          norbi,evale,work_lp,n_lp,info)
     if (info.ne.0) write(*,*) 'DSYGV ERROR',info,i,natsc+1

     !do the diagonalisation separately in case of spin polarization     
     if (nspin==2) then
        norbj=norbsc_arr(i,2)
        call DSYGV(1,'V','U',norbj,hamovr(imatrst+ndim_hamovr,1),&
             norbj,hamovr(imatrst+ndim_hamovr,2),norbj,evale(norbi+1),work_lp,n_lp,info)
        if (info.ne.0) write(*,*) 'DSYGV ERROR',info,i,natsc+1
     end if

     !write the matrices on a file
     !open(33+2*(i-1))
     !do jjorb=1,norbi
     !   write(33+2*(i-1),'(2000(1pe10.2))')&
     !        (hamovr(imatrst-1+jiorb+(jjorb-1)*norbi,1),jiorb=1,norbi)
     !end do
     !close(33+2*(i-1))
     !open(34+2*(i-1))
     !do jjorb=1,norbi
     !   write(34+2*(i-1),'(2000(1pe10.2))')&
     !        (hamovr(imatrst-1+jjorb+(jiorb-1)*norbi,1),jiorb=1,norbi)
     !end do
     !close(34+2*(i-1))
     

     !writing rules, control if the last eigenvector is degenerate
     !do this for each spin
     !for each spin it is supposed that only the last group is not completely passed
     !and also that the components of each of the group but the last are the same for up and 
     !down polarisation. Do not work properly in the other cases
     do iorb=1,norbi
        if (nspin==1) then
           if (nwrtmsg==1) then
              if (abs(evale(iorb)-preval(1)) <= etol) then
                 !degeneracy found
                 message='  <- found degeneracy'
                 ndegen=ndegen+1
              else
                 nwrtmsg=0
              end if
           end if
           if (iorb+iorbst-1 == norb) then
              nwrtmsg=1
              message=' <- Last eigenvalue for input wavefunctions'
              preval(1)=evale(iorb)
           end if
           if (iproc.eq.0) then
              if (nwrtmsg == 1) then
                 write(*,'(1x,a,i0,a,1x,1pe21.14,a)') &
                      'evale(',iorb+iorbst-1,')=',evale(iorb),trim(message)
              else
                 write(*,'(1x,a,i0,a,1x,1pe21.14)') &
                      'evale(',iorb+iorbst-1,')=',evale(iorb)
              end if
           end if
        else
           if (nwrtmsg==1) then
              if (abs(evale(iorb)-preval(1)) <= etol .and. &
                   abs(evale(iorb+norbi)-preval(2)) <= etol) then
                 !degeneracy found
                 message='  <-deg->  '
                 !ndegen=ndegen+1 removed, only for non magnetized cases
              else if (abs(evale(iorb)-preval(1)) <= etol) then
                 !degeneracy found
                 message='  <-deg    '
              else if (abs(evale(iorb+norbi)-preval(2)) <= etol) then
                 !degeneracy found
                 message='    deg->  '
              else
                 nwrtmsg=0
              end if
           end if
           if (iorb+iorbst-1 == norbu .and. iorb+iorbst-1 == norbd) then
              nwrtmsg=1
              message='  <-Last-> ' 
              preval(1)=evale(iorb)
              preval(2)=evale(iorb+norbi)
           else if (iorb+iorbst-1 == norbu) then
              nwrtmsg=1
              message='  <-Last   '
              preval(1)=evale(iorb)
           else if (iorb+iorbst-1 == norbd) then
              nwrtmsg=1
              message='    Last-> '
              preval(2)=evale(iorb+norbi)
           end if
           if (iproc == 0) then
              if (nwrtmsg==1) then
                 write(*,'(1x,a,i4,a,1x,1pe21.14,a12,a,i4,a,1x,1pe21.14)') &
                      'evale(',iorb+iorbst-1,',u)=',evale(iorb),message,&
                      'evale(',iorb+iorbst-1,',d)=',evale(iorb+norbi)
              else
                 write(*,'(1x,a,i4,a,1x,1pe21.14,12x,a,i4,a,1x,1pe21.14)') &
                      'evale(',iorb+iorbst-1,',u)=',evale(iorb),&
                      'evale(',iorb+iorbst-1,',d)=',evale(iorb+norbi)
              end if
           end if
        end if
     end do
     if (nspin==1) then
        do iorb=iorbst,min(norbi+iorbst-1,norb)
           eval(iorb)=evale(iorb-iorbst+1)
        end do
     else
        do iorb=iorbst,min(norbi+iorbst-1,norbu)
           eval(iorb)=evale(iorb-iorbst+1)
        end do
        do iorb=iorbst,min(norbi+iorbst-1,norbd)
           eval(iorb+norbu)=evale(iorb-iorbst+1+norbi)
        end do
     end if
     iorbst=iorbst+norbi
     imatrst=imatrst+norbi**2
  end do

  i_all=-product(shape(work_lp))*kind(work_lp)
  deallocate(work_lp,stat=i_stat)
  call memocc(i_stat,i_all,'work_lp','solve_eigensystem')
  i_all=-product(shape(evale))*kind(evale)
  deallocate(evale,stat=i_stat)
  call memocc(i_stat,i_all,'evale','solve_eigensystem')

!!$  !remove the degeneracy treatment, to be tested later
!!$  ndegen=0
!!$  !in the case of degeneracy
!!$  !transform the passage matrix with all the components of the eigenspace 
!!$  if (ndegen /= 0) then
!!$     !create the array of random numbers
!!$     !it must be the same for all the processors so use some fake functions
!!$     allocate(randarr(0:ndegen),stat=i_stat)
!!$     call memocc(i_stat,product(shape(randarr))*kind(randarr),'randarr','solve_eigensystem')
!!$     sum=0.d0
!!$     do i=0,ndegen
!!$        tt=abs(dsin(real(73*i,kind=8)+.7d0))
!!$        !call random_number(tt)
!!$        randarr(i)=tt
!!$        sum=sum+tt**2
!!$     end do
!!$     tt=1.d0/sqrt(sum)
!!$     do i=0,ndegen
!!$        randarr(i)=tt*randarr(i)
!!$     end do
!!$
!!$     !the degeneracy may appear ONLY in the group of the valence electrons (last one)
!!$     iorbst=iorbst-norbi
!!$     imatrst=imatrst-norbi**2
!!$     istart=norbu-iorbst+1
!!$     if (norbd < norbu .and. norbd>0) istart=norbd-iorbst+1
!!$     !print *,'imatrst',imatrst,iorbst,norbi,istart
!!$     do jorb=1,norbi
!!$        tt=randarr(0)
!!$        hamovr(imatrst-1+jorb+norbi*(istart-1),1)=&
!!$             tt*hamovr(imatrst-1+jorb+norbi*(istart-1),1)
!!$        !print *, imatrst-1+jorb+norbi*(istart-1),ndim_hamovr,tt
!!$     end do
!!$     do iorb=istart+1,istart+ndegen
!!$        tt=randarr(iorb-istart)
!!$        do jorb=1,norbi
!!$           hamovr(imatrst-1+jorb+norbi*(istart-1),1)=&
!!$                hamovr(imatrst-1+jorb+norbi*(istart-1),1)+tt*hamovr(imatrst-1+jorb+norbi*(iorb-1),1)
!!$           !print *, imatrst-1+jorb+norbi*(iorb-1),ndim_hamovr,tt
!!$        end do
!!$     end do
!!$
!!$     i_all=-product(shape(randarr))*kind(randarr)
!!$     deallocate(randarr,stat=i_stat)
!!$     call memocc(i_stat,i_all,'randarr','solve_eigensystem')
!!$
!!$  end if

end subroutine solve_eigensystem

subroutine build_eigenvectors(nproc,norbu,norbd,norbp,norbep,nvctrp,nvctr,natsc,nspin,nspinor,ndim_hamovr,&
     norbsc_arr,hamovr,psi,ppsit)
  implicit none
  integer, intent(in) :: nproc,norbu,norbd,norbp,norbep,nvctrp,nvctr,natsc,nspin,nspinor,ndim_hamovr
  integer, dimension(natsc+1,nspin), intent(in) :: norbsc_arr
  real(kind=8), dimension(nspin*ndim_hamovr), intent(in) :: hamovr
  real(kind=8), dimension(nvctrp,norbep*nproc), intent(in) :: psi
  real(kind=8), dimension(nvctrp*nspinor,norbp*nproc), intent(out) :: ppsit
  !local variables
  integer :: ispin,iorbst,iorbst2,imatrst,norbsc,norbi,norbj,i,iorb,i_stat,i_all
  real(kind=8) :: tt,mx,my,mz,mnorm,fac
  real, dimension(:), allocatable :: randnoise
  real(kind=8), dimension(:,:), allocatable :: tpsi

  !perform the vector-matrix multiplication for building the input wavefunctions
  ! ppsit(k,iorb)=+psit(k,jorb)*hamovr(jorb,iorb,1)
  !!     iorbst=1
  !!     imatrst=1
  !!     do i=1,natsc
  !!        norbi=norbsc_arr(i)
  !!        call DGEMM('N','N',nvctrp,norbi,norbi,1.d0,psi(1,iorbst),nvctrp,&
  !!             hamovr(imatrst,1),norbi,0.d0,ppsit(1,iorbst),nvctrp)
  !!        iorbst=iorbst+norbi
  !!        imatrst=imatrst+norbi**2
  !!     end do
  !!     norbi=norbsc_arr(natsc+1)
  !!     norbj=norb-norbsc
  !!     call DGEMM('N','N',nvctrp,norbj,norbi,1.d0,psi(1,iorbst),nvctrp,&
  !!          hamovr(imatrst,1),norbi,0.d0,ppsit(1,iorbst),nvctrp)

  !ppsi(k,iorb)=+psi(k,jorb)*hamovr(jorb,iorb,1)

  if(nspinor==1) then
     iorbst=1
     iorbst2=1
     imatrst=1
     do ispin=1,nspin
        norbsc=0
        do i=1,natsc
           norbi=norbsc_arr(i,ispin)
           norbsc=norbsc+norbi
           call DGEMM('N','N',nvctrp,norbi,norbi,1.d0,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.d0,ppsit(1,iorbst2),nvctrp)
           iorbst=iorbst+norbi
           iorbst2=iorbst2+norbi
           imatrst=imatrst+norbi**2
        end do
        norbi=norbsc_arr(natsc+1,ispin)
        if(ispin==1) norbj=norbu-norbsc
        if(ispin==2) norbj=norbd-norbsc
        !        write(*,'(1x,a,5i4)') "DIMS:",norbi,norbj,iorbst,imatrst
        !        norbj=norb-norbsc
        if(norbj>0) then
           call DGEMM('N','N',nvctrp,norbj,norbi,1.d0,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.d0,ppsit(1,iorbst2),nvctrp)
        end if
        iorbst=norbi+norbsc+1 !this is equal to norbe+1
        iorbst2=norbu+1
        imatrst=ndim_hamovr+1
     end do
  else
     allocate(tpsi(nvctrp,norbep*nproc))
!     print *,'DIM SHOW',shape(tpsi),shape(psi),shape(ppsit),norbep*nproc,norbu,norbd
     iorbst=1
     iorbst2=1
     imatrst=1
     do ispin=1,nspin
        norbsc=0
        do i=1,natsc
           norbi=norbsc_arr(i,ispin)
           norbsc=norbsc+norbi
           call DGEMM('N','N',nvctrp,norbi,norbi,1.d0,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.d0,tpsi(1,iorbst2),nvctrp)
           iorbst=iorbst+norbi
           iorbst2=iorbst2+norbi
           imatrst=imatrst+norbi**2
        end do
        norbi=norbsc_arr(natsc+1,ispin)
        if(ispin==1) norbj=norbu-norbsc
        if(ispin==2) norbj=norbd-norbsc
        !        write(*,'(1x,a,5i4)') "DIMS:",norbi,norbj,iorbst,imatrst
        !        norbj=norb-norbsc
        if(norbj>0) then
           call DGEMM('N','N',nvctrp,norbj,norbi,1.d0,psi(1,iorbst),nvctrp,&
                hamovr(imatrst),norbi,0.d0,tpsi(1,iorbst2),nvctrp)
        end if
        iorbst=norbi+norbsc+1 !this is equal to norbe+1
        iorbst2=norbu+1
        imatrst=ndim_hamovr+1
     end do
     ppsit=0.0d0
     open(unit=1978,file='moments')
     read(1978,*) mx,my,mz
     close(1978)
     mnorm=sqrt(mx**2+my**2+mz**2)
     mx=mx/mnorm;my=my/mnorm;mz=mz/mnorm
     fac=1.0d0/(2.0d0)
 !    print *,'Moments',mx,my,mz
     do iorb=1,norbu
        do i=1,nvctrp
!           ppsit(2*i-1,iorb)=(mz-fac*(my+mx))*tpsi(i,iorb)
!           ppsit(2*i,iorb)=fac*(my-mx)*tpsi(i,iorb)
!           ppsit(2*i+2*nvctrp-1,iorb)=(fac*(mx-my))*tpsi(i,iorb)
!           ppsit(2*i+2*nvctrp,iorb)=-fac*(my-mx)*tpsi(i,iorb)
           ppsit(2*i-1,iorb)=(mz+fac*(my+mx))*tpsi(i,iorb)
           ppsit(2*i,iorb)=fac*(my-mx)*tpsi(i,iorb)
           ppsit(2*i+2*nvctrp-1,iorb)=(fac*(mx-my))*tpsi(i,iorb)
           ppsit(2*i+2*nvctrp,iorb)=fac*(my-mx)*tpsi(i,iorb)
        end do
     end do
     do iorb=norbu+1,norbu+norbd
        do i=1,nvctrp
           ppsit(2*i-1,iorb)=(fac*(mx+my))*tpsi(i,iorb)
           ppsit(2*i,iorb)=-fac*(my+mx)*tpsi(i,iorb)
           ppsit(2*i+2*nvctrp-1,iorb)=-(mz+fac*(my+mx))*tpsi(i,iorb)
           ppsit(2*i+2*nvctrp,iorb)=-fac*(my-mx)*tpsi(i,iorb)
        end do
     end do
!     print *,'EIGe',shape(ppsit),shape(tpsi),norbu,norbd,nspinor
     deallocate(tpsi)
  end if
!!$  !here we should put a random noise on the spin-down components in the case of norbu=norbd
!!$  if (nspin == 2 .and. norbu==norbd) then
!!$     allocate(randnoise(nvctrp),stat=i_stat)
!!$     call memocc(i_stat,product(shape(randnoise))*kind(randnoise),'randnoise','build_eigenvectors')
!!$     call random_number(randnoise)
!!$
!!$     do iorb=1,norbu
!!$        do i=1,nvctrp
!!$           tt=50.d0*real(randnoise(nvctrp-i+1)-0.5,kind=8)/real(nvctrp*nproc,kind=8)
!!$           ppsit(i,iorb)=tt+ppsit(i,iorb)
!!$        end do
!!$     end do
!!$
!!$     do iorb=norbu+1,norbu+norbd
!!$        do i=1,nvctrp
!!$           tt=50.d0*real(randnoise(i)-0.5,kind=8)/real(nvctrp*nproc,kind=8)
!!$           ppsit(i,iorb)=tt+ppsit(i,iorb)
!!$        end do
!!$     end do
!!$
!!$     i_all=-product(shape(randnoise))*kind(randnoise)
!!$     deallocate(randnoise,stat=i_stat)
!!$     call memocc(i_stat,i_all,'randnoise','build_eigenvectors')
!!$  end if

end subroutine build_eigenvectors

