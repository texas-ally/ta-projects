# Neighborhood Content Generator — User Prompt Template

Used by the n8n Neighborhood Content Generator workflow.
Variables in `{{brackets}}` are replaced with real data at runtime.

---

Write the neighborhood page content for the following location. Return ONLY valid JSON matching the schema described in your instructions.

## Location Data

Neighborhood: {{name}}
Type: {{type}}
City: {{city_name}}
County: {{county_name}}
State: Texas
ZIP Code(s): {{zip_codes}}

## Geography & Neighbors

Nearby Neighborhoods: {{nearby_neighborhoods}}
Named Roads: {{named_roads}}

## Schools (from TEA data)

{{schools_list}}

## Points of Interest

Named Parks or Landmarks: {{parks_landmarks}}
Named Businesses or POIs: {{pois_list}}

## Demographics (ACS data for ZIP {{primary_zip}})

Median Home Value: {{median_home_value}}
Median Household Income: {{median_household_income}}
Population: {{population}}
Median Age: {{median_age}}
Homeownership Rate: {{homeownership_rate}}

## Cost of Living

Property Tax Rate: {{property_tax_rate}}
HOA Fees (county avg): {{hoa_fees}}

## Additional Context

{{additional_context}}

---

## Quality requirements for this output

Before finalizing, verify your output against these checks:

1. **Uniqueness** — The about_body contains at least 3 data points unique to this ZIP or location (a specific dollar figure, a specific school name, a specific POI). The summary mentions at least one named local landmark, park, or road. The summary would be factually wrong if you swapped in a different neighborhood name.

2. **Accuracy** — All dollar figures come from the data provided above. School names match the TEA data listed above. The city and county match what was provided — not inferred from ZIP.

3. **Prose quality** — about_body is at least 80 words of flowing prose. No sentence appears generic enough to reuse on another page. The opening does NOT start with "[Name] is a neighborhood located in..." or "[Name] is a property owners association located in..."

4. **Specificity** — If you removed the neighborhood name, a local reader could still identify the area from the details alone. Every section references at least one named place, road, school, or data point from the input.

If any data field above is empty or unavailable, skip it gracefully — do not invent numbers or names to fill gaps. Write around what you have.
