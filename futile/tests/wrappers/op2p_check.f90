  !> @file
  !!  Test of the overlap point to point, modern version
  !! @author
  !!    Copyright (C) 2015-2016 BigDFT group
  !!    This file is distributed under the terms of the
  !!    GNU General Public License, see ~/COPYING file
  !!    or http://www.gnu.org/copyleft/gpl.txt .
  !!    For the list of contributors, see ~/AUTHORS
  program OP2P_check
    use futile
    use overlap_point_to_point
    use wrapper_MPI
    implicit none
    logical :: symmetric,nearest_neighbor,symfalse
    integer :: iproc,jproc,nproc,norbp,ngroup,igroup,ndim,norb,iobj,jobj,kobj,nij_loc,nij_glob,i,j,ndimp,isdim
    integer :: iorb_glb,jorb_glb,nsteps
    integer, dimension(:), allocatable :: nobj,nobj_p
    integer, dimension(:,:), allocatable :: nobj_par
    type(dictionary), pointer :: options
    type(OP2P_data) :: OP2P_outer,OP2P_inner
    type(OP2P_iterator) :: iter_outer,iter_inner
    type(f_progress_bar) :: bar
    integer, dimension(:,:), allocatable :: ncouples_local
    real(f_double), dimension(:,:), allocatable :: data,res,rho_i_data,v_i_data,k_ij,v_i_data_res
    real(f_double), dimension(:,:), allocatable :: v_i_dist
    real(f_double), dimension(:,:), allocatable :: treated_couples

    call f_lib_initialize()

    call mpiinit()
    iproc = mpirank()

    call f_malloc_set_status(iproc=iproc)

    !read command line
    call OP2P_check_command_line_options(options)

    if (iproc==0) then
      call yaml_new_document()
      call yaml_dict_dump(options)
    end if

    nproc=mpisize()
    ngroup=dict_len(options//'objects')
    if (iproc==0 .and. ngroup <= 0) call f_err_throw('Error, number of groups must be more than one')

    nobj=f_malloc(ngroup,id='nobj')
    nobj=options//'objects'
    ndim=options//'ndim'
    symmetric=options//'symmetric'
    nearest_neighbor=options//'nn-pattern'
    call dict_free(options)

    !construct the number of objects per processor
    norb=sum(nobj)
    norbp=norb/nproc

    nobj_p=f_malloc(0.to.nproc-1,id='nobj_p')
    nobj_p=norbp
    !the first processes have more orbitals
    jproc=norb-norbp*nproc-1
    call f_increment(nobj_p(:jproc))

    if (iproc==0 .and. sum(nobj_p) /= norb) &
         call f_err_throw('Error in orbital repartition; norb is'+norb+' and nobj_p is'+yaml_toa(nobj_p))

    !construct the OP2P scheme and test it
    nobj_par = f_malloc0((/ 0.to.nproc-1, 1.to.ngroup /),id='nobj_par')
    iobj=0
    igroup=1
    do jproc=0,nproc-1
       kobj=0
       do jobj=1,nobj_p(jproc)
          if (iobj == nobj(igroup)) then
             nobj_par(jproc,igroup)=kobj
             iobj=0
             kobj=0
             call f_increment(igroup)
          end if
          call f_increment(iobj)
          call f_increment(kobj)
       end do
       nobj_par(jproc,igroup)=kobj
    end do

    if (iproc==0 .and. any(sum(nobj_par,dim=1) /= nobj)) &
          call f_err_throw('Error in orbital repartition'+yaml_toa(mpirank())+';'+yaml_toa(sum(nobj_par,dim=1)))

    if (iproc==0) then
       call yaml_map('Orbital repartition per group',nobj)
       call yaml_map('Orbital repartition per mpi',nobj_p)
       call yaml_map('Groups per proc',nobj_par)
       call yaml_map('Starting simulation for the operator, symmetricity activated',symmetric)
    end if

    call f_free(nobj)

    call OP2P_unitary_test(mpiworld(),mpirank(),nproc,ngroup,ndim,nobj_par,symmetric,nearest_neighbor)

    !starting the test for four point coupling matrix approach
!!$
!!$    call calculate_ndimp_and_isdim(ndim,nproc,iproc,ndimp,isdim....,nobj_p)
!!$
!!$    call yaml_map('Ndimp',[ndimp,isdim,iproc])
!!$
    call mpibarrier()
    call yaml_flush_document()
!!$

    !allocate these value to their maximum result in local
    !this array represents the couples that will be creted locally in each step of the outer loop
    treated_couples=f_malloc0([1.to.norbp*maxval(nobj_par),0.to.nproc-1],id='treated_couples')

    !this array counts the number of couples created locally for each processor in each step
    ncouples_local=f_malloc0([0.to.nproc-1,0.to.nproc-1],id='ncouples_local')
   

    call warmup(nproc,ngroup,nobj_par,norb,norbp,norbp*maxval(nobj_par),symmetric,nearest_neighbor,&
         ncouples_local,treated_couples,nsteps)

    if (iproc==0) then
       call yaml_mapping_open('Test of the warmup procedure')
       call yaml_map('Number of steps',nsteps)
       call yaml_map('Total number of local couples',ncouples_local(:,0:nsteps))
       call yaml_map('Id of treated couples locally',treated_couples(:,0:nsteps))
       call yaml_mapping_close()
    end if


!!$
!!$    !at this point we know the list of couples tht are been treated per processor and per
!!$    !step. Therefore we might infer which kind of matrix indices have to be
!!$    !stored in parallel and which others not.
!!$    !allocate the array of fake result
!!$    fake_res=f_malloc(maxval(ncouples_local),id='fake_res')
!!$
!!$    local_transposed_v=f_malloc0(maxval(ncouples_local)*OP2P_outer%nstep,id='local_transposed_v')
!!$
!!$    !then for each step of the previous communication perform a loop
!!$    !to control which couples have to be passed
!!$    jdirect=0
!!$    jtransposed=0
!!$    do outer_step=0,OP2P_outer%nstep
!!$
!!$      call initialize_OP2P_data(OP2P_inner,mpiworld(),mpirank(),nproc,1,&
!!$        1,ncouples_local(0,outer_step),0,symfalse,nearest_neighbor)
!!$      !let us initialize two different OP2P objects, for the communication
!!$      call set_OP2P_iterator(iproc,OP2P_inner,iter_inner,&
!!$        ncouples_local(iproc,outer_step),treated_couples(1,outer_step),fake_res)
!!$      !perform here the stepps for the communication and realize which
!!$      !couples are entirely calculated
!!$      !if all the prcesses participate to the calculation
!!$      OP2P_inner_loop_init: do
!!$         call OP2P_communication_step(iproc,OP2P_inner,iter_inner)
!!$         if (iter_inner%event == OP2P_EXIT) exit
!!$         !here we should check which are the treated couples in the direct disctribution
!!$         !schemes and which are the ones which work in the transposed distribution scheme
!!$         do iorb=iter_inner%isloc_i,iter_inner%nloc_i+iter_inner%isloc_i-1
!!$            do jorb=iter_inner%isloc_j,iter_inner%nloc_j+iter_inner%isloc_j-1
!!$               !the quantities phi_i and phi_j here contain local and remote couples
!!$               ishift=iter_inner%phi_i%displ(iorb)
!!$               jshift=iter_inner%phi_j%displ(jorb)
!!$               icouple=iter_inner%phi_i(1+ishift)
!!$               jcouple=iter_inner%phi_j(1+jshift)
!!$               ind=matrix_element_id(icouple,jcouple)
!!$               call f_increment(jdirect)
!!$               k_ij_direct(jdirect)=ind
!!$               if (iorb==iter_inner%isloc_i) then
!!$                  call f_increment(jtransposed)
!!$                  local_transposed_v(jtransposed)=jcouple
!!$               end if
!!$            end do
!!$         end do
!!$      end do OP2P_inner_loop_init
!!$      call free_OP2P_data(OP2P_inner)
!!$    end do
!!$
!!$    !number of local couples to be stored
!!$    nij_loc=maxval(ncouples_local(iproc,:))
!!$
!!$    !as now the metadata are ready we may start the actual computation
!!$
!!$
!!$    !let us now identify a template for the calculation of the coupling matrix
!!$    k_ij=f_malloc0(jdirect,id='kij')
!!$    !also the array of distributed potentials is needed
!!$    !here we store the potentials which are built little by little
!!$    v_i_dist=f_malloc([ndimp,jtransposed],id='v_i_dist')
!!$
!!$    !again initialize the data, use no res for the moment
!!$    data=f_malloc([ndim,norbp],id='data')
!!$    res=f_malloc0([ndim,norbp],id='res')
!!$
!!$    !here we should put the max (so for the moment we assume norbp*nproc=norb)
!!$    rho_i_data=f_malloc([ndim,nij_loc],id='rho_i_data')
!!$    V_i_data=f_malloc([ndim,nij_loc],id='V_i_data')
!!$    V_i_data_res=f_malloc([ndim,nij_loc],id='V_i_data_res')
!!$
!!$
!!$    data=1.0_f_double
!!$    symfalse=.false.
!!$
!!$    !first initialize the OP2P data
!!$    call initialize_OP2P_data(OP2P_outer,mpiworld(),mpirank(),nproc,ngroup,ndim,nobj_par,0,symmetric,nearest_neighbor)
!!$
!!$    !let us initialize two different OP2P objects, for the communication
!!$    call set_OP2P_iterator(iproc,OP2P_outer,iter_outer,norbp,data,res)
!!$
!!$    bar=f_progress_bar_new(OP2P_outer%ncouples)
!!$    OP2P_outer_loop: do
!!$       call OP2P_communication_step(iproc,OP2P_outer,iter_outer)
!!$       if (iter_outer%event == OP2P_EXIT) exit
!!$       !otherwise calculate
!!$       call prepare_rho_and_v(ndim,norbp,norb,iter_outer%isloc_i,iter_outer%isloc_j,&
!!$            iter_outer%nloc_i,iter_outer%nloc_j,iter_outer%phi_i,iter_outer%phi_j,&
!!$            nij_loc,nij_glob,&
!!$            rho_I_data,v_i_data)
!!$
!!$       jorb_glb=iter_outer%phi_j%id_glb(iter_outer%isloc_j)
!!$       iorb_glb=iter_outer%phi_i%id_glb(iter_outer%isloc_i)
!!$
!!$       call OP2P_unitary_test(mpiworld(),mpirank(),nproc,1,ndim+2,nobj_p,symfalse,nearest_neighbor,assert=.true.)
!!$
!!$            !first initialize the OP2P data
!!$       call initialize_OP2P_data(OP2P_inner,mpiworld(),mpirank(),nproc,1,ndim+2,nobj_p,0,symfalse,nearest_neighbor)
!!$
!!$       !let us initialize two different OP2P objects, for the communication
!!$       call set_OP2P_iterator(iproc,OP2P_inner,iter_inner,nij_loc,v_i_data,v_i_data_res)
!!$
!!$       !call set_OP2P_iterator(iproc,OP2P_metadata,iter_inner,nij_loc,v_i_data,v_i_data_res)
!!$
!!$       !this loop should be modified into a mpi_alltoallv, but we do not know
!!$       !if all the prcesses participate to the calculation
!!$       OP2P_inner_loop: do
!!$          !call OP2P_communication_step(iproc,OP2P_metadata,iter_metadata)
!!$          call OP2P_communication_step(iproc,OP2P_inner,iter_inner)
!!$          print *,'iter_inner',iter_inner%istep,iter_outer%istep,iproc
!!$          if (iter_inner%event == OP2P_EXIT) exit
!!$          call fill_coupling_matrix(ndim,iter_inner%isloc_i,iter_inner%isloc_j,&
!!$               iter_inner%nloc_i,iter_inner%nloc_j,&
!!$               iter_inner%phi_i,iter_inner%phi_j,&
!!$               nij_loc,nij_glob,iorb_glb-1,jorb_glb-1,norb,ndimp,isdim,&
!!$               rho_I_data,k_ij,v_i_dist)
!!$
!!$       end do OP2P_inner_loop
!!$       call free_OP2P_data(OP2P_inner)
!!$
!!$       !here we might again fill the coupling matrix in the distributed sense
!!$       !calculate the coupling matrix
!!$       !call f_zero(coupl)
!!$       !here we only have the diagonal
!!$
!!$      !  do i=1,ndim
!!$      !     coupl=coupl+iter_inner%phi_j%data(i+jshift)*rho_i_data(i,ishift/(ndim+2)+1)
!!$      !  end do
!!$
!!$
!!$       if (iproc==0) then
!!$          call dump_progress_bar(bar,iter_outer%ncalls) !tmp
!!$       end if
!!$    end do OP2P_outer_loop
!!$
!!$    call mpiallred(k_ij,op=MPI_SUM)
!!$
!!$  !!$  do i=1,nij_glob
!!$  !!$     do j=i+1,nij_glob
!!$  !!$        !as we do not know which is zero and which is not
!!$  !!$        if (k_ij(i,j) ==0.0_f_double) then
!!$  !!$           k_ij(i,j)=k_ij(j,i)
!!$  !!$        else if (k_ij(j,i) == 0.0_f_double) then
!!$  !!$           k_ij(j,i)=k_ij(i,j)
!!$  !!$        end if
!!$  !!$     end do
!!$  !!$  end do
!!$
!!$    !printout the coupling matrix
!!$    !if (iproc==0)call yaml_map('K_IJ',[(k_ij(I,I), i=1,nij_glob)])
!!$
!!$    if (iproc==0) then
!!$       call yaml_map('K_IJ',k_ij)
!!$       call yaml_map('Total sum',sum(k_ij))
!!$       call yaml_map('Dist',sum(v_i_dist,dim=1))
!!$    end if
!!$
!!$
!!$
!!$    call free_OP2P_data(OP2P_outer)
!!$
!!$    call f_free(data)
!!$    call f_free(res)
!!$    call f_free(rho_i_data)
!!$    call f_free(v_i_data)
!!$    call f_free(v_i_data_res)
!!$    call f_free(v_i_dist)
!!$    call f_free(k_ij)

    call f_free(nobj_par)
    call f_free(nobj_p)
    call f_free(treated_couples)
    call f_free(ncouples_local)

    call mpifinalize()
    call f_lib_finalize()

    contains

      !> Identify the options from command line
      !! and write the result in options dict
      subroutine OP2P_check_command_line_options(options)
        implicit none
        !> dictionary of the options of the run
        !! on entry, it contains the options for initializing
        !! on exit, it contains in the key "BigDFT", a list of the
        !! dictionaries of each of the run that the local instance of BigDFT
        !! code has to execute
        type(dictionary), pointer :: options
        !local variables
        type(yaml_cl_parse) :: parser !< command line parser

        !define command-line options
        parser=yaml_cl_parse_null()
        !between these lines, for another executable using BigDFT as a blackbox,
        !other command line options can be specified
        !then the bigdft options can be specified
        call OP2P_check_options(parser)
        !parse command line, and retrieve arguments
        call yaml_cl_parse_cmd_line(parser,args=options)
        !free command line parser information
        call yaml_cl_parse_free(parser)

      end subroutine OP2P_check_command_line_options

  end program OP2P_check


  !> Check the options
  subroutine OP2P_check_options(parser)
    use futile
    implicit none
    type(yaml_cl_parse), intent(inout) :: parser

    call yaml_cl_parse_option(parser,'ndim','10',&
         'Size of the object','n',&
         dict_new('Usage' .is. &
         'Sizes of the unitary object of the check',&
         'Allowed values' .is. &
         'Yaml list of integers. If a scalar integer is given, all the dimensions will have this size.'))

    call yaml_cl_parse_option(parser,'objects','[10, 10]',&
         'Objects per group','o',&
         dict_new('Usage' .is. &
         'Set the number of objects per group',&
         'Allowed values' .is. &
         'Yaml list of integers. The orbitals are then distributed among the processors.'))

    call yaml_cl_parse_option(parser,'symmetric','Yes',&
         'Symmetricity','s',&
         dict_new('Usage' .is. &
         'Boolean, set the symmetricity of the operation.'))

    call yaml_cl_parse_option(parser,'nn-pattern','No',&
         'Nearest-Neigbor communication','c',&
         dict_new('Usage' .is. &
         'Boolean, adjust the communication pattern of the operation.'))

  end subroutine OP2P_Check_options

!!$  subroutine calculate_ndimp_and_isdim(ndim,nproc,iproc,ndimp,isdim,ndim_p)
!!$    use futile
!!$    implicit none
!!$    integer, intent(in) :: ndim,nproc,iproc
!!$    integer, intent(out) :: ndimp,isdim
!!$    integer, dimension(0:nproc-1), intent(out) :: ndim_p
!!$    !local variables
!!$    integer :: jproc,i
!!$
!!$    do i=0,ndim-1
!!$       jproc=modulo(i,nproc)
!!$       call f_increment(ndim_p(jproc))
!!$    end do
!!$
!!$    !verify
!!$    call f_assert(sum(ndim_p)==ndim,id='Total partition of ndim failed')
!!$
!!$    isdim=0
!!$    !calculate the shift
!!$    do jproc=0,iproc-1
!!$       call f_increment(isdim,inc=ndim_p(jproc))
!!$    end do
!!$    ndimp=ndim_p(iproc)
!!$
!!$  end subroutine calculate_ndimp_and_isdim
!!$
!!$  subroutine prepare_rho_and_v(ndim,norbp,norb,isloc_i,isloc_j,nloc_i,nloc_j,phi_i,phi_j,&
!!$       ncouples_local,ncouples_global,&
!!$       rho_I_data,v_i_data)
!!$    use futile
!!$    use overlap_point_to_point
!!$    implicit none
!!$    integer, intent(in) :: ndim,isloc_i,isloc_j,nloc_i,nloc_j,ncouples_global,ncouples_local,norbp,norb
!!$    real(f_double), dimension(ndim,ncouples_local),intent(inout) :: rho_I_data
!!$    real(f_double), dimension(ndim,ncouples_local),intent(inout) :: v_i_data
!!$    type(local_data), intent(inout) :: phi_i,phi_j
!!$    !local variables
!!$    real(f_double), parameter :: factor=5.0_f_double
!!$    integer :: iorb,jorb,i,ishift,jshift,jorb_glb,I_Loc,iorb_glb
!!$    !fill the coupling matrix
!!$    do iorb=isloc_i,nloc_i+isloc_i-1
!!$       do jorb=isloc_j,nloc_j+isloc_j-1
!!$          I_loc=iorb+norbp*(jorb-1)
!!$          !calculate rho_i
!!$          ishift=phi_i%displ(iorb)
!!$          jshift=phi_j%displ(jorb)
!!$          do i=1,ndim
!!$             rho_i_data(i,I_loc)=phi_i%data(i+ishift)*phi_j%data(i+jshift)
!!$          end do
!!$
!!$          !calculate V_i (siimulate the application of the poisson solver)
!!$          do i=1,ndim
!!$             v_i_data(i,I_loc)=factor*rho_i_data(i,I_loc)
!!$          end do
!!$
!!$          jorb_glb=phi_j%id_glb(jorb)
!!$          iorb_glb=phi_i%id_glb(iorb)
!!$       end do
!!$    end do
!!$
!!$  end subroutine prepare_rho_and_v
!!$
!!$  !>this routine have to be called with the proper shifts and offsets
!!$  subroutine store_v_transposed
!!$    implicit none
!!$
!!$    do jc=1,nloc_j
!!$       jshift=phi_j%displ(jc+isloc_j)
!!$       !store in the distributed array the potentials
!!$       !of the couples which have been calculalted already
!!$       do i=1,ndimp
!!$          v_i_dist(i,jc)=phi_j%data(i+jshift+isdim)
!!$       end do
!!$    end do
!!$
!!$  end subroutine store_v_transposed
!!$
!!$  subroutine combine_rho_and_v_transposed(ndimp,ncouples_local,ncouples_transposed,ncouples_total,&
!!$       v_i_transposed,rho_i,local_transposed_v,k_ij_tr)
!!$    use f_precisions
!!$    implicit none
!!$    integer, intent(in) :: ndimp,ncouples_transposed,ncouples_local,ncouples_total
!!$    integer, dimension(ncouples_transposed), intent(in) :: local_transposed_v !<lookup array
!!$    real(f_double), dimension(ndimp,ncouples_local), intent(in) :: rho_i
!!$    real(f_double), dimension(ndimp,ncouples_transposed), intent(in) :: v_i_transposed
!!$    real(f_double), dimension(ncouples_total), intent(in) :: k_ij_tr !<transposed coupling matrix
!!$    !local variables
!!$    integer :: ic,iic,jc,jjc,idim,ind
!!$    real(f_double) :: coupling
!!$
!!$    do ic=1,ncouples_local
!!$       iic=local_to_global_id(ic)
!!$       do jc=1,ncouples_transposed
!!$          jjc=local_transposed_v(jc)
!!$          coupling=0.0_f_double
!!$          do idim=1,ndimp
!!$             coupling=coupling+rho_i(idim,ic)*v_i_transposed(idim,jc)
!!$          end do
!!$          ind=matrix_element_id(iic,jjc)
!!$          k_ij_tr(ind)=coupling
!!$       end do
!!$    end do
!!$
!!$  end subroutine combine_rho_and_v_transposed
!!$
!!$  subroutine fill_coupling_matrix(ndim,isloc_i,isloc_j,nloc_i,nloc_j,phi_i,phi_j,&
!!$       ncouples_local,ncouples_global,iglob_shift,jglob_shift,norb,ndimp,&
!!$       isdim,rho_I_data,k_ij,v_i_dist)
!!$    use futile
!!$    use overlap_point_to_point
!!$    implicit none
!!$    integer, intent(in) :: ndim,isloc_i,isloc_j,nloc_i,nloc_j,ncouples_global,ncouples_local
!!$    integer, intent(in) :: iglob_shift,jglob_shift,norb,ndimp,isdim
!!$    real(f_double), dimension(ndim,ncouples_local),intent(inout) :: rho_I_data
!!$    real(f_double), dimension(ncouples_global,ncouples_global), intent(inout) :: k_ij
!!$    real(f_double), dimension(ndimp,ncouples_global), intent(inout) :: v_i_dist
!!$    type(local_data), intent(inout) :: phi_i,phi_j
!!$    integer :: ic,jc,i,ishift,jshift,jc_glb,ic_glb,iorbi,iorbj,jorbi,jorbj
!!$    real(f_double) :: coupl
!!$
!!$    do ic=isloc_i,nloc_i+isloc_i-1
!!$       do jc=isloc_j,nloc_j+isloc_j-1
!!$
!!$          jshift=phi_j%displ(jc)
!!$          ishift=phi_i%displ(ic)
!!$
!!$          !calculate the coupling matrix
!!$          call f_zero(coupl)
!!$          !here we only have the local steps columns
!!$          do i=1,ndim
!!$             coupl=coupl+phi_j%data(i+jshift)*rho_i_data(i,ishift/(ndim)+1)
!!$          end do
!!$
!!$          call f_increment(icoupling)
!!$          ind=lookup_k_ij(icoupling)
!!$
!!$          k_ij(ind)=coupling
!!$
!!$          !store in the distributed array the potentials
!!$          !of the couples which have been calculalted already
!!$          do i=1,ndimp
!!$             v_i_dist(i,jc_glb)=phi_j%data(i+jshift+isdim)
!!$          end do
!!$
!!$       end do
!!$    end do
!!$  end subroutine fill_coupling_matrix

  subroutine warmup(nproc,ngroup,nobj_par,norb,norbp,ncouples_local_max,symmetric,nearest_neighbor,&
       ncouples_local,treated_couples,nsteps)
    use futile
    use wrapper_MPI
    use overlap_point_to_point
    implicit none
    logical, intent(in) :: nearest_neighbor
    integer, intent(in) :: norbp,ngroup,ncouples_local_max,nproc,norb
    logical, intent(inout) :: symmetric
    integer, dimension(0:nproc-1,ngroup), intent(in) :: nobj_par
    integer, intent(out) :: nsteps
    integer, dimension(0:nproc-1,0:nproc-1), intent(inout) :: ncouples_local
    real(f_double), dimension(ncouples_local_max,0:nproc-1), intent(inout) :: treated_couples
    !local variables
    integer :: iorb,jorb,ncouples_step,ndim_metadata,iproc,iorb_glb,jorb_glb
    type(OP2P_data) :: OP2P_outer
    type(OP2P_iterator) :: iter_outer
    real(f_double), dimension(:,:), allocatable :: fake_res_psi,pseudopsi
  
    ndim_metadata=2

    pseudopsi=f_malloc0([ndim_metadata,norbp],id='pseudopsi')
    fake_res_psi=f_malloc0([ndim_metadata,norbp],id='fake_res_psi')

    iproc=mpirank()
    !initialize data and res object
    !to calculate the couples globally let us perform a run exchanging the metadata
    !first initialize the OP2P data for the couples
    call initialize_OP2P_data(OP2P_outer,mpiworld(),iproc,nproc,ngroup,ndim_metadata,&
      nobj_par,0,symmetric,nearest_neighbor)
    !let us initialize two different OP2P objects, for the communication
    call set_OP2P_iterator(iproc,OP2P_outer,iter_outer,norbp,pseudopsi,fake_res_psi)
    nsteps=0
    OP2P_outer_loop_init: do
       call OP2P_communication_step(iproc,OP2P_outer,iter_outer)
       if (iter_outer%event == OP2P_EXIT) exit
       nsteps=iter_outer%istep
       !for each step now calculate the id of the couples that will be echanged
       !and the id of the ones which will be neglected
       ncouples_step=0
       do iorb=iter_outer%isloc_i,iter_outer%nloc_i+iter_outer%isloc_i-1
          do jorb=iter_outer%isloc_j,iter_outer%nloc_j+iter_outer%isloc_j-1
             jorb_glb=iter_outer%phi_j%id_glb(jorb)
             iorb_glb=iter_outer%phi_i%id_glb(iorb)
            call f_increment(ncouples_step)
            treated_couples(ncouples_step,iter_outer%istep)=&
                 real(couple_global_id(iorb_glb,jorb_glb,norb),f_double)
         end do
      end do
      ncouples_local(iproc,iter_outer%istep)=ncouples_step
    end do OP2P_outer_loop_init
    
    call free_OP2P_data(OP2P_outer)
    !then reduce the results of the communication for each of the steps
    call mpiallred(ncouples_local,op=MPI_SUM)

    call f_free(fake_res_psi)
    call f_free(pseudopsi)

    contains

      !> constructs the unique id of the couple starting from the orbital number
      pure function couple_global_id(iorb,jorb,norb) result(id)
        implicit none
        integer, intent(in) :: iorb,jorb,norb
        integer :: id
        !local variables
        integer :: ii,jj
        ii=max(iorb,jorb)
        jj=min(iorb,jorb)
        id=ii+(jj-1)*norb
      end function couple_global_id

  end subroutine warmup
