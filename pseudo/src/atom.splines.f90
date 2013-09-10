!> @file
!! sandia mathematical program library
!!     applied mathematics division 2613
!!     sandia laboratories
!!     albuquerque, new mexico  87185
!!     control data 6600/7600  version 7.2  may 1978
!!  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
!!                    issued by sandia laboratories                     *
!!  *                   a prime contractor to the                       *
!!  *                united states department of energy                 *
!!  * * * * * * * * * * * * * * * notice  * * * * * * * * * * * * * * * *
!!  * this report was prepared as an account of work sponsored by the   *
!!  * united states government.  neither the united states nor the      *
!!  * united states department of energy nor any of their employees,    *
!!  * nor any of their contractors, subcontractors, or their employees  *
!!  * makes any warranty, express or implied, or assumes any legal      *
!!  * liability or responsibility for the accuracy, completeness or     *
!!  * usefulness of any information, apparatus, product or process      *
!!  * disclosed, or represents that its use would not infringe          *
!!  * owned rights.                                                     *
!!  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
!!  * the primary document for the library of which this routine is     *
!!  * part is sand77-1441.                                              *
!!  * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
!!
!! @todo Remove arithmetic if


!> splift fits an interpolating cubic spline to the n data points
!! given in x and y and returns the first and second derivatives
!! in yp and ypp.  the resulting spline (defined by x, y, and
!! ypp) and its first and second derivatives may then be
!! evaluated using splint.  the spline may be integrated using
!! spliq.  for a smoothing spline fit see subroutine smoo.
!!
!! description of arguments
!!     the user must dimension all arrays appearing in the call list,
!!     e.g.   x(n), y(n), yp(n), ypp(n), w(3n)
!!
!!   --input--
!!
!!     x    - array of abscissas of data (in increasing order)
!!     y    - array of ordinates of data
!!     n    - the number of data points.  the arrays x, y, yp, and
!!            ypp must be dimensioned at least n.  (n .ge. 4)
!!     isx  - must be zero on the initial call to splift.
!!            if a spline is to be fitted to a second set of data
!!            that has the same set of abscissas as a previous set,
!!            and if the contents of w have not been changed since
!!            that previous fit was computed, then isx may be
!!            set to one for faster execution.
!!     a1,b1,an,bn - specify the end conditions for the spline which
!!            are expressed as constraints on the second derivative
!!            of the spline at the end points (see ypp).
!!            the end condition constraints are
!!                    ypp(1) = a1*ypp(2) + b1
!!            and
!!                    ypp(n) = an*ypp(n-1) + bn
!!            where
!!                    abs(a1).lt. 1.0  and  abs(an).lt. 1.0.
!!
!!            the smoothest spline (i.e., least integral of square
!!            of second derivative) is obtained by a1=b1=an=bn=0.
!!            in this case there is an inflection at x(1) and x(n).
!!            if the data is to be extrapolated (say, by using splint
!!            to evaluate the spline outside the range x(1) to x(n)),
!!            then taking a1=an=0.5 and b1=bn=0 may yield better
!!            results.  in this case there is an inflection
!!            at x(1) - (x(2)-x(1)) and at x(n) + (x(n)-x(n-1)).
!!            in the more general case of a1=an=a  and b1=bn=0,
!!            there is an inflection at x(1) - (x(2)-x(1))*a/(1.0-a)
!!            and at x(n) + (x(n)-x(n-1))*a/(1.0-a).
!!
!!            a spline that has a given first derivative yp1 at x(1)
!!            and ypn at y(n) may be defined by using the
!!            following conditions.
!!
!!            a1=-0.5
!!
!!            b1= 3.0*((y(2)-y(1))/(x(2)-x(1))-yp1)/(x(2)-x(1))
!!
!!            an=-0.5
!!
!!            bn=-3.0*((y(n)-y(n-1))/(x(n)-x(n-1))-ypn)/(x(n)-x(n-1))
!!
!!   --output--
!!
!!     yp   - array of first derivatives of spline (at the x(i))
!!     ypp  - array of second derivatives of spline (at the x(i))
!!     ierr - a status code
!!          --normal code
!!             1 means that the requested spline was computed.
!!          --abnormal codes
!!             2 means that n, the number of points, was .lt. 4.
!!             3 means the abscissas were not strictly increasing.
!!
!!   --work--
!!
!!     w    - array of working storage dimensioned at least 3n.
!! @author written by Rondall E. Jones
subroutine splift(x,y,yp,ypp,n,w,ierr,isx,a1,b1,an,bn)
   implicit none
   !Arguments
   integer, intent(in) :: n     !< the number of data points
   integer, intent(in) :: isx   !< must be zero on the initial call to splift.
                                !! if a spline is to be fitted to a second set of data that has the same set 
                                !! of abscissas as a previous set, and if the contents of w have not been changed since
                                !! that previous fit was computed, then isx may be set to one for faster execution.
   real(kind=8), intent(in) :: a1,b1,an,bn !< specify the end conditions for the spline which are expressed as constraints 
                                           !! on the second derivative of the spline at the end points (see ypp).
                                           !! the end condition constraints are ypp(1) = a1*ypp(2) + b1
                                           !! and                               ypp(n) = an*ypp(n-1) + bn
                                           !! where abs(a1).lt. 1.0  and  abs(an).lt. 1.0.
   integer, intent(out) :: ierr !< a status code
                                !! (normal),   1 means that the requested spline was computed.
                                !! (abnormal), 2 means that n, the number of points, was < 4.
                                !!             3 means the abscissas were not strictly increasing.
   real(kind=8), dimension(n), intent(in) :: x    !< array of abscissas of data (in increasing order)
   real(kind=8), dimension(n), intent(in) :: y    !< array of ordinates of data
   real(kind=8), dimension(n), intent(out) :: yp  !< array of first derivatives of spline (at the x(i))
   real(kind=8), dimension(n), intent(out) :: ypp !< array of second derivatives of spline (at the x(i))
   real(kind=8), dimension(n,3), intent(out) :: w !< array of working storage dimensioned at least 3n.
   
   !Local variables
   real(kind=8) :: dnew,dold
   integer :: i,nm1,nm2,j

   !Check if enough points
   if (n < 4) then
      ierr = 2
      write(6,'(47h in splift, there were less than 4 data values.)')
      return
   end if
   nm1  = n-1
   nm2  = n-2

   if (isx == 0) then
      !Initialize w (which keeps the L U decomposition)
      do i=2,n
         if (x(i)-x(i-1) <= 0.d0) then
            ierr = 3
            write(6,'(11h in splift, 44h the abscissas were not strictly increasing.)')
            return
         end if
      end do

      ! define the tridiagonal matrix
      w(1,3) = x(2)-x(1)
      do i=2,nm1
         w(i,2) = w(i-1,3)
         w(i,3) = x(i+1)-x(i)
         w(i,1) = 2.D0*(w(i,2)+w(i,3))
      end do
      w(1,1) = 4.D0
      w(1,3) =-4.D0*a1
      w(n,1) = 4.D0
      w(n,2) =-4.D0*an

      ! L U decomposition
      do i=2,n
         w(i-1,3) = w(i-1,3)/w(i-1,1)
         w(i,1)   = w(i,1) - w(i,2)*w(i-1,3)
      end do
   end if

   ! define *constant* vector
   ypp(1) = 4.D0*b1
   dold   = (y(2)-y(1))/w(2,2)
   do i=2,nm2
      dnew   = (y(i+1) - y(i))/w(i+1,2)
      ypp(i) = 6.D0*(dnew - dold)
      yp(i)  = dold
      dold   = dnew
   end do
   dnew   = (y(n)-y(n-1))/(x(n)-x(n-1))
   ypp(nm1) = 6.D0*(dnew - dold)
   ypp(n) = 4.D0*bn
   yp(nm1)= dold
   yp(n)  = dnew

   ! forward substitution
   ypp(1) = ypp(1)/w(1,1)
   do i=2,n
      ypp(i) = (ypp(i) - w(i,2)*ypp(i-1))/w(i,1)
   end do

   ! backward substitution
   do j=1,nm1
      i = n-j
      ypp(i) = ypp(i) - w(i,3)*ypp(i+1)
   end do

   ! compute first derivatives
   yp(1)  = (y(2)-y(1))/(x(2)-x(1)) - (x(2)-x(1))*(2.D0*ypp(1) + ypp(2))/6.D0
   do i=2,nm1
      yp(i)  = yp(i) + w(i,2)*(ypp(i-1) + 2.D0*ypp(i))/6.D0
   end do
   yp(n)  = yp(n) + (x(n)-x(nm1))*(ypp(nm1) + 2.D0*ypp(n))/6.D0

   !Normal error code
   ierr = 1
end subroutine splift


!> subroutine spliq integrates a cubic spline (generated by
!! splift, smoo, etc.) on the intervals (xlo,xup(i)), where xup
!! is a sequence of upper limits on the intervals of integration.
!! the only restrictions on xlo and xup(*) are
!!            xlo .lt. xup(1),
!!            xup(i) .le. xup(i+1)   for each i .
!! endpoints beyond the span of abscissas are allowed.
!! the spline over the interval (x(i),x(i+1)) is regarded
!! as a cubic polynomial expanded about x(i) and is integrated
!! analytically.
!!
!! description of arguments
!!     the user must dimension all arrays appearing in the call list,
!!     e.g.  x(n), y(n), yp(n), ypp(n), xup(nup), ans(nup)
!!
!!  --input--
!!
!!    x    - array of abscissas (in increasing order) that define the
!!           spline.  usually x is the same as x in splift or smoo.
!!    y    - array of ordinates that define the spline.  usually y is
!!           the same as y in splift or as r in smoo.
!!    yp   - array of first derivatives of the spline at abscissas.
!!           usually yp is the same as yp in splift or r1 in smoo.
!!    ypp  - array of second derivatives that define the spline.
!!           usually ypp is the same as ypp in splift or r2 in smoo.
!!    n    - the number of data points that define the spline.
!!    xlo  - left endpoint of integration intervals.
!!    xup  - right endpoint or array of right endpoints of
!!           integration intervals in ascending order.
!!    nup  - the number of right endpoints.  if nup is greater than
!!           1, then xup and ans must be dimensioned at least nup.
!!
!!  --output--
!!
!!    ans -- array of integral values, that is,
!!           ans(i) = integral from xlo to xup(i)
!!    ierr -- error status
!!            = 1 integration successful
!!            = 2 improper input - n.lt.4 or nup.lt.1
!!            = 3 improper input - abscissas not in
!!                    strictly ascending order
!!            = 4 improper input - right endpoints xup not
!!                    in ascending order
!!            = 5 improper input - xlo.gt.xup(1)
!!            = 6 integration successful but at least one endpoint
!!                    not within span of abscissas
!!
!! check for improper input
!!
!! @author This routine was written by M. K. Gordon
subroutine spliq(x,y,yp,ypp,n,xlo,xup,nup,ans,ierr)
  implicit none
  !Arguments
  integer, intent(in) :: n     !< the number of data points that define the spline.
  integer, intent(in) :: nup   !< the number of right endpoints.
  integer, intent(out) :: ierr !< error status
  real(kind=8), dimension(n), intent(in) :: x,y,yp,ypp
  real(kind=8), intent(in) :: xlo !< left endpoint of integration intervals
  real(kind=8), dimension(nup), intent(in) :: xup  !< right endpoint or array of right endpoints of integration intervals in ascending order.
  real(kind=8), dimension(nup), intent(out) :: ans !< array of integral values, that is ans(i) = integral from xlo to xup(i)
  !Local variables
  real(kind=8) :: hlo,hdiff,hi,hi2,hi3,hlo2,hsum,hup,hup2,hup3,hup4
  real(kind=8) :: psum0,psum1,psum2,psum3,sum,sum0,sum1,sum2,sum3
  integer :: nm1,nm2,i,j,m
  !Check length of arrays
  if (n < 4  .or.  nup < 1) then
     ierr = 2
     write(6,'(36h in spliq, either n.lt.4 or nup.lt.1)')
     return
  end if
  nm1 = n-1
  nm2 = n-2
  !Check ascending order
  do i = 1,nm1
     if (x(i) >= x(i+1)) then
        ierr = 3
        write(6,'(43h in spliq, abscissas not in ascending order)')
        return
     end if
  end do
  !Check ascending order for right endpoints
  if (nup > 1) then
      do i = 2,nup
         if (xup(i-1) > xup(i)) then
            ierr = 4
            write(6,'(49h in spliq, right endpoints not in ascending order)')
            return
         end if
      end do
   end if
   !Check if left end point < right end points
   if (xlo > xup(1)) then
      ierr = 5
      write(6,'(26h in spliq, xlo .gt. xup(1))')
      write(6,*) xlo ,'>',xup(1)
      return
   end if
   !Normal code
   ierr = 1
   if (xlo .lt. x(1)  .or.  xup(nup) .gt. x(n)) ierr = 6

   ! locate xlo in interval (x(i),x(i+1))
      do 10 i = 1,nm2
        if (xlo .lt. x(i+1)) go to 20
 10     continue
      i = nm1
 20   continue
      hlo = xlo-x(i)
      hlo2 = hlo*hlo
      hi = x(i+1)-x(i)
      hi2 = hi*hi
      do 30 j = 1,nup
        if (xup(j) .gt. x(i+1)  .and.  xlo .lt. x(nm1)) go to 40
!
!   compute special cases of xup in interval with xlo
!
        hup = xup(j)-x(i)
        hsum = hup+hlo
        hdiff = hup-hlo
        hup2 = hup*hup
        sum = (ypp(i+1)-ypp(i))*hsum*hdiff*(hup2+hlo2)/(24.D0*hi)
        sum = sum + ypp(i)*hdiff*(hup2+hlo*hup+hlo2)/6.D0
        sum = sum + yp(i)*hdiff*hsum/2.D0
        sum = sum + y(i)*hdiff
        ans(j) = sum
 30   continue
      return
!
!   compute integral between xlo and x(i+1) as four terms in taylor
!   polynomial and advance i to i+1
!
 40   continue
      hdiff = hi-hlo
      hsum = hi+hlo
      sum0 = y(i)*hdiff
      sum1 = yp(i)*hdiff*hsum
      sum2 = ypp(i)*hdiff*(hi2+hi*hlo+hlo2)
      sum3 = (ypp(i+1)-ypp(i))*hdiff*hsum*(hi2+hlo2)/hi
      i = i+1
!
!   locate each xup(m) in interval (x(i),x(i+1))
!
      do m = j,nup
 50      continue  
         if (xup(m) .lt. x(i+1)  .or.  i .eq. nm1) go to 60
!
!   augment integral between abscissas to include interval
!   (x(i),x(i+1)) and advance i to i+1
!
        hi = x(i+1)-x(i)
        hi2 = hi*hi
        hi3 = hi2*hi
        sum0 = sum0 + y(i)*hi
        sum1 = sum1 + yp(i)*hi2
        sum2 = sum2 + ypp(i)*hi3
        sum3 = sum3 + (ypp(i+1)-ypp(i))*hi3
        i = i+1
        go to 50
!
!   integral between x(i) and xup(m) is zero
!
 60     continue
        if (xup(m) .ne. x(i)) go to 70
        sum = ((sum3/24.D0 + sum2/6.D0) + sum1/2.D0) + sum0
        go to 90
!
!   compute integral between x(i) and xup(m) and evaluate
!   taylor polynomial in reverse order
!
 70     continue
        hup = xup(m)-x(i)
        hup2 = hup*hup
        hup3 = hup2*hup
        hup4 = hup3*hup
        hi = x(i+1)-x(i)
        psum0 = y(i)*hup
        psum1 = yp(i)*hup2
        psum2 = ypp(i)*hup3
        psum3 = (ypp(i+1)-ypp(i))*hup4/hi
        sum = (sum3+psum3)/24.D0 + (sum2+psum2)/6.D0
        sum = sum + (sum1+psum1)/2.D0
        sum = sum + (sum0+psum0)
 90     continue
        ans(m) = sum
     end do
end subroutine spliq


!> this subroutine is a translation of the algol procedure bisect,
!! num. math. 9, 386-393(1967) by barth, martin, and wilkinson.
!! handbook for auto. comp., vol.ii-linear algebra, 249-256(1971).
!!
!! this subroutine finds those eigenvalues of a tridiagonal
!! symmetric matrix between specified boundary indices,
!! using bisection.
!!
!! on input-
!!
!!    n is the order of the matrix,
!!
!!    eps1 is an absolute error tolerance for the computed
!!      eigenvalues.  if the input eps1 is non-positive,
!!      it is reset for each submatrix to a default value,
!!      namely, minus the product of the relative machine
!!      precision and the 1-norm of the submatrix,
!!
!!    d contains the diagonal elements of the input matrix,
!!
!!    e contains the subdiagonal elements of the input matrix
!!      in its last n-1 positions.  e(1) is arbitrary,
!!
!!    e2 contains the squares of the corresponding elements of e.
!!      e2(1) is arbitrary,
!!
!!    m11 specifies the lower boundary index for the desired
!!      eigenvalues,
!!
!!    m specifies the number of eigenvalues desired.  the upper
!!      boundary index m22 is then obtained as m22=m11+m-1.
!!
!! on output-
!!
!!    eps1 is unaltered unless it has been reset to its
!!      (last) default value,
!!
!!    d and e are unaltered,
!!
!!    elements of e2, corresponding to elements of e regarded
!!      as negligible, have been replaced by zero causing the
!!      matrix to split into a direct sum of submatrices.
!!      e2(1) is also set to zero,
!!
!!    lb and ub define an interval containing exactly the desired
!!      eigenvalues,
!!
!!    w contains, in its first m positions, the eigenvalues
!!      between indices m11 and m22 in ascending order,
!!
!!    ind contains in its first m positions the submatrix indices
!!      associated with the corresponding eigenvalues in w --
!!      1 for eigenvalues belonging to the first submatrix from
!!      the top, 2 for those belonging to the second submatrix, etc.,
!!
!!    ierr is set to
!!      zero       for normal return,
!!      3*n+1      if multiple eigenvalues at index m11 make
!!                 unique selection impossible,
!!      3*n+2      if multiple eigenvalues at index m22 make
!!                 unique selection impossible,
!!
!!    rv4 and rv5 are temporary storage arrays.
!!
!! note that subroutine tql1, imtql1, or tqlrat is generally faster
!! than tridib, if more than n/4 eigenvalues are to be found.
!!
!! questions and comments should be directed to B. S. garbow,
!! applied mathematics division, Argonne National Laboratory
subroutine tridib(n,eps1,d,e,e2,lb,ub,m11,m,w,ind,ierr,rv4,rv5)

   implicit none
   !Arguments
   integer, intent(in) :: n,m,m11
   integer, dimension(m), intent(out) :: ind,ierr
   real(kind=8), dimension(n), intent(in) :: d,e
   real(kind=8), dimension(n), intent(out) :: e2,rv4,rv5
   real(kind=8), dimension(m), intent(out) :: w
   real(kind=8), intent(inout) :: eps1
   real(kind=8), intent(out) :: lb,ub
   !Local variables
   real(kind=8), parameter :: machep= 2.D0**(-47) !< machine dependent parameter specifying
                                                  !! the relative precision of floating point arithmetic.
   real(kind=8) :: u,v,t1,t2,xu,x0,x1
   integer :: i,j,k,l,p,q,r,s,ii,m1,m2,m22,tag,isturm

   ierr = 0
   tag = 0
   xu = d(1)
   x0 = d(1)
   u = 0.D0
   ! look for small sub-diagonal entries and determine an interval containing all the eigenvalues
      do 40 i = 1, n
         x1 = u
         u = 0.D0
         if (i .ne. n) u = abs(e(i+1))
         xu = min(d(i)-(x1+u),xu)
         x0 = max(d(i)+(x1+u),x0)
         if (i .eq. 1) go to 20
         if (abs(e(i)) .gt. machep * (abs(d(i)) + abs(d(i-1)))) go to 40
   20    e2(i) = 0.D0
   40 continue
!
      x1 = max(abs(xu),abs(x0)) * machep * DBLE(n)
      xu = xu - x1
      t1 = xu
      x0 = x0 + x1
      t2 = x0
!     ********** determine an interval containing exactly
!                the desired eigenvalues **********
      p = 1
      q = n
      m1 = m11 - 1
      if (m1 .eq. 0) go to 75
      isturm = 1
   50 v = x1
      x1 = xu + (x0 - xu) * 0.5D0
      if (x1 .eq. v) go to 980
      go to 320
   60 if (s - m1) 65, 73, 70
   65 xu = x1
      go to 50
   70 x0 = x1
      go to 50
   73 xu = x1
      t1 = x1
   75 m22 = m1 + m
      if (m22 .eq. n) go to 90
      x0 = t2
      isturm = 2
      go to 50
   80 if (s - m22) 65, 85, 70
   85 t2 = x1
   90 q = 0
      r = 0
!     ********** establish and process next submatrix, refining
!                interval by the gerschgorin bounds **********
  100 if (r .eq. m) go to 1001
      tag = tag + 1
      p = q + 1
      xu = d(p)
      x0 = d(p)
      u = 0.D0
!
      do 120 q = p, n
         x1 = u
         u = 0.D0
         v = 0.D0
         if (q .eq. n) go to 110
         u = abs(e(q+1))
         v = e2(q+1)
  110    xu = min(d(q)-(x1+u),xu)
         x0 = max(d(q)+(x1+u),x0)
         if (v .eq. 0.D0) go to 140
  120 continue
!
  140 x1 = max(abs(xu),abs(x0)) * machep
      if (eps1 .le. 0.D0) eps1 = -x1
      if (p .ne. q) go to 180
!     ********** check for isolated root within interval **********
      if (t1 .gt. d(p) .or. d(p) .ge. t2) go to 940
      m1 = p
      m2 = p
      rv5(p) = d(p)
      go to 900
  180 x1 = x1 * DBLE(q-p+1)
      lb = max(t1,xu-x1)
      ub = min(t2,x0+x1)
      x1 = lb
      isturm = 3
      go to 320
  200 m1 = s + 1
      x1 = ub
      isturm = 4
      go to 320
  220 m2 = s
      if (m1 .gt. m2) go to 940
!     ********** find roots by bisection **********
      x0 = ub
      isturm = 5
!
      do 240 i = m1, m2
         rv5(i) = ub
         rv4(i) = lb
  240 continue
!     ********** loop for k-th eigenvalue
!                for k=m2 step -1 until m1 do --
!                (-do- not used to legalize -computed go to-) **********
      k = m2
  250    xu = lb
!     ********** for i=k step -1 until m1 do -- **********
         do 260 ii = m1, k
            i = m1 + k - ii
            if (xu .ge. rv4(i)) go to 260
            xu = rv4(i)
            go to 280
  260    continue
!
  280    if (x0 .gt. rv5(k)) x0 = rv5(k)
!     ********** next bisection step **********
  300    x1 = (xu + x0) * 0.5D0
         if ((x0 - xu) .le. (2.D0 * machep * &
            (abs(xu) + abs(x0)) + abs(eps1))) go to 420
!     ********** in-line procedure for sturm sequence **********
  320    s = p - 1
         u = 1.D0
!
         do 340 i = p, q
            if (u .ne. 0.D0) go to 325
            v = abs(e(i)) / machep
            if (e2(i) .eq. 0.D0) v = 0.D0
            go to 330
  325       v = e2(i) / u
  330       u = d(i) - x1 - v
            if (u .lt. 0.D0) s = s + 1
  340    continue
!
         go to (60,80,200,220,360), isturm
!     ********** refine intervals **********
  360    if (s .ge. k) go to 400
         xu = x1
         if (s .ge. m1) go to 380
         rv4(m1) = x1
         go to 300
  380    rv4(s+1) = x1
         if (rv5(s) .gt. x1) rv5(s) = x1
         go to 300
  400    x0 = x1
         go to 300
!     ********** k-th eigenvalue found **********
  420    rv5(k) = x1
      k = k - 1
      if (k .ge. m1) go to 250
!     ********** order eigenvalues tagged with their
!                submatrix associations **********
  900 s = r
      r = r + m2 - m1 + 1
      j = 1
      k = m1
!
      do 920 l = 1, r
         if (j .gt. s) go to 910
         if (k .gt. m2) go to 940
         if (rv5(k) .ge. w(l)) go to 915
!
         do 905 ii = j, s
            i = l + s - ii
            w(i+1) = w(i)
            ind(i+1) = ind(i)
  905    continue
!
  910    w(l) = rv5(k)
         ind(l) = tag
         k = k + 1
         go to 920
  915    j = j + 1
  920 continue
!
  940 if (q .lt. n) go to 100
      go to 1001
!     ********** set error -- interval cannot be found containing
!                exactly the desired eigenvalues **********
  980 ierr = 3 * n + isturm
 1001 lb = t1
      ub = t2

end subroutine tridib


!> this subroutine is a translation of the inverse iteration tech-
!! nique in the algol procedure tristurm by peters and wilkinson.
!! handbook for auto. comp., vol.ii-linear algebra, 418-439(1971).
!!
!! this subroutine finds those eigenvectors of a tridiagonal
!! symmetric matrix corresponding to specified eigenvalues,
!! using inverse iteration.
!!
!! on input-
!!
!!    nm must be set to the row dimension of two-dimensional
!!      array parameters as declared in the calling program
!!      dimension statement,
!!
!!    n is the order of the matrix,
!!
!!    d contains the diagonal elements of the input matrix,
!!
!!    e contains the subdiagonal elements of the input matrix
!!      in its last n-1 positions.  e(1) is arbitrary,
!!
!!    e2 contains the squares of the corresponding elements of e,
!!      with zeros corresponding to negligible elements of e.
!!      e(i) is considered negligible if it is not larger than
!!      the product of the relative machine precision and the sum
!!      of the magnitudes of d(i) and d(i-1).  e2(1) must contain
!!      0.0 if the eigenvalues are in ascending order, or 2.0
!!      if the eigenvalues are in descending order.  if  bisect,
!!      tridib, or  imtqlv  has been used to find the eigenvalues,
!!      their output e2 array is exactly what is expected here,
!!
!!    m is the number of specified eigenvalues,
!!
!!    w contains the m eigenvalues in ascending or descending order,
!!
!!    ind contains in its first m positions the submatrix indices
!!      associated with the corresponding eigenvalues in w --
!!      1 for eigenvalues belonging to the first submatrix from
!!      the top, 2 for those belonging to the second submatrix, etc.
!!
!! on output-
!!
!!    all input arrays are unaltered,
!!
!!    z contains the associated set of orthonormal eigenvectors.
!!      any vector which fails to converge is set to zero,
!!
!!    ierr is set to
!!      zero       for normal return,
!!      -r         if the eigenvector corresponding to the r-th
!!                 eigenvalue fails to converge in 5 iterations,
!!
!!    rv1, rv2, rv3, rv4, and rv6 are temporary storage arrays.
!!
!! questions and comments should be directed to b. s. garbow,
!! applied mathematics division, argonne national laboratory
subroutine tinvit(nm,n,d,e,e2,m,w,ind,z,ierr,rv1,rv2,rv3,rv4,rv6)

   implicit none
   integer :: i,j,m,n,p,q,r,s,ii,ip,jj,nm,its,tag,ierr,group
   double precision :: d(n),e(n),e2(n),w(m),z(nm,m)
   double precision :: rv1(n),rv2(n),rv3(n),rv4(n),rv6(n)
   double precision :: u,v,uk,xu,x0,x1,eps2,eps3,eps4,norm,order
   integer :: ind(m)
   !Local variables
   real(kind=8), parameter :: machep= 2.D0**(-47) !< machine dependent parameter specifying
                                                  !! the relative precision of floating point arithmetic.
!
      ierr = 0
      if (m .eq. 0) go to 1001
      tag = 0
      order = 1.D0 - e2(1)
      q = 0
!     ********** establish and process next submatrix **********
  100 p = q + 1
!
      do 120 q = p, n
         if (q .eq. n) go to 140
         if (e2(q+1) .eq. 0.D0) go to 140
  120 continue
!     ********** find vectors by inverse iteration **********
  140 tag = tag + 1
      s = 0
!
      do 920 r = 1, m
         if (ind(r) .ne. tag) go to 920
         its = 1
         x1 = w(r)
         if (s .ne. 0) go to 510
!     ********** check for isolated root **********
         xu = 1.D0
         if (p .ne. q) go to 490
         rv6(p) = 1.D0
         go to 870
  490    norm = abs(d(p))
         ip = p + 1
!
         do 500 i = ip, q
  500    norm = norm + abs(d(i)) + abs(e(i))
!     ********** eps2 is the criterion for grouping,
!                eps3 replaces zero pivots and equal
!                roots are modified by eps3,
!                eps4 is taken very small to avoid overflow **********
         eps2 = 1.0D-3 * norm
         eps3 = machep * norm
         uk = DBLE(q-p+1)
         eps4 = uk * eps3
         uk = eps4 / sqrt(uk)
         s = p
  505    group = 0
         go to 520
!     ********** look for close or coincident roots **********
  510    if (abs(x1-x0) .ge. eps2) go to 505
         group = group + 1
         if (order * (x1 - x0) .le. 0.D0) x1 = x0 + order * eps3
!     ********** elimination with interchanges and
!                initialization of vector **********
  520    v = 0.D0
!
         do 580 i = p, q
            rv6(i) = uk
            if (i .eq. p) go to 560
            if (abs(e(i)) .lt. abs(u)) go to 540
!     ********** warning -- a divide check may occur here if
!                e2 array has not been specified correctly **********
            xu = u / e(i)
            rv4(i) = xu
            rv1(i-1) = e(i)
            rv2(i-1) = d(i) - x1
            rv3(i-1) = 0.D0
            if (i .ne. q) rv3(i-1) = e(i+1)
            u = v - xu * rv2(i-1)
            v = -xu * rv3(i-1)
            go to 580
  540       xu = e(i) / u
            rv4(i) = xu
            rv1(i-1) = u
            rv2(i-1) = v
            rv3(i-1) = 0.D0
  560       u = d(i) - x1 - xu * v
            if (i .ne. q) v = e(i+1)
  580    continue
!
         if (u .eq. 0.D0) u = eps3
         rv1(q) = u
         rv2(q) = 0.D0
         rv3(q) = 0.D0
!     ********** back substitution
!                for i=q step -1 until p do -- **********
  600    do 620 ii = p, q
            i = p + q - ii
            rv6(i) = (rv6(i) - u * rv2(i) - v * rv3(i)) / rv1(i)
            v = u
            u = rv6(i)
  620    continue
!     ********** orthogonalize with respect to previous
!                members of group **********
         if (group .eq. 0) go to 700
         j = r
!
         do 680 jj = 1, group
  630       j = j - 1
            if (ind(j) .ne. tag) go to 630
            xu = 0.D0
!
            do 640 i = p, q
  640       xu = xu + rv6(i) * z(i,j)
!
            do 660 i = p, q
  660       rv6(i) = rv6(i) - xu * z(i,j)
!
  680    continue
!
  700    norm = 0.D0
!
         do 720 i = p, q
  720    norm = norm + abs(rv6(i))
!
         if (norm .ge. 1.D0) go to 840
!     ********** forward substitution **********
         if (its .eq. 5) go to 830
         if (norm .ne. 0.D0) go to 740
         rv6(s) = eps4
         s = s + 1
         if (s .gt. q) s = p
         go to 780
  740    xu = eps4 / norm
!
         do 760 i = p, q
  760    rv6(i) = rv6(i) * xu
!     ********** elimination operations on next vector
!                iterate **********
  780    do 820 i = ip, q
            u = rv6(i)
!     ********** if rv1(i-1) .eq. e(i), a row interchange
!                was performed earlier in the
!                triangularization process **********
            if (rv1(i-1) .ne. e(i)) go to 800
            u = rv6(i-1)
            rv6(i-1) = rv6(i)
  800       rv6(i) = u - rv4(i) * rv6(i-1)
  820    continue
!
         its = its + 1
         go to 600
!     ********** set error -- non-converged eigenvector **********
  830    ierr = -r
         xu = 0.D0
         go to 870
!     ********** normalize so that sum of squares is
!                1 and expand to full order **********
  840    u = 0.D0
!
         do 860 i = p, q
  860    u = u + rv6(i)**2
!
         xu = 1.D0 / sqrt(u)
!
  870    do 880 i = 1, n
  880    z(i,r) = 0.D0
!
         do 900 i = p, q
  900    z(i,r) = rv6(i) * xu
!
         x0 = x1
  920 continue
!
      if (q .lt. n) go to 100
 1001 return

end subroutine tinvit


!> SPLINT EVALUATES A CUBIC SPLINE AND ITS FIRST AND SECOND
!!     DERIVATIVES AT THE ABSCISSAS IN XI.  THE SPLINE (WHICH
!!     IS DEFINED BY X, Y, AND YPP) MAY HAVE BEEN DETERMINED BY
!!     SPLIFT OR SMOO OR ANY OTHER SPLINE FITTING ROUTINE THAT
!!     PROVIDES SECOND DERIVATIVES.
!!
!! DESCRIPTION OF ARGUMENTS
!!     THE USER MUST DIMENSION ALL ARRAYS APPEARING IN THE CALL LIST
!!     E.G.  X(N), Y(N), YPP(N), XI(NI), YI(NI), YPI(NI), YPPI(NI)
!!
!!   --INPUT--
!!
!!     X   - ARRAY OF ABSCISSAS (IN INCREASING ORDER) THAT DEFINE TH
!!           SPLINE.  USUALLY X IS THE SAME AS X IN SPLIFT OR SMOO.
!!     Y   - ARRAY OF ORDINATES THAT DEFINE THE SPLINE.  USUALLY Y I
!!           THE SAME AS Y IN SPLIFT OR AS R IN SMOO.
!!     YPP - ARRAY OF SECOND DERIVATIVES THAT DEFINE THE SPLINE.
!!           USUALLY YPP IS THE SAME AS YPP IN SPLIFT OR R2 IN SMOO.
!!     N   - THE NUMBER OF DATA POINTS THAT DEFINE THE SPLINE.
!!           THE ARRAYS X, Y, AND YPP MUST BE DIMENSIONED AT LEAST N
!!           N MUST BE GREATER THAN OR EQUAL TO 2.
!!     XI  - THE ABSCISSA OR ARRAY OF ABSCISSAS (IN ARBITRARY ORDER)
!!           AT WHICH THE SPLINE IS TO BE EVALUATED.
!!           EACH XI(K) THAT LIES BETWEEN X(1) AND X(N) IS A CASE OF
!!           INTERPOLATION.  EACH XI(K) THAT DOES NOT LIE BETWEEN
!!           X(1) AND X(N) IS A CASE OF EXTRAPOLATION.  BOTH CASES
!!           ARE ALLOWED.  SEE DESCRIPTION OF KERR.
!!     NI  - THE NUMBER OF ABSCISSAS AT WHICH THE SPLINE IS TO BE
!!           EVALUATED.  IF NI IS GREATER THAN 1, THEN XI, YI, YPI,
!!           AND YPPI MUST BE ARRAYS DIMENSIONED AT LEAST NI.
!!           NI MUST BE GREATER THAN OR EQUAL TO 1.
!!
!!   --OUTPUT--
!!
!!     YI  - ARRAY OF VALUES OF THE SPLINE (ORDINATES) AT XI.
!!     YPI - ARRAY OF VALUES OF THE FIRST DERIVATIVE OF SPLINE AT XI
!! 
!!     YPPI- ARRAY OF VALUES OF SECOND DERIVATIVES OF SPLINE AT XI.
!!     KERR- A STATUS CODE
!!         --NORMAL CODES
!!            1 MEANS THAT THE SPLINE WAS EVALUATED AT EACH ABSCISSA
!!              IN XI USING ONLY INTERPOLATION.
!!            2 MEANS THAT THE SPLINE WAS EVALUATED AT EACH ABSCISSA
!!              IN XI, BUT AT LEAST ONE EXTRAPOLATION WAS PERFORMED.
!!         -- ABNORMAL CODE
!!            3 MEANS THAT THE REQUESTED NUMBER OF EVALUATIONS, NI,
!!             WAS NOT POSITIVE.
!!
!! @author Written by Rondall E. Jones
subroutine SPLINT (X,Y,YPP,N,XI,YI,YPI,YPPI,NI,KERR)
         
   implicit none
   !Arguments
   Integer, Intent(in) :: N,NI
   Real(kind=8), Intent(in) :: X(N),Y(N),YPP(N),XI(NI)
   Integer, Intent(out) :: KERR
   Real(kind=8), Intent(out) :: YI(NI),YPI(NI),YPPI(NI)
   !Local variables
   Integer :: nm1,i,K,IL,IR
   Real(8) :: H,H2,XR,XR2,XR3,XL,XL2,XL3,XX
  
   ! CHECK INPUT
   IF (NI) 1,1,2
 1    CONTINUE
    !    1 CALL ERRCHK(67,67HIN SPLINT,  THE REQUESTED NUMBER OF INTERPOLATI
    !     1NS WAS NOT POSITIVE)
      KERR = 3
      RETURN
 2    KERR = 1
      NM1= N-1

    !
    !    K IS INDEX ON VALUE OF XI BEING WORKED ON.  XX IS THAT VALUE.
    !    I IS CURRENT INDEX INTO X ARRAY.
    !
      K  = 1
      XX = XI(1)
      IF (XX.LT.X(1)) GO TO 90
      IF (XX.GT.X(N)) GO TO 80
      IL = 1
      IR = N
!
!   BISECTION SEARCH
!
 10   I  = (IL+IR)/2
      IF (I.EQ.IL) GO TO 100
      IF (XX-X(I)) 20,100,30
 20   IR = I
      GO TO 10
 30   IL = I
      GO TO 10
!
!     LINEAR FORWARD SEARCH
!
 50   IF (XX-X(I+1)) 100,100,60
 60   IF (I.GE.NM1) GO TO 80
      I  = I+1
      GO TO 50
!
! EXTRAPOLATION
!
 80   KERR = 2
      I  = NM1
      GO TO 100
 90   KERR = 2
      I  = 1
!
!     INTERPOLATION
!
 100  H  = X(I+1) - X(I)
      H2 = H*H
      XR = (X(I+1)-XX)/H
      XR2= XR*XR
      XR3= XR*XR2
      XL = (XX-X(I))/H
      XL2= XL*XL
      XL3= XL*XL2
      YI(K) = Y(I)*XR + Y(I+1)*XL-H2*(YPP(I)*(XR-XR3) + YPP(I+1)*(XL-XL3))/6.0D0
      YPI(K) = (Y(I+1)-Y(I))/H+H*(YPP(I)*(1.0D0-3.0D0*XR2)-YPP(I+1)* (1.0D0-3.0D0*XL2))/6.0D0
      YPPI(K) = YPP(I)*XR + YPP(I+1)*XL
!
!     NEXT POINT
!
      IF (K.GE.NI) RETURN
      K = K+1
      XX = XI(K)
      IF (XX.LT.X(1)) GO TO 90
      IF (XX.GT.X(N)) GO TO 80
      IF (XX-XI(K-1)) 110,100,50
 110  IL = 1
      IR = I+1
      GO TO 10

END subroutine SPLINT
