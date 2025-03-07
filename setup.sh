#!/usr/bin/env bash
. ./config

cat ./jirasik.txt
echo "Setting up jirasik..."

# Function to check if a command exists with custom help text
check_command() {
    local cmd=$1
    local help_text=$2
    local package_name=$3

    if ! command -v "$cmd" &>/dev/null; then
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
check_command "gum" "Please install gum (https://github.com/charmbracelet/gum)" "gum"
check_command "skate" "Please install skate (https://github.com/charmbracelet/skate)" "skate"
check_command "jira" "Please install jira-cli (https://github.com/ankitpokhrel/jira-cli)" "jira-cli"
check_command "jq" "Please install jq (https://stedolan.github.io/jq/)" "jq"

# TODO Set up api token and run jira init, read from config ~/.config/.jira/.config.yml
if [[ "$JIRA_TOKEN" == *"Key not found"* ]] || [[ -z "$JIRA_TOKEN" ]]; then
    echo -e "${RED}jirasik is not yet configured!${NC}"
    if [[ "$JIRA_TOKEN" == *"Key not found"* ]]; then
        JIRA_TOKEN=""
    fi
    JIRA_TOKEN=$(gum input --placeholder "Enter your Jira API token" --value "$JIRA_TOKEN")

    # If any of these are still empty quit
    if [[ -z "$JIRA_TOKEN" ]]; then
        echo -e "${RED}Configuration incomplete.${NC}"
        exit 1
    fi

    skate set "$SKATE_KEY_JIRA_TOKEN"@"$SKATE_DB" "$JIRA_TOKEN"
    echo -e "${GREEN}Token saved!${NC}"
    jira init
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

# Test the connection
echo "Testing connection to Jira..."
if jira-cli-command me; then
    echo -e "${GREEN}Connection successful!${NC}"
else
    echo -e "${RED}Connection failed. Please check your credentials.${NC}"
fi
