module sparsematrix_init
  use module_base
  use sparsematrix_base
  implicit none

  private


  !> Public routines
  public :: init_sparse_matrix
  public :: compressed_index
  public :: matrixindex_in_compressed
  public :: check_kernel_cutoff

  contains



    !> Count for each orbital and each process the number of overlapping orbitals.
    subroutine determine_overlap_from_descriptors(iproc, nproc, orbs, orbsig, lzd, lzdig, op_noverlaps, op_overlaps)
      use module_base
      use module_types
      use module_interfaces
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      type(orbitals_data),intent(in) :: orbs, orbsig
      type(local_zone_descriptors),intent(in) :: lzd, lzdig
      integer,dimension(orbs%norb),intent(out):: op_noverlaps
      integer,dimension(:,:),pointer,intent(out):: op_overlaps
    
      ! Local variables
      integer :: jproc, iorb, jorb, ioverlapMPI, ioverlaporb, ilr, jlr, ilrold
      integer :: iiorb, istat, iall, noverlaps, ierr, ii
      logical :: isoverlap
      integer :: onseg
      logical,dimension(:,:),allocatable :: overlapMatrix
      integer,dimension(:),allocatable :: noverlapsarr, displs, recvcnts, comon_noverlaps
      integer,dimension(:,:),allocatable :: overlaps_op
      integer,dimension(:,:,:),allocatable :: overlaps_nseg
      character(len=*),parameter :: subname='determine_overlap_from_descriptors'
    
      allocate(overlapMatrix(orbsig%norb,maxval(orbs%norb_par(:,0))), stat=istat)
      call memocc(istat, overlapMatrix, 'overlapMatrix', subname)
      allocate(noverlapsarr(orbs%norbp), stat=istat)
      call memocc(istat, noverlapsarr, 'noverlapsarr', subname)
      allocate(displs(0:nproc-1), stat=istat)
      call memocc(istat, displs, 'displs', subname)
      allocate(recvcnts(0:nproc-1), stat=istat)
      call memocc(istat, recvcnts, 'recvcnts', subname)
      allocate(overlaps_nseg(orbsig%norb,orbs%norbp,2), stat=istat)
      call memocc(istat, overlaps_nseg, 'overlaps_nseg', subname)
    
      allocate(comon_noverlaps(0:nproc-1), stat=istat)
      call memocc(istat, comon_noverlaps, 'comon_noverlaps',subname)
    
      overlapMatrix=.false.
      overlaps_nseg = 0
      ioverlapMPI=0 ! counts the overlaps for the given MPI process.
      ilrold=-1
      do iorb=1,orbs%norbp
         ioverlaporb=0 ! counts the overlaps for the given orbital.
         iiorb=orbs%isorb+iorb
         ilr=orbs%inWhichLocreg(iiorb)
    !     call get_start_and_end_indices(lzd%llr(ilr), is1, ie1, is2, ie2, is3, ie3)
         do jorb=1,orbsig%norb
            jlr=orbsig%inWhichLocreg(jorb)
            call check_overlap_cubic_periodic(lzd%Glr,lzd%llr(ilr),lzdig%llr(jlr),isoverlap)
    !        call get_start_and_end_indices(lzd%llr(jlr), js1, je1, js2, je2, js3, je3)
    !        ovrlpx = ( is1<=je1 .and. ie1>=js1 )
    !        ovrlpy = ( is2<=je2 .and. ie2>=js2 )
    !        ovrlpz = ( is3<=je3 .and. ie3>=js3 )
    !        if(ovrlpx .and. ovrlpy .and. ovrlpz) then
            !write(*,*) 'second: iproc, ilr, jlr, isoverlap', iproc, ilr, jlr, isoverlap
            if(isoverlap) then
               ! From the viewpoint of the box boundaries, an overlap between ilr and jlr is possible.
               ! Now explicitely check whether there is an overlap by using the descriptors.
               !!call overlapbox_from_descriptors(lzd%llr(ilr)%d%n1, lzd%llr(ilr)%d%n2, lzd%llr(ilr)%d%n3, &
               !!     lzd%llr(jlr)%d%n1, lzd%llr(jlr)%d%n2, lzd%llr(jlr)%d%n3, &
               !!     lzd%glr%d%n1, lzd%glr%d%n2, lzd%glr%d%n3, &
               !!     lzd%llr(ilr)%ns1, lzd%llr(ilr)%ns2, lzd%llr(ilr)%ns3, &
               !!     lzd%llr(jlr)%ns1, lzd%llr(jlr)%ns2, lzd%llr(jlr)%ns3, &
               !!     lzd%glr%ns1, lzd%glr%ns2, lzd%glr%ns3, &
               !!     lzd%llr(ilr)%wfd%nseg_c, lzd%llr(jlr)%wfd%nseg_c, &
               !!     lzd%llr(ilr)%wfd%keygloc, lzd%llr(ilr)%wfd%keyvloc, lzd%llr(jlr)%wfd%keygloc, lzd%llr(jlr)%wfd%keyvloc, &
               !!     n1_ovrlp, n2_ovrlp, n3_ovrlp, ns1_ovrlp, ns2_ovrlp, ns3_ovrlp, nseg_ovrlp)
               call check_overlap_from_descriptors_periodic(lzd%llr(ilr)%wfd%nseg_c, lzdig%llr(jlr)%wfd%nseg_c,&
                    lzd%llr(ilr)%wfd%keyglob, lzdig%llr(jlr)%wfd%keyglob, &
                    isoverlap, onseg)
               if(isoverlap) then
                  ! There is really an overlap
                  overlapMatrix(jorb,iorb)=.true.
                  ioverlaporb=ioverlaporb+1
                  overlaps_nseg(ioverlaporb,iorb,1)=onseg
                  if(ilr/=ilrold) then
                     ! if ilr==ilrold, we are in the same localization region, so the MPI prosess
                     ! would get the same orbitals again. Therefore the counter is not increased
                     ! in that case.
                     ioverlapMPI=ioverlapMPI+1
                  end if
               else
                  overlapMatrix(jorb,iorb)=.false.
               end if
            else
               overlapMatrix(jorb,iorb)=.false.
            end if
         end do
         noverlapsarr(iorb)=ioverlaporb
         ilrold=ilr
      end do
      noverlaps=ioverlapMPI
    
      !call mpi_allreduce(overlapMatrix, orbs%norb*maxval(orbs%norb_par(:,0))*nproc, mpi_sum bigdft_mpi%mpi_comm, ierr)
    
      ! Communicate op_noverlaps and comon_noverlaps
      if (nproc > 1) then
         call mpi_allgatherv(noverlapsarr, orbs%norbp, mpi_integer, op_noverlaps, orbs%norb_par, &
              orbs%isorb_par, mpi_integer, bigdft_mpi%mpi_comm, ierr)
      else
         call vcopy(orbs%norb,noverlapsarr(1),1,op_noverlaps(1),1)
      end if
      do jproc=0,nproc-1
         recvcnts(jproc)=1
         displs(jproc)=jproc
      end do
      if (nproc > 1) then
         call mpi_allgatherv(noverlaps, 1, mpi_integer, comon_noverlaps, recvcnts, &
              displs, mpi_integer, bigdft_mpi%mpi_comm, ierr)
      else
         comon_noverlaps=noverlaps
      end if
    
      allocate(op_overlaps(maxval(op_noverlaps),orbs%norb), stat=istat)
      call memocc(istat, op_overlaps, 'op_overlaps', subname)
      allocate(overlaps_op(maxval(op_noverlaps),orbs%norbp), stat=istat)
      call memocc(istat, overlaps_op, 'overlaps_op', subname)
      if(orbs%norbp>0) call to_zero(maxval(op_noverlaps)*orbs%norbp,overlaps_op(1,1))
    
      ! Now we know how many overlaps have to be calculated, so determine which orbital overlaps
      ! with which one. This is essentially the same loop as above, but we use the array 'overlapMatrix'
      ! which indicates the overlaps.
    
      ! Initialize to some value which will never be used.
      op_overlaps=-1
    
      iiorb=0
      ilrold=-1
      do iorb=1,orbs%norbp
         ioverlaporb=0 ! counts the overlaps for the given orbital.
         iiorb=orbs%isorb+iorb
         ilr=orbs%inWhichLocreg(iiorb)
         do jorb=1,orbsig%norb
            jlr=orbsig%inWhichLocreg(jorb)
            if(overlapMatrix(jorb,iorb)) then
               ioverlaporb=ioverlaporb+1
               ! Determine the number of segments of the fine grid in the overlap
               call check_overlap_from_descriptors_periodic(lzd%llr(ilr)%wfd%nseg_c, lzdig%llr(jlr)%wfd%nseg_f,&
                    lzd%llr(ilr)%wfd%keyglob(1,1), lzdig%llr(jlr)%wfd%keyglob(1,1+lzdig%llr(jlr)%wfd%nseg_c), &
                    isoverlap, overlaps_nseg(ioverlaporb,iorb,2))
               !op_overlaps(ioverlaporb,iiorb)=jorb
               overlaps_op(ioverlaporb,iorb)=jorb
            end if
         end do 
         ilrold=ilr
      end do
    
    
      displs(0)=0
      recvcnts(0)=comon_noverlaps(0)
      do jproc=1,nproc-1
          recvcnts(jproc)=comon_noverlaps(jproc)
          displs(jproc)=displs(jproc-1)+recvcnts(jproc-1)
      end do
    
      ii=maxval(op_noverlaps)
      displs(0)=0
      recvcnts(0)=ii*orbs%norb_par(0,0)
      do jproc=1,nproc-1
          recvcnts(jproc)=ii*orbs%norb_par(jproc,0)
          displs(jproc)=displs(jproc-1)+recvcnts(jproc-1)
      end do
      if (nproc > 1) then
         call mpi_allgatherv(overlaps_op, ii*orbs%norbp, mpi_integer, op_overlaps, recvcnts, &
              displs, mpi_integer, bigdft_mpi%mpi_comm, ierr)
      else
         call vcopy(ii*orbs%norbp,overlaps_op(1,1),1,op_overlaps(1,1),1)
      end if
    
    
      iall=-product(shape(overlapMatrix))*kind(overlapMatrix)
      deallocate(overlapMatrix, stat=istat)
      call memocc(istat, iall, 'overlapMatrix', subname)
    
      iall=-product(shape(noverlapsarr))*kind(noverlapsarr)
      deallocate(noverlapsarr, stat=istat)
      call memocc(istat, iall, 'noverlapsarr', subname)
    
      iall=-product(shape(overlaps_op))*kind(overlaps_op)
      deallocate(overlaps_op, stat=istat)
      call memocc(istat, iall, 'overlaps_op', subname)
    
      iall=-product(shape(displs))*kind(displs)
      deallocate(displs, stat=istat)
      call memocc(istat, iall, 'displs', subname)
    
      iall=-product(shape(recvcnts))*kind(recvcnts)
      deallocate(recvcnts, stat=istat)
      call memocc(istat, iall, 'recvcnts', subname)
    
      iall=-product(shape(overlaps_nseg))*kind(overlaps_nseg)
      deallocate(overlaps_nseg, stat=istat)
      call memocc(istat, iall, 'overlaps_nseg', subname)
    
      iall=-product(shape(comon_noverlaps))*kind(comon_noverlaps)
      deallocate(comon_noverlaps, stat=istat)
      call memocc(istat, iall, 'comon_noverlaps', subname)
    
    
    end subroutine determine_overlap_from_descriptors




    subroutine init_matrix_parallelization(iproc, nproc, sparsemat)
      use module_base
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc, nproc
      type(sparse_matrix),intent(inout) :: sparsemat
    
      ! Local variables
      integer :: jproc, jorbs, jorbold, ii, jorb, istat
      character(len=*),parameter :: subname='init_matrix_parallelization'
    
      ! parallelization of matrices, following same idea as norb/norbp/isorb
      sparsemat%nvctr_par=f_malloc_ptr((/0.to.nproc-1/),id='sparsemat%nvctr_par')
      sparsemat%isvctr_par=f_malloc_ptr((/0.to.nproc-1/),id='sparsemat%isvctr_par')
    
      !most equal distribution, but want corresponding to norbp for second column
      !call kpts_to_procs_via_obj(nproc,1,sparsemat%nvctr,sparsemat%nvctr_par)
      !sparsemat%nvctrp=sparsemat%nvctr_par(iproc)
      !sparsemat%isvctr=0
      !do jproc=0,iproc-1
      !    sparsemat%isvctr=sparsemat%isvctr+sparsemat%nvctr_par(jproc)
      !end do
      !sparsemat%isvctr_par=0
      !do jproc=0,nproc-1
      !    if(iproc==jproc) then
      !       sparsemat%isvctr_par(jproc)=sparsemat%isvctr
      !    end if
      !end do
      !if(nproc >1) call mpiallred(sparsemat%isvctr_par(0), nproc, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      do jproc=0,nproc-1
         jorbs=sparsemat%isfvctr_par(jproc)+1
         jorbold=0
         do ii=1,sparsemat%nvctr
            jorb = sparsemat%orb_from_index(2,ii)
            if (jorb/=jorbold .and. jorb==jorbs) then
               sparsemat%isvctr_par(jproc)=ii-1
               exit
            end if
            jorbold=jorb
         end do
      end do
      do jproc=0,nproc-1
         if (jproc==nproc-1) then
            sparsemat%nvctr_par(jproc)=sparsemat%nvctr-sparsemat%isvctr_par(jproc)
         else
            sparsemat%nvctr_par(jproc)=sparsemat%isvctr_par(jproc+1)-sparsemat%isvctr_par(jproc)
         end if
         if (iproc==jproc) sparsemat%isvctr=sparsemat%isvctr_par(jproc)
         if (iproc==jproc) sparsemat%nvctrp=sparsemat%nvctr_par(jproc)
      end do
      !do jproc=0,nproc-1
      !   write(*,*) iproc,jproc,sparsemat%isvctr_par(jproc),sparsemat%isvctr,sparsemat%nvctr_par(jproc),sparsemat%nvctrp,sparsemat%nvctr
      !end do
    
      ! 0 - none, 1 - mpiallred, 2 - allgather
      sparsemat%parallel_compression=0
      sparsemat%can_use_dense=.false.
    
    end subroutine init_matrix_parallelization


    subroutine init_indices_in_compressed(store_index, norb, sparsemat)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix
      implicit none
    
      ! Calling arguments
      logical,intent(in) :: store_index
      integer,intent(in) :: norb
      type(sparse_matrix),intent(inout) :: sparsemat
    
      ! Local variables
      !integer :: iorb, jorb, compressed_index, istat
      integer :: iorb, jorb, istat
      character(len=*),parameter :: subname='init_indices_in_compressed'
    
      if (store_index) then
          ! store the indices of the matrices in the sparse format
          sparsemat%store_index=.true.
    
          ! initialize sparsemat%matrixindex_in_compressed
          sparsemat%matrixindex_in_compressed_arr=f_malloc_ptr((/norb,norb/),id='sparsemat%matrixindex_in_compressed_arr')
    
          do iorb=1,norb
             do jorb=1,norb
                sparsemat%matrixindex_in_compressed_arr(iorb,jorb)=compressed_index(iorb,jorb,norb,sparsemat)
             end do
          end do
    
      else
          ! otherwise alwyas calculate them on-the-fly
          sparsemat%store_index=.false.
          nullify(sparsemat%matrixindex_in_compressed_arr)
      end if
    
    end subroutine init_indices_in_compressed


    !> Function that gives the index of the matrix element (jjorb,iiorb) in the compressed format.
    function compressed_index(irow, jcol, norb, sparsemat)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: irow, jcol, norb
      type(sparse_matrix),intent(in) :: sparsemat
      integer :: compressed_index
    
      ! Local variables
      integer :: ii, iseg
    
      ii=(jcol-1)*norb+irow
    
      iseg=sparsemat%istsegline(jcol)
      do
          if (ii>=sparsemat%keyg(1,iseg) .and. ii<=sparsemat%keyg(2,iseg)) then
              ! The matrix element is in this segment
               compressed_index = sparsemat%keyv(iseg) + ii - sparsemat%keyg(1,iseg)
              return
          end if
          iseg=iseg+1
          if (iseg>sparsemat%nseg) exit
          if (ii<sparsemat%keyg(1,iseg)) then
              compressed_index=0
              return
          end if
      end do
    
      ! Not found
      compressed_index=0
    
    end function compressed_index


    integer function matrixindex_in_compressed(sparsemat, iorb, jorb)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix
      implicit none
    
      ! Calling arguments
      type(sparse_matrix),intent(in) :: sparsemat
      integer,intent(in) :: iorb, jorb
    
      ! Local variables
    
      if (sparsemat%store_index) then
          ! Take the value from the array
          matrixindex_in_compressed = sparsemat%matrixindex_in_compressed_arr(iorb,jorb)
      else
          ! Recalculate the value
          matrixindex_in_compressed = compressed_index_fn(iorb, jorb, sparsemat%nfvctr, sparsemat)
      end if
    
      contains
        ! Function that gives the index of the matrix element (jjorb,iiorb) in the compressed format.
        integer function compressed_index_fn(irow, jcol, norb, sparsemat)
          implicit none
        
          ! Calling arguments
          integer,intent(in) :: irow, jcol, norb
          type(sparse_matrix),intent(in) :: sparsemat
        
          ! Local variables
          integer :: ii, iseg
        
          ii=(jcol-1)*norb+irow
        
          iseg=sparsemat%istsegline(jcol)
          do
              if (ii>=sparsemat%keyg(1,iseg) .and. ii<=sparsemat%keyg(2,iseg)) then
                  ! The matrix element is in sparsemat segment
                   compressed_index_fn = sparsemat%keyv(iseg) + ii - sparsemat%keyg(1,iseg)
                  return
              end if
              iseg=iseg+1
              if (iseg>sparsemat%nseg) exit
              if (ii<sparsemat%keyg(1,iseg)) then
                  compressed_index_fn=0
                  return
              end if
          end do
        
          ! Not found
          compressed_index_fn=0
        
        end function compressed_index_fn
    end function matrixindex_in_compressed


    subroutine init_orbs_from_index(sparsemat)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix
      implicit none
    
      ! Calling arguments
      type(sparse_matrix),intent(inout) :: sparsemat
    
      ! local variables
      integer :: ind, iseg, segn, iorb, jorb, istat
      character(len=*),parameter :: subname='init_orbs_from_index'
    
      !allocate(sparsemat%orb_from_index(2,sparsemat%nvctr),stat=istat)
      !call memocc(istat, sparsemat%orb_from_index, 'sparsemat%orb_from_index', subname)
      sparsemat%orb_from_index=f_malloc_ptr((/2,sparsemat%nvctr/),id='sparsemat%orb_from_index')
    
      ind = 0
      do iseg = 1, sparsemat%nseg
         do segn = sparsemat%keyg(1,iseg), sparsemat%keyg(2,iseg)
            ind=ind+1
            iorb = (segn - 1) / sparsemat%nfvctr + 1
            jorb = segn - (iorb-1)*sparsemat%nfvctr
            sparsemat%orb_from_index(1,ind) = jorb
            sparsemat%orb_from_index(2,ind) = iorb
         end do
      end do
    
    end subroutine init_orbs_from_index



    subroutine check_kernel_cutoff(iproc, orbs, atoms, lzd)
      use module_base
      use module_types
      use yaml_output
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: iproc
      type(orbitals_data),intent(in) :: orbs
      type(atoms_data),intent(in) :: atoms
      type(local_zone_descriptors),intent(inout) :: lzd
    
      ! Local variables
      integer :: iorb, ilr, iat, iatype
      real(kind=8) :: cutoff_sf, cutoff_kernel
      character(len=20) :: atomname
      logical :: write_data
      logical,dimension(atoms%astruct%ntypes) :: write_atomtype
    
      write_atomtype=.true.
    
      if (iproc==0) then
          call yaml_open_sequence('check of kernel cutoff radius')
      end if
    
      do iorb=1,orbs%norb
          ilr=orbs%inwhichlocreg(iorb)
    
          ! cutoff radius of the support function, including shamop region
          cutoff_sf=lzd%llr(ilr)%locrad+8.d0*lzd%hgrids(1)
    
          ! cutoff of the density kernel
          cutoff_kernel=lzd%llr(ilr)%locrad_kernel
    
          ! check whether the date for this atomtype has already shoudl been written
          iat=orbs%onwhichatom(iorb)
          iatype=atoms%astruct%iatype(iat)
          if (write_atomtype(iatype)) then
              if (iproc==0) then
                  write_data=.true.
              else
                  write_data=.false.
              end if
              write_atomtype(iatype)=.false.
          else
              write_data=.false.
          end if
    
          ! Adjust if necessary
          if (write_data) then
              call yaml_sequence(advance='no')
              call yaml_open_map(flow=.true.)
              atomname=trim(atoms%astruct%atomnames(atoms%astruct%iatype(iat)))
              call yaml_map('atom type',atomname)
          end if
          if (cutoff_sf>cutoff_kernel) then
              if (write_data) then
                  call yaml_map('adjustment required',.true.)
                  call yaml_map('new value',cutoff_sf,fmt='(f6.2)')
              end if
              lzd%llr(ilr)%locrad_kernel=cutoff_sf
          else
              if (write_data) then
                  call yaml_map('adjustment required',.false.)
              end if
          end if
          if (write_data) then
              call yaml_close_map()
          end if
      end do
    
      if (iproc==0) then
          call yaml_close_sequence
      end if
    
    
    end subroutine check_kernel_cutoff


    subroutine init_sparse_matrix_matrix_multiplication(norb, norbp, isorb, nseg, &
               nsegline, istsegline, keyg, sparsemat)
      use module_base
      implicit none

      ! Calling arguments
      integer,intent(in) :: norb, norbp, isorb, nseg
      integer,dimension(norb),intent(in) :: nsegline, istsegline
      integer,dimension(2,nseg),intent(in) :: keyg
      type(sparse_matrix),intent(inout) :: sparsemat

      call get_nout(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, sparsemat%smmm%nout)
      call determine_sequential_length(norb, norbp, isorb, nseg, &
           nsegline, istsegline, keyg, sparsemat, &
           sparsemat%smmm%nseq, sparsemat%smmm%nmaxsegk, sparsemat%smmm%nmaxvalk)
      call allocate_sparse_matrix_matrix_multiplication(norb, nseg, nsegline, istsegline, keyg, sparsemat%smmm)
      sparsemat%smmm%nseg=nseg
      call vcopy(norb, nsegline(1), 1, sparsemat%smmm%nsegline(1), 1)
      call vcopy(norb, istsegline(1), 1, sparsemat%smmm%istsegline(1), 1)
      call vcopy(2*nseg, keyg(1,1), 1, sparsemat%smmm%keyg(1,1), 1)
      call init_onedimindices_new(norb, norbp, isorb, nseg, &
           nsegline, istsegline, keyg, &
           sparsemat, sparsemat%smmm%nout, sparsemat%smmm%onedimindices)
      call get_arrays_for_sequential_acces(norb, norbp, isorb, nseg, &
           nsegline, istsegline, keyg, sparsemat, &
           sparsemat%smmm%nseq, sparsemat%smmm%nmaxsegk, sparsemat%smmm%nmaxvalk, &
           sparsemat%smmm%ivectorindex)
      call init_sequential_acces_matrix(norb, norbp, isorb, nseg, &
           nsegline, istsegline, keyg, sparsemat, sparsemat%smmm%nseq, &
           sparsemat%smmm%nmaxsegk, sparsemat%smmm%nmaxvalk, &
           sparsemat%smmm%indices_extract_sequential)
    end subroutine init_sparse_matrix_matrix_multiplication


    subroutine nseg_perline(norb, lut, nseg, nvctr, nsegline)
      implicit none

      ! Calling arguments
      integer,intent(in) :: norb
      logical,dimension(norb),intent(in) :: lut
      integer,intent(out) :: nseg, nvctr, nsegline

      ! Local variables
      integer :: jorb
      logical :: segment_started, newline, overlap

      ! Always start a new segment for each line
      segment_started=.false.
      nsegline=0
      newline=.true.
      do jorb=1,norb
          overlap=lut(jorb)
          if (overlap) then
              if (segment_started) then
                  ! there is no "hole" in between, i.e. we are in the same segment
                  nvctr=nvctr+1
              else
                  ! there was a "hole" in between, i.e. we are in a new segment
                  nseg=nseg+1
                  nsegline=nsegline+1
                  nvctr=nvctr+1
                  newline=.false.
              end if
              segment_started=.true.
          else
              segment_started=.false.
          end if
      end do

    end subroutine nseg_perline


    subroutine keyg_per_line(norb, nseg, iline, istseg, lut, ivctr, keyg)
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: norb, nseg, iline, istseg
      logical,dimension(norb),intent(in) :: lut
      integer,intent(inout) :: ivctr
      integer,dimension(2,nseg),intent(out) :: keyg
      
      ! Local variables
      integer :: iseg, jorb, ijorb
      logical :: segment_started, overlap

      ! Always start a new segment for each line
      segment_started=.false.
      !iseg=sparsemat%istsegline(iline)-1
      iseg=istseg-1
      do jorb=1,norb
          overlap=lut(jorb)
          ijorb=(iline-1)*norb+jorb
          if (overlap) then
              if (segment_started) then
                  ! there is no "hole" in between, i.e. we are in the same segment
                  ivctr=ivctr+1
              else
                  ! there was a "hole" in between, i.e. we are in a new segment.
                  iseg=iseg+1
                  ivctr=ivctr+1
                  ! open the current segment
                  keyg(1,iseg)=ijorb
              end if
              segment_started=.true.
          else
              if (segment_started) then
                  ! close the previous segment
                  keyg(2,iseg)=ijorb-1
              end if
              segment_started=.false.
          end if
      end do
      ! close the last segment on the line if necessary
      if (segment_started) then
          keyg(2,iseg)=iline*norb
      end if
    end subroutine keyg_per_line



    !> Currently assuming square matrices
    subroutine init_sparse_matrix(iproc, nproc, norb, norbp, isorb, store_index, &
               nnonzero, nonzero, nnonzero_mult, nonzero_mult, sparsemat, &
               allocate_full_)
      use module_base
      use yaml_output
      implicit none
      
      ! Calling arguments
      integer,intent(in) :: iproc, nproc, norb, norbp, isorb, nnonzero, nnonzero_mult
      logical,intent(in) :: store_index
      integer,dimension(nnonzero),intent(in) :: nonzero
      integer,dimension(nnonzero_mult),intent(in) :: nonzero_mult
      type(sparse_matrix), intent(out) :: sparsemat
      logical,intent(in),optional :: allocate_full_
      
      ! Local variables
      integer :: jproc, iorb, jorb, iiorb, iseg, ilr, segn, ind
      integer :: ierr, jorbs, jorbold, ii, jst_line, jst_seg
      integer :: matrixindex_in_compressed, ist, ivctr
      logical,dimension(:),allocatable :: lut
      integer :: nseg_mult, nvctr_mult, ivctr_mult
      integer,dimension(:),allocatable :: nsegline_mult, istsegline_mult
      integer,dimension(:,:),allocatable :: keyg_mult
      logical :: allocate_full
      
      call timing(iproc,'init_matrCompr','ON')

      call set_value_from_optional()

      lut = f_malloc(norb,id='lut')
    
      sparsemat=sparse_matrix_null()
    
      sparsemat%nfvctr=norb
      sparsemat%nfvctrp=norbp
      sparsemat%isfvctr=isorb
      sparsemat%nfvctr_par=f_malloc_ptr((/0.to.nproc-1/),id='sparsemat%nfvctr_par')
      sparsemat%isfvctr_par=f_malloc_ptr((/0.to.nproc-1/),id='sparsemat%isfvctr_par')

      ! Same as isorb_par and norb_par
      call to_zero(nproc, sparsemat%nfvctr_par(0))
      call to_zero(nproc, sparsemat%isfvctr_par(0))
      do jproc=0,nproc-1
          if (iproc==jproc) then
              sparsemat%isfvctr_par(jproc)=isorb
              sparsemat%nfvctr_par(jproc)=norbp
          end if
      end do
      call mpiallred(sparsemat%isfvctr_par(0), nproc, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      call mpiallred(sparsemat%nfvctr_par(0), nproc, mpi_sum, bigdft_mpi%mpi_comm, ierr)

      call allocate_sparse_matrix_basic(store_index, norb, nproc, sparsemat)
    

      sparsemat%nseg=0
      sparsemat%nvctr=0
      sparsemat%nsegline=0
      do iorb=1,norbp
          iiorb=isorb+iorb
          call create_lookup_table(nnonzero, nonzero, iiorb)
          call nseg_perline(norb, lut, sparsemat%nseg, sparsemat%nvctr, sparsemat%nsegline(iiorb))
      end do

      call mpiallred(sparsemat%nvctr, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      call mpiallred(sparsemat%nseg, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      call mpiallred(sparsemat%nsegline(1), sparsemat%nfvctr, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      ist=1
      do jorb=1,sparsemat%nfvctr
          ! Starting segment for this line
          sparsemat%istsegline(jorb)=ist
          ist=ist+sparsemat%nsegline(jorb)
      end do

    
      if (iproc==0) then
          call yaml_map('total elements',norb**2)
          call yaml_map('non-zero elements',sparsemat%nvctr)
          call yaml_map('sparsity in %',1.d2*dble(norb**2-sparsemat%nvctr)/dble(norb**2),fmt='(f5.2)')
      end if
    
      call allocate_sparse_matrix_keys(sparsemat)
    


      ivctr=0
      sparsemat%keyg=0
      do iorb=1,norbp
          iiorb=isorb+iorb
          call create_lookup_table(nnonzero, nonzero, iiorb)
          call keyg_per_line(norb, sparsemat%nseg, iiorb, sparsemat%istsegline(iiorb), &
               lut, ivctr, sparsemat%keyg)
      end do
    
      ! check whether the number of elements agrees
      call mpiallred(ivctr, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      if (ivctr/=sparsemat%nvctr) then
          write(*,'(a,2i8)') 'ERROR: ivctr/=sparsemat%nvctr', ivctr, sparsemat%nvctr
          stop
      end if
      call mpiallred(sparsemat%keyg(1,1), 2*sparsemat%nseg, mpi_sum, bigdft_mpi%mpi_comm, ierr)


      ! start of the segments
      sparsemat%keyv(1)=1
      do iseg=2,sparsemat%nseg
          sparsemat%keyv(iseg) = sparsemat%keyv(iseg-1) + sparsemat%keyg(2,iseg-1) - sparsemat%keyg(1,iseg-1) + 1
      end do

    
    
      if (store_index) then
          ! store the indices of the matrices in the sparse format
          sparsemat%store_index=.true.
    
          ! initialize sparsemat%matrixindex_in_compressed
          do iorb=1,norb
             do jorb=1,norb
                sparsemat%matrixindex_in_compressed_arr(iorb,jorb)=compressed_index(iorb,jorb,norb,sparsemat)
             end do
          end do
    
      else
          ! Otherwise alwyas calculate them on-the-fly
          sparsemat%store_index=.false.
      end if
    
      ind = 0
      do iseg = 1, sparsemat%nseg
         do segn = sparsemat%keyg(1,iseg), sparsemat%keyg(2,iseg)
            ind=ind+1
            iorb = (segn - 1) / sparsemat%nfvctr + 1
            jorb = segn - (iorb-1)*sparsemat%nfvctr
            sparsemat%orb_from_index(1,ind) = jorb
            sparsemat%orb_from_index(2,ind) = iorb
         end do
      end do
    
      ! parallelization of matrices, following same idea as norb/norbp/isorb
    
      !most equal distribution, but want corresponding to norbp for second column


      do jproc=0,nproc-1
          jst_line = sparsemat%isfvctr_par(jproc)+1
          jst_seg = sparsemat%istsegline(jst_line)
          sparsemat%isvctr_par(jproc) = sparsemat%keyv(jst_seg)-1
      end do
      do jproc=0,nproc-1
         if (jproc==nproc-1) then
            sparsemat%nvctr_par(jproc)=sparsemat%nvctr-sparsemat%isvctr_par(jproc)
         else
            sparsemat%nvctr_par(jproc)=sparsemat%isvctr_par(jproc+1)-sparsemat%isvctr_par(jproc)
         end if
         if (iproc==jproc) sparsemat%isvctr=sparsemat%isvctr_par(jproc)
         if (iproc==jproc) sparsemat%nvctrp=sparsemat%nvctr_par(jproc)
      end do

    
      ! 0 - none, 1 - mpiallred, 2 - allgather
      sparsemat%parallel_compression=0
      sparsemat%can_use_dense=.false.


      nsegline_mult = f_malloc0(norb,id='nsegline_mult')
      istsegline_mult = f_malloc(norb,id='istsegline_mult')
      nseg_mult=0
      nvctr_mult=0
      do iorb=1,norbp
          iiorb=isorb+iorb
          call create_lookup_table(nnonzero_mult, nonzero_mult, iiorb)
          call nseg_perline(norb, lut, nseg_mult, nvctr_mult, nsegline_mult(iiorb))
      end do
      call mpiallred(nvctr_mult, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      call mpiallred(nseg_mult, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      call mpiallred(nsegline_mult(1), norb, mpi_sum, bigdft_mpi%mpi_comm, ierr)



      ! Initialize istsegline, which gives the first segment of each line
      istsegline_mult(1)=1
      do iorb=2,norb
          istsegline_mult(iorb) = istsegline_mult(iorb-1) + nsegline_mult(iorb-1)
      end do

      keyg_mult = f_malloc0((/2,nseg_mult/),id='keyg_mult')

      ivctr_mult=0
      do iorb=1,norbp
         iiorb=isorb+iorb
         call create_lookup_table(nnonzero_mult, nonzero_mult, iiorb)
         call keyg_per_line(norb, nseg_mult, iiorb, istsegline_mult(iiorb), &
              lut, ivctr_mult, keyg_mult)
      end do
      ! check whether the number of elements agrees
      call mpiallred(ivctr_mult, 1, mpi_sum, bigdft_mpi%mpi_comm, ierr)
      if (ivctr_mult/=nvctr_mult) then
          write(*,'(a,2i8)') 'ERROR: ivctr_mult/=nvctr_mult', ivctr_mult, nvctr_mult
          stop
      end if
      call mpiallred(keyg_mult(1,1), 2*nseg_mult, mpi_sum, bigdft_mpi%mpi_comm, ierr)


      ! Allocate the matrices
      call allocate_sparse_matrix_matrices(sparsemat, allocate_full)


      ! Initialize the parameters for the spare matrix matrix multiplication
      call init_sparse_matrix_matrix_multiplication(norb, norbp, isorb, nseg_mult, &
               nsegline_mult, istsegline_mult, keyg_mult, sparsemat)

      call f_free(nsegline_mult)
      call f_free(istsegline_mult)
      call f_free(keyg_mult)
      call f_free(lut)
    
      call timing(iproc,'init_matrCompr','OF')



      contains

        subroutine create_lookup_table(nnonzero, nonzero, iiorb)
          implicit none

          ! Calling arguments
          integer :: nnonzero, iiorb
          integer,dimension(nnonzero) :: nonzero

          ! Local variables
          integer :: ist, iend, i, jjorb

          lut = .false.
          ist=(iiorb-1)*norb+1
          iend=iiorb*norb
          do i=1,nnonzero
              if (nonzero(i)<ist) cycle
              if (nonzero(i)>iend) exit
              jjorb=mod(nonzero(i)-1,norb)+1
              lut(jjorb)=.true.
          end do
        end subroutine create_lookup_table


        subroutine set_value_from_optional()
          if (present(allocate_full_))then
              allocate_full = allocate_full_
          else
              allocate_full = .false.
          end if
        end subroutine set_value_from_optional


    
    end subroutine init_sparse_matrix


    subroutine determine_sequential_length(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, &
               sparsemat, nseq, nmaxsegk, nmaxvalk)
      use module_base
      use module_types
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: norb, norbp, isorb, nseg
      integer,dimension(norb),intent(in) :: nsegline, istsegline
      integer,dimension(2,nseg),intent(in) :: keyg
      type(sparse_matrix),intent(in) :: sparsemat
      integer,intent(out) :: nseq, nmaxsegk, nmaxvalk
    
      ! Local variables
      integer :: i,iseg,jorb,iorb,jseg,ii
      integer :: isegoffset, istart, iend
    
      nseq=0
      nmaxsegk=0
      nmaxvalk=0
      do i = 1,norbp
         ii=isorb+i
         nmaxsegk=max(nmaxsegk,nsegline(ii))
         isegoffset=istsegline(ii)-1
         do iseg=1,nsegline(ii)
              istart=keyg(1,isegoffset+iseg)
              iend=keyg(2,isegoffset+iseg)
              ! keyg is defined in terms of "global coordinates", so get the
              ! coordinate on a given line by using the mod function
              istart=mod(istart-1,norb)+1
              iend=mod(iend-1,norb)+1
              nmaxvalk=max(nmaxvalk,iend-istart+1)
              do iorb=istart,iend
                  do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                      do jorb = sparsemat%keyg(1,jseg),sparsemat%keyg(2,jseg)
                          nseq=nseq+1
                      end do
                  end do
              end do
         end do
      end do 
    
    end subroutine determine_sequential_length


    subroutine get_nout(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, nout)
      use module_base
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: norb, norbp, isorb, nseg
      integer,dimension(norb),intent(in) :: nsegline, istsegline
      integer,dimension(2,nseg),intent(in) :: keyg
      integer,intent(out) :: nout
    
      ! Local variables
      integer :: i, iii, iseg, iorb, ii
      integer :: isegoffset, istart, iend
    
      nout=0
      do i = 1,norbp
         iii=isorb+i
         isegoffset=istsegline(iii)-1
         do iseg=1,nsegline(iii)
              istart=keyg(1,isegoffset+iseg)
              iend=keyg(2,isegoffset+iseg)
              do iorb=istart,iend
                  nout=nout+1
              end do
          end do
      end do
    
    end subroutine get_nout


    subroutine init_onedimindices_new(norb, norbp, isorb, nseg, nsegline, istsegline, keyg, sparsemat, nout, onedimindices)
      use module_base
      use sparsematrix_base, only: sparse_matrix
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: norb, norbp, isorb, nseg
      integer,dimension(norb),intent(in) :: nsegline, istsegline
      integer,dimension(2,nseg),intent(in) :: keyg
      type(sparse_matrix),intent(in) :: sparsemat
      integer,intent(in) :: nout
      integer,dimension(4,nout) :: onedimindices
    
      ! Local variables
      integer :: i, iii, iseg, iorb, ii, jseg, ilen, itot
      integer :: isegoffset, istart, iend
    
    
      ii=0
      itot=1
      do i = 1,norbp
         iii=isorb+i
         isegoffset=istsegline(iii)-1
         do iseg=1,nsegline(iii)
              istart=keyg(1,isegoffset+iseg)
              iend=keyg(2,isegoffset+iseg)
              ! keyg is defined in terms of "global coordinates", so get the
              ! coordinate on a given line by using the mod function
              istart=mod(istart-1,norb)+1
              iend=mod(iend-1,norb)+1
              do iorb=istart,iend
                  ii=ii+1
                  onedimindices(1,ii)=i
                  onedimindices(2,ii)=iorb
                  ilen=0
                  do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                      ilen=ilen+sparsemat%keyg(2,jseg)-sparsemat%keyg(1,jseg)+1
                  end do
                  onedimindices(3,ii)=ilen
                  onedimindices(4,ii)=itot
                  itot=itot+ilen
              end do
          end do
      end do
    
    end subroutine init_onedimindices_new


    subroutine get_arrays_for_sequential_acces(norb, norbp, isorb, nseg, &
               nsegline, istsegline, keyg, sparsemat, nseq, nmaxsegk, nmaxvalk, &
               ivectorindex)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: norb, norbp, isorb, nseg, nseq, nmaxsegk, nmaxvalk
      integer,dimension(norb),intent(in) :: nsegline, istsegline
      integer,dimension(2,nseg),intent(in) :: keyg
      type(sparse_matrix),intent(in) :: sparsemat
      integer,dimension(nseq),intent(out) :: ivectorindex
    
      ! Local variables
      integer :: i,iseg,jorb,jjorb,iorb,jseg,ii,iii
      integer :: isegoffset, istart, iend
    
    
      ii=1
      do i = 1,norbp
         iii=isorb+i
         isegoffset=istsegline(iii)-1
         do iseg=1,nsegline(iii)
              istart=keyg(1,isegoffset+iseg)
              iend=keyg(2,isegoffset+iseg)
              ! keyg is defined in terms of "global coordinates", so get the
              ! coordinate on a given line by using the mod function
              istart=mod(istart-1,norb)+1
              iend=mod(iend-1,norb)+1
              do iorb=istart,iend
                  !!istindexarr(iorb-istart+1,iseg,i)=ii
                  do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                      do jorb = sparsemat%keyg(1,jseg),sparsemat%keyg(2,jseg)
                          jjorb = jorb - (iorb-1)*norb
                          ivectorindex(ii)=jjorb
                          ii = ii+1
                      end do
                  end do
              end do
         end do
      end do 
    
    end subroutine get_arrays_for_sequential_acces


    subroutine init_sequential_acces_matrix(norb, norbp, isorb, nseg, &
               nsegline, istsegline, keyg, sparsemat, nseq, nmaxsegk, nmaxvalk, &
               indices_extract_sequential)
      use module_base
      use module_types
      use sparsematrix_base, only: sparse_matrix
      implicit none
    
      ! Calling arguments
      integer,intent(in) :: norb, norbp, isorb, nseg, nseq, nmaxsegk, nmaxvalk
      integer,dimension(norb),intent(in) :: nsegline, istsegline
      integer,dimension(2,nseg),intent(in) :: keyg
      type(sparse_matrix),intent(in) :: sparsemat
      integer,dimension(nseq),intent(out) :: indices_extract_sequential
    
      ! Local variables
      integer :: i,iseg,jorb,jj,iorb,jseg,ii,iii
      integer :: isegoffset, istart, iend
    
    
      ii=1
      do i = 1,norbp
         iii=isorb+i
         isegoffset=istsegline(iii)-1
         do iseg=1,nsegline(iii)
              istart=keyg(1,isegoffset+iseg)
              iend=keyg(2,isegoffset+iseg)
              ! keyg is defined in terms of "global coordinates", so get the
              ! coordinate on a given line by using the mod function
              istart=mod(istart-1,norb)+1
              iend=mod(iend-1,norb)+1
              do iorb=istart,iend
                  do jseg=sparsemat%istsegline(iorb),sparsemat%istsegline(iorb)+sparsemat%nsegline(iorb)-1
                      jj=1
                      do jorb = sparsemat%keyg(1,jseg),sparsemat%keyg(2,jseg)
                          indices_extract_sequential(ii)=sparsemat%keyv(jseg)+jj-1
                          jj = jj+1
                          ii = ii+1
                      end do
                  end do
              end do
         end do
      end do 
    
    end subroutine init_sequential_acces_matrix



end module sparsematrix_init
