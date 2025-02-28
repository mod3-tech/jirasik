#!/usr/bin/env bash
. ./config.sh

echo "Setting up Jira CLI configuration..."

# Check if gum command exists
if ! command -v gum &> /dev/null; then
    echo -e "${RED}Error: gum command not found${NC}"
    echo "Please install gum before continuing"
    exit 1
fi

# Check if skate command exists
if ! command -v skate &> /dev/null; then
    echo -e "${RED}Error: skate command not found${NC}"
    echo "Please install skate before continuing"
    exit 1
fi

# Check if jira command exists
if ! command -v jira &> /dev/null; then
    echo -e "${RED}Error: jira command not found${NC}"
    echo "Please install jira CLI before continuing"
    exit 1
fi

# Check configuration
if [[ "$JIRA_URL" == *"Key not found"* ]] || [[ -z "$JIRA_URL" ]] || [[ "$JIRA_USER" == *"Key not found"* ]] || [[ -z "$JIRA_USER" ]] || [[ "$JIRA_TOKEN" == *"Key not found"* ]] || [[ -z "$JIRA_TOKEN" ]]; then
    echo -e "${RED}jirasik is not yet configured!${NC}"

    if [[ "$JIRA_URL" == *"Key not found"* ]]; then
        JIRA_URL=""
    fi
    JIRA_URL=$(gum input --placeholder "Enter your Jira instance URL (https://your-domain.atlassian.net)" --value "$JIRA_URL")

    if [[ "$JIRA_USER" == *"Key not found"* ]]; then
        JIRA_USER=""
    fi
    JIRA_USER=$(gum input --placeholder "Enter your Jira user email" --value "$JIRA_USER")

    if [[ "$JIRA_TOKEN" == *"Key not found"* ]]; then
        JIRA_TOKEN=""
    fi
    JIRA_TOKEN=$(gum input --placeholder "Enter your Jira API token" --value "$JIRA_TOKEN")

    # If any of these are still empty quit
    if [[ -z "$JIRA_URL" ]] || [[ -z "$JIRA_USER" ]] || [[ -z "$JIRA_TOKEN" ]]; then
        echo -e "${RED}Configuration incomplete. Please fill in all fields.${NC}"
        exit 1
    fi

    # Save to skate
    skate set "$SKATE_KEY_JIRA_URL"@"$SKATE_DB" "$JIRA_URL"
    skate set "$SKATE_KEY_JIRA_USER"@"$SKATE_DB" "$JIRA_USER"
    skate set "$SKATE_KEY_JIRA_TOKEN"@"$SKATE_DB" "$JIRA_TOKEN"
    echo -e "${GREEN}Configuration saved!${NC}"
fi

# Test the connection
echo "Testing connection to Jira..."
if jira-cli-command me; then
    echo -e "${GREEN}Connection successful!${NC}"
else
    echo -e "${RED}Connection failed. Please check your credentials.${NC}"
fi

# Check issue key
if [[ "$JIRA_ISSUE_KEY" == *"Key not found"* ]] || [[ -z "$JIRA_ISSUE_KEY" ]]; then
    if [[ "$JIRA_ISSUE_KEY" == *"Key not found"* ]]; then
        JIRA_ISSUE_KEY=""
    fi
    JIRA_ISSUE_KEY=$(gum input --placeholder "Enter your Jira issue key prefix (KEY-123)" --value "$JIRA_ISSUE_KEY")
    skate set "$SKATE_KEY_JIRA_ISSUE_KEY"@"$SKATE_DB" "$JIRA_ISSUE_KEY"
fi
