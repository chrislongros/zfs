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

#
# DESCRIPTION:
# 'zpool create' should report which device is in use when the
# create fails because a vdev belongs to an active pool.
#
# STRATEGY:
# 1. Two loopback devices on the same backing file: the create
#    fails and the error names a device.
# 2. Cache device of an active pool: the error names that device.
# 3. Log device of an active pool: the error names that device.
#

verify_runnable "global"

TESTFILE_SHARED="$TEST_BASE_DIR/vdev_errinfo_shared"
TESTFILE_MAIN="$TEST_BASE_DIR/vdev_errinfo_main"
TESTFILE_AUX="$TEST_BASE_DIR/vdev_errinfo_aux"
TESTPOOL2="testpool_errinfo_2"
LIVEPOOL="testpool_errinfo_live"
BLKDEV1=""
BLKDEV2=""
BLKMAIN=""
BLKAUX=""

function attach_blkdev # backing-file
{
	typeset file="$1"
	if is_linux; then
		losetup -f --show "$file"
	elif is_freebsd; then
		echo "/dev/$(mdconfig -a -t vnode -f "$file")"
	else
		log_unsupported "Platform not supported for this test"
	fi
}

function detach_blkdev # device
{
	typeset dev="$1"
	[[ -z "$dev" ]] && return
	if is_linux; then
		losetup -d "$dev" 2>/dev/null
	elif is_freebsd; then
		mdconfig -d -u "$dev" 2>/dev/null
	fi
}

function cleanup
{
	poolexists $TESTPOOL2 && destroy_pool $TESTPOOL2
	poolexists $LIVEPOOL && destroy_pool $LIVEPOOL
	poolexists $TESTPOOL && destroy_pool $TESTPOOL

	detach_blkdev "$BLKDEV1"
	detach_blkdev "$BLKDEV2"
	detach_blkdev "$BLKMAIN"
	detach_blkdev "$BLKAUX"

	rm -f "$TESTFILE_SHARED" "$TESTFILE_MAIN" "$TESTFILE_AUX"
}

log_assert "'zpool create' reports device-specific errors for in-use vdevs."
log_onexit cleanup

#
# Scenario 1: two loopback devices on the same backing file
#
log_must truncate -s $MINVDEVSIZE "$TESTFILE_SHARED"
BLKDEV1=$(attach_blkdev "$TESTFILE_SHARED")
BLKDEV2=$(attach_blkdev "$TESTFILE_SHARED")
log_note "Scenario 1 devices: $BLKDEV1 $BLKDEV2"

log_mustnot_expect_re "$BLKDEV1|$BLKDEV2" "" \
    zpool create $TESTPOOL2 mirror $BLKDEV1 $BLKDEV2

#
# Scenarios 2 and 3 share a live pool with two auxiliary roles.
#
log_must truncate -s $MINVDEVSIZE "$TESTFILE_MAIN" "$TESTFILE_AUX"
BLKMAIN=$(attach_blkdev "$TESTFILE_MAIN")
BLKAUX=$(attach_blkdev "$TESTFILE_AUX")
log_note "Live-pool devices: main=$BLKMAIN aux=$BLKAUX"

#
# Scenario 2: cache device of an active pool
#
log_must zpool create $LIVEPOOL $BLKMAIN cache $BLKAUX
log_mustnot_expect_re "$BLKAUX" "" \
    zpool create $TESTPOOL2 $BLKAUX
log_must zpool destroy $LIVEPOOL

#
# Scenario 3: log device of an active pool
#
log_must zpool create $LIVEPOOL $BLKMAIN log $BLKAUX
log_mustnot_expect_re "$BLKAUX" "" \
    zpool create $TESTPOOL2 $BLKAUX
log_must zpool destroy $LIVEPOOL

log_pass "'zpool create' reports device-specific errors for in-use vdevs."
