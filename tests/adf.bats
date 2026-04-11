#!/usr/bin/env bats

load common.bash

# ─── Plain text ───────────────────────────────────────────────

@test "plain paragraph" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"Hello world"}]}')
  result=$(run_adf "$input")
  [ "$result" = "Hello world" ]
}

@test "multiple paragraphs" {
  input=$(wrap_body '
    {"type":"paragraph","content":[{"type":"text","text":"First"}]},
    {"type":"paragraph","content":[{"type":"text","text":"Second"}]}
  ')
  result=$(run_adf "$input")
  expected=$(printf "First\nSecond")
  [ "$result" = "$expected" ]
}

# ─── Text marks ───────────────────────────────────────────────

@test "bold text" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"bold","marks":[{"type":"strong"}]}]}')
  result=$(run_adf "$input")
  [ "$result" = "**bold**" ]
}

@test "italic text" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"italic","marks":[{"type":"em"}]}]}')
  result=$(run_adf "$input")
  [ "$result" = "*italic*" ]
}

@test "inline code" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"code","marks":[{"type":"code"}]}]}')
  result=$(run_adf "$input")
  [ "$result" = '`code`' ]
}

@test "strikethrough text" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"deleted","marks":[{"type":"strike"}]}]}')
  result=$(run_adf "$input")
  [ "$result" = "~~deleted~~" ]
}

@test "link" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"click here","marks":[{"type":"link","attrs":{"href":"https://example.com"}}]}]}')
  result=$(run_adf "$input")
  [ "$result" = "[click here](https://example.com)" ]
}

@test "nested marks: bold + italic" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"both","marks":[{"type":"strong"},{"type":"em"}]}]}')
  result=$(run_adf "$input")
  [ "$result" = "***both***" ]
}

# ─── Lists ────────────────────────────────────────────────────

@test "bullet list" {
  input=$(wrap_body '{"type":"bulletList","content":[
    {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"one"}]}]},
    {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"two"}]}]}
  ]}')
  result=$(run_adf "$input")
  expected=$(printf -- "- one\n\n- two\n")
  [ "$result" = "$expected" ]
}

@test "ordered list" {
  input=$(wrap_body '{"type":"orderedList","content":[
    {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"first"}]}]},
    {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"second"}]}]}
  ]}')
  result=$(run_adf "$input")
  expected=$(printf "1. first\n\n2. second\n")
  [ "$result" = "$expected" ]
}

# ─── Code blocks ──────────────────────────────────────────────

@test "code block with language" {
  input=$(wrap_body '{"type":"codeBlock","attrs":{"language":"python"},"content":[{"type":"text","text":"print(42)"}]}')
  result=$(run_adf "$input")
  expected=$(printf '```python\nprint(42)```')
  [ "$result" = "$expected" ]
}

@test "code block without language" {
  input=$(wrap_body '{"type":"codeBlock","content":[{"type":"text","text":"hello"}]}')
  result=$(run_adf "$input")
  expected=$(printf '```\nhello```')
  [ "$result" = "$expected" ]
}

# ─── Blockquote ───────────────────────────────────────────────

@test "blockquote" {
  input=$(wrap_body '{"type":"blockquote","content":[{"type":"paragraph","content":[{"type":"text","text":"quoted"}]}]}')
  result=$(run_adf "$input")
  expected=$(printf "> quoted")
  [ "$result" = "$expected" ]
}

# ─── Heading ──────────────────────────────────────────────────

@test "heading" {
  input=$(wrap_body '{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Title"}]}')
  result=$(run_adf "$input")
  [ "$result" = "Title" ]
}

# ─── Rule ─────────────────────────────────────────────────────

@test "horizontal rule" {
  input=$(wrap_body '{"type":"rule"}')
  result=$(run_adf "$input")
  expected=$(printf "\n---")
  [ "$result" = "$expected" ]
}

# ─── Inline elements ─────────────────────────────────────────

@test "mention" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"mention","attrs":{"text":"John Doe","id":"abc123"}}]}')
  result=$(run_adf "$input")
  [ "$result" = "@John Doe" ]
}

@test "emoji" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"emoji","attrs":{"shortName":":thumbsup:"}}]}')
  result=$(run_adf "$input")
  [ "$result" = ":thumbsup:" ]
}

@test "status badge" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"status","attrs":{"text":"IN PROGRESS"}}]}')
  result=$(run_adf "$input")
  [ "$result" = "[IN PROGRESS]" ]
}

@test "inline card (URL)" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"inlineCard","attrs":{"url":"https://example.com/pr/42"}}]}')
  result=$(run_adf "$input")
  [ "$result" = "https://example.com/pr/42" ]
}

# ─── Table ────────────────────────────────────────────────────

@test "simple table" {
  input=$(wrap_body '{"type":"table","content":[
    {"type":"tableRow","content":[
      {"type":"tableHeader","content":[{"type":"paragraph","content":[{"type":"text","text":"Name"}]}]},
      {"type":"tableHeader","content":[{"type":"paragraph","content":[{"type":"text","text":"Value"}]}]}
    ]},
    {"type":"tableRow","content":[
      {"type":"tableCell","content":[{"type":"paragraph","content":[{"type":"text","text":"foo"}]}]},
      {"type":"tableCell","content":[{"type":"paragraph","content":[{"type":"text","text":"bar"}]}]}
    ]}
  ]}')
  result=$(run_adf "$input")
  # Table headers get **bold**, rows are pipe-delimited
  [[ "$result" == *"**Name"* ]]
  [[ "$result" == *"**Value"* ]]
  [[ "$result" == *"| foo"* ]]
  [[ "$result" == *"bar"* ]]
}

# ─── Media ────────────────────────────────────────────────────

@test "media attachment" {
  input=$(wrap_body '{"type":"mediaSingle","content":[{"type":"media","attrs":{"type":"file","id":"abc","alt":"screenshot.png"}}]}')
  result=$(run_adf "$input")
  [ "$result" = "[attachment: screenshot.png]" ]
}

# ─── Panel ────────────────────────────────────────────────────

@test "info panel" {
  input=$(wrap_body '{"type":"panel","attrs":{"panelType":"warning"},"content":[{"type":"paragraph","content":[{"type":"text","text":"careful"}]}]}')
  result=$(run_adf "$input")
  expected=$(printf "[warning] careful")
  [ "$result" = "$expected" ]
}

# ─── Hard break ───────────────────────────────────────────────

@test "hard break within paragraph" {
  input=$(wrap_body '{"type":"paragraph","content":[{"type":"text","text":"line1"},{"type":"hardBreak"},{"type":"text","text":"line2"}]}')
  result=$(run_adf "$input")
  expected=$(printf "line1\nline2")
  [ "$result" = "$expected" ]
}

# ─── Null / empty input ──────────────────────────────────────

@test "null body returns empty string" {
  result=$(run_adf '{"body":null}')
  [ "$result" = "" ]
}

@test "null description returns empty string" {
  result=$(run_adf_desc '{"fields":{"description":null}}')
  [ "$result" = "" ]
}

# ─── Description filter ──────────────────────────────────────

@test "description filter works with fields.description envelope" {
  input=$(wrap_desc '{"type":"paragraph","content":[{"type":"text","text":"A description"}]}')
  result=$(run_adf_desc "$input")
  [ "$result" = "A description" ]
}

# ─── Expand ───────────────────────────────────────────────────

@test "expand block" {
  input=$(wrap_body '{"type":"expand","attrs":{"title":"Details"},"content":[{"type":"paragraph","content":[{"type":"text","text":"hidden content"}]}]}')
  result=$(run_adf "$input")
  expected=$(printf "Details\nhidden content")
  [ "$result" = "$expected" ]
}

# ─── Mixed content (integration) ─────────────────────────────

@test "mixed: paragraph + bold + bullet list" {
  input=$(wrap_body '
    {"type":"paragraph","content":[
      {"type":"text","text":"Please review "},
      {"type":"text","text":"carefully","marks":[{"type":"strong"}]}
    ]},
    {"type":"bulletList","content":[
      {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"item A"}]}]},
      {"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"item B"}]}]}
    ]}
  ')
  result=$(run_adf "$input")
  [[ "$result" == *"Please review **carefully**"* ]]
  [[ "$result" == *"- item A"* ]]
  [[ "$result" == *"- item B"* ]]
}
