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

    const { messages, products, orgName } = await req.json()

    if (!Array.isArray(messages) || messages.length === 0) {
      return new Response(
        JSON.stringify({ error: 'messages array is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

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

    const userText = Array.isArray(messages)
      ? messages.map((m: any) => `${m.role || 'user'}: ${m.content || ''}`).join('\n')
      : ''

    const combinedPrompt = `${systemPrompt}\n\nConversation:\n${userText}`

    // Step 1: Ask the model to extract intent (keyword/category/etc.) and return only JSON.
    const lastUserMessage = Array.isArray(messages) && messages.length
      ? (messages[messages.length - 1].content || '')
      : ''

    const extractSystem = `You are a JSON extractor. Given a user's message, extract their shopping intent.
Return ONLY a JSON object (no explanations) with any of these keys when available: keyword, category, color, price, size.
If nothing is found, return an empty JSON object {}.`

    const extractResponse = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${GROQ_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: GROQ_MODEL,
          messages: [
            { role: 'system', content: extractSystem },
            { role: 'user', content: lastUserMessage },
          ],
          temperature: 0,
          max_tokens: 200,
        }),
      }
    )

    if (!extractResponse.ok) {
      const err = await extractResponse.text()
      throw new Error(`Intent extraction failed: ${err}`)
    }

    const extractData = await extractResponse.json()
    let aiResult: any = {}

    try {
      let raw = extractData?.choices?.[0]?.message?.content || ''
      // try to safely extract the JSON object from the model output
      const first = raw.indexOf('{')
      const last = raw.lastIndexOf('}')
      if (first !== -1 && last !== -1) {
        raw = raw.substring(first, last + 1)
      }
      aiResult = raw ? JSON.parse(raw) : {}
    } catch (e) {
      aiResult = {}
    }

    // Step 2: Search products using extracted intent
    const keyword = (aiResult.keyword || '').toLowerCase()
    const category = (aiResult.category || '').toLowerCase()

    let matched: any[] = []

    if (category) {
      matched = productList.filter((p: any) =>
        (p.category_name || '').toLowerCase().includes(category) && p.inStock
      )
    } else if (keyword) {
      matched = productList.filter((p: any) => {
        const name = (p.name || '').toLowerCase()
        const desc = (p.description || '').toLowerCase()
        return (name.includes(keyword) || desc.includes(keyword)) && p.inStock
      })
    }

    const productsToSend = (matched.length ? matched : []).slice(0, 5).map((p: any) => ({
      name: p.name,
      priceUsd: p.priceUsd,
      image: p.imageUrl,
    }))

    // Step 3: Fallback when no exact match
    if (productsToSend.length === 0) {
      const fallback = productList.length > 0
  ? productList.slice(0, 5)
  : [].map((p: any) => ({
        name: p.name,
        priceUsd: p.priceUsd,
        image: p.imageUrl,
      }))

      return new Response(
        JSON.stringify({ reply: "I didn’t find an exact match, here are some products 👇", products: fallback }),
        { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Successful filtered result
    const displayKeyword = category || keyword || 'products'
    return new Response(
      JSON.stringify({ reply: `Here are the available ${displayKeyword} 👇`, products: productsToSend }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
    // ✅ FIXED: Changed v1 → v1beta and model to gemini-2.0-flash
    const response = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${GROQ_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: GROQ_MODEL,
          messages: [
            {
              role: 'system',
              content: systemPrompt,
            },
            {
              role: 'user',
              content: userText,
            },
          ],
          temperature: 0.7,
          max_tokens: 200,
        }),
      }
    )

    if (!response.ok) {
      const err = await response.text()
      throw new Error(err)
    }

    const data = await response.json()

    const reply =
      data?.choices?.[0]?.message?.content?.trim() ||
      'Sorry, I couldn’t respond.'

    // Include an explicit `products` field so clients can rely on consistent shape.
    return new Response(
      JSON.stringify({ reply, products: [] }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `Internal error: ${e}` }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  }
})