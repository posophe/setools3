#!/bin/sh

# command line shell to run seuser change/susermod
#

    SEUSER=/usr/local/selinux/bin/seuser
    USERMOD=/usr/local/selinux/bin/susermod
    seuseropts=""
    seuserrenopts=""
    susermodopts=""
    comment=""
    RENAME=0
    ROLES=0

# short usage
usage() {
    echo >&2 ""
    echo >&2 "$@"
    echo >&2 "
usage: 
	$0  -X
	$0  -A
	$0  -h
	$0  [-u uid [-o]] [-g group] [-G group,...] 
                     [-d home [-m]] [-s shell] [-c comment] [-f inactive] 
                     [-e expire ] [-p passwd] [-l new_name] [-L|-U]
	             [-R role[,...]] username
"
}

# -h show this
long_usage() {
    usage ""
    echo >&2 "
    -X             start seuser gui (seuser -X)
    -A             Activate policy (seuser load)
    -u uid [-o]    specify userid, optional -o must be used if uid is not
		   unique
    -g group       initial group name or number
    -G group[,...] supplementary groups
    -d dir [-m]    user's home directory, -m moves the existing directory
    -c comment     password file comment field
    -e date        expiration date of account
    -f days        number of days after a password expires on which account 
                   disabled
    -p password    initial password (encrypted)
    -s shell       user's login shell
    -L             lock user's password
    -U             unlock user's password
    -R role[,...]  specify complete, new set of selinux roles for user
    -h             print out this usage message
"
#    -N             do not load policy (only build and install)
}

# if no arguments are given print usage statement
if [ $# -eq 0 ]; then
    usage ""
    exit 1
fi

while getopts Au:og:G:d:s:c:mf:e:p:XR:hLUl: optvar
do
    case "$optvar"
    in 
	A) # load policy
	    if [ $# -eq 1 ]; then # we're just loading the policy
		${SEUSER} load
		exit $?
	    fi
	    # -A is redundant otherwise so discard and continue
	    echo >&2 "Warning: -A ignored (must be used alone)"
	    ;;
	L) # lock password
	    susermodopts="${susermodopts} -L"
	    ;;
	U) # unlock password
	    susermodopts="${susermodopts} -U"
	    ;;
	l) # change username, for now we force user==policy_user
	    susermodopts="${susermodopts} -l ${OPTARG}"
	    NEWNAME=${OPTARG}
	    RENAME=1;
	    ;;
	u) # specify a uid, unique unless -o also used
	    susermodopts="${susermodopts} -u ${OPTARG}"
	    ;;
	o) # allow use of existing uid, must also use -u
	    susermodopts="${susermodopts} -o"
	    ;;	    
	g) # user's group name or id (must exist)
	    susermodopts="${susermodopts} -g ${OPTARG}"
	    ;; 
	G) # additional groups
	    susermodopts="${susermodopts} -G ${OPTARG}"
	    ;;
	d) # home directory
	    susermodopts="${susermodopts} -d ${OPTARG}"
	    ;;
	s) # login shell
	    susermodopts="${susermodopts} -s ${OPTARG}"
	    ;;
	c) # user's comment field (should be quoted)
	    comment="${OPTARG}"
	    ;;
	m) # move home dir from original
	    susermodopts="${susermodopts} -m"
	    ;;	   
	f) # disable account after password expires
	    susermodopts="${susermodopts} -f ${OPTARG}"
	    ;;
	e) # account expiration date
	    susermodopts="${susermodopts} -e ${OPTARG}"
	    ;;
	p) # encrypted initial password
	    susermodopts="${susermodopts} -p ${OPTARG}"
	    ;;
	h) # print usage
	    long_usage
	    exit 0
	    ;;	    
	X) # start sueser gui
	    if [ ${OPTIND} -ne 2 ]; then
		usage "-X is for running seuser in gui mode"
		exit 1
	    fi
	    ${SEUSER} -g
	    exit $?
	    ;;
#	N) # option to NOT load policy
#	    seuseropts="${seuseropts} -N"
#	    seuserrenopts="${seuserrenopts} -N"
#	    ;;
        R) # roles to use
	    seuseropts="${seuseropts} -R ${OPTARG}"
	    ROLES=1
	    ;;
    esac
done

# toss out the arguments we've already processed
shift  `expr $OPTIND - 1`


# Here we expect the username
if [ $# -eq 0 ]; then
    usage "Need user name"
    exit 1
fi

USERNAME=$1

# cannot play with system_u
if [ "${USERNAME}" = "system_u" ]; then
    usage "${USERNAME} is a predefined policy user; use seuser"
    exit 1
fi


# can change user_u roles, but not rename
# (if this is ever removed, remember to add a check on the rename 
# call below because it assumes this check is done here.)
if [ "${USERNAME}" = "user_u" -a $RENAME -eq 1 ]; then
    usage "user_u may not be renamed"
    exit 1
fi
if [ "${USERNAME}" = "user_u" -a -n "${susermodopts}" ]; then
    usage "user_u is only a policy user.  You may only change its roles"
    exit 1
fi

shift

# there should be nothing after the username
if [ $# -ne 0 ]; then
    usage "You're giving me some extra stuff: $@"
    exit 1
fi


# if there are roles, then change them.  Note that if the user
# did not exist in the policy (but was a system user) then that
# means we are defining roles for a formerly Generic user.  The
# user *must* exist as a system user.
if [ "${USERNAME}" != "user_u" ]; then
    grep ${USERNAME} /etc/passwd > /dev/null
fi
if [ $? -ne 0 ]; then
    echo >&2 "$USERNAME must exist as a system user if you want to set Roles"
    exit 1
fi
if [ "${ROLES}" -eq 1 ]; then
    ${SEUSER} change -f -N ${seuseropts} ${USERNAME} 2> /dev/null
fi
if [ $? -eq 0 ]; then
    echo >&2 "${USERNAME}'s roles have been set"
else # if error, warn about changes requested but not made
    echo >&2 "couldn't change ${USERNAME}'s roles"
    if [ "${RENAME}" -eq 1 ]; then
	echo >&2 "user was NOT renamed in the policy."
    fi
    if [ -n "${susermodopts}" ]; then
	echo >&2 "changes to user's system attributes NOT made"
    fi
    exit 1
fi

# don't have to worry about user_u because we've already checked 
# and errored above
if [ "${RENAME}" -eq 1 ]; then
    ${SEUSER} rename $seuserrenopts ${USERNAME} ${NEWNAME} 2> /dev/null

    if [ $? -eq 0 ]; then
	echo >&2 "${USERNAME} changed to ${NEWNAME} in policy"
    else
	echo >&2 "couldn't change ${USERNAME}'s name"
	if [ "${ROLES}" -eq 1 ]; then
	    echo >&2 "role changes for ${USERNAME} *WERE* made"
	fi
	if [ -n "${susermodopts}" ]; then
	    echo >&2 "changes to user's system attributes NOT made"
	fi
        exit 1
    fi
fi

# only mod system user if we have to and name != user_u (we made
# the check for user_u above already
if [ -n "${susermodopts}" -o -n "${comment}" ]; then
    # need to handle comment like this because of possible spaces
    if [ -n "${comment}" ]; then
	${USERMOD} ${susermodopts} -c "${comment}" ${USERNAME} 2> /dev/null
    else
	${USERMOD} ${susermodopts} ${USERNAME} 2> /dev/null
    fi
fi

# when we're done make the policy changes effective
${SEUSER} load 2> /dev/null
