# Neighborhood Content Generator — User Prompt Template

Used by the n8n Neighborhood Content Generator workflow (`wMfyygQVuaQutPR7`).
This is the `neighborhoodPrompt` template in the "Build Content Prompt By Type" Code node.

Variables in `${brackets}` are JavaScript template literals replaced at runtime.

---

Create structured content for the ${locName} neighborhood in ${city ? city + ', ' : ''}${county ? county + ' County, ' : ''}${state}.

${statsContext}

Return a JSON object with these exact keys:

```json
{
  "about_title": "A compelling section heading about ${locName} (e.g. 'Discover ${locName}')",
  "about_body": "MINIMUM 300 WORDS. 4-5 detailed paragraphs...",
  "living_title": "A section heading about living in ${locName} (e.g. 'Living in ${locName}')",
  "living_body": "MINIMUM 300 WORDS. 4-5 detailed paragraphs...",
  "amenities_title": "A section heading for nearby amenities (e.g. 'Things to Do Near ${locName}')",
  "amenities_body": "MINIMUM 100 WORDS. 2-3 paragraphs...",
  "nearby_title": "A section heading for nearby neighborhoods (e.g. 'Neighborhoods Near ${locName}')",
  "nearby_body": "MINIMUM 100 WORDS. 2-3 paragraphs...",
  "resources_title": "A section heading for local resources (e.g. 'Local Resources in ${locName}')",
  "resources_body": "MINIMUM 100 WORDS. 2-3 paragraphs...",
  "cta_title": "A call-to-action heading (e.g. 'Interested in ${locName}?')",
  "cta_body": "2-3 sentences...",
  "faq_answers": { ... },
  "excerpt": "35-45 word summary...",
  "meta_title": "60-character SEO title tag...",
  "meta_description": "155-character meta description..."
}
```

## Section-by-section requirements

**about_body** (MINIMUM 300 WORDS, 4-5 paragraphs):
Lead with what makes this specific place real and recognizable — named roads, named parks, named landmarks, named schools. Cover the neighborhood's development history, its character and overall vibe, dominant architectural styles and how the streetscape feels, the community culture and what draws people here, and how it fits into the broader ${city || 'city'} landscape. Weave in one compelling data point naturally (median home value, school rating, or income level). Close with a natural signal of who this neighborhood attracts — show it through the details, don't say "perfect for." Every sentence must be specific to THIS neighborhood — if a sentence would work for a different neighborhood, rewrite it.

**living_body** (MINIMUM 300 WORDS, 4-5 paragraphs):
Cover housing stock (home types, styles, typical lot sizes, price ranges, renovation trends), walkability and bikeability, parks and green spaces by name, popular local restaurants/cafes/shops, school zones and school quality by name, typical commute patterns referencing specific roads, and who tends to live here. Paint a picture of daily life — weekend routines, seasonal rhythms. Ground every claim in provided data.

**amenities_body** (MINIMUM 100 WORDS, 2-3 paragraphs):
Name specific parks, businesses, POIs from the provided data. Describe proximity and the experience of using them, not just their existence. Mention specific corridors, shopping centers, or popular spots.

**nearby_body** (MINIMUM 100 WORDS, 2-3 paragraphs):
Reference surrounding neighborhoods by name. Briefly characterize how they differ or complement this one — different price points, different character, different amenities.

**resources_body** (MINIMUM 100 WORDS, 2-3 paragraphs):
Mention relevant civic resources: school districts by name, county services, library branches, parks departments, community organizations. Only reference what was provided in the data.

**cta_body** (2-3 sentences):
A warm, specific invitation to explore further. Reference one distinctive quality of the neighborhood.

## FAQ answers

The `faq_answers` object must include these keys:

```json
{
  "good_place_to_live": "MINIMUM 80 WORDS. Is ${locName} a good place to live? Cover quality of life, community feel, standout features. Use specific data points.",
  "safety": "MINIMUM 80 WORDS. Is ${locName} safe? Discuss general safety reputation, community policing, neighborhood watch culture.",
  "schools": "MINIMUM 80 WORDS. How are the schools in ${locName}? Mention specific school districts and notable schools from the data provided.",
  "cost_of_living": "MINIMUM 120 WORDS. What is the cost of living in ${locName}? Use the REAL tax rates and cost-of-living indices provided in the stats. Break down property taxes by city, county, and school district rates, and give the combined estimated rate. Explain the BEA Regional Price Parity index (where 100 = US average) for overall cost of living, housing costs, goods, and utilities. Compare to the national average and note whether residents pay more or less. Mention Texas has no state income tax. If specific data is not available, discuss general trends for the ${city || 'city'} area.",
  "families": "MINIMUM 80 WORDS. Is ${locName} good for families? Discuss family-friendly amenities, parks, schools, and safety.",
  "known_for": "MINIMUM 80 WORDS. What is ${locName} known for? Cover reputation, notable landmarks, cultural identity, and distinguishing features.",
  "things_to_do": "MINIMUM 80 WORDS. What are things to do near ${locName}? Mention specific restaurants, parks, entertainment venues, and local events from the data.",
  "zip_code": "1-2 sentences. What ZIP code is ${locName} in?"
}
```

## Quality self-check before outputting

Before finalizing your JSON, verify against these checks:

1. **Uniqueness** — about_body contains at least 3 data points unique to this ZIP or location (a specific dollar figure, a specific school name, a specific POI). At least one named local landmark, park, or road is mentioned. The summary would be factually wrong if you swapped in a different neighborhood name.

2. **Accuracy** — All dollar figures come from the stats data provided above. School names match the data provided. The city and county match what was provided — not inferred from ZIP.

3. **Prose quality** — No section starts with "[Name] is a neighborhood located in..." No sentence appears generic enough to reuse on another page. All sections meet their minimum word counts.

4. **Specificity** — If you removed the neighborhood name, a local reader could still identify the area from the details alone. Every section references at least one named place, road, school, or data point.

5. **FAQ quality** — Each FAQ answer contains at least one data point specific to this neighborhood or its ZIP. The "What is ${locName}?" answer differs meaningfully from about_body. The cost_of_living answer uses real tax rates and RPP indices from the stats provided.

If any data field is empty or unavailable, skip it gracefully — do not invent numbers or names to fill gaps. Write around what you have.

Output ONLY the JSON object, no markdown fences or commentary.
