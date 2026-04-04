#!/bin/ksh -p
# SPDX-License-Identifier: CDDL-1.0
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or https://opensource.org/licenses/CDDL-1.0.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright (c) 2026, Christos Longros. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/cli_root/zfs_destroy/zfs_destroy.cfg

#
# DESCRIPTION:
#	Verify that 'zfs destroy' on a protected filesystem or volume
#	fails, and succeeds after the protected property is removed.
#
# STRATEGY:
#	1. Create a filesystem and a volume.
#	2. Set protected=on for each.
#	3. Verify 'zfs destroy' fails with an error.
#	4. Set protected=off for each.
#	5. Verify 'zfs destroy' succeeds.
#

verify_runnable "both"

function cleanup
{
	for ds in \
	    "$TESTPOOL/$TESTFS1" \
	    "$TESTPOOL/$TESTVOL"; do
		if datasetexists "$ds"; then
			zfs set protected=off "$ds" 2>/dev/null
			destroy_dataset "$ds" -Rf
		fi
	done
}

log_assert "'zfs destroy' must fail on datasets with protected=on"
log_onexit cleanup

# Test filesystem protection
log_must zfs create $TESTPOOL/$TESTFS1
log_must zfs set protected=on $TESTPOOL/$TESTFS1
log_mustnot zfs destroy $TESTPOOL/$TESTFS1
log_must datasetexists $TESTPOOL/$TESTFS1

log_must zfs set protected=off $TESTPOOL/$TESTFS1
log_must zfs destroy $TESTPOOL/$TESTFS1

# Test volume protection
if is_global_zone; then
	log_must zfs create -V 64M $TESTPOOL/$TESTVOL
	log_must udevadm settle
	log_must zfs set protected=on $TESTPOOL/$TESTVOL
	log_mustnot zfs destroy $TESTPOOL/$TESTVOL
	log_must datasetexists $TESTPOOL/$TESTVOL

	log_must zfs set protected=off $TESTPOOL/$TESTVOL
	log_must zfs destroy $TESTPOOL/$TESTVOL
fi

log_pass "'zfs destroy' correctly rejects protected datasets"
