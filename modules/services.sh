#!/bin/bash
# Docker Compose services deployment
# Requires: utils.sh, Docker installed

# shellcheck source=utils.sh
[[ -z "${UTILS_LOADED:-}" ]] && source "$(dirname "$0")/utils.sh"

prepare_env() {
    local script_root="${SCRIPT_ROOT:-.}"
    local example="${ENV_EXAMPLE:-.envs.example}"
    local env_file="${ENV_FILE:-.env}"
    local example_path="$script_root/$example"

    print_step "Preparing environment configuration"

    if [[ -f "$script_root/.env" ]]; then
        print_info ".env already exists"
        return 0
    fi

    if [[ -f "$example_path" ]]; then
        grep -E '^export [A-Z_]+=' "$example_path" 2>/dev/null | sed 's/^export //' > "$script_root/.env"
        print_success "Created .env from $example"
        print_info "Edit .env to set passwords and tokens"
    else
        print_info "Creating minimal .env"
        cat > "$script_root/.env" <<'ENVEOF'
POSTGRES_DB=mldev
POSTGRES_USER=mldev
POSTGRES_PASSWORD=changeme
MONGO_ROOT_PASSWORD=changeme
GRAFANA_ADMIN_PASSWORD=changeme
DEVPI_PASSWORD=changeme
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1
ENVEOF
    fi
}

install_services() {
    local script_root="${SCRIPT_ROOT:-.}"
    local compose_file="${COMPOSE_FILE:-docker-compose.yml}"
    local compose_path="$script_root/$compose_file"

    print_step "Deploying Docker Compose services"

    if ! check_command docker; then
        print_error "Docker not installed. Run docker module first."
        return 1
    fi

    if [[ ! -f "$compose_path" ]]; then
        print_error "Compose file not found: $compose_path"
        return 1
    fi

    prepare_env

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would run: docker compose -f $compose_path up -d"
        return 0
    fi

    (cd "$script_root" && docker compose -f "$compose_file" up -d)
    print_success "Services started"
}

verify_services() {
    local script_root="${SCRIPT_ROOT:-.}"
    local compose_file="${COMPOSE_FILE:-docker-compose.yml}"
    local compose_path="$script_root/$compose_file"

    if [[ ! -f "$compose_path" ]]; then
        print_warning "Compose file not found: $compose_path"
        return 0
    fi
    (cd "$script_root" && docker compose -f "$compose_file" ps 2>/dev/null) || print_warning "Could not list services"
    return 0
}
