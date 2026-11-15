#!/usr/bin/bash
# Add Verta's packages (packages.txt) and remove the ones it doesn't want (remove.txt).
set -xeuo pipefail

read_list() { grep -vE '^[[:space:]]*(#|$)' "$1" | sed 's/[[:space:]]*#.*//'; }

# Steam lives in RPM Fusion; install its repo files if the base image lacks them.
if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    dnf5 -y install \
        "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
        "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
fi

# COPR repos, enabled only for this build and switched off again afterwards:
#   bieszczaders/kernel-cachyos-addons  sched-ext CPU schedulers (scx), ananicy-cpp
#   matinlotfali/KDE-Rounded-Corners    rounded window corners (upstream author's repo)
COPRS=(bieszczaders/kernel-cachyos-addons matinlotfali/KDE-Rounded-Corners)
COPR_FILES=()
for copr in "${COPRS[@]}"; do
    owner="${copr%%/*}"; project="${copr#*/}"
    file="/etc/yum.repos.d/_copr_${owner}-${project}.repo"
    curl -fsSL -o "$file" \
        "https://copr.fedorainfracloud.org/coprs/${owner}/${project}/repo/fedora-${FEDORA_VERSION}/${owner}-${project}-fedora-${FEDORA_VERSION}.repo"
    COPR_FILES+=("$file")
done

mapfile -t PACKAGES < <(read_list "$CTX/packages.txt")
dnf5 -y install \
    --enable-repo='rpmfusion-free*' \
    --enable-repo='rpmfusion-nonfree*' \
    "${PACKAGES[@]}"

for file in "${COPR_FILES[@]}"; do
    sed -i 's/^enabled=.*/enabled=0/' "$file"
done

# Remove apps a gaming desktop doesn't need. One at a time, and only if nothing
# else depends on it, so a removal can never drag other packages with it.
while read -r -a group; do
    installed=()
    for pkg in "${group[@]}"; do
        rpm -q "$pkg" >/dev/null 2>&1 && installed+=("$pkg")
    done
    [ "${#installed[@]}" -gt 0 ] || continue
    if rpm -e --test "${installed[@]}" >/dev/null 2>&1; then
        rpm -e "${installed[@]}"
        echo "removed ${installed[*]}"
    else
        echo "keeping ${installed[*]} (required by other packages)"
    fi
done < <(read_list "$CTX/remove.txt")
