!> @file
!! Medium-level routines associated to the generation of Atomic Orbitals inputguess
!! wavefunctions
!! @author
!!    Copyright (C) 2007-2014 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
!> Handling of input guess creation from basis of atomic orbitals
module ao_inguess
  use module_base, only: gp,memocc,f_err_raise,ndebug,to_zero,f_err_throw,bigdft_mpi

  implicit none

  
  integer, parameter :: nmax_ao=6 !<maximum allowed value of principal quantum number for the electron configuration
  integer, parameter :: lmax_ao=3 !<maximum value of the angular momentum for the electron configuration
  integer, parameter :: nelecmax_ao=32 !<size of the interesting values of the compressed atomic input polarization
  integer, parameter :: noccmax_ao=2 !<maximum number of the occupied input guess orbitals for a given shell

  private:: nmax_ao,lmax_ao,nelecmax_ao,noccmax_ao

contains

  subroutine iguess_generator(izatom,ielpsp,zion,psppar,npspcode,ngv,ngc,nlccpar,ng,nl,&
       &   nmax_occ,noccmax,lmax,occup,expo,psiat,enlargerprb,quartic_prefactor,gaenes_aux)
    implicit none
    logical, intent(in) :: enlargerprb
    integer, intent(in) :: ng,npspcode,nmax_occ,lmax,noccmax,ielpsp,izatom,ngv,ngc
    real(gp), intent(in) :: zion
    integer, dimension(lmax+1), intent(in) :: nl
    real(gp), dimension(0:4,0:6), intent(in) :: psppar
    real(gp), dimension(0:4,max((ngv*(ngv+1)/2)+(ngc*(ngc+1)/2),1)), intent(in) :: nlccpar
    real(gp), dimension(noccmax,lmax+1), intent(in) :: occup
    real(gp), dimension(ng+1), intent(out) :: expo
    real(gp), dimension(ng+1,nmax_occ), intent(out) :: psiat
    real(gp),intent(in),optional:: quartic_prefactor
    real(gp), dimension(nmax_occ),intent(out), optional :: gaenes_aux
    !local variables
    character(len=*), parameter :: subname='iguess_generator'
    integer, parameter :: n_int=100
    real(gp), parameter :: fact=4.0_gp
    !character(len=2) :: symbol
    integer :: lpx!,nsccode,mxpl,mxchg
    integer :: l,i,j,iocc,i_all,i_stat,iorder
    real(gp) :: alpz,alpl,rprb,rcov,rij,a,a0,a0in,tt!,ehomo,amu
    !integer, dimension(6,4) :: neleconf
    !real(kind=8), dimension(6,4) :: neleconf
    real(gp), dimension(4) :: gpot
    real(gp), dimension(noccmax,lmax+1) :: aeval,chrg,res
    real(gp), dimension(:), allocatable :: xp,alps
    real(gp), dimension(:,:), allocatable :: vh,hsep,ofdcoef
    real(gp), dimension(:,:,:), allocatable :: psi
    real(gp), dimension(:,:,:,:), allocatable :: rmt

    !filename = 'psppar.'//trim(atomname)
    if (present(gaenes_aux)) call to_zero(nmax_occ,gaenes_aux(1))


    lpx=0
    lpx_determination: do i=1,4
       if (psppar(i,0) == 0.0_gp) then
          exit lpx_determination
       else
          lpx=i-1
       end if
    end do lpx_determination

    allocate(alps(lpx+1+ndebug),stat=i_stat)
    call memocc(i_stat,alps,'alps',subname)
    allocate(hsep(6,lpx+1+ndebug),stat=i_stat)
    call memocc(i_stat,hsep,'hsep',subname)

    !assignation of radii and coefficients of the local part
    alpz=psppar(0,0)
    alpl=psppar(0,0)
    alps(1:lpx+1)=psppar(1:lpx+1,0)
    gpot(1:4)=psppar(0,1:4)

    !assignation of the coefficents for the nondiagonal terms
    if (npspcode == 2) then !GTH case
       do l=1,lpx+1
          hsep(1,l)=psppar(l,1)
          hsep(2,l)=0.0_gp
          hsep(3,l)=psppar(l,2)
          hsep(4,l)=0.0_gp
          hsep(5,l)=0.0_gp
          hsep(6,l)=psppar(l,3)
       end do
    else if (npspcode == 3) then !HGH case
       allocate(ofdcoef(3,4+ndebug),stat=i_stat)
       call memocc(i_stat,ofdcoef,'ofdcoef',subname)

       ofdcoef(1,1)=-0.5_gp*sqrt(3._gp/5._gp) !h2
       ofdcoef(2,1)=0.5_gp*sqrt(5._gp/21._gp) !h4
       ofdcoef(3,1)=-0.5_gp*sqrt(100.0_gp/63._gp) !h5

       ofdcoef(1,2)=-0.5_gp*sqrt(5._gp/7._gp) !h2
       ofdcoef(2,2)=1._gp/6._gp*sqrt(35._gp/11._gp) !h4
       ofdcoef(3,2)=-7._gp/3._gp*sqrt(1._gp/11._gp) !h5

       ofdcoef(1,3)=-0.5_gp*sqrt(7._gp/9._gp) !h2
       ofdcoef(2,3)=0.5_gp*sqrt(63._gp/143._gp) !h4
       ofdcoef(3,3)=-9._gp*sqrt(1._gp/143._gp) !h5

       ofdcoef(1,4)=0.0_gp !h2
       ofdcoef(2,4)=0.0_gp !h4
       ofdcoef(3,4)=0.0_gp !h5

       !define the values of hsep starting from the pseudopotential file
       do l=1,lpx+1
          hsep(1,l)=psppar(l,1)
          hsep(2,l)=psppar(l,2)*ofdcoef(1,l)
          hsep(3,l)=psppar(l,2)
          hsep(4,l)=psppar(l,3)*ofdcoef(2,l)
          hsep(5,l)=psppar(l,3)*ofdcoef(3,l)
          hsep(6,l)=psppar(l,3)
       end do
       i_all=-product(shape(ofdcoef))*kind(ofdcoef)
       deallocate(ofdcoef,stat=i_stat)
       call memocc(i_stat,i_all,'ofdcoef',subname)
    else if (npspcode == 10 .or. npspcode == 7 .or. npspcode == 12) then !HGH-K case
       ! For PAW this is just the initial guess
       do l=1,lpx+1
          hsep(1,l)=psppar(l,1) !h11
          hsep(2,l)=psppar(l,4) !h12
          hsep(3,l)=psppar(l,2) !h22
          hsep(4,l)=psppar(l,5) !h13
          hsep(5,l)=psppar(l,6) !h23
          hsep(6,l)=psppar(l,3) !h33
       end do
    end if

    !!Just for extracting the covalent radius and rprb
    call atomic_info(izatom,ielpsp,rcov=rcov,rprb=rprb)
!    call eleconf(izatom,ielpsp,symbol,rcov,rprb,ehomo,neleconf,nsccode,mxpl,mxchg,amu)
    !!write(*,*) 'WARNING: multiply rprb with 5!!'
    !!rprb=rprb*5.d0


    if(present(quartic_prefactor)) then
       tt=rprb
       if(quartic_prefactor>0.d0) then
          ! There is a non-zero confinement
          rprb=(1.d0/(2.d0*quartic_prefactor))**.25d0
       else
          ! No confinement is used. Adjust rprb such that the quartic potential has at r=12 the same
          ! value as the parabolic potential
          rprb=144.d0**.25d0*tt
       end if
       !if(iproc==0) write(*,'(2(a,es12.3))') 'quartic potential for AO: modify rprb from ',tt,' to ',rprb
       !write(*,'(2(a,es12.3))') 'quartic potential for AO: modify rprb from ',tt,' to ',rprb
    end if

    if (enlargerprb) then
       !experimental
       rprb=100.0_gp
    end if

    !  occup(:,:)=0.0_gp
    !   do l=0,lmax-1
    !     iocc=0
    !     do i=1,6
    !        if (elecorbs(i,l+1) > 0.0_gp) then
    !           iocc=iocc+1
    !           !print *,'elecorbs',i,l,elecorbs(i,l+1),noccmax
    !            if (iocc > noccmax) stop 'iguess_generator: noccmax too small'
    !           occup(iocc,l+1)=elecorbs(i,l+1)
    !        endif
    !     end do
    !     nl(l+1)=iocc
    !  end do

    !allocate arrays for the gatom routine
    allocate(vh(4*(ng+1)**2,4*(ng+1)**2+ndebug),stat=i_stat)
    call memocc(i_stat,vh,'vh',subname)
    allocate(psi(0:ng,noccmax,lmax+ndebug),stat=i_stat)
    call memocc(i_stat,psi,'psi',subname)
    allocate(xp(0:ng+ndebug),stat=i_stat)
    call memocc(i_stat,xp,'xp',subname)
    allocate(rmt(n_int,0:ng,0:ng,lmax+ndebug),stat=i_stat)
    call memocc(i_stat,rmt,'rmt',subname)

    !can be switched on for debugging
    !if (iproc.eq.0) write(*,'(1x,a,a7,a9,i3,i3,a9,i3,f5.2)')&
    !     'Input Guess Generation for atom',trim(atomname),&
    !     'Z,Zion=',izatom,ielpsp,'ng,rprb=',ng+1,rprb

    rij=3._gp
    ! exponents of gaussians
    a0in=alpz
    a0=a0in/rij
    !       tt=sqrt(sqrt(2._gp))
    tt=2._gp**.3_gp
    do i=0,ng
       a=a0*tt**i
       xp(i)=.5_gp/a**2
    end do

    ! initial guess
    do l=0,lmax-1
       do iocc=1,noccmax
          do i=0,ng
             psi(i,iocc,l+1)=0.0_gp
          end do
       end do
    end do

    call crtvh(ng,lmax-1,xp,vh,rprb,fact,n_int,rmt)
    if(present(quartic_prefactor)) then
       iorder=4
    else
       iorder=2
    end if
    call gatom(rcov,rprb,lmax-1,lpx,noccmax,occup,&
         zion,alpz,gpot,alpl,hsep,alps,ngv,ngc,nlccpar,vh,xp,rmt,fact,n_int,&
         aeval,ng,psi,res,chrg,iorder)
    
    !post-treatment of the inguess data
    do i=1,ng+1
       expo(i)=sqrt(0.5_gp/xp(i-1))
    end do

    i=0
    do l=1,4
       do iocc=1,nl(l)
          i=i+1
          !occupat(i)=occup(iocc,l)
          do j=1,ng+1
             psiat(j,i)=psi(j-1,iocc,l)
             if (present(gaenes_aux)) gaenes_aux(i) = aeval(iocc,l)
          end do
       end do
    end do

    i_all=-product(shape(vh))*kind(vh)
    deallocate(vh,stat=i_stat)
    call memocc(i_stat,i_all,'vh',subname)
    i_all=-product(shape(psi))*kind(psi)
    deallocate(psi,stat=i_stat)
    call memocc(i_stat,i_all,'psi',subname)
    i_all=-product(shape(xp))*kind(xp)
    deallocate(xp,stat=i_stat)
    call memocc(i_stat,i_all,'xp',subname)
    i_all=-product(shape(rmt))*kind(rmt)
    deallocate(rmt,stat=i_stat)
    call memocc(i_stat,i_all,'rmt',subname)
    i_all=-product(shape(hsep))*kind(hsep)
    deallocate(hsep,stat=i_stat)
    call memocc(i_stat,i_all,'hsep',subname)
    i_all=-product(shape(alps))*kind(alps)
    deallocate(alps,stat=i_stat)
    call memocc(i_stat,i_all,'alps',subname)

  END SUBROUTINE iguess_generator

  !> retrieve the information from the atom.
  !! different information can be obtained according to the usage which is needed
  subroutine atomic_info(zatom,zion,symbol,elconf,amu,rcov,rprb,ehomo,nsccode,maxpol,maxchg)
    use yaml_output, only: yaml_toa
    implicit none
    ! Arguments
    integer, intent(in) :: zatom            !< Z number of atom
    integer, intent(in) :: zion             !< Number of valence electrons of the ion (PSP should be in agreement)
    character(len=2), intent(out), optional :: symbol  !< Atomic symbol of Z, from the periodic table of elements
    double precision, intent(out), optional :: rcov        !< Covalent radius, atomic units
    double precision, intent(out), optional :: rprb        !< Parabolic radius for the input guess, of interest in the subroutine "gatom"
    double precision, intent(out), optional :: ehomo       !< Highest occupied molecular orbital energy, atomic units,
    !! See <a>http://physics.nist.gov/PhysRefData/DFTdata/Tables/ptable.html</a>
    double precision, intent(out), optional :: amu         !< Atomic mass unit (use values coming from ABINIT/11util/atmdata.F90)
    double precision, dimension(:,0:), optional :: elconf            !< Occupation number (electron configuration of the PSP atom)
                                                           !! assumed-shape, intent(out) not specified as did not found in the norm if it is legal
    integer, intent(out), optional :: nsccode !< Semicore orbitals, indicated as an integer.
    !! The integer is the n_s + 4*n_p + 16* n_d + 64* n_f
    !! where n_l are the number of semicore orbitals for a given angular momentum
    !! starting from the lower level of course
    integer, intent(out), optional :: maxpol    !< Maximum spin polarisation to be placed on the atom
    integer, intent(out), optional :: maxchg   !< Maximum charge to be placed on the atom

    !local variables
    character(len=2) :: symbol_
    integer :: nsccode_,mxpl_,mxchg_
    double precision :: rprb_,ehomo_,rcov_,amu_
    double precision, dimension(nmax_ao,0:lmax_ao) :: releconf !<these dimensions have to be modified in the following

    !extract all the information from the tabulated values of eleconf-inc.f90 file
    call eleconf(zatom,zion,symbol_,rcov_,rprb_,ehomo_,releconf,nsccode_,mxpl_,mxchg_,amu_)

    !then assign the requested values
    if (present(elconf)) then
       if (f_err_raise(any(shape(elconf) /= shape(releconf)),&
            'Electron Configuration array has wrong shape, found '//&
            trim(yaml_toa(shape(elconf)))//', needed '//&
            trim(yaml_toa(shape(releconf)))//'.',&
            err_name='BIGDFT_RUNTIME_ERROR')) return
       elconf=releconf
    end if

    if (present(symbol)) symbol=symbol_
    if (present(amu))       amu=amu_
    if (present(rcov))     rcov=rcov_
    if (present(rprb))     rprb=rprb_
    if (present(ehomo))   ehomo=ehomo_
    if (present(nsccode)) nsccode=nsccode_
    if (present(maxpol))   maxpol=mxpl_
    if (present(maxchg))   maxchg=mxchg_
    
  end subroutine atomic_info

  !> fill the corresponding arrays with atomic information, compressed as indicated in the module
  subroutine atomic_configuration(zatom,zion,input_pol,nspin,nsccodeIG,occupIG)
    use yaml_output, only: yaml_toa
    implicit none
    integer, intent(in) :: zatom       !< Z number of atom
    integer, intent(in) :: zion        !< Number of valence electrons of the ion (PSP should be in agreement)
    integer, intent(in) :: input_pol   !< input polarisation of the atom as indicated by charge_and_spol routine
    integer, intent(in) :: nspin       !< Spin description 1:spin averaged, 2:collinear spin, 4:spinorial
    integer, intent(out) :: nsccodeIG  !< Code for which states have to be treated as semicore
    real(gp), dimension(nelecmax_ao), intent(out) :: occupIG !<input guess occupation of the atom from the input polarization
    !local variables
    integer :: nsccode,mxpl,mxchg,nsp,nspinor
    integer :: ichg, ispol
    double precision :: elec
    character(len=2) :: symbol
    real(kind=8), dimension(nmax_ao,0:lmax_ao) :: neleconf
    real(gp), dimension(nmax_ao,lmax_ao+1) :: eleconf_

    !control the spin
    select case(nspin)
    case(1)
       nsp=1
       nspinor=1
    case(2)
       nsp=2
       nspinor=1
    case(4)
       nsp=1
       nspinor=4
    case default
       call f_err_throw('nspin not valid. Value=' // trim(yaml_toa(nspin)),&
            err_name='BIGDFT_INPUT_VARIABLES_ERROR')
       return
       !call yaml_warning('nspin not valid. Value=' // trim(yaml_toa(nspin)))
       !write(*,*)' ERROR: nspin not valid:',nspin
       !stop
    end select

    call atomic_info(zatom,zion,elconf=neleconf,nsccode=nsccode,&
         maxpol=mxpl,maxchg=mxchg)

    ! Some checks from input values.
    call charge_and_spol(input_pol,ichg,ispol)

    if (f_err_raise(abs(ispol) > mxpl+abs(ichg),&
         'Input polarisation of '//trim(symbol)//' atom must be <= '//&
         trim(yaml_toa(mxpl))//', while found '//trim(yaml_toa(ispol)),&
         err_name='BIGDFT_INPUT_VARIABLES_ERROR')) return
    if (f_err_raise(abs(ichg) > mxchg,&
         'Input charge of '//trim(symbol)//' atom must be <= '//&
         trim(yaml_toa(mxchg))//', while found '//trim(yaml_toa(ichg)),&
         err_name='BIGDFT_INPUT_VARIABLES_ERROR')) return

    ! Fill this atom with default values from eleconf.
    nsccodeIG=nsccode
    !correct the electronic configuration in case there is a charge
    call correct_semicore(nmax_ao,lmax_ao,ichg,&
         neleconf,eleconf_,nsccodeIG)
    !then compress the information in the occupation numbers
    call at_occnums(ispol,nsp,nspinor,nmax_ao,lmax_ao+1,nelecmax_ao,&
         eleconf_,occupIG)

    !check if the atomic charge is consistent with the input polarization
    !check the total number of electrons
    elec=ao_ig_charge(nspin,occupIG)
    if (nint(elec) /= zion - ichg) then
       if (bigdft_mpi%iproc == 0) call print_eleconf(nspin,occupIG,nsccodeIG)
       call f_err_throw('The total atomic charge '//trim(yaml_toa(elec))//&
            ' is different from the PSP charge '//trim(yaml_toa(nsccodeIG))//&
            ' plus the charge '//trim(yaml_toa(-ichg)),&
            err_name='BIGDFT_INPUT_VARIABLES_ERROR')
       return
    end if
  end subroutine atomic_configuration

  subroutine aocc_from_dict(dict,nspin_in,aocc,nsccode)
    use module_defs, only: gp, UNINITIALIZED,f_malloc_str,f_free_str,assignment(=)
    use dictionaries
    use yaml_output, only: yaml_toa,yaml_map
    implicit none
    type(dictionary), pointer :: dict
    integer, intent(in) :: nspin_in
    integer, intent(out) :: nsccode
    real(gp), dimension(nelecmax_ao), intent(out) :: aocc

    !local variables
    character(len = max_field_length) :: key
    !character(max_field_length), dimension(:), allocatable :: keys
    integer :: i, ln
    integer :: m,n,iocc,icoll,inl,noncoll,l,ispin,is,lsc,nspinor,nspin
    real(gp) :: tt,sh_chg
    integer, dimension(lmax_ao+1) :: nl,nlsc
    real(gp), dimension(2*(2*lmax_ao-1),nmax_ao,lmax_ao+1) :: allocc
    type(dictionary), pointer :: dict_tmp!,dict_it

    !control the spin
    select case(nspin_in)
    case(1)
       nspin=1
       nspinor=1
       noncoll=1
    case(2)
       nspin=2
       nspinor=1
       noncoll=1
    case(4)
       nspin=1
       nspinor=4
       noncoll=2
    end select

    nl(:)=0
    nlsc(:)=0
    allocc(:,:,:) = UNINITIALIZED(1._gp)

    !if non-collinear it is like nspin=1 but with the double of orbitals
    if (nspinor == 4) then
       noncoll=2
    else
       noncoll=1
    end if

    !allocate(keys(dict_size(dict)))
!!    keys=f_malloc_str(max_field_length,dict_size(dict),id='keys')

    !here we have to iterate on the dictionary instead of allocating the array of the keys
    
!!    keys = dict_keys(dict)
!!    do i = 1, dict_size(dict), 1
    dict_tmp=> dict_iter(dict)
    do while(associated(dict_tmp))
       key(1:len(key)) = dict_key(dict_tmp)!keys(i)
       ln = len_trim(key)
       is = 1
       if (key(1:1) == "(" .and. key(ln:ln) == ")") is = 2
       ! Read the major quantum number
       read(key(is:is), "(I1)") n
       is = is + 1
       ! Read the channel
       select case(key(is:is))
       case('s')
          l=1
       case('p')
          l=2
       case('d')
          l=3
       case('f')
          l=4
       case default
          call f_err_throw("wrong channel specified",err_name='BIGDFT_INPUT_VARIABLES_ERROR')
          return
       end select
       nl(l) = nl(l) + 1
       if (is == 3) nlsc(l) = nlsc(l) + 1
       if (f_err_raise(nlsc(l) > 2,'Cannot admit more than two semicore orbitals per channel',&
            err_name='BIGDFT_INPUT_VARIABLES_ERROR')) return
       !read the different atomic occupation numbers
       !this section can be relaxed according to the format used
       !in the end there should be no errors anymore
!!$       if (dict_len(dict // key) /= nspin*noncoll*(2*l-1)) then
!!$          write(*,*) "Awaited: ", nspin*noncoll*(2*l-1), nspin, noncoll, l
!!$          write(*,*) "provided", dict_len(dict // key)
!!$          stop 'Not enough aocc'
!!$       end if
       !determine how to fill the allocc array according to the value
       !dict_tmp=>dict // key
       !call yaml_map('Dict of shell'//trim(yaml_toa(l)),dict_tmp)
       ln=dict_len(dict_tmp)
       if (modulo(ln,(2*l-1))==0 .and. ln /=0) then
          !call yaml_map('here, shell',l)
          !all the values are given explicitly, in agreement with the spin
          if (ln==nspin*noncoll*(2*l-1)) then
             allocc(1:nspin*noncoll*(2*l-1), n, l) = dict_tmp
          else if (nspin*noncoll == 2) then
             !the spin is not in agreement (too low: split the result)
             if (nspin==2) then
                !first up and then down
                do m = 1,2*l-1
                   tt=dict_tmp// (m - 1)
                   allocc(m, n, l) = 0.5_gp*tt
                   allocc(m+2*l-1,n,l) = 0.5_gp*tt
                end do
             else
                !majority and minority
                do m = 1,2*l-1
                   tt=dict_tmp // (m - 1)
                   allocc(2*(m-1)+1, n, l) = 0.5_gp*tt
                   allocc(2*(m-1)+2 ,n,l) = 0.5_gp*tt
                end do
             end if
          else 
             !third case, too many values given: results of up and down have to be summed
             do m = 1,2*l-1
                allocc(m, n, l)=dict_tmp//(m - 1)
                tt=dict_tmp// (m - 1+2*l-1)
                allocc(m, n, l)=allocc(m, n, l)+tt
             end do
          end if
       else if (dict_size(dict_tmp) == 2 ) then
          !call yaml_map('there, shell',l)
          !the dictionary should contain the up and down spins
          if (has_key(dict_tmp,'up')) then
             !call yaml_map('here up, shell',l)
             if (dict_len(dict_tmp//'up') == 2*l-1) then
                !up values have been entered explicitly
                if (noncoll==2) then
                   !spinorial case
                   do m = 1,2*l-1
                      allocc(2*(m-1)+1, n, l)=dict_tmp//'up'//(m-1)
                   end do
                else
                   !collinear spin case
                   !spin-averaged case
                   allocc(1:(2*l-1),n,l)=dict_tmp//'up'
                end if
             else if (dict_len(dict_tmp//'up') == 0) then
                !use spherical average for the values
                tt=dict_tmp//'up'
                tt=tt/real(2*l-1,gp)
                if (noncoll == 2) then
                   !spinorial
                   do m = 1,2*l-1
                      allocc(2*(m-1)+1, n, l)=tt
                   end do
                else
                   !collinear and spin averaged
                   allocc(1:(2*l-1),n,l)=tt
                end if
             else
                call f_err_throw('Only scalar and list of correct lenghts are allowed for '//&
                     'Atomic occupation number of up channel',err_name='BIGDFT_INPUT_VARIABLES_ERROR')
                return
             end if
          end if
          if (has_key(dict_tmp,'down')) then
             !call yaml_map('here down, shell',l)
             if (dict_len(dict_tmp//'down') == 2*l-1) then
                !down values have been entered explicitly
                if (noncoll==2) then
                   !spinorial case
                   do m = 1,2*l-1
                      allocc(2*(m-1)+2, n, l)=dict_tmp//'down'//(m-1)
                   end do
                else if (nspin==2) then
                   !collinear spin case
                   allocc(2*l:2*(2*l-1),n,l)=dict_tmp//'down'
                else
                   !spin-averaged case
                   do m = 1,2*l-1
                      tt=dict_tmp//'down'//(m-1)
                      allocc(m,n,l)=allocc(m,n,l)+tt
                   end do
                end if
             else if(dict_len(dict_tmp//'down') == 0) then
                !use spherical average for the values
                tt=dict_tmp//'down'
                tt=tt/real(2*l-1,gp)
                if (noncoll == 2) then
                   !spinorial
                   do m = 1,2*l-1
                      allocc(2*(m-1)+2, n, l)=tt
                   end do
                else if (nspin == 2) then
                   !collinear spin
                   allocc(2*l:2*(2*l-1),n,l)=tt
                else
                   !spin averaged
                   do m = 1,2*l-1
                      allocc(m,n,l)=allocc(m,n,l)+tt
                   end do
                end if
             else
                call f_err_throw('Only scalar and list of correct lenghts are allowed for '//&
                     'Atomic occupation number of down channel',err_name='BIGDFT_INPUT_VARIABLES_ERROR')
                return
             end if
          end if
       else if (ln == 0) then
          !call yaml_map('here AAA, shell',l)
          !scalar case, the values are assumed to be spherically symmetric in all spins
          tt=dict//key
          !call yaml_map('value found',tt)
          tt=tt/real(nspin*noncoll*(2*l-1),gp)
          allocc(1:nspin*noncoll*(2*l-1),n,l)=tt
       else
          call f_err_throw('Only scalar and list of correct lenghts are allowed for '//&
               'Atomic occupation number',err_name='BIGDFT_INPUT_VARIABLES_ERROR')
       end if
       
!!$       do m = 1, nspin*noncoll*(2*l-1), 1
!!$          allocc(m, n, l) = dict // key // (m - 1)
!!$       end do
       dict_tmp=>dict_next(dict_tmp)
    end do
    !deallocate(keys)
    !call f_free_str(max_field_length,keys)
!!$    do l=1,lmax_ao+1
!!$       call yaml_map('nl',nl(l))
!!$       do inl=1,nmax_ao
!!$
!!$          if (any(allocc(:,inl,l) /=  UNINITIALIZED(1._gp))) then
!!$             call yaml_map('Shell'//trim(yaml_toa(inl))//'-'//&
!!$                  trim(yaml_toa(l)),allocc(1:nspin*noncoll*(2*l-1),inl,l))
!!$          end if
!!$
!!$       end do
!!$    end do

    !put the values in the aocc array
    aocc(:)=0.0_gp
    iocc=0
    do l=1,lmax_ao+1
       iocc=iocc+1
       aocc(iocc)=real(nl(l),gp)
       !print *,'setl',l,aocc(iocc),iocc
       do inl=1,nmax_ao !this is an information which will disappear
          if (allocc(1, inl, l) == UNINITIALIZED(1._gp)) cycle
          !otherwise check if the shell is meaningful
          sh_chg=0.0_gp
          do ispin=1,nspin
             do m=1,2*l-1
                do icoll=1,noncoll !non-trivial only for nspinor=4
                   iocc=iocc+1
                   aocc(iocc)=allocc(icoll+(m-1)*noncoll+(ispin-1)*(2*l-1)*noncoll,inl,l)
                   sh_chg=sh_chg+aocc(iocc)
                end do
             end do
          end do
          if (f_err_raise(sh_chg>real(2*(2*l-1),gp)+1.e-8_gp,'The charge of the shell'//&
               trim(yaml_toa(l))//' is '//trim(yaml_toa(sh_chg))//&
               ' which is higher than the limit '//&
               trim(yaml_toa(nspin*noncoll*(2*l-1))),&
               err_name='BIGDFT_INPUT_VARIABLES_ERROR')) return
       end do
    end do

    !then calculate the nsccode
    nsccode=0
    do lsc=1,lmax_ao+1
       nsccode=nsccode+nlsc(lsc) * (4**(lsc-1))
    end do

  end subroutine aocc_from_dict


  !> Print the electronic configuration, with the semicore orbitals
  subroutine print_eleconf(nspin_in,aocc,nsccode) !noccmax,nelecmax,lmax,
    use module_base
    use yaml_output
    implicit none
    integer, intent(in) :: nspin_in,nsccode!,nelecmax,noccmax,lmax
    real(gp), dimension(nelecmax_ao), intent(in) :: aocc
    !local variables
    character(len=10) :: tmp
    character(len=500) :: string
    integer :: i,m,iocc,icoll,inl,nspin,nspinor,noncoll,l,ispin,is,nl,niasc,lsc,nlsc,ntmp,iss
    logical, dimension(4,2) :: scorb

    !control the spin
    select case(nspin_in)
    case(1)
       nspin=1
       nspinor=1
       noncoll=1
    case(2)
       nspin=2
       nspinor=1
       noncoll=1
    case(4)
       nspin=1
       nspinor=4
       noncoll=2
    end select


    scorb=.false.
    if (nsccode/=0) then !the atom has some semicore orbitals
       niasc=nsccode
       do lsc=4,1,-1
          nlsc=niasc/4**(lsc-1)
          do i=1,nlsc
             scorb(lsc,i)=.true.
          end do
          niasc=niasc-nlsc*4**(lsc-1)
       end do
    end if

    call yaml_open_map('Electronic configuration',flow=.true.)

    !initalise string
    string=repeat(' ',len(string))

    is=1
    do i=1,noccmax_ao
       iocc=0
       do l=1,lmax_ao+1
          iocc=iocc+1
          nl=nint(aocc(iocc))
          do inl=1,nl
             !write to the string the angular momentum
             if (inl == i) then
                iss=is
                if (scorb(l,inl)) then
                   string(is:is)='('
                   is=is+1
                end if
                select case(l)
                case(1)
                   string(is:is)='s'
                case(2)
                   string(is:is)='p'
                case(3)
                   string(is:is)='d'
                case(4)
                   string(is:is)='f'
                case default
                   stop 'l not admitted'
                end select
                is=is+1
                if (scorb(l,inl)) then
                   string(is:is)=')'
                   is=is+1
                end if
                call yaml_open_sequence(string(iss:is))
             end if
             do ispin=1,nspin
                do m=1,2*l-1
                   do icoll=1,noncoll !non-trivial only for nspinor=4
                      iocc=iocc+1
                      !write to the string the value of the occupation numbers
                      if (inl == i) then
                         call write_fraction_string(l,aocc(iocc),tmp,ntmp)
                         string(is:is+ntmp-1)=tmp(1:ntmp)
                         call yaml_sequence(tmp(1:ntmp))
                         is=is+ntmp
                      end if
                   end do
                end do
             end do
             if (inl == i) then
                string(is:is+2)=' , '
                is=is+3
                call yaml_close_sequence()
             end if
          end do
       end do
    end do

    !write(*,'(2x,a,1x,a,1x,a)',advance='no')' Elec. Configuration:',trim(string),'...'

    call yaml_close_map()

  END SUBROUTINE print_eleconf

  !>calculate the total charge of a given set of occupation numbers in compressed form 
  pure function ao_ig_charge(nspin,occupIG) result(elec)
    integer, intent(in) :: nspin
    double precision, dimension(nelecmax_ao), intent(in) :: occupIG
    double precision :: elec
    !local variables
    integer :: iocc,l,nl,inl,ispin,nsp,noncoll,icoll,m

    nsp=nspin
    noncoll=1
    if (nspin==4) then
       nsp=1
       noncoll=2
    end if
    !check the total number of electrons
    elec=0.0_gp
    iocc=0
    do l=1,lmax_ao+1
       iocc=iocc+1
       nl=nint(occupIG(iocc))!atoms%aocc(iocc,iat))
       do inl=1,nl
          do ispin=1,nsp
             do m=1,2*l-1
                do icoll=1,noncoll !non-trivial only for nspinor=4
                   iocc=iocc+1
                   elec=elec+occupIG(iocc)!,iat)
                end do
             end do
          end do
       end do
    end do

  end function ao_ig_charge

  !> Correct the electronic configuration for a given atomic charge
  subroutine correct_semicore(nmax,lmax,ichg,neleconf,eleconf,nsccode)
    use module_base
    implicit none
    integer, intent(in) :: nmax,lmax,ichg
    real(kind=8) , dimension(nmax,0:lmax), intent(in) :: neleconf
    !integer, dimension(nmax,0:lmax), intent(in) :: neleconf
    real(gp), dimension(nmax,0:lmax), intent(out) :: eleconf
    integer, intent(inout) :: nsccode
    !local variables
    logical :: inocc
    integer :: i,l,nchgres,ichgp,nlsc
    real(gp) :: atchg

    !convert the array in real numbers
    do i=1,nmax
       do l=0,lmax
          eleconf(i,l)=real(neleconf(i,l),gp)
       end do
    end do

    nchgres=ichg !residual charge
    if (ichg >0) then
       !place the charge on the atom starting from the non closed shells
       do i=nmax,1,-1
          do l=lmax,0,-1
             if (neleconf(i,l) /= 2*(2*l+1) .and. neleconf(i,l) /= 0) then
                ichgp=min(nint(neleconf(i,l)),nchgres)
                nchgres=nchgres-ichgp
                eleconf(i,l)=eleconf(i,l)-real(ichgp,gp)
             end if
          end do
       end do
       if (nchgres /= 0) then
          !localise the highest occupied shell and charge it
          do i=nmax,1,-1
             do l=lmax,0,-1
                if (nint(eleconf(i,l)) == 2*(2*l+1)) then
                   ichgp=min(nint(eleconf(i,l)),nchgres)
                   nchgres=nchgres-ichgp
                   eleconf(i,l)=eleconf(i,l)-real(ichgp,gp)
                end if
             end do
          end do
          !!        !charge only unoccupied shells 
          !!        print *,'Atom ',symbol,': cannot charge occupied shells for the moment'
          !!        stop
       end if
    else if (ichg < 0) then
       !place the charge on the atom starting from the non closed shells
       do i=nmax,1,-1
          do l=lmax,0,-1
             if (neleconf(i,l) /= 0) then
                ichgp=min(2*(2*l+1)-nint(neleconf(i,l)),-nchgres)
                nchgres=nchgres+ichgp
                eleconf(i,l)=eleconf(i,l)+real(ichgp,gp)
             end if
          end do
       end do
       if (nchgres /= 0) then
          !localise the highest unoccupied shell and charge it
          inocc=.false.
          do i=1,nmax
             do l=0,lmax
                !once found the first occupied shell search for the first unoccpied
                if (inocc .and. nint(eleconf(i,l)) == 0) then
                   ichgp=min(2*(2*l+1),-nchgres)
                   nchgres=nchgres+ichgp
                   eleconf(i,l)=eleconf(i,l)+real(ichgp,gp)
                end if
                inocc=eleconf(i,l) /= 0.0_gp
             end do
          end do
          !!        !charge only occupied shells 
          !!        print *,'Atom ',symbol,': cannot charge unoccupied shells for the moment'
          !!        stop
       end if

    end if

    atchg=0.0_gp
    if (ichg /= 0) then
       !correct the semicore informations for a charged atom
       nsccode=0
       do l=0,lmax
          nlsc=0
          do i=1,nmax
             atchg=atchg+eleconf(i,l)
             if (eleconf(i,l) == real(2*(2*l+1),gp)) then
                nlsc=nlsc+1
                !if (nlsc <= 2) nsccode=nsccode+4**l
             end if
          end do
       end do
       if (atchg==0.0_gp) then
          write(*,*)'ERROR: an Atom must have input charge'
          stop
       end if
    end if



!!!  !if the atom has only closed shells we can treat it as semicore atom (commented)
!!!  isccode=nsccode
!!!  do l=lmax,0,-1
!!!     !control whether it is already semicore
!!!     itmp=isccode/((lmax+1)**l)
!!!     isccode=isccode-itmp*((lmax+1)**l)
!!!     !print *,'symbol',symbol,l,itmp,isccode,itmp*(lmax**l)
!!!     do i=1,nmax
!!!        if (neleconf(i,l) == 2*(2*l+1)) then
!!!           if (itmp==1) then
!!!              itmp=0
!!!              cycle
!!!           else
!!!               nsccode=nsccode+4**l !the maximum occupied is noccmax=2
!!!           end if
!!!        end if
!!!     end do
!!!  end do
  END SUBROUTINE correct_semicore

  !>  Calculate the occupation number for any of the orbitals
  subroutine at_occnums(ipolres,nspin,nspinor,nmax,lmax,nelecmax,eleconf,occupIG)
    use module_base
    implicit none
    integer, intent(in) :: nspinor,nspin,nmax,lmax,nelecmax
    real(gp), dimension(nmax,lmax), intent(in) :: eleconf
    integer, intent(inout) :: ipolres
    real(gp), dimension(nelecmax), intent(out) :: occupIG
    !local variables
    logical :: polarised
    integer :: iocc,ipolorb,norbpol_nc,i,l,m,noncoll,icoll,ispin, ipolsign
    real(gp) :: shelloccup,occshell,occres,rnl

    !in the non-collinear case the number of orbitals doubles
    if (nspinor == 4) then
       noncoll=2
    else
       noncoll=1
    end if

    call razero(nelecmax,occupIG)
    !call to_zero(nelecmax, occupIG(1))

    !here we should define the array of the occupation numbers
    !such array can then be redefined on the parent routines and then used as input
    iocc=0
    polarised=.false.
    !the sign is always the same
    if (ipolres >= 0) then
       ipolsign=1
    else
       ipolsign=-1
    end if
    do l=1,lmax
       iocc=iocc+1
       rnl=0.0_gp !real since it goes in occupIG
       do i=1,nmax
          if (eleconf(i,l) > 0.0_gp) then
             rnl=rnl+1.0_gp
          endif
       end do
       occupIG(iocc)=rnl
       !print *,'rnl,l',l,rnl,eleconf(:,l)
       do i=1,nmax
          if (eleconf(i,l) > 0.0_gp) then  
             shelloccup=eleconf(i,l)
             !decide the polarisation of the orbital by changing the population
             if (nint(shelloccup) /=  2*(2*l-1) ) then
                !this is a polarisable orbital
                polarised=.true.
                !assuming that the control of the allowed polarisation is already done

                ipolorb=ipolsign*min(abs(ipolres),  ((2*l-1) - abs( (2*l-1)- int(shelloccup) ) )  )
                ipolres=ipolres-ipolorb
             else
                !check for odd values of the occupation number
                if (mod(nint(shelloccup),2) /= 0) then
                   write(*,'(1x,a)')&
                        &   'The occupation number in the case of closed shells must be even'
                   stop
                end if
             end if

             if( polarised .AND. nspinor==4 .and. ipolorb /=0) then
                stop " in non-collinear case at_moments must be used for polarising, not natpol input"  
             endif

             do ispin=1,nspin
                occshell=shelloccup                 
                if (nspin==2 .or. nspinor==4) then
                   if (polarised) then
                      occshell=0.5_gp*(occshell+real(1-2*(ispin-1),gp)*ipolorb)
                   else
                      occshell=0.5_gp*occshell
                   end if
                end if

                !residue for the occupation number, to be used for
                !non-collinear case 
                occres=occshell
                !number of orbitals which will be polarised in this shell
                norbpol_nc=2*l-1
                do m=1,2*l-1
                   !each orbital has two electrons in the case of the 
                   !non-collinear case
                   do icoll=1,noncoll !non-trivial only for nspinor=4
                      iocc=iocc+1
                      !the occupation number rule changes for non-collinear
                      if (nspinor == 4) then
                         !for each orbital of the shell, use the Hund rule
                         !for determining the occupation
                         !if the occupation is one the orbital is not polarised
                         !otherwise it can be polarised via the polarisation
                         !indicated by atmoments
                         if (ceiling(occres) >= real(2*l-1,gp)) then
                            occupIG(iocc)=1.0_gp
                            if (icoll==2) then
                               occres=occres-1.0_gp
                               norbpol_nc=norbpol_nc-1
                            end if
                         else
                            if (icoll ==1) then
                               occupIG(iocc)=2.0_gp*occres/real(norbpol_nc,gp)
                            else
                               occupIG(iocc)=0.0_gp
                            end if
                         end if
                      else
                         occupIG(iocc)=occshell/real(2*l-1,gp)
                      end if
                   end do
                end do
             end do
          end if
       end do
    end do
  END SUBROUTINE at_occnums


  include 'eleconf-inc.f90'

end module ao_inguess