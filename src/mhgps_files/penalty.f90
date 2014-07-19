program penalty
use module_lst
implicit none



end program


!! @file
!! @author Bastian Schaefer
!! @section LICENCE
!!    Copyright (C) 2014 UNIBAS
!!    This file is not freely distributed.
!!    A licence is necessary from UNIBAS
module module_lst
implicit none

!to be removed when moved to bigdft:
integer, parameter :: gp=kind(1.0d0)

contains
subroutine lst_penalty(nat,rxyz1,rxyz2,rxyz,lambda,val,grad)
!computes the linear synchronous penalty function
!and gradient
!
!see:
!
!Halgren, T. A., & Lipscomb, W. N. (1977). The synchronous-transit
!method for determining reaction pathways and locating molecular
!transition states. Chemical Physics Letters, 49(2), 225–232.
!doi:10.1016/0009-2614(77)80574-5
!
!and
!
!Behn, A., Zimmerman, P. M., Bell, A. T., & Head-Gordon, M. (2011).
!Incorporating Linear Synchronous Transit Interpolation into
!the Growing String Method: Algorithm and Applications.
!Journal of Chemical Theory and Computation, 7(12), 4019–4025.
!doi:10.1021/ct200654u
!
!BS: For computation of gradient see also personal notes in intel
!notebook (paper version) from June 18th, 2014
!
    implicit none
    !parameters
    integer, intent(in)  :: nat
    real(gp), intent(in) :: rxyzR(3,nat) !reactant
    real(gp), intent(in) :: rxyzP(3,nat) !product
    real(gp), intent(in) :: rxyz(3,nat)  !the positon at which
                                         !the penalty fct. is to
                                         !be evaluated
    real(gp), intent(in)  :: lambda !interpolation parameter
    real(gp), intent(out) :: val  !the value of the penalty function
    real(gp), intent(out) :: grad(3,nat) !the gradient of
                                        !the penal. fct. at
                                        !rxyz
    !internal
    integer :: b !outer loop
    integer :: a !inner loop
    real(gp) :: rabi !interpolated interatomic distances
    real(gp) :: rabi4 !ri4=ri**4
    real(gp) :: rabC !computed interatomic distances
    real(gp) :: rabR !interatomic dist. of reactant
    real(gp) :: rabP !interatomic dist. of product
    real(gp),parameter :: oml=1.0_gp-lambda
    real(gp) :: rxRb, ryRb, rxRb
    real(gp) :: rxPb, ryPb, rxPb
    real(gp) :: rxb, ryb, rxb
    real(gp) :: rabiMrabC,

    val=0.0_gp
    do b = 1, nat-1
        rxRb = rxyzR(1,b)
        ryRb = rxyzR(2,b)
        rzRb = rxyzR(3,b)
        rxPb = rxyzP(1,b)
        ryPb = rxyzP(2,b)
        rzPb = rxyzP(3,b)
        rxb = rxyz(1,b)
        ryb = rxyz(2,b)
        rzb = rxyz(3,b)
        do a = l+1, nat
            !compute interatomic distances of reactant
            rabR = (rxyzR(1,a)-rxRb)**2+&
                   (rxyzR(2,a)-ryRb)**2+&
                   (rxyzR(3,a)-rzRb)**2
            !compute interatomic distances of product
            rabP = (rxyzP(1,a)-rxPb)**2+&
                   (rxyzP(2,a)-ryPb)**2+&
                   (rxyzP(3,a)-rzPb)**2
            !compute interpolated interatomic distances
            rabi = oml*rabR-lambda*rabP
            !compute interatomic distances at rxyz
            rabC = (rxyz(1,a)-rxb)**2+&
                   (rxyz(2,a)-ryb)**2+&
                   (rxyz(3,a)-rzb)**2
        enddo
    enddo
end subroutine

!subroutine fire_original(nat,rxyz,fxyz,epot,fnrm,count_fr,displ)
!    implicit none
!    !parameters
!    integer, intent(in) :: nat
!    integer :: maxit
!    real(gp)  :: fmax_tol,fnrm_tol,dt_max
!    real(gp), intent(inout) :: rxyz(3,nat),fxyz(3,nat)
!    real(gp)  :: epot,fmax,fnrm
!    logical :: success
!    real(gp), intent(inout) :: count_fr
!    real(gp), intent(out) :: displ
!    !internal
!    real(gp) :: vxyz(3,nat),ff(3,nat),power
!!    real(gp) :: ekin
!    real(gp) :: at1,at2,at3,vxyz_norm,fxyz_norm,alpha
!    integer :: iat,iter,check,cut
!    integer, parameter :: n_min=5
!    real(gp), parameter :: f_inc=1.1_gp, f_dec=0.5_gp, alpha_start=0.1_gp,f_alpha=0.99_gp
!    real(gp) :: dt
!    real(gp) :: ddot,dnrm2
!    character(len=5), allocatable :: xat(:)
!    real(gp) :: rxyzIn(3,nat)
!
!    real(gp) :: epot_prev, anoise
!    real(gp) :: rxyz_prev(3,nat)
!    real(gp) :: counter_reset
!    real(gp) :: disp(3,nat),dmy1,dmy2
!
!    displ=0.0_gp
!    dt_max = 4.5d-2
!    maxit=50000
!
!    rxyzIn=rxyz
!
!    success=.false.
!
!!    dt=0.1_gp*dt_max
!    dt=dt_max
!    alpha=alpha_start
!    vxyz=0.0_gp
!    check=0
!    cut=1
!    call energyandforces(nat,rxyz,ff,epot)
!        count_fr=count_fr+1.0_gp
!!write(*,'(a)')'FIRE         iter     epot            fmax           fnrm
!!dt             alpha'
!    do iter=1,maxit
!        epot_prev=epot
!        rxyz_prev=rxyz
!        1000 continue
!        call daxpy(3*nat,dt,vxyz(1,1),1,rxyz(1,1),1)
!        call daxpy(3*nat,0.5_gp*dt*dt,ff(1,1),1,rxyz(1,1),1)
!!        ekin=ddot(3*nat,vxyz(1,1),1,vxyz(1,1),1)
!!        ekin=0.5_gp*ekin
!        call energyandforces(nat,rxyz,fxyz,epot)
!        count_fr=count_fr+1.0_gp
!        disp=rxyz-rxyz_prev
!        call fmaxfnrm(nat,disp,dmy1,dmy2)
!        displ=displ+dmy2
!        do iat=1,nat
!           at1=fxyz(1,iat)
!           at2=fxyz(2,iat)
!           at3=fxyz(3,iat)
!           !C Evolution of the velocities of the system
!           vxyz(1,iat)=vxyz(1,iat) + (.5_gp*dt) * (at1 + ff(1,iat))
!           vxyz(2,iat)=vxyz(2,iat) + (.5_gp*dt) * (at2 + ff(2,iat))
!           vxyz(3,iat)=vxyz(3,iat) + (.5_gp*dt) * (at3 + ff(3,iat))
!           !C Memorization of old forces
!           ff(1,iat) = at1
!           ff(2,iat) = at2
!           ff(3,iat) = at3
!        end do
!!write(*,*)rxyz(1,1),vxyz(1,1)
!        call fmaxfnrm(nat,fxyz,fmax,fnrm)
!!        call convcheck(fmax,fmax_tol,check)
!!        if(check > 5)then
!         if (fnrm.lt.1.e-3_gp)   then
!!            write(*,*)'FIRE converged, force calls: ',iter+1,epot
!            write(100,'(a,x,i0,5(1x,es14.7))')'FIRE converged # e evals, epot, fmax, fnrm, dt, alpha: ',int(count_fr),epot,fmax,fnrm,dt,alpha
!!            write(*,'(a,x,i0,x,i0,5(1x,es14.7))')'FIRE converged iter, epot,
!!            fmax, fnrm, dt, alpha:
!!            ',iter,iter+int(count_fr)+1+int(counter_reset),epot,fmax,fnrm,dt,alpha
!            success=.true.
!            return
!        endif
!        power = ddot(3*nat,fxyz,1,vxyz,1)
!        vxyz_norm = dnrm2(3*nat,vxyz,1)
!        fxyz_norm = dnrm2(3*nat,fxyz,1)
!        vxyz = (1.0_gp-alpha)*vxyz + alpha * fxyz * vxyz_norm / fxyz_norm
!        if(power<=0)then
!!write(*,*)'freeze'
!            vxyz=0.0_gp
!            cut=iter
!            dt=dt*f_dec
!            alpha=alpha_start
!        else if(power > 0 .and. iter-cut >n_min)then
!            dt= min(dt*f_inc,dt_max)
!            alpha = alpha*f_alpha
!        endif
!    enddo
!    if(fmax > fmax_tol)then
!            write(100,'(a,x,i0,5(1x,es14.7))')'FIRE ERROR not converged iter, epot, fmax, fnrm, dt, alpha: ',iter,epot,fmax,fnrm,dt,alpha
!    endif
!end subroutine


end module
