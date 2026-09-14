// 後台側邊欄：換頁後維持捲動位置
//
// 後台每個選單都是整頁重新載入，側邊欄（.sidebar 自己有捲軸）的捲動位置預設會歸零，
// 點了下方的選單後，新頁面的側邊欄就會跳回最上面。這裡用 sessionStorage 記住位置。
//
// 這支檔案必須放在 </aside> 後面「同步」載入：側邊欄已經解析完、主內容還沒畫出來，
// 在這個時間點捲回原位，畫面才不會先出現在頂端再跳下去。
(function () {
  var sidebar = document.querySelector('.sidebar');
  if (!sidebar) return;

  var KEY = 'jlens-admin-sidebar-scroll';

  try {
    var saved = parseInt(sessionStorage.getItem(KEY), 10);
    if (!isNaN(saved)) sidebar.scrollTop = saved;
  } catch (e) {
    // 瀏覽器禁止存取 storage（例如隱私模式設定）時，維持原本行為即可
  }

  // 從頁面內容的連結跳過來時（例如在紀錄頁點使用者名稱），記住的位置不一定看得到
  // 目前這頁的選項，這種情況就把目前選項捲進畫面
  var active = sidebar.querySelector('a.active');
  if (active) {
    var itemRect = active.getBoundingClientRect();
    var sidebarRect = sidebar.getBoundingClientRect();
    if (itemRect.top < sidebarRect.top || itemRect.bottom > sidebarRect.bottom) {
      active.scrollIntoView({ block: 'nearest' });
    }
  }

  sidebar.addEventListener('scroll', function () {
    try {
      sessionStorage.setItem(KEY, String(sidebar.scrollTop));
    } catch (e) {}
  }, { passive: true });
})();
