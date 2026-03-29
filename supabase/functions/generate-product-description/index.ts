// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY')!
const GROQ_MODEL = Deno.env.get('GROQ_MODEL') || 'llama-3.1-8b-instant'

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
    if (!GROQ_API_KEY) {
      return new Response(
        JSON.stringify({ error: 'GROQ_API_KEY secret is not set' }),
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

    const supportedLanguages: Record<string, string> = {
      en: 'English',
      ar: 'Arabic',
      fr: 'French',
    }
    const langCode = (typeof language === 'string' && supportedLanguages[language]) ? language : 'en'
    const langName = supportedLanguages[langCode]

    let context = `Product name: "${productName.trim()}"`
    if (categoryName) context += `\nCategory: ${categoryName}`
    if (priceLbp) context += `\nPrice: ${priceLbp} LBP`
    else if (priceUsd) context += `\nPrice: $${priceUsd}`

    const prompt = `You are a helpful assistant for small businesses. Write a short, appealing product description (2-3 sentences max) for the following product. Be concise, highlight key benefits, and make it sound desirable. Do not repeat the product name in the description. Write the description in ${langName}. Return only the description text with no extra formatting or prefixes.\n\n${context}`

    // Call GROQ/chat-compatible endpoint with the prompt as system message
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${GROQ_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages: [
          { role: 'system', content: prompt },
        ],
        temperature: 0.7,
        max_tokens: 200,
      }),
    })

    if (!response.ok) {
      const err = await response.text()
      return new Response(
        JSON.stringify({ error: `Groq API error: ${err}` }),
        { status: 502, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    const data = await response.json()
    const description: string = data?.choices?.[0]?.message?.content?.trim() ?? ''

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