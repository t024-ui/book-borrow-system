Write-Host "=== 借還書箱系統 - 部署腳本 ==="
Write-Host ""

# 檢查 SUPABASE_ACCESS_TOKEN
if (-not $env:SUPABASE_ACCESS_TOKEN) {
    Write-Host "錯誤：請先設定 SUPABASE_ACCESS_TOKEN 環境變數"
    Write-Host "1. 到 https://supabase.com/dashboard/account/tokens 建立 Personal Access Token"
    Write-Host "2. 執行: `$env:SUPABASE_ACCESS_TOKEN = '你的_token'"
    exit 1
}

Write-Host "步驟 1：部署 Edge Functions..."
Write-Host ""

Write-Host "-> 部署 remind_due（每日到期提醒）..."
npx supabase functions deploy remind_due --project-ref dwfrqidfhpixqsjmdqzz
if (-not $?) { Write-Host "remind_due 部署失敗"; exit 1 }

Write-Host "-> 部署 notify_queue（排隊通知）..."
npx supabase functions deploy notify_queue --project-ref dwfrqidfhpixqsjmdqzz
if (-not $?) { Write-Host "notify_queue 部署失敗"; exit 1 }

Write-Host ""
Write-Host "=== 部署完成 ==="
Write-Host ""
Write-Host "=== 接下來請手動執行 ==="
Write-Host "1. 到 Supabase Dashboard > SQL Editor，執行 database/migration.sql"
Write-Host "2. 設定 Edge Functions 的環境變數："
Write-Host "   remind_due: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, FROM_EMAIL, NOTIFY_EMAIL"
Write-Host "   notify_queue: ADMIN_LINE_TOKEN"
Write-Host "3. 設定 remind_due 的 cron 排程（排程每天早上 8 點執行）"
Write-Host "4. 設定 Database Webhook：borrow_records 的 UPDATE 事件觸發 notify_queue"
Write-Host "5. 在 Supabase Dashboard > Table Editor 新增書箱和班級資料"
Write-Host "6. 用瀏覽器打開 public/index.html 即可使用"
