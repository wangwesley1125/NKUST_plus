# NKUST Plus 課程推薦後端（Cloudflare Workers + D1）

## 第一次部署

```bash
npm install
npx wrangler login                              # 用瀏覽器登入 Cloudflare 帳號
npx wrangler d1 create nkust-plus-ratings       # 把印出的 database_id 貼進 wrangler.toml
npm run db:init:remote                          # 建立資料表
npx wrangler secret put RATING_SECRET           # 貼一串很長的亂碼（例：openssl rand -hex 32 的結果）
npm run deploy                                  # 會印出 https://nkust-plus-ratings.xxx.workers.dev
```

把最後印出的網址填進 App 的 `CourseRatingAPI.baseURL`（CourseRatingStore.swift）。

> ⚠️ `RATING_SECRET` 設定後不要再改。改了之後，同一個學號會算出不同的雜湊，
> 等於所有人都變成新使用者，可以再投一次票。

## 本機測試

```bash
echo 'RATING_SECRET=local-test-secret' > .dev.vars
npm run db:init:local
npm run dev                                     # http://127.0.0.1:8787
# 手動觸發每日清除：
curl "http://127.0.0.1:8787/__scheduled?cron=0+19+*+*+*"
```

## API

| 方法 | 路徑 | 說明 |
|---|---|---|
| POST | `/v1/ratings` | `{ studentId, year, term, courseCode, courseName, teacher, level }`，level = 4 🔥 超級推薦 / 3 👍 還可以 / 2 😐 普普通通 / 1 💀 修到懷疑人生 / 0 取消 |
| POST | `/v1/stats` | `{ courses: [{ name, teacher }] }`，最多 30 筆，回傳順序與請求相同 |
| GET | `/health` | 健康檢查 |

- 學號只在伺服器端做 `HMAC-SHA256(RATING_SECRET, 學號)`，資料庫不存原文。
- 評分人數少於 5 人時，`/v1/stats` 只回傳 `hidden: true`，不回傳各等級人數。
- `/v1/stats` 只讀 `course_counts`（每門課 1 列），由 SQLite trigger 在每次評分時自動加減，省 D1 讀取額度。
- 每天 UTC 19:00（台灣 03:00）把 2 年前的個人評分彙總進 `course_stats` 後刪除；
  彙總與刪除在同一個交易裡，不會重複計算，歷年推薦數也不會消失。

## 資料表

- `ratings`：每人每班一票（主鍵 `course_key + user_hash`），保存 2 年
- `course_counts`：目前評分的各等級人數（trigger 自動維護）
- `course_stats`：已刪除評分的彙總數字，不含個人識別，永久保存
