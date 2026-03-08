// Supabase Edge Function: generate-product-description
// Deploy: supabase functions deploy generate-product-description
// Set secret: supabase secrets set OPENROUTER_API_KEY=<your-key>

// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const OPENROUTER_API_KEY = Deno.env.get('OPENROUTER_API_KEY')!

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    if (!OPENROUTER_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'OPENROUTER_API_KEY secret is not set' }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    const { productName, categoryName, priceLbp, priceUsd, language } = await req.json()

    if (!productName || typeof productName !== 'string' || productName.trim().length === 0) {
      return new Response(
        JSON.stringify({ error: 'productName is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Supported languages — default to English
    const supportedLanguages: Record<string, string> = {
      en: 'English',
      ar: 'Arabic',
      fr: 'French',
    }
    const langCode = (typeof language === 'string' && supportedLanguages[language]) ? language : 'en'
    const langName = supportedLanguages[langCode]

    // Build context for the prompt
    let context = `Product name: "${productName.trim()}"`
    if (categoryName) context += `\nCategory: ${categoryName}`
    if (priceLbp) context += `\nPrice: ${priceLbp} LBP`
    else if (priceUsd) context += `\nPrice: $${priceUsd}`

    const prompt = `You are a helpful assistant for small businesses. Write a short, appealing product description (2-3 sentences max) for the following product. Be concise, highlight key benefits, and make it sound desirable. Do not repeat the product name in the description. Write the description in ${langName}. Return only the description text with no extra formatting or prefixes.\n\n${context}`

    const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://yallaqr.app',
        'X-Title': 'Yalla QR',
      },
      body: JSON.stringify({
        model: 'google/gemma-3-27b-it:free',
        messages: [
          { role: 'user', content: prompt }
        ],
        max_tokens: 150,
        temperature: 0.7,
      }),
    })

    if (!response.ok) {
      const errText = await response.text()
      return new Response(
        JSON.stringify({ error: `OpenRouter error: ${errText}` }),
        { status: 502, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    const data = await response.json()
    const description: string = data.choices?.[0]?.message?.content?.trim() ?? ''

    return new Response(
      JSON.stringify({ description }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  }
})
