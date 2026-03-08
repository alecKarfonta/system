#!/bin/bash
# Python environment: Miniconda, base env, pip packages
# Requires: utils.sh

# shellcheck source=utils.sh
[[ -z "${UTILS_LOADED:-}" ]] && source "$(dirname "$0")/utils.sh"

install_python() {
    print_step "Installing Miniconda"
    require_ubuntu

    local install_dir="${CONDA_INSTALL_DIR:-$HOME/miniconda3}"
    local script_root="${SCRIPT_ROOT:-.}"

    if [[ -d "$install_dir" ]] && [[ -x "$install_dir/bin/conda" ]]; then
        print_info "Miniconda already installed at $install_dir"
        if [[ -n "${YES_TO_ALL:-}" ]] && [[ "$YES_TO_ALL" -eq 1 ]]; then
            print_info "Skipping (--yes, already installed)"
            return 0
        fi
        if [[ -z "${FORCE_REINSTALL:-}" ]] && ! prompt_yes_no "Reinstall Miniconda?" "n"; then
            print_info "Skipping Miniconda installation"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would install Miniconda to $install_dir"
        return 0
    fi

    local installer="/tmp/Miniconda3-latest-Linux-x86_64.sh"
    if [[ ! -f "$installer" ]]; then
        wget -q "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" -O "$installer"
    fi
    chmod +x "$installer"
    bash "$installer" -b -p "$install_dir"
    rm -f "$installer"

    print_success "Miniconda installed at $install_dir"
    print_info "Run: source $install_dir/bin/activate"
}

install_requirements() {
    local req_file="${REQUIREMENTS_FILE:-requirements.txt}"
    local script_root="${SCRIPT_ROOT:-.}"
    local req_path="$script_root/$req_file"

    if [[ ! -f "$req_path" ]]; then
        print_warning "Requirements file not found: $req_path"
        return 0
    fi

    print_step "Installing Python packages from $req_file"

    local conda_path="${CONDA_INSTALL_DIR:-$HOME/miniconda3}"
    if [[ -x "$conda_path/bin/pip" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            print_info "[DRY-RUN] Would run: $conda_path/bin/pip install -r $req_path"
        else
            "$conda_path/bin/pip" install -r "$req_path"
            print_success "Packages installed from $req_file"
        fi
    else
        if command -v pip3 >/dev/null 2>&1; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                print_info "[DRY-RUN] Would run: pip3 install -r $req_path"
            else
                pip3 install -r "$req_path"
                print_success "Packages installed from $req_file"
            fi
        else
            print_warning "No pip found. Install Miniconda or Python first."
        fi
    fi
}

verify_python() {
    local conda_path="${CONDA_INSTALL_DIR:-$HOME/miniconda3}"
    if [[ -x "$conda_path/bin/conda" ]]; then
        print_success "Conda: $($conda_path/bin/conda --version 2>/dev/null)"
    elif check_command conda; then
        print_success "Conda: $(conda --version 2>/dev/null)"
    else
        print_warning "Conda: not found"
    fi
    if check_command python3; then
        print_success "Python: $(python3 --version 2>/dev/null)"
    else
        print_warning "Python3: not found"
    fi
    return 0
}
