#!/usr/bin/env bash
. ./config.sh

echo "Setting up Jira CLI configuration..."

# Function to check if a command exists with custom help text
check_command() {
    local cmd=$1
    local help_text=$2
    local package_name=$3

    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}Error: $cmd command not found${NC}"
        echo "${help_text:-Please install $cmd before continuing}"

        # If gum is not installed, ask user to confirm without using gum
        if [[ "$cmd" == "gum" ]]; then
            read -p "Would you like to install gum? (Y/n): " response
            if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
                echo "Installing gum..."
                brew install gum
            else
                echo "Installation skipped. Please install gum manually."
                exit 1
            fi
        # Otherwise use gum, ask to run the brew install command
        elif gum confirm "Would you like to install $package_name using brew?"; then
            echo "Installing $cmd..."
            brew install "$package_name"
        else
            echo "Installation skipped. Please install $cmd manually."
            exit 1
        fi

    fi
}

# Check required commands with custom installation instructions
check_command "gum" "Please install gum before continuing" "gum"
check_command "skate" "Please install skate before continuing" "skate"
check_command "jira" "Please install jira-cli before continuing" "jira-cli"

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
