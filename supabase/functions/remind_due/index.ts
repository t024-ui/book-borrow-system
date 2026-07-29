import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SMTP_HOST = Deno.env.get("SMTP_HOST") || "";
const SMTP_PORT = parseInt(Deno.env.get("SMTP_PORT") || "587");
const SMTP_USER = Deno.env.get("SMTP_USER") || "";
const SMTP_PASS = Deno.env.get("SMTP_PASS") || "";
const FROM_EMAIL = Deno.env.get("FROM_EMAIL") || "noreply@example.com";
const NOTIFY_EMAIL = Deno.env.get("NOTIFY_EMAIL") || "";

interface BorrowRecord {
  id: string;
  book_box_id: string;
  class_id: string;
  borrow_date: string;
  due_date: string;
  status: string;
}

interface BookBox {
  id: string;
  name: string;
}

interface Class {
  id: string;
  name: string;
  email: string;
}

async function sendEmail(to: string, subject: string, body: string) {
  if (!SMTP_HOST) {
    console.log(`[DEBUG] Would send email to ${to}: ${subject}`);
    return;
  }

  // Send via SMTP
  const encoder = new TextEncoder();
  const cmd = new Deno.Command("deno", {
    args: [
      "eval",
      `
        import { createTransport } from "npm:nodemailer@6";
        const t = createTransport({
          host: ${JSON.stringify(SMTP_HOST)},
          port: ${SMTP_PORT},
          secure: ${SMTP_PORT === 465},
          auth: { user: ${JSON.stringify(SMTP_USER)}, pass: ${JSON.stringify(SMTP_PASS)} }
        });
        await t.sendMail({
          from: ${JSON.stringify(FROM_EMAIL)},
          to: ${JSON.stringify(to)},
          subject: ${JSON.stringify(subject)},
          text: ${JSON.stringify(body)}
        });
        console.log("Email sent to", ${JSON.stringify(to)});
      `
    ],
  });
  const { code, stderr } = await cmd.output();
  if (code !== 0) console.error("Send email error:", new TextDecoder().decode(stderr));
}

Deno.serve(async (_req: Request) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // Calculate tomorrow's date
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const tomorrowStr = tomorrow.toISOString().split("T")[0];

    console.log(`Checking borrows due on ${tomorrowStr}...`);

    // Find all borrow records due tomorrow
    const { data: dueBorrows, error } = await supabase
      .from("borrow_records")
      .select("id, book_box_id, class_id, borrow_date, due_date, status")
      .eq("status", "borrowed")
      .eq("due_date", tomorrowStr);

    if (error) {
      console.error("Query error:", error);
      return new Response(JSON.stringify({ error: error.message }), { status: 500 });
    }

    if (!dueBorrows || dueBorrows.length === 0) {
      console.log("No borrows due tomorrow.");
      return new Response(JSON.stringify({ ok: true, notified: 0 }));
    }

    // Get all related book boxes and classes
    const boxIds = [...new Set(dueBorrows.map((b: BorrowRecord) => b.book_box_id))];
    const classIds = [...new Set(dueBorrows.map((b: BorrowRecord) => b.class_id))];

    const [boxesRes, classesRes] = await Promise.all([
      supabase.from("book_boxes").select("id, name").in("id", boxIds),
      supabase.from("classes").select("id, name, email").in("id", classIds),
    ]);

    const boxes = new Map(
      (boxesRes.data || []).map((b: BookBox) => [b.id, b.name]),
    );
    const classes = new Map(
      (classesRes.data || []).map((c: Class) => [c.id, c]),
    );

    const subject = "【書庫提醒】書箱歸還期限將至";
    let notified = 0;

    for (const borrow of dueBorrows as BorrowRecord[]) {
      const boxName = boxes.get(borrow.book_box_id) || "未知書箱";
      const cls = classes.get(borrow.class_id) as Class | undefined;
      const className = cls?.name || "未知班級";
      const dueDate = new Date(borrow.due_date).toLocaleDateString("zh-TW", {
        year: "numeric", month: "numeric", day: "numeric",
      });

      const body = `提醒通知\n\n班級：${className}\n書箱：${boxName}\n到期日：${dueDate}\n\n請記得在到期前歸還書箱，以便下一個班級使用。\n\n此為系統自動通知，請勿回覆。`;

      // Send to admin
      if (NOTIFY_EMAIL) {
        await sendEmail(NOTIFY_EMAIL, subject, body);
        notified++;
      }

      // Also send to class email if available
      if (cls?.email) {
        await sendEmail(cls.email, subject, body);
        notified++;
      }
    }

    console.log(`Notified ${notified} recipients.`);
    return new Response(JSON.stringify({ ok: true, notified }));
  } catch (err) {
    console.error("Unexpected error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
