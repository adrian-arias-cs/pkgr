#!/bin/bash

create_deb_pkg()
{
    if [ $# -ne 2 ]; then
        die "*** invalid call to create_deb_pkg ***"
    fi

    local pkg="$1"
    local ver="$2"

    local controlfile="${build_dir}/debian/control"

    export_ref "${pkg}" "${ver}"

    # finish building package from scratch

    pushd "${build_dir}" > /dev/null

    dh_make --yes --indep --createorig
    
    rm .gitignore debian/*.{ex,EX} debian/README.*

    ex "${controlfile}" <<-EOEX
    :%s/^Section:\s\{1}.*$/Section: ${SECTION}
    :%s,^Homepage:\s\{1}.*$,Homepage: ${HOMEPAGE}
    :wq
EOEX

    local d_line=$(ex ${controlfile} <<-EOEX
    /^Depends:
    :.p
EOEX
)
    local misc_deps=`echo $d_line | awk -F': ' '{print $2}'`
#    echo "$poo" 
    depends="$misc_deps, $RUNTIME_DEPS"
    #echo "$depends"
    ex ${controlfile} <<-EOEX
    :%s/^Depends:\s\{1}.*$/Depends: ${depends}
    :wq
EOEX

    local desc_lines=$( echo "${DESCRIPTION}" | fold -s )
    declare -a lines
    local i=1

    while read line
    do
        lines[$i]=${line}
        ((i++))
    done <<< "${desc_lines}"

    for line in "${!lines[@]}"
    do
        if [ $line -eq 1 ]; then
            # if the first line of the descript search and replace ^Description: with proper value
            ex "${controlfile}" <<-EOEX
            :%s/^Description:\s\{1}.*$/Description: ${lines[$line]}
            :wq
EOEX
        else
            # or else, append the line
            echo " ${lines[$line]}" >> ${controlfile}
        fi
    done

    # drop in templated versions of control, install, changelog and copyright
    debuild

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
        clean_buildroot
        die "*** specified version is not a branch or tag ***"
    fi
    
    # git archive v0.0.1-rc1 | tar -x -C ~/pkgbuild/quartz-ltr-0.0.1~rc1/
    git archive "${ver}" | tar -x -C "${build_dir}"/ 

    return 0
}

create_orig_tarball()
{
    if [ $# -ne 2 ]; then
        clean_buildroot
        die "*** invalid call to create_orig_tarball() ***"
    fi

    local ver_exists=''
    local orig_tarball=''

    check_for_version "${ver}"
    ver_exists=$?

    if [ $ver_exists -ne 0 ]; then
        clean_buildroot
        die "*** specified version is not a branch or tag ***"
    fi

    # git archive --prefix=./ --format=tar v0.0.1-rc2 | xz -c > ~/pkgbuild/pentaho-reporting_0.0.1~rc2.orig.tar.xz
    if [ -n "${rc}" ]; then
        orig_tarball="${BUILDROOT}/${pkg}_${version}~${rc}.orig.tar.xz"
    else
        orig_tarball="${BUILDROOT}/${pkg}_${version}.orig.tar.xz"
    fi

    git archive --prefix=./ --format=tar "${ver}" | xz -c > "${orig_tarball}"
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
    local prever=''

    # export version to build_dir
    export_ref "${pkg}" "${ver}"

    # create lzma compressed tarball of orig upstream release
    create_orig_tarball "${pkg}" "${ver}"

    prever=`get_previous_version ${ver}`

    if [ -z "${prever}" -o $? -ne 0 ]; then
        clean_buildroot
        die "*** unable to determine previous version ***"
    fi
    msgs=`get_commit_msgs_between_two_tags ${prever} ${ver}`

    # unpack debian tarball from previous version into build_dir

    pushd ${PKGSTORE}/ > /dev/null

    local pv=`echo "${prever}" | awk -F'-' '{print $1}'`
    local pr=`echo "${prever}" | awk -F'-' '{print $2}'`
    # find the debian tarball of the previous version's last debian revision 
    local prdt=`find . -regextype posix-egrep -iregex "(\.\/){1}${pkg}_${pv}(~${pr})?-([[:digit:]]){1}\.debian\.tar\.gz$" \
        | sort -r | head -n 1`
    #local debian_tarball="${pkg}_${pv}~${pr}-1.debian.tar.gz"
    local debian_tarball=`echo "${prdt}" | awk -F'/' '{print $2}'`
    if [ -f "$debian_tarball" ]; then
        tar xzvf "$debian_tarball" -C ${build_dir}/ > /dev/null
    else
        clean_buildroot
        die "*** Invalid path to debian tarball. Ensure the initial release is available in ${PKGSTORE} ***"
    fi

    popd > /dev/null

    pushd ${build_dir}/debian > /dev/null

    # the trailing "-1" represents the package build version.
    # this should be incremented each time changes are made to the
    # debian files.
    if [ -n "${rc}" ]; then
        dch -v "${version}~${rc}-1" "New upstream release"
    else
        dch -v "${version}-1" "New upstream release"
    fi

    # for each commit message
    while read -r line
    do
        # append a new entry in the changelog
        dch -a "${line}"
    done < <(echo "$msgs")
    # changelog is prepared, mark is ready for release.
    dch -r --distribution unstable ""

    # initiate the package build
    # TODO: make passphrase an environment variable/option
    debuild --source-option=-i'version.txt|target\/|(?:^|/).*~$|(?:^|/)\.#.*$|(?:^|/)\..*\.sw.$|(?:^|/),,.*(?:$|/.*$)|(?:^|/)(?:DEADJOE|\.arch-inventory|\.(?:bzr|cvs|hg|git)ignore)$|(?:^|/)(?:CVS|RCS|\.deps|\{arch\}|\.arch-ids|\.svn|\.hg(?:tags|sigs)?|_darcs|\.git(?:attributes|modules)?|\.shelf|_MTN|\.be|\.bzr(?:\.backup|tags)?)(?:$|/.*$)' -p'gpg --passphrase connectsolutions'

    popd > /dev/null
}

get_previous_version()
{
    # this function requires only 1 parameter, the version string to operate on
    if [ $# -ne 1 ]; then
        die "*** invalid call to get_previous_version() ***"
    fi

    local rel=''
    local ver=''

    # normalize input parameter.
    if [ `echo ${1:0:1}` = "v" ]; then
        ver=${1:1}
    else
        ver=${1}
    fi

    # get a list of tags matching the supporting format, sort numerically,
    # strip out any preceding 'v' characters, print only the releases less than
    # the value of the version parameter (less the 'v'), and print the second item.
    rel=`git tag | grep -e '^\(v\)\?\([[:digit:]]\)\{1,2\}.\([[:digit:]]\)\{1,2\}.\([[:digit:]]\)\{1,3\}\(-rc[[:digit:]]\+\)\?$' |
        sort -r | tr -d 'v' | awk '{
            if (system("dpkg --compare-versions "$1" le '${ver}'") == 0)
            {
                    print $1
            }
        }' | head -n 2 | xargs | awk '{print $2}'`

    # if the captured value is a null string, indicate faulure.
    if [ -z  "${rel}" ]; then
        return 1
    fi

    # echo here to return the value to the variable assignment used by the callee
    echo "${rel}"
    return 0
}

get_commit_msgs_between_two_tags()
{
    if [ $# -ne 2 ]; then
        clean_buildroot
        die "*** invalid call to get_commit_msgs_between_two_tags() ***"
    fi
    range="$1..$2"
    echo "`git log --format=%s%b ${range}`"
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

copy_build_artifacts_to_pkgstore()
{
    pushd "${BUILDROOT}" > /dev/null
    cp -r ./* "${PKGSTORE}"
    popd > /dev/null
}

# vim: ts=4 sw=4 expandtab

