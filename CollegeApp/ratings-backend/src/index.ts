/**
 * NKUST Plus 課程推薦 API（Cloudflare Workers + D1）
 *
 * 推薦程度 level：4 = 🔥 超級推薦、3 = 👍 還可以、2 = 😐 普普通通、1 = 💀 修到懷疑人生
 *
 * POST /v1/ratings            送出推薦（含修課心得）——每人每學期每門課只能一次
 *   { studentId, year, term, courseName, teacher, department, courseType, level: 1~4, comment?, courseCode? }
 *   同一學期＋課名視為同一門課。已推薦過：內容相同回 200（補傳），不同回 409 already_rated
 *
 * POST /v1/stats              批次查詢推薦數（回傳順序與請求相同）
 *   { courses: [{ name, teacher }], department? }   最多 30 筆
 *
 * GET  /v1/departments        有人評分過的科系（給膠囊按鈕用），依評分數排序
 *
 * GET  /v1/browse?department=&q=&limit=
 *   課程推薦列表；department 省略 = 全校；q = 課名關鍵字
 *
 * GET  /v1/comments?name=&teacher=&department=&limit=
 *   某門課（＋老師）的修課心得，新的在前；department 省略 = 全校
 *
 * POST /v1/comments/report    檢舉留言 { id, studentId, reason? }
 *   同一人對同一則只算一次；達 REPORT_HIDE_THRESHOLD 次自動隱藏
 *
 * 匿名：資料庫只存學號雜湊；留言者顯示為「匿名同學 #xxxxxx」（另一把雜湊，無法反推學號）。
 * 顯示門檻：評分人數 < MIN_VOTES 時不回傳各等級人數（wrangler.toml 的 [vars] 可調，預設 1 = 即時顯示）。
 *
 * Cron（每天一次）：把 2 年前的個人評分彙總進 course_stats（含科系、修別），再刪除評分與留言。
 */

export interface Env {
  DB: D1Database;
  /** wrangler secret put RATING_SECRET（任意長亂碼，設定後不要再改，否則同一人會變成新的雜湊） */
  RATING_SECRET: string;
  /** 顯示門檻（wrangler.toml [vars]），預設 1 */
  MIN_VOTES?: string;
}

const RETENTION_DAYS = 730; // 2 年
const MAX_BATCH = 30;
const MAX_BROWSE = 100;
const MAX_COMMENTS = 50;
const COMMENT_MAX_LENGTH = 200;
const REPORT_HIDE_THRESHOLD = 3;

/**
 * 不當用語（中文）。比對前會先 NFKC、轉小寫、拿掉所有空白與符號，
 * 所以「約.砲」「約 砲」「約‧砲」都會被當成「約砲」擋下。
 * 只放「兩個字以上、幾乎不會出現在正常課程心得裡」的詞，避免誤擋。可依實際狀況自行增加。
 */
const BLOCKED_TERMS = [
  // 罵人
  "幹你娘", "幹您娘", "操你媽", "操你妈", "靠北", "靠杯", "機掰", "雞掰", "機歪",
  "智障", "白癡", "白痴", "腦殘", "你去死", "去死吧",   // 不放「去死」：會擋到「不要去死背」
  // 色情（不放醫學 / 藝術課會用到的詞，例如裸體、陰道；也不放「色色」「a片」：會擋到「形形色色」「data片段」）
  "色情", "做愛", "做爱", "打砲", "打炮", "口交", "肛交", "自慰", "打手槍", "尻槍",
  "裸照", "裸聊", "成人影片", "雞巴", "鸡巴",
  "小穴", "奶子", "巨乳", "淫蕩", "騷貨", "婊子", "炮友", "砲友",
  // 性交易、拉客廣告
  "約砲", "約炮", "约炮", "援交", "一夜情", "賣淫", "卖淫", "妓女", "嫖妓", "包養", "包养",
  "外送茶", "茶訊", "性交易", "性服務", "加line", "加微信",   // 不放「加賴」：賴是常見姓氏
];

/** 不當用語（英文）：以「整個單字」比對，避免 sex 擋到 Sussex 之類的字 */
const BLOCKED_ENGLISH_WORDS = [
  "fuck", "fucking", "shit", "bitch", "porn", "porno", "sex", "sexy", "nude", "nudes",
  "xxx", "hentai", "onlyfans", "dick", "pussy",
];

/** 英文字母串起來比對（擋 f.u.c.k、p o r n 這種拆開寫的）：只放夠長、不易誤判的字 */
const BLOCKED_ENGLISH_SPELLED = ["fuck", "porn", "hentai", "onlyfans", "pussy"];

// ---------- 工具 ----------

/** 與 App 端一致的正規化：NFKC（全形轉半形）+ 去掉所有空白 */
export function normalize(s: string): string {
  return s.normalize("NFKC").replace(/\s+/gu, "");
}

/** 科系正規化：「電子工程系[建工|燕巢]」→「電子工程系」（去掉中括號裡的校區等附註） */
export function normalizeDepartment(s: string): string {
  return normalize(s).replace(/\[[^\]]*\]/gu, "").slice(0, 30);
}

function normalizeCourseType(v: unknown): string {
  if (!isString(v)) return "";
  const t = normalize(v);
  return t === "必修" || t === "選修" ? t : "";
}

/** 留言整理：保留原文（不做 NFKC，避免中文全形標點被改成半形），只去頭尾空白、壓縮連續空行 */
export function cleanComment(s: string): string {
  return s.normalize("NFC").replace(/\r\n?/g, "\n").replace(/\n{3,}/g, "\n\n").trim();
}

export function hasBlockedWord(text: string): boolean {
  // 檢查用的版本才做 NFKC（全形英文 ｆｕｃｋ、全形符號也一起處理）
  const lowered = text.normalize("NFKC").toLowerCase();

  // 1. 中文：拿掉所有空白、標點、符號、零寬字元後比對
  const compact = lowered.replace(/[^\p{L}\p{N}]/gu, "");
  if (BLOCKED_TERMS.some((w) => compact.includes(w))) return true;

  // 2. 英文：整個單字比對
  const words = lowered.split(/[^a-z]+/);
  if (words.some((w) => BLOCKED_ENGLISH_WORDS.includes(w))) return true;

  // 3. 英文拆開寫：只看英文字母、連起來比對
  const letters = lowered.replace(/[^a-z]/g, "");
  return BLOCKED_ENGLISH_SPELLED.some((w) => letters.includes(w));
}

/** 手機號碼（09 開頭 10 碼，中間可夾空白、- 或 .）：避免拉客廣告與洩漏個資 */
function hasPhoneNumber(text: string): boolean {
  return /0\s*9(?:[\s.\-]*\d){8}/.test(text.normalize("NFKC"));
}

/** 回傳不合格原因；合格回傳 null */
export function commentProblem(text: string): string | null {
  if ([...text].length > COMMENT_MAX_LENGTH) return `留言最多 ${COMMENT_MAX_LENGTH} 字`;
  if (hasBlockedWord(text)) return "留言含有不當用語";
  if (/https?:\/\/|www\./i.test(text)) return "留言不能包含網址";
  if (hasPhoneNumber(text)) return "留言不能包含電話號碼";
  return null;
}

/**
 * 老師名稱（已正規化）：使用者可以自己填，又會公開顯示，所以只允許文字，
 * 以及多位老師常用的分隔符號（、 , / · . 括號），最多 40 字；擋不當用語。
 */
export function teacherProblem(teacher: string): string | null {
  if (!teacher) return null;
  if ([...teacher].length > 40) return "授課教師名稱太長";
  if (!/^[\p{L}\p{M}·.,、/()]+$/u.test(teacher)) return "授課教師名稱只能包含文字";
  if (hasBlockedWord(teacher)) return "授課教師名稱含有不當用語";
  return null;
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function badRequest(message: string): Response {
  return json({ error: message }, 400);
}

async function hmacHex(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function isString(v: unknown): v is string {
  return typeof v === "string";
}

async function readJson<T>(req: Request): Promise<T | null> {
  try {
    return (await req.json()) as T;
  } catch {
    return null;
  }
}

function minVotes(env: Env): number {
  const n = Number.parseInt(env.MIN_VOTES ?? "1", 10);
  return Number.isFinite(n) && n >= 1 ? n : 1;
}

function isValidStudentId(v: unknown): v is string {
  return isString(v) && /^[A-Za-z0-9]{6,12}$/.test(v);
}

/** LIKE 用的關鍵字：正規化並跳脫 % _ \ */
function likePattern(q: string): string {
  const n = normalize(q).slice(0, 30);
  if (!n) return "";
  return `%${n.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
}

type CountsRow = {
  c1: number; c2: number; c3: number; c4: number;
  req?: number; ele?: number; cm?: number;
};

/** 把統計整理成回傳格式（套用顯示門檻） */
function summarize(row: Partial<CountsRow> | undefined, min: number) {
  const levels = [row?.c1, row?.c2, row?.c3, row?.c4].map((n) => Math.max(0, Number(n) || 0));
  const total = levels.reduce((a, b) => a + b, 0);
  const hidden = total < min;
  const recommended = levels[2] + levels[3];
  return {
    total,
    hidden,
    levels: hidden ? null : levels,
    recommended: hidden ? null : recommended,
    recommendRate: hidden || total === 0 ? null : recommended / total,
    required: Math.max(0, Number(row?.req) || 0),
    elective: Math.max(0, Number(row?.ele) || 0),
    comments: Math.max(0, Number(row?.cm) || 0),
  };
}

// ---------- POST /v1/ratings ----------

interface RatingBody {
  studentId?: unknown;
  year?: unknown;
  term?: unknown;
  courseCode?: unknown;
  courseName?: unknown;
  teacher?: unknown;
  department?: unknown;
  courseType?: unknown;
  level?: unknown;
  comment?: unknown;
}

async function handleRating(req: Request, env: Env): Promise<Response> {
  const body = await readJson<RatingBody>(req);
  if (!body) return badRequest("invalid json");

  const { studentId, year, term, courseCode, courseName, level } = body;
  const teacherRaw = body.teacher ?? "";
  const departmentRaw = body.department ?? "";

  if (!isValidStudentId(studentId)) return badRequest("invalid studentId");
  if (!isString(year) || !/^\d{2,3}$/.test(year)) return badRequest("invalid year");
  if (!isString(term) || !/^[1-4]$/.test(term)) return badRequest("invalid term");
  // 課號只有當學期成績頁有，歷年成績單（PDF）沒有，所以可省略；不拿來判斷是哪門課
  if (courseCode !== undefined && courseCode !== "" &&
      (!isString(courseCode) || !/^[A-Za-z0-9-]{1,12}$/.test(courseCode))) {
    return badRequest("invalid courseCode");
  }
  if (!isString(courseName)) return badRequest("invalid courseName");
  if (!isString(teacherRaw)) return badRequest("invalid teacher");
  if (!isString(departmentRaw)) return badRequest("invalid department");
  // 每門課只能推薦一次：不提供取消（level 0）
  if (typeof level !== "number" || !Number.isInteger(level) || level < 1 || level > 4) {
    return badRequest("invalid level");
  }

  let comment = "";
  if (body.comment !== undefined && body.comment !== null) {
    if (!isString(body.comment)) return badRequest("invalid comment");
    comment = cleanComment(body.comment);
    const problem = commentProblem(comment);
    if (problem) return json({ error: problem, code: "comment_rejected" }, 400);
  }

  const name = normalize(courseName);
  const teacher = normalize(teacherRaw);
  const department = normalizeDepartment(departmentRaw);
  const courseType = normalizeCourseType(body.courseType);
  if (name.length < 1 || name.length > 60) return badRequest("invalid courseName");
  const teacherIssue = teacherProblem(teacher);
  if (teacherIssue) return json({ error: teacherIssue, code: "comment_rejected" }, 400);

  const userHash = await hmacHex(env.RATING_SECRET, studentId.toUpperCase());
  // 同一學期同一門課（課名）＝同一筆；成績頁和歷年成績推薦同一門課不會重複
  const courseKey = `${year}-${term}-${name}`;

  const findExisting = () =>
    env.DB.prepare("SELECT level, comment FROM ratings WHERE course_key = ?1 AND user_hash = ?2")
      .bind(courseKey, userHash)
      .first<{ level: number; comment: string }>();

  /** 已推薦過：內容相同（例如沒網路補傳）當作成功；不同就拒絕 */
  const respondExisting = (existing: { level: number; comment: string }) => {
    if (existing.level === level && existing.comment === comment) {
      return json({ ok: true, level, comment, duplicate: true });
    }
    return json(
      { error: "你已經推薦過這門課了", code: "already_rated", level: existing.level, comment: existing.comment },
      409,
    );
  };

  const existing = await findExisting();
  if (existing) return respondExisting(existing);

  try {
    // course_counts / dept_counts 由 schema.sql 裡的 trigger 自動加減，這裡只要寫 ratings
    await env.DB.prepare(
      `INSERT INTO ratings (course_key, user_hash, year, term, course_name, teacher, department,
                            course_type, level, comment, comment_hidden, updated_at)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, 0, ?11)`,
    )
      .bind(courseKey, userHash, year, term, name, teacher, department,
            courseType, level, comment, new Date().toISOString())
      .run();
  } catch (e) {
    // 同一時間送了兩次：第二筆會撞 UNIQUE，回傳第一筆的結果
    if (String(e).includes("UNIQUE")) {
      const raced = await findExisting();
      if (raced) return respondExisting(raced);
    }
    throw e;
  }

  return json({ ok: true, level, comment });
}

// ---------- POST /v1/stats ----------

// 全校：course_counts 只讀 1 列；已封存的 course_stats 每學期每科系 1 列
const GLOBAL_SQL = `
SELECT
  COALESCE(cc.c1, 0)  + COALESCE(cs.c1, 0)  AS c1,
  COALESCE(cc.c2, 0)  + COALESCE(cs.c2, 0)  AS c2,
  COALESCE(cc.c3, 0)  + COALESCE(cs.c3, 0)  AS c3,
  COALESCE(cc.c4, 0)  + COALESCE(cs.c4, 0)  AS c4,
  COALESCE(cc.req, 0) + COALESCE(cs.req, 0) AS req,
  COALESCE(cc.ele, 0) + COALESCE(cs.ele, 0) AS ele,
  COALESCE(cc.cm, 0)                        AS cm
FROM (SELECT 1) AS one
LEFT JOIN course_counts cc ON cc.course_name = ?1 AND cc.teacher = ?2
LEFT JOIN (
  SELECT SUM(c1) c1, SUM(c2) c2, SUM(c3) c3, SUM(c4) c4, SUM(req) req, SUM(ele) ele
  FROM course_stats WHERE course_name = ?1 AND teacher = ?2
) cs
`;

// 單一科系
const DEPT_SQL = `
SELECT
  COALESCE(dc.c1, 0)  + COALESCE(cs.c1, 0)  AS c1,
  COALESCE(dc.c2, 0)  + COALESCE(cs.c2, 0)  AS c2,
  COALESCE(dc.c3, 0)  + COALESCE(cs.c3, 0)  AS c3,
  COALESCE(dc.c4, 0)  + COALESCE(cs.c4, 0)  AS c4,
  COALESCE(dc.req, 0) + COALESCE(cs.req, 0) AS req,
  COALESCE(dc.ele, 0) + COALESCE(cs.ele, 0) AS ele,
  COALESCE(dc.cm, 0)                        AS cm
FROM (SELECT 1) AS one
LEFT JOIN dept_counts dc ON dc.course_name = ?1 AND dc.teacher = ?2 AND dc.department = ?3
LEFT JOIN (
  SELECT SUM(c1) c1, SUM(c2) c2, SUM(c3) c3, SUM(c4) c4, SUM(req) req, SUM(ele) ele
  FROM course_stats WHERE course_name = ?1 AND teacher = ?2 AND department = ?3
) cs
`;

interface StatsBody {
  courses?: unknown;
  department?: unknown;
}

async function handleStats(req: Request, env: Env): Promise<Response> {
  const body = await readJson<StatsBody>(req);
  if (!body) return badRequest("invalid json");

  if (!Array.isArray(body.courses)) return badRequest("courses must be an array");
  if (body.courses.length === 0) return json({ stats: [] });
  if (body.courses.length > MAX_BATCH) return badRequest(`at most ${MAX_BATCH} courses`);

  const departmentRaw = body.department ?? "";
  if (!isString(departmentRaw)) return badRequest("invalid department");
  const department = normalizeDepartment(departmentRaw);

  const items: { name: string; teacher: string }[] = [];
  for (const c of body.courses) {
    if (typeof c !== "object" || c === null) return badRequest("invalid course");
    const { name, teacher } = c as { name?: unknown; teacher?: unknown };
    if (!isString(name)) return badRequest("invalid course name");
    const t = teacher ?? "";
    if (!isString(t)) return badRequest("invalid teacher");
    items.push({ name: normalize(name).slice(0, 60), teacher: normalize(t).slice(0, 40) });
  }

  const min = minVotes(env);
  const globalStmt = env.DB.prepare(GLOBAL_SQL);
  const deptStmt = env.DB.prepare(DEPT_SQL);
  const statements = items.flatMap((it) =>
    department
      ? [globalStmt.bind(it.name, it.teacher), deptStmt.bind(it.name, it.teacher, department)]
      : [globalStmt.bind(it.name, it.teacher)],
  );
  const results = await env.DB.batch<CountsRow>(statements);
  const step = department ? 2 : 1;

  const stats = items.map((it, i) => {
    const global = summarize(results[i * step].results[0], min);
    const base = { name: it.name, teacher: it.teacher, ...global };
    if (!department) return base;
    return { ...base, dept: { department, ...summarize(results[i * step + 1].results[0], min) } };
  });

  return json({ stats });
}

// ---------- GET /v1/departments ----------

async function handleDepartments(env: Env): Promise<Response> {
  const { results } = await env.DB.prepare(
    `SELECT department, SUM(c1 + c2 + c3 + c4) AS total
     FROM (
       SELECT department, c1, c2, c3, c4 FROM dept_counts
       UNION ALL
       SELECT department, c1, c2, c3, c4 FROM course_stats WHERE department <> ''
     )
     GROUP BY department
     HAVING total > 0
     ORDER BY total DESC, department
     LIMIT 200`,
  ).all<{ department: string; total: number }>();

  return json({ departments: results.map((r) => ({ department: r.department, total: Number(r.total) })) });
}

// ---------- GET /v1/browse ----------

const BROWSE_GLOBAL_SQL = `
SELECT course_name, teacher,
       SUM(c1) c1, SUM(c2) c2, SUM(c3) c3, SUM(c4) c4, SUM(req) req, SUM(ele) ele, SUM(cm) cm
FROM (
  SELECT course_name, teacher, c1, c2, c3, c4, req, ele, cm FROM course_counts
  UNION ALL
  SELECT course_name, teacher, c1, c2, c3, c4, req, ele, 0 FROM course_stats
)
WHERE (?1 = '' OR course_name LIKE ?1 ESCAPE '\\')
GROUP BY course_name, teacher
HAVING SUM(c1) + SUM(c2) + SUM(c3) + SUM(c4) >= ?2
ORDER BY SUM(c3) + SUM(c4) DESC, SUM(c1) + SUM(c2) + SUM(c3) + SUM(c4) DESC, course_name
LIMIT ?3
`;

const BROWSE_DEPT_SQL = `
SELECT course_name, teacher,
       SUM(c1) c1, SUM(c2) c2, SUM(c3) c3, SUM(c4) c4, SUM(req) req, SUM(ele) ele, SUM(cm) cm
FROM (
  SELECT course_name, teacher, c1, c2, c3, c4, req, ele, cm FROM dept_counts  WHERE department = ?4
  UNION ALL
  SELECT course_name, teacher, c1, c2, c3, c4, req, ele, 0  FROM course_stats WHERE department = ?4
)
WHERE (?1 = '' OR course_name LIKE ?1 ESCAPE '\\')
GROUP BY course_name, teacher
HAVING SUM(c1) + SUM(c2) + SUM(c3) + SUM(c4) >= ?2
ORDER BY SUM(c3) + SUM(c4) DESC, SUM(c1) + SUM(c2) + SUM(c3) + SUM(c4) DESC, course_name
LIMIT ?3
`;

async function handleBrowse(url: URL, env: Env): Promise<Response> {
  const department = normalizeDepartment(url.searchParams.get("department") ?? "");
  const pattern = likePattern(url.searchParams.get("q") ?? "");
  const limitRaw = Number.parseInt(url.searchParams.get("limit") ?? "60", 10);
  const limit = Math.min(Math.max(Number.isFinite(limitRaw) ? limitRaw : 60, 1), MAX_BROWSE);
  const min = minVotes(env);

  const stmt = department
    ? env.DB.prepare(BROWSE_DEPT_SQL).bind(pattern, min, limit, department)
    : env.DB.prepare(BROWSE_GLOBAL_SQL).bind(pattern, min, limit);
  const { results } = await stmt.all<CountsRow & { course_name: string; teacher: string }>();

  return json({
    department: department || null,
    courses: results.map((r) => ({ name: r.course_name, teacher: r.teacher, ...summarize(r, min) })),
  });
}

// ---------- GET /v1/comments ----------

async function handleComments(url: URL, env: Env): Promise<Response> {
  const name = normalize(url.searchParams.get("name") ?? "").slice(0, 60);
  const teacher = normalize(url.searchParams.get("teacher") ?? "").slice(0, 40);
  const department = normalizeDepartment(url.searchParams.get("department") ?? "");
  const limitRaw = Number.parseInt(url.searchParams.get("limit") ?? "30", 10);
  const limit = Math.min(Math.max(Number.isFinite(limitRaw) ? limitRaw : 30, 1), MAX_COMMENTS);
  if (!name) return badRequest("invalid name");

  // WHERE 要寫出 comment <> '' AND comment_hidden = 0，才會用到部分索引
  const sql = `SELECT id, user_hash, year, term, department, course_type, level, comment, updated_at
               FROM ratings
               WHERE course_name = ?1 AND teacher = ?2
                 AND comment <> '' AND comment_hidden = 0
                 ${department ? "AND department = ?4" : ""}
               ORDER BY updated_at DESC
               LIMIT ?3`;
  const stmt = department
    ? env.DB.prepare(sql).bind(name, teacher, limit, department)
    : env.DB.prepare(sql).bind(name, teacher, limit);

  const { results } = await stmt.all<{
    id: number; user_hash: string; year: string; term: string; department: string;
    course_type: string; level: number; comment: string; updated_at: string;
  }>();

  const comments = await Promise.all(
    results.map(async (r) => ({
      id: r.id,
      // 匿名代號：另一把雜湊的前 6 碼，同一人在各門課相同（方便封鎖），但無法反推學號
      author: (await hmacHex(env.RATING_SECRET, `author:${r.user_hash}`)).slice(0, 6),
      year: r.year,
      term: r.term,
      department: r.department,
      courseType: r.course_type,
      level: r.level,
      text: r.comment,
      updatedAt: r.updated_at,
    })),
  );

  return json({ comments });
}

// ---------- POST /v1/comments/report ----------

interface ReportBody {
  id?: unknown;
  studentId?: unknown;
  reason?: unknown;
}

async function handleReport(req: Request, env: Env): Promise<Response> {
  const body = await readJson<ReportBody>(req);
  if (!body) return badRequest("invalid json");
  const { id, studentId } = body;
  if (typeof id !== "number" || !Number.isInteger(id) || id < 1) return badRequest("invalid id");
  if (!isValidStudentId(studentId)) return badRequest("invalid studentId");
  const reason = isString(body.reason) ? body.reason.normalize("NFKC").trim().slice(0, 100) : "";

  const target = await env.DB.prepare(
    "SELECT id FROM ratings WHERE id = ?1 AND comment <> '' AND comment_hidden = 0",
  )
    .bind(id)
    .first<{ id: number }>();
  if (!target) return json({ ok: true, hidden: true }); // 已刪除或已隱藏

  const reporterHash = await hmacHex(env.RATING_SECRET, studentId.toUpperCase());

  const [, countResult] = await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO comment_reports (rating_id, reporter_hash, reason, created_at)
       VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT (rating_id, reporter_hash) DO NOTHING`,
    ).bind(id, reporterHash, reason, new Date().toISOString()),
    env.DB.prepare("SELECT COUNT(*) AS n FROM comment_reports WHERE rating_id = ?1").bind(id),
  ]);

  const reports = Number((countResult.results[0] as { n: number } | undefined)?.n ?? 0);
  const hidden = reports >= REPORT_HIDE_THRESHOLD;
  if (hidden) {
    await env.DB.prepare("UPDATE ratings SET comment_hidden = 1 WHERE id = ?1").bind(id).run();
  }
  return json({ ok: true, hidden });
}

// ---------- 定時：彙總後刪除 2 年前資料 ----------

export async function purgeOldRatings(env: Env, now = Date.now()): Promise<number> {
  const cutoff = new Date(now - RETENTION_DAYS * 86_400_000).toISOString();

  // D1 batch 是交易：彙總與刪除要嘛一起成功、要嘛一起失敗，不會重複計算。
  // 刪除時 trigger 會把 course_counts / dept_counts 扣掉，數字改由 course_stats 承接，總數不變。
  // 留言與檢舉紀錄一併刪除，不封存。
  const results = await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO course_stats (course_name, teacher, department, year, term, c1, c2, c3, c4, req, ele)
       SELECT course_name, teacher, department, year, term,
              SUM(level = 1), SUM(level = 2), SUM(level = 3), SUM(level = 4),
              SUM(course_type = '必修'), SUM(course_type = '選修')
       FROM ratings
       WHERE updated_at < ?1
       GROUP BY course_name, teacher, department, year, term
       ON CONFLICT (course_name, teacher, department, year, term) DO UPDATE SET
         c1 = c1 + excluded.c1, c2 = c2 + excluded.c2,
         c3 = c3 + excluded.c3, c4 = c4 + excluded.c4,
         req = req + excluded.req, ele = ele + excluded.ele`,
    ).bind(cutoff),
    env.DB.prepare(
      "DELETE FROM comment_reports WHERE rating_id IN (SELECT id FROM ratings WHERE updated_at < ?1)",
    ).bind(cutoff),
    env.DB.prepare("DELETE FROM ratings WHERE updated_at < ?1").bind(cutoff),
  ]);

  return results[2].meta.changes ?? 0;
}

// ---------- 進入點 ----------

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    const route = `${req.method} ${url.pathname}`;

    switch (route) {
      case "POST /v1/ratings":         return handleRating(req, env);
      case "POST /v1/stats":           return handleStats(req, env);
      case "GET /v1/departments":      return handleDepartments(env);
      case "GET /v1/browse":           return handleBrowse(url, env);
      case "GET /v1/comments":         return handleComments(url, env);
      case "POST /v1/comments/report": return handleReport(req, env);
      case "GET /health":              return json({ ok: true });
      default:                         return json({ error: "not found" }, 404);
    }
  },

  async scheduled(_controller: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
    ctx.waitUntil(
      purgeOldRatings(env).then((n) => console.log(`purged ${n} ratings older than ${RETENTION_DAYS} days`)),
    );
  },
} satisfies ExportedHandler<Env>;
