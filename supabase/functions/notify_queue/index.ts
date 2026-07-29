import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const NOTIFY_EMAIL = Deno.env.get("NOTIFY_EMAIL") || "";

Deno.serve(async (req: Request) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Parse the webhook payload from Supabase Database Webhook
    const payload = await req.json();
    console.log("Webhook payload type:", payload.type);
    console.log("Webhook payload:", JSON.stringify(payload));

    // The payload structure depends on the webhook configuration.
    // It typically has: { type: "UPDATE", table: "borrow_records", record: { ... }, old_record: { ... } }

    const record = payload.record;
    const oldRecord = payload.old_record;

    // Only proceed if status changed to 'returned'
    if (!record || record.status !== "returned") {
      return new Response(JSON.stringify({ ok: true, skipped: "not a return event" }));
    }

    const boxId = record.book_box_id;

    // Get the book box name
    const { data: box } = await supabase
      .from("book_boxes")
      .select("name")
      .eq("id", boxId)
      .single();

    const boxName = box?.name || "未知書箱";
    console.log(`Book box "${boxName}" (${boxId}) was returned. Checking queue...`);

    // Get the next class in queue for this box
    const { data: nextInQueue } = await supabase
      .from("waiting_queue")
      .select("id, class_id")
      .eq("book_box_id", boxId)
      .eq("notified", false)
      .order("queue_order")
      .limit(1)
      .single();

    if (!nextInQueue) {
      console.log("No next class in queue for this box.");
      return new Response(JSON.stringify({ ok: true, skipped: "no queue" }));
    }

    // Get class info (including Line token)
    const { data: cls } = await supabase
      .from("classes")
      .select("id, name, line_token")
      .eq("id", nextInQueue.class_id)
      .single();

    if (!cls) {
      console.log("Class not found:", nextInQueue.class_id);
      return new Response(JSON.stringify({ error: "class not found" }), { status: 404 });
    }

    const message = `【書庫通知】輪到 ${cls.name} 借閱了\n\n書箱「${boxName}」已歸還，現在輪到 ${cls.name} 借閱。請老師儘快到系統登記借閱。\n\n系統網址：https://dwfrqidfhpixqsjmdqzz.supabase.co/functions/v1/`;

    if (NOTIFY_EMAIL) {
      console.log(`[EMAIL] To: ${NOTIFY_EMAIL}, Subject: 輪到 ${cls.name} 借閱書箱, Body: ${message}`);
    }

    // Mark as notified
    await supabase
      .from("waiting_queue")
      .update({ notified: true })
      .eq("id", nextInQueue.id);

    console.log(`Notified class "${cls.name}" (${cls.id}) for box "${boxName}".`);

    return new Response(JSON.stringify({ ok: true, notified: cls.name }));
  } catch (err) {
    console.error("Error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
