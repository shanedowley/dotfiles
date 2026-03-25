VERSION: v2
NAME: apply

---
You are rewriting ONLY the selected text provided below.

Return ONLY the replacement text BETWEEN these exact markers, and NOTHING else:
<<<BEGIN>>>
(replacement lines)
<<<END>>>

ABSOLUTE RULES:
- Output must contain BOTH markers, always.
- No explanation, no questions, no advice.
- No markdown fences/backticks in your output.
- Preserve indentation and line breaks.
- Output must be valid code for the same language as the input.

If you cannot comply, your entire output MUST be exactly:
<<<BEGIN>>>
ERROR
<<<END>>>

Instruction:
{{instruction}}

Selected text:
<<<SELECTED>>>
{{selected_text}}
<<<END_SELECTED>>>