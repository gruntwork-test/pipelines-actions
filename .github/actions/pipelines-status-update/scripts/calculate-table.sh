#!/usr/bin/env bash

set -euo pipefail

# TODO: Enforce Environment variables check

# : "${IS_PLAN:?Environment variable IS_PLAN must be set}"
# : "${STEP_DETAILS:?Environment variable STEP_DETAILS must be set}"
# : "${STEP_DETAILS_JSON:?Environment variable STEP_DETAILS_JSON must be set}"
# : "${STEP_DETAILS_EXTENDED:?Environment variable STEP_DETAILS_EXTENDED must be set}"
# : "${STEP_DETAILS_PREVIEW:?Environment variable STEP_DETAILS_PREVIEW must be set}"
# : "${STEP_STATUS:?Environment variable STEP_STATUS must be set}"
# : "${RUNNER_TEMP:?Environment variable RUNNER_TEMP must be set}"
# : "${GITHUB_OUTPUT:?Environment variable GITHUB_OUTPUT must be set}"
# : "${GITHUB_REPOSITORY:?Environment variable GITHUB_REPOSITORY must be set}"
# : "${GITHUB_RUN_ID:?Environment variable GITHUB_RUN_ID must be set}"
# : "${GITHUB_SHA:?Environment variable GITHUB_SHA must be set}"
# : "${FORMATTED_STEP_NAME:?Environment variable FORMATTED_STEP_NAME must be set}"
# : "${STEP_WORKING_DIRECTORY:?Environment variable STEP_WORKING_DIRECTORY must be set}"
# : "${SUMMARY_STATUS:?Environment variable SUMMARY_STATUS must be set}"

function statusToIcon() {
    local -r status=$1
    if [[ "$status" = "not_started" ]]; then
        echo "⚪"
        return
    fi
    if [[ "$status" = "in_progress" ]]; then
        echo "🔄"
        return
    fi
    if [[ "$status" = "success" ]]; then
        echo "✅"
        return
    fi
    if [[ "$status" = "failed" || "$status" = "failure" ]]; then
        echo "❌"
        return
    fi
    echo "$status"
}

function getMaximumStepCharacterCount() {
    local -r steps=$1

    echo $((40000 / steps))
}

# Ensure we have a statefile
if [[ ! -f "state.json" ]]; then
    echo '{}' >state.json
fi

icon="$(statusToIcon "$STEP_STATUS")"
TMPFILE="$RUNNER_TEMP/message.txt"

# Convert the incoming step details to JSON to make sure it fits inside the state file
echo "$STEP_DETAILS_JSON" >details.json
if [[ -z "${STEP_DETAILS:-}" ]]; then
    echo "setting details to empty json..."
    echo '""' >details.json
fi

echo "New Details as JSON:"
cat details.json

# If a step name is passed, then update the state file with new step details
# If no step name is passed, we'll just create a comment with the existing state
if [[ -n "${FORMATTED_STEP_NAME:-}" ]]; then
    echo "building new json object.."
    key="$FORMATTED_STEP_NAME|$STEP_WORKING_DIRECTORY"

    step_details_extended="$(cat step-details-extended.log)"
    if [[ -n "${step_details_extended:-}" ]]; then
        extended_title="Apply Output"
        if [[ "$IS_PLAN" == "true" ]]; then
            extended_title="Plan Output"
        fi
        if [[ "${#step_details_extended}" -gt 4000 ]]; then
            echo "Length of $FORMATTED_STEP_NAME step_details_extended (${#step_details_extended}) is greater than the maximum character limit (4000)"
            step_details_extended="$FORMATTED_STEP_NAME logs exceeding max character limit. Please check GitHub Actions logs for full output."
        fi
    fi

    JQSTR="$(
        jq -n \
            --arg key "$key" \
            --arg name "$FORMATTED_STEP_NAME" \
            --arg status "$STEP_STATUS" \
            --arg icon "$icon" \
            --arg working_directory "$STEP_WORKING_DIRECTORY" \
            --arg details_preview "$STEP_DETAILS_PREVIEW" \
            --arg extended "$step_details_extended" \
            --arg extended_title "$extended_title" \
            --argjson details "$STEP_DETAILS_JSON" \
            '{ ($key): { name: $name, status: $status, status_icon: $icon, working_directory: $working_directory, details_preview: $details_preview, details: $details, extended: $extended, extended_title: $extended_title}}'
    )"

    echo "$JQSTR"
    NEWJSON="$(jq "$JQSTR" details.json)"
    echo "$NEWJSON"
    echo "building new state..."
    jq ". + $NEWJSON" state.json >updated_state.json
    cat state.json
    cat updated_state.json
    mv updated_state.json state.json
fi

echo "<details open><summary>" >"$TMPFILE"
logs_link="<a href=\"https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID\">logs</a>"
if [[ $IS_PLAN == 'true' ]]; then
    echo "<h2>Gruntwork Pipelines Plan $PR_HEAD_SHA ($logs_link)</h2>" >>"$TMPFILE"
else
    echo "<h2>Gruntwork Pipelines Apply $PR_HEAD_SHA ($logs_link)</h2>" >>"$TMPFILE"
fi
echo "</summary>" >>"$TMPFILE"

if [[ -n "$SUMMARY_STATUS" ]]; then
    echo "$SUMMARY_STATUS<br />" >>"$TMPFILE"
fi

NUM_STEPS=$(jq -c '. | values[]' state.json | wc -l)

if [[ $NUM_STEPS -gt 0 ]]; then
    IFS=$'\n'
    for item in $(jq -c '. | values[]' state.json); do
        echo "single item..."
        echo "$item"
        name="$(jq -r '.name' <<< "$item")"
        status_icon="$(jq -r '.status_icon' <<< "$item")"
        details="$(jq -r '.details' <<< "$item")"
        working_directory="$(jq -r '.working_directory' <<< "$item")"

        if [[ -n "${working_directory:-}" ]]; then
            module="$(basename "$working_directory")"
            echo "<table><tr><td align='left' width='800px'>$status_icon <b>$name:</b> <code>$module</code> (<a href=\"https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID\">logs</a>)</td></tr>" >>"$TMPFILE"
        else
            echo "<table><tr><td align='left' width='800px'>$status_icon <b>$name</b> (<a href=\"https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID\">logs</a>)</td></tr>" >>"$TMPFILE"
        fi

        echo "<tr><td>" >>"$TMPFILE"
        if [[ -n "${working_directory:-}" ]]; then
            echo "<code>$working_directory</code><br /><br />" >>"$TMPFILE"
        fi
        if [[ -n "${details:-}" ]]; then
            echo "$details" >>"$TMPFILE"
        fi
        echo "details extended"

        extended="$(jq -r '.extended' <<< "$item")"

        # If the length of `step_details_extended` is greater than 40000 characters divided by steps, then we emit a default message instead
        extended_len="${#extended}"
        max_len="$(getMaximumStepCharacterCount "$NUM_STEPS")"
        if (( "$extended_len" > "$max_len" )); then
            echo "Length of step_details_extended ($extended_len) is greater than the maximum character limit ($max_len)"
            extended="Logs exceeding max character limit. Please check GitHub Actions logs."
        fi

        extended_title="$(jq -r '.extended_title' <<< "$item")"

        if [[ -n "${extended:-}" ]]; then
            extended_html="$(
                cat <<-EOF
<details><summary>$extended_title</summary>

\`\`\`terraform
$extended
\`\`\`
</details>
EOF

            )"

            echo "$extended_html" >>"$TMPFILE"
        fi

        echo "</td></tr>" >>"$TMPFILE"
        echo "</table>" >>"$TMPFILE"
    done
fi

echo "</details>" >>"$TMPFILE"
cat "$TMPFILE"
echo "tmpfile=$TMPFILE" >>"$GITHUB_OUTPUT"
