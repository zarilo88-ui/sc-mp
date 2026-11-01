#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Test installer identity and config-path checks without root or system account changes.
set -eu

guard=${1:-}
if [ -z "$guard" ] || [ ! -f "$guard" ]; then
    echo "usage: sh test_install_guard.sh <install_guard.sh>" >&2
    exit 2
fi
. "$guard"

failures=0
ok() { echo "ok: $*"; }
fail() { echo "FAIL: $*" >&2; failures=$((failures + 1)); }

mock_group=""
mock_groups_all=""
mock_user=""
mock_passwd_all=""
mock_groups=""
groupadd_calls=0
useradd_calls=0
chown_calls=0
chmod_calls=0

getent() {
    case "$1" in
        group)
            if [ "$#" -eq 2 ]; then
                [ -n "$mock_group" ] || return 2
                printf '%s\n' "$mock_group"
                return 0
            fi
            printf '%s\n' "$mock_groups_all"
            return 0
            ;;
        passwd)
            if [ "$#" -eq 2 ]; then
                [ -n "$mock_user" ] || return 2
                printf '%s\n' "$mock_user"
                return 0
            fi
            printf '%s\n' "$mock_passwd_all"
            return 0
            ;;
    esac
    return 2
}

groupadd() {
    groupadd_calls=$((groupadd_calls + 1))
    [ "$1" = --system ] && [ "$2" = sco-relay ] || return 2
    mock_group=sco-relay:x:64001:
    mock_groups_all=$mock_group
}

useradd() {
    useradd_calls=$((useradd_calls + 1))
    mock_user='sco-relay:!:64001:64001::/nonexistent:/usr/sbin/nologin'
    mock_passwd_all=$mock_user
    mock_groups=64001
}

id() {
    [ "$1" = -G ] && [ "$2" = sco-relay ] || return 2
    printf '%s\n' "$mock_groups"
}

chown() {
    chown_calls=$((chown_calls + 1))
    [ "$1" = root:sco-relay ]
}

chmod() {
    chmod_calls=$((chmod_calls + 1))
    [ "$1" = 0640 ]
}

set_safe_identity() {
    mock_group='sco-relay:x:64001:'
    mock_groups_all=$mock_group
    mock_user='sco-relay:!:64001:64001::/nonexistent:/usr/sbin/nologin'
    mock_passwd_all=$mock_user
    mock_groups=64001
    groupadd_calls=0
    useradd_calls=0
}

expect_identity_rejected() {
    label=$1
    if ensure_service_identity sco-relay /usr/sbin/nologin 2>/dev/null; then
        fail "$label was accepted"
    else
        ok "$label was refused"
    fi
}

set_safe_identity
if ensure_service_identity sco-relay /usr/sbin/nologin; then
    [ "$groupadd_calls" -eq 0 ] && [ "$useradd_calls" -eq 0 ] \
        && ok "a pre-existing isolated service identity is accepted" \
        || fail "a valid existing identity was unexpectedly recreated"
else
    fail "a pre-existing isolated service identity was refused"
fi
mock_user='sco-relay:!:64001:64001:Relay service:/nonexistent:/usr/sbin/nologin'
mock_passwd_all=$mock_user
if ensure_service_identity sco-relay /usr/sbin/nologin; then
    ok "a valid GECOS field is parsed without changing the account checks"
else
    fail "a valid GECOS field confused the account parser"
fi

mock_group='sco-relay:x:64001:another-user'
mock_groups_all=$mock_group
expect_identity_rejected "a group with listed members"
set_safe_identity
mock_groups_all="$mock_group
alias-group:x:64001:another-user"
expect_identity_rejected "a shared numeric group ID"
set_safe_identity
mock_passwd_all="$mock_user
another-user:x:1002:64001::/home/another-user:/bin/sh"
expect_identity_rejected "a group used as another user's primary group"
set_safe_identity
mock_passwd_all="$mock_user
other-uid:x:64001:1002::/home/other-uid:/bin/sh"
expect_identity_rejected "a UID shared with another account"
set_safe_identity
mock_user='sco-relay:!:0:64001::/nonexistent:/usr/sbin/nologin'
mock_passwd_all=$mock_user
expect_identity_rejected "a UID-0 service account"
set_safe_identity
mock_user='sco-relay:!:64001:10::/nonexistent:/usr/sbin/nologin'
mock_passwd_all=$mock_user
expect_identity_rejected "a service account with a different primary group"
set_safe_identity
mock_user='sco-relay:!:64001:64001::/nonexistent:/bin/sh'
mock_passwd_all=$mock_user
expect_identity_rejected "a service account with a login shell"
set_safe_identity
mock_groups='64001 10'
expect_identity_rejected "a service account with supplementary groups"

mock_group=
mock_user=
mock_passwd_all=
mock_groups=
groupadd_calls=0
useradd_calls=0
if ensure_service_identity sco-relay /usr/sbin/nologin; then
    [ "$groupadd_calls" -eq 1 ] && [ "$useradd_calls" -eq 1 ] \
        && ok "a missing identity is created through mocked account commands and then validated" \
        || fail "the mock account creation path did not run exactly once"
else
    fail "the mocked account creation path was refused"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' 0 HUP INT TERM
safe_dir=$work/etc/sco-relay
safe_config=$safe_dir/sco-relay.conf
mkdir -p "$safe_dir"
printf '%s\n' 'port = 64091' > "$safe_config"
chown_calls=0
chmod_calls=0
if set_config_permissions "$safe_dir" "$safe_config" sco-relay; then
    [ "$chown_calls" -eq 1 ] && [ "$chmod_calls" -eq 1 ] \
        && ok "a regular config file receives the requested permission operations" \
        || fail "safe config permission operations were not called once"
else
    fail "a regular config file was refused"
fi

outside=$work/outside.conf
printf '%s\n' 'unrelated=secret' > "$outside"
rm -f "$safe_config"
ln -s "$outside" "$safe_config"
chown_calls=0
chmod_calls=0
if set_config_permissions "$safe_dir" "$safe_config" sco-relay 2>/dev/null; then
    fail "a symlinked config file was accepted"
else
    [ "$chown_calls" -eq 0 ] && [ "$chmod_calls" -eq 0 ] \
        && ok "a symlinked config is refused before ownership/mode changes" \
        || fail "permission commands ran for a symlinked config"
fi

rm -f "$safe_config"
mkdir "$safe_config"
if validate_config_paths "$safe_dir" "$safe_config" 2>/dev/null; then
    fail "a directory at the config path was accepted"
else
    ok "a non-regular config path is refused"
fi
rmdir "$safe_config"
ln -s "$work/missing-target" "$safe_config"
if validate_config_paths "$safe_dir" "$safe_config" 2>/dev/null; then
    fail "a dangling config symlink was accepted"
else
    ok "a dangling config symlink is refused"
fi

real_dir=$work/real-dir
mkdir -p "$real_dir"
printf '%s\n' 'port = 64091' > "$real_dir/sco-relay.conf"
ln -s "$real_dir" "$work/linked-dir"
chown_calls=0
chmod_calls=0
if set_config_permissions "$work/linked-dir" "$work/linked-dir/sco-relay.conf" sco-relay 2>/dev/null; then
    fail "a symlinked config directory was accepted"
else
    [ "$chown_calls" -eq 0 ] && [ "$chmod_calls" -eq 0 ] \
        && ok "a symlinked config directory is refused before ownership/mode changes" \
        || fail "permission commands ran through a symlinked config directory"
fi
ln -s "$real_dir" "$real_dir/alias"
chown_calls=0
chmod_calls=0
if set_config_permissions "$real_dir" "$real_dir/alias/sco-relay.conf" sco-relay 2>/dev/null; then
    fail "an ancestor symlink in the config file path was accepted"
else
    [ "$chown_calls" -eq 0 ] && [ "$chmod_calls" -eq 0 ] \
        && ok "an ancestor symlink in the config path is refused before ownership/mode changes" \
        || fail "permission commands ran through an ancestor symlink"
fi
if validate_config_paths "$real_dir/../real-dir" "$real_dir/../real-dir/sco-relay.conf" 2>/dev/null; then
    fail "dot traversal in a config path was accepted"
else
    ok "dot traversal in config paths is refused"
fi

if [ "$failures" -ne 0 ]; then
    echo "test_install_guard: $failures failure(s)" >&2
    exit 1
fi
echo "test_install_guard: all checks passed"
