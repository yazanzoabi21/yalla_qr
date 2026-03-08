// Supabase Edge Function: shop-assistant
// Deploy: supabase functions deploy shop-assistant

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

    const { messages, products, orgName } = await req.json()

    if (!Array.isArray(messages) || messages.length === 0) {
      return new Response(
        JSON.stringify({ error: 'messages array is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Build product catalog context (cap at 80 products to stay within token budget)
    const productList = Array.isArray(products) ? products.slice(0, 80) : []
    const catalogLines = productList.map((p: any) => {
      const price = p.priceLbp && p.priceUsd
        ? `${p.priceLbp} LBP / $${p.priceUsd}`
        : p.priceLbp ? `${p.priceLbp} LBP`
        : p.priceUsd ? `$${p.priceUsd}`
        : 'Price not set'
      const stock = p.inStock ? 'In stock' : 'Out of stock'
      const desc = p.description ? ` — ${p.description}` : ''
      return `• ${p.name}${desc} | ${price} | ${stock}`
    }).join('\n')

    const systemPrompt = `You are a helpful shopping assistant for "${orgName || 'this store'}". Your job is to help customers find the right products, answer questions about what's available, suggest items based on their needs, and provide pricing information.

Here is the current product catalog:
${catalogLines || 'No products listed.'}

Rules:
- Only recommend products that are listed above and in stock.
- If asked about a product not in the list, politely say it's not available.
- Keep responses short and friendly (2-4 sentences max).
- You may suggest combinations or alternatives.
- Do not invent prices or details not given above.`

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
          { role: 'system', content: systemPrompt },
          ...messages,
        ],
        max_tokens: 250,
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
    const reply: string = data.choices?.[0]?.message?.content?.trim() ?? ''

    return new Response(
      JSON.stringify({ reply }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `Internal error: ${e}` }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  }
})
