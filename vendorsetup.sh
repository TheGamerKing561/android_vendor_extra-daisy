# SPDX-FileCopyrightText: Giovanni Ricca
# SPDX-License-Identifier: Apache-2.0

# Defs
TOP=$(gettop)
VENDOR_EXTRA_PATH=${TOP}/vendor/extra

# Toggle to enable/disable applying legacy kernel & BPF compatibility patches
APPLY_LEGACY_KERNEL_PATCHES=${APPLY_LEGACY_KERNEL_PATCHES:-false}

# Logging defs
function LOGI() {
    echo -e "\n\033[32m[INFO]: $1\033[0m"
}

function LOGW() {
    echo -e "\n\033[33m[WARNING]: $1\033[0m"
}

function LOGE() {
    echo -e "\n\033[31m[ERROR]: $1\033[0m"
}

# Apply legacy/compatibility patches safely
function apply_legacy_patches() {
    local patches_dir="$1"

    if [[ ! -d "${patches_dir}" ]]; then
        LOGW "Patches directory not found: ${patches_dir}"
        return
    fi

    local root_dir=${TOP}

    LOGI "Starting application of legacy compatibility patches..."

    for project_dir in "${patches_dir}"/*/; do
        # Remove trailing slash and get base name (e.g., frameworks_base)
        project_dir=${project_dir%/}
        local project_name="${project_dir##*/}"

        # Convert underscores back to slashes for Android repository paths
        local project_path
        case "${project_name}" in
            hardware_qcom-caf_common)
                project_path="hardware/qcom-caf/common"
                ;;
            hardware_qcom-caf_msm8996_audio)
                project_path="hardware/qcom-caf/msm8996/audio"
                ;;
            hardware_qcom-caf_msm8996_display)
                project_path="hardware/qcom-caf/msm8996/display"
                ;;
            hardware_qcom-caf_wlan)
                project_path="hardware/qcom-caf/wlan"
                ;;
            hardware_qcom_wlan)
                project_path="hardware/qcom/wlan"
                ;;
            packages_modules_Connectivity)
                project_path="packages/modules/Connectivity"
                ;;
            system_memory_libmeminfo)
                project_path="system/memory/libmeminfo"
                ;;
            *)
                project_path=$(tr '_' '/' <<< "${project_name}")
                ;;
        esac

        if [[ ! -d "${root_dir}/${project_path}" ]]; then
            LOGW "Repository path ${project_path} does not exist in source tree. Skipping."
            continue
        fi

        cd "${root_dir}/${project_path}" || continue

        # Apply patches and safely abort if conflicts occur
        LOGI "Applying patches for: ${project_path}"
        if git am --no-gpg-sign "${patches_dir}/${project_name}"/*.patch; then
            LOGI "Successfully applied patches to ${project_path}"
        else
            LOGE "Failed to apply patches to ${project_path}. Aborting git am."
            git am --abort &>/dev/null
        fi
    done

    # Return to source root directory
    croot
}

# Execute patching only if explicitly requested
if [[ "${APPLY_LEGACY_KERNEL_PATCHES}" == "true" ]]; then
    apply_legacy_patches "${VENDOR_EXTRA_PATH}/build/patches"
fi