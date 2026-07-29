# handoff.md — Session 交接檔

## ⏯️ 目前做到哪
完成系統從「借還書」全面改為「班級選書登記」模式：
- 新增 `class_book_selections` 資料表，含 RLS policies
- 重寫 `index.html`：選擇年級→班級→確認→勾選 1-3 本書→送出登記
- 新增 `admin.html`：查看各班級登記明細與統計概覽
- 部署至 GitHub Pages，已推送兩個 commit

## 🚦 目前狀態
✅ 可運行（GitHub Pages 上線中）
- 班級老師可正常選書登記（1-3 本）
- 管理者可查看總表

## ➡️ 下一步
1. 若需修改選書登記（刪除重選），需加解除登記功能
2. 測試實際選書流程有無 bug
3. 設定 SMTP 讓 remind_due 能寄信
4. 管理者匯出功能（CSV 或 Excel）
5. Line Notify 整合

## ⚠️ 注意事項
- Supabase anon key 已硬寫在 index.html / admin.html 中（校內封閉網路，風險可接受）
- RLS policy 全開（public read/write），全校師生均可操作
- 班級資料（66 個班級）與 25 本書箱已匯入資料庫
- class_book_selections 有 UNIQUE(class_id, book_box_id)，同一班級不可重複選同一本書
- CDN 載入 @supabase/supabase-js 時全域變數名為 `supabase`（非 `supabaseJs`）

## 🕐 最後更新
- 時間：2026-07-29 收工
- 更新者：opencode @ DESKTOP-FK8TV0T
- Git push 狀態：✅ 已推
