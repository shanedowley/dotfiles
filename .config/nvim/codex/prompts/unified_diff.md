Generate a unified diff that applies my instruction to the provided snippet.

ABSOLUTE OUTPUT RULES:

- Output ONLY a unified diff. No prose. No explanations.
- No markdown fences/backticks.
- Use these exact filenames in the headers:
  --- a/selection
  +++ b/selection
- Include at least one hunk header starting with @@.

Instruction:
{{instruction}}
