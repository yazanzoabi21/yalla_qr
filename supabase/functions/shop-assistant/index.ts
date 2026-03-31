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

    const extractSystem = `
  You are a JSON extractor for a shopping assistant.

  Extract user intent into JSON with these fields when applicable:

  - keyword (product name)
  - category
  - priceSort ("asc" for cheapest, "desc" for most expensive)
  - priceFilter ("cheap", "expensive", or null)

  Rules:
  - If user asks for cheapest → priceSort = "asc"
  - If user asks for most expensive → priceSort = "desc"
  - If no price intent → leave priceSort null or omit it
  - Return ONLY a JSON object (no explanations)

  Examples:

  "cheap bag" → { "keyword": "bag", "priceSort": "asc" }
  "most expensive shoes" → { "keyword": "shoes", "priceSort": "desc" }
  "I need a bag" → { "keyword": "bag" }
  "hi" → {}
  `

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

    // Step 2: Decide whether this is a product query (keyword/category) or general chat
    // Primary extraction from the model
    let keyword = (aiResult.keyword || '').toLowerCase().trim()
    const category = (aiResult.category || '').toLowerCase().trim()

    // Lowercased user message text for fallback checks
    const msg = (lastUserMessage || '').toLowerCase()

    // Fallback: if extractor failed to extract keyword, try to find product names in the message
    if (!keyword) {
      const possibleMatches = productList.map((p: any) => (p.name || '').toLowerCase())
      for (const name of possibleMatches) {
        if (name && msg.includes(name)) {
          keyword = name
          break
        }
      }
    }

    // Image intent detection (user asking for images/photos)
    const wantsImage = msg.includes('image') || msg.includes('picture') || msg.includes('photo') || msg.includes('photo of') || msg.includes('image of')

    // Conversation memory: if user asks for an image with no keyword, try to find last-mentioned product in conversation
    if (wantsImage && !keyword) {
      let lastProductMention = ''
      for (let i = messages.length - 1; i >= 0; i--) {
        const m = (messages[i].content || '').toLowerCase()
        for (const p of productList) {
          const pname = (p.name || '').toLowerCase()
          if (pname && m.includes(pname)) {
            lastProductMention = pname
            break
          }
        }
        if (lastProductMention) break
      }
      if (lastProductMention) keyword = lastProductMention
    }

    const isProductQuery = Boolean(keyword) || Boolean(category) || wantsImage

    // If this is NOT a product query, forward to the model for a normal chat reply
    if (!isProductQuery) {
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
              { role: 'system', content: systemPrompt },
              { role: 'user', content: lastUserMessage },
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
      const reply = data?.choices?.[0]?.message?.content?.trim() || "I'm here to help 😊"

      return new Response(
        JSON.stringify({ reply, products: [] }),
        { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Otherwise, perform product matching
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

    // Support priceSort extracted from the intent extractor
    const priceSort = (aiResult.priceSort || aiResult.price_sort || null)

    if (priceSort === 'asc') {
      matched.sort((a: any, b: any) => {
        const aPrice = typeof a.priceUsd === 'number' ? a.priceUsd : parseFloat(a.priceUsd) || 999999
        const bPrice = typeof b.priceUsd === 'number' ? b.priceUsd : parseFloat(b.priceUsd) || 999999
        return aPrice - bPrice
      })
    }

    if (priceSort === 'desc') {
      matched.sort((a: any, b: any) => {
        const aPrice = typeof a.priceUsd === 'number' ? a.priceUsd : parseFloat(a.priceUsd) || 0
        const bPrice = typeof b.priceUsd === 'number' ? b.priceUsd : parseFloat(b.priceUsd) || 0
        return bPrice - aPrice
      })
    }

    const productsToSend = matched.slice(0, 5).map((p: any) => ({
      name: p.name,
      priceUsd: p.priceUsd,
      image: p.imageUrl,
    }))

    if (productsToSend.length > 0) {
      let replyText = `Here are the available ${keyword || category || 'products'} 👇`
      if (priceSort === 'asc') replyText = 'Here are the cheapest options 👇'
      if (priceSort === 'desc') replyText = 'Here are the most expensive options 👇'

      return new Response(
        JSON.stringify({ reply: replyText, products: productsToSend }),
        { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      )
    }

    // Smarter fallback when no products matched
    return new Response(
      JSON.stringify({ reply: "I didn’t find an exact match. Want me to suggest something similar? 😊", products: [] }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: `Internal error: ${e}` }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    )
  }
})