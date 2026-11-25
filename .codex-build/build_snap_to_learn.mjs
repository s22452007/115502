import fs from "node:fs/promises";
import path from "node:path";
import { Presentation, PresentationFile } from "@oai/artifact-tool";

const workspaceDir = "C:/Users/billp/Desktop/my_project/115502";
const buildDir = path.join(workspaceDir, ".codex-build");
const outputDir = path.join(workspaceDir, "output");
const finalPptx = path.join(outputDir, "Snap_to_Learn_系統介紹.pptx");
const W = 1280;
const H = 720;
const FONT = "Microsoft JhengHei";
const C = {
  green: "#0F5B3A",
  green2: "#4F9A54",
  mint: "#E9F2EC",
  pale: "#F5F7F5",
  navy: "#18324A",
  ink: "#223142",
  gray: "#6B7785",
  gold: "#F0C94D",
  coral: "#EE765B",
  white: "#FFFFFF",
};

async function readBytes(filePath) {
  const b = await fs.readFile(filePath);
  return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength);
}

function textbox(slide, text, left, top, width, height, style = {}) {
  const s = slide.shapes.add({
    geometry: "textbox",
    position: { left, top, width, height },
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  s.text = text;
  s.text.style = {
    fontFamily: FONT,
    fontSize: "18pt",
    color: C.ink,
    ...style,
  };
  if (style.alignment) s.text.alignment = style.alignment;
  if (style.verticalAlignment) s.text.verticalAlignment = style.verticalAlignment;
  return s;
}

function box(slide, left, top, width, height, fill, radius = "rounded-xl", lineFill = "none") {
  return slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width, height },
    fill,
    line: { style: "solid", fill: lineFill, width: lineFill === "none" ? 0 : 1 },
    borderRadius: radius,
  });
}

async function image(slide, filePath, left, top, width, height, fit = "contain") {
  return slide.images.add({
    blob: await readBytes(filePath),
    contentType: filePath.toLowerCase().endsWith(".png") ? "image/png" : "image/jpeg",
    alt: path.basename(filePath),
    fit,
    position: { left, top, width, height },
    geometry: "roundRect",
    borderRadius: "rounded-xl",
  });
}

function header(slide, kicker, title, page, dark = false) {
  const titleColor = dark ? C.white : C.navy;
  const kickerColor = dark ? C.gold : C.green2;
  textbox(slide, kicker.toUpperCase(), 72, 44, 420, 30, { fontSize: "12pt", bold: true, color: kickerColor });
  textbox(slide, title, 72, 76, 1000, 64, { fontSize: "30pt", bold: true, color: titleColor });
  textbox(slide, String(page).padStart(2, "0"), 1160, 52, 48, 30, { fontSize: "14pt", bold: true, color: dark ? C.white : C.gray, alignment: "right" });
}

function footer(slide, text, dark = false) {
  textbox(slide, text, 72, 672, 800, 24, { fontSize: "10pt", color: dark ? "#DDE8E0" : C.gray });
}

function rule(slide, left, top, width, color) {
  slide.shapes.add({ geometry: "rect", position: { left, top, width, height: 5 }, fill: color, line: { style: "solid", fill: color, width: 0 } });
}

const asset = (...parts) => path.join(workspaceDir, ...parts);
const logo = asset("115502-Snap_to_Learn-logo.png");
const photoResult = asset("系統文件", "第12章", "系統畫面截圖", "APP", "拍照學習", "3-辨識結果.png");
const dialogue = asset("系統文件", "第12章", "系統畫面截圖", "APP", "AI 情境對話", "2-AI 情境對話 對話.png");
const sentence = asset("系統文件", "第12章", "系統畫面截圖", "APP", "拍照學習", "4-練習造句 判斷結果.png");
const reading = asset("系統文件", "第12章", "系統畫面截圖", "APP", "文章閱讀", "3-發音評估報告.png");
const profile = asset("系統文件", "第12章", "系統畫面截圖", "APP", "個人中心", "1-個人檔案.png");
const group = asset("系統文件", "第12章", "系統畫面截圖", "APP", "好友與學習小組", "7-小組主畫面.png");
const student = asset("系統文件", "第12章", "系統畫面截圖", "APP", "學生端介面", "學生首頁.png");
const teacher = asset("系統文件", "第12章", "系統畫面截圖", "網頁", "老師", "班級管理.png");
const architecture = asset("系統文件", "系統架構圖(含後台).png");

const p = Presentation.create({ slideSize: { width: W, height: H } });

// 1 Cover
{
  const s = p.slides.add();
  s.background.fill = C.pale;
  s.shapes.add({ geometry: "rect", position: { left: 0, top: 0, width: 18, height: H }, fill: C.green, line: { style: "solid", fill: C.green, width: 0 } });
  await image(s, logo, 850, 104, 260, 260, "contain");
  textbox(s, "AI 日語學習平台", 86, 94, 560, 34, { fontSize: "16pt", bold: true, color: C.green2 });
  textbox(s, "Snap to Learn", 82, 142, 720, 86, { fontSize: "46pt", bold: true, color: C.navy });
  rule(s, 86, 246, 160, C.gold);
  textbox(s, "看到什麼，就學會什麼", 86, 278, 700, 72, { fontSize: "30pt", bold: true, color: C.green });
  textbox(s, "把生活變教材，把練習變成果。", 86, 374, 650, 46, { fontSize: "20pt", color: C.gray });
  textbox(s, "第 115502 組｜系統介紹", 86, 590, 520, 30, { fontSize: "14pt", color: C.gray });
  textbox(s, "拍照學習　AI 對話　即時批改　校園教學", 86, 630, 850, 28, { fontSize: "13pt", bold: true, color: C.green2 });
  s.speakerNotes.text = "各位老師、評審大家好。我們是第115502組，今天介紹 Snap to Learn，一個能讓使用者看到什麼就學會什麼的 AI 日語學習平台。";
}

// 2 Problem
{
  const s = p.slides.add();
  s.background.fill = C.green;
  header(s, "01｜問題", "學日文，卡在三件事", 2, true);
  textbox(s, "教材離生活太遠", 104, 190, 300, 54, { fontSize: "24pt", bold: true, color: C.white });
  textbox(s, "單字背了，卻不會用", 492, 190, 320, 54, { fontSize: "24pt", bold: true, color: C.white });
  textbox(s, "想練習，卻沒人糾正", 880, 190, 310, 54, { fontSize: "24pt", bold: true, color: C.white });
  for (const [x, n, t] of [[96, "01", "學習內容和日常脫節"], [484, "02", "知道意思，不敢開口"], [872, "03", "錯了，也不知道為什麼"]]) {
    textbox(s, n, x, 278, 100, 90, { fontSize: "54pt", bold: true, color: C.gold });
    rule(s, x, 378, 260, "#7BB883");
    textbox(s, t, x, 408, 300, 52, { fontSize: "18pt", color: "#E3F0E5" });
  }
  box(s, 84, 528, 1112, 84, "#174F36");
  textbox(s, "Snap to Learn 直接把三個痛點，變成三個學習入口。", 116, 551, 1060, 42, { fontSize: "21pt", bold: true, color: C.white, alignment: "center" });
  footer(s, "痛點很清楚，解法也要更直接。", true);
  s.speakerNotes.text = "現在學日文最大的問題不是沒有教材，而是教材離生活太遠；不是沒有單字，而是學會了卻不敢開口；不是沒有練習，而是沒有人可以隨時糾正你。Snap to Learn 直接解決這三個問題。";
}

// 3 Product overview
{
  const s = p.slides.add();
  s.background.fill = C.pale;
  header(s, "02｜解法", "一個 App，完成整套學習循環", 3);
  textbox(s, "從生活出發，\n一路練到會。", 72, 174, 400, 150, { fontSize: "34pt", bold: true, color: C.navy });
  textbox(s, "拍照 → 練習 → 修正 → 持續", 78, 358, 520, 50, { fontSize: "21pt", bold: true, color: C.green });
  textbox(s, "每一個功能都在推動下一步學習。", 78, 425, 490, 44, { fontSize: "17pt", color: C.gray });
  await image(s, photoResult, 650, 150, 165, 450, "contain");
  await image(s, dialogue, 830, 150, 165, 450, "contain");
  await image(s, profile, 1010, 150, 165, 450, "contain");
  textbox(s, "拍照學單字", 654, 620, 160, 28, { fontSize: "12pt", bold: true, color: C.green2, alignment: "center" });
  textbox(s, "AI 開口對話", 834, 620, 160, 28, { fontSize: "12pt", bold: true, color: C.green2, alignment: "center" });
  textbox(s, "看見學習成果", 1014, 620, 160, 28, { fontSize: "12pt", bold: true, color: C.green2, alignment: "center" });
  s.speakerNotes.text = "Snap to Learn 的核心不是單一功能，而是一套完整的學習循環：拍照取得素材，透過 AI 練習，再用批改和評分修正，最後以任務和社群讓學習持續。";
}

// 4 Features 1-2
{
  const s = p.slides.add();
  s.background.fill = C.white;
  header(s, "03｜七大功能", "01–02｜拍照即學，AI 陪你開口", 4);
  box(s, 72, 172, 520, 430, C.pale);
  textbox(s, "01", 100, 198, 86, 60, { fontSize: "36pt", bold: true, color: C.coral });
  textbox(s, "拍照即學", 190, 210, 330, 46, { fontSize: "24pt", bold: true, color: C.navy });
  textbox(s, "一張照片，自動產生單字、假名、中文意思與分級例句。", 100, 276, 420, 76, { fontSize: "16pt", color: C.gray });
  await image(s, photoResult, 158, 362, 348, 218, "cover");
  box(s, 650, 172, 558, 430, C.mint);
  textbox(s, "02", 678, 198, 86, 60, { fontSize: "36pt", bold: true, color: C.green2 });
  textbox(s, "AI 情境對話", 770, 210, 360, 46, { fontSize: "24pt", bold: true, color: C.navy });
  textbox(s, "點餐、問路、購物，AI 即時回覆並糾正文法，還能自訂角色。", 678, 276, 450, 76, { fontSize: "16pt", color: C.gray });
  await image(s, dialogue, 762, 362, 330, 218, "cover");
  footer(s, "生活素材進來，真正的語言輸出跟著發生。", false);
  s.speakerNotes.text = "第一個功能是拍照即學。拍下物品或場景，AI 自動辨識並生成單字與例句。第二個功能是 AI 情境對話，讓使用者在點餐、問路、購物等情境中練習開口，AI 會即時提供文法建議。";
}

// 5 Features 3-4
{
  const s = p.slides.add();
  s.background.fill = C.pale;
  header(s, "04｜七大功能", "03–04｜寫得對，也說得準", 5);
  textbox(s, "背得出單字，不代表真的會用。", 72, 168, 700, 46, { fontSize: "22pt", bold: true, color: C.navy });
  box(s, 72, 252, 536, 340, C.white);
  textbox(s, "03｜AI 造句批改", 104, 280, 430, 38, { fontSize: "21pt", bold: true, color: C.green });
  textbox(s, "依程度出題，AI 幾秒內指出錯誤，提供修正句、翻譯與文法重點。", 104, 334, 410, 70, { fontSize: "16pt", color: C.gray });
  await image(s, sentence, 156, 430, 370, 132, "cover");
  box(s, 672, 252, 536, 340, C.white);
  textbox(s, "04｜閱讀與朗讀評分", 704, 280, 450, 38, { fontSize: "21pt", bold: true, color: C.green });
  textbox(s, "分級文章附假名、翻譯與解析，錄音後由 AI 分析發音表現。", 704, 334, 420, 70, { fontSize: "16pt", color: C.gray });
  await image(s, reading, 790, 420, 300, 152, "cover");
  footer(s, "使用者不用等老師，馬上知道自己哪裡需要修正。", false);
  s.speakerNotes.text = "第三個功能是 AI 造句批改。使用者造句後，系統會直接指出問題並提供修正。第四個功能是閱讀與朗讀評分，使用者可以閱讀分級文章並錄音，由 AI 分析發音，確認自己是真的會說。";
}

// 6 Personal learning center
{
  const s = p.slides.add();
  s.background.fill = C.white;
  header(s, "05｜七大功能", "個人學習中心｜看見自己的進步", 6);
  textbox(s, "五大能力，一張圖看懂。", 72, 170, 520, 56, { fontSize: "26pt", bold: true, color: C.navy });
  textbox(s, "聽　說　讀　寫　文化", 76, 250, 570, 58, { fontSize: "22pt", bold: true, color: C.green2 });
  rule(s, 76, 336, 460, C.gold);
  textbox(s, "升級測驗判定程度\n每日任務提供目標\n連續學習解鎖徽章\n完成任務獲得點數", 80, 380, 470, 170, { fontSize: "19pt", color: C.gray });
  await image(s, profile, 760, 132, 280, 540, "contain");
  box(s, 1020, 234, 188, 192, C.mint);
  textbox(s, "學習\n有紀錄", 1040, 272, 150, 96, { fontSize: "24pt", bold: true, color: C.green, alignment: "center" });
  textbox(s, "每天都有下一步", 1018, 464, 190, 36, { fontSize: "13pt", bold: true, color: C.green2, alignment: "center" });
  s.speakerNotes.text = "第五個功能是個人學習中心。系統會用升級測驗與學習紀錄，呈現聽、說、讀、寫、文化五大能力。再用每日任務、連續學習與成就徽章，讓使用者看見自己的進步並持續使用。";
}

// 7 Social
{
  const s = p.slides.add();
  s.background.fill = C.pale;
  header(s, "06｜七大功能", "好友與學習小組｜把自己學變成一起完成", 7);
  textbox(s, "一個人學，容易放棄。", 72, 176, 620, 56, { fontSize: "27pt", bold: true, color: C.navy });
  textbox(s, "找好友、組隊、訂目標、看排名。", 76, 254, 580, 48, { fontSize: "20pt", color: C.green });
  rule(s, 76, 330, 420, C.gold);
  textbox(s, "搜尋或掃描 QR Code 加好友\n學習小組共同設定目標\n押金制讓達標更有動力\n完成後取回押金並獲得點數", 78, 374, 500, 170, { fontSize: "18pt", color: C.gray });
  await image(s, group, 730, 140, 330, 540, "contain");
  box(s, 1078, 292, 130, 112, C.green);
  textbox(s, "一起\n完成", 1090, 315, 108, 72, { fontSize: "21pt", bold: true, color: C.white, alignment: "center" });
  footer(s, "讓學習多一點互相鼓勵，也多一點完成的理由。", false);
  s.speakerNotes.text = "第六個功能是好友與學習小組。使用者可以加好友、設定共同目標、互相排名。小組也能採用押金制度，達標者取回押金並獲得點數，讓學習從一個人的堅持，變成一群人的完成。";
}

// 8 Education
{
  const s = p.slides.add();
  s.background.fill = C.white;
  header(s, "07｜七大功能", "校園教育版｜同一套 App，直接進入課堂", 8);
  textbox(s, "學生端 + 老師後台，完整串起教學流程。", 72, 162, 850, 48, { fontSize: "22pt", bold: true, color: C.navy });
  box(s, 72, 258, 460, 314, C.mint);
  textbox(s, "學生端", 104, 290, 180, 40, { fontSize: "24pt", bold: true, color: C.green });
  textbox(s, "學校帳號登入\n加入班級\n查看與繳交作業\n收到公告與批改結果", 106, 360, 320, 170, { fontSize: "19pt", color: C.gray });
  await image(s, student, 540, 300, 286, 280, "cover");
  await image(s, teacher, 858, 300, 348, 280, "cover");
  textbox(s, "App", 608, 586, 150, 32, { fontSize: "13pt", bold: true, color: C.green2, alignment: "center" });
  textbox(s, "教師網頁後台", 948, 586, 170, 32, { fontSize: "13pt", bold: true, color: C.green2, alignment: "center" });
  footer(s, "對學生是學習工具，對老師是教學管理系統。", false);
  s.speakerNotes.text = "第七個功能是完整的校園教育版。學生可以使用學校帳號登入、加入班級、查看與繳交作業。老師則透過網頁後台建立教室、管理學生、派發與批改作業，並查看成績報表。";
}

// 9 System completeness
{
  const s = p.slides.add();
  s.background.fill = C.pale;
  header(s, "08｜完整系統", "不只是一個 App，而是一整套可運作的平台", 9);
  await image(s, architecture, 72, 166, 710, 448, "contain");
  box(s, 842, 182, 350, 156, C.green);
  textbox(s, "技術底座", 872, 210, 280, 34, { fontSize: "20pt", bold: true, color: C.gold });
  textbox(s, "Flutter｜Flask\nGemini AI｜Firebase\nMySQL｜Docker", 872, 258, 280, 66, { fontSize: "17pt", color: C.white });
  box(s, 842, 372, 350, 188, C.white);
  textbox(s, "安全設計", 872, 402, 280, 34, { fontSize: "20pt", bold: true, color: C.green });
  textbox(s, "照片上傳前自動遮蔽\n人臉、電話、地址、卡號等敏感資訊\n降低個人資料外洩風險", 872, 450, 286, 86, { fontSize: "16pt", color: C.gray });
  footer(s, "從手機端、後端服務到管理後台，全部自己完成。", false);
  s.speakerNotes.text = "除了功能之外，我們也完成完整的技術架構。前端使用 Flutter，後端採用 Flask，串接 Gemini AI、Firebase、MySQL 與 Docker。資料安全方面，照片上傳前會自動偵測並遮蔽敏感資訊。";
}

// 10 Closing
{
  const s = p.slides.add();
  s.background.fill = C.green;
  await image(s, logo, 90, 120, 190, 190, "contain");
  textbox(s, "Snap to Learn", 344, 128, 700, 70, { fontSize: "40pt", bold: true, color: C.white });
  textbox(s, "不是把課本搬到手機裡。", 346, 240, 650, 48, { fontSize: "23pt", bold: true, color: C.gold });
  textbox(s, "而是重新設計學習日文的方式。", 346, 300, 730, 48, { fontSize: "23pt", bold: true, color: C.white });
  rule(s, 346, 390, 180, C.gold);
  textbox(s, "拍照，學單字\n對話，練表達\n造句，馬上批改\n朗讀，立即評分\n組隊，持續完成\n進入校園，直接支援教學", 346, 430, 520, 170, { fontSize: "18pt", color: "#E3F0E5" });
  textbox(s, "讓每一個生活畫面，都成為你學會日文的下一步。", 878, 532, 320, 70, { fontSize: "17pt", bold: true, color: C.white, alignment: "right" });
  textbox(s, "謝謝大家", 940, 636, 250, 34, { fontSize: "16pt", bold: true, color: C.gold, alignment: "right" });
  s.speakerNotes.text = "Snap to Learn 不是把課本搬到手機裡，而是重新設計學習日文的方式。拍照學單字、對話練表達、造句馬上批改、朗讀立即評分、組隊持續完成，並且直接支援校園教學。讓每一個生活畫面，都成為學會日文的下一步。謝謝大家。";
}

await fs.mkdir(outputDir, { recursive: true });
for (const [i, slide] of p.slides.items.entries()) {
  const png = await p.export({ slide, format: "png", scale: 1 });
  await fs.writeFile(path.join(buildDir, `snap-slide-${String(i + 1).padStart(2, "0")}.png`), new Uint8Array(await png.arrayBuffer()));
}
const pptx = await PresentationFile.exportPptx(p);
await pptx.save(finalPptx);
console.log(finalPptx);
