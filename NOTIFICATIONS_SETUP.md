# Enabling Push Notifications (FCM + Supabase Webhooks)

Push notifications are critical for food delivery apps. By tying them directly to **Database Webhooks**, they will reliably trigger even if the Admin or Delivery Boy's phone loses connection right after updating an order.

## 1. Supabase Edge Function (Deno / TypeScript)

You need to deploy a Supabase Edge Function that catches webhooks from the `orders` table.
Save this code to `supabase/functions/order-alerts/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')!
const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

serve(async (req) => {
  const payload = await req.json()
  const oldRecord = payload.old_record
  const newRecord = payload.record

  // We only care about status changes
  if (oldRecord.status === newRecord.status) {
    return new Response("No status change", { status: 200 })
  }

  // 1. Fetch the user's FCM token from the users table
  const { data: user } = await supabase
    .from('users')
    .select('fcm_token')
    .eq('id', newRecord.user_id)
    .single()

  if (!user || !user.fcm_token) {
    return new Response("User has no FCM token", { status: 200 })
  }

  // 2. Draft the Notification Message
  let title = "Order Update"
  let body = `Your order is now ${newRecord.status}.`

  if (newRecord.status === 'accepted') {
    title = "Order Accepted! 🍳"
    body = "The kitchen has started preparing your healthy meal."
  } else if (newRecord.status === 'out_for_delivery') {
    title = "Out for Delivery! 🛵"
    body = "Your delivery partner is on the way. Track them live!"
  } else if (newRecord.status === 'delivered') {
    title = "Delivered! 🎉"
    body = "Enjoy your Ghar Jaisa Khana! See you next time."
  }

  // 3. Send to Firebase Cloud Messaging (FCM) API
  const response = await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      notification: { title, body },
      to: user.fcm_token,
      data: { order_id: newRecord.id, click_action: "FLUTTER_NOTIFICATION_CLICK" }
    }),
  })

  return new Response(JSON.stringify(await response.json()), {
    headers: { "Content-Type": "application/json" },
  })
})
```

### Deployment
1. Run `supabase functions deploy order-alerts`
2. Run `supabase secrets set FCM_SERVER_KEY=your_firebase_server_key`
3. Go to your Supabase Dashboard -> Database -> Webhooks.
4. Create a Webhook on the `orders` table. Select "Update" events, and point it to your deployed Edge Function.

## 2. Flutter App Setup

To register the user's phone to receive these notifications, add this in your Flutter app (usually in `splash_screen.dart` or after login):

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> setupPushNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission (iOS specifically)
  await messaging.requestPermission();

  // Get the unique FCM token for this device
  String? token = await messaging.getToken();
  
  if (token != null) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      // Save it securely in our Database
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
    }
  }
}
```

Whenever an admin or delivery boy updates the `status` dropdown, the database webhook automatically fires the Edge Function, which hits Firebase, pushing the notification directly to the user's Apple/Android device instantly.
