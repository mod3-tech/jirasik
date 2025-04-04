# jirasik

`jirasik` is a collection of shell scripts designed to interact with Jira using
the `jira-cli` tool. These scripts help automate various tasks such as viewing
sprint details, changing issue statuses, etc.

## Setup

1. [Set up a Jira API token here](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Run the `install` script to help install dependencies and configure the
   project:

```sh
./install
```

## Usage

Once installed you can run all scripts with `jirasik`.

Use `jira-cli` to run that tool with the configured Jira API token instead of
running `jira`.

Use `jira-api` to call the Jira API with the configured credentials.

## Dependencies

Current dependencies are:

- [homebrew](https://brew.sh/) for installing packages
- [jira-cli](https://github.com/ankitpokhrel/jira-cli)
- [gum](https://github.com/charmbracelet/gum)
- [skate](https://github.com/charmbracelet/skate)
