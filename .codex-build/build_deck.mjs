import fs from 'node:fs/promises';
import path from 'node:path';
import { Presentation, PresentationFile } from '@oai/artifact-tool';

const W = 1280, H = 720;
const C = {
  bg: '#F5F7F2',
  dark: '#164B36',
  ink: '#26332D',
  muted: '#6D7E74',
  mint: '#DCEBDF',
  mint2: '#EAF2EA',
  cream: '#FFF8E8',
  orange: '#F4B740',
  coral: '#E57463',
  white: '#FFFFFF',
  line: '#D3DED5',
};
const font = 'Microsoft JhengHei';
const root = 'C:/Users/billp/Desktop/my_project/115502';
const build = path.join(root, '.codex-build');
const output = path.join(root, 'output');

async function imgBytes(p) {
  const b = await fs.readFile(p);
  return b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength);
}

function addText(slide, text, x, y, w, h, size, color=C.ink, bold=false, align='left') {
  const s = slide.shapes.add({
    geometry: 'textbox',
    position: { left: x, top: y, width: w, height: h },
    fill: 'none',
    line: { style: 'solid', fill: 'none', width: 0 },
  });
  s.text = text;
  s.text.style = { fontSize: size, color, bold, alignment: align, fontFamily: font };
  return s;
}

function addRect(slide, x, y, w, h, fill, radius='rounded-xl', lineFill='none', lineWidth=0) {
  const cfg = {
    geometry: radius === 'square' ? 'rect' : 'roundRect',
    position: { left: x, top: y, width: w, height: h },
    fill,
    line: { style: 'solid', fill: lineFill, width: lineWidth },
  };
  if (radius !== 'square') cfg.borderRadius = radius;
  return slide.shapes.add(cfg);
}

function addRule(slide, x, y, w, color=C.line, h=2) { addRect(slide, x, y, w, h, color, 'square'); }

async function addImage(slide, p, x, y, w, h, fit='contain', radius='rounded-xl') {
  const ext = path.extname(p).toLowerCase();
  const contentType = ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : 'image/png';
  return slide.images.add({ blob: await imgBytes(p), contentType, alt: path.basename(p), fit, position: { left:x, top:y, width:w, height:h }, geometry:'roundRect', borderRadius: radius });
}

function slideBase(p, title, kicker, num) {
  p.background.fill = C.bg;
  if (kicker) addText(p, kicker.toUpperCase(), 72, 38, 420, 22, 13, C.dark, true);
  if (title) addText(p, title, 72, 70, 1080, 64, 32, C.ink, true);
  addRule(p, 72, 144, 1136, C.line, 2);
  addText(p, String(num).padStart(2,'0'), 1175, 42, 40, 20, 12, C.muted, true, 'right');
}

async function main() {
  await fs.mkdir(build, { recursive:true });
  await fs.mkdir(output, { recursive:true });
  const p = Presentation.create({ slideSize: { width: W, height: H } });

  // 1 cover
  {
    const s = p.slides.add(); s.background.fill = C.mint;
    addRect(s, 0, 0, 300, H, C.dark, 'square');
    addRect(s, 980, 0, 300, H, C.cream, 'square');
    addText(s, '115502 專題成果', 72, 58, 340, 24, 15, C.cream, true);
    addText(s, 'Snap to Learn', 360, 224, 520, 92, 64, C.dark, true);
    addText(s, '生活場景 × AI 對話的日文學習 App', 366, 330, 600, 42, 25, C.ink, false);
    addText(s, '把今天遇到的事物，變成明天說得出口的日文', 366, 392, 720, 32, 18, C.muted, false);
    await addImage(s, path.join(root, '115502-Snap_to_Learn-logo.png'), 828, 154, 320, 320, 'contain', 'rounded-2xl');
    addRule(s, 366, 502, 640, C.dark, 3);
    addText(s, '彭靖奕　丁泳瑄　蘇品璇　廖唯岑　施品妤', 366, 528, 700, 26, 16, C.ink, true);
    addText(s, '指導老師：林宥志', 366, 566, 360, 24, 15, C.muted, false);
  }

  // 2 problem
  {
    const s = p.slides.add(); slideBase(s, '學習者卡在「看得懂，說不出口」', '01｜問題', 2);
    addText(s, '傳統單字學習把內容放在教材裡，卻很少放進生活裡。', 72, 172, 650, 38, 21, C.ink, false);
    addRect(s, 72, 250, 520, 330, C.white, 'rounded-2xl', C.line, 1);
    addText(s, '四個流失學習動力的瞬間', 104, 280, 420, 28, 18, C.dark, true);
    const pain = [
      ['枯燥', '只背單字，記憶沒有畫面'],
      ['缺情境', '學過的句型，遇到現場不會用'],
      ['缺回饋', '不知道自己有沒有真的進步'],
      ['缺互動', '想開口，卻找不到不怕犯錯的對象'],
    ];
    pain.forEach((d,i)=>{
      const yy = 330 + i*56;
      addRect(s, 104, yy, 84, 30, i===3?C.coral:C.mint, 'rounded-lg');
      addText(s, d[0], 104, yy+4, 84, 22, 15, i===3?C.white:C.dark, true, 'center');
      addText(s, d[1], 208, yy+2, 330, 28, 16, C.ink, false);
    });
    await addImage(s, path.join(root, '系統文件','第12章','系統畫面截圖','APP','拍照學習','1-拍照辨識.png'), 690, 214, 240, 360, 'contain', 'rounded-2xl');
    addRect(s, 962, 298, 234, 142, C.dark, 'rounded-2xl');
    addText(s, '學習素材\n就在眼前', 990, 326, 180, 70, 24, C.cream, true);
    addText(s, '從「背」轉成「遇到就學」', 962, 464, 250, 30, 16, C.dark, true);
  }

  // 3 differentiation
  {
    const s = p.slides.add(); slideBase(s, '人無我有：從生活照片長出一套課程', '02｜差異化', 3);
    addText(s, 'Snap to Learn 的核心不是多一個題庫，而是把每一次拍照都變成個人化教材。', 72, 172, 900, 38, 21, C.ink, false);
    const xs = [72, 428, 784];
    const titles = ['生活取材', 'AI 轉譯', '練習留下來'];
    const subs = ['拍下菜單、指示牌或身邊物品', '產生單字、例句與程度對應內容', '收藏、造句、對話，形成個人學習軌跡'];
    const nums = ['01','02','03'];
    xs.forEach((x,i)=>{
      addText(s, nums[i], x, 258, 72, 54, 38, i===1?C.orange:C.dark, true);
      addRule(s, x, 326, 280, i===1?C.orange:C.dark, 4);
      addText(s, titles[i], x, 352, 280, 36, 24, C.ink, true);
      addText(s, subs[i], x, 404, 270, 72, 17, C.muted, false);
    });
    addRect(s, 72, 540, 1136, 90, C.dark, 'rounded-2xl');
    addText(s, '市場缺口', 102, 566, 120, 26, 16, C.orange, true);
    addText(s, '單字 App 的輸入效率　　Snap to Learn：情境 × 對話　　真人家教的高成本', 236, 561, 900, 34, 20, C.cream, true);
  }

  // 4 photo workflow
  {
    const s = p.slides.add(); slideBase(s, '一張照片，變成可複習、可造句的學習素材', '03｜產品流程', 4);
    addText(s, '從相機入口開始，讓學習內容跟著使用者的生活走。', 72, 172, 720, 34, 21, C.ink, false);
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','拍照學習','3-辨識結果.png'), 72, 242, 250, 360, 'contain', 'rounded-2xl');
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','單字圖鑑與收藏','6-單字詳情.png'), 392, 242, 250, 360, 'contain', 'rounded-2xl');
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','拍照學習','4-練習造句.png'), 712, 242, 250, 360, 'contain', 'rounded-2xl');
    const steps=[['拍照','辨識場景中的日文物件'],['理解','產生詞義、例句與分級內容'],['輸出','用自己的句子重新使用']];
    steps.forEach((d,i)=>{ const x=72+i*320; addText(s, `${i+1}  ${d[0]}`, x, 620, 240, 24, 16, C.dark, true); addText(s, d[1], x, 646, 270, 24, 14, C.muted, false); });
  }

  // 5 AI roleplay
  {
    const s = p.slides.add(); slideBase(s, '把「不敢說」變成可重來的對話練習', '04｜AI 互動', 5);
    addText(s, '使用者可以建立角色與情境，練習旅遊、生存或興趣交流，不必先找到真人老師。', 72, 172, 760, 40, 21, C.ink, false);
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','AI 情境對話','1-建立對話角色.png'), 72, 246, 270, 360, 'contain', 'rounded-2xl');
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','AI 情境對話','2-AI 情境對話 對話.png'), 392, 246, 270, 360, 'contain', 'rounded-2xl');
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','AI 情境對話','3-AI 對話紀錄.png'), 712, 246, 270, 360, 'contain', 'rounded-2xl');
    addRect(s, 1014, 250, 190, 330, C.cream, 'rounded-2xl');
    addText(s, '角色\n×\n情境\n×\n語氣', 1044, 296, 130, 160, 27, C.dark, true, 'center');
    addRule(s, 1048, 490, 124, C.orange, 4);
    addText(s, '可重來的\n低壓輸出環境', 1030, 518, 160, 48, 16, C.ink, true, 'center');
  }

  // 6 retention / school
  {
    const s = p.slides.add(); slideBase(s, '學習不是一次性體驗', '05｜留存與延伸', 6);
    addText(s, '個人化的累積，加上小組互動，讓學習從「今天用過」變成「明天還會回來」。', 72, 172, 820, 38, 21, C.ink, false);
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','個人中心','2-成就徽章.png'), 72, 248, 300, 330, 'contain', 'rounded-2xl');
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','APP','好友與學習小組','7-小組主畫面.png'), 444, 248, 300, 330, 'contain', 'rounded-2xl');
    await addImage(s, path.join(root,'系統文件','第12章','系統畫面截圖','網頁','老師','班級管理.png'), 816, 248, 360, 250, 'contain', 'rounded-2xl');
    addText(s, '個人進步可視化', 92, 600, 260, 26, 17, C.dark, true);
    addText(s, '好友與學習小組', 466, 600, 260, 26, 17, C.dark, true);
    addText(s, '校園教育版延伸', 836, 526, 260, 26, 17, C.dark, true);
    addText(s, '徽章、能力值、每日目標', 92, 628, 260, 24, 14, C.muted, false);
    addText(s, '一起挑戰、互相鼓勵', 466, 628, 260, 24, 14, C.muted, false);
    addText(s, '教師可建立班級與作業', 836, 554, 260, 24, 14, C.muted, false);
  }

  // 7 architecture
  {
    const s = p.slides.add(); slideBase(s, '技術架構：Flutter × Flask × Gemini', '06｜落地能力', 7);
    addText(s, '跨平台前端承接使用體驗，後端與雲端服務支撐帳號、資料與 AI 功能。', 72, 172, 860, 36, 21, C.ink, false);
    await addImage(s, path.join(root,'系統文件','系統架構圖(新).png'), 72, 236, 690, 410, 'contain', 'rounded-2xl');
    addRect(s, 816, 236, 392, 410, C.white, 'rounded-2xl', C.line, 1);
    addText(s, '可持續擴充的技術底座', 850, 270, 320, 30, 20, C.dark, true);
    const tech=[['前端','Flutter、Android / Web'],['後端','Python、Flask API Server'],['資料','SQLite、Firebase Auth'],['AI','Gemini、場景辨識與對話'],['流程','GitHub、單元與整合測試']];
    tech.forEach((d,i)=>{ const yy=330+i*52; addText(s, d[0], 850, yy, 90, 24, 15, C.orange, true); addText(s, d[1], 950, yy, 220, 24, 15, C.ink, false); });
  }

  // 8 market position
  {
    const s = p.slides.add(); slideBase(s, '市場位置：填補單字 App 與真人家教之間', '07｜市場', 8);
    addText(s, '先服務最需要「低壓輸出」的使用者，再用 Freemium 模式降低第一次使用的門檻。', 72, 172, 930, 38, 21, C.ink, false);
    addRect(s, 72, 250, 300, 130, C.white, 'rounded-2xl', C.line, 1);
    addText(s, '單字／文法 App', 100, 280, 244, 30, 22, C.muted, true, 'center');
    addText(s, '輸入效率高\n情境輸出較少', 100, 326, 244, 46, 16, C.muted, false, 'center');
    addRect(s, 490, 228, 300, 174, C.dark, 'rounded-2xl');
    addText(s, 'Snap to Learn', 520, 258, 240, 34, 25, C.cream, true, 'center');
    addText(s, '生活取材 × AI 會話\n低門檻、零壓力、可持續', 520, 310, 240, 60, 18, C.cream, false, 'center');
    addRect(s, 908, 250, 300, 130, C.white, 'rounded-2xl', C.line, 1);
    addText(s, '真人線上家教', 936, 280, 244, 30, 22, C.muted, true, 'center');
    addText(s, '互動品質高\n時間與費用門檻高', 936, 326, 244, 46, 16, C.muted, false, 'center');
    addRule(s, 72, 456, 1136, C.line, 2);
    addText(s, '優先客群', 72, 494, 120, 26, 16, C.dark, true);
    addText(s, 'N5～N4 基礎學習者、赴日自由行旅客、日本流行文化愛好者', 214, 490, 880, 30, 19, C.ink, true);
    addText(s, '商業路徑', 72, 556, 120, 26, 16, C.dark, true);
    addText(s, '免費體驗、主題包解鎖、Premium 訂閱與進階學習數據', 214, 552, 880, 30, 19, C.ink, false);
  }

  // 9 close
  {
    const s = p.slides.add(); s.background.fill = C.dark;
    addText(s, 'Snap to Learn', 72, 66, 500, 50, 34, C.cream, true);
    addText(s, '從今天拍到的每一個場景，累積成能說出口的日文。', 72, 168, 940, 74, 38, C.cream, true);
    addRule(s, 72, 292, 760, C.orange, 4);
    const items=[['01','生活即教材'],['02','AI 會話陪練'],['03','社群留住習慣']];
    items.forEach((d,i)=>{ const x=72+i*350; addText(s, d[0], x, 360, 72, 40, 30, C.orange, true); addText(s, d[1], x, 420, 280, 40, 24, C.cream, true); });
    addText(s, '下一步：以 Beta 測試持續校正辨識、語料與對話體驗', 72, 584, 800, 28, 17, '#C9D9CD', false);
    addText(s, '115502｜Snap to Learn', 1050, 650, 160, 22, 12, '#C9D9CD', true, 'right');
  }

  for (const [i, slide] of p.slides.items.entries()) {
    const png = await p.export({ slide, format:'png', scale:1 });
    await fs.writeFile(path.join(build, `slide-${String(i+1).padStart(2,'0')}.png`), new Uint8Array(await png.arrayBuffer()));
  }
  const pptx = await PresentationFile.exportPptx(p);
  await pptx.save(path.join(build, 'candidate.pptx'));
}

main().catch(err=>{ console.error(err); process.exitCode=1; });

