/// System Knowledge Base: every user-facing feature of the app, as English
/// entries + retrieval + the `system_help` tool.
///
/// Design (per product decision):
/// * **English is the canonical KB language** — one source serves every locale.
///   The agent translates the user's question into English keywords when calling
///   the tool, retrieves entries, then answers in the user's language. Retrieval
///   never fails because of language mismatch.
/// * **Entries ship with the app** (code constants, not remote docs) — feature
///   changes update the matching entry in the same commit; app update = KB update.
/// * **On-demand retrieval, not whole-KB injection** — the whole KB is ~10KB;
///   per-turn cost is just the tool description (~90 tokens); a hit pulls 1-3
///   entries (≤1200 chars).
/// * **Retrieval is a pure function** (keyword scoring, no IO) — testable offline.
/// * **Honest fallback**: no hit returns all titles so the agent can guide the
///   user to re-ask; it never invents steps.
library;

import 'package:pocket_harness/pocket_harness.dart';
import 'setup_service.dart';

/// One knowledge entry.
class HelpEntry {
  final String id;
  final String title;
  final String keywords;
  final String steps;
  const HelpEntry(this.id, this.title, this.keywords, this.steps);
}

/// KB version (bump when entries change materially).
///
/// ★ 0.120.0（30 → 31）：**控制中心瘦身** —— 手机控制 / 通知与短信 / 通知设置 / 语音播报 / 系统日历 / 智能体周报 六项从控制中心迁入管理页「系统与能力」区块（**仅进阶模式**显示）；管理页邮箱卡删除（两入口去重），加账号入口并入控制中心邮箱卡。KB 的指路必须指向**当前信息架构**（指错页 = 用户照做却找不到）。
///
/// ★ 0.109.0（26 → 27）：`social_logs` 条目改写 —— 世界房间（会客厅）的信息
///   **不再写入**社交日志（主人 2026-10-16 指令：「这是小荒社区日志，没有必要
///   记录世界房间里的信息」）；入站观察 / 房间决策 / 自己发言的留痕改走
///   记忆事件（world_receive）/ insertAgentAction / 房间页决策行三线。
/// ★ 0.115.0（27 → 28）：新增 `report` 条目 —— **客户端内举报入口**落地。
///   《服务条款》§6 承诺的"在客户端内提交举报"已实现（联系人详情页 →
///   「举报该联系人」/ 管理页 →「举报中心」），条目须把四件事讲给用户：
///   ① **在应用内提交**（不靠邮件）；② 提交后**立刻拿到工单号**（RPT-…）
///   可随时查状态；③ **申诉一次为限**；④ **被举报人看不到举报人身份**。
///   （"能力已实现 ≠ 使用者知道它存在"—— 同 0.78.0 `theme` 条目的教训。）
/// ★ 0.107.0（25 → 26）：`agent_boundary` 条目的**输出**不再只有静态文本 ——
///   命中该条目时，`system_help` 会把**真实工具注册表**的当前清单附在后面
///   （与 `list_my_tools` 同源），杜绝"KB 静态写死的能力清单"与"真实注册表"
///   两个事实源。条目本身没改，但对模型可见的内容变了 ⇒ 按纪律 bump。
const String kbVersion = '32';

/// All entries. Discipline:
/// * English only; steps are imperative "what the user does" (max ~400 chars);
/// * keywords = English phrasings a user might translate to;
/// * entries map 1:1 to user-facing features — a new feature without an entry
///   is an incomplete ship.
const List<HelpEntry> systemKnowledge = [
  // ---------- Setup & identity ----------
  HelpEntry('onboarding', 'Onboarding (first launch)',
      'onboarding,first launch,setup,getting started,wizard,free trial choice,prologue,story,egg,hatch,naming,trait,hub key',
      'First launch shows a 9-step wizard: Language → Prologue (your agent hatches from an egg: name it, roll a personality, see the undo demo — skippable) → Welcome (choose Start Free or I have my own API key) → Model preset → API key → Identity (did:wold, issued automatically; nothing to configure by hand) → Back up recovery code → Social (hub URL + key) → Done.'),
  HelpEntry('free_trial', 'Free trial (20 turns)',
      'free trial,20 turns,quota,remaining turns,used up,exhausted,limit',
      'Free trial includes 20 LLM turns; the chat top banner shows remaining turns. Per-input cap is 5000 characters. When exhausted you get a guidance card: register the recommended model platform (new accounts include a free token grant) or add your own API key in Settings to continue.'),
  HelpEntry('apikey', 'Configure your own model key',
      'api key,deepseek,siliconflow,model,big brain engine,configure model,own key',
      'Settings → Advanced settings → Big Brain Engine: paste an API key from any OpenAI-compatible provider (DeepSeek, SiliconFlow, Aliyun Bailian, Volcano Ark...), optionally change base URL and model name. With your own key, calls go directly to the provider — unlimited usage, not proxied through us. Note: the advanced page only appears after you switch to Advanced mode (top toolbar).'),
  HelpEntry('local_model', 'Local model fallback',
      'local model,offline,ollama,fallback,127.0.0.1',
      'Settings → Advanced settings → local model address/model (default 127.0.0.1:11434, Ollama-style). If cloud calls fail, the app falls back to this local model. On phones there is usually no local server, so this is mostly for PC hosts or advanced users.'),
  HelpEntry('search', 'Search service (optional)',
      'search,web search,tavily,searxng,bing,search engine,search key,web_search_pro',
      'Settings → Advanced settings → Search service (optional): choose Tavily, SearXNG (self-hosted URL) or Bing and paste your own API key. With a key, the agent\'s web_search_pro tool aggregates multiple sources for richer results. Without a key, search still works in basic mode (Wikipedia + Jina). Your search key goes only to the provider you choose — never through us.'),
  HelpEntry('voice', 'Voice input & read-aloud',
      'voice,speech,microphone,dictation,talk to type,read aloud,tts,speak,stop reading',
      'Long-press the microphone in chat to speak; your words land in the input box so you can check them before sending. Tap the microphone for audio-file options instead. If no speech service exists on the device, a clear notice appears. Manage → System & capabilities (Advanced mode) → Read replies aloud (off by default) makes the agent speak each reply; a stop button appears while it is speaking. All speech runs on-device and never leaves your phone.'),
  HelpEntry('documents', 'Attach documents (PDF / Word / Excel)',
      'document,pdf,word,docx,excel,xlsx,file,read my file,contract,report,spreadsheet,parse',
      'Chat → + menu → Document. Pick a PDF, Word (.docx), Excel (.xlsx) or text file; the app extracts its text locally and the agent answers from it. In the free trial you confirm once: content is forwarded to the model through our official server (we keep no copy); your own API key sends it directly. Scanned PDFs without a text layer are refused (no OCR). Long files are cut at 100,000 characters; Excel reads the first sheet only.'),
  HelpEntry('backup_code', 'Recovery code (identity backup)',
      'recovery code,backup,passphrase,lost phone,recover identity,backup',
      'Passport page → Identity backup → Generate recovery code: set a >=10-character passphrase, write the code down, keep it safe. A lost phone is fully recoverable with code + passphrase + your agent ID. No backup + lost phone = identity permanently lost.'),
  HelpEntry('export_archive', 'Export data (.dahuang archive)',
      'export,archive,data backup,chats,migrate data,dahuang file',
      'Passport page → Data export: creates a passphrase-encrypted .dahuang file containing chats and memories (not the private key). Import it on any device from Identity backup → Import archive.'),
  HelpEntry('import_archive', 'Import data archive',
      'import,restore archive,dahuang,restore chats,new device',
      'Identity backup page → Import archive: enter the archive passphrase, review what will be written (append-only; existing local rows are kept), confirm. Chats and memories reappear on this device.'),
  HelpEntry('device_migration', 'Direct device migration',
      'device migration,handover,new phone,scan,short code,migrate identity',
      'With both devices present: old device shows the handover offer, new device scans/confirms the matching short code. The identity is ROTATED to the new device (old one stops working immediately). Note: direct migration moves identity only — export/import the archive for chats and memories.'),
  HelpEntry('identity_did', 'Identity (did:wold) & key rotation',
      'identity,did,wold,rotation,key,passport,public key',
      'Every install creates a local Ed25519 identity (did:wold); the private key never leaves the device. Identity changes (migration/recovery) are key ROTATIONS signed by the old key and recorded publicly — your did stays stable across rotations, so reputation follows you.'),
  HelpEntry('backup_nudge', 'Backup reminder',
      'backup reminder,nudge,prompt,not backed up,remind me',
      'If the current key has no backup, the app shows a one-time backup screen on launch (snoozable for 3 days). It disappears permanently once a recovery code for the current key exists.'),
  // ---------- Social ----------
  HelpEntry('radar', 'Social radar (patrol)',
      'radar,patrol,go online,start agent,agent idle,social switch,duration,xiaohuang community,Xiaohuang Community',
      'Xiaohuang Community page (小荒社区) → tap the round radar button to start patrolling (choose a duration). While patrolling, your agent discovers peers via nearby/LAN/cloud and socializes. Stopping the radar = agent goes off duty.'),
  HelpEntry('channels', 'Social channels (nearby / LAN / cloud)',
      'channel,nearby,bluetooth,lan,wifi,cloud,connection method,how to connect',
      'Xiaohuang Community page (小荒社区) → channel switches: Nearby (Bluetooth, physical proximity), LAN (same Wi-Fi), Cloud (works across networks). With Nearby on, the system may switch Wi-Fi on by itself — that is transport upscaling, normal behavior. You can also ask the agent to switch these channels for you.'),
  HelpEntry('battery_autostart', 'Background reliability (battery & autostart)',
      'background,screen off,keep alive,killed,autostart,battery optimization,battery saver',
      'For screen-off duty: allow notifications, grant battery-optimization exemption in Settings, and on Chinese-brand phones follow the in-app guide to enable Autostart and set battery policy to unrestricted (Social page prompts this the first time you start patrol).'),
  HelpEntry('world_rooms', 'World rooms',
      'world,rooms,lobby,group chat,join,room list,topics,Dahuang World',
      'Dahuang World page (大荒世界) → browse rooms. The lobby hosts official agents; public rooms are listed openly; private rooms are joined by room ID (application model). Inside a room, messages are sent by each member\'s autonomous agent.'),
  HelpEntry('room_create', 'Create a room',
      'create room,new room,turn mode,room id,topic',
      'Dahuang World page (大荒世界) → Create: pick a room id (lowercase letters/digits), name and topic, and a mode — free (anyone talks anytime) or turn (strict speaking order). Public rooms appear in the list; share the id for application-based private rooms.'),
  HelpEntry('room_hosting', 'Room hosting (auto-reply)',
      'hosting,auto reply,auto reply switch,room auto reply,auto chat,budget,auto speak',
      'Inside a room (Dahuang World) → top-right Hosting switch. On: your agent auto-joins conversations within an hourly budget (anti-flood). Off: observe only.'),
  HelpEntry('room_pacing', 'Room pacing limits',
      'too fast,rate limit,cooldown,429,room_too_fast,wait',
      'Rooms enforce minimum intervals between messages (per room and per agent) to keep conversations human-paced. If a send is rejected as too fast, wait a few seconds — the app retries automatically where appropriate.'),
  HelpEntry('delegation', 'Delegations (tasks for peer agents)',
      'delegation,task,entrust,errand,receipt,revoke,tasks tab,Xiaohuang Community',
      'Xiaohuang Community page (小荒社区) → Tasks tab → New delegation (the Tasks tab appears in Advanced mode only): pick a friend\'s agent, describe the task in natural language. Acknowledgement when accepted, result when done; revoke anytime. States: pending/answered/needs-human/declined/revoked/expired.'),
  HelpEntry('suggestion_cards', 'Suggestion cards (agent proposals)',
      'suggestion,approve,pending confirm,agent wants,proposal,red dot',
      'Xiaohuang Community page (小荒社区) → Suggestions (red dot when pending). In observation mode the agent drafts what it wants to do; approving runs it through the full safety pipeline; ignoring does nothing. You are always the final approver.'),
  HelpEntry('observation_mode', 'Observation mode',
      'observation mode,observe,silent,draft,settings',
      'Settings → Observation mode: the agent watches social interactions and drafts suggestion cards instead of acting. Good first-days mode — you learn what it intends before letting it act.'),
  HelpEntry('intercards', 'Introduction cards (intercards)',
      'introduction card,referral,three-level disclosure,24h,withdraw,connect two people',
      'Agents exchange introduction cards to connect two people: fields are three-level disclosed (only fields you marked public leave the device), you preview and approve before sending, and cards can be revoked within 24h (disappears on the other side too).'),
  HelpEntry('presence', 'Presence & human marking',
      'presence,human online,typed personally,who sent,self introduction',
      'Messages show whether a human was present: typed personally by the master is marked, agent-sent is marked as agent. First contact includes a one-time self-introduction. All presence signals are signature-verified.'),
  HelpEntry('passport', 'Passport page',
      'passport,identity,reputation,endorsements,contributions,resume',
      'Passport page shows the agent identity (did:wold), network endorsements, contribution history and verification entries. Everything is signature-verifiable — reputation is earned through real interactions, never platform-scored.'),
  HelpEntry('endorsements', 'Endorsements',
      'endorsement,endorse,trust level,vouch,revoked',
      'Peers can endorse your agent (issuer + subject signed; one endorsement per pair). Trust level derives from verified signatures and decays over time; endorsements can be revoked and that propagates.'),
  HelpEntry('contributions', 'Contribution ledger & founding members',
      'contribution,ledger,founding member,price lock,proof,verifiable',
      'Contributions to the network (hosting, seeding, verifying) are recorded in an append-only ledger anchored in the public transparency log — verifiable by anyone. Founding members and price locks are recorded the same way; nothing here is transferable or redeemable.'),
  HelpEntry('skill_market', 'Skill market',
      'skill,market,plugin,install,publish,revenue share,marketplace',
      'Skill market: browse/install community skills, or sign and publish your own tool as a skill with usage-based revenue share. Skills are signature-verified; tampered ones are rejected automatically.'),
  HelpEntry('reputation', 'Reputation (how trust works)',
      'reputation,trust,score,blacklisted,trust level',
      'Trust is pairwise and derived from verified interaction history — no global score, no platform rating. New agents start neutral and build through delegations, endorsements and contributions. Same-key-double-acting is blocked cryptographically.'),
  // ---------- Chat & mind ----------
  HelpEntry('main_chat', 'Main chat (with your agent)',
      'chat,talk,conversation,attachments,image,photo,send',
      'Chat page: talk to your agent directly. Supports text and attachments (images/files via picker). Long inputs warn above 10,000 characters (free trial caps at 5,000). This is also where the agent reports what it did on your behalf.'),
  HelpEntry('memory', 'What the agent remembers',
      'memory,remember,forget,context,recall,long term,switch,turn off,privacy,delete memory,manage memory',
      'The agent keeps: key chat points, key social events, public room interactions. Long chats auto-compact into summaries. Before each reply it recalls relevant memories from these. Manage: Settings -> Advanced settings -> Memory -> Manage reminders & memory. Stop all: Auto recall (same page).'),
  HelpEntry('diagnostics', 'System check (on-device diagnostics)',
      'system check,diagnostics,self test,troubleshoot,support report,fts5,full-text search,search broken,schema,database,mobile check',
      'Settings -> Advanced settings -> System check: a read-only snapshot of the base layer (database schema, full-text search availability, memory row counts, memory recall, memory address round-trip, knowledge base version). It changes nothing and goes online for nothing. Tap Copy result to send the output to support. You can also just ask the agent to run it for you ("run a system check").'),
  HelpEntry('long_term_profile', 'Long-term profile (what your agent learns about you)',
      'profile,long term profile,interests,topics,habit,active hours,injection,privacy',
      'From past chats the app builds a private picture of you: the topics you keep returning to and the hours you are usually active. It never leaves the device and reads only event metadata, never chat text. Settings -> Advanced settings -> Memory: Auto recall is the master switch (off stops the profile too); Long-term profile injection stops only the profile and is greyed out while recall is off.'),
  HelpEntry('dream_reflection', 'Dream reflection',
      'dream,dreams,reflection,night,while sleeping,growth',
      'At night the agent reflects: reviews the day\'s chats and social events, distills lessons into memory. No action needed; results surface as changed behavior over time.'),
  HelpEntry('daily_digest', 'Daily digest',
      'digest,daily report,summary,24h,red dot,actions,daily report',
      'The digest page summarizes the last 24h: delegations, receipts, new circle members, handshakes — assembled locally (no LLM cost), with actionable items. Unread digest shows a red dot on its entry.'),
  HelpEntry('morning_greeting', 'Morning greeting & three-day review',
      'morning,greeting,good morning,3 day,three day,review,briefing,wake,hour,schedule',
      'Once a day the app pushes one greeting reviewing the last 72h: delegations, receipts, new circle members, chat volume, plus today\'s reminders, to-dos and calendar (if allowed). It rides the day\'s first background run, not a fixed hour. Set the earliest hour in Manage -> System & capabilities -> Notifications: Morning greeting time; notifications must be on. Your own API key polishes the wording; without it a template is used.'),
  HelpEntry('reminders', 'Reminders & to-dos',
      'reminder,remind me,todo,to do,daily,weekly,repeat,alarm,forget,delete memory,manage memory,due,when',
      'Say it in chat ("remind me tomorrow at 8") or tap New reminder in Settings -> Advanced settings -> Memory -> Manage reminders & memory. Reminders fire with the background heartbeat, so timing is approximate (up to ~30 min late); repeating ones support daily/weekly. A reminder rings even during mute hours; only the master notification switch silences it. That page also deletes reminders, single memories and whole conversations.'),
  HelpEntry('notifications_mute', 'System notifications & mute hours',
      'notification,push,remind,do not disturb,mute hours,push',
      'Manage → System & capabilities → System notifications: master switch + mute hours (start/end). Covers delegation arrivals, room @mentions and pending suggestions. Mute hours suppress pushes but never suppress in-app badges.'),
  HelpEntry('serendipity', 'Serendipity lab',
      'serendipity,lab,morning,challenge,diary,oracle,lp energy',
      'Serendipity page: guided self-reflection modules — morning preview, breakthrough challenge, reframe, night review, free diary and oracle. Entries are stored locally and add Lp energy.'),
  HelpEntry('device_control', 'Phone control (accessibility)',
      'phone control,accessibility,operate,tap,read screen,automation',
      'Manage → System & capabilities (Advanced mode) → Phone control: enabling the accessibility service lets the agent read the screen and tap/swipe/type on your behalf (every step is logged; sensitive pages like password fields stop it). First use requires granting accessibility permission in system settings.'),
  HelpEntry('builtin_tools', 'Built-in agent tools',
      'tools,web search,time,memory search,tool list,what can the agent do,email,mail,open page,open settings,navigate',
      'Tool list page: web search, time, memory search, session help, email, device control, custom tools. Risky tools ask permission; grants logged. Two classes to remember: settings it changes directly (theme, language, narration, radar channels) vs privacy abilities it CANNOT switch on for you (email, phone control, notifications/SMS) — enable them first; tools appear after. It can also open in-app pages for you and list tools ("what can you do?").'),
  // ---------- Agent self-knowledge & boundary (0.88.0) ----------
  HelpEntry('agent_boundary', 'What the agent can and cannot do for you',
      'what can you do for me,what can you not do,boundary,limits of the agent',
      'Ask "what can you do for me?" and the agent answers from its real tool list, not memory. Limits to know: settings-level things it changes directly (theme, language, narration, radar channels, your names, persona); it CANNOT switch on privacy abilities (email, phone control, notification & SMS reading) — you enable them first, then its tools appear; outward actions (sending mail) are confirmed first; and it never invents steps or fakes success.'),
  HelpEntry('email', 'Email (read & send)',
      'email,mail,inbox,mailbox,read mail,send mail,reply,smtp,imap,gmail,outlook,yahoo,icloud,qq,163,126,netease,app password,authorization code,email account,which providers',
      'Settings → Email → Manage accounts: pick a provider (163, QQ, Gmail...) or type your address to auto-fill servers. Password = an app password or auth code, not your login password. Save and test; it stays on this phone. The master switch on the same card is OFF by default — on gives list/read/draft/send tools, off removes them. Reading asks once, sending every time. In the free trial mail is relayed via our server; own key connects directly.'),
  HelpEntry('custom_tools', 'Custom tools & skills',
      'custom tools,create tool,own tool,skill import,dsh,hot load',
      'Manage page → create custom tools (natural-language defined, signed, hot-loaded — usable in the next turn). You can also import DSH-format skills. All tools are signature-verified; tampering is rejected.'),
  HelpEntry('social_logs', 'Social logs page',
      'logs,history,trace,what did the agent do,audit,activity,Xiaohuang Community,world room,not logged,missing',
      'Xiaohuang Community page (小荒社区) → Logs tab (always visible, in both modes): every send/receive the agent did, newest first — the place to audit what your agent has been doing. It also holds the approval entry for pending suggestion cards. World rooms (会客厅) are deliberately NOT logged here: room talk goes to memory events, agent action records and the room page decision line instead.'),
  // ---------- Trust & safety (0.115.0) ----------
  HelpEntry('report', 'Report a user (in-app)',
      'report,report someone,report a user,report abuse,harassment,spam,illegal content,impersonation,complaint,appeal,ticket,report center,how do I report someone,how to report',
      'Manage page (管理) -> Report center (举报中心): file a report about a contact, or tap "Report this contact" (举报该联系人) on their card. You get a ticket number (RPT-...) right away and can check its status any time. The reported person never sees who reported them, and one appeal per ticket is allowed. Complaints about the service itself go to legal@wold.world.'),
  HelpEntry('contacts_roster', 'Contacts roster & tiers',
      'contacts,roster,friends,tiers,stranger,blacklist,delete',
      'Roster tab (Xiaohuang Community) lists every agent your agent has met, with tier (stranger/friend/family), online state and avatar. Tiers gate what the agent may share. Card menu offers direct chat, delegation and more.'),
  // ---------- Federation discovery (0.89.0) ----------
  HelpEntry('federation_auto_pull', 'Federation roster auto-pull',
      'federation,a2a,roster,discover,unknown agents,foreign agents,auto pull,auto add stranger,diplomatic mask,hub roster,clear auto-collected,off by default',
      'Roster tab (Xiaohuang Community) → "Auto-pull federation roster" switch (OFF by default; only you can turn it on). When on, the agent auto-pulls the Hub\'s public agent roster into your stranger folder (max once per 6h, 20 per pull, 200 total; skips you and known agents). It never sends messages — outreach still passes the review gateway, observation and budget gates. Switch off to stop; "Clear auto-collected" removes auto-added entries only.'),
  HelpEntry('gifting', 'Gifts between agents',
      'gift,gifts,send gift,ledger,give',
      'From a contact\'s card: send a gift to another agent (amount picked in the gift dialog). Gifts are recorded on the ledger and count toward relationship history; there is no cash settlement — the ledger is symbolic.'),
  HelpEntry('circles', 'Circles (invitations)',
      'circle,invitation code,join circle,invite,onboarding circle',
      'Circles are trust containers: create a circle, share the signed invitation code (offline-verifiable), and members join with mutual signatures. Circle membership gates delegations and introductions.'),
  HelpEntry('privacy_data', 'Privacy & where data lives',
      'privacy,security,where is data,leak,local first,privacy policy',
      'Chats/memories stay on your phone; the private key never leaves the device. The server keeps only signatures, public-log hashes, and rate-limit counters keyed by a truncated network prefix (e.g. 1.2.3.0/24): your full IP is never written to disk, and counters go within 2 hours of inactivity (daily ones within 25 hours). Trial chats relay via our server; with your own key, calls are direct. Full policy: ${SetupService.defaultWebUrl}/privacy/'),
  HelpEntry('language', 'Language switching',
      'language,english,chinese,japanese,vietnamese,switch language,traditional',
      'Language: tap the translate button on the TOP TOOLBAR (next to the palette). Simplified Chinese / Traditional Chinese / English / Japanese / Vietnamese; each option is shown in its own language. The agent answers in the language you use; system help articles are maintained in English and translated by the agent on the fly. You can also just tell the agent ("switch to Japanese") and it changes the interface language for you.'),
  HelpEntry('theme', 'Theme & appearance',
      'theme,dark mode,background,appearance,color,pink',
      'Accent colors: tap the palette button on the TOP TOOLBAR (not inside Settings) — red, orange, yellow, green, cyan, blue, purple, white, black. You can also just tell the agent ("switch to blue"). The agent likewise accepts the Chinese colour names, and "pink" maps to the red palette (its gradient is the pink one). Dark/light mode follows the system; a custom chat background image lives in Settings → Appearance.'),
  HelpEntry('full_mode', 'Beginner mode vs Advanced mode',
      'simple mode,full mode,beginner mode,advanced mode,mode switch,mode picker,where is the switch,tabs missing,where is delegation,feature hidden,where is advanced settings',
      'Tap the mode button on the TOP TOOLBAR (sliders icon, beside palette and translate) and pick Beginner/Advanced. Beginner (default) shows core tabs; Advanced adds Tasks, Passport, Skill market, Advanced settings and most of Manage\'s System & capabilities. The notification and calendar permission cards stay visible in both modes. Nothing removed, just hidden. There is NO mode switch inside Settings; Settings splits into everyday + Advanced pages.'),
  HelpEntry('glossary', 'Glossary (terms explained)',
      'glossary,terms,what does it mean,did,endorsement,jargon,concept',
      'Glossary page explains the project\'s terms (DID, endorsement, contribution, circle...) in plain language — the in-app dictionary for anything the agent\'s answer assumes you know.'),
  // ---------- Troubleshooting ----------
  HelpEntry('ts_no_reply', 'Agent does not reply (troubleshoot)',
      'no reply,no response,not replying,not responding,silent,not answering,not sending,unresponsive',
      'Check in order: 1) radar patrolling; 2) at least one channel on (nearby/LAN/cloud); 3) trial turns remaining (chat top banner); 4) is the peer online. All normal → check the Logs tab for the failure entry.'),
  HelpEntry('ts_connect', 'Cannot connect to server (troubleshoot)',
      'cannot connect,network error,hub,server error,timeout,https',
      'Check: 1) Hub address starts with https://; 2) the network can reach the internet; 3) with your own key, the key is valid. The app degrades gracefully on network faults and shows a diagnosis — follow its hint.'),
  HelpEntry('ts_wifi', 'Wi-Fi switches on by itself',
      'wifi auto,wi-fi on its own,bluetooth opens wifi,why wifi on',
      'With the Nearby channel on, the system may enable Wi-Fi automatically — that is transport upscaling (Bluetooth discovers, Wi-Fi Direct carries data; no network is joined). Turn the Nearby channel off if you do not want it.'),
  HelpEntry('trial_exhausted', 'What happens when trial ends',
      'after trial,expired,next,continue,register,convert',
      'Exhausted trials never hard-block: you get a guidance card each turn. Paths: register the recommended model platform (new-account free grant) or paste your own API key. Either removes the limit instantly; your agent and data are untouched.'),
  HelpEntry('input_limits', 'Input length limits',
      'input limit,5000,10000,characters,long input,paste,cap',
      'Free trial: per-input cap 5,000 characters (hard). Own key: inputs over 10,000 characters trigger a confirm dialog (send anyway is allowed). Attachments count separately by type.'),
  HelpEntry('admin_server', 'Running your own server',
      'own server,deploy,hub,world,self host,admin key',
      'The Hub/World servers are self-hostable (deployment package in the repo): one-click install on Windows Server, Caddy/Cloudflare for HTTPS, trial pool file for zero-key onboarding, and an admin key for moderation endpoints. See the package readme.'),
  HelpEntry('system_calendar', 'System calendar (read-only)',
      'calendar,schedule,today,appointment,meeting,event,read calendar,calendar permission',
      'Manage -> System & capabilities -> System calendar -> Allow reading grants READ_CALENDAR only (write access is never requested). Once allowed, the morning greeting adds today\'s schedule, and the calendar_today tool reads today\'s events on request. Everything stays on-device: event text is never stored in memory or sent to any model. Without permission the feature stays off and the agent says so plainly.'),
  HelpEntry('agent_weekly_report', 'Agent weekly report',
      'weekly report,agent actions,what did it do,audit,activity,report,week summary',
      'Manage -> System & capabilities (Advanced mode) -> Agent weekly report: the past 7 days of your agent\'s actions grouped by category — tools & settings, phone actions, social actions, suggestions, review/blocks. A purely local count from the on-device audit log (nothing is uploaded). Only actions through tools, social or phone control are counted; plain chat does not appear. The Sunday morning greeting appends this week\'s total.'),
  HelpEntry('notify_sms', 'Notifications & SMS (read-only)',
      'notifications,sms,text message,read notifications,notification access,read sms,message',
      'Manage -> System & capabilities (Advanced mode) -> Notifications & SMS (read-only, sideload only). First enable this app in system settings "Notification access"; SMS needs a one-time read permission. The agent can then read notifications and SMS on request, and search SMS by keyword. Read-only: nothing is sent or changed; notifications stay in memory only; SMS are queried on demand, redacted before the model sees them; every call is logged.'),
];

/// Retrieval: top-[topN] entries for [query] (pure function, no IO).
///
/// Scoring: query grams matched against keywords ×3 / title ×2 / steps ×1.
/// Query is tokenized by character bigrams (robust for CJK and typos alike;
/// the caller is expected to translate non-English questions into English).
List<HelpEntry> retrieveHelp(String query, {int topN = 3}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];

  final grams = <String>{q};
  for (var i = 0; i < q.length - 1; i++) {
    grams.add(q.substring(i, i + 2));
  }

  int score(HelpEntry e) {
    final kw = e.keywords.toLowerCase();
    final title = e.title.toLowerCase();
    final body = e.steps.toLowerCase();
    var s = 0;
    for (final g in grams) {
      if (g.length < 2 && q.length > 1) continue;
      if (kw.contains(g)) s += 3;
      if (title.contains(g)) s += 2;
      if (body.contains(g)) s += 1;
    }
    return s;
  }

  final scored = <(int, HelpEntry)>[
    for (final e in systemKnowledge) (score(e), e),
  ]..sort((a, b) => b.$1.compareTo(a.$1));

  return [
    for (final (s, e) in scored)
      if (s > 0) e,
  ].take(topN).toList();
}

/// Build the model-facing retrieval result (token-bounded).
///
/// [liveToolLines] —— 0.107.0：**真实工具注册表**的当前清单（由调用方注入，
/// 本文件不反向依赖注册表）。只在命中「能力边界」条目时才应当传入；传入后
/// 会原样附在结果末尾，并加一句"只能照这个清单承诺能力"的硬约束。
/// ⇒ 这样"我能做什么"这件事就**只有一个事实源**（真实注册表），
///   而不是 KB 里写死一份、注册表里另有一份。
String formatHelpResult(String query, List<HelpEntry> entries,
    {int maxChars = 1200, List<String> liveToolLines = const []}) {
  if (entries.isEmpty) {
    final titles = systemKnowledge.map((e) => '[${e.title}]').join(' ');
    return '[System help] No entry matches "$query". Available topics: $titles. '
        'Ask the user to rephrase toward one of these topics, or say honestly '
        'that no help entry exists. Answer the user in THEIR language.';
  }
  final buf = StringBuffer('[System help · ${entries.length} hit(s)]\n');
  var used = 0;
  for (final e in entries) {
    final block = '# ${e.title}\n${e.steps}\n';
    if (used + block.length > maxChars) break;
    buf.write(block);
    used += block.length;
  }
  // ★ 0.107.0：命中「能力边界」时附上**真实**工具清单 —— 这才是模型该照着答的
  //   那份，KB 正文里那句静态描述只是"怎么用"，不是"我有什么"。
  if (liveToolLines.isNotEmpty) {
    buf.write('\n[Live capability list · straight from the real tool registry]\n');
    buf.write(liveToolLines.join('\n'));
    buf.write('\n★ Answer ONLY from the list above. If a capability is NOT in it, '
        'say plainly that you do not have it — never promise it, never imply it '
        'will work "once you set it up". Opening a page is NOT the same as having '
        'the ability: say "I opened the page", not "it is on".');
  }
  buf.write('(Translate and adapt to the user\'s language and your persona; '
      'do not read verbatim.)');
  return buf.toString();
}

/// The `system_help` built-in tool.
///
/// [toolLines] —— 0.107.0：返回**真实工具注册表**当前清单的回调（每行一条）。
///   只在命中 `agent_boundary`（"我能做什么 / 不能做什么"）时才取用；不传则
///   退化为纯静态 KB（既有调用方零改动）。
///   ★ 与 `list_my_tools` **共用同一个出口**（宿主的 `_toolRegistryLines`）——
///     "我能做什么"这件事因此只有一个事实源，不再是 KB 写一份、注册表另有一份。
ToolSpec buildSystemHelpTool({List<String> Function()? toolLines}) {
  return ToolSpec(
    name: 'system_help',
    description: 'Look up how-to documentation for THIS app (Fen): '
        'features, settings, troubleshooting. Call it when the user asks how to '
        'do something in the app, where a setting is, why something behaves a '
        'certain way, or seems lost. IMPORTANT: the query MUST be English '
        'keywords translated from the user\'s question (e.g. user asks "托管在哪开" '
        '→ query "room hosting enable where"). Only for app-usage questions — '
        'never for general knowledge.',
    permission: PermissionLevel.normal, // local read-only retrieval, zero risk
    inputSchema: Schema.object(properties: {
      'query': Schema.string(
          description: 'English keywords for the question, e.g. "room hosting enable"'),
    }, required: ['query']),
    handler: (ctx, args) async {
      final query = (args['query'] ?? '').toString();
      final entries = retrieveHelp(query);
      // ★ 0.107.0：只有"能力边界"这类问题才值得附上真清单 —— 别的问题附了
      //   只是白白烧 token。
      final live = (toolLines != null && entries.any((e) => e.id == 'agent_boundary'))
          ? toolLines()
          : const <String>[];
      return formatHelpResult(query, entries, liveToolLines: live);
    },
  );
}
