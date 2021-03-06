!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2020  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief types for task lists
!> \par History
!>      01.2008 [Joost VandeVondele] refactered out of qs_collocate / qs_integrate
!> \author Joost VandeVondele
! **************************************************************************************************
MODULE task_list_types

   USE kinds,                           ONLY: dp,&
                                              int_8
#include "./base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'task_list_types'

! **************************************************************************************************
   TYPE task_list_type
      INTEGER(kind=int_8), DIMENSION(:, :), POINTER :: tasks
      REAL(KIND=dp), DIMENSION(:, :), POINTER       :: dist_ab
      INTEGER(kind=int_8), DIMENSION(:), POINTER    :: atom_pair_send, atom_pair_recv
      INTEGER                                       :: ntasks
      INTEGER, DIMENSION(:, :), POINTER             :: taskstart, taskstop
      INTEGER, DIMENSION(:), POINTER                :: npairs
   END TYPE task_list_type

   PUBLIC :: task_list_type

   PUBLIC :: allocate_task_list, &
             deallocate_task_list

CONTAINS

! **************************************************************************************************
!> \brief allocates and initialised the components of the task_list_type
!> \param task_list ...
!> \par History
!>      01.2008 created [Joost VandeVondele]
! **************************************************************************************************
   SUBROUTINE allocate_task_list(task_list)
      TYPE(task_list_type), POINTER                      :: task_list

      CHARACTER(len=*), PARAMETER :: routineN = 'allocate_task_list', &
         routineP = moduleN//':'//routineN

      ALLOCATE (task_list)

      NULLIFY (task_list%tasks)
      NULLIFY (task_list%dist_ab)
      NULLIFY (task_list%atom_pair_send)
      NULLIFY (task_list%atom_pair_recv)
      NULLIFY (task_list%taskstart)
      NULLIFY (task_list%taskstop)
      NULLIFY (task_list%npairs)
      task_list%ntasks = 0
   END SUBROUTINE allocate_task_list

! **************************************************************************************************
!> \brief deallocates the components and the object itself
!> \param task_list ...
!> \par History
!>      01.2008 created [Joost VandeVondele]
! **************************************************************************************************
   SUBROUTINE deallocate_task_list(task_list)
      TYPE(task_list_type), POINTER                      :: task_list

      CHARACTER(len=*), PARAMETER :: routineN = 'deallocate_task_list', &
         routineP = moduleN//':'//routineN

      IF (ASSOCIATED(task_list%tasks)) THEN
         DEALLOCATE (task_list%tasks)
      ENDIF
      IF (ASSOCIATED(task_list%dist_ab)) THEN
         DEALLOCATE (task_list%dist_ab)
      ENDIF
      IF (ASSOCIATED(task_list%atom_pair_send)) THEN
         DEALLOCATE (task_list%atom_pair_send)
      ENDIF
      IF (ASSOCIATED(task_list%atom_pair_recv)) THEN
         DEALLOCATE (task_list%atom_pair_recv)
      ENDIF
      IF (ASSOCIATED(task_list%taskstart)) THEN
         DEALLOCATE (task_list%taskstart)
      ENDIF
      IF (ASSOCIATED(task_list%taskstop)) THEN
         DEALLOCATE (task_list%taskstop)
      ENDIF
      IF (ASSOCIATED(task_list%npairs)) THEN
         DEALLOCATE (task_list%npairs)
      ENDIF

      DEALLOCATE (task_list)
   END SUBROUTINE deallocate_task_list
END MODULE task_list_types
