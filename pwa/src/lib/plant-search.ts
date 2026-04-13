import { createEmptyPlant, type PlantData } from './types';

export interface SearchResult {
  latinName: string;
  commonName: string;
  wikidataId?: string;
  description?: string;
}

/**
 * Search for plants via Wikidata SPARQL — no CORS issues, no API key needed.
 * Searches for taxa (plants) by label matching the query.
 */
export async function searchPlants(query: string): Promise<SearchResult[]> {
  if (!query || query.length < 2) return [];

  const sparql = `
    SELECT DISTINCT ?item ?itemLabel ?itemDescription ?taxonName WHERE {
      {
        ?item wdt:P31/wdt:P279* wd:Q756 .
        ?item rdfs:label ?label .
        FILTER(CONTAINS(LCASE(?label), LCASE("${escapeSparql(query)}")))
        FILTER(LANG(?label) = "de" || LANG(?label) = "en" || LANG(?label) = "la")
      }
      OPTIONAL { ?item wdt:P225 ?taxonName . }
      SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en,la" . }
    }
    LIMIT 20
  `;

  const url = `https://query.wikidata.org/sparql?query=${encodeURIComponent(sparql)}&format=json`;

  const res = await fetch(url, {
    headers: { 'Accept': 'application/json' },
  });

  if (!res.ok) throw new Error(`Wikidata query failed: ${res.status}`);

  const data = await res.json();
  const seen = new Set<string>();
  const results: SearchResult[] = [];

  for (const binding of data.results.bindings) {
    const latinName = binding.taxonName?.value || '';
    const commonName = binding.itemLabel?.value || '';
    const key = latinName || commonName;
    if (seen.has(key)) continue;
    seen.add(key);

    results.push({
      latinName,
      commonName,
      wikidataId: binding.item?.value?.split('/').pop(),
      description: binding.itemDescription?.value,
    });
  }

  return results;
}

/**
 * Fetch detailed plant data from Wikidata for a specific entity.
 */
export async function fetchPlantDetails(wikidataId: string): Promise<Partial<PlantData>> {
  const sparql = `
    SELECT ?taxonName ?image ?height ?width ?hardiness ?commonNameDe ?commonNameEn WHERE {
      BIND(wd:${escapeSparql(wikidataId)} AS ?item)
      OPTIONAL { ?item wdt:P225 ?taxonName . }
      OPTIONAL { ?item wdt:P18 ?image . }
      OPTIONAL { ?item wdt:P2044 ?height . }
      OPTIONAL { ?item wdt:P2043 ?width . }
      OPTIONAL { ?item wdt:P1088 ?hardiness . }
      OPTIONAL {
        ?item rdfs:label ?commonNameDe .
        FILTER(LANG(?commonNameDe) = "de")
      }
      OPTIONAL {
        ?item rdfs:label ?commonNameEn .
        FILTER(LANG(?commonNameEn) = "en")
      }
    }
    LIMIT 1
  `;

  const url = `https://query.wikidata.org/sparql?query=${encodeURIComponent(sparql)}&format=json`;
  const res = await fetch(url, { headers: { 'Accept': 'application/json' } });
  if (!res.ok) return {};

  const data = await res.json();
  const b = data.results.bindings[0];
  if (!b) return {};

  const result: Partial<PlantData> = {};
  if (b.taxonName?.value) result.latinName = b.taxonName.value;
  if (b.commonNameDe?.value) result.commonName = b.commonNameDe.value;
  else if (b.commonNameEn?.value) result.commonName = b.commonNameEn.value;
  if (b.image?.value) result.imageUrl = b.image.value;
  if (b.height?.value) result.heightM = parseFloat(b.height.value);
  if (b.width?.value) result.widthM = parseFloat(b.width.value);
  if (b.hardiness?.value) result.climateZone = b.hardiness.value;

  return result;
}

/**
 * Search + fetch: find a plant and create a pre-filled PlantData object.
 */
export async function importPlantFromSearch(result: SearchResult): Promise<PlantData> {
  const plant = createEmptyPlant();
  plant.latinName = result.latinName;
  plant.commonName = result.commonName;

  if (result.wikidataId) {
    const details = await fetchPlantDetails(result.wikidataId);
    Object.assign(plant, details);
    // Keep the generated ID
    plant.id = crypto.randomUUID();
  }

  return plant;
}

function escapeSparql(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/'/g, "\\'");
}
