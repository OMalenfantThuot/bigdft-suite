!> @file 
!! Handle operation about density (rho) and local potential
!! @author
!!   Copyright (C) 2011-2015 BigDFT group 
!!   This file is distributed under the terms of the
!!   GNU General Public License, see ~/COPYING file
!!   or http://www.gnu.org/copyleft/gpl.txt .
!!   For the list of contributors, see ~/AUTHORS 


!> Handle operation about density (rho) and local potential
module rhopotential

  implicit none

  private

  public :: updatePotential
  public :: full_local_potential
  public :: sumrho_for_TMBs
  public :: clean_rho
  public :: corrections_for_negative_charge
  public :: extract_potential

  contains

    !> Calculates the potential and energy
    subroutine updatePotential(nspin,denspot,energs)!ehart,eexcu,vexcu)
    
    use module_base
    use module_types
    use module_interfaces, only: XC_potential
    use Poisson_Solver, except_dp => dp, except_gp => gp
    use yaml_output
    implicit none
    
    ! Calling arguments
    integer, intent(in) :: nspin                     !< Spin number
    type(DFT_local_fields), intent(inout) :: denspot !< in=density, out=pot
    type(energy_terms), intent(inout) :: energs
    !real(kind=8), intent(out) :: ehart, eexcu, vexcu !> Energies (Hartree, XC and XC potential energy)
    
    ! Local variables
    character(len=*), parameter :: subname='updatePotential'
    logical :: nullifyVXC
    real(gp) :: ehart_ps
    real(dp), dimension(6) :: xcstr
    
    call f_routine(id='updatePotential')
    
    nullifyVXC=.false.
    
    if(nspin==4) then
       !this wrapper can be inserted inside the poisson solver 
       call PSolverNC(denspot%pkernel%geocode,'D',denspot%pkernel%mpi_env%iproc,denspot%pkernel%mpi_env%nproc,&
            denspot%dpbox%mesh%ndims(1),denspot%dpbox%mesh%ndims(2),&
            denspot%dpbox%mesh%ndims(3),&
            denspot%dpbox%n3d,denspot%xc,&
            denspot%dpbox%mesh%hgrids,&
            denspot%rhov,denspot%pkernel%kernel,denspot%V_ext,energs%eh,energs%exc,energs%evxc,0.d0,.true.,4)
    
    else
       if (.not. associated(denspot%V_XC)) then   
          !Allocate XC potential
          if (denspot%dpbox%n3p >0) then
             denspot%V_XC = f_malloc_ptr((/ denspot%dpbox%mesh%ndims(1),&
                  denspot%dpbox%mesh%ndims(2),&
                  denspot%dpbox%n3p , nspin /),&
                                id='denspot%V_XC')
          else
             denspot%V_XC = f_malloc_ptr((/ 1 , 1 , 1 , 1 /),id='denspot%V_XC')
          end if
          nullifyVXC=.true.
       end if
    
       call XC_potential(denspot%pkernel%geocode,'D',denspot%pkernel%mpi_env%iproc,denspot%pkernel%mpi_env%nproc,&
            denspot%pkernel%mpi_env%mpi_comm,&
            denspot%dpbox%mesh%ndims(1),denspot%dpbox%mesh%ndims(2),denspot%dpbox%mesh%ndims(3),denspot%xc,&
            denspot%dpbox%mesh%hgrids,&
            denspot%rhov,energs%exc,energs%evxc,nspin,denspot%rho_C,denspot%rhohat,denspot%V_XC,xcstr)
    
       call H_potential('D',denspot%pkernel,denspot%rhov,denspot%V_ext,ehart_ps,0.0_dp,.true.,&
            quiet=denspot%PSquiet,rho_ion=denspot%rho_ion) !optional argument

       if (denspot%pkernel%method /= 'VAC') then
          energs%eelec=ehart_ps
          energs%eh=0.0_gp
       else
          energs%eelec=0.0_gp
          energs%eh=ehart_ps
       end if
       
       !sum the two potentials in rhopot array
       !fill the other part, for spin, polarised
       if (nspin == 2) then
          !denspot%dpbox%ndims(1)*denspot%dpbox%ndims(2)*denspot%dpbox%n3p
          call vcopy(denspot%dpbox%ndimpot,denspot%rhov(1),1,&
               denspot%rhov(1+denspot%dpbox%mesh%ndims(1)*denspot%dpbox%mesh%ndims(2)*denspot%dpbox%n3p),1)
       end if
       !spin up and down together with the XC part
       !denspot%dpbox%ndims(1)*denspot%dpbox%ndims(2)*denspot%dpbox%n3p
       call axpy(denspot%dpbox%ndimpot*nspin,1.0_dp,denspot%V_XC(1,1,1,1),1,&
            denspot%rhov(1),1)
       
       if (nullifyVXC) call f_free_ptr(denspot%V_XC)

    end if
    
    call f_release_routine()
    
    END SUBROUTINE updatePotential


    !> Build the potential in the whole box
    !! Control also the generation of an orbital
    subroutine full_local_potential(iproc,nproc,orbs,Lzd,iflag,dpbox,xc,potential,pot,comgp)
      !ndimpot,ndimgrid,nspin,&
      !   ndimrhopot,i3rho_add,orbs,&
      !   Lzd,iflag,ngatherarr,potential,pot,comgp)
       use module_base
       use module_types
       use module_xc
       use communications_base, only: p2pComms
       use communications, only: synchronize_onesided_communication
       use locreg_operations, only: global_to_local
       use module_dpbox, only: denspot_distribution
       implicit none
       !Arguments
       integer, intent(in) :: iproc,nproc,iflag!,nspin,ndimpot,ndimgrid
       !integer, intent(in) :: ndimrhopot,i3rho_add
       type(orbitals_data),intent(in) :: orbs
       type(local_zone_descriptors),intent(in) :: Lzd
       type(denspot_distribution), intent(in) :: dpbox
       type(xc_info), intent(in) :: xc
       !integer, dimension(0:nproc-1,2), intent(in) :: ngatherarr 
       real(wp), dimension(max(dpbox%ndimrhopot,orbs%nspin)), intent(in), target :: potential !< Distributed potential. Might contain the density for the SIC treatments
       real(wp), dimension(:), pointer :: pot
       !type(p2pCommsGatherPot),intent(inout), optional:: comgp
       type(p2pComms),intent(inout), optional:: comgp
       !local variables
       character(len=*), parameter :: subname='full_local_potential'
       logical :: odp,newvalue !orbital dependent potential
       integer :: npot,ispot,ispotential,ispin,ierr,ii,ilr,iorb,iorb2,nilr,ni1,ni2,iiorb,size_lpot_max
       !integer :: i
       integer:: istl, ist, size_Lpot, i3s, i3e, i2s, i2e, i1s, i1e, iispin, ishift
       integer,dimension(:),allocatable:: ilrtable
       real(wp), dimension(:), pointer :: pot1
       integer :: i1shift, i2shift, i3shift
       !integer :: i
       
       call timing(iproc,'Pot_commun    ','ON')
       call f_routine(id='full_local_potential')
    
       odp = (xc_exctXfac(xc) /= 0.0_gp .or. (dpbox%i3rho_add /= 0 .and. orbs%norbp > 0))
    
       !!write(*,'(a,100i4)') 'in full_local_potential: orbs%inwhichlocreg',orbs%inwhichlocreg
    
       !############################################################################
       ! Build the potential on the whole simulation box
       ! NOTE: in the linear scaling case this should be done for a given localisation
       !       region this routine should then be modified or integrated in HamiltonianApplication
       ! WARNING : orbs%nspin and nspin are not the same !! Check if orbs%nspin should be replaced everywhere
       !#############################################################################
       if (iflag<2) then
    
          !determine the dimension of the potential array
          if (odp) then
             if (xc_exctXfac(xc) /= 0.0_gp) then
                npot=dpbox%ndimgrid*orbs%nspin+&
                     &   max(max(dpbox%ndimgrid*orbs%norbp,dpbox%ngatherarr(0,1)*orbs%norb),1) !part which refers to exact exchange
             else if (dpbox%i3rho_add /= 0 .and. orbs%norbp > 0) then
                npot=dpbox%ndimgrid*orbs%nspin+&
                     &   dpbox%ndimgrid*max(orbs%norbp,orbs%nspin) !part which refers to SIC correction
             end if
          else
             npot=dpbox%ndimgrid*orbs%nspin
          end if
    !      write(*,*) 'dpbox%ndimgrid, orbs%norbp, npot, odp', dpbox%ndimgrid, orbs%norbp, npot, odp
    !      write(*,*)'nspin',orbs%nspin,dpbox%i3rho_add,dpbox%ndimpot,dpbox%ndimrhopot,sum(potential)
    !      write(*,*)'iproc',iproc,'ngatherarr',dpbox%ngatherarr(:,1),dpbox%ngatherarr(:,2)
    
          !build the potential on the whole simulation box
          !in the linear scaling case this should be done for a given localisation region
          !this routine should then be modified or integrated in HamiltonianApplication
          if (dpbox%mpi_env%nproc > 1) then
    
             pot1 = f_malloc_ptr(npot,id='pot1')
             ispot=1
             ispotential=1
             do ispin=1,orbs%nspin
                call MPI_ALLGATHERV(potential(ispotential),dpbox%ndimpot,&
                     &   mpidtypw,pot1(ispot),dpbox%ngatherarr(0,1),&
                     dpbox%ngatherarr(0,2),mpidtypw,dpbox%mpi_env%mpi_comm,ierr)
                ispot=ispot+dpbox%ndimgrid
                ispotential=ispotential+max(1,dpbox%ndimpot)
             end do
             !continue to copy the density after the potential if required
             if (dpbox%i3rho_add >0 .and. orbs%norbp > 0) then
                ispot=ispot+dpbox%i3rho_add-1
                do ispin=1,orbs%nspin
                   call MPI_ALLGATHERV(potential(ispotential),dpbox%ndimpot,&
                        &   mpidtypw,pot1(ispot),dpbox%ngatherarr(0,1),&
                        dpbox%ngatherarr(0,2),mpidtypw,dpbox%mpi_env%mpi_comm,ierr)
                   ispot=ispot+dpbox%ndimgrid
                   ispotential=ispotential+max(1,dpbox%ndimpot)
                end do
             end if
          else
             if (odp) then
                pot1 = f_malloc_ptr(npot,id='pot1')
                call vcopy(dpbox%ndimgrid*orbs%nspin,potential(1),1,pot1(1),1)
                if (dpbox%i3rho_add >0 .and. orbs%norbp > 0) then
                   ispot=dpbox%ndimgrid*orbs%nspin+1
                   call vcopy(dpbox%ndimgrid*orbs%nspin,potential(ispot+dpbox%i3rho_add),1,pot1(ispot),1)
                end if
             else
                pot1 => potential
             end if
          end if
       else
           !!if(.not.comgp%communication_complete) call gatherPotential(iproc, nproc, comgp)
           !!if(.not.comgp%communication_complete) call wait_p2p_communication(iproc, nproc, comgp)
           !!call wait_p2p_communication(iproc, nproc, comgp)
           call synchronize_onesided_communication(iproc, nproc, comgp)
       end if
    
       call timing(iproc,'Pot_commun    ','OF') 
    
       !########################################################################
       ! Determine the dimension of the potential array and orbs%ispot
       !########################################################################
    !!$   if(associated(orbs%ispot)) then
    !!$      nullify(orbs%ispot)
    !!$      !     i_all=-product(shape(orbs%ispot))*kind(orbs%ispot)
    !!$      !     deallocate(orbs%ispot,stat=i_stat)
    !!$      !     call memocc(i_stat,i_all,'orbs%ispot',subname)
    !!$   end if
    !!$   allocate(orbs%ispot(orbs%norbp),stat=i_stat)
    !!$   call memocc(i_stat,orbs%ispot,'orbs%ispot',subname)
    
       call timing(iproc,'Pot_after_comm','ON')
       
       if(Lzd%nlr > 1 .or. iflag==2) then !nlr>1 not enough to activate linear scaling (linear scaling with only one locreg is possible...)
          ilrtable = f_malloc(orbs%norbp,id='ilrtable')
          !call f_zero(orbs%norbp*2,ilrtable(1,1))
          ilrtable=0
          ii=0
          do ispin=1,dpbox%nrhodim
              do iorb=1,orbs%norbp
                 newvalue=.true.
                 !localization region to which the orbital belongs
                 ilr = orbs%inwhichlocreg(iorb+orbs%isorb)
                 !spin state of the orbital
                 if (orbs%spinsgn(orbs%isorb+iorb) > 0.0_gp) then
                    iispin = 1       
                 else
                    iispin=2
                 end if
                 ! First the up TMBs, then the down TMBs
                 if (iispin==ispin) then
                     !check if the orbitals already visited have the same conditions
                     !SM: if each TMB has its own locreg, this loop is probably not needed.
                     loop_iorb2: do iorb2=1,orbs%norbp
                        if(ilrtable(iorb2) == ilr) then
                           newvalue=.false.
                           exit loop_iorb2
                        end if
                     end do loop_iorb2
                     if (newvalue) then
                        ii = ii + 1
                        ilrtable(ii)=ilr
                        !write(*,*) 'ii, iorb, ilr, ilrtable(ii)', ii, iorb, ilr, ilrtable(ii)
                     end if
                 end if
              end do
          end do
          !number of inequivalent potential regions
          nilr = ii
       else 
          ilrtable = f_malloc(1,id='ilrtable')
          nilr = 1
          ilrtable=1
       end if
    
       !!write(*,'(a,100i4)') 'in full_local_potential: ilrtable', ilrtable
    
    
    !!$   !calculate the dimension of the potential in the gathered form 
    !!$   !this part has been deplaced in check_linear_and_create_Lzd routine 
    !!$   lzd%ndimpotisf=0
    !!$   do iilr=1,nilr
    !!$      ilr=ilrtable(iilr,1)
    !!$      do iorb=1,orbs%norbp
    !!$         !put the starting point
    !!$         if (orbs%inWhichLocreg(iorb+orbs%isorb) == ilr) then
    !!$            !assignment of ispot array to the value of the starting address of inequivalent
    !!$            orbs%ispot(iorb)=lzd%ndimpotisf + 1
    !!$            if(orbs%spinsgn(orbs%isorb+iorb) <= 0.0_gp) then
    !!$               orbs%ispot(iorb)=lzd%ndimpotisf + &
    !!$                    1 + lzd%llr(ilr)%d%n1i*lzd%llr(ilr)%d%n2i*lzd%llr(ilr)%d%n3i
    !!$            end if
    !!$         end if
    !!$      end do
    !!$      lzd%ndimpotisf = lzd%ndimpotisf + &
    !!$           lzd%llr(ilr)%d%n1i*lzd%llr(ilr)%d%n2i*lzd%llr(ilr)%d%n3i*nspin
    !!$   end do
    !!$   !part which refers to exact exchange
    !!$   if (exctX) then
    !!$      lzd%ndimpotisf = lzd%ndimpotisf + &
    !!$           max(max(ndimgrid*orbs%norbp,ngatherarr(0,1)*orbs%norb),1) 
    !!$   end if
    
       !#################################################################################################################################################
       ! Depending on the scheme, cut out the local pieces of the potential
       !#################################################################################################################################################
       if(iflag==0) then
          !       allocate(pot(lzd%ndimpotisf),stat=i_stat)
          !       call vcopy(lzd%ndimpotisf,pot,1,pot,1) 
          ! This is due to the dynamic memory managment. The original version was: pot=>pot1
          !pot = f_malloc_ptr(npot,id='pot')
          !pot=pot1
          !call f_free_ptr(pot1)
          pot=>pot1
       else if(iflag>0 .and. iflag<2) then
          pot = f_malloc_ptr(lzd%ndimpotisf,id='pot')
          ! Cut potential
          istl=1
          do iorb=1,nilr
             ilr = ilrtable(iorb)
             ! Cut the potential into locreg pieces
             call global_to_local(Lzd%Glr,Lzd%Llr(ilr),dpbox%nrhodim,npot,lzd%ndimpotisf,pot1,pot(istl:))
             istl = istl + Lzd%Llr(ilr)%d%n1i*Lzd%Llr(ilr)%d%n2i*Lzd%Llr(ilr)%d%n3i*dpbox%nrhodim
          end do
       else
          if(.not.associated(pot)) then !otherwise this has been done already... Should be improved.
             !pot = f_malloc_ptr(lzd%ndimpotisf,id='pot')
    

             size_lpot_max = 0
    
             !!ist=1
             do iorb=1,nilr
                ilr = ilrtable(iorb)
                iiorb=orbs%isorb+iorb
                if (orbs%inwhichlocreg(iiorb)/=ilr) call f_err_throw('full_local_potential: orbs%inwhichlocreg(iiorb)/=ilr')

                !determine the dimension of the potential array (copied from full_local_potential)
                if (xc_exctXfac(xc) /= 0.0_gp) then
                   stop 'exctX not yet implemented!'
                else
                   size_Lpot = Lzd%Llr(ilr)%d%n1i*Lzd%Llr(ilr)%d%n2i*Lzd%Llr(ilr)%d%n3i
                end if

                size_lpot_max = max(size_lpot_max,size_lpot)

                
                !!if (orbs%spinsgn(iiorb)>0.d0) then
                !!    ispin=1
                !!else
                !!    ispin=2
                !!end if

                !!call extract_potential(ispin, ilr, size_lpot, lzd, pot(ist:), comgp)
    
                !!ist = ist + size_lpot
             end do
             pot = f_malloc_ptr(size_lpot_max,id='pot')
          end if
       end if
    
       call f_free(ilrtable)
    
       ! Deallocate pot.
       if (iflag<2 .and. iflag>0) then
          if (dpbox%mpi_env%nproc > 1) then
             call f_free_ptr(pot1)
          else
             if (xc_exctXfac(xc) /= 0.0_gp) then
                call f_free_ptr(pot1)
             else
                nullify(pot1)
             end if
          end if
       end if
    
       call f_release_routine()
       call timing(iproc,'Pot_after_comm','OF')
    
       !!call mpi_finalize(ierr)
       !!stop
    
    
    END SUBROUTINE full_local_potential


    subroutine sumrho_for_TMBs(iproc, nproc, hx, hy, hz, collcom_sr, denskern, denskern_, ndimrho, rho, rho_negative, &
            print_results)
      use module_base
      use module_types
      use yaml_output
      use sparsematrix_base, only: sparse_matrix
      use bigdft_matrices, only: get_modulo_array
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, ndimrho
      real(kind=8),intent(in) :: hx, hy, hz
      type(comms_linear),intent(inout) :: collcom_sr
      type(sparse_matrix),intent(in) :: denskern
      type(matrices),intent(in) :: denskern_
      real(kind=8),dimension(ndimrho),intent(out) :: rho
      logical,intent(out) :: rho_negative
      logical,intent(in),optional :: print_results
    
      ! Local variables
      integer :: ipt, ii, i0, iiorb, jjorb, iorb, jorb, i, j, ierr, ind, ispin, ishift, ishift_mat, iorb_shift
      real(8) :: tt, total_charge, hxh, hyh, hzh, factor, tt1, tt2, rho_neg
      integer,dimension(:),allocatable :: isend_total
      integer,dimension(:),pointer :: moduloarray
      real(kind=8),dimension(:),allocatable :: rho_local
      character(len=*),parameter :: subname='sumrho_for_TMBs'
      logical :: print_local
      integer :: size_of_double, mpisource, istsource, istdest, nsize, jproc, ishift_dest, ishift_source
      !integer :: info
    
      call f_routine('sumrho_for_TMBs')

      call get_modulo_array(denskern, moduloarray)
    
      ! check whether all entries of the charge density are positive
      rho_negative=.false.
    
      if (present(print_results)) then
          if (print_results) then
              print_local=.true.
          else
              print_local=.false.
          end if
      else
          print_local=.true.
      end if
    
    
      rho_local = f_malloc(collcom_sr%nptsp_c*denskern%nspin,id='rho_local')
    
      ! Define some constant factors.
      hxh=.5d0*hx
      hyh=.5d0*hy
      hzh=.5d0*hz
      factor=1.d0/(hxh*hyh*hzh)
    
      call timing(iproc,'sumrho_TMB    ','ON')
      
      ! Initialize rho. (not necessary for the moment)
      !if (xc_isgga()) then
      !    call f_zero(collcom_sr%nptsp_c, rho_local)
      !else
       !   ! There is no mpi_allreduce, therefore directly initialize to
       !   ! 10^-20 and not 10^-20/nproc.
      !    rho_local=1.d-20
      !end if
    
    
      !!if (print_local .and. iproc==0) write(*,'(a)', advance='no') 'Calculating charge density... '
    
      total_charge=0.d0
      rho_neg=0.d0
    
    !ispin=1
      !SM: check if the modulo operations take a lot of time. If so, try to use an
      !auxiliary array with shifted bounds in order to access smat%matrixindex_in_compressed_fortransposed
      do ispin=1,denskern%nspin
          if (ispin==1) then
              ishift=0
          else
              ishift=collcom_sr%ndimind_c/2
          end if
          iorb_shift=(ispin-1)*denskern%nfvctr
          ishift_mat=(ispin-1)*denskern%nvctr
          !$omp parallel default(private) &
          !$omp shared(total_charge, collcom_sr, factor, denskern, denskern_, rho_local, moduloarray) &
          !$omp shared(rho_neg, ispin, ishift, ishift_mat, iorb_shift) 
          !$omp do schedule(static,200) reduction(+:total_charge, rho_neg)
          do ipt=1,collcom_sr%nptsp_c
              ii=collcom_sr%norb_per_gridpoint_c(ipt)
        
              i0=collcom_sr%isptsp_c(ipt)+ishift
              tt=1.e-20_dp
              do i=1,ii
                  iiorb=collcom_sr%indexrecvorbital_c(i0+i) - iorb_shift
                  iorb=moduloarray(iiorb)
                  tt1=collcom_sr%psit_c(i0+i)
                  ind=denskern%matrixindex_in_compressed_fortransposed(iorb,iorb)
                  ind=ind+ishift_mat-denskern%isvctrp_tg
                  tt=tt+denskern_%matrix_compr(ind)*tt1*tt1
                  tt2=2.0_dp*tt1
                  do j=i+1,ii
                      jjorb=collcom_sr%indexrecvorbital_c(i0+j) - iorb_shift
                      jorb=moduloarray(jjorb)
                      ind=denskern%matrixindex_in_compressed_fortransposed(jorb,iorb)
                      if (ind==0) cycle
                      ind=ind+ishift_mat-denskern%isvctrp_tg
                      tt=tt+denskern_%matrix_compr(ind)*tt2*collcom_sr%psit_c(i0+j)
                  end do
              end do
              tt=factor*tt
              total_charge=total_charge+tt
              rho_local(ipt+(ispin-1)*collcom_sr%nptsp_c)=tt
              if (tt<0.d0) rho_neg=rho_neg+1.d0
          end do
          !$omp end do
          !$omp end parallel
      end do
    
      call f_free_ptr(moduloarray)
    
      !if (print_local .and. iproc==0) write(*,'(a)') 'done.'
    
      call timing(iproc,'sumrho_TMB    ','OF')
    
    
      call communicate_density_for_TMBs()
    
    
      !!if (nproc > 1) then
      !!   call mpiallred(irho, 1, mpi_sum, bigdft_mpi%mpi_comm)
      !!end if
    
      if (rho_neg>0.d0) then
          rho_negative=.true.
      end if
    
      call f_free(rho_local)
    
      call f_release_routine()
    
      contains
    
        subroutine communicate_density_for_TMBs()
          implicit none
          real(kind=8),dimension(2) :: reducearr
    
          call f_routine(id='communicate_density')
          call timing(iproc,'sumrho_allred','ON')
        
          ! Communicate the density to meet the shape required by the Poisson solver.
          !!if (nproc>1) then
          !!    call mpi_alltoallv(rho_local, collcom_sr%nsendcounts_repartitionrho, collcom_sr%nsenddspls_repartitionrho, &
          !!                       mpi_double_precision, rho, collcom_sr%nrecvcounts_repartitionrho, &
          !!                       collcom_sr%nrecvdspls_repartitionrho, mpi_double_precision, bigdft_mpi%mpi_comm, ierr)
          !!else
          !!    call vcopy(ndimrho, rho_local(1), 1, rho(1), 1)
          !!end if
        
          !!!!do ierr=1,size(rho)
          !!!!    write(200+iproc,*) ierr, rho(ierr)
          !!!!end do
        
        
        
          if (nproc>1) then
              !!call mpi_type_size(mpi_double_precision, size_of_double, ierr)
              !!call mpi_info_create(info, ierr)
              !!call mpi_info_set(info, "no_locks", "true", ierr)
              !!call mpi_win_create(rho_local(1), int(collcom_sr%nptsp_c*denskern%nspin*size_of_double,kind=mpi_address_kind), &
              !!     size_of_double, info, bigdft_mpi%mpi_comm, collcom_sr%window, ierr)
              !!call mpi_info_free(info, ierr)
              !!call mpi_win_fence(mpi_mode_noprecede, collcom_sr%window, ierr)
              call mpi_type_size(mpi_double_precision, size_of_double, ierr)
              collcom_sr%window = mpiwindow(collcom_sr%nptsp_c*denskern%nspin, rho_local(1), bigdft_mpi%mpi_comm)
        
              ! This is a bit quick and dirty. Could be done in a better way, but
              ! would probably required to pass additional arguments to the subroutine
              isend_total = f_malloc0(0.to.nproc-1,id='isend_total')
              isend_total(iproc)=collcom_sr%nptsp_c
              call mpiallred(isend_total, mpi_sum, comm=bigdft_mpi%mpi_comm)
        
        
              do ispin=1,denskern%nspin
                  !ishift_dest=(ispin-1)*sum(collcom_sr%commarr_repartitionrho(4,:)) !spin shift for the receive buffer
                  ishift_dest=(ispin-1)*ndimrho/denskern%nspin
                  do jproc=1,collcom_sr%ncomms_repartitionrho
                      mpisource=collcom_sr%commarr_repartitionrho(1,jproc)
                      istsource=collcom_sr%commarr_repartitionrho(2,jproc)
                      istdest=collcom_sr%commarr_repartitionrho(3,jproc)
                      nsize=collcom_sr%commarr_repartitionrho(4,jproc)
                      ishift_source=(ispin-1)*isend_total(mpisource) !spin shift for the send buffer
                      if (nsize>0) then
                          !!write(*,'(6(a,i0))') 'process ',iproc, ' gets ',nsize,' elements at position ',istdest+ishift_dest, &
                          !!                     ' from position ',istsource+ishift_source,' on process ',mpisource, &
                          !!                     '; error code=',ierr
                          call mpi_get(rho(istdest+ishift_dest), nsize, mpi_double_precision, mpisource, &
                               int((istsource-1+ishift_source),kind=mpi_address_kind), &
                               nsize, mpi_double_precision, collcom_sr%window, ierr)
                      end if
                  end do
              end do
              !!call mpi_win_fence(0, collcom_sr%window, ierr)
              !!call mpi_win_free(collcom_sr%window, ierr)
              call mpi_fenceandfree(collcom_sr%window)
        
              call f_free(isend_total)
          else
              call vcopy(ndimrho, rho_local(1), 1, rho(1), 1)
          end if
        
          !do ierr=1,size(rho)
          !    write(300+iproc,*) ierr, rho(ierr)
          !end do
          !call mpi_finalize(ierr)
          !stop
        
          if (nproc > 1) then
              reducearr(1) = total_charge
              reducearr(2) = rho_neg
              call mpiallred(reducearr, mpi_sum, comm=bigdft_mpi%mpi_comm)
              total_charge = reducearr(1)
              rho_neg = reducearr(2)
             !call mpiallred(total_charge, 1, mpi_sum, bigdft_mpi%mpi_comm)
          end if
        
          !!if(print_local .and. iproc==0) write(*,'(3x,a,es20.12)') 'Calculation finished. TOTAL CHARGE = ', total_charge*hxh*hyh*hzh
          if (iproc==0 .and. print_local) then
              call yaml_map('Total charge',total_charge*hxh*hyh*hzh,fmt='(es20.12)')
          end if
          
          call timing(iproc,'sumrho_allred','OF')
          call f_release_routine()
    
        end subroutine communicate_density_for_TMBs


        !function get_transposed_index(jorb,iorb) result(ind)
        !    integer,intent(in) :: jorb, iorb
        !    integer :: ind
        !    integer :: jjorb,iiorb
        !    ! If iorb is smaller than the offset, add a periodic shift
        !    if (iorb<smat%offset_matrixindex_in_compressed_fortransposed) then
        !        iiorb = iorb + smat%nfvctr
        !    else
        !        iiorb = iorb
        !    end if
        !    if (jorb<smat%offset_matrixindex_in_compressed_fortransposed) then
        !        jjorb = jorb + smat%nfvctr
        !    else
        !        jjorb = jorb
        !    end if
        !    ind = smat%matrixindex_in_compressed_fortransposed(jjorb,iiorb)
        !end function get_transposed_index
    
      !!write(*,*) 'after deallocate'
      !!call mpi_finalize(ierr)
      !!stop
    
    
    end subroutine sumrho_for_TMBs


    subroutine corrections_for_negative_charge(iproc, nproc, at, denspot)
      use module_types
      use yaml_output
      use dynamic_memory
      implicit none
    
      ! Calling arguments
      integer, intent(in) :: iproc, nproc
      type(atoms_data), intent(in) :: at
      type(DFT_local_fields), intent(inout) :: denspot
    
      call f_routine(id='corrections_for_negative_charge')
    
      if (iproc==0) call yaml_warning('No increase of FOE cutoff')
      call clean_rho(iproc, nproc, denspot%dpbox%ndimrhopot, denspot%rhov)
    
      call f_release_routine()
    
    end subroutine corrections_for_negative_charge


    !> Set negative entries to zero
    subroutine clean_rho(iproc, nproc, npt, rho)
      use module_base
      use yaml_output
      implicit none
    
      ! Calling arguments
      integer, intent(in) :: iproc, nproc, npt
      real(kind=8),dimension(npt), intent(inout) :: rho
    
      ! Local variables
      integer :: ncorrection, ipt
      real(kind=8) :: charge_correction
    
      if (iproc==0) then
          call yaml_newline()
          call yaml_map('Need to correct charge density',.true.)
          call yaml_warning('set to 1.d-20 instead of 0.d0')
      end if
    
      ncorrection=0
      charge_correction=0.d0
      do ipt=1,npt
          if (rho(ipt)<0.d0) then
              if (rho(ipt)>=-1.d-5) then
                  ! negative, but small, so simply set to zero
                  charge_correction=charge_correction+rho(ipt)
                  !rho(ipt)=0.d0
                  rho(ipt)=1.d-20
                  ncorrection=ncorrection+1
              else
                  ! negative, but non-negligible, so issue a warning
                  ! only print first time this occurs
                  if (ncorrection==0) then
                      call yaml_warning('considerable negative rho, value: '//&
                        &trim(yaml_toa(rho(ipt),fmt='(es12.4)'))) 
                  end if
                  charge_correction=charge_correction+rho(ipt)
                  !rho(ipt)=0.d0
                  rho(ipt)=1.d-20
                  ncorrection=ncorrection+1
              end if
          end if
      end do
    
      if (nproc > 1) then
          call mpiallred(ncorrection, 1, mpi_sum, comm=bigdft_mpi%mpi_comm)
          call mpiallred(charge_correction, 1, mpi_sum, comm=bigdft_mpi%mpi_comm)
      end if
    
      if (iproc==0) then
          call yaml_newline()
          call yaml_map('number of corrected points',ncorrection)
          call yaml_newline()
          call yaml_map('total charge correction',abs(charge_correction),fmt='(es14.5)')
          call yaml_newline()
      end if
      
    end subroutine clean_rho


    subroutine extract_potential(ispin, ilr, size_lpot, lzd, pot, comgp)
      use module_base
      use module_types
      use locreg_operations, only: global_to_local_parallel
      implicit none

      ! Calling arguments
      integer,intent(in) :: ispin, ilr, size_lpot
      type(local_zone_descriptors),intent(in) :: lzd
      real(kind=8),dimension(size_lpot),intent(out) :: pot
      type(p2pComms),intent(in):: comgp

      ! Local variables
      integer :: ishift, i1s, i1e, i2s, i2e, i3s, i3e, ni1, ni2, ni3, i1shift, i2shift, i3shift
    
      ! spin shift of the potential in the receive buffer
      ishift=(ispin-1)*comgp%nrecvBuf
    
      ! Extract the part of the potential which is needed for the current localization region.
      i3s=modulo(lzd%Llr(ilr)%nsi3-1,lzd%glr%d%n3i)+1-comgp%ise(5)+2 ! starting index of localized  potential with respect to total potential in comgp%recvBuf
      i3e=i3s+lzd%Llr(ilr)%d%n3i-1 ! ending index of localized potential with respect to total potential in comgp%recvBuf
      i2s=modulo(lzd%Llr(ilr)%nsi2-1,lzd%glr%d%n2i)+1-comgp%ise(3)+2
      i2e=i2s+lzd%Llr(ilr)%d%n2i-1
      i1s=modulo(lzd%Llr(ilr)%nsi1-1,lzd%glr%d%n1i)+1-comgp%ise(1)+2
      i1e=i1s+lzd%Llr(ilr)%d%n1i-1
      !!!! Make sure that the length is not larger than the global box (only possible for non-free BC)
      if (comgp%ise(2)>=comgp%ise(1)) then
          ni1=comgp%ise(2)-comgp%ise(1)+1
      else
          ! This is the case with aperiodic wrap around
          ni1=comgp%ise(2)+lzd%glr%d%n1i-comgp%ise(1)+1
      end if
      if (comgp%ise(4)>=comgp%ise(3)) then
          ni2=comgp%ise(4)-comgp%ise(3)+1
      else
          ! This is the case with aperiodic wrap around
          ni2=comgp%ise(4)+lzd%glr%d%n2i-comgp%ise(3)+1
      end if
      if(i3e-i3s+1 /= Lzd%Llr(ilr)%d%n3i) then
         write(*,'(a,i0,3x,i0)') 'ERROR: i3e-i3s+1 /= Lzd%Llr(ilr)%d%n3i',i3e-i3s+1, Lzd%Llr(ilr)%d%n3i
         stop
      end if
    
      if (comgp%ise(6)<comgp%ise(5)) then
          i3shift=comgp%ise(6)
      else
          i3shift=0
      end if
      if (comgp%ise(4)<comgp%ise(3)) then
          i2shift=comgp%ise(4)
      else
          i2shift=0
      end if
      if (comgp%ise(2)<comgp%ise(1)) then
          i1shift=comgp%ise(2)
      else
          i1shift=0
      end if
      call global_to_local_parallel(lzd%Glr, lzd%Llr(ilr), comgp%nrecvBuf, size_Lpot,&
           comgp%recvBuf(ishift+1:), pot, i1s, i1e, i2s, i2e, i3s, i3e, ni1, ni2, &
           i1shift, i2shift, i3shift, comgp%ise)

     end subroutine extract_potential

end module rhopotential