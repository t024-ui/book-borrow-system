# AGENTS.md — 專案藍圖

## 專案名稱
115上愛的書庫預約書單

## 目標
建置校內「愛的書庫」線上選書登記系統，讓班級老師上網選書（1-3 本），管理者可查看各班登記狀況。

## 技術棧
- 前端：純 HTML + CSS + JavaScript（GitHub Pages）
- 後端：Supabase Cloud（PostgreSQL）
- Edge Functions：Deno（cron 排程）
- 版本控制：GitHub（t024-ui/book-borrow-system）

## 路線圖

### ✅ 已完成
- [x] Supabase 專案建立（dwfrqidfhpixqsjmdqzz）
- [x] 資料庫 4 張表（book_boxes、classes、borrow_records、waiting_queue）含 trigger、RLS
- [x] 25 本書箱匯入
- [x] 66 個班級匯入（一甲～六仁）
- [x] index.html 首頁上線（GitHub Pages）
- [x] Edge Functions 部署（remind_due、notify_queue）
- [x] 班級選書登記表 class_book_selections（含 RLS policies）
- [x] 改為選書流程：選擇年級班級 → 選 1-3 本書 → 送出登記
- [x] admin.html 管理者總表
- [x] 兩個 commit 推上 GitHub

### 📋 待辦
- [ ] 設定 SMTP（讓 remind_due 真的能寄信）
- [ ] Line Notify 整合（notify_queue function 啟用）
- [ ] 測試實際選書流程有無 bug
- [ ] 提供管理者匯出功能（CSV 或 Excel）

## 資料夾結構
```
G:\我的雲端硬碟\20260728借還書系統\
├── AGENTS.md               ← 專案藍圖（本檔）
├── handoff.md              ← session 交接檔
├── index.html              ← 班級選書首頁
├── admin.html              ← 管理者總表
├── public\
│   ├── index.html          ← GitHub Pages 版
│   └── admin.html          ← GitHub Pages 版
├── database\
│   └── migration.sql       ← 完整 DB schema
├── supabase\
│   └── functions\
│       ├── remind_due\
│       │   └── index.ts
│       └── notify_queue\
│           └── index.ts
```

## 重要決策紀錄
| 日期 | 決策 | 原因 |
|------|------|------|
| 2026-07-28 | 從借還書改為選書登記 | 使用者需求變更 |
| 2026-07-28 | 每人限選 1-3 本 | 符合校方實際運作 |
| 2026-07-28 | class_book_selections 用 UNIQUE(class_id, book_box_id) 避免重複登記 | 資料完整性 |
| 2026-07-28 | RLS 全開（公開讀寫） | 簡化前端，校內封閉網路環境 |
