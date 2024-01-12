# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Build METIS and ParMETIS (from PETSc forks)
#

# Force build order
set(METIS_DEPENDENCIES)
set(PARMETIS_DEPENDENCIES metis)

# METIS does not add OpenMP flags
set(METIS_CFLAGS "${CMAKE_C_FLAGS}")
set(METIS_MATH_LIB "m")
if(PALACE_WITH_OPENMP)
  find_package(OpenMP REQUIRED)
  set(METIS_CFLAGS "${OpenMP_C_FLAGS} ${HYPRE_CFLAGS}")
  string(REPLACE ";" "$<SEMICOLON>" METIS_OPENMP_LIBRARIES "${OpenMP_C_LIBRARIES}")
  set(METIS_MATH_LIB "${METIS_OPENMP_LIBRARIES}$<SEMICOLON>${METIS_MATH_LIB}")
endif()

# Build METIS
set(METIS_OPTIONS ${PALACE_SUPERBUILD_DEFAULT_ARGS})
list(APPEND METIS_OPTIONS
  "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
  "-DCMAKE_C_FLAGS=${METIS_CFLAGS}"
  "-DGKLIB_PATH=${CMAKE_BINARY_DIR}/extern/metis/GKlib"
  "-DGKRAND=1"
  "-DMATH_LIB=${METIS_MATH_LIB}"
)
if(CMAKE_BUILD_TYPE MATCHES "Debug|debug|DEBUG")
  list(APPEND METIS_OPTIONS "-DDEBUG=1")
else()
  list(APPEND METIS_OPTIONS "-DDEBUG=0")
endif()
if(BUILD_SHARED_LIBS)
  list(APPEND METIS_OPTIONS "-DSHARED=1")
else()
  list(APPEND METIS_OPTIONS "-DSHARED=0")
endif()
if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
  list(APPEND METIS_OPTIONS "-DMSVC=1")
else()
  list(APPEND METIS_OPTIONS "-DMSVC=0")
endif()
if(PALACE_WITH_64BIT_INT)
  list(APPEND METIS_OPTIONS "-DMETIS_USE_LONGINDEX=1")
else()
  list(APPEND METIS_OPTIONS "-DMETIS_USE_LONGINDEX=0")
endif()
# list(APPEND METIS_OPTIONS "-DMETIS_USE_DOUBLEPRECISION=1")

string(REPLACE ";" "; " METIS_OPTIONS_PRINT "${METIS_OPTIONS}")
message(STATUS "METIS_OPTIONS: ${METIS_OPTIONS_PRINT}")

# Some build fixes
set(METIS_PATCH_FILES
  "${CMAKE_SOURCE_DIR}/extern/patch/metis/patch_build.diff"
)

include(ExternalProject)
ExternalProject_Add(metis
  DEPENDS           ${METIS_DEPENDENCIES}
  GIT_REPOSITORY    ${EXTERN_METIS_URL}
  GIT_TAG           ${EXTERN_METIS_GIT_TAG}
  SOURCE_DIR        ${CMAKE_BINARY_DIR}/extern/metis
  BINARY_DIR        ${CMAKE_BINARY_DIR}/extern/metis-build
  INSTALL_DIR       ${CMAKE_INSTALL_PREFIX}
  PREFIX            ${CMAKE_BINARY_DIR}/extern/metis-cmake
  UPDATE_COMMAND    ""
  PATCH_COMMAND     git apply "${METIS_PATCH_FILES}"
  CONFIGURE_COMMAND ${CMAKE_COMMAND} <SOURCE_DIR> ${METIS_OPTIONS}
  TEST_COMMAND      ""
)

# Build ParMETIS (as needed)
if(PALACE_WITH_SUPERLU OR PALACE_WITH_STRUMPACK)
  set(PARMETIS_OPTIONS ${PALACE_SUPERBUILD_DEFAULT_ARGS})
  list(APPEND PARMETIS_OPTIONS
    "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
    "-DCMAKE_C_FLAGS=${CMAKE_C_FLAGS}"
    "-DGKLIB_PATH=${CMAKE_BINARY_DIR}/extern/metis/GKlib"
    "-DMETIS_PATH=${CMAKE_INSTALL_PREFIX}"
  )
  if(BUILD_SHARED_LIBS)
    list(APPEND PARMETIS_OPTIONS "-DSHARED=1")
  else()
    list(APPEND PARMETIS_OPTIONS "-DSHARED=0")
  endif()
  if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
    list(APPEND PARMETIS_OPTIONS "-DMSVC=1")
  else()
    list(APPEND PARMETIS_OPTIONS "-DMSVC=0")
  endif()

  # User might specify the MPI compiler wrappers directly, otherwise we need to supply MPI
  # as found from the CMake module
  if(NOT MPI_FOUND)
    message(FATAL_ERROR "MPI is not found when trying to build ParMETIS")
  endif()
  if(NOT CMAKE_C_COMPILER STREQUAL MPI_C_COMPILER)
    list(APPEND PARMETIS_OPTIONS
      "-DMPI_LIBRARIES=${MPI_C_LIBRARIES}"
      "-DMPI_INCLUDE_PATH=${MPI_C_INCLUDE_DIRS}"
    )
  endif()

  string(REPLACE ";" "; " PARMETIS_OPTIONS_PRINT "${PARMETIS_OPTIONS}")
  message(STATUS "PARMETIS_OPTIONS: ${PARMETIS_OPTIONS_PRINT}")

  # Some build fixes
  set(PARMETIS_PATCH_FILES
    "${CMAKE_SOURCE_DIR}/extern/patch/parmetis/patch_build.diff"
  )

  ExternalProject_Add(parmetis
    DEPENDS           ${PARMETIS_DEPENDENCIES}
    GIT_REPOSITORY    ${EXTERN_PARMETIS_URL}
    GIT_TAG           ${EXTERN_PARMETIS_GIT_TAG}
    SOURCE_DIR        ${CMAKE_BINARY_DIR}/extern/parmetis
    BINARY_DIR        ${CMAKE_BINARY_DIR}/extern/parmetis-build
    INSTALL_DIR       ${CMAKE_INSTALL_PREFIX}
    PREFIX            ${CMAKE_BINARY_DIR}/extern/parmetis-cmake
    UPDATE_COMMAND    ""
    PATCH_COMMAND     git apply "${PARMETIS_PATCH_FILES}"
    CONFIGURE_COMMAND ${CMAKE_COMMAND} <SOURCE_DIR> "${PARMETIS_OPTIONS}"
    TEST_COMMAND      ""
  )
endif()

# Save variables to cache
if(BUILD_SHARED_LIBS)
  set(_METIS_LIB_SUFFIX ${CMAKE_SHARED_LIBRARY_SUFFIX})
else()
  set(_METIS_LIB_SUFFIX ${CMAKE_STATIC_LIBRARY_SUFFIX})
endif()
set(METIS_LIBRARIES ${CMAKE_INSTALL_PREFIX}/lib/libmetis${_METIS_LIB_SUFFIX} CACHE STRING
  "List of library files for METIS"
)
if(PALACE_WITH_SUPERLU OR PALACE_WITH_STRUMPACK)
  set(PARMETIS_LIBRARIES ${CMAKE_INSTALL_PREFIX}/lib/libparmetis${_METIS_LIB_SUFFIX} CACHE STRING
    "List of library files for ParMETIS"
  )
endif()
