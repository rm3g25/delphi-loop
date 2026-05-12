unit uUIConsts;

{
  DelphiLoop v0.3 — UI constants
  Single source of truth for colors, layout, typography, and shape tokens.
  All magic numbers live here; form code stays clean.
}

interface

uses
  System.UITypes;

const
  // ---------------------------------------------------------------------------
  //  Dark palette (single theme — light mode support is v0.4+)
  // ---------------------------------------------------------------------------
  CLR_BG         = $FF1A1A1E;
  CLR_SIDEBAR    = $FF13131A;
  CLR_SURFACE    = $FF242428;
  CLR_SURF2      = $FF2E2E34;
  CLR_BORDER     = $FF3A3A42;
  CLR_ACCENT     = $FF2979FF;
  CLR_TEXT       = $FFE8E8EC;
  CLR_DIM        = $FF888896;
  CLR_MUTE       = $FF55555E;
  CLR_STATUS_BG  = $142979FF; // accent at ~8% alpha
  CLR_GREEN      = $FF3DBA6E;
  CLR_ORANGE     = $FFE8621A;
  CLR_ACCENT_LT  = $FF42A5F5; // lighter accent for avatar tints
  CLR_RUN_HOVER  = $FF3D8BFF; // run button hover state
  CLR_CLEAR_HOVER = $FFCC2244; // clear button hover state

  // Bubble backgrounds
  CLR_THINK_BG   = $FF252530; // thinking bubble (legacy — kept for reference)
  CLR_REV_OK     = $FF1A2420; // review — approved (dark green tint)
  CLR_REV_FIX    = $FF261E1A; // review — needs fix (dark orange tint)
  CLR_DONE_BG    = $FF192819; // done bar
  CLR_ERR_BG     = $FF261A18; // error bar

  // Task bubble
  CLR_TASK_BG     = $FF1E2535; // dark blue-tinted background
  CLR_TASK_BORDER = $FF3A5070; // muted blue border

  // Review bubble — rejection (red)
  CLR_REV_REJECT_BG  = $FF2A1515; // dark red background
  CLR_REV_REJECT_BDR = $FF6A3A3A; // red border
  CLR_REV_REJECT_ICO = $FFE24B4A; // red icon / text

  // Review bubble — no-issues (green)
  CLR_REV_NOISS_BG  = $FF1A2E22; // dark green background
  CLR_REV_NOISS_BDR = $FF2A5A38; // green border

  // Result panel
  CLR_RESULT_BG   = $FF1C2433; // dark blue-tinted body
  CLR_RESULT_HDR  = $FF1C2433; // header (same, separated by padding)
  CLR_RESULT_FOOT = $FF181E2A; // footer slightly darker

  // Badge tints (fill color for pill background)
  CLR_BADGE_DRAFT  = $1A2979FF;
  CLR_BADGE_FINAL  = $1A3DBA6E;
  CLR_BADGE_FIX    = $1AE8621A;

  // ---------------------------------------------------------------------------
  //  Layout — sidebar & chrome
  // ---------------------------------------------------------------------------
  SIDEBAR_W     = 220;
  LOGO_H        = 80;   // logo slot height (fits icon comfortably)
  STATUS_H      = 80;
  SFOOTER_H     = 50;   // sidebar footer (Settings button)
  IFOOTER_H     = 46;   // input footer (combos + run button row)

  // Input area
  MEMO_MIN_H    = 54.0;
  MEMO_MAX_H    = 140.0;
  INPUT_PAD_H   = 24;   // vertical padding around memo inside RectInput

  // Chat bubbles
  BUBBLE_MH     = 14.0; // bubble horizontal margin
  BUBBLE_MV     = 4.0;  // bubble vertical margin

  // Task bubble
  TASK_H_COLL   = 52;   // collapsed: tag header + preview line

  // Code bubble
  CODE_BUBBLE_COLL_H = 36; // collapsed: just the header strip

  // Review bubble (always the same height for the header strip)
  REVIEW_BUBBLE_H    = 36;

  // Result bubble (chat-stream, replaces fixed result panel)
  RESULT_BUBBLE_HDR_H   = 42;  // header row height
  RESULT_BUBBLE_FOOT_H  = 28;  // footer strip height
  RESULT_BUBBLE_COLL_H  = 106; // collapsed: header + footer + border breathing room
  // RESULT_PANEL_H / RESULT_HDR_H / RESULT_FOOT_H / RESULT_CODE_MAX_H removed in v0.3

  // ---------------------------------------------------------------------------
  //  Shape tokens
  // ---------------------------------------------------------------------------
  CORNER_SM     = 7;    // small radius  — settings back button, settings btn
  CORNER_MD     = 8;    // medium radius — run button, status block
  CORNER_LG     = 10;   // large radius  — input box, settings cards

  // ---------------------------------------------------------------------------
  //  Typography
  // ---------------------------------------------------------------------------
  FONT_XS       = 10;   // version label, section captions
  FONT_SM       = 11;   // iter label, dim text
  FONT_MD       = 12;   // buttons, settings rows
  FONT_LG       = 13;   // memo, logo label

  // ---------------------------------------------------------------------------
  //  Form defaults
  // ---------------------------------------------------------------------------
  FORM_W        = 1040;
  FORM_H        = 700;
  FORM_MIN_W    = 800;
  FORM_MIN_H    = 600;

  // ---------------------------------------------------------------------------
  //  Component sizes
  // ---------------------------------------------------------------------------
  BTN_H         = 32;   // standard button height
  BTN_RUN_W     = 54;   // run button width
  BTN_CLEAR_W   = 36;   // clear button width
  BTN_COPY_W    = 88;   // "Copy code" button width in result panel
  SETTINGS_ROW_H = 56;  // settings card row height
  PROGRESS_H    = 3;    // progress bar height
  SEPARATOR_H   = 1;    // divider line height

  // Logo image
  LOGO_IMG_W    = 120;
  LOGO_IMG_H    = 70;

  // ---------------------------------------------------------------------------
  //  App identity
  // ---------------------------------------------------------------------------
  APP_NAME      = 'DelphiLoop';
  APP_VERSION   = 'v0.3';

  // ---------------------------------------------------------------------------
  //  Asset paths (relative to exe folder)
  // ---------------------------------------------------------------------------
  PATH_STYLES   = 'styles\';
  FILE_STYLE    = 'Win10ModernDark.style';
  FILE_LOGO     = 'dlogo.png';

  // ---------------------------------------------------------------------------
  //  UI strings
  // ---------------------------------------------------------------------------
  STR_READY         = 'Ready';
  STR_RUNNING       = 'Running'#$2026;  // …
  STR_SETTINGS      = #$2699'  Settings';
  STR_MEMO_PROMPT   = 'Describe the task for DelphiLoop'#$2026;  // …
  STR_BTN_RUN       = #$25B6;    // ▶
  STR_BTN_RUNNING   = #$25CF' Running'; // ●
  STR_BTN_RUN_ICON  = #$25B6;           // ▶
  STR_BTN_CLEAR     = #$2715;           // ✕
  STR_HINT_RUN      = 'Run';
  STR_HINT_CLEAR    = 'Clear';

  // Collapsible bubbles — chevron states
  STR_CHEVRON_COLL  = #$25B6;           // ▶ (closed)
  STR_CHEVRON_OPEN  = #$25BC;           // ▼ (open)

  // Task bubble
  STR_TASK_TAG      = 'TASK';

  // Thinking text row
  STR_THINK_ARROW   = #$2192;           // →
  STR_THINK_SUFFIX  = ' thinking...';

  // Review verdicts
  STR_REVIEW_REJECTED = 'rejected result';

  // Result panel
  STR_RESULT_TITLE  = #$25C9' Final result'; // ◉ Final result (hex circle bullet)
  STR_COPY_CODE     = 'Copy';   // ⎘ Copy code

  // Sidebar status phases
  STR_PHASE_EXECUTOR = 'Executor';
  STR_PHASE_REVIEWER = 'Reviewer';
  STR_PHASE_DONE     = 'Done';
  STR_FMT_ITERATION  = 'Iteration %d of %d  '#$00B7'  %s';
  STR_FMT_ITER_HDR   = #$2014' Iteration %d of %d '#$2014;

implementation

end.
