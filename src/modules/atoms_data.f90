!> @file
!! Routines associated to the generation of data for atoms of the system
!! @author
!!    Copyright (C) 2007-2014 BigDFT group
!!    This file is distributed under the terms of the
!!    GNU General Public License, see ~/COPYING file
!!    or http://www.gnu.org/copyleft/gpl.txt .
!!    For the list of contributors, see ~/AUTHORS


!> Handling of input guess creation from basis of atomic orbitals
!! and also pseudopotentials
module module_atoms
  use module_defs, only: dp,gp
  use ao_inguess, only: aoig_data
  implicit none
  private

  !> Source of the radii coefficients
  integer, parameter, public :: RADII_SOURCE_HARD_CODED = 1
  integer, parameter, public :: RADII_SOURCE_FILE = 2
  integer, parameter, public :: RADII_SOURCE_USER = 3
  integer, parameter, public :: RADII_SOURCE_UNKNOWN = 4
  character(len=*), dimension(4), parameter, public :: RADII_SOURCE = (/ "Hard-Coded  ", &
                                                                         "PSP File    ", &
                                                                         "User defined", &
                                                                         "Unknown     " /)

  !> Quantities used for the symmetry operators. To be used in atomic_structure derived type.
  type, public :: symmetry_data
     integer :: symObj                             !< The symmetry object from ABINIT
     integer :: nSym                               !< Number of symmetry (0 if disable)
     character(len=15) :: spaceGroup               !< Space group (disabled if not useful)
     integer, dimension(:,:,:), pointer :: irrzon
     real(dp), dimension(:,:,:), pointer :: phnons
  end type symmetry_data
  
  !>Structure of the system. This derived type contains the information about the physical properties
  type, public :: atomic_structure
     character(len=1) :: geocode          !< @copydoc poisson_solver::doc::geocode
     character(len=5) :: inputfile_format !< Can be xyz, ascii or yaml
     character(len=20) :: units           !< Can be angstroem or bohr 
     character(len=20) :: angle           !< Can be radian or degree
     integer :: nat                       !< Number of atoms
     integer :: ntypes                    !< Number of atomic species in the structure
     real(gp), dimension(3) :: cell_dim   !< Dimensions of the simulation domain (each one periodic or free according to geocode)
     !pointers
     real(gp), dimension(:,:), pointer :: rxyz             !< Atomic positions (always in AU, units variable is considered for I/O only)
     real(gp), dimension(:,:), pointer :: rxyz_int         !< Atomic positions in internal coordinates (Z matrix)
     integer, dimension(:,:), pointer :: ixyz_int          !< Neighbor list for internal coordinates (Z matrix)
     character(len=20), dimension(:), pointer :: atomnames !< Atomic species names
     integer, dimension(:), pointer :: iatype              !< Atomic species id
     integer, dimension(:), pointer :: ifrztyp             !< Freeze atoms while updating structure
     integer, dimension(:), pointer :: input_polarization  !< Used in AO generation for WFN input guess
     type(symmetry_data) :: sym                            !< The symmetry operators
  end type atomic_structure

  !> Data containing the information about the atoms in the system
  type, public :: atoms_data
     type(atomic_structure) :: astruct                   !< Atomic structure (positions and so on)
     type(aoig_data), dimension(:), pointer :: aoig      !< Contains the information needed for generating the AO inputguess data for each atom
     integer :: natsc                                    !< Number of atoms with semicore occupations at the input guess
!     integer, dimension(:), pointer :: iasctype
     integer, dimension(:), pointer :: nelpsp
     integer, dimension(:), pointer :: npspcode          !< PSP codes (see @link psp_projectors::pspcode_hgh @endlink)
     integer, dimension(:), pointer :: ixcpsp            !< PSP ixc code
     integer, dimension(:), pointer :: nzatom            !< Atomic number
     integer, dimension(:), pointer :: iradii_source     !< Source of the radii coefficients (Hard-Coded, PSP File, ...)
     real(gp), dimension(:,:), pointer :: radii_cf       !< User defined radii_cf, overridden in sysprop.f90
     real(gp), dimension(:), pointer :: amu              !< Amu(ntypes)  Atomic Mass Unit for each type of atoms
     !real(gp), dimension(:,:), pointer :: rloc          !< Localization regions for parameters of linear, to be moved somewhere else
     real(gp), dimension(:,:,:), pointer :: psppar       !< Pseudopotential parameters (HGH SR section)
     logical :: donlcc                                   !< Activate non-linear core correction treatment
     logical :: multipole_preserving                     !< Activate preservation of the multipole moment for the ionic charge
     integer, dimension(:), pointer :: nlcc_ngv,nlcc_ngc !< Number of valence and core gaussians describing NLCC 
     real(gp), dimension(:,:), pointer :: nlccpar        !< Parameters for the non-linear core correction, if present
!     real(gp), dimension(:,:), pointer :: ig_nlccpar    !< Parameters for the input NLCC

     !! for abscalc with pawpatch
     integer, dimension(:), pointer ::  paw_NofL, paw_l, paw_nofchannels
     integer, dimension(:), pointer ::  paw_nofgaussians
     real(gp), dimension(:), pointer :: paw_Greal, paw_Gimag, paw_Gcoeffs
     real(gp), dimension(:), pointer :: paw_H_matrices, paw_S_matrices, paw_Sm1_matrices
     integer :: iat_absorber 
  end type atoms_data

  public :: atoms_data_null,nullify_atoms_data,deallocate_atoms_data
  public :: atomic_structure_null,nullify_atomic_structure,deallocate_atomic_structure
  public :: deallocate_symmetry_data,set_symmetry_data
  public :: set_astruct_from_file
  public :: allocate_atoms_data

  contains

    !> Creators and destructors
    pure function symmetry_data_null() result(sym)
      implicit none
      type(symmetry_data) :: sym
      call nullify_symmetry_data(sym)
    end function symmetry_data_null
    pure subroutine nullify_symmetry_data(sym)
      type(symmetry_data), intent(out) :: sym
      sym%symObj=-1
      nullify(sym%irrzon)
      nullify(sym%phnons)
    end subroutine nullify_symmetry_data

    pure function atomic_structure_null() result(astruct)
      implicit none
      type(atomic_structure) :: astruct
      call nullify_atomic_structure(astruct)
    end function atomic_structure_null
    pure subroutine nullify_atomic_structure(astruct)
      implicit none
      type(atomic_structure), intent(out) :: astruct
      astruct%geocode='X'
      astruct%inputfile_format=repeat(' ',len(astruct%inputfile_format))
      astruct%units=repeat(' ',len(astruct%units))
      astruct%angle=repeat(' ',len(astruct%angle))
      astruct%nat=-1
      astruct%ntypes=-1
      astruct%cell_dim=0.0_gp
      nullify(astruct%input_polarization)
      nullify(astruct%ifrztyp)
      nullify(astruct%atomnames)
      nullify(astruct%iatype)
      nullify(astruct%rxyz)
      call nullify_symmetry_data(astruct%sym)
    end subroutine nullify_atomic_structure


    !> Nullify atoms_data structure
    pure function atoms_data_null() result(at)
      type(atoms_data) :: at
      call nullify_atoms_data(at)
    end function atoms_data_null


    pure subroutine nullify_atoms_data(at)
      implicit none
      type(atoms_data), intent(out) :: at
      call nullify_atomic_structure(at%astruct)
      nullify(at%aoig)
      at%natsc=0
      at%donlcc=.false.
      at%multipole_preserving=.false.
      at%iat_absorber=-1
      !     nullify(at%iasctype)
      nullify(at%nelpsp)
      nullify(at%npspcode)
      nullify(at%ixcpsp)
      nullify(at%nzatom)
      nullify(at%radii_cf)
      nullify(at%iradii_source)
      nullify(at%amu)
      !     nullify(at%aocc)
      !nullify(at%rloc)
      nullify(at%psppar)
      nullify(at%nlcc_ngv)
      nullify(at%nlcc_ngc)
      nullify(at%nlccpar)
      nullify(at%paw_NofL)
      nullify(at%paw_l)
      nullify(at%paw_nofchannels)
      nullify(at%paw_nofgaussians)
      nullify(at%paw_Greal)
      nullify(at%paw_Gimag)
      nullify(at%paw_Gcoeffs)
      nullify(at%paw_H_matrices)
      nullify(at%paw_S_matrices)
      nullify(at%paw_Sm1_matrices)
    end subroutine nullify_atoms_data


    !> Destructor of symmetry data operations
    subroutine deallocate_symmetry_data(sym)
      use dynamic_memory, only: f_free_ptr
      use m_ab6_symmetry, only: symmetry_free
      implicit none
      type(symmetry_data), intent(inout) :: sym
      !character(len = *), intent(in) :: subname
!      integer :: i_stat, i_all

      if (sym%symObj >= 0) then
         call symmetry_free(sym%symObj)
      end if
      call f_free_ptr(sym%irrzon)
      call f_free_ptr(sym%phnons)
    end subroutine deallocate_symmetry_data

    !> Deallocate the structure atoms_data.
    subroutine deallocate_atomic_structure(astruct)!,subname) 
      use dynamic_memory, only: f_free_ptr
      use module_base, only: memocc
      implicit none
      !character(len=*), intent(in) :: subname
      type(atomic_structure), intent(inout) :: astruct
      !local variables
      character(len=*), parameter :: subname='deallocate_atomic_structure' !remove
      integer :: i_stat, i_all


      ! Deallocations for the geometry part.
      if (astruct%nat >= 0) then
         call f_free_ptr(astruct%ifrztyp)
         call f_free_ptr(astruct%iatype)
         call f_free_ptr(astruct%input_polarization)
         call f_free_ptr(astruct%rxyz)
         call f_free_ptr(astruct%rxyz_int)
         call f_free_ptr(astruct%ixyz_int)
      end if
      if (astruct%ntypes >= 0) then
          if (associated(astruct%atomnames)) then
             i_all=-product(shape(astruct%atomnames))*kind(astruct%atomnames)
             deallocate(astruct%atomnames, stat=i_stat)
             call memocc(i_stat, i_all, 'astruct%atomnames', subname)
          end if
      end if
      ! Free additional stuff.
      call deallocate_symmetry_data(astruct%sym)

    END SUBROUTINE deallocate_atomic_structure

    !> Deallocate the structure atoms_data.
    subroutine deallocate_atoms_data(atoms) 
      use module_base
      use dynamic_memory
      implicit none
      type(atoms_data), intent(inout) :: atoms
      !local variables
      character(len=*), parameter :: subname='dellocate_atoms_data' !remove

      ! Deallocate atomic structure
      call deallocate_atomic_structure(atoms%astruct) 

      ! Deallocations related to pseudos.
      if (associated(atoms%nzatom)) then
         call f_free_ptr(atoms%nzatom)
         call f_free_ptr(atoms%psppar)
         call f_free_ptr(atoms%nelpsp)
         call f_free_ptr(atoms%ixcpsp)
         call f_free_ptr(atoms%npspcode)
         call f_free_ptr(atoms%nlcc_ngv)
         call f_free_ptr(atoms%nlcc_ngc)
         call f_free_ptr(atoms%radii_cf)
         call f_free_ptr(atoms%iradii_source)
         call f_free_ptr(atoms%amu)
      end if
      if (associated(atoms%aoig)) then
         !no flib calls for derived types for the moment
         deallocate(atoms%aoig)
         nullify(atoms%aoig)
      end if
         call f_free_ptr(atoms%nlccpar)

      !  Free data for pawpatch
      if(associated(atoms%paw_l)) then
         call f_free_ptr(atoms%paw_l)
      end if
      if(associated(atoms%paw_NofL)) then
         call f_free_ptr(atoms%paw_NofL)
      end if
      if(associated(atoms%paw_nofchannels)) then
         call f_free_ptr(atoms%paw_nofchannels)
      end if
      if(associated(atoms%paw_nofgaussians)) then
         call f_free_ptr(atoms%paw_nofgaussians)
      end if
      if(associated(atoms%paw_Greal)) then
         call f_free_ptr(atoms%paw_Greal)
      end if
      if(associated(atoms%paw_Gimag)) then
         call f_free_ptr(atoms%paw_Gimag)
      end if
      if(associated(atoms%paw_Gcoeffs)) then
         call f_free_ptr(atoms%paw_Gcoeffs)
      end if
      if(associated(atoms%paw_H_matrices)) then
         call f_free_ptr(atoms%paw_H_matrices)
      end if
      if(associated(atoms%paw_S_matrices)) then
         call f_free_ptr(atoms%paw_S_matrices)
      end if
      if(associated(atoms%paw_Sm1_matrices)) then
         call f_free_ptr(atoms%paw_Sm1_matrices)
      end if

    END SUBROUTINE deallocate_atoms_data

    !> set irreductible Brillouin zone
    subroutine set_symmetry_data(sym, geocode, n1i, n2i, n3i, nspin)
      use module_base
      use m_ab6_kpoints
      use m_ab6_symmetry
      implicit none
      type(symmetry_data), intent(inout) :: sym
      integer, intent(in) :: n1i, n2i, n3i, nspin
      character, intent(in) :: geocode !< @copydoc poisson_solver::doc::geocode

      character(len = *), parameter :: subname = "symmetry_set_irreductible_zone"
      integer :: i_stat, nsym, i_third
!!$      integer :: i_all
      integer, dimension(:,:,:), allocatable :: irrzon
      real(dp), dimension(:,:,:), allocatable :: phnons

      call f_free_ptr(sym%irrzon)
      call f_free_ptr(sym%phnons)


      if (sym%symObj >= 0) then
         call symmetry_get_n_sym(sym%symObj, nsym, i_stat)
         if (nsym > 1) then
            ! Current third dimension is set to 1 always
            ! since nspin == nsppol always in BigDFT
            i_third = 1
            if (geocode == "S") i_third = n2i
            sym%irrzon=f_malloc_ptr((/n1i*(n2i - i_third + 1)*n3i,2,i_third/),id='sym%irrzon')
            sym%phnons=f_malloc_ptr((/2,n1i*(n2i - i_third + 1)*n3i,i_third/),id='sym%phnons')
            if (geocode /= "S") then
               call kpoints_get_irreductible_zone(sym%irrzon, sym%phnons, &
                    &   n1i, n2i, n3i, nspin, nspin, sym%symObj, i_stat)
            else
               irrzon=f_malloc((/n1i*n3i,2,1/),id='irrzon')
               phnons=f_malloc((/2,n1i*n3i,1/),id='phnons')
               do i_third = 1, n2i, 1
                  call kpoints_get_irreductible_zone(irrzon, phnons, n1i, 1, n3i, &
                       & nspin, nspin, sym%symObj, i_stat)
                  sym%irrzon(:,:,i_third:i_third) = irrzon
                  call vcopy(2*n1i*n3i, phnons(1,1,1), 1, sym%phnons(1,1,i_third), 1)
               end do
               call f_free(irrzon)
               call f_free(phnons)
            end if
         end if
      end if

      if (.not. associated(sym%irrzon)) then
         ! Allocate anyway to small size otherwise the bounds check does not pass.
         sym%irrzon=f_malloc_ptr((/1,2,1/),id='sym%irrzon')
         sym%phnons=f_malloc_ptr((/2,1,1/),id='sym%phnons')
      end if
    END SUBROUTINE set_symmetry_data


    ! allocations, and setters


    !> Read atomic file
    subroutine set_astruct_from_file(file,iproc,astruct,status,comment,energy,fxyz)
      use module_base
      use m_ab6_symmetry
      use dynamic_memory
      use internal_coordinates, only: internal_to_cartesian
      !use position_files
      implicit none
      !Arguments
      character(len=*), intent(in) :: file  !< File name containing the atomic positions
      integer, intent(in) :: iproc
      type(atomic_structure), intent(inout) :: astruct !< Contains all info
      integer, intent(out), optional :: status
      real(gp), intent(out), optional :: energy
      real(gp), dimension(:,:), pointer, optional :: fxyz
      character(len = *), intent(out), optional :: comment
      !Local variables
      character(len=*), parameter :: subname='read_atomic_file'
      integer :: l, extract, i_stat
      logical :: file_exists, archive
      character(len = 128) :: filename
      character(len = 15) :: arFile
      character(len = 6) :: ext
      real(gp) :: energy_
      real(gp), dimension(:,:), pointer :: fxyz_
      character(len = 1024) :: comment_
      external :: openNextCompress, check_atoms_positions
      real(gp),parameter :: degree = 57.295779513d0

      file_exists = .false.
      archive = .false.
      if (present(status)) status = 0
      nullify(fxyz_)

      ! Extract from archive (posout_)
      if (index(file, "posout_") == 1 .or. index(file, "posmd_") == 1) then
         write(arFile, "(A)") "posout.tar.bz2"
         if (index(file, "posmd_") == 1) write(arFile, "(A)") "posmd.tar.bz2"
         inquire(FILE = trim(arFile), EXIST = file_exists)
         if (file_exists) then
!!$     call extractNextCompress(trim(arFile), len(trim(arFile)), &
!!$          & trim(file), len(trim(file)), extract, ext)
            call openNextCompress(trim(arFile), len(trim(arFile)), &
                 & trim(file), len(trim(file)), extract, ext)
            if (extract == 0) then
               write(*,*) "Can't find '", file, "' in archive."
               if (present(status)) then
                  status = 1
                  return
               else
                  stop
               end if
            end if
            archive = .true.
            write(filename, "(A)") file//'.'//trim(ext)
            write(astruct%inputfile_format, "(A)") trim(ext)
         end if
      end if

      ! Test posinp.xyz
      if (.not. file_exists) then
         inquire(FILE = file//'.xyz', EXIST = file_exists)
         if (file_exists) then
            write(filename, "(A)") file//'.xyz'!"posinp.xyz"
            write(astruct%inputfile_format, "(A)") "xyz"
            open(unit=99,file=trim(filename),status='old')
         end if
      end if
      ! Test posinp.ascii
      if (.not. file_exists) then
         inquire(FILE = file//'.ascii', EXIST = file_exists)
         if (file_exists) then
            write(filename, "(A)") file//'.ascii'!"posinp.ascii"
            write(astruct%inputfile_format, "(A)") "ascii"
            open(unit=99,file=trim(filename),status='old')
         end if
      end if
      ! Test posinp.int
      if (.not. file_exists) then
         inquire(FILE = file//'.int', EXIST = file_exists)
         if (file_exists) then
            write(filename, "(A)") file//'.int'!"posinp.int
            write(astruct%inputfile_format, "(A)") "int"
            open(unit=99,file=trim(filename),status='old')
         end if
      end if
      ! Test posinp.yaml
      if (.not. file_exists) then
         inquire(FILE = file//'.yaml', EXIST = file_exists)
         if (file_exists) then
            write(filename, "(A)") file//'.yaml'!"posinp.yaml
            write(astruct%inputfile_format, "(A)") "yaml"
            ! Pb if toto.yaml because means that there is no key posinp!!
         end if
      end if
      ! Test the name directly
      if (.not. file_exists) then
         inquire(FILE = file, EXIST = file_exists)
         if (file_exists) then
            write(filename, "(A)") file
            l = len(file)
            if (file(l-3:l) == ".xyz") then
               write(astruct%inputfile_format, "(A)") "xyz"
            else if (file(l-5:l) == ".ascii") then
               write(astruct%inputfile_format, "(A)") "ascii"
            else if (file(l-3:l) == ".int") then
               write(astruct%inputfile_format, "(A)") "int"
            else if (file(l-4:l) == ".yaml") then
               write(astruct%inputfile_format, "(A)") "yaml"
            else
               write(*,*) "Atomic input file '" // trim(file) // "', format not recognised."
               write(*,*) " File should be *.yaml, *.ascii, *.int or *.xyz."
               if (present(status)) then
                  status = 1
                  return
               else
                  stop
               end if
            end if
            if (trim(astruct%inputfile_format) /= "yaml") then
               open(unit=99,file=trim(filename),status='old')
            end if
         end if
      end if

      if (.not. file_exists) then
         if (present(status)) then
            status = 1
            return
         else
            write(*,*) "Atomic input file not found."
            write(*,*) " Files looked for were '"//file//".yaml', '"//file//".ascii', '"//file//".xyz' and '"//file//"'."
            stop 
         end if
      end if

      if (astruct%inputfile_format == "xyz") then
         !read atomic positions
         if (.not.archive) then
            call read_xyz_positions(iproc,99,astruct,comment_,energy_,fxyz_,directGetLine)
         else
            call read_xyz_positions(iproc,99,astruct,comment_,energy_,fxyz_,archiveGetLine)
         end if
      else if (astruct%inputfile_format == "ascii") then
         i_stat = iproc
         if (present(status)) i_stat = 1
         !read atomic positions
         if (.not.archive) then
            call read_ascii_positions(i_stat,99,astruct,comment_,energy_,fxyz_,directGetLine)
         else
            call read_ascii_positions(i_stat,99,astruct,comment_,energy_,fxyz_,archiveGetLine)
         end if
      else if (astruct%inputfile_format == "int") then
         !read atomic positions
         if (.not.archive) then
            call read_int_positions(iproc,99,astruct,comment_,energy_,fxyz_,directGetLine)
         else
            call read_int_positions(iproc,99,astruct,comment_,energy_,fxyz_,archiveGetLine)
         end if
         ! Fill the ordinary rxyz array
         !!! convert to rad
         !!astruct%rxyz_int(2:3,1:astruct%nat) = astruct%rxyz_int(2:3,1:astruct%nat) / degree
         call internal_to_cartesian(astruct%nat, astruct%ixyz_int(1,:), astruct%ixyz_int(2,:), astruct%ixyz_int(3,:), &
              astruct%rxyz_int, astruct%rxyz)
         !!do i_stat=1,astruct%nat
         !!    write(*,'(3(i4,3x,f12.5))') astruct%ixyz_int(1,i_stat),astruct%rxyz_int(1,i_stat),&
         !!                                astruct%ixyz_int(2,i_stat),astruct%rxyz_int(2,i_stat),&
         !!                                astruct%ixyz_int(3,i_stat),astruct%rxyz_int(3,i_stat)
         !!end do
         !!do i_stat=1,astruct%nat
         !!    write(*,*) astruct%rxyz(:,i_stat)
         !!end do
      else if (astruct%inputfile_format == "yaml" .and. index(file,'posinp') /= 0) then
         ! Pb if toto.yaml because means that there is already no key posinp in the file toto.yaml!!
         call f_err_throw("Atomic input file in YAML not yet supported, call 'astruct_set_from_dict()' instead.",&
              err_name='BIGDFT_RUNTIME_ERROR')
      end if

      !Check the number of atoms
      if (astruct%nat < 0) then
         if (present(status)) then
            status = 1
            return
         else
            write(*,'(1x,3a,i0,a)') "In the file '",trim(filename),&
                 &  "', the number of atoms (",astruct%nat,") < 0 (should be >= 0)."
            stop 
         end if
      end if

      !control atom positions
      call check_atoms_positions(astruct,(iproc == 0))

      ! We delay the calculation of the symmetries.
      !this should be already in the atoms_null routine
      astruct%sym=symmetry_data_null()
      !   astruct%sym%symObj = -1
      !   nullify(astruct%sym%irrzon)
      !   nullify(astruct%sym%phnons)

      ! close open file.
      if (.not.archive .and. trim(astruct%inputfile_format) /= "yaml") then
         close(99)
!!$  else
!!$     call unlinkExtract(trim(filename), len(trim(filename)))
      end if

      ! We transfer optionals.
      if (present(energy)) then
         energy = energy_
      end if
      if (present(comment)) then
         write(comment, "(A)") comment_
      end if
      if (present(fxyz)) then
         if (associated(fxyz_)) then
            !fxyz = f_malloc_ptr(src = fxyz_, id = "fxyz") not needed anymore
            fxyz => fxyz_
         else
            nullify(fxyz)
         end if
         !call f_free_ptr(fxyz_)
      else if (associated(fxyz_)) then
         call f_free_ptr(fxyz_)
      end if

    END SUBROUTINE set_astruct_from_file

    include 'astruct-inc.f90'


    !> Terminate the allocation of the memory in the pointers of atoms
    subroutine allocate_atoms_data(atoms)
      implicit none
      type(atoms_data), intent(inout) :: atoms
      external :: allocate_atoms_nat,allocate_atoms_ntypes
      
      call allocate_atoms_nat(atoms)
      call allocate_atoms_ntypes(atoms)
    end subroutine allocate_atoms_data

END MODULE module_atoms


!> Allocation of the arrays inside the structure atoms_data, considering the part which is associated to astruct%nat
!! this routine is external to the module as it has to be called from C
subroutine astruct_set_n_atoms(astruct, nat)
  use module_base
  use module_atoms, only: atomic_structure
  implicit none
  type(atomic_structure), intent(inout) :: astruct
  integer, intent(in) :: nat
  !local variables
  character(len=*), parameter :: subname='astruct_set_n_atoms' !<remove

  astruct%nat = nat

  ! Allocate geometry related stuff.
  astruct%iatype = f_malloc_ptr(astruct%nat+ndebug,id='astruct%iatype')
  astruct%ifrztyp = f_malloc_ptr(astruct%nat+ndebug,id='astruct%ifrztyp')
  astruct%input_polarization = f_malloc_ptr(astruct%nat+ndebug,id='astruct%input_polarization')
  astruct%rxyz = f_malloc_ptr((/ 3,astruct%nat+ndebug /),id='astruct%rxyz')
  astruct%rxyz_int = f_malloc_ptr((/ 3,astruct%nat+ndebug /),id='astruct%rxyz_int')
  astruct%ixyz_int = f_malloc_ptr((/ 3,astruct%nat+ndebug /),id='astruct%ixyz_int')

  !this array is useful for frozen atoms, no atom is frozen by default
  astruct%ifrztyp(:)=0
  !also the spin polarisation and the charge are is fixed to zero by default
  !this corresponds to the value of 100
  !RULE natpol=charge*1000 + 100 + spinpol
  astruct%input_polarization(:)=100

  if (astruct%nat > 0) call to_zero(3 * astruct%nat, astruct%rxyz(1,1))
END SUBROUTINE astruct_set_n_atoms


!> allocation of the memory space associated to the number of types astruct%ntypes
subroutine astruct_set_n_types(astruct, ntypes)
  use module_base
  use module_atoms, only: atomic_structure
  implicit none
  type(atomic_structure), intent(inout) :: astruct
  integer, intent(in) :: ntypes
  !character(len = *), intent(in) :: subname
  !local variables
  character(len=*), parameter :: subname='astruct_set_n_types' !<remove
  integer :: i, i_stat

  astruct%ntypes = ntypes

  ! Allocate geometry related stuff.
  allocate(astruct%atomnames(astruct%ntypes+ndebug),stat=i_stat)
  call memocc(i_stat,astruct%atomnames,'astruct%atomnames',subname)

  do i = 1, astruct%ntypes, 1
     write(astruct%atomnames(i), "(A)") " "
  end do
END SUBROUTINE astruct_set_n_types

!> initialize the astruct variable from a file
subroutine astruct_set_from_file(lstat, astruct, filename)
  use module_base
  use module_atoms, only: atomic_structure,read_atomic_file=>set_astruct_from_file
  implicit none
  logical, intent(out) :: lstat
  type(atomic_structure), intent(inout) :: astruct
  character(len = *), intent(in) :: filename

  integer :: status

  call read_atomic_file(filename, 0, astruct, status)
  lstat = (status == 0)
END SUBROUTINE astruct_set_from_file


!> Calculate the symmetries and update
subroutine astruct_set_symmetries(astruct, disableSym, tol, elecfield, nspin)
  use module_base
  use module_atoms, only: atomic_structure,deallocate_symmetry_data
  use defs_basis
  use m_ab6_symmetry
  implicit none
  type(atomic_structure), intent(inout) :: astruct
  logical, intent(in) :: disableSym
  real(gp), intent(in) :: tol
  real(gp), intent(in) :: elecfield(3)
  integer, intent(in) :: nspin
  !local variables
  character(len=*), parameter :: subname='astruct_set_symmetries'
  integer :: ierr
  real(gp), dimension(3,3) :: rprimd
  real(gp), dimension(:,:), allocatable :: xRed
  integer, dimension(3, 3, AB6_MAX_SYMMETRIES) :: sym
  integer, dimension(AB6_MAX_SYMMETRIES) :: symAfm
  real(gp), dimension(3, AB6_MAX_SYMMETRIES) :: transNon
  real(gp), dimension(3) :: genAfm
  integer :: spaceGroupId, pointGroupMagn

  ! Calculate the symmetries, if needed (for periodic systems only)
  if (astruct%geocode /= 'F') then
     if (astruct%sym%symObj < 0) then
        call symmetry_new(astruct%sym%symObj)
     end if
     ! Adjust tolerance
     if (tol > 0._gp) call symmetry_set_tolerance(astruct%sym%symObj, tol, ierr)
     ! New values
     rprimd(:,:) = 0
     rprimd(1,1) = astruct%cell_dim(1)
     rprimd(2,2) = astruct%cell_dim(2)
     if (astruct%geocode == 'S') rprimd(2,2) = 1000._gp
     rprimd(3,3) = astruct%cell_dim(3)
     call symmetry_set_lattice(astruct%sym%symObj, rprimd, ierr)
     xRed = f_malloc((/ 3 , astruct%nat+ndebug /),id='xRed')
     xRed(1,:) = modulo(astruct%rxyz(1, :) / rprimd(1,1), 1._gp)
     xRed(2,:) = modulo(astruct%rxyz(2, :) / rprimd(2,2), 1._gp)
     xRed(3,:) = modulo(astruct%rxyz(3, :) / rprimd(3,3), 1._gp)
     call symmetry_set_structure(astruct%sym%symObj, astruct%nat, astruct%iatype, xRed, ierr)
     call f_free(xRed)
     if (astruct%geocode == 'S') then
        call symmetry_set_periodicity(astruct%sym%symObj, &
             & (/ .true., .false., .true. /), ierr)
     else if (astruct%geocode == 'F') then
        call symmetry_set_periodicity(astruct%sym%symObj, &
             & (/ .false., .false., .false. /), ierr)
     end if
     !if (all(in%elecfield(:) /= 0)) then
     !     ! I'm not sure what this subroutine does!
     !   call symmetry_set_field(astruct%sym%symObj, (/ in%elecfield(1) , in%elecfield(2),in%elecfield(3) /), ierr)
     !elseif (in%elecfield(2) /= 0) then
     !   call symmetry_set_field(astruct%sym%symObj, (/ 0._gp, in%elecfield(2), 0._gp /), ierr)
     if (elecfield(2) /= 0) then
        call symmetry_set_field(astruct%sym%symObj, (/ 0._gp, elecfield(2), 0._gp /), ierr)
     end if
     if (nspin == 2) then
        call symmetry_set_collinear_spin(astruct%sym%symObj, astruct%nat, &
             & astruct%input_polarization, ierr)
!!$     else if (in%nspin == 4) then
!!$        call symmetry_set_spin(atoms%astruct%sym%symObj, atoms%astruct%nat, &
!!$             & atoms%astruct%input_polarization, ierror)
     end if
     if (disableSym) then
        call symmetry_set_n_sym(astruct%sym%symObj, 1, &
          & reshape((/ 1, 0, 0, 0, 1, 0, 0, 0, 1 /), (/ 3 ,3, 1 /)), &
          & reshape((/ 0.d0, 0.d0, 0.d0 /), (/ 3, 1/)), (/ 1 /), ierr)
     end if
  else
     call deallocate_symmetry_data(astruct%sym)
     astruct%sym%symObj = -1
  end if

  ! Generate symmetries for atoms
  if (.not. disableSym) then
     call symmetry_get_matrices(astruct%sym%symObj, astruct%sym%nSym, sym, transNon, symAfm, ierr)
     call symmetry_get_group(astruct%sym%symObj, astruct%sym%spaceGroup, &
          & spaceGroupId, pointGroupMagn, genAfm, ierr)
     if (ierr == AB7_ERROR_SYM_NOT_PRIMITIVE) write(astruct%sym%spaceGroup, "(A)") "not prim."
  else 
     astruct%sym%nSym = 0
     astruct%sym%spaceGroup = 'disabled'
  end if

END SUBROUTINE astruct_set_symmetries


!> Allocation of the arrays inside the structure atoms_data
subroutine allocate_atoms_nat(atoms)
  use module_base
  use module_atoms, only: atoms_data
  use ao_inguess, only : aoig_data_null
  implicit none
  type(atoms_data), intent(inout) :: atoms
  integer :: iat

  allocate(atoms%aoig(atoms%astruct%nat))
  do iat=1,atoms%astruct%nat
     atoms%aoig(iat)=aoig_data_null()
  end do

END SUBROUTINE allocate_atoms_nat


subroutine allocate_atoms_ntypes(atoms)
  use module_base
  use module_atoms, only: atoms_data
  implicit none
  type(atoms_data), intent(inout) :: atoms
  !local variables
  character(len = *), parameter :: subname='allocate_atoms_ntypes'

  ! Allocate pseudo related stuff.
  ! store PSP parameters, modified to accept both GTH and HGHs pseudopotential types
  atoms%amu = f_malloc_ptr(atoms%astruct%nat,id='atoms%amu')
  atoms%psppar = f_malloc_ptr((/ 0.to.4 , 0.to.6 , 1.to.atoms%astruct%ntypes /),id='atoms%psppar')
  atoms%nelpsp = f_malloc_ptr(atoms%astruct%ntypes,id='atoms%nelpsp')
  atoms%npspcode = f_malloc_ptr(atoms%astruct%ntypes,id='atoms%npspcode')
  atoms%nzatom = f_malloc_ptr(atoms%astruct%ntypes,id='atoms%nzatom')
  atoms%ixcpsp = f_malloc_ptr(atoms%astruct%ntypes,id='atoms%ixcpsp')
  atoms%radii_cf = f_malloc_ptr((/ atoms%astruct%ntypes , 3 /),id='atoms%radii_cf')
  atoms%iradii_source = f_malloc_ptr(atoms%astruct%ntypes,id='atoms%iradii_source')
  ! parameters for NLCC
  atoms%nlcc_ngv = f_malloc_ptr(atoms%astruct%ntypes,id='atoms%nlcc_ngv')
  atoms%nlcc_ngc = f_malloc_ptr(atoms%astruct%ntypes,id='atoms%nlcc_ngc')
END SUBROUTINE allocate_atoms_ntypes


! Init and free routines


!> Allocate a new atoms_data type, for bindings.
subroutine atoms_new(atoms)
  use module_atoms, only: atoms_data,nullify_atoms_data
  implicit none
  type(atoms_data), pointer :: atoms

  type(atoms_data), pointer :: intern
  
  allocate(intern)
  call nullify_atoms_data(intern)
  atoms => intern
END SUBROUTINE atoms_new


!> Free an allocated atoms_data type.
subroutine atoms_free(atoms)
  use module_atoms, only: atoms_data,deallocate_atoms_data
  implicit none
  type(atoms_data), pointer :: atoms
  
  call deallocate_atoms_data(atoms)
  deallocate(atoms)
END SUBROUTINE atoms_free
