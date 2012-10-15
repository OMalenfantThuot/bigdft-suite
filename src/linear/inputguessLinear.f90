!>   input guess wavefunction diagonalization
subroutine inputguessConfinement(iproc, nproc, inputpsi, at, &
     input, hx, hy, hz, lzd, lorbs, rxyz, denspot, rhopotold,&
     nlpspd, proj, GPU, lphi,orbs,tmb, tmblarge,energs,overlapmatrix)
  ! Input wavefunctions are found by a diagonalization in a minimal basis set
  ! Each processors write its initial wavefunctions into the wavefunction file
  ! The files are then read by readwave
  use module_base
  use module_interfaces, exceptThisOne => inputguessConfinement
  use module_types
  use Poisson_Solver
  implicit none
  !Arguments
  integer, intent(in) :: iproc,nproc,inputpsi
  real(gp), intent(in) :: hx, hy, hz
  type(atoms_data), intent(inout) :: at
  type(nonlocal_psp_descriptors), intent(in) :: nlpspd
  type(GPU_pointers), intent(inout) :: GPU
  type(DFT_local_fields), intent(inout) :: denspot
  type(input_variables),intent(in) :: input
  type(local_zone_descriptors),intent(inout) :: lzd
  type(orbitals_data),intent(in) :: lorbs
  real(gp), dimension(3,at%nat), intent(in) :: rxyz
  real(wp), dimension(nlpspd%nprojel), intent(inout) :: proj
  real(dp),dimension(max(lzd%glr%d%n1i*lzd%glr%d%n2i*denspot%dpbox%n3p,1)*input%nspin),intent(inout) ::  rhopotold
  real(8),dimension(max(lorbs%npsidim_orbs,lorbs%npsidim_comp)),intent(out) :: lphi
  type(orbitals_data),intent(inout) :: orbs
  type(DFT_wavefunction),intent(inout) :: tmb
  type(DFT_wavefunction),intent(inout) :: tmblarge
  type(energy_terms),intent(inout) :: energs
  real(8),dimension(tmb%orbs%norb,tmb%orbs%norb),intent(out):: overlapmatrix

  ! Local variables
  type(gaussian_basis) :: G !basis for davidson IG
  character(len=*), parameter :: subname='inputguessConfinement'
  integer :: istat,iall,iat,nspin_ig,iorb,nvirt,norbat
  real(gp) :: hxh,hyh,hzh,eks,fnrm,V3prb,x0
  integer, dimension(:,:), allocatable :: norbsc_arr
  real(gp), dimension(:), allocatable :: locrad
  real(wp), dimension(:,:,:), pointer :: psigau
  integer, dimension(:),allocatable :: norbsPerAt, mapping, inversemapping
  logical,dimension(:),allocatable :: covered
  integer, parameter :: nmax=6,lmax=3,noccmax=2,nelecmax=32
  logical :: isoverlap
  integer :: ist,jorb,iadd,ii,jj,ityp
  integer :: ldim,gdim,jlr,iiorb
  integer :: infoCoeff
  type(orbitals_data) :: orbs_gauss
  type(GPU_pointers) :: GPUe
  character(len=2) :: symbol
  real(kind=8) :: rcov,rprb,ehomo,amu                                          
  real(kind=8) :: neleconf(nmax,0:lmax)                                        
  integer :: nsccode,mxpl,mxchg


  call nullify_orbitals_data(orbs_gauss)

  ! Allocate some arrays we need for the input guess.
  allocate(norbsc_arr(at%natsc+1,input%nspin+ndebug),stat=istat)
  call memocc(istat,norbsc_arr,'norbsc_arr',subname)
  allocate(locrad(at%nat+ndebug),stat=istat)
  call memocc(istat,locrad,'locrad',subname)
  allocate(norbsPerAt(at%nat), stat=istat)
  call memocc(istat, norbsPerAt, 'norbsPerAt', subname)
  allocate(mapping(tmb%orbs%norb), stat=istat)
  call memocc(istat, mapping, 'mapping', subname)
  allocate(covered(tmb%orbs%norb), stat=istat)
  call memocc(istat, covered, 'covered', subname)
  allocate(inversemapping(tmb%orbs%norb), stat=istat)
  call memocc(istat, inversemapping, 'inversemapping', subname)

  GPUe = GPU

  ! Spin for inputguess orbitals
  if (input%nspin == 4) then
     nspin_ig=1
  else
     nspin_ig=input%nspin
  end if

  ! Determine how many atomic orbitals we have. Maybe we have to increase this number to more than
  ! its 'natural' value.
  norbat=0
  ist=0
  do iat=1,at%nat
      ii=input%lin%norbsPerType(at%iatype(iat))
      iadd=0
      do 
          ! Count the number of atomic orbitals and increase the number if necessary until we have more
          ! (or equal) atomic orbitals than basis functions per atom.
          jj=1*nint(at%aocc(1,iat))+3*nint(at%aocc(3,iat))+&
               5*nint(at%aocc(7,iat))+7*nint(at%aocc(13,iat))
          if(jj>=ii) then
              ! we have enough atomic orbitals
              exit
          else
              ! add additional orbitals
              iadd=iadd+1
              select case(iadd)
                  case(1) 
                      at%aocc(1,iat)=1.d0
                  case(2) 
                      at%aocc(3,iat)=1.d0
                  case(3) 
                      at%aocc(7,iat)=1.d0
                  case(4) 
                      at%aocc(13,iat)=1.d0
                  case default 
                      write(*,'(1x,a)') 'ERROR: more than 16 basis functions per atom are not possible!'
                      stop
              end select
          end if
      end do
      norbsPerAt(iat)=jj
      norbat=norbat+norbsPerAt(iat)
  end do



  ! This array gives a mapping from the 'natural' orbital distribution (i.e. simply counting up the atoms) to
  ! our optimized orbital distribution (determined by in orbs%inwhichlocreg).
  iiorb=0
  covered=.false.
  do iat=1,at%nat
      do iorb=1,norbsPerAt(iat)
          iiorb=iiorb+1
          ! Search the corresponding entry in inwhichlocreg
          do jorb=1,tmb%orbs%norb
              if(covered(jorb)) cycle
              jlr=tmb%orbs%inwhichlocreg(jorb)
              if( tmb%lzd%llr(jlr)%locregCenter(1)==rxyz(1,iat) .and. &
                  tmb%lzd%llr(jlr)%locregCenter(2)==rxyz(2,iat) .and. &
                  tmb%lzd%llr(jlr)%locregCenter(3)==rxyz(3,iat) ) then
                  covered(jorb)=.true.
                  mapping(iiorb)=jorb
                  exit
              end if
          end do
      end do
  end do

  ! Inverse mapping
  do iorb=1,tmb%orbs%norb
      do jorb=1,tmb%orbs%norb
          if(mapping(jorb)==iorb) then
              inversemapping(iorb)=jorb
              exit
          end if
      end do
  end do



  nvirt=0

  do ityp=1,at%ntypes
     call eleconf(at%nzatom(ityp),at%nelpsp(ityp),symbol,rcov,rprb,ehomo,neleconf,nsccode,mxpl,mxchg,amu)
     if(4.d0*rprb>input%lin%locrad_type(ityp)) then
         if(iproc==0) write(*,'(3a,es10.2)') 'WARNING: locrad for atom type ',trim(symbol), &
                      ' is too small; minimal value is ',4.d0*rprb
     end if
     if(input%lin%potentialPrefac_lowaccuracy(ityp)>0.d0) then
         x0=(70.d0/input%lin%potentialPrefac_lowaccuracy(ityp))**.25d0
         if(iproc==0) write(*,'(a,a,2es11.2,es12.3)') 'type, 4.d0*rprb, x0, input%lin%locrad_type(ityp)', &
                      trim(symbol),4.d0*rprb, x0, input%lin%locrad_type(ityp)
         V3prb=input%lin%potentialPrefac_lowaccuracy(ityp)*(4.d0*rprb)**4
         if(iproc==0) write(*,'(a,es14.4)') 'V3prb',V3prb
     end if
  end do


  call inputguess_gaussian_orbitals_forLinear(iproc,nproc,tmb%orbs%norb,at,rxyz,nvirt,nspin_ig,&
       at%nat, norbsPerAt, mapping, &
       lorbs,orbs_gauss,norbsc_arr,locrad,G,psigau,eks,input%lin%potentialPrefac_lowaccuracy)
  ! Take inwhichlocreg from tmb (otherwise there might be problems after the restart...
  do iorb=1,tmb%orbs%norb
      orbs_gauss%inwhichlocreg(iorb)=tmb%orbs%onwhichatom(iorb)
  end do


  ! Grid spacing on fine grid.
  hxh=.5_gp*hx
  hyh=.5_gp*hy
  hzh=.5_gp*hz

  ! Transform the atomic orbitals to the wavelet basis.
  orbs_gauss%inwhichlocreg=tmb%orbs%inwhichlocreg
  call wavefunction_dimension(tmb%lzd,orbs_gauss)
  call to_zero(max(lorbs%npsidim_orbs,lorbs%npsidim_comp), lphi(1))
  call gaussians_to_wavelets_new(iproc,nproc,tmb%lzd,orbs_gauss,G,&
       psigau(1,1,min(tmb%orbs%isorb+1,tmb%orbs%norb)),lphi)

  iall=-product(shape(psigau))*kind(psigau)
  deallocate(psigau,stat=istat)
  call memocc(istat,iall,'psigau',subname)

  call deallocate_gwf(G,subname)


  ! Deallocate locrad, which is not used any longer.
  iall=-product(shape(locrad))*kind(locrad)
  deallocate(locrad,stat=istat)
  call memocc(istat,iall,'locrad',subname)


  ! Create the potential. First calculate the charge density.
  do iorb=1,tmb%orbs%norb
      tmb%orbs%occup(iorb)=orbs_gauss%occup(iorb)
  end do
  call sumrho(denspot%dpbox,tmb%orbs,tmb%lzd,GPUe,at%sym,denspot%rhod,&
       lphi,denspot%rho_psi,inversemapping)
  call communicate_density(denspot%dpbox,input%nspin,&!hxh,hyh,hzh,tmbgauss%lzd,&
       denspot%rhod,denspot%rho_psi,denspot%rhov,.false.)


  if(input%lin%scf_mode==LINEAR_MIXDENS_SIMPLE) then
      call dcopy(max(lzd%glr%d%n1i*lzd%glr%d%n2i*denspot%dpbox%n3p,1)*input%nspin, denspot%rhov(1), 1, rhopotold(1), 1)
  end if


  call updatePotential(input%ixc,input%nspin,denspot,energs%eh,energs%exc,energs%evxc)

  if(input%lin%scf_mode==LINEAR_MIXPOT_SIMPLE) then
      call dcopy(max(lzd%glr%d%n1i*lzd%glr%d%n2i*denspot%dpbox%n3p,1)*input%nspin, denspot%rhov(1), 1, rhopotold(1), 1)
  end if

  if (input%exctxpar == 'OP2P') energs%eexctX = uninitialized(energs%eexctX)


  call get_coeff(iproc,nproc,LINEAR_MIXDENS_SIMPLE,lzd,orbs,at,rxyz,denspot,GPU,infoCoeff,energs%ebs,nlpspd,proj,&
       input%SIC,tmb,fnrm,overlapmatrix,.true.,.false.,&
       tmblarge)

  ! Important: Don't use for the rest of the code
  tmblarge%can_use_transposed = .false.

  if(associated(tmblarge%psit_c)) then
      iall=-product(shape(tmblarge%psit_c))*kind(tmblarge%psit_c)
      deallocate(tmblarge%psit_c, stat=istat)
      call memocc(istat, iall, 'tmblarge%psit_c', subname)
  end if
  if(associated(tmblarge%psit_f)) then
      iall=-product(shape(tmblarge%psit_f))*kind(tmblarge%psit_f)
      deallocate(tmblarge%psit_f, stat=istat)
      call memocc(istat, iall, 'tmblarge%psit_f', subname)
  end if
  

  if(iproc==0) write(*,'(1x,a)') '------------------------------------------------------------- Input guess generated.'
  
  ! Deallocate all local arrays.

  ! Deallocate all types that are not needed any longer.
  call deallocate_orbitals_data(orbs_gauss, subname)

  ! Deallocate all remaining local arrays.
  iall=-product(shape(norbsc_arr))*kind(norbsc_arr)
  deallocate(norbsc_arr,stat=istat)
  call memocc(istat,iall,'norbsc_arr',subname)

  iall=-product(shape(norbsPerAt))*kind(norbsPerAt)
  deallocate(norbsPerAt, stat=istat)
  call memocc(istat, iall, 'norbsPerAt',subname)

  iall=-product(shape(mapping))*kind(mapping)
  deallocate(mapping, stat=istat)
  call memocc(istat, iall, 'mapping',subname)

  iall=-product(shape(covered))*kind(covered)
  deallocate(covered, stat=istat)
  call memocc(istat, iall, 'covered',subname)

  iall=-product(shape(inversemapping))*kind(inversemapping)
  deallocate(inversemapping, stat=istat)
  call memocc(istat, iall, 'inversemapping',subname)


END SUBROUTINE inputguessConfinement





