-- ============================================
-- 借還書箱系統 - 資料庫 Schema
-- 請在 Supabase Dashboard > SQL Editor 執行
-- ============================================

-- 1. 書箱資料表
CREATE TABLE book_boxes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. 班級資料表
CREATE TABLE classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  email TEXT,
  line_token TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. 借閱記錄表
CREATE TABLE borrow_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_box_id UUID NOT NULL REFERENCES book_boxes(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  borrow_date DATE NOT NULL DEFAULT CURRENT_DATE,
  due_date DATE NOT NULL,
  return_date DATE,
  status TEXT NOT NULL DEFAULT 'borrowed' CHECK (status IN ('borrowed', 'returned', 'overdue')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. 等待佇列表
CREATE TABLE waiting_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_box_id UUID NOT NULL REFERENCES book_boxes(id) ON DELETE CASCADE,
  class_id UUID NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
  queue_order INT NOT NULL,
  notified BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(book_box_id, class_id)
);

-- 索引
CREATE INDEX idx_borrow_records_book_box ON borrow_records(book_box_id);
CREATE INDEX idx_borrow_records_class ON borrow_records(class_id);
CREATE INDEX idx_borrow_records_status ON borrow_records(status);
CREATE INDEX idx_waiting_queue_book_box ON waiting_queue(book_box_id);
CREATE INDEX idx_waiting_queue_order ON waiting_queue(book_box_id, queue_order);

-- 限制：一個班級同一時間只能借一個書箱
CREATE UNIQUE INDEX idx_one_active_borrow_per_class
  ON borrow_records(class_id)
  WHERE status = 'borrowed';

-- 限制：一個書箱同一時間只能被一個班級借走
CREATE UNIQUE INDEX idx_one_active_borrow_per_box
  ON borrow_records(book_box_id)
  WHERE status = 'borrowed';

-- 自動更新 updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_borrow_records_updated_at
  BEFORE UPDATE ON borrow_records
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- 自動計算到期日（借閱日 + 14 天）
CREATE OR REPLACE FUNCTION set_due_date()
RETURNS TRIGGER AS $$
BEGIN
  NEW.due_date := NEW.borrow_date + INTERVAL '14 days';
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_borrow_due_date
  BEFORE INSERT ON borrow_records
  FOR EACH ROW
  EXECUTE FUNCTION set_due_date();

-- 啟用 RLS（Row Level Security）
ALTER TABLE book_boxes ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE borrow_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE waiting_queue ENABLE ROW LEVEL SECURITY;

-- 允許公開讀取所有資料表（前端頁面使用 anon key 讀取）
CREATE POLICY "允許公開讀取書箱" ON book_boxes FOR SELECT USING (true);
CREATE POLICY "允許公開讀取班級" ON classes FOR SELECT USING (true);
CREATE POLICY "允許公開讀取借閱記錄" ON borrow_records FOR SELECT USING (true);
CREATE POLICY "允許公開讀取佇列" ON waiting_queue FOR SELECT USING (true);

-- 允許公開寫入（借閱、歸還、排隊）
CREATE POLICY "允許公開新增借閱" ON borrow_records FOR INSERT WITH CHECK (true);
CREATE POLICY "允許公開更新借閱" ON borrow_records FOR UPDATE USING (true);
CREATE POLICY "允許公開新增佇列" ON waiting_queue FOR INSERT WITH CHECK (true);
CREATE POLICY "允許公開更新佇列" ON waiting_queue FOR UPDATE USING (true);
CREATE POLICY "允許公開刪除佇列" ON waiting_queue FOR DELETE USING (true);

-- ============================================
-- 115上愛的書庫預約書單（從 Excel 匯入）
-- ============================================
INSERT INTO book_boxes (name) VALUES
  ('地球生病了，我們可以怎麼幫他？'),
  ('從前從前有一座森林'),
  ('真正老森林'),
  ('森林裡的特別教室'),
  ('國際安徒生大獎10：樹木的四季之歌-梨樹、樺樹、刺檗的故事'),
  ('生命之樹：雨林裡的大樹王國'),
  ('10層樓的樟樹公寓'),
  ('山櫻樹下的新家'),
  ('大樹的祕密'),
  ('樹：春夏秋冬，季節流轉'),
  ('爺爺和橡樹教會我的事'),
  ('樹木之歌'),
  ('上山種下一棵樹'),
  ('像大樹一樣的人'),
  ('我心中的樹'),
  ('種樹的男人'),
  ('我是一棵櫻花樹'),
  ('成為一棵樹'),
  ('椅子樹'),
  ('如果你種下一棵樹(注音)'),
  ('你真的知道樹是什麼嗎？'),
  ('老樹之歌'),
  ('最後一棵樹'),
  ('樹的小寶寶'),
  ('科學不思議4：神奇植物吹泡泡');

-- ============================================
-- 插入範例班級資料（請修改為實際班級名稱）
-- ============================================
INSERT INTO classes (name) VALUES
  ('301'), ('302'), ('303'), ('304'), ('305'),
  ('401'), ('402'), ('403'), ('404'), ('405'),
  ('501'), ('502'), ('503'), ('504'), ('505');
