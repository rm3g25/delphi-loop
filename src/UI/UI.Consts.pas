unit UI.Consts;

{
  UI constants: single source of truth for colors, layout, typography, and
  shape tokens. All magic numbers live here; form code stays clean.
}

interface

uses
  System.UITypes;

const
  // ---------------------------------------------------------------------------
  //  Dark palette (single theme - light mode support is v0.4+)
  // ---------------------------------------------------------------------------
  ColorBackground = $FF1A1A1E;
  ColorSidebar = $FF13131A;
  ColorSurface = $FF242428;
  ColorSurface2 = $FF2E2E34;
  ColorBorder = $FF3A3A42;
  ColorAccent = $FF2979FF;
  ColorText = $FFE8E8EC;
  ColorDim = $FF888896;
  ColorMute = $FF55555E;
  ColorStatusBackground = $142979FF; // accent at ~8% alpha
  ColorGreen = $FF3DBA6E;
  ColorOrange = $FFE8621A;
  ColorAccentLight = $FF42A5F5; // lighter accent for avatar tints
  ColorRunHover = $FF3D8BFF; // run button hover state
  ColorClearHover = $FFCC2244; // clear button hover state

  // Bubble backgrounds
  ColorThinkBackground = $FF252530; // thinking bubble (legacy - kept for reference)
  ColorReviewOk = $FF1A2420; // review - approved (dark green tint)
  ColorReviewFix = $FF261E1A; // review - needs fix (dark orange tint)
  ColorDoneBackground = $FF192819; // done bar
  ColorErrorBackground = $FF261A18; // error bar

  // Task bubble
  ColorTaskBackground = $FF1E2535; // dark blue-tinted background
  ColorTaskBorder = $FF3A5070; // muted blue border

  // Review bubble - rejection (red)
  ColorReviewRejectBackground = $FF2A1515; // dark red background
  ColorReviewRejectBorder = $FF6A3A3A; // red border
  ColorReviewRejectIcon = $FFE24B4A; // red icon / text

  // Review bubble - no-issues (green)
  ColorReviewNoIssuesBackground = $FF1A2E22; // dark green background
  ColorReviewNoIssuesBorder = $FF2A5A38; // green border

  // Result panel
  ColorResultBackground = $FF1C2433; // dark blue-tinted body
  ColorResultHeader = $FF1C2433; // header (same, separated by padding)
  ColorResultFooter = $FF181E2A; // footer slightly darker

  // Badge tints (fill color for pill background)
  ColorBadgeDraft = $1A2979FF;
  ColorBadgeFinal = $1A3DBA6E;
  ColorBadgeFix = $1AE8621A;

  // ---------------------------------------------------------------------------
  //  Layout - sidebar & chrome
  // ---------------------------------------------------------------------------
  SidebarWidth = 220;
  LogoHeight = 80; // logo slot height (fits icon comfortably)
  StatusHeight = 80;
  SidebarFooterHeight = 50; // sidebar footer (Settings button)
  InputFooterHeight = 46; // input footer (combos + run button row)

  // Input area
  MemoMinHeight = 54.0;
  MemoMaxHeight = 140.0;
  InputPaddingVertical = 24; // vertical padding around memo inside RectInput

  // Chat bubbles
  BubbleMarginHorizontal = 14.0; // bubble horizontal margin
  BubbleMarginVertical = 4.0; // bubble vertical margin

  // Task bubble
  TaskCollapsedHeight = 52; // collapsed: tag header + preview line

  // Code bubble
  CodeBubbleCollapsedHeight = 36; // collapsed: just the header strip

  // Review bubble (always the same height for the header strip)
  ReviewBubbleHeight = 36;

  // Result bubble (chat-stream, replaces fixed result panel)
  ResultBubbleHeaderHeight = 42; // header row height
  ResultBubbleFooterHeight = 28; // footer strip height
  ResultBubbleCollapsedHeight = 106; // collapsed: header + footer + border breathing room

  // ---------------------------------------------------------------------------
  //  Shape tokens
  // ---------------------------------------------------------------------------
  CornerSmall = 7; // small radius - settings back button, settings btn
  CornerMedium = 8; // medium radius - run button, status block
  CornerLarge = 10; // large radius - input box, settings cards

  // ---------------------------------------------------------------------------
  //  Typography
  // ---------------------------------------------------------------------------
  FontXs = 10; // version label, section captions
  FontSm = 11; // iter label, dim text
  FontMd = 12; // buttons, settings rows
  FontLg = 13; // memo, logo label

  // ---------------------------------------------------------------------------
  //  Form defaults
  // ---------------------------------------------------------------------------
  FormWidth = 1040;
  FormHeight = 700;
  FormMinWidth = 800;
  FormMinHeight = 600;

  // ---------------------------------------------------------------------------
  //  Component sizes
  // ---------------------------------------------------------------------------
  ButtonHeight = 32; // standard button height
  RunButtonWidth = 54; // run button width
  ClearButtonWidth = 36; // clear button width
  CopyButtonWidth = 88; // "Copy code" button width in result panel
  SettingsRowHeight = 56; // settings card row height
  ProgressHeight = 3; // progress bar height
  SeparatorHeight = 1; // divider line height

  // Logo image
  LogoImageWidth = 120;
  LogoImageHeight = 70;

  // ---------------------------------------------------------------------------
  //  App identity
  // ---------------------------------------------------------------------------
  AppName = 'DelphiLoop';
  AppVersionLabel = 'v0.3';

  // ---------------------------------------------------------------------------
  //  Asset paths (relative to exe folder)
  // ---------------------------------------------------------------------------
  StylesPath = 'styles\';
  StyleFileName = 'Win10ModernDark.style';
  LogoFileName = 'dlogo.png';

  // ---------------------------------------------------------------------------
  //  UI strings
  // ---------------------------------------------------------------------------
  SReady = 'Ready';
  SRunning = 'Running'#$2026; // …
  SSettings = #$2699' Settings';
  SMemoPrompt = 'Describe the task for DelphiLoop'#$2026; // …
  SButtonRun = #$25B6; // ▶
  SButtonRunning = #$25CF' Running'; // ●
  SButtonRunIcon = #$25B6; // ▶
  SButtonClear = #$2715; // ✕
  SHintRun = 'Run';
  SHintClear = 'Clear';

  // Collapsible bubbles - chevron states
  SChevronCollapsed = #$25B6; // ▶ (closed)
  SChevronOpen = #$25BC; // ▼ (open)

  // Task bubble
  STaskTag = 'TASK';

  // Thinking text row
  SThinkArrow = #$2192; // →
  SThinkSuffix = ' thinking...';

  // Review verdicts
  SReviewRejected = 'rejected result';

  // Result panel
  SResultTitle = #$25C9' Final result'; // ◉ Final result (hex circle bullet)
  SCopyCode = 'Copy'; // ⎘ Copy code

  // Sidebar status phases
  SPhaseExecutor = 'Executor';
  SPhaseReviewer = 'Reviewer';
  SPhaseDone = 'Done';
  SIterationFormat = 'Iteration %d of %d '#$00B7' %s';
  SIterationHeaderFormat = #$2014' Iteration %d of %d '#$2014;

implementation

end.
