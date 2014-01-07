#!/bin/bash

create_deb_pkg()
{
    if [ $# -ne 2 ]; then
        die "*** invalid call to create_deb_pkg ***"
    fi

    local pkg="$1"
    local ver="$2"

    export_ref "${pkg}" "${ver}"

    # finish building package from scratch

    pushd "${build_dir}" > /dev/null

    dh_make --yes --indep --createorig
    
    rm .gitignore debian/*.{ex,EX} debian/README.*

    # drop in templated versions of control, install, changelog and copyright
    # debuild

    return 0
}

check_for_version()
{

    if [ $# -ne 1 ]; then
        die "*** invalid call to check_for_version() ***"
    fi

    local matched_ver=''
    local match_found=false
    local ver=$1

    # check if cwd is actually a git repo
    git status > /dev/null 2>&1
    gitrc=$?
    if [ $gitrc -eq 128 ]; then
        die "*** Not a git repository (or any of the parent directories) ***"
    elif [ $gitrc -ne 0 ]; then
        die "*** unexpected git error ***"
    fi

    # check for matching tag or branch
    matched_ver=`git tag | awk /^${ver}$/'{print $1}'`
    if [ -n "${matched_ver}" ]; then
        match_found=true
        return 0
    fi

    matched_ver=`git branch | awk /${ver}/'{print $2}'`
    if [ -n "${matched_ver}" ]; then
        match_found=true
        return 0
    fi

    return 1
}

export_ref()
{
    if [ $# -ne 2 ]; then
        die "*** invalid call to export_ref ***"
    fi

    local pkg=$1
    local ver=$2
    local ver_exists=''

    check_for_version "${ver}"
    local ver_exists=$?

    if [ $ver_exists -ne 0 ]; then
        die "*** specified version is not a branch or tag ***"
    fi
    
    # git archive v0.0.1-rc1 | tar -x -C ~/pkgbuild/quartz-ltr-0.0.1~rc1/
    git archive "${ver}" | tar -x -C "${build_dir}"/ 

    return 0
}

create_orig_tarball()
{
    if [ $# -ne 2 ]; then
        die "*** invalid call to create_orig_tarball() ***"
    fi

    local ver_exists=''

    check_for_version "${ver}"
    ver_exists=$?

    if [ $ver_exists -ne 0 ]; then
        die "*** specified version is not a branch or tag ***"
    fi

    # git archive --prefix=./ --format=tar v0.0.1-rc2 | xz -c > ~/pkgbuild/pentaho-reporting_0.0.1~rc2.orig.tar.xz
    git archive --prefix=./ --format=tar "${ver}" | xz -c > "${BUILDROOT}/${pkg}_${version}~${rc}.orig.tar.xz"
}

# function for creating packages for next upstream release
pkg_new_release()
{
    if [ $# -ne 2 ]; then
        die "*** invalid call to pkg_new_release() ***"
    fi

    local pkg="$1"
    local ver="$2"
    local aptrc=''

    pushd ${BUILDROOT} > /dev/null

    apt-get source ${pkg}
    aptrc=$?
    if [ $aptrc -ne 0 ] ; then
        die "*** unable to install source package for ${pkg} ***"
    fi

    popd > /dev/null

    pushd "${SOURCESDIR}/${pkg}" > /dev/null

    # export version to build_dir
    export_ref "${pkg}" "${ver}"

    # create lzma compressed tarball of orig upstream release
    create_orig_tarball "${pkg}" "${ver}"

    popd > /dev/null

    # unpack debian tarball from previous version into build_dir
    # version bump the changelog

#    export_ref "${pkg}" "${ver}"
}

get_commit_msgs_between_two_greatest_tags()
{
    range=`git tag | grep -e '^\([[:digit:]]\)\{1,2\}.\([[:digit:]]\)\{1,2\}.\([[:digit:]]\)\{1,3\}\(-rc[[:digit:]]\+\)\?$' | sort -r | head -n 2 | xargs | awk '{print $2".."$1}'`
    echo "`git log --format=%s%b ${range}`"
}

clean_buildroot()
{
    rm -rf ${BUILDROOT}/*
}

# vim: ts=4 sw=4 expandtab

