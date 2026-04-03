#!/bin/ksh -p
# SPDX-License-Identifier: CDDL-1.0

#
# CDDL HEADER START
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#
# CDDL HEADER END
#

#
# Copyright (c) 2026, Christos Longros. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib

#
# DESCRIPTION:
# Verify that zpool status -E outputs parsable error information.
#
# STRATEGY:
# 1. Create a pool and write data
# 2. Use zinject to create permanent data errors
# 3. Verify -E produces no output on a healthy pool
# 4. Verify -E produces tab-delimited output with 3 fields
# 5. Verify -E suppresses normal status output
#

function cleanup
{
	zinject -c all
	poolexists $TESTPOOL2 && destroy_pool $TESTPOOL2
	log_must rm -f $TESTDIR/vdev_e
}

log_assert "Verify 'zpool status -E' produces parsable error output"

log_onexit cleanup

log_must mkdir -p $TESTDIR
log_must truncate -s $MINVDEVSIZE $TESTDIR/vdev_e
log_must zpool create -f $TESTPOOL2 $TESTDIR/vdev_e
log_must zfs create $TESTPOOL2/data
log_must dd if=/dev/urandom of=/$TESTPOOL2/data/testfile bs=4096 count=20
log_must sync_pool $TESTPOOL2

# Verify -E produces no output with a healthy pool
log_mustnot eval "zpool status -E $TESTPOOL2 | grep -q ."

# Inject permanent data errors using zinject
log_must zinject -t data -e checksum -f 100 /$TESTPOOL2/data/testfile
log_must zinject -a

# Read the file to trigger errors, scrub to record them
dd if=/$TESTPOOL2/data/testfile of=/dev/null bs=4096 2>/dev/null
log_must zpool scrub -w $TESTPOOL2

# Check that there are permanent errors via -v
log_must eval "zpool status -v $TESTPOOL2 | grep -q 'Permanent errors'"

# Verify -E produces output
log_must eval "zpool status -E $TESTPOOL2 | grep -q ."

# Verify output is tab-delimited with 3 fields per line
typeset tmpfile=$(mktemp)
zpool status -E $TESTPOOL2 > "$tmpfile"
while IFS= read -r line; do
	nfields=$(echo "$line" | awk -F'\t' '{print NF}')
	if [ "$nfields" -ne 3 ]; then
		rm -f "$tmpfile"
		log_fail "Expected 3 tab-delimited fields, got $nfields: $line"
	fi
done < "$tmpfile"
rm -f "$tmpfile"

# Verify first field contains the dataset name
log_must eval "zpool status -E $TESTPOOL2 | awk -F'\t' '{print \$1}' | \
    grep -q '$TESTPOOL2'"

# Verify second field is a numeric object ID
log_must eval "zpool status -E $TESTPOOL2 | awk -F'\t' '{print \$2}' | \
    grep -qE '^[0-9]+$'"

# Verify -E suppresses all other status output
log_mustnot eval "zpool status -E $TESTPOOL2 | grep -q 'pool:'"
log_mustnot eval "zpool status -E $TESTPOOL2 | grep -q 'state:'"
log_mustnot eval "zpool status -E $TESTPOOL2 | grep -q 'config:'"

log_pass "Verify zpool status -E produces parsable error output"
