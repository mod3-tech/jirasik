#!/usr/bin/env bash
. ./config

# Set up api token and run jira init, read from config ~/.config/.jira/.config.yml
if [[ "$JIRA_TOKEN" == *"Key not found"* ]] || [[ -z "$JIRA_TOKEN" ]]; then
    echo -e "${RED}jirasik is not yet configured!${NC}"
    if [[ "$JIRA_TOKEN" == *"Key not found"* ]]; then
        JIRA_TOKEN=""
    fi

    echo -e "${YELLOW}Please find or create an API token at https://id.atlassian.com/manage-profile/security/api-tokens${NC}"
    JIRA_TOKEN=$(gum input --placeholder "Enter your Jira API token" --value "$JIRA_TOKEN")

    if [[ -z "$JIRA_TOKEN" ]]; then
        echo -e "${RED}Configuration incomplete.${NC}"
        exit 1
    fi

    skate set "$SKATE_KEY_JIRA_TOKEN"@"$SKATE_DB" "$JIRA_TOKEN"
    echo -e "${GREEN}Token saved!${NC}"
    jira init
fi

# Test the connection
echo "Testing connection to Jira..."
if jira-cli-command me; then
    echo -e "${GREEN}Connection successful!${NC}"
else
    echo -e "${RED}Connection failed. Please check your credentials.${NC}"
    exit 1
fi

# Check configuration
if [[ "$JIRA_URL" == *"Key not found"* ]] || [[ -z "$JIRA_URL" ]] ||
    [[ "$JIRA_USER" == *"Key not found"* ]] || [[ -z "$JIRA_USER" ]] ||
    [[ "$JIRA_BOARD_ID" == *"Key not found"* ]] || [[ -z "$JIRA_BOARD_ID" ]] ||
    [[ "$JIRA_PROJECT_KEY" == *"Key not found"* ]] || [[ -z "$JIRA_PROJECT_KEY" ]]; then

    echo -e "${RED}jirasik is not yet configured!${NC}"

    JIRA_URL=$(grep 'server:' "$JIRACLI_CONFIG_FILE" | awk '{print $2}')
    skate set "$SKATE_KEY_JIRA_URL"@"$SKATE_DB" "$JIRA_URL"

    JIRA_USER=$(grep 'login:' "$JIRACLI_CONFIG_FILE" | awk '{print $2}')
    skate set "$SKATE_KEY_JIRA_USER"@"$SKATE_DB" "$JIRA_USER"

    JIRA_BOARD_ID=$(grep 'board:' "$JIRACLI_CONFIG_FILE" -A 1 | grep 'id:' | awk '{print $2}')
    skate set "$SKATE_KEY_JIRA_BOARD_ID"@"$SKATE_DB" "$JIRA_BOARD_ID"

    JIRA_PROJECT_KEY=$(grep 'project:' "$JIRACLI_CONFIG_FILE" -A 1 | grep 'key:' | awk '{print $2}')
    skate set "$SKATE_KEY_JIRA_PROJECT_KEY"@"$SKATE_DB" "$JIRA_PROJECT_KEY"

    # If any of these are still empty quit
    if [[ -z "$JIRA_URL" ]] || [[ -z "$JIRA_USER" ]] || [[ -z "$JIRA_BOARD_ID" ]] || [[ -z "$JIRA_PROJECT_KEY" ]]; then
        echo -e "${RED}Configuration incomplete.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Configuration saved!${NC}"
fi
