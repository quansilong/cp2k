#!/bin/bash -e
[ "${BASH_SOURCE[0]}" ] && SCRIPT_NAME="${BASH_SOURCE[0]}" || SCRIPT_NAME=$0
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_NAME")" && pwd -P)"

openblas_ver="0.3.7" # Keep in sync with get_openblas_arch.sh
openblas_sha256="bde136122cef3dd6efe2de1c6f65c10955bbb0cc01a520c2342f5287c28f9379"
openblas_pkg="OpenBLAS-${openblas_ver}.tar.gz"

source "${SCRIPT_DIR}"/common_vars.sh
source "${SCRIPT_DIR}"/tool_kit.sh
source "${SCRIPT_DIR}"/signal_trap.sh
source "${INSTALLDIR}"/toolchain.conf
source "${INSTALLDIR}"/toolchain.env

[ -f "${BUILDDIR}/setup_openblas" ] && rm "${BUILDDIR}/setup_openblas"

OPENBLAS_CFLAGS=''
OPENBLAS_LDFLAGS=''
OPENBLAS_LIBS=''

! [ -d "${BUILDDIR}" ] && mkdir -p "${BUILDDIR}"
cd "${BUILDDIR}"

case "$with_openblas" in
    __INSTALL__)
        echo "==================== Installing OpenBLAS ===================="
        pkg_install_dir="${INSTALLDIR}/openblas-${openblas_ver}"
        install_lock_file="$pkg_install_dir/install_successful"
        if verify_checksums "${install_lock_file}" ; then
            echo "openblas-${openblas_ver} is already installed, skipping it."
        else
            if [ -f ${openblas_pkg} ] ; then
                echo "${openblas_pkg} is found"
            else
                download_pkg ${DOWNLOADER_FLAGS} ${openblas_sha256} \
                             https://www.cp2k.org/static/downloads/${openblas_pkg}
            fi

            echo "Installing from scratch into ${pkg_install_dir}"
            [ -d OpenBLAS-${openblas_ver} ] && rm -rf OpenBLAS-${openblas_ver}
            tar -zxf ${openblas_pkg}
            cd OpenBLAS-${openblas_ver}

            # First attempt to make openblas using auto detected
            # TARGET, if this fails, then make with forced
            # TARGET=NEHALEM
            #
            ( make -j $NPROCS \
                   MAKE_NB_JOBS=0 \
                   USE_THREAD=0 \
                   CC="${CC}" \
                   FC="${FC}" \
                   PREFIX="${pkg_install_dir}" \
                   > make.serial.log 2>&1 \
            ) || ( \
              make clean > clean.serial_nehalem.log 2>&1; \
              make -j $NPROCS \
                   MAKE_NB_JOBS=0 \
                   TARGET=NEHALEM \
                   USE_THREAD=0 \
                   CC="${CC}" \
                   FC="${FC}" \
                   PREFIX="${pkg_install_dir}" \
                   > make.serial_nehalem.log 2>&1 \
            )
            make -j $NPROCS \
                 MAKE_NB_JOBS=0 \
                 USE_THREAD=0 \
                 CC="${CC}" \
                 FC="${FC}" \
                 PREFIX="${pkg_install_dir}" \
                 install > install.serial.log 2>&1
            if [ $ENABLE_OMP = "__TRUE__" ] ; then
               make clean > clean.omp.log 2>&1
               # wrt NUM_THREADS=64: this is what the most common Linux distros seem to choose atm
               #                     for a good compromise between memory usage and scalability
               ( make -j $NPROCS \
                      MAKE_NB_JOBS=0 \
                      NUM_THREADS=64 \
                      USE_THREAD=1 \
                      USE_OPENMP=1 \
                      LIBNAMESUFFIX=omp \
                      CC="${CC}" \
                      FC="${FC}" \
                      PREFIX="${pkg_install_dir}" \
                      > make.omp.log 2>&1 \
               ) || ( \
                 make clean > clean.omp_nehalem.log 2>&1; \
                 make -j $NPROCS \
                      MAKE_NB_JOBS=0 \
                      TARGET=NEHALEM \
                      NUM_THREADS=64 \
                      USE_THREAD=1 \
                      USE_OPENMP=1 \
                      LIBNAMESUFFIX=omp \
                      CC="${CC}" \
                      FC="${FC}" \
                      PREFIX="${pkg_install_dir}" \
                      > make.omp_nehalem.log 2>&1 \
               )
               make -j $NPROCS \
                    MAKE_NB_JOBS=0 \
                    NUM_THREADS=64 \
                    USE_THREAD=1 \
                    USE_OPENMP=1 \
                    LIBNAMESUFFIX=omp \
                    CC="${CC}" \
                    FC="${FC}" \
                    PREFIX="${pkg_install_dir}" \
                    install > install.omp.log 2>&1
            fi
            cd ..
            write_checksums "${install_lock_file}" "${SCRIPT_DIR}/$(basename ${SCRIPT_NAME})"
        fi
        OPENBLAS_CFLAGS="-I'${pkg_install_dir}/include'"
        OPENBLAS_LDFLAGS="-L'${pkg_install_dir}/lib' -Wl,-rpath='${pkg_install_dir}/lib'"
        ;;
    __SYSTEM__)
        echo "==================== Finding LAPACK from system paths ===================="
        # assume that system openblas is threaded
        check_lib -lopenblas "OpenBLAS"
        add_include_from_paths OPENBLAS_CFLAGS "openblas_config.h" $INCLUDE_PATHS
        add_lib_from_paths OPENBLAS_LDFLAGS "libopenblas.*" $LIB_PATHS
        ;;
    __DONTUSE__)
        ;;
    *)
        echo "==================== Linking LAPACK to user paths ===================="
        pkg_install_dir="$with_openblas"
        check_dir "${pkg_install_dir}/include"
        check_dir "${pkg_install_dir}/lib"
        OPENBLAS_CFLAGS="-I'${pkg_install_dir}/include'"
        OPENBLAS_LDFLAGS="-L'${pkg_install_dir}/lib' -Wl,-rpath='${pkg_install_dir}/lib'"
        ;;
esac
if [ "$with_openblas" != "__DONTUSE__" ] ; then
    OPENBLAS_LIBS="-lopenblas"
    OPENBLAS_LIBS_OMP="-lopenblas"
    if [ "$with_openblas" != "__SYSTEM__" ] ; then
        OPENBLAS_LIBS_OMP="-lopenblas_omp"
        cat <<EOF > "${BUILDDIR}/setup_openblas"
prepend_path LD_LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path LD_RUN_PATH "$pkg_install_dir/lib"
prepend_path LIBRARY_PATH "$pkg_install_dir/lib"
prepend_path CPATH "$pkg_install_dir/include"
EOF
        cat "${BUILDDIR}/setup_openblas" >> $SETUPFILE
    fi
    cat <<EOF >> "${BUILDDIR}/setup_openblas"
export OPENBLAS_CFLAGS="${OPENBLAS_CFLAGS}"
export OPENBLAS_LDFLAGS="${OPENBLAS_LDFLAGS}"
export OPENBLAS_LIBS="IF_OMP(${OPENBLAS_LIBS_OMP}|${OPENBLAS_LIBS})"
export FAST_MATH_CFLAGS="\${FAST_MATH_CFLAGS} ${OPENBLAS_CFLAGS}"
export FAST_MATH_LDFLAGS="\${FAST_MATH_LDFLAGS} ${OPENBLAS_LDFLAGS}"
export FAST_MATH_LIBS="\${FAST_MATH_LIBS} IF_OMP(${OPENBLAS_LIBS_OMP}|${OPENBLAS_LIBS})"
EOF
fi

# update toolchain environment
load "${BUILDDIR}/setup_openblas"
export -p > "${INSTALLDIR}/toolchain.env"

cd "${ROOTDIR}"
report_timing "openblas"
