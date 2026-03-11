# Content Generation Prompts

Source-of-truth prompts for the n8n Neighborhood Content Generator workflow (`wMfyygQVuaQutPR7`).

## Files

| File | Purpose | Maps to |
|------|---------|---------|
| `neighborhood-content-system-prompt.md` | System prompt — writing style, rules, output format | `jsonSystemPrompt` in Code node |
| `neighborhood-content-user-prompt.md` | User prompt — data injection, section specs, quality checks | `neighborhoodPrompt` in Code node |
| `../ai-summary-quality-control-checklist.md` | Post-generation QC checklist | Manual review + future automation |

## What changed from the live workflow

The live workflow (as of 2026-03-11) already uses structured JSON output for neighborhoods. These updated prompts keep all existing structure and add:

| Aspect | Live workflow | Updated prompts |
|--------|--------------|----------------|
| Writing persona | "Real estate journalist" | "Writer who knows this specific place" |
| Opening lines | No guidance | Explicitly banned generic patterns |
| Data handling | "Use them accurately" | "Weave into prose naturally, never list" |
| Specificity | "Be specific when possible" | "Every sentence must be specific to THIS neighborhood" |
| Quality checks | None | 5-point self-check before output |
| FAQ cost_of_living | Uses real tax/RPP data | Same, plus quality verification step |
| Lifestyle voice | Not mentioned | "Lifestyle over logistics" principle |
| Red flags | None | Auto-detect patterns documented in QC checklist |

## How to apply to the n8n workflow

1. Open the workflow in the n8n editor: https://texasally.app.n8n.cloud
2. Open the **"Build Content Prompt By Type"** Code node
3. Replace the `jsonSystemPrompt` string with the content from `neighborhood-content-system-prompt.md`
4. Replace the `neighborhoodPrompt` template with the content from `neighborhood-content-user-prompt.md`
5. The `statsContext`, `statsMap`, image prompts, and city/county/zip prompts remain unchanged
6. Test with a single neighborhood by triggering the webhook with a `location_id`
7. Compare the output against `ai-summary-quality-control-checklist.md`

## Stats context (unchanged)

The Code node builds a `statsContext` string from database fields. These are injected into the user prompt automatically:

- Population, Area
- Average home value, list price, price per sqft
- Market score, homes for sale, 1-year appreciation
- Median household income, median age, homeownership rate
- City/county/school district tax rates + combined rate
- BEA Regional Price Parity indices (all items, housing, goods, utilities)
- School district name
- Crime index
