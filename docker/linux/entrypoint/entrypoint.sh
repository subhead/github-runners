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
    local registration_token_response
    if [ -n "${GITHUB_REPOSITORY}" ]; then
        registration_token_response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners/registration-token")
    else
        registration_token_response=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/registration-token")
    fi

    local registration_token
    local response_body=$(echo "$registration_token_response" | head -n -1)
    local http_code=$(echo "$registration_token_response" | tail -n 1)

    # Debug: show raw response
    log "Raw API Response: $response_body"
    log "HTTP Status Code: $http_code"

    registration_token=$(echo "$response_body" | jq -r '.token' 2>/dev/null)

    if [ -z "${registration_token}" ] || [ "${registration_token}" = "null" ]; then
        log "ERROR: Failed to generate registration token. HTTP Status: ${http_code}"
        # Try to extract error message with multiple fallbacks
        local error_msg=$(echo "$response_body" | jq -r '.message // .detail // .error // .errors[0].message // "Unknown error"' 2>/dev/null)
        log "API Error: $error_msg"
        log "Full response: $response_body"
        log "Check GITHUB_TOKEN permissions and ensure it has 'repo' scope (classic PAT) or 'Actions: Read/Write' (fine-grained)."
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

    # Check if we're running as root
    local current_user=$(id -un)

    if [ "${RUNNER_AS_ROOT}" = "true" ]; then
        log "Running as root (not recommended for production)"
        ./run.sh
    elif [ "${current_user}" = "runner" ]; then
        # Already running as runner user - just run directly
        log "Running as runner user: ${current_user}"
        ./run.sh
    else
        # Running as root but need to switch to runner user
        log "Running as root, switching to runner user for runner execution"
        # Change ownership of /actions-runner to runner user
        chown -R runner:runner /actions-runner 2>/dev/null || log "Note: Could not change ownership"
        # Switch to runner user and start the runner
        su runner -c "./run.sh"
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

                local delete_response
                if [ -n "${GITHUB_REPOSITORY}" ]; then
                    delete_response=$(curl -s -w "\n%{http_code}" -X DELETE \
                        -H "Authorization: token ${GITHUB_TOKEN}" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "https://api.github.com/repos/${GITHUB_REPOSITORY}/actions/runners/${runner_id}")
                else
                    delete_response=$(curl -s -w "\n%{http_code}" -X DELETE \
                        -H "Authorization: token ${GITHUB_TOKEN}" \
                        -H "Accept: application/vnd.github.v3+json" \
                        "https://api.github.com/orgs/${GITHUB_OWNER}/actions/runners/${runner_id}")
                fi

                local delete_code=$(echo "$delete_response" | tail -n 1)
                if [ "$delete_code" -eq 204 ]; then
                    log "Runner ${runner_id} removed successfully"
                else
                    log "Failed to remove runner ${runner_id}. HTTP Status: ${delete_code}"
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

    # Copy runner files from /opt/actions-runner if they don't exist
    # This handles the case where /actions-runner is mounted via docker-compose
    if [ ! -f /actions-runner/config.sh ] && [ -d /opt/actions-runner ]; then
        log "Copying runner files from /opt/actions-runner to /actions-runner..."
        # Use rsync or cp with proper permissions
        cp -r /opt/actions-runner/* /actions-runner/ 2>/dev/null || cp -r /opt/actions-runner/* /actions-runner/
        chmod +x /actions-runner/*.sh 2>/dev/null
        chown -R runner:runner /actions-runner 2>/dev/null || log "Note: Could not change ownership of /actions-runner"
        log "Runner files copied successfully"
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
