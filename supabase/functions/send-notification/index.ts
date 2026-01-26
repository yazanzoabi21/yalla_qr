// Supabase Edge Function to send OneSignal notifications
// Deploy: supabase functions deploy send-notification
// Call from Flutter: supabase.functions.invoke('send-notification', body: {...})

// Disable TypeScript checking in this Deno-edge function file to avoid
// editor/TS server errors for URL imports used by Deno runtime.
// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')!
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')!

interface NotificationRequest {
  type: 'user' | 'tag' | 'player_ids'
  // For type: 'user'
  userId?: string
  // optionally allow array to target multiple users
  userIds?: string[]
  // For type: 'tag'
  tagKey?: string
  tagValue?: string
  // For type: 'player_ids'
  playerIds?: string[]
  // Common fields
  title: string
  message: string
  data?: Record<string, any>
}

serve(async (req) => {
  try {
    // CORS headers
    if (req.method === 'OPTIONS') {
      return new Response('ok', { 
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        }
      })
    }

    // Parse request
    const requestData: NotificationRequest = await req.json()
    const { type, userId, tagKey, tagValue, playerIds, title, message, data } = requestData

    // Build OneSignal notification payload
    let body: any = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
    }

    // Add data if provided
    if (data) {
      body.data = data
    }

    // Set target based on type
    if (type === 'user') {
      // support single userId or array of userIds
      if (userId) {
        body.include_external_user_ids = [userId]
      } else if (Array.isArray(requestData.userIds) && requestData.userIds.length > 0) {
        body.include_external_user_ids = requestData.userIds
      } else {
        return new Response(
          JSON.stringify({ error: 'Missing userId or userIds for type=user' }),
          { status: 400, headers: { 'Content-Type': 'application/json' } }
        )
      }
    } else if (type === 'tag' && tagKey && tagValue) {
      body.filters = [
        {
          field: 'tag',
          key: tagKey,
          relation: '=',
          value: tagValue,
        }
      ]
    } else if (type === 'player_ids' && playerIds && playerIds.length > 0) {
      // direct device targeting (optional)
      body.include_player_ids = playerIds
    } else {
      return new Response(
        JSON.stringify({ error: 'Invalid request parameters' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    console.log('Sending OneSignal notification:', JSON.stringify(body, null, 2))

    // Send to OneSignal REST API
    const response = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(body),
    })

    const result = await response.json()

    // OneSignal returns recipients (number) when successful
    const recipients = result?.recipients ?? 0

    if (response.ok) {
      console.log('✅ Notification sent successfully:', result)

      // If recipients is 0, include helpful debug note
      if (recipients === 0) {
        console.warn('⚠️ OneSignal reported 0 recipients. Possible reasons:')
        console.warn('- External user IDs do not match any subscribed device')
        console.warn("- Devices are unsubscribed or not opted-in")
        console.warn('- Tags/filters matched no devices')
      }

      return new Response(
        JSON.stringify({ success: true, result, recipients }),
        {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    } else {
      console.error('❌ OneSignal API error:', result)

      // Try to extract error reason from OneSignal response
      const errorDetails = result?.errors ?? result

      return new Response(
        JSON.stringify({
          error: 'OneSignal API error',
          details: errorDetails,
          recipients: result?.recipients ?? 0,
        }),
        {
          status: response.status,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
        }
      )
    }

  } catch (error) {
    console.error('❌ Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { 
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        } 
      }
    )
  }
})
