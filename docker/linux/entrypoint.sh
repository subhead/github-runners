#!/bin/bash
set -e

# GitHub Actions Runner Entrypoint Script
# Handles automatic registration and startup of self-hosted runners

# Required environment variables
GITHUB_TOKEN=${GITHUB_TOKEN:-}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-}
RUNNER_NAME=${RUNNER_NAME:-$(hostname)}
RUNNER_LABELS=${RUNNER_LABELS:-linux}
RUNNER_GROUP=${RUNNER_GROUP:-default}
WORK_DIR=${WORK_DIR:-/actions-runner}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate required environment variables
validate_config() {
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GITHUB_TOKEN environment variable is required"
        exit 1
    fi

    if [ -z "$GITHUB_REPOSITORY" ]; then
        log_error "GITHUB_REPOSITORY environment variable is required (format: owner/repo)"
        exit 1
    fi

    # Validate repository format
    if ! [[ "$GITHUB_REPOSITORY" =~ ^[^/]+/[^/]+$ ]]; then
        log_error "GITHUB_REPOSITORY must be in format 'owner/repo'"
        exit 1
    fi

    log_info "Configuration validated successfully"
}

# Generate runner registration token
generate_runner_token() {
    local repo=$1
    local token=$2

    log_info "Generating runner token for repository: $repo"

    local token_response
    token_response=$(curl -s -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $token" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "https://api.github.com/repos/$repo/actions/runners/generate-token")

    if [ $? -ne 0 ]; then
        log_error "Failed to generate runner token: API request failed"
        exit 1
    fi

    local runner_token
    runner_token=$(echo "$token_response" | jq -r '.token' 2>/dev/null)

    if [ -z "$runner_token" ] || [ "$runner_token" = "null" ]; then
        local error_message=$(echo "$token_response" | jq -r '.message // "Unknown error"' 2>/dev/null)
        log_error "Failed to generate runner token: $error_message"
        exit 1
    fi

    echo "$runner_token"
}

# Configure the runner
configure_runner() {
    local repo=$1
    local token=$2
    local name=$3
    local labels=$4
    local group=$5
    local work_dir=$6

    log_info "Configuring runner..."
    log_info "  Repository: $repo"
    log_info "  Name: $name"
    log_info "  Labels: $labels"
    log_info "  Group: $group"
    log_info "  Work directory: $work_dir"

    # Check if config.sh exists
    if [ ! -f "./config.sh" ]; then
        log_error "config.sh not found in current directory: $(pwd)"
        exit 1
    fi

    # Run config.sh with appropriate arguments
    local config_cmd="./config.sh --url https://github.com/$repo --token $token --name $name --labels $labels --runnergroup $group --work $work_dir"

    if [ -n "${RUNNER_EPHEMERAL:-}" ] && [ "${RUNNER_EPHEMERAL}" = "true" ]; then
        config_cmd="$config_cmd --ephemeral"
    fi

    if [ -n "${RUNNER_URL:-}" ]; then
        config_cmd="$config_cmd --url $RUNNER_URL"
    fi

    if [ -n "${RUNNER_TOKEN:-}" ]; then
        config_cmd="$config_cmd --token $RUNNER_TOKEN"
    fi

    log_info "Running config command: $config_cmd"

    if ! eval $config_cmd; then
        log_error "Runner configuration failed"
        exit 1
    fi

    log_info "Runner configured successfully"
}

# Clean up existing configuration if needed
cleanup_existing_config() {
    local work_dir=$1

    if [ -f "$work_dir/.runner" ]; then
        log_warn "Found existing runner configuration, attempting to remove..."

        if [ -f "./config.sh" ]; then
            # Try to unregister the existing runner
            log_info "Unregistering existing runner..."
            ./config.sh remove --token "$RUNNER_TOKEN" || true
        fi

        # Clean up work directory
        rm -rf "$work_dir"/*
        log_info "Cleaned up existing configuration"
    fi
}

# Main execution
main() {
    log_info "Starting GitHub Actions Runner"
    log_info "================================="

    # Change to work directory
    cd "$WORK_DIR" || {
        log_error "Failed to change to work directory: $WORK_DIR"
        exit 1
    }

    # Validate configuration
    validate_config

    # Generate runner token
    RUNNER_TOKEN=$(generate_runner_token "$GITHUB_REPOSITORY" "$GITHUB_TOKEN")

    # Clean up if runner already exists
    if [ -n "${CLEANUP_EXISTING:-}" ] && [ "${CLEANUP_EXISTING}" = "true" ]; then
        cleanup_existing_config "$WORK_DIR"
    fi

    # Configure runner
    if [ ! -f "$WORK_DIR/.runner" ] || [ -n "${FORCE_RECONFIGURE:-}" ] && [ "${FORCE_RECONFIGURE}" = "true" ]; then
        configure_runner "$GITHUB_REPOSITORY" "$RUNNER_TOKEN" "$RUNNER_NAME" "$RUNNER_LABELS" "$RUNNER_GROUP" "$WORK_DIR"
    else
        log_info "Runner already configured, skipping configuration"
    fi

    # Install Docker CLI if needed (for Docker-in-Docker support)
    if [ -n "${INSTALL_DOCKER:-}" ] && [ "${INSTALL_DOCKER}" = "true" ]; then
        log_info "Docker socket detected, ensuring Docker CLI is available"
        if ! command -v docker &> /dev/null; then
            log_warn "Docker CLI not found, attempting to install..."
            apt-get update && apt-get install -y docker.io || true
        fi
    fi

    log_info "================================="
    log_info "Starting runner process..."
    log_info "Runner Name: $RUNNER_NAME"
    log_info "Labels: $RUNNER_LABELS"
    log_info "Repository: $GITHUB_REPOSITORY"

    # Start the runner
    if [ -f "./run.sh" ]; then
        exec ./run.sh
    else
        log_error "run.sh not found in current directory"
        exit 1
    fi
}

# Handle signals
trap 'log_warn "Received signal, shutting down..."; exit 0' SIGTERM SIGINT

# Run main function
main "$@"
