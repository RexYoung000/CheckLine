#!/usr/bin/env bash
# Install immutable source/runtime releases. Secrets and service activation are separate.
set -euo pipefail
umask 022

if [[ ${EUID} -ne 0 || $# -ne 2 ]]; then
  echo 'Usage (root): install-systemd.sh <source-directory> <release-id>' >&2
  exit 2
fi
source_dir=$(realpath "$1")
release_id=$2
if [[ ! $release_id =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$ ]] \
    || [[ ! -f "$source_dir/src/server.mjs" || ! -f "$source_dir/deploy/checkline-agent.service" ]]; then
  echo 'Invalid release input' >&2
  exit 2
fi

deploy_root=/opt/checkline-agent
node_version=24.22.0
node_archive="node-v${node_version}-linux-x64.tar.xz"
node_sha256=cc2f601cee82d9a5a233302fe307abc600727035fd7d2c3a3571755989e95008
if [[ $(uname -m) != x86_64 ]]; then
  echo 'This pinned runtime supports x86_64 only' >&2
  exit 2
fi

install -d -m 0755 "$deploy_root" "$deploy_root/releases" "$deploy_root/runtimes"
node_dir="$deploy_root/runtimes/node-v${node_version}-linux-x64"
if [[ ! -x "$node_dir/bin/node" ]]; then
  node_work=$(mktemp -d /var/tmp/checkline-node.XXXXXXXX)
  trap 'rm -rf -- "$node_work"' EXIT
  curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    --connect-timeout 10 --max-time 180 \
    "https://nodejs.org/dist/v${node_version}/${node_archive}" -o "$node_work/$node_archive"
  (cd "$node_work" && printf '%s  %s\n' "$node_sha256" "$node_archive" | sha256sum -c -)
  tar -xJf "$node_work/$node_archive" -C "$deploy_root/runtimes" --no-same-owner
fi
"$node_dir/bin/node" --version
ln -sfn "$node_dir" "$deploy_root/node.next"
mv -Tf "$deploy_root/node.next" "$deploy_root/node"

if ! getent group checkline-agent >/dev/null; then
  groupadd --system checkline-agent
fi
if ! getent passwd checkline-agent >/dev/null; then
  useradd --system --gid checkline-agent --home-dir /nonexistent \
    --shell /usr/sbin/nologin --no-create-home checkline-agent
fi
if [[ $(id -u checkline-agent) == 0 || $(id -gn checkline-agent) != checkline-agent ]]; then
  echo 'Unexpected service account configuration' >&2
  exit 2
fi

release_dir="$deploy_root/releases/$release_id"
if [[ -e "$release_dir" ]]; then
  echo 'Release already exists; choose a new release ID' >&2
  exit 2
fi
install -d -m 0755 "$release_dir"
cp -R -- "$source_dir/src" "$source_dir/review" "$source_dir/test" "$release_dir/"
install -m 0644 "$source_dir/package.json" "$release_dir/package.json"
chown -R root:root "$release_dir"
find "$release_dir" -type d -exec chmod 0755 {} +
find "$release_dir" -type f -exec chmod 0644 {} +
(cd "$release_dir" && "$node_dir/bin/node" --test test/*.test.mjs)

unit_path=/etc/systemd/system/checkline-agent.service
if [[ -e "$unit_path" ]]; then
  cp -p -- "$unit_path" "${unit_path}.$(date -u +%Y%m%dT%H%M%SZ).bak"
fi
install -m 0644 "$source_dir/deploy/checkline-agent.service" "$unit_path"
systemd-analyze verify "$unit_path"

if [[ -L "$deploy_root/current" ]]; then
  ln -sfn "$(readlink -f "$deploy_root/current")" "$deploy_root/previous.next"
  mv -Tf "$deploy_root/previous.next" "$deploy_root/previous"
elif [[ -e "$deploy_root/current" ]]; then
  echo 'Refusing to replace non-symlink current directory' >&2
  exit 2
fi
ln -sfn "$release_dir" "$deploy_root/current.next"
mv -Tf "$deploy_root/current.next" "$deploy_root/current"
install -d -m 0700 /etc/checkline-agent
systemctl daemon-reload
echo 'Release installed. Configure /etc/checkline-agent/agent.env, then enable/start checkline-agent.'
