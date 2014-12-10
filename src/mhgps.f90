!! @file
!! @author Bastian Schaefer
!! @section LICENCE
!!    Copyright (C) 2014 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS
program mhgps
    use module_base
    use module_types
    use module_interfaces
    use module_input_dicts
    use yaml_output
    use module_io
    use module_atoms, only: deallocate_atoms_data,&
                            deallocate_atomic_structure,&
                            atomic_structure,&
                            read_atomic_file=>set_astruct_from_file,&
                            astruct_dump_to_file
    
    use module_global_variables
    use module_userinput
    use module_energyandforces, only: mhgpsenergyandforces
    use module_ls_rmsd, only: superimpose
    use module_sqn, only: findbonds !for finding binds
    use module_freezingstring, only: get_ts_guess 
    use module_saddle, only: findsad_work, findsad,&
                             allocate_finsad_workarrays,&
                             deallocate_finsad_workarrays
    use module_connect, only: connect_recursively, connect,&
                              connect_object,&
                              deallocate_connect_object,&
                              allocate_connect_object
    use module_fingerprints, only: fingerprint_interface
    use module_hessian, only: cal_hessian_fd 
    use module_minimizers
    use bigdft_run
    implicit none
    integer :: isame,njobs,nbond
    integer :: infocode
    character(len=200) :: filename
    character(len=60) :: run_id,naming_id
    integer :: ifolder,ijob
    logical :: xyzexists,asciiexists
    type(dictionary), pointer :: run
    integer :: ierr, nconfig
    real(gp), allocatable :: rcov(:)
    character(len=300)  :: comment
    character(len=100), allocatable :: joblist(:,:)
    logical :: converged=.false.
    type(connect_object) :: cobj
    type(dictionary), pointer :: options
    integer :: nsad
    logical :: connected
    type(run_objects) :: runObj
    type(state_properties) :: outs
    type(findsad_work) :: fsw
    type(userinput) :: uinp
    integer :: lwork
    real(8), allocatable :: work(:)
    real(8) :: wd(1)

    !simple atomic datastructre
    integer :: nat
    integer :: nid
    real(gp) :: alat(3)
    real(gp), allocatable :: rxyz(:,:),fxyz(:,:)
    real(gp), allocatable :: fat(:,:)
    real(gp), allocatable :: rxyz2(:,:),fxyz2(:,:)
    real(gp), allocatable :: tsguess(:,:),minmodeguess(:,:)
    real(gp), allocatable :: tsgforces(:,:)
    real(gp)              :: tsgenergy
    real(gp), allocatable :: fp(:),fp2(:)
    real(gp), allocatable :: rotforce(:,:),hess(:,:)
    real(gp), allocatable :: eval(:)
    real(gp) :: energy, energy2, ec, displ
    real(gp) :: fnoise, fnrm, fmax
    integer :: i,j,info
    integer :: idum=0
    real(kind=4) :: builtin_rand

    !functions
    real(gp) :: dnrm2

    nbond=1
    ifolder=1
    ef_counter=0.d0 !from module_global_variables
!    isad=0  !from module_global_variables
!    ntodo=0  !from module_global_variables
    !isadprob=0
    call read_restart(isad,isadprob,ntodo)


    call f_lib_initialize()

    !read mhgps.inp
    call read_input(uinp)

    isForceField=.true.
    write(currDir,'(a,i3.3)')'input',ifolder
    call get_first_struct_file(filename)

!    if(efmethod=='BIGDFT')then
    call bigdft_command_line_options(options)
    call bigdft_init(options)!mpi_info,nconfig,run_id,ierr)
    if (bigdft_nruns(options) > 1) then
        call f_err_throw('runs-file not supported for MHGPS '//&
                         'executable')
    endif
    run => options // 'BigDFT' // 0
    iproc=bigdft_mpi%iproc!mpi_info(1)
    nproc=bigdft_mpi%nproc!mpi_info(2)
    igroup=bigdft_mpi%igroup!mpi_info(3)
    !number of groups
    ngroups=bigdft_mpi%ngroup!mpi_info(4)
    !actual value of iproc
    iproc=iproc+igroup*ngroups
    if(iproc==0) call print_logo_mhgps()

    !reset input and output positions of run
    call bigdft_get_run_properties(run,input_id=run_id,&
         naming_id=naming_id)
    call bigdft_set_run_properties(run,&
         posinp_id=trim(adjustl(filename))//trim(naming_id))

    call run_objects_init(runObj,run)

    !options and run are not needed
    call dict_free(options)
    nullify(run)

    call init_state_properties(outs, bigdft_nat(runObj))

    if(trim(adjustl(char(runObj%run_mode)))=='QM_RUN_MODE')then
        isForceField=.false.
        itermin=runObj%inputs%itermin
    endif


!    elseif(efmethod=='AMBER')then
!        iproc=0
!        isForceField=.true.
!        call read_atomic_file(trim(adjustl(filename)),&
!             iproc,atom_struct)
!        astruct_ptr=>atom_struct
!        fdim=astruct_ptr%nat
!        !alanine stuff ......................START!>
!          l_sat=5
!          allocate(atomnamesdmy(1000))
!          rxyzdmy = f_malloc((/ 1.to.3, 1.to.astruct_ptr%nat/),&
!                            id='rxyzdmy')
!          fxyzdmy = f_malloc((/ 1.to.3, 1.to.astruct_ptr%nat/),&
!                            id='fxyzdmy')
!          fnpdb='ald_new.pdb'
!          nfnpdb=len(trim(fnpdb));
!          call nab_init(astruct_ptr%nat,rxyzdmy,fxyzdmy,&
!                        trim(fnpdb),nfnpdb,l_sat,atomnamesdmy)
!          call f_free(rxyzdmy)
!          call f_free(fxyzdmy)
!          deallocate(atomnamesdmy)
!        !alanine stuff ......................END!>
!
!        call print_logo_mhgps()
!    else
!        call yaml_warning('Following method for evaluation of '//&
!        'energies and forces is unknown: '//trim(adjustl(efmethod)))
!        stop
!    endif
    if(iproc==0) call print_input(uinp)

    nat = bigdft_nat(runObj)
    nid = nat !s-overlap fingerprints
    alat =bigdft_get_cell(runObj)!astruct_ptr%cell_dim
    
    !allocate arrays
    hess     = f_malloc((/ 1.to.3*nat,&
                1.to.3*nat/),id='hess')
    eval  = f_malloc((/ 1.to.3*nat/),id='eval')
    call DSYEV('N','L',3*nat,hess,3*nat,eval,wd,-1,info)
    if (info.ne.0) stop 'info query'
    lwork=nint(wd(1))
    work = f_malloc((/ 1.to.lwork/),id='work')
    tsgforces     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='tsgforces')
    tsguess     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='tsguess')
    minmodeguess  = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='minmodeguess')
    minmode  = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='minmode')
    rxyz     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='rxyz')
    fp       = f_malloc((/ 1.to.nid/),&
                id='fp')
    fp2      = f_malloc((/ 1.to.nid/),&
                id='fp2')
    fxyz     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='fxyz')
    rxyz2     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='rxyz2')
    fat       = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='fat')
    fxyz2     = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='fxyz2')
    rcov     = f_malloc((/ 1.to.nat/),id='rcov')
    iconnect = f_malloc((/ 1.to.2, 1.to.1000/),id='iconnect')
    rotforce = f_malloc((/ 1.to.3, 1.to.nat/),&
                id='rotforce')


!    joblist = f_malloc_str((/1.to.2, 1.to.999/),id='joblist') !how??
   allocate(joblist(2,999))

    call allocate_connect_object(nat,nid,uinp%nsadmax,cobj)

    iconnect = 0
    call give_rcov(bigdft_get_astruct_ptr(runObj),nat,rcov)
    !if in biomode, determine bonds betweens atoms once and for all
    !(it isassuemed that all conifugrations over which will be
    !iterated have the same bonds)
    if(uinp%saddle_biomode)then
        call findbonds('(MHGPS)',iproc,uinp%mhgps_verbosity,nat,rcov,&
        bigdft_get_rxyz_ptr(runObj),nbond,iconnect)
    endif
    call allocate_finsad_workarrays(runObj,uinp,nbond,fsw)

    do ifolder = 1,999
        write(currDir,'(a,i3.3)')'input',ifolder
        call read_jobs(uinp,njobs,joblist)

        do ijob = 1,njobs
           call bigdft_get_rxyz(filename=&
                trim(adjustl(joblist(1,ijob))),rxyz=rxyz)

           select case(trim(adjustl(uinp%operation_mode)))
           case('guessonly')
              call bigdft_get_rxyz(filename=joblist(2,ijob),&
                   rxyz=rxyz2)

              isad=isad+1
              write(isadc,'(i5.5)')isad
              !rmsd alignment (optional in mhgps approach)
              call superimpose(nat,rxyz(1,1),rxyz2(1,1))
              inputPsiId=0
              call get_ts_guess(nat,alat,uinp,runObj,outs,rxyz(1,1),&
                   rxyz2(1,1),tsguess(1,1),minmodeguess(1,1),&
                   tsgenergy,tsgforces(1,1))
              write(comment,'(a)')&
                   'TS guess; forces below give guessed '//&
                   'minimummode.'
              call astruct_dump_to_file(&
                   bigdft_get_astruct_ptr(runObj),currDir//'/sad'//&
                   trim(adjustl(isadc))//'_ig_finalM',comment,&
                   tsgenergy,rxyz=tsguess,forces=minmodeguess)

              call astruct_dump_to_file(&
                   bigdft_get_astruct_ptr(runObj),currDir//'/sad'//&
                   trim(adjustl(isadc))//'_ig_finalF',comment,&
                   tsgenergy,rxyz=tsguess,forces=tsgforces)
           case('connect')
              call bigdft_get_rxyz(filename=joblist(2,ijob),&
                   rxyz=rxyz2)

              !Evalute energies. They are needed in connect
              !for identification
              inputPsiId=0
              call mhgpsenergyandforces(nat,alat,runObj,outs,rxyz,&
                                        fat,fnoise,energy,infocode)
              inputPsiId=0
              call mhgpsenergyandforces(nat,alat,runObj,outs,rxyz2,&
                                        fat,fnoise,energy2,infocode)
              call fingerprint(nat,nid,alat,&
                   bigdft_get_geocode(runObj),rcov,rxyz(1,1),fp(1))
              call fingerprint(nat,nid,alat,&
                   bigdft_get_geocode(runObj),rcov,rxyz2(1,1),fp2(1))
              if(iproc==0)then
                 call yaml_comment('(MHGPS) Connect '//&
                      trim(adjustl(joblist(1,ijob)))//' and '//&
                      trim(adjustl(joblist(2,ijob)))//' ....',&
                      hfill='-')
              endif
              isame=0
              nsad=0
              connected=.true.
              !call connect(nat,nid,alat,rcov,nbond,&
              !     iconnect,rxyz,rxyz2,energy,energy2,fp,fp2,&
              !     nsad,cobj,connected)
              call connect_recursively(nat,nid,alat,fsw,uinp,runObj,outs,rcov,&
                   nbond,isame,iconnect,rxyz,rxyz2,energy,energy2,fp,&
                   fp2,nsad,cobj,connected)
              if(connected)then
                 if(iproc==0)call yaml_map('(MHGPS) '//&
                      'succesfully connected, intermediate'//&
                      ' transition states',nsad)
              else
                 if(iproc==0)call yaml_comment('(MHGPS) '//&
                      'Connection not established within '//&
                      trim(adjustl(yaml_toa(nsad)))//&
                      ' transition state computations')
              endif
           case('simple')
              isad=isad+1
              write(isadc,'(i3.3)')isad
              if(uinp%random_minmode_guess)then
                 do i=1,nat
                    minmode(1,i)=2.0_gp*&
                         (real(builtin_rand(idum),gp)-0.5_gp)
                    minmode(2,i)=2.0_gp*&
                         (real(builtin_rand(idum),gp)-0.5_gp)
                    minmode(3,i)=2.0_gp*&
                         (real(builtin_rand(idum),gp)-0.5_gp)
                 enddo
                 call write_mode(nat,runObj,outs,&
                      trim(adjustl(joblist(1,ijob)))//'_mode',minmode)
              else
                 call read_mode(nat,trim(adjustl(joblist(1,ijob)))&
                      //'_mode',minmode)
              endif
              !!call random_seed
              !!call random_number(minmode)
              !!minmode=2.d0*(minmode-0.5d0)
              !normalize
              minmode = minmode/dnrm2(3*nat,minmode(1,1),1)
              ec=0.0_gp
              displ=0.0_gp
              call findsad(nat,alat,fsw,uinp,runObj,outs,rcov,nbond,iconnect,&
                   rxyz(1,1),energy,fxyz(1,1),minmode(1,1),displ,ec,&
                   rotforce(1,1),converged)
              if(.not.converged)then
                 call yaml_warning('Saddle '//yaml_toa(isad)//&
                      ' not converged')
              endif
              call fnrmandforcemax(fxyz(1,1),fnrm,&
                   fmax,nat)
              fnrm = sqrt(fnrm)
              if (iproc == 0) then
                 write(comment,'(a,1pe10.3,5x1pe10.3)')&
                      'ATTENTION! Forces below give no forces, '//&
                      'but the final minmode| '//&
                      'fnrm, fmax = ',fnrm,fmax

                 call astruct_dump_to_file(&
                      bigdft_get_astruct_ptr(runObj),currDir//&
                      '/sad'//trim(adjustl(isadc))//'_finalM',&
                      comment,energy,rxyz=rxyz,forces=minmode)

                 write(comment,'(a,1pe10.3,5x1pe10.3)')&
                      'fnrm, fmax = ',fnrm,fmax
                 call astruct_dump_to_file(&
                      bigdft_get_astruct_ptr(runObj),currDir//&
                      '/sad'//trim(adjustl(isadc))//'_finalF',&
                      comment,energy,rxyz=rxyz,forces=fxyz)

                 call write_mode(nat,runObj,outs,currDir//'/sad'//&
                      trim(adjustl(isadc))//'_mode_final',&
                      minmode(1,1),rotforce(1,1))
              endif
           case('minimize')
              isad=isad+1
              write(isadc,'(i3.3)')isad
              ec=0.0_gp
              inputPsiId=0
              call mhgpsenergyandforces(nat,alat,runObj,outs,rxyz,&
                   fxyz,fnoise,energy,infocode)
              call minimize(uinp%imode,nat,alat,uinp,runObj,outs,nbond,&
                   iconnect,rxyz(1,1),fxyz(1,1),fnoise,energy,ec,&
                   converged,'')
              if(.not.converged)then
                 call yaml_warning('Minimization '//yaml_toa(isad)&
                      //' not converged')
              endif
              call fnrmandforcemax(fxyz(1,1),fnrm,fmax,nat)
              if (iproc == 0) then
                 write(comment,'(a,1pe10.3,5x1pe10.3)')&
                      'fnrm, fmax = ',fnrm,fmax

                 call astruct_dump_to_file(&
                      bigdft_get_astruct_ptr(runObj),currDir//'/min'&
                      //trim(adjustl(isadc))//'_final',comment,&
                      energy,rxyz=rxyz,forces=fxyz)
              endif
           case('hessian')
              inputPsiId=0
              call mhgpsenergyandforces(nat,alat,runObj,outs,rxyz,&
                   fxyz,fnoise,energy,infocode)
              inputPsiId=0
              call cal_hessian_fd(iproc,nat,alat,runObj,outs,rxyz,&
                   hess)
              if(iproc==0)then
                 write(*,*)'(hess) HESSIAN:'
                 write(*,*)hess
              endif
              call DSYEV('V','L',3*nat,hess,3*nat,eval,WORK,LWORK,&
                   INFO)
              if (info.ne.0) stop 'DSYEV'
              if(iproc==0)then
                 write(*,*)'(hess) EIGENVECTORS:'
                 write(*,*) hess
                 write(*,'(a,1x,es9.2,1x,es24.17)') '(hess)'//&
                      ' ---   App. eigenvalues in exact --------'//&
                      '--- fnrm:',sqrt(sum(fxyz**2)),energy
                 do j=1,3*nat
                    write(*,*) '(hess) eval ',j,eval(j)
                 enddo
              endif
           case default
              call yaml_warning('(MHGPS) operation mode '//&
                   trim(adjustl(uinp%operation_mode))//' unknown STOP')
              stop '(MHGPS) operation mode unknown STOP'
           end select
           call write_jobs(njobs,joblist,ijob)
           call write_restart(isad,isadprob,ntodo)
        enddo
        call f_delete_file('restart')
        call f_delete_file(trim(adjustl(currdir))//'/job_list_restart')
     enddo

    call f_delete_file('restart')

    !finalize (dealloctaion etc...)
    call free_run_objects(runObj)
    call deallocate_state_properties(outs)
    call bigdft_finalize(ierr)

    call f_free(work)
    call f_free(eval)
    call f_free(tsguess)
    call f_free(tsgforces)
    call f_free(minmodeguess)
    call f_free(minmode)
    call f_free(fp)
    call f_free(fp2)
    call f_free(rxyz)
    call f_free(fat)
    call f_free(fxyz) 
    call f_free(rxyz2)
    call f_free(fxyz2) 
    call f_free(rcov)
    call f_free(iconnect)
    call f_free(rotforce)
    call f_free(hess)
    call deallocate_connect_object(cobj)
    call deallocate_finsad_workarrays(fsw)

    if(iproc==0)call yaml_map('(MHGPS) Total calls to energy and '//&
                               'forces',nint(ef_counter))
    if(iproc==0)call yaml_map('(MHGPS) Run finished at',&
                               yaml_date_and_time_toa())
    call f_lib_finalize()
end program
