/**
 * Kindleの購入通知メールを読んで、GitHub Issueのステータスを「💰 購入済み」にする。
 *
 * Kindleには購入履歴を取得する公式APIがないため、Amazonから届く注文確認メールを
 * 唯一の確実な購入シグナルとして使う。メール本文には商品ページのURLが入っているので、
 * そこからASINを取り出し、同じASINを含むIssueを突き合わせる。
 *
 * セットアップは README.md を参照。
 */

// ---- 設定（スクリプトプロパティで上書きできる） ----------------------
const DEFAULTS = {
  REPO: 'kawafuchieirin/book-to-action',
  // 購入した本のIssueが見つからないとき、新しくIssueを作るか
  CREATE_IF_MISSING: 'true',
  // 処理済みのメールに付けるGmailラベル（二重処理を防ぐ）
  PROCESSED_LABEL: 'book-to-action/処理済み',
  // 何日前までのメールを見るか
  SEARCH_DAYS: '30',
};

const STATUS_PURCHASED = '💰 購入済み';
const STATUS_LABELS = ['📋 読みたい', '💰 購入済み', '📚 積読', '📖 読書中', '✅ 読了', '🛑 辞めた'];

function config_(key) {
  return PropertiesService.getScriptProperties().getProperty(key) || DEFAULTS[key];
}

function token_() {
  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) throw new Error('スクリプトプロパティ GITHUB_TOKEN が未設定です');
  return token;
}

// ---- GitHub API -------------------------------------------------------
function github_(path, options) {
  const response = UrlFetchApp.fetch('https://api.github.com' + path, Object.assign({
    muteHttpExceptions: true,
    headers: {
      Authorization: 'Bearer ' + token_(),
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  }, options || {}));

  const code = response.getResponseCode();
  const body = response.getContentText();
  if (code >= 300) throw new Error(`GitHub API ${code}: ${body}`);
  return body ? JSON.parse(body) : null;
}

function searchIssues_(terms) {
  const query = encodeURIComponent(`repo:${config_('REPO')} ${terms}`);
  const result = github_(`/search/issues?q=${query}&sort=created&order=desc&per_page=5`);
  return ((result && result.items) || []).filter(item => !item.pull_request);
}

/**
 * 購入した本のIssueを探す。ASINが取れればそれが確実。
 * 古い形式のメールにはASINが無いので、タイトルで探すところまでフォールバックする。
 */
function findIssue_(asin, title) {
  if (asin) {
    const byAsin = searchIssues_(`${asin} in:body`);
    if (byAsin.length) return byAsin[0];
  }
  if (title) {
    // 記号で検索が外れることがあるので、長めの語だけを使う
    const words = title.split(/[\s　・:：「」『』（）()\[\]―ー-]+/).filter(w => w.length >= 3).slice(0, 3);
    if (words.length) {
      const byTitle = searchIssues_(`${words.map(w => `"${w}"`).join(' ')} in:title`);
      if (byTitle.length) return byTitle[0];
    }
  }
  return null;
}

function setPurchased_(issue) {
  const stale = (issue.labels || [])
    .map(label => label.name)
    .filter(name => STATUS_LABELS.indexOf(name) !== -1 && name !== STATUS_PURCHASED);

  // ステータスは常に1つだけにする
  stale.forEach(name => {
    github_(`/repos/${config_('REPO')}/issues/${issue.number}/labels/${encodeURIComponent(name)}`,
      { method: 'delete' });
  });

  github_(`/repos/${config_('REPO')}/issues/${issue.number}/labels`, {
    method: 'post',
    payload: JSON.stringify({ labels: [STATUS_PURCHASED] }),
  });
}

function createIssue_(title, asin, orderedOn) {
  // 古い形式のメールにはASINが無いので、その場合は検索リンクを入れておく
  const link = asin
    ? `https://www.amazon.co.jp/dp/${asin}`
    : `https://www.amazon.co.jp/s?k=${encodeURIComponent(title)}&i=digital-text`;
  const body = [
    '### ジャンル', '', '✏️ その他', '',
    '### ジャンル（その他を選んだ場合）', '', '_No response_', '',
    '### いまの状態', '', STATUS_PURCHASED, '',
    '### 購入リンク', '', link, '',
    '### きっかけ・解決したいこと', '', '（購入通知メールから自動作成。あとで埋める）', '',
    '### 手に入れたいもの', '', '（購入通知メールから自動作成。あとで埋める）', '',
    '### 登録したときの気持ち', '', '_No response_', '',
    '### 優先度', '', '🔥 今すぐ読みたい', '',
    '### メモ（任意）', '', `Kindleで購入（${orderedOn}）${asin ? '' : '※購入通知メールにASINがなかったため検索リンク'}`,
  ].join('\n');

  return github_(`/repos/${config_('REPO')}/issues`, {
    method: 'post',
    payload: JSON.stringify({
      title: `📚 ${title}`,
      body: body,
      labels: ['want-to-read', STATUS_PURCHASED, '🔥 今すぐ', '✏️ その他'],
    }),
  });
}

function comment_(issueNumber, text) {
  github_(`/repos/${config_('REPO')}/issues/${issueNumber}/comments`, {
    method: 'post',
    payload: JSON.stringify({ body: text }),
  });
}

// ---- メールの解析 -----------------------------------------------------
/**
 * 本のタイトルを取り出す。
 *
 * Amazonは注文確認メールの形式を何度も変えており、実際に次の3種類が存在する。
 *   2026年〜: 件名「Amazon.co.jpでのご注文: タイトル」／本文は商品リンクの次行がタイトル
 *   2025年頃: 件名「タイトルからなる注文Amazon.co.jp。」
 *   2024年頃: 件名「Amazon.co.jpでのご注文D01-...（1点）」＝タイトルなし
 *             本文の「Kindle版」の直前行がタイトル。商品リンク（ASIN）も入っていない
 * 件名より本文のほうが形式変更に強いので、本文を先に見る。
 */
function titleFromMessage_(subject, body) {
  const lines = (body || '').split('\n').map(line => line.trim());

  // 本文: 商品ページリンクの直後にある最初の非空行
  const linkAt = lines.findIndex(line => /\/dp\/[A-Z0-9]{10}/.test(line));
  if (linkAt !== -1) {
    const title = lines.slice(linkAt + 1).find(line => line && line.indexOf('販売') !== 0);
    if (title) return title;
  }

  // 本文: 「Kindle版」の直前にある最初の非空行
  const kindleAt = lines.findIndex(line => line === 'Kindle版' || line === 'Kindle 版');
  if (kindleAt > 0) {
    for (let i = kindleAt - 1; i >= 0; i--) {
      if (lines[i] && lines[i].indexOf('.....') === -1) return lines[i];
    }
  }

  // 件名のパターンを順に試す
  const patterns = [
    /ご注文[:：]\s*(.+)$/,                    // 2026年形式
    /^(.+?)からなる注文Amazon\.co\.jp/,       // 2025年形式
    /予約注文「(.+?)」/,                       // 予約注文
  ];
  for (const pattern of patterns) {
    const m = (subject || '').match(pattern);
    if (m && m[1].trim()) return m[1].trim();
  }
  return (subject || '').trim();
}

/** 本文の商品ページURL（/dp/ASIN）からASINを取り出す。古い形式には入っていない */
function asinFromBody_(body) {
  const m = (body || '').match(/\/dp\/([A-Z0-9]{10})/);
  return m ? m[1] : '';
}

function processedLabel_() {
  const name = config_('PROCESSED_LABEL');
  return GmailApp.getUserLabelByName(name) || GmailApp.createLabel(name);
}

// ---- エントリポイント（時間トリガーで実行する） -----------------------
function syncKindlePurchases() {
  const label = processedLabel_();
  const query = [
    'from:digital-no-reply@amazon.co.jp',
    'subject:ご注文',
    `newer_than:${config_('SEARCH_DAYS')}d`,
    `-label:"${config_('PROCESSED_LABEL')}"`,
  ].join(' ');

  const threads = GmailApp.search(query, 0, 50);
  const log = [];

  threads.forEach(thread => {
    thread.getMessages().forEach(message => {
      const subject = message.getSubject() || '';
      if (subject.indexOf('ご注文') === -1) return;

      const body = message.getPlainBody() || message.getBody() || '';
      const title = titleFromMessage_(subject, body);
      const asin = asinFromBody_(body);
      if (!title) {
        log.push('タイトルが取れなかったので飛ばした');
        return;
      }

      const orderedOn = Utilities.formatDate(message.getDate(), 'Asia/Tokyo', 'yyyy-MM-dd');
      const issue = findIssue_(asin, title);

      if (issue) {
        const current = (issue.labels || []).map(l => l.name);
        // 読書中・読了・辞めた まで進んでいる本を購入済みに巻き戻さない
        if (current.some(n => ['📖 読書中', '✅ 読了', '🛑 辞めた'].indexOf(n) !== -1)) {
          log.push(`#${issue.number} は先に進んでいるので触らない: ${title}`);
        } else if (current.indexOf(STATUS_PURCHASED) !== -1) {
          log.push(`#${issue.number} は既に購入済み: ${title}`);
        } else {
          setPurchased_(issue);
          comment_(issue.number, `Kindleで購入しました（${orderedOn}）`);
          log.push(`#${issue.number} を購入済みにした: ${title}`);
        }
      } else if (String(config_('CREATE_IF_MISSING')) === 'true') {
        const created = createIssue_(title, asin, orderedOn);
        log.push(`#${created.number} を新規作成した（未登録の購入）: ${title}`);
      } else {
        log.push(`該当Issueなし: ${title}`);
      }
    });
    thread.addLabel(label);
  });

  console.log(log.length ? log.join('\n') : '処理対象の購入通知メールはありませんでした');
  return log;
}

/** 設定確認用。トリガーを作る前に一度これを実行する */
function checkSetup() {
  const repo = github_(`/repos/${config_('REPO')}`);
  console.log(`リポジトリに接続できました: ${repo.full_name}`);
  const threads = GmailApp.search(
    `from:digital-no-reply@amazon.co.jp subject:ご注文 newer_than:${config_('SEARCH_DAYS')}d`, 0, 5);
  console.log(`購入通知メール: ${threads.length} 件見つかりました`);
  threads.forEach(t => {
    const m = t.getMessages()[0];
    const b = m.getPlainBody() || '';
    console.log(`  ${titleFromMessage_(m.getSubject(), b)} / ASIN=${asinFromBody_(b) || '(なし→タイトルで突き合わせ)'}`);
  });
}
