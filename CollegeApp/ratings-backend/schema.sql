-- NKUST Plus 課程推薦 — Cloudflare D1 (SQLite) schema
--
-- 推薦程度 level：4 = 🔥 超級推薦、3 = 👍 還可以、2 = 😐 普普通通、1 = 💀 修到懷疑人生
--
-- ratings         ：每個人對每一班課的評分與修課心得（個人資料，保存 2 年後刪除）
-- comment_reports ：留言檢舉（同一人對同一則留言只算一次）
-- course_counts   ：目前 ratings 裡每門課＋老師的統計（全校），由 trigger 自動維護
-- dept_counts     ：同上，但再依「評分者科系」分開，由 trigger 自動維護
--                   → 查推薦數每門課只讀 1 列，不用掃全部評分（省 D1 讀取額度）
-- course_stats    ：已刪除評分的彙總數字（含科系，不含任何個人識別與留言，永久保存）
--
-- 每列評分對統計的貢獻：
--   c1~c4 = 各推薦程度人數、req / ele = 評分者修別為必修 / 選修的人數、cm = 可見留言數

CREATE TABLE IF NOT EXISTS ratings (
    id             INTEGER PRIMARY KEY,          -- 給留言檢舉用的固定編號
    course_key     TEXT    NOT NULL,             -- 學年-學期-課號，例如 115-1-0543
    user_hash      TEXT    NOT NULL,             -- HMAC-SHA256(伺服器密鑰, 學號)，不存學號原文
    year           TEXT    NOT NULL,             -- 學年，例如 115
    term           TEXT    NOT NULL,             -- 學期，例如 1
    course_name    TEXT    NOT NULL,             -- 正規化後的課名（NFKC + 去空白）
    teacher        TEXT    NOT NULL DEFAULT '',  -- 正規化後的老師名稱（對不到時為空字串）
    department     TEXT    NOT NULL DEFAULT '',  -- 評分者科系（學籍資料，正規化後；抓不到時為空字串）
    course_type    TEXT    NOT NULL DEFAULT '',  -- 評分者成績單上的修別：必修 / 選修 / 空字串
    level          INTEGER NOT NULL CHECK (level BETWEEN 1 AND 4),
    comment        TEXT    NOT NULL DEFAULT '',  -- 修課心得（最多 200 字，空字串 = 沒留言）
    comment_hidden INTEGER NOT NULL DEFAULT 0,   -- 被檢舉達門檻後隱藏
    updated_at     TEXT    NOT NULL,             -- ISO 8601（UTC）
    UNIQUE (course_key, user_hash)               -- 每人每班只能一票，重評就覆蓋
);

-- 每日清除兩年前資料
CREATE INDEX IF NOT EXISTS idx_ratings_updated ON ratings (updated_at);
-- 讀某門課的留言（只索引有留言的列，省空間）
CREATE INDEX IF NOT EXISTS idx_ratings_comments ON ratings (course_name, teacher, updated_at)
    WHERE comment <> '' AND comment_hidden = 0;

CREATE TABLE IF NOT EXISTS comment_reports (
    rating_id     INTEGER NOT NULL,
    reporter_hash TEXT    NOT NULL,
    reason        TEXT    NOT NULL DEFAULT '',
    created_at    TEXT    NOT NULL,
    PRIMARY KEY (rating_id, reporter_hash)
);

CREATE TABLE IF NOT EXISTS course_counts (
    course_name TEXT    NOT NULL,
    teacher     TEXT    NOT NULL DEFAULT '',
    c1  INTEGER NOT NULL DEFAULT 0,  -- 💀 修到懷疑人生
    c2  INTEGER NOT NULL DEFAULT 0,  -- 😐 普普通通
    c3  INTEGER NOT NULL DEFAULT 0,  -- 👍 還可以
    c4  INTEGER NOT NULL DEFAULT 0,  -- 🔥 超級推薦
    req INTEGER NOT NULL DEFAULT 0,  -- 評分者是必修
    ele INTEGER NOT NULL DEFAULT 0,  -- 評分者是選修
    cm  INTEGER NOT NULL DEFAULT 0,  -- 可見留言數
    PRIMARY KEY (course_name, teacher)
);

CREATE TABLE IF NOT EXISTS dept_counts (
    course_name TEXT    NOT NULL,
    teacher     TEXT    NOT NULL DEFAULT '',
    department  TEXT    NOT NULL,
    c1  INTEGER NOT NULL DEFAULT 0,
    c2  INTEGER NOT NULL DEFAULT 0,
    c3  INTEGER NOT NULL DEFAULT 0,
    c4  INTEGER NOT NULL DEFAULT 0,
    req INTEGER NOT NULL DEFAULT 0,
    ele INTEGER NOT NULL DEFAULT 0,
    cm  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (course_name, teacher, department)
);
CREATE INDEX IF NOT EXISTS idx_dept_counts_department ON dept_counts (department);

CREATE TABLE IF NOT EXISTS course_stats (
    course_name TEXT    NOT NULL,
    teacher     TEXT    NOT NULL DEFAULT '',
    department  TEXT    NOT NULL DEFAULT '',
    year        TEXT    NOT NULL,
    term        TEXT    NOT NULL,
    c1  INTEGER NOT NULL DEFAULT 0,
    c2  INTEGER NOT NULL DEFAULT 0,
    c3  INTEGER NOT NULL DEFAULT 0,
    c4  INTEGER NOT NULL DEFAULT 0,
    req INTEGER NOT NULL DEFAULT 0,
    ele INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (course_name, teacher, department, year, term)
);
CREATE INDEX IF NOT EXISTS idx_course_stats_department ON course_stats (department);

-- ---------- 自動維護 course_counts / dept_counts ----------
-- 註：不用 INSERT OR IGNORE。外層是 upsert 時，SQLite 會用外層的衝突策略蓋掉 trigger 裡的 OR IGNORE，
--     所以改用 INSERT ... WHERE NOT EXISTS。
-- 科系為空字串時不計入 dept_counts（全校數字照算）。

CREATE TRIGGER IF NOT EXISTS trg_ratings_insert AFTER INSERT ON ratings
BEGIN
    INSERT INTO course_counts (course_name, teacher)
    SELECT NEW.course_name, NEW.teacher
     WHERE NOT EXISTS (SELECT 1 FROM course_counts WHERE course_name = NEW.course_name AND teacher = NEW.teacher);
    UPDATE course_counts
       SET c1 = c1 + (NEW.level = 1), c2 = c2 + (NEW.level = 2),
           c3 = c3 + (NEW.level = 3), c4 = c4 + (NEW.level = 4),
           req = req + (NEW.course_type = '必修'), ele = ele + (NEW.course_type = '選修'),
           cm = cm + (NEW.comment <> '' AND NEW.comment_hidden = 0)
     WHERE course_name = NEW.course_name AND teacher = NEW.teacher;

    INSERT INTO dept_counts (course_name, teacher, department)
    SELECT NEW.course_name, NEW.teacher, NEW.department
     WHERE NEW.department <> ''
       AND NOT EXISTS (SELECT 1 FROM dept_counts
                        WHERE course_name = NEW.course_name AND teacher = NEW.teacher AND department = NEW.department);
    UPDATE dept_counts
       SET c1 = c1 + (NEW.level = 1), c2 = c2 + (NEW.level = 2),
           c3 = c3 + (NEW.level = 3), c4 = c4 + (NEW.level = 4),
           req = req + (NEW.course_type = '必修'), ele = ele + (NEW.course_type = '選修'),
           cm = cm + (NEW.comment <> '' AND NEW.comment_hidden = 0)
     WHERE course_name = NEW.course_name AND teacher = NEW.teacher AND department = NEW.department;
END;

CREATE TRIGGER IF NOT EXISTS trg_ratings_delete AFTER DELETE ON ratings
BEGIN
    UPDATE course_counts
       SET c1 = c1 - (OLD.level = 1), c2 = c2 - (OLD.level = 2),
           c3 = c3 - (OLD.level = 3), c4 = c4 - (OLD.level = 4),
           req = req - (OLD.course_type = '必修'), ele = ele - (OLD.course_type = '選修'),
           cm = cm - (OLD.comment <> '' AND OLD.comment_hidden = 0)
     WHERE course_name = OLD.course_name AND teacher = OLD.teacher;
    UPDATE dept_counts
       SET c1 = c1 - (OLD.level = 1), c2 = c2 - (OLD.level = 2),
           c3 = c3 - (OLD.level = 3), c4 = c4 - (OLD.level = 4),
           req = req - (OLD.course_type = '必修'), ele = ele - (OLD.course_type = '選修'),
           cm = cm - (OLD.comment <> '' AND OLD.comment_hidden = 0)
     WHERE course_name = OLD.course_name AND teacher = OLD.teacher AND department = OLD.department;
END;

CREATE TRIGGER IF NOT EXISTS trg_ratings_update
AFTER UPDATE OF level, course_name, teacher, department, course_type, comment, comment_hidden ON ratings
BEGIN
    -- 先扣掉舊的
    UPDATE course_counts
       SET c1 = c1 - (OLD.level = 1), c2 = c2 - (OLD.level = 2),
           c3 = c3 - (OLD.level = 3), c4 = c4 - (OLD.level = 4),
           req = req - (OLD.course_type = '必修'), ele = ele - (OLD.course_type = '選修'),
           cm = cm - (OLD.comment <> '' AND OLD.comment_hidden = 0)
     WHERE course_name = OLD.course_name AND teacher = OLD.teacher;
    UPDATE dept_counts
       SET c1 = c1 - (OLD.level = 1), c2 = c2 - (OLD.level = 2),
           c3 = c3 - (OLD.level = 3), c4 = c4 - (OLD.level = 4),
           req = req - (OLD.course_type = '必修'), ele = ele - (OLD.course_type = '選修'),
           cm = cm - (OLD.comment <> '' AND OLD.comment_hidden = 0)
     WHERE course_name = OLD.course_name AND teacher = OLD.teacher AND department = OLD.department;

    -- 再加上新的
    INSERT INTO course_counts (course_name, teacher)
    SELECT NEW.course_name, NEW.teacher
     WHERE NOT EXISTS (SELECT 1 FROM course_counts WHERE course_name = NEW.course_name AND teacher = NEW.teacher);
    UPDATE course_counts
       SET c1 = c1 + (NEW.level = 1), c2 = c2 + (NEW.level = 2),
           c3 = c3 + (NEW.level = 3), c4 = c4 + (NEW.level = 4),
           req = req + (NEW.course_type = '必修'), ele = ele + (NEW.course_type = '選修'),
           cm = cm + (NEW.comment <> '' AND NEW.comment_hidden = 0)
     WHERE course_name = NEW.course_name AND teacher = NEW.teacher;

    INSERT INTO dept_counts (course_name, teacher, department)
    SELECT NEW.course_name, NEW.teacher, NEW.department
     WHERE NEW.department <> ''
       AND NOT EXISTS (SELECT 1 FROM dept_counts
                        WHERE course_name = NEW.course_name AND teacher = NEW.teacher AND department = NEW.department);
    UPDATE dept_counts
       SET c1 = c1 + (NEW.level = 1), c2 = c2 + (NEW.level = 2),
           c3 = c3 + (NEW.level = 3), c4 = c4 + (NEW.level = 4),
           req = req + (NEW.course_type = '必修'), ele = ele + (NEW.course_type = '選修'),
           cm = cm + (NEW.comment <> '' AND NEW.comment_hidden = 0)
     WHERE course_name = NEW.course_name AND teacher = NEW.teacher AND department = NEW.department;
END;
