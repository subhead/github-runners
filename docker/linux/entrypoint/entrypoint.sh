#!/bin/bash
# docker/linux/entrypoint/entrypoint.sh
# Entrypoint script for GitHub Actions runner containers

set -e

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Function to validate required environment variables
validate_environment() {
    local missing_vars=()

    if [ -z "${GITHUB_TOKEN}" ]; then
        missing_vars+=("GITHUB_TOKEN")
    fi

    if [ -z "${GITHUB_REPOSITORY}" ] && [ -z "${GITHUB_OWNER}" ]; then
        missing_vars+=("GITHUB_REPOSITORY or GITHUB_OWNER")
    fi

    if [ -z "${RUNNER_NAME}" ]; then
        missing_vars+=("RUNNER_NAME")
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log "ERROR: Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        return 1
    fi

    return 0
}

# Function to configure the runner
configure_runner() {
    local runner_url

    if [ -n "${GITHUB_REPOSITORY}" ]; then
        runner_url="https://github.com/${GITHUB_REPOSITORY}"
    else
        runner_url="https://github.com/${GITHUB_OWNER}"
    fi

    log "Configuring GitHub Actions runner for: ${runner_url}"

    # Determine runner scope (repository or organization)
    local runner_scope_arg
    if [ -n "${GITHUB_REPOSITORY}" ]; then
        runner_scope_arg="--url ${runner_url}"
    else
        runner_scope_arg="--url ${runner_url}"
    fi

    # Generate registration token
    log "Generating registration token..."
    local registration_token
    if [ -n "${GITHUB_REPOSITORY}" ]; then
        registration_token=$(curl -s -X POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "${runner_url}/actions/runners/registration-token" | jq -r '.token')
    else
        registration_token=$(curl -s -X POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/registration-token" | jq -r '.token')
    fi

    if [ -z "${registration_token}" ] || [ "${registration_token}" = "null" ]; then
        log "ERROR: Failed to generate registration token. Check GITHUB_TOKEN permissions."
        return 1
    fi

    log "Registration token generated successfully"

    # Configure the runner
    log "Configuring runner with name: ${RUNNER_NAME}"

    local config_args=()

    # Add runner labels
    if [ -n "${RUNNER_LABELS}" ]; then
        config_args+=(--labels "${RUNNER_LABELS}")
    fi

    # Add runner group if specified
    if [ -n "${RUNNER_GROUP}" ]; then
        config_args+=(--runnergroup "${RUNNER_GROUP}")
    fi

    # Add work directory if specified
    if [ -n "${RUNNER_WORKDIR}" ]; then
        config_args+=(--work "${RUNNER_WORKDIR}")
    fi

    # Add replace flag if needed
    if [ "${RUNNER_REPLACE_EXISTING}" = "true" ]; then
        config_args+=(--replace)
    fi

    # Run config.sh
    ./config.sh \
        --url "${runner_url}" \
        --token "${registration_token}" \
        --name "${RUNNER_NAME}" \
        --unattended \
        "${config_args[@]}"

    if [ $? -eq 0 ]; then
        log "Runner configured successfully"
        return 0
    else
        log "ERROR: Failed to configure runner"
        return 1
    fi
}

# Function to start the runner
start_runner() {
    log "Starting GitHub Actions runner..."

    # Run as root if specified, otherwise run as runner user
    if [ "${RUNNER_AS_ROOT}" = "true" ]; then
        log "Running as root (not recommended for production)"
        ./run.sh
    else
        # Switch to runner user and start the runner
        # Use sudo to preserve environment variables
        sudo -E -u runner ./run.sh
    fi
}

# Function to clean up runner on shutdown
cleanup_runner() {
    log "Cleaning up runner..."

    if [ -f .runner ]; then
        # Try to remove the runner from GitHub
        if [ -n "${GITHUB_TOKEN}" ] && [ -n "${RUNNER_NAME}" ]; then
            local runner_url
            if [ -n "${GITHUB_REPOSITORY}" ]; then
                runner_url="https://github.com/${GITHUB_REPOSITORY}"
            else
                runner_url="https://github.com/${GITHUB_OWNER}"
            fi

            # Get runner ID
            local runner_id=$(./config.sh list | grep "${RUNNER_NAME}" | head -1 | awk '{print $1}')

            if [ -n "${runner_id}" ]; then
                log "Removing runner ${runner_id} from GitHub..."

                if [ -n "${GITHUB_REPOSITORY}" ]; then
                    curl -s -X DELETE \
                        -H "Authorization: token ${GITHUB_TOKEN}" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "${runner_url}/actions/runners/${runner_id}" > /dev/null 2>&1
                else
                    curl -s -X DELETE \
                        -H "Authorization: token ${GITHUB_TOKEN}" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/${runner_id}" > /dev/null 2>&1
                fi
            fi
        fi

        # Remove runner configuration
        rm -f .runner .credentials .credentials_rsaparams
        log "Runner cleanup completed"
    fi
}

# Signal handlers for graceful shutdown
cleanup_on_exit() {
    log "Received shutdown signal"
    cleanup_runner
    exit 0
}

# Main execution
main() {
    # Display help if requested
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "GitHub Actions Runner Entrypoint"
        echo "================================="
        echo ""
        echo "Required Environment Variables:"
        echo "  GITHUB_TOKEN        - GitHub personal access token (must have repo/org scope)"
        echo "  GITHUB_REPOSITORY   - Repository in format 'owner/repo' (for repo runners)"
        echo "  GITHUB_OWNER        - Organization name (for org runners, if GITHUB_REPOSITORY not set)"
        echo "  RUNNER_NAME         - Unique name for this runner instance"
        echo ""
        echo "Optional Environment Variables:"
        echo "  RUNNER_LABELS       - Comma-separated labels for runner selection (default: 'linux')"
        echo "  RUNNER_GROUP        - Runner group name (default: 'Default')"
        echo "  RUNNER_WORKDIR      - Working directory for runner (default: '_work')"
        echo "  RUNNER_AS_ROOT      - Run runner as root (not recommended: 'true'/'false')"
        echo "  RUNNER_REPLACE_EXISTING - Replace existing runner with same name (default: 'false')"
        echo ""
        echo "Usage:"
        echo "  docker run -e GITHUB_TOKEN=... -e GITHUB_REPOSITORY=... -e RUNNER_NAME=... gh-runner:linux-base"
        echo ""
        return 0
    fi

    # Set up signal handlers
    trap cleanup_on_exit SIGTERM SIGINT

    log "Starting GitHub Actions Runner entrypoint"

    # Validate environment
    if ! validate_environment; then
        log "Environment validation failed"
        exit 1
    fi

    # Configure the runner if not already configured
    if [ ! -f .runner ]; then
        log "Runner not configured, starting configuration..."
        if ! configure_runner; then
            log "Failed to configure runner"
            exit 1
        fi
    else
        log "Runner already configured, skipping configuration"
    fi

    # Start the runner
    start_runner
}

# Run main function with all arguments
main "$@"
