#!/bin/bash
# ADF (Atlassian Document Format) to Markdown conversion library

ADF_TO_MD_FILTER='
  def indent(d): "  " * d;

  def apply_marks(txt; marks):
    reduce (marks // [])[] as $m (txt;
      if $m.type == "strong" then "**" + . + "**"
      elif $m.type == "em" then "*" + . + "*"
      elif $m.type == "code" then "`" + . + "`"
      elif $m.type == "strike" then "~~" + . + "~~"
      elif $m.type == "link" then "[" + . + "](" + ($m.attrs.href // "") + ")"
      elif $m.type == "underline" then .
      else .
      end
    );

  def fmt(b; d):
    if b.type == "text" then
      apply_marks(b.text; b.marks)
    elif b.type == "hardBreak" then
      "\n" + indent(d)
    elif b.type == "paragraph" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "\n"
    elif b.type == "bulletList" then
      (reduce b.content[] as $li (""; . + indent(d) + "- " + (reduce ($li.content // [])[] as $c (""; . + fmt($c; d + 1))) + "\n"))
    elif b.type == "orderedList" then
      (reduce range(0; b.content | length) as $i (
        "";
        . + indent(d) + "\($i + 1). " + (reduce (b.content[$i].content // [])[] as $c (""; . + fmt($c; d + 1))) + "\n"
      ))
    elif b.type == "listItem" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "rule" then
      "\n---\n"
    elif b.type == "heading" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "\n"
    elif b.type == "codeBlock" then
      "```" + (b.attrs.language // "") + "\n" + (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "```\n"
    elif b.type == "blockquote" then
      (reduce (b.content // [])[] as $c (""; . + "> " + fmt($c; d)))
    elif b.type == "panel" then
      "[" + (b.attrs.panelType // "info") + "] " + (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "inlineCard" then
      (b.attrs.url // "[link]")
    elif b.type == "blockCard" then
      (b.attrs.url // "[link]") + "\n"
    elif b.type == "mention" then
      "@" + (b.attrs.text // b.attrs.id // "unknown")
    elif b.type == "emoji" then
      (b.attrs.shortName // b.attrs.text // "")
    elif b.type == "status" then
      "[" + (b.attrs.text // "status") + "]"
    elif b.type == "date" then
      (b.attrs.timestamp // "")
    elif b.type == "expand" then
      (b.attrs.title // "") + "\n" + (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "table" then
      (reduce (b.content // [])[] as $row (""; . + fmt($row; d))) + "\n"
    elif b.type == "tableRow" then
      "| " + (reduce (b.content // [])[] as $cell (""; . + fmt($cell; d) + " | ")) + "\n"
    elif b.type == "tableHeader" then
      "**" + (reduce (b.content // [])[] as $c (""; . + fmt($c; d))) + "**"
    elif b.type == "tableCell" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "mediaSingle" or b.type == "mediaGroup" then
      (reduce (b.content // [])[] as $c (""; . + fmt($c; d)))
    elif b.type == "media" then
      "[attachment: " + (b.attrs.alt // b.attrs.id // "media") + "]\n"
    elif b.content != null then
      (reduce b.content[] as $c (""; . + fmt($c; d)))
    else
      ""
    end;

  if .body == null then
    ""
  else
    reduce .body.content[] as $block (""; . + fmt($block; 0))
  end
'

adf_to_markdown() {
  echo "$1" | jq -r "$ADF_TO_MD_FILTER" 2>/dev/null
}
