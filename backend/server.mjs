import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
loadEnv(path.join(__dirname, '.env'));
loadEnv(path.join(__dirname, '..', '.env'));

const env = process.env;
const port = Number.parseInt(env.PORT || '8787', 10);
const maxBodyBytes = Number.parseInt(env.MAX_BODY_BYTES || '12000000', 10);
const publicDir = path.join(__dirname, 'public');

const plantProfilePrompt = `Identify the plant in this image. Return only valid JSON with:
common_name, scientific_name, family, confidence, description, care_difficulty,
native_region, toxicity_level, toxicity_score, water_requirement, water_score,
sunlight_requirement, sunlight_score, temperature_range, humidity_level,
humidity_score, photosynthesis_score, oxygen_output, air_intake, air_release,
health_summary, story_markdown,
human_toxicity, pet_toxicity, toxic_compounds, care_intelligence,
environmental_intelligence, candidate_matches.

Use confidence, toxicity_score, water_score, sunlight_score, humidity_score,
and photosynthesis_score from 0 to 1.
candidate_matches must be an array of 2-4 possible visual matches. Each item
must include common_name, scientific_name, confidence, and reason. Include the
best match first. If confidence is below 0.58, keep the language cautious and
explain what visible details are missing.

human_toxicity must be an object with:
level, severity_score, touch_effects, ingestion_effects, skin_irritation,
child_warning, first_aid.

pet_toxicity must be an object with cats, dogs, and birds. Each must include:
severity, symptoms, emergency_level.

toxic_compounds must be an object with:
summary, harmful_compounds, alkaloids, oxalates, latex, sap_chemicals.

care_intelligence must be an object with:
water: {score, ideal_frequency, amount_estimation, overwatering_risk,
underwatering_symptoms, seasonal_changes, soil_moisture_preference},
sunlight: {score, direct_tolerance, indirect_preference, indoor_compatibility,
outdoor_compatibility, best_window_direction, heat_tolerance},
humidity: {score, ideal_humidity, dry_climate_tolerance,
misting_recommendations, ac_room_compatibility},
temperature: {score, minimum_temperature, maximum_temperature,
best_growth_temperature, winter_survival}.

environmental_intelligence must be an object with:
oxygen: {score, estimated_hourly_release, estimated_daily_release,
day_vs_night, air_purification_score, indoor_contribution,
nasa_clean_air_relevance, photosynthesis_efficiency, approximation_logic},
co2: {score, estimated_daily_absorption, photosynthesis_cycle,
carbon_capture_efficiency, indoor_air_improvement},
biology: {photosynthesis_type, transpiration_details, root_oxygen_exchange,
growth_respiration_details}.

estimated_hourly_release and estimated_daily_release must include realistic
approximate ranges in liters, for example "0.002-0.006 L oxygen/hour" and
"0.024-0.072 L oxygen/day assuming about 12 productive light hours". Clearly state
that values vary with leaf area, light intensity, humidity, and plant maturity.
oxygen_output must summarize both the hourly and daily oxygen estimates in one
plain-language sentence.

Known visual confusion rule:
If the image shows an upright pine-like succulent with narrow pointed green
leaves arranged around branching woody or succulent stems, consider Crassula
tetragona, also called Miniature Pine Tree, Pine Tree Crassula, or pine
succulent. Do not label it as Coral Beads or Nertera granadensis unless the
image clearly shows a low creeping mat with many round orange-red bead-like
berries. Coral Beads is not a pine-like succulent.

If the image is not a plant, set common_name to Unknown and explain in description.
Return only raw JSON. No markdown. No code blocks.`;

const diagnosisPrompt = `Act as a plant care assistant. Analyze visible plant health symptoms in this image.
Return only valid JSON with:
diagnosis, confidence, severity, treatment, recovery_time, prevention, steps.
steps must be an array of 3 to 5 short actionable strings.
If the photo is unclear, say so and recommend retaking the image.
Use confidence from 0 to 1.
Return only raw JSON. No markdown. No code blocks.`;

class ProviderError extends Error {
  constructor(provider, message, { status = 500, quota = false } = {}) {
    super(message);
    this.provider = provider;
    this.status = status;
    this.quota = quota;
  }
}

const server = http.createServer(async (req, res) => {
  applyCors(req, res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  try {
    const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

    if (req.method === 'GET' && url.pathname === '/api/health') {
      sendJson(res, 200, {
        ok: true,
        service: 'PlantVerse AI backend',
        providers: {
          gemini: Boolean(env.GEMINI_API_KEY),
          groq: Boolean(env.GROQ_API_KEY),
          openrouter: Boolean(env.OPENROUTER_API_KEY),
          plantnet: Boolean(env.PLANTNET_API_KEY),
          plantId: Boolean(env.PLANT_ID_API_KEY),
          perenual: Boolean(env.PERENUAL_API_KEY),
        },
      });
      return;
    }

    if (req.method === 'GET' && url.pathname === '/api/app-version') {
      sendJson(res, 200, appVersionPayload(req));
      return;
    }

    if ((req.method === 'GET' || req.method === 'HEAD') && !url.pathname.startsWith('/api/')) {
      if (await serveStatic(req, res, url.pathname)) return;
    }

    if (req.method === 'POST' && url.pathname === '/api/identify-plant') {
      const body = await readJson(req);
      const input = parseImageInput(body);
      const result = normalizeIdentityResult(await identifyPlant(input));
      sendJson(res, 200, result);
      return;
    }

    if (req.method === 'POST' && url.pathname === '/api/diagnose-disease') {
      const body = await readJson(req);
      const input = parseImageInput(body);
      const result = await diagnoseDisease(input);
      sendJson(res, 200, result);
      return;
    }

    sendJson(res, 404, { error: { message: 'Route not found.' } });
  } catch (error) {
    const status = error instanceof ProviderError ? error.status : 500;
    sendJson(res, status, {
      error: {
        message: error.message || 'Unexpected backend error.',
        provider: error.provider || 'backend',
        quota: Boolean(error.quota),
      },
    });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`PlantVerse AI backend listening on http://0.0.0.0:${port}`);
});

async function identifyPlant({ imageBase64, fileName }) {
  const failures = [];
  let fallbackReason = '';

  if (env.GEMINI_API_KEY) {
    try {
      const content = await generateGemini({
        prompt: plantProfilePrompt,
        imageBase64,
        fileName,
      });
      const result = decodeObject(content);
      result.recognition_mode ||= 'live_ai_backend';
      return result;
    } catch (error) {
      if (!(error instanceof ProviderError) || !error.quota) {
        throw error;
      }
      fallbackReason = `Gemini limit reached. ${error.message}`;
      failures.push(`Gemini unavailable: ${error.message}`);
    }
  }

  const external = await identifyWithExternalProviders({
    imageBase64,
    fileName,
    fallbackReason,
    failures,
  });
  if (external) return external;

  throw new ProviderError(
    'PlantVerse backend',
    `No cloud plant provider succeeded. ${failures.join(' | ')}`,
    { status: 503 },
  );
}

async function diagnoseDisease({ imageBase64, fileName }) {
  const failures = [];

  if (env.GEMINI_API_KEY) {
    try {
      return decodeObject(
        await generateGemini({
          prompt: diagnosisPrompt,
          imageBase64,
          fileName,
        }),
      );
    } catch (error) {
      if (!(error instanceof ProviderError) || !error.quota) {
        throw error;
      }
      failures.push(`Gemini unavailable: ${error.message}`);
    }
  }

  if (env.GROQ_API_KEY) {
    try {
      return decodeObject(
        await openAiVisionCompletion({
          provider: 'Groq',
          endpoint: 'https://api.groq.com/openai/v1/chat/completions',
          apiKey: env.GROQ_API_KEY,
          model: env.GROQ_VISION_MODEL || 'meta-llama/llama-4-scout-17b-16e-instruct',
          prompt: diagnosisPrompt,
          imageBase64,
          fileName,
          maxTokens: 1200,
        }),
      );
    } catch (error) {
      failures.push(`Groq unavailable: ${error.message}`);
    }
  }

  if (env.OPENROUTER_API_KEY) {
    try {
      return decodeObject(
        await openAiVisionCompletion({
          provider: 'OpenRouter',
          endpoint: 'https://openrouter.ai/api/v1/chat/completions',
          apiKey: env.OPENROUTER_API_KEY,
          model: env.OPENROUTER_MODEL || 'meta-llama/llama-4-maverick:free',
          prompt: diagnosisPrompt,
          imageBase64,
          fileName,
          maxTokens: 1200,
        }),
      );
    } catch (error) {
      failures.push(`OpenRouter unavailable: ${error.message}`);
    }
  }

  throw new ProviderError(
    'PlantVerse backend',
    `No cloud diagnosis provider succeeded. ${failures.join(' | ')}`,
    { status: 503 },
  );
}

async function identifyWithExternalProviders({
  imageBase64,
  fileName,
  fallbackReason,
  failures,
}) {
  if (env.GROQ_API_KEY) {
    try {
      const result = decodeObject(
        await openAiVisionCompletion({
          provider: 'Groq',
          endpoint: 'https://api.groq.com/openai/v1/chat/completions',
          apiKey: env.GROQ_API_KEY,
          model: env.GROQ_VISION_MODEL || 'meta-llama/llama-4-scout-17b-16e-instruct',
          prompt: plantProfilePrompt,
          imageBase64,
          fileName,
          maxTokens: 4000,
        }),
      );
      result.recognition_mode = 'groq_vision_backend';
      result.reference_sources = ['Groq vision AI: https://console.groq.com'];
      return withFallbackReason(result, fallbackReason);
    } catch (error) {
      failures.push(`Groq unavailable: ${error.message}`);
    }
  }

  if (env.OPENROUTER_API_KEY) {
    try {
      const result = decodeObject(
        await openAiVisionCompletion({
          provider: 'OpenRouter',
          endpoint: 'https://openrouter.ai/api/v1/chat/completions',
          apiKey: env.OPENROUTER_API_KEY,
          model: env.OPENROUTER_MODEL || 'meta-llama/llama-4-maverick:free',
          prompt: plantProfilePrompt,
          imageBase64,
          fileName,
          maxTokens: 4000,
        }),
      );
      result.recognition_mode = 'openrouter_vision_backend';
      result.reference_sources = ['OpenRouter AI: https://openrouter.ai'];
      return withFallbackReason(result, fallbackReason);
    } catch (error) {
      failures.push(`OpenRouter unavailable: ${error.message}`);
    }
  }

  if (env.PLANTNET_API_KEY) {
    try {
      return withFallbackReason(
        await identifyWithPlantNet({ imageBase64, fileName }),
        fallbackReason,
      );
    } catch (error) {
      failures.push(`Pl@ntNet unavailable: ${error.message}`);
    }
  }

  if (env.PLANT_ID_API_KEY) {
    try {
      return withFallbackReason(
        await identifyWithPlantId({ imageBase64, fileName }),
        fallbackReason,
      );
    } catch (error) {
      failures.push(`Plant.id unavailable: ${error.message}`);
    }
  }

  return null;
}

async function generateGemini({ prompt, imageBase64, fileName }) {
  const model = env.GEMINI_MODEL || 'gemini-2.5-flash-lite';
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': env.GEMINI_API_KEY,
    },
    body: JSON.stringify({
      contents: [
        {
          role: 'user',
          parts: [
            { text: prompt },
            {
              inline_data: {
                mime_type: mimeType(fileName),
                data: imageBase64,
              },
            },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.25,
      },
    }),
  });

  if (!response.ok) {
    const message = await providerErrorMessage(response, 'Gemini');
    throw new ProviderError('Gemini', message, {
      status: response.status,
      quota: isQuotaLimit(response.status, message),
    });
  }

  const data = await response.json();
  const text = extractGeminiText(data);
  if (!text.trim()) {
    throw new ProviderError('Gemini', 'Gemini returned an empty answer.');
  }
  return text;
}

async function openAiVisionCompletion({
  provider,
  endpoint,
  apiKey,
  model,
  prompt,
  imageBase64,
  fileName,
  maxTokens,
}) {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        {
          role: 'user',
          content: [
            { type: 'text', text: prompt },
            {
              type: 'image_url',
              image_url: {
                url: `data:${mimeType(fileName)};base64,${imageBase64}`,
              },
            },
          ],
        },
      ],
      temperature: 0,
      max_tokens: maxTokens,
    }),
  });

  if (!response.ok) {
    const message = await providerErrorMessage(response, provider);
    throw new ProviderError(provider, message, {
      status: response.status,
      quota: isQuotaLimit(response.status, message),
    });
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;
  if (typeof content !== 'string' || !content.trim()) {
    throw new ProviderError(provider, `${provider} returned an empty answer.`);
  }
  return content;
}

async function identifyWithPlantNet({ imageBase64, fileName }) {
  const url = new URL('https://my-api.plantnet.org/v2/identify/all');
  url.searchParams.set('api-key', env.PLANTNET_API_KEY);
  url.searchParams.set('lang', 'en');
  url.searchParams.set('include-related-images', 'false');

  const bytes = Buffer.from(imageBase64, 'base64');
  const form = new FormData();
  form.append('organs', 'leaf');
  form.append('images', new Blob([bytes], { type: mimeType(fileName) }), fileName || 'plant.jpg');

  const response = await fetch(url, { method: 'POST', body: form });
  if (!response.ok) {
    const message = await providerErrorMessage(response, 'Pl@ntNet');
    throw new ProviderError('Pl@ntNet', message, { status: response.status });
  }

  const data = await response.json();
  const top = Array.isArray(data.results) ? data.results[0] : null;
  if (!top?.species) {
    throw new ProviderError('Pl@ntNet', 'Pl@ntNet returned no plant match.');
  }

  const species = top.species;
  const scientificName = cleanText(species.scientificNameWithoutAuthor || species.scientificName);
  if (!scientificName) {
    throw new ProviderError('Pl@ntNet', 'Pl@ntNet returned no scientific name.');
  }

  const commonNames = Array.isArray(species.commonNames)
    ? species.commonNames.map((item) => cleanText(item)).filter(Boolean)
    : [];

  const profile = identityProfile({
    provider: 'Pl@ntNet',
    sourceUrl: 'https://my.plantnet.org/',
    commonName: commonNames[0] || scientificName,
    scientificName,
    family: cleanText(species.family?.scientificName) || 'Plant family not listed',
    confidence: clamp01(top.score),
    candidateMatches: plantNetCandidates(data.results),
  });
  return maybeEnrichWithPerenual(profile, scientificName);
}

async function identifyWithPlantId({ imageBase64, fileName }) {
  try {
    return await identifyWithPlantIdV3({ imageBase64, fileName });
  } catch (v3Error) {
    try {
      return await identifyWithPlantIdV2({ imageBase64, fileName });
    } catch (v2Error) {
      throw new ProviderError(
        'Plant.id',
        `Plant.id v3 failed: ${v3Error.message}; Plant.id v2 failed: ${v2Error.message}`,
      );
    }
  }
}

async function identifyWithPlantIdV3({ imageBase64 }) {
  const response = await fetch('https://api.plant.id/v3/identification', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Api-Key': env.PLANT_ID_API_KEY,
    },
    body: JSON.stringify({
      images: [`data:image/jpeg;base64,${imageBase64}`],
      similar_images: true,
    }),
  });

  if (!response.ok) {
    const message = await providerErrorMessage(response, 'Plant.id');
    throw new ProviderError('Plant.id', message, { status: response.status });
  }

  const data = await response.json();
  const top = data?.result?.classification?.suggestions?.[0];
  if (!top) throw new ProviderError('Plant.id', 'Plant.id returned no plant match.');

  const scientificName = cleanText(top.name);
  if (!scientificName) {
    throw new ProviderError('Plant.id', 'Plant.id returned no scientific name.');
  }

  const profile = identityProfile({
    provider: 'Plant.id',
    sourceUrl: 'https://www.kindwise.com/plant-id',
    commonName: scientificName,
    scientificName,
    family: 'Plant family not listed',
    confidence: clamp01(top.probability),
    candidateMatches: plantIdV3Candidates(data?.result?.classification?.suggestions),
  });
  return maybeEnrichWithPerenual(profile, scientificName);
}

async function identifyWithPlantIdV2({ imageBase64 }) {
  const response = await fetch('https://api.plant.id/v2/identify', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Api-Key': env.PLANT_ID_API_KEY,
    },
    body: JSON.stringify({
      images: [imageBase64],
      plant_details: ['common_names', 'url', 'taxonomy'],
    }),
  });

  if (!response.ok) {
    const message = await providerErrorMessage(response, 'Plant.id v2');
    throw new ProviderError('Plant.id v2', message, { status: response.status });
  }

  const data = await response.json();
  const top = Array.isArray(data.suggestions) ? data.suggestions[0] : null;
  if (!top) throw new ProviderError('Plant.id v2', 'Plant.id v2 returned no plant match.');

  const scientificName = cleanText(top.plant_name);
  if (!scientificName) {
    throw new ProviderError('Plant.id v2', 'Plant.id v2 returned no scientific name.');
  }

  const details = top.plant_details || {};
  const commonNames = Array.isArray(details.common_names)
    ? details.common_names.map((item) => cleanText(item)).filter(Boolean)
    : [];

  const profile = identityProfile({
    provider: 'Plant.id v2',
    sourceUrl: 'https://www.kindwise.com/plant-id',
    commonName: commonNames[0] || scientificName,
    scientificName,
    family: cleanText(details.taxonomy?.family) || 'Plant family not listed',
    confidence: clamp01(top.probability),
    candidateMatches: plantIdV2Candidates(data.suggestions),
  });
  return maybeEnrichWithPerenual(profile, scientificName);
}

function plantNetCandidates(results) {
  if (!Array.isArray(results)) return [];
  return results
    .slice(0, 4)
    .map((item) => {
      const species = item?.species || {};
      const commonNames = Array.isArray(species.commonNames)
        ? species.commonNames.map((name) => cleanText(name)).filter(Boolean)
        : [];
      const scientificName = cleanText(
        species.scientificNameWithoutAuthor || species.scientificName,
      );
      return {
        common_name: commonNames[0] || scientificName,
        scientific_name: scientificName,
        confidence: clamp01(item?.score),
        reason: 'Pl@ntNet visual candidate',
      };
    })
    .filter((item) => item.common_name || item.scientific_name);
}

function plantIdV3Candidates(suggestions) {
  if (!Array.isArray(suggestions)) return [];
  return suggestions
    .slice(0, 4)
    .map((item) => {
      const scientificName = cleanText(item?.name);
      return {
        common_name: scientificName,
        scientific_name: scientificName,
        confidence: clamp01(item?.probability),
        reason: 'Plant.id visual candidate',
      };
    })
    .filter((item) => item.scientific_name);
}

function plantIdV2Candidates(suggestions) {
  if (!Array.isArray(suggestions)) return [];
  return suggestions
    .slice(0, 4)
    .map((item) => {
      const scientificName = cleanText(item?.plant_name);
      const commonNames = Array.isArray(item?.plant_details?.common_names)
        ? item.plant_details.common_names.map((name) => cleanText(name)).filter(Boolean)
        : [];
      return {
        common_name: commonNames[0] || scientificName,
        scientific_name: scientificName,
        confidence: clamp01(item?.probability),
        reason: 'Plant.id visual candidate',
      };
    })
    .filter((item) => item.common_name || item.scientific_name);
}

function identityProfile({
  provider,
  sourceUrl,
  commonName,
  scientificName,
  family,
  confidence,
  candidateMatches = [],
}) {
  const hourlyOxygen =
    'Approx. 0.002-0.008 L oxygen/hour for a small healthy indoor plant in bright light.';
  const dailyOxygen =
    'Approx. 0.024-0.096 L oxygen/day, assuming about 12 productive light hours.';
  return {
    common_name: commonName,
    scientific_name: scientificName,
    family,
    confidence,
    recognition_mode: 'backend_external_api',
    candidate_matches: candidateMatches,
    reference_sources: [`${provider} plant identification result: ${sourceUrl}`],
    description:
      `Identified from the uploaded image by ${provider}. Care and toxicity stay conservative unless enriched by a source-backed care database.`,
    care_difficulty: 'Moderate until source-enriched',
    native_region: 'Not listed by provider response',
    toxicity_level: 'Unknown - verify before pet or child exposure',
    toxicity_score: 0.45,
    water_requirement: 'Check soil moisture before watering',
    water_score: 0.50,
    sunlight_requirement: 'Bright indirect light is safest until exact care is verified',
    sunlight_score: 0.60,
    temperature_range: '18-30 C',
    humidity_level: 'Average indoor humidity',
    humidity_score: 0.50,
    photosynthesis_score: 0.55,
    oxygen_output:
      `${hourlyOxygen} ${dailyOxygen} Exact output depends on species, leaf area, light, and plant health.`,
    air_intake: 'Carbon dioxide, light energy, and water.',
    air_release: 'Oxygen and water vapor during daylight photosynthesis.',
    health_summary:
      'Identification came from a backup plant provider. Use conservative care until richer botanical references are attached.',
    story_markdown:
      `${commonName} was identified by ${provider}. Treat it as a living system: observe light, soil moisture, and new growth before making major care changes.`,
    environmental_intelligence: {
      oxygen: {
        score: 0.55,
        estimated_hourly_release: hourlyOxygen,
        estimated_daily_release: dailyOxygen,
        day_vs_night:
          'Most oxygen release happens during active photosynthesis in bright daylight; at night the plant mainly respires.',
        air_purification_score: 0.38,
        indoor_contribution:
          'Small but measurable biological gas exchange; not a replacement for ventilation.',
        nasa_clean_air_relevance:
          'Clean-air relevance depends on exact species, plant density, and room ventilation.',
        photosynthesis_efficiency:
          'Moderate estimate until richer species-specific biology data is attached.',
        approximation_logic:
          'Estimated from a small-to-medium potted plant, typical indoor leaf area, and about 12 productive light hours.',
      },
    },
  };
}

async function maybeEnrichWithPerenual(profile, scientificName) {
  if (!env.PERENUAL_API_KEY) return profile;
  try {
    const url = new URL('https://www.perenual.com/api/v2/species-list');
    url.searchParams.set('key', env.PERENUAL_API_KEY);
    url.searchParams.set('q', scientificName);
    const response = await fetch(url);
    if (!response.ok) return profile;
    const data = await response.json();
    const item = Array.isArray(data.data) ? data.data[0] : null;
    if (!item) return profile;
    const watering = cleanText(item.watering);
    const sunlight = Array.isArray(item.sunlight) ? item.sunlight.join(', ') : cleanText(item.sunlight);
    const cycle = cleanText(item.cycle);
    return {
      ...profile,
      reference_sources: [
        ...(Array.isArray(profile.reference_sources) ? profile.reference_sources : []),
        'Perenual plant data: https://www.perenual.com/docs/api',
      ],
      ...(watering ? { water_requirement: watering } : {}),
      ...(sunlight ? { sunlight_requirement: sunlight } : {}),
      ...(cycle
        ? { health_summary: `${profile.health_summary} Perenual lists the plant cycle as ${cycle}.` }
        : {}),
    };
  } catch {
    return profile;
  }
}

async function providerErrorMessage(response, provider) {
  const text = await response.text();
  try {
    const data = JSON.parse(text);
    if (typeof data?.error?.message === 'string') return data.error.message;
    if (typeof data?.message === 'string') return data.message;
  } catch {
    // Use generic message below.
  }
  return `${provider} request failed with status ${response.status}.`;
}

function extractGeminiText(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return '';
  return parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('');
}

function decodeObject(text) {
  const cleaned = String(text)
    .replace(/^```json\s*/gm, '')
    .replace(/^```\s*/gm, '')
    .replace(/\s*```$/gm, '')
    .trim();
  const start = cleaned.indexOf('{');
  const end = cleaned.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new ProviderError('AI', `The AI response was not valid JSON: ${text}`);
  }
  return JSON.parse(cleaned.slice(start, end + 1));
}

function parseImageInput(body) {
  const fileName = cleanText(body.fileName || body.file_name) || 'plant.jpg';
  let imageBase64 = cleanText(body.imageBase64 || body.image_base64 || body.image);
  imageBase64 = imageBase64.replace(/^data:[^;]+;base64,/, '');
  if (!imageBase64) {
    throw new ProviderError('backend', 'imageBase64 is required.', { status: 400 });
  }
  return { imageBase64, fileName };
}

function normalizeIdentityResult(profile) {
  const result = { ...profile };
  const mode = cleanText(result.recognition_mode).toLowerCase();
  const originalCommon = cleanText(result.common_name);
  const originalScientific = cleanText(result.scientific_name);
  const originalFamily = cleanText(result.family);
  const confidence = scoreValue(result.confidence, defaultConfidence(mode));
  const candidates = normalizedCandidates(
    result,
    originalCommon,
    originalScientific,
    confidence,
  );
  const status = identityStatus({
    confidence,
    mode,
    unknownName: isUnknownIdentity(originalCommon, originalScientific),
    candidates,
  });

  result.confidence = confidence;
  result.candidate_matches = candidates;
  result.identity_status = status;
  result.identity_status_label = identityLabel(status, confidence);
  result.identity_warning = identityWarning(status, candidates);
  result.identity_confidence_reason = identityReason(status, mode, confidence);
  result.requires_identity_confirmation =
    status === 'needs_confirmation' || status === 'unconfirmed';

  if (status === 'unconfirmed' && mode !== 'offline_general') {
    return {
      ...result,
      original_common_name: originalCommon,
      original_scientific_name: originalScientific,
      original_family: originalFamily,
      ...unconfirmedOverlay(candidates),
    };
  }

  return result;
}

function normalizedCandidates(profile, commonName, scientificName, confidence) {
  const raw =
    profile.candidate_matches ||
    profile.possible_matches ||
    profile.alternatives ||
    profile.similar_species;
  const candidates = [];

  if (Array.isArray(raw)) {
    for (const item of raw) {
      const candidate = candidateFrom(item);
      if (candidate) candidates.push(candidate);
    }
  }

  if (!isUnknownIdentity(commonName, scientificName)) {
    candidates.unshift({
      common_name: commonName || scientificName,
      scientific_name: scientificName,
      confidence,
      reason: 'Top scan interpretation',
    });
  }

  const seen = new Set();
  return candidates
    .filter((item) => {
      const common = cleanText(item.common_name);
      const scientific = cleanText(item.scientific_name);
      const key = `${common.toLowerCase()}|${scientific.toLowerCase()}`;
      if (key === '|' || seen.has(key)) return false;
      seen.add(key);
      item.common_name = common;
      item.scientific_name = scientific;
      item.confidence = scoreValue(item.confidence, 0);
      item.reason = cleanText(item.reason) || 'Visual similarity';
      return true;
    })
    .sort((left, right) => right.confidence - left.confidence)
    .slice(0, 4);
}

function candidateFrom(value) {
  if (value && typeof value === 'object') {
    const common = cleanText(value.common_name || value.commonName || value.name);
    const scientific = cleanText(
      value.scientific_name || value.scientificName || value.canonicalName,
    );
    if (isUnknownIdentity(common, scientific)) return null;
    return {
      common_name: common || scientific,
      scientific_name: scientific,
      confidence: scoreValue(value.confidence || value.score, 0),
      reason: cleanText(value.reason) || 'Visual similarity',
    };
  }

  const text = cleanText(value);
  if (!text) return null;
  return {
    common_name: text,
    scientific_name: '',
    confidence: 0,
    reason: 'Possible visual alternative',
  };
}

function identityStatus({ confidence, mode, unknownName, candidates }) {
  if (mode === 'offline_general' || unknownName) return 'unconfirmed';
  if (mode === 'offline_taxonomy') return 'needs_confirmation';
  if (mode === 'offline_catalog') {
    return confidence >= 0.62 ? 'likely' : 'needs_confirmation';
  }
  if (confidence >= 0.78) return 'confirmed';
  if (confidence >= 0.58) return 'likely';
  const topCandidateConfidence = candidates.length
    ? scoreValue(candidates[0].confidence, 0)
    : 0;
  if (confidence >= 0.40 || topCandidateConfidence >= 0.40) {
    return 'needs_confirmation';
  }
  return 'unconfirmed';
}

function unconfirmedOverlay(candidates) {
  const possible = candidates.length
    ? ` Possible match: ${cleanText(candidates[0].common_name)}.`
    : '';
  return {
    common_name: 'Unconfirmed plant',
    scientific_name: 'Species not confirmed',
    family: 'Family not confirmed',
    description:
      `The scan looks plant-like, but confidence is too low to attach species-specific facts safely.${possible} Retake with clear leaves, stems, and full plant shape.`,
    care_difficulty: 'Moderate until identified',
    native_region: 'Unknown until identity is confirmed',
    toxicity_level: 'Unknown - keep away from pets and children',
    toxicity_score: 0.45,
    water_requirement: 'Check soil moisture before watering',
    water_score: 0.52,
    sunlight_requirement: 'Bright indirect light is safest until confirmed',
    sunlight_score: 0.62,
    temperature_range: '18-30 C',
    humidity_level: 'Average indoor humidity',
    humidity_score: 0.50,
    photosynthesis_score: 0.54,
    health_summary:
      'PlantVerse is not confident enough to name this plant. To avoid wrong care or toxicity facts, it is showing conservative guidance and possible matches instead of pretending certainty.',
    story_markdown:
      'This scan needs a clearer identity before PlantVerse can give species-specific care. Use a bright photo with several leaves, the stem structure, and the full plant silhouette.',
  };
}

function identityLabel(status, confidence) {
  if (status === 'confirmed') return `${Math.round(confidence * 100)}% confirmed`;
  if (status === 'likely') return `${Math.round(confidence * 100)}% likely match`;
  if (status === 'needs_confirmation') return 'Needs confirmation';
  return 'Unconfirmed plant';
}

function identityWarning(status, candidates) {
  if (status === 'confirmed') return 'Strong identity signal from the scan.';
  if (status === 'likely') {
    return 'Likely match. Confirm leaf shape, stem structure, and growth habit before high-risk care or toxicity decisions.';
  }
  if (status === 'needs_confirmation') {
    return 'The scan has a possible match, but PlantVerse is keeping the identity cautious. Compare the alternatives before trusting species-specific details.';
  }
  if (candidates.length === 0) {
    return 'Identity is too weak. Retake with clearer leaves, stems, and full plant shape.';
  }
  return 'Identity is too weak. Possible matches are shown only as leads, not confirmed facts.';
}

function identityReason(status, mode, confidence) {
  if (mode === 'offline_taxonomy') {
    return 'Matched by name/taxonomy signal only, not direct visual proof.';
  }
  if (mode === 'offline_general') {
    return 'No reliable catalog or cloud identity was available.';
  }
  return `Identity guard status: ${status} from ${Math.round(confidence * 100)}% confidence using ${mode}.`;
}

function isUnknownIdentity(commonName, scientificName) {
  const joined = `${commonName} ${scientificName}`.toLowerCase().trim();
  return (
    !joined ||
    joined.includes('unknown') ||
    joined.includes('unconfirmed') ||
    joined.includes('not confirmed') ||
    joined.includes('species pending')
  );
}

function defaultConfidence(mode) {
  if (mode === 'offline_general') return 0.28;
  if (mode === 'offline_taxonomy') return 0.46;
  if (mode === 'offline_catalog') return 0.68;
  return 0.50;
}

function withFallbackReason(profile, fallbackReason) {
  const reason = cleanText(fallbackReason);
  return reason ? { ...profile, fallback_reason: reason } : profile;
}

function cleanText(value) {
  return value == null ? '' : String(value).trim();
}

function clamp01(value) {
  return typeof value === 'number' && Number.isFinite(value)
    ? Math.max(0, Math.min(1, value))
    : 0.5;
}

function scoreValue(value, fallback = 0.5) {
  const numeric =
    typeof value === 'number' && Number.isFinite(value)
      ? value
      : Number.parseFloat(String(value || ''));
  if (!Number.isFinite(numeric)) return Math.max(0, Math.min(1, fallback));
  const scaled = numeric > 1 && numeric <= 100 ? numeric / 100 : numeric;
  return Math.max(0, Math.min(1, scaled));
}

function mimeType(fileName) {
  const lower = String(fileName || '').toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

function isQuotaLimit(status, message) {
  const lower = String(message || '').toLowerCase();
  return (
    status === 429 ||
    lower.includes('resource_exhausted') ||
    lower.includes('quota') ||
    lower.includes('rate limit') ||
    lower.includes('too many requests')
  );
}

function applyCors(req, res) {
  const allowedOrigins = (env.ALLOWED_ORIGINS || '*')
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
  const origin = req.headers.origin;
  const allowOrigin =
    allowedOrigins.includes('*') || !origin
      ? '*'
      : allowedOrigins.includes(origin)
        ? origin
        : allowedOrigins[0] || '*';
  res.setHeader('Access-Control-Allow-Origin', allowOrigin);
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  res.setHeader('Vary', 'Origin');
}

function sendJson(res, status, data) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(data));
}

function appVersionPayload(req) {
  const baseUrl = publicBaseUrl(req);
  const latestVersionCode = Number.parseInt(env.APP_VERSION_CODE || '4', 10);
  const latestVersionName = cleanText(env.APP_VERSION_NAME) || '1.0.3';
  const apkUrl =
    cleanText(env.APK_URL) ||
    `${baseUrl}/downloads/PlantVerse-AI-release.apk`;

  return {
    platform: 'android',
    latest_version_name: latestVersionName,
    latest_version_code: Number.isFinite(latestVersionCode)
      ? latestVersionCode
      : 2,
    min_supported_version_code: Number.parseInt(
      env.MIN_SUPPORTED_VERSION_CODE || '1',
      10,
    ),
    apk_url: apkUrl,
    force_update: env.FORCE_APP_UPDATE === 'true',
    release_notes: [
      'Fixes mobile web scan recovery so gallery/camera does not show getLostData errors.',
      'Adds identity confidence guard with possible plant matches.',
      'Avoids confident species facts when scan confidence is weak.',
      'Improved pine succulent identification.',
      'Warms PlantVerse cloud on app launch to reduce first-scan lag.',
      'Adds hourly and daily oxygen estimates in Plant Details.',
      'Reduces mobile web animation and glass blur for smoother scanning.',
      'Shows scan progress while cloud AI is working.',
      'Added Miniature Pine Tree / Crassula tetragona offline profile.',
    ],
  };
}

function publicBaseUrl(req) {
  const configured = cleanText(env.PUBLIC_BASE_URL);
  if (configured) return configured.replace(/\/+$/, '');
  const proto = req.headers['x-forwarded-proto'] || 'https';
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  return `${proto}://${host}`;
}

async function serveStatic(req, res, requestPath) {
  const indexPath = path.join(publicDir, 'index.html');
  if (!fs.existsSync(indexPath)) return false;

  const decodedPath = decodeURIComponent(requestPath);
  const normalizedPath = path
    .normalize(decodedPath)
    .replace(/^(\.\.[/\\])+/, '')
    .replace(/^[/\\]+/, '');
  let filePath = path.join(publicDir, normalizedPath);

  if (!filePath.startsWith(publicDir)) {
    sendJson(res, 403, { error: { message: 'Forbidden.' } });
    return true;
  }

  try {
    const stat = fs.existsSync(filePath) ? fs.statSync(filePath) : null;
    if (!stat || stat.isDirectory()) {
      filePath = indexPath;
    }
    await sendFile(req, res, filePath);
    return true;
  } catch {
    await sendFile(req, res, indexPath);
    return true;
  }
}

function sendFile(req, res, filePath) {
  return new Promise((resolve, reject) => {
    const headers = {
      'Content-Type': contentType(filePath),
      'Cache-Control': cacheControl(filePath),
    };
    res.writeHead(200, headers);
    if (req.method === 'HEAD') {
      res.end();
      resolve();
      return;
    }
    const stream = fs.createReadStream(filePath);
    stream.on('error', reject);
    stream.on('end', resolve);
    stream.pipe(res);
  });
}

function cacheControl(filePath) {
  const name = path.basename(filePath);
  if (
    name === 'index.html' ||
    name === 'main.dart.js' ||
    name === 'flutter.js' ||
    name === 'flutter_service_worker.js' ||
    name === 'version.json' ||
    name === '.last_build_id'
  ) {
    return 'no-cache';
  }
  return 'public, max-age=31536000, immutable';
}

function contentType(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  switch (ext) {
    case '.html':
      return 'text/html; charset=utf-8';
    case '.js':
      return 'application/javascript; charset=utf-8';
    case '.css':
      return 'text/css; charset=utf-8';
    case '.json':
      return 'application/json; charset=utf-8';
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.svg':
      return 'image/svg+xml';
    case '.wasm':
      return 'application/wasm';
    case '.ico':
      return 'image/x-icon';
    case '.apk':
      return 'application/vnd.android.package-archive';
    default:
      return 'application/octet-stream';
  }
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > maxBodyBytes) {
        reject(
          new ProviderError('backend', 'Request body is too large.', {
            status: 413,
          }),
        );
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      try {
        const text = Buffer.concat(chunks).toString('utf8');
        resolve(text ? JSON.parse(text) : {});
      } catch {
        reject(
          new ProviderError('backend', 'Request body must be valid JSON.', {
            status: 400,
          }),
        );
      }
    });
    req.on('error', reject);
  });
}

function loadEnv(filePath) {
  if (!fs.existsSync(filePath)) return;
  for (const rawLine of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#') || !line.includes('=')) continue;
    const index = line.indexOf('=');
    const key = line.slice(0, index).trim();
    const value = line.slice(index + 1).trim();
    if (key && process.env[key] == null) {
      process.env[key] = value;
    }
  }
}
