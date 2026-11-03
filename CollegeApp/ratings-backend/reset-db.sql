-- ⚠️ 清空並移除所有資料表與 trigger。
-- 只在「還沒有正式評分資料」時使用（例如這次加入修別、留言欄位，資料庫還是空的）。
-- 上線、有人評分之後就不要再執行，否則所有評分與留言都會消失。
--
-- 用法：
--   npx wrangler d1 execute nkust-plus-ratings --remote --file=reset-db.sql
--   npm run db:init:remote

DROP TRIGGER IF EXISTS trg_ratings_insert;
DROP TRIGGER IF EXISTS trg_ratings_delete;
DROP TRIGGER IF EXISTS trg_ratings_update;
DROP TABLE IF EXISTS comment_reports;
DROP TABLE IF EXISTS ratings;
DROP TABLE IF EXISTS course_counts;
DROP TABLE IF EXISTS dept_counts;
DROP TABLE IF EXISTS course_stats;
