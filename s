<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Anki CSV Builder (JP-EN) — Mobile & Desktop</title>
<style>
  :root { --pad: 16px; }
  body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, "Noto Sans", Arial, sans-serif; margin: var(--pad); }
  h1 { font-size: 22px; margin: 0 0 8px; }
  .hint { color:#555; font-size:14px; margin-bottom: 12px; }
  .row { display:flex; gap:10px; align-items:center; flex-wrap:wrap; margin: 8px 0; }
  .btn { padding:12px 16px; border:1px solid #ccc; border-radius:10px; background:#f4f4f6; cursor:pointer; font-size:16px; }
  .btn.primary { background:#0b5fff; border-color:#0b5fff; color:#fff; }
  .btn:active { transform: translateY(1px); }
  textarea { width:100%; height:50vh; padding:12px; font-family: ui-monospace, Menlo, Consolas, monospace; font-size:15px; line-height:1.5; border:1px solid #ddd; border-radius:10px; }
  label { font-size:15px; }
  .status { margin-top:8px; font-size:14px; color:#444; }
  table { width:100%; border-collapse: collapse; margin-top:10px; font-size:14px; }
  th, td { border:1px solid #eee; padding:8px; vertical-align: top; }
  th { background:#fafafa; text-align:left; }
  @media (min-width: 900px){
    textarea{ height: 45vh; }
  }
</style>
</head>
<body>
  <h1>Anki CSV Builder (JP-EN)</h1>
  <div class="hint">
    Xuất CSV **5 cột, không header** theo thứ tự Note Type của bạn: <code>Sentence | Translation | Target Word | (trống) | Screenshot</code>.<br>
    Dán dữ liệu → Preview → Tải CSV → Import trong Anki và map 5 cột theo thứ tự trên.
  </div>

  <div class="row">
    <button class="btn" id="btnExample">Dán ví dụ</button>
    <button class="btn primary" id="btnDownload">Tải CSV</button>
    <label><input type="checkbox" id="chkDedup" checked> Loại trùng theo Sentence</label>
  </div>

  <textarea id="input" placeholder="[日本語文]
すみません、この料理はもう少し辛くできますか？
[英語文]
Excuse me, can you make this dish a bit spicier?
📌 キーフレーズ: [Excuse me]::すみません,[a bit spicier]::もう少し辛く
🖼 画像キーワード: restaurant waiter spicy dish"></textarea>

  <div class="row">
    <button class="btn" id="btnPreview">Preview</button>
    <span class="status" id="status">Số thẻ hợp lệ: 0</span>
  </div>

  <div id="preview"></div>

<script>
function normalize(text){ return (text||"").trim().replace(/\r\n/g,"\n").replace(/\r/g,"\n"); }

function parseBlocks(text){
  const t = normalize(text);
  if(!t) return [];
  const parts = t.split(/\n(?=\[日本語文\])/);
  const rows = [];
  for(const part of parts){
    const mJP  = part.match(/\[日本語文\]\s*(.+)/);
    const mEN  = part.match(/\[英語文\]\s*(.+)/);
    const mKEY = part.match(/📌\s*キーフレーズ:\s*(.+)/);
    const mIMG = part.match(/🖼\s*画像キーワード:\s*(.+)/);
    const jp  = mJP  ? mJP[1].trim()  : "";
    const en  = mEN  ? mEN[1].trim()  : "";
    const key = mKEY ? mKEY[1].trim() : "";
    const img = mIMG ? mIMG[1].trim() : "";
    if(jp && en){
      // 5 cột theo Note Type: 1)Sentence 2)Translation 3)Target Word 4)(trống) 5)Screenshot
      rows.push([jp, en, key, "", img]);
    }
  }
  return rows;
}

function toCSVNoHeader(rows){
  // CSV không header; quote tự động khi có dấu phẩy/xuống dòng/ngoặc kép
  const escape = (v) => {
    const s = String(v ?? "");
    const need = /[",\n]/.test(s);
    const e = s.replace(/"/g, '""');
    return need ? `"${e}"` : e;
  };
  return rows.map(r => r.map(escape).join(",")).join("\n");
}

function setStatus(msg){ document.getElementById("status").textContent = msg; }

function renderPreview(rows){
  const el = document.getElementById("preview");
  if(rows.length===0){ el.innerHTML=""; return; }
  const head = `<tr><th>Sentence</th><th>Translation</th><th>Target Word</th><th>(empty)</th><th>Screenshot</th></tr>`;
  const body = rows.slice(0,10).map(r=>`<tr>${r.map(c=>`<td>${c?c.replace(/&/g,"&amp;").replace(/</g,"&lt;"):""}</td>`).join("")}</tr>`).join("");
  el.innerHTML = `<table>${head}${body}</table><div class="status">Hiển thị tối đa 10 dòng xem trước • Tổng: ${rows.length}</div>`;
}

function downloadCSV(filename, csvText){
  // UTF-8 BOM để Excel/Anki hiểu Unicode
  const blob = new Blob(["\uFEFF"+csvText], {type:"text/csv;charset=utf-8;"});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename;
  document.body.appendChild(a);
  a.click();
  setTimeout(()=>{ document.body.removeChild(a); URL.revokeObjectURL(url); }, 0);
}

const EXAMPLE = `[日本語文]
すみません、この料理はもう少し辛くできますか？
[英語文]
Excuse me, can you make this dish a bit spicier?
📌 キーフレーズ: [Excuse me]::すみません,[a bit spicier]::もう少し辛く
🖼 画像キーワード: restaurant waiter spicy dish

[日本語文]
明日のテストのために、この問題を一緒に解きませんか？
[英語文]
Shall we solve this problem together for tomorrow's test?
📌 キーフレーズ: [Shall we ~ ?]::一緒に〜しませんか？
🖼 画像キーワード: school desk students textbook`;

const $input = document.getElementById("input");
const $chk = document.getElementById("chkDedup");

function currentRows(){
  let rows = parseBlocks($input.value);
  if($chk.checked){
    const seen = new Set();
    rows = rows.filter(r=>{
      if(seen.has(r[0])) return false;
      seen.add(r[0]); return true;
    });
  }
  return rows;
}

document.getElementById("btnExample").addEventListener("click", ()=>{
  $input.value = EXAMPLE;
  const rows = currentRows();
  setStatus(`Số thẻ hợp lệ: ${rows.length}`);
  renderPreview(rows);
});

document.getElementById("btnPreview").addEventListener("click", ()=>{
  const rows = currentRows();
  if(rows.length===0){
    alert("Chưa tìm thấy thẻ hợp lệ. Mỗi block cần có [日本語文] và [英語文].");
  }
  setStatus(`Số thẻ hợp lệ: ${rows.length}`);
  renderPreview(rows);
});

document.getElementById("btnDownload").addEventListener("click", ()=>{
  const rows = currentRows();
  if(rows.length===0){
    alert("Không có thẻ hợp lệ để xuất.");
    return;
  }
  const csv = toCSVNoHeader(rows);
  downloadCSV("anki_cards.csv", csv);
});

// cập nhật đếm nhanh khi nhập
$input.addEventListener("input", ()=>{
  const rows = currentRows();
  setStatus(`Số thẻ hợp lệ: ${rows.length}`);
});
</script>
</body>
</html>
