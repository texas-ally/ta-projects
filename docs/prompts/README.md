# Content Generation Prompts

Prompts for the n8n Neighborhood Content Generator workflow (`wMfyygQVuaQutPR7`).

## Files

| File | Purpose | Used by |
|------|---------|---------|
| `neighborhood-content-system-prompt.md` | System prompt — writing style, rules, JSON output schema | OpenAI node system message |
| `neighborhood-content-user-prompt.md` | User prompt template — data injection and quality checks | OpenAI node user message |
| `../ai-summary-quality-control-checklist.md` | Post-generation QC checklist | Manual review + future automation |

## Key changes from previous prompts

| Before | After |
|--------|-------|
| Generic "real estate journalist" persona | Specific writer who knows Texas neighborhoods |
| 1,500-2,500 word HTML output | 80-120 word focused paragraphs per section |
| Single blob of HTML content | Structured JSON with separate fields per section |
| No quality guardrails in prompt | Inline quality checks before output |
| Generic openings acceptable | Generic openings explicitly banned |
| Data listing encouraged | Data must be woven into prose naturally |

## How to update the workflow

1. Edit the prompt files here (source of truth)
2. Copy the system prompt into the n8n workflow's OpenAI node system message
3. Update the "Build Content Prompt" Code node to use the user prompt template
4. Test with a single neighborhood: trigger workflow with `location_id` parameter
5. Compare output against the QC checklist
