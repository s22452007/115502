import fs from 'node:fs/promises';
import path from 'node:path';
import { Presentation, PresentationFile } from '@oai/artifact-tool';

const W=1280,H=720;
const C={bg:'#F5F7F2',dark:'#164B36',ink:'#26332D',muted:'#6D7E74',mint:'#DCEBDF',cream:'#FFF8E8',orange:'#F4B740',coral:'#E57463',white:'#FFFFFF',line:'#D3DED5',gray:'#9BAEB2',olive:'#7C9560'};
const font='Aptos';
const root='C:/Users/billp/Desktop/my_project/115502';
const source=path.join(root,'output','Snap_to_Learn_人無我有_簡報.pptx');
const build=path.join(root,'.codex-build');
function t(s,text,x,y,w,h,size,color=C.ink,bold=false,align='left') { const q=s.shapes.add({geometry:'textbox',position:{left:x,top:y,width:w,height:h},fill:'none',line:{style:'solid',fill:'none',width:0}}); q.text=text; q.text.style={fontSize:size,color,bold,alignment:align,fontFamily:font}; return q; }
function rect(s,x,y,w,h,fill,r='rounded-xl',lineFill='none',lw=0){const c={geometry:r==='square'?'rect':'roundRect',position:{left:x,top:y,width:w,height:h},fill,line:{style:'solid',fill:lineFill,width:lw}};if(r!=='square')c.borderRadius=r;return s.shapes.add(c);}
function rule(s,x,y,w,color=C.line,h=2){rect(s,x,y,w,h,color,'square');}
function base(s,title,kicker,num){s.background.fill=C.bg;t(s,kicker.toUpperCase(),72,38,400,22,13,C.dark,true);t(s,title,72,70,1080,64,32,C.ink,true);rule(s,72,144,1136,C.line,2);t(s,String(num).padStart(2,'0'),1175,42,40,20,12,C.muted,true,'right');}
function table(s,{x,y,w,h,values,headerFill=C.gray,headerColor=C.white,bodyFill=C.bg,bodyColor=C.ink,fontSize=17,firstColFill=null}) { const rows=values.length, cols=values[0].length; const tb=s.tables.add({rows,columns:cols,left:x,top:y,width:w,height:h,values}); tb.borders.assign({style:'solid',fill:'#8F8062',width:1}); for(let c=0;c<cols;c++){tb.getCell(0,c).fill=headerFill;tb.getCell(0,c).text.style={fontSize:fontSize+2,bold:true,color:headerColor,fontFamily:font,alignment:'center'};} for(let r=1;r<rows;r++){for(let c=0;c<cols;c++){const cell=tb.getCell(r,c);cell.fill=bodyFill;cell.text.style={fontSize,bold:c===0,color:bodyColor,fontFamily:font,alignment:'center'}; if(firstColFill&&c===0)cell.fill=firstColFill;}} return tb; }
async function main(){
 const p=await PresentationFile.importPptx(await (await import('@oai/artifact-tool')).FileBlob.load(source));
 // Section divider
 {const s=p.slides.add(); s.background.fill=C.cream; rect(s,0,0,300,H,C.dark,'square'); rect(s,980,0,300,H,C.mint,'square'); t(s,'A2｜',72,66,300,54,42,C.cream,true); t(s,'成本與方案設計',366,226,760,64,40,C.dark,true); t(s,'讓免費體驗降低門檻，讓 Premium 支撐 AI 服務成本',366,310,720,40,20,C.ink,false); rule(s,366,392,620,C.orange,4); t(s,'方案額度　　訂閱價格　　AI 單次成本　　規模化試算',366,430,760,28,17,C.muted,true); t(s,'Snap to Learn｜A2',1040,650,170,22,12,C.muted,true,'right'); }
 // free premium usage
 {const s=p.slides.add();base(s,'免費體驗與 Premium：額度差異創造升級理由','A2｜方案額度',11);t(s,'Free 讓使用者先感受到價值，Premium 把高頻使用留給願意持續學習的人。',72,172,920,36,21,C.ink);table(s,{x:72,y:250,w:1136,h:320,values:[['方案','Free','Premium'],['造句／次','3 次','5 次'],['朗讀／次','1 次','5 次'],['AI 對話／次','3 次','10 次'],['拍照／次','2 次','10 次'],['Total Time','約 20 分鐘','最少約 1 小時']],headerFill:C.gray,bodyFill:C.cream,fontSize:18});t(s,'單位：每次使用額度所能支援的學習時間',72,612,500,24,14,C.muted); }
 // subscription plans
 {const s=p.slides.add();base(s,'訂閱方案：價格與每日使用額度','A2｜訂閱設計',12);t(s,'把「每日可用量」說清楚，使用者才能理解月訂閱與年訂閱的差別。',72,172,900,36,21,C.ink);table(s,{x:72,y:250,w:1136,h:350,values:[['方案','免費版','月訂閱','年訂閱'],['費用','免費','NT$149／月','NT$1,290／年'],['贈點','無','20 點','300 點'],['拍照／天','2','10','10'],['AI 對話／天','3','10','10'],['文章朗讀','1','5','5'],['造句挑戰','3','5','5'],['小組免費／週','1','3','3']],headerFill:C.gray,bodyFill:C.cream,fontSize:16});t(s,'設計重點：免費版保留完整核心流程，付費版提高使用頻率並提供點數。',72,630,900,24,15,C.dark,true); }
 // unit cost
 {const s=p.slides.add();base(s,'AI 單次成本：先看模型，再看規模','A2｜成本結構',13);t(s,'附件以 GPT-4.0 與 GPT-4.0 mini 做單次成本比較，這裡保留原始數據作為估算基準。',72,172,1000,36,20,C.ink);table(s,{x:72,y:236,w:1136,h:220,values:[['每日花費／人','gpt 4.0','gpt 4.0 (mini)'],['造句／次','0.15','0.005'],['閱讀朗讀／次','0.28','0.1'],['AI 對話／次','0.72','0.030'],['拍照／次','0.5','0.015']],headerFill:C.gray,bodyFill:C.cream,fontSize:17});table(s,{x:72,y:466,w:540,h:150,values:[['方案／100 人','Free'],['造句／3 次','1.5'],['朗讀／1 次','10'],['AI 對話／3 次','9'],['拍照／2 次','3'],['Total','23.5']],headerFill:C.gray,bodyFill:C.cream,fontSize:16});table(s,{x:668,y:466,w:540,h:150,values:[['方案／100 人','Premium'],['造句／5 次','2.5'],['朗讀／5 次','50'],['AI 對話／10 次','30'],['拍照／10 次','15'],['Total','97.5']],headerFill:C.olive,bodyFill:C.cream,fontSize:16});t(s,'單位：台幣；以上以 gpt 4.0 mini 為例',72,650,500,20,13,C.muted); }
 // takeaways
 {const s=p.slides.add();base(s,'成本結論：Premium 是服務品質的支撐','A2｜商業判斷',14);t(s,'方案設計同時回答兩個問題：使用者為什麼付費？團隊如何負擔 AI 成本？',72,172,970,36,21,C.ink);rect(s,72,250,340,220,C.white,'rounded-2xl',C.line,1);t(s,'使用者端',104,282,260,28,18,C.dark,true);t(s,'免費版先體驗\nPremium 提高頻率\n點數對應使用量',104,332,260,96,23,C.ink,true);rect(s,470,250,340,220,C.dark,'rounded-2xl');t(s,'產品端',502,282,260,28,18,C.orange,true);t(s,'核心功能不切斷\n高成本功能設上限\n用訂閱支撐持續使用',502,332,260,96,23,C.cream,true);rect(s,868,250,340,220,C.cream,'rounded-2xl');t(s,'財務端',900,282,260,28,18,C.dark,true);t(s,'mini 模型降低單次成本\n以 100 人試算容量\n再用 Beta 數據校正',900,332,260,96,23,C.ink,true);rule(s,72,540,1136,C.line,2);t(s,'建議下一步',72,580,140,26,16,C.dark,true);t(s,'以實際使用紀錄驗證：每人每日平均請求量、Premium 轉換率、AI 成本／活躍用戶。',236,576,900,30,18,C.ink,false); }
 const out=path.join(build,'candidate_section.pptx'); const pptx=await PresentationFile.exportPptx(p); await pptx.save(out); for(const [i,s] of p.slides.items.entries()){const png=await p.export({slide:s,format:'png',scale:1});await fs.writeFile(path.join(build,`section-slide-${String(i+1).padStart(2,'0')}.png`),new Uint8Array(await png.arrayBuffer()));}
}
main().catch(e=>{console.error(e);process.exitCode=1;});
