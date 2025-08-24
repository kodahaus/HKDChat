local ADDON, ns = ...

ns.CFG = {
  PANEL_W        = 600,
  EDGE_PADDING   = 8,
  GUTTER_LEFT    = 24,
  GUTTER_RIGHT   = 24,
  BG_ALPHA       = 0.55,
  FADE_MS        = 0.20,
  LOGIN_DEBOUNCE = 1.5,

  MIN_TEXT_GAP   = 18,
  GAP_MULT       = 1.10,
  BOTTOM_NUDGE   = 6,
  FRAME_INSETS   = { left = 0, top = 2, right = 0, bottom = 2 },
  EXTRA_SPACING  = 1,

  -- Barra lateral esquerda
  LEFTBAR_W         = 48,
  LEFTBAR_PAD       = 6,
  LEFTBAR_STRATA    = "FULLSCREEN_DIALOG",
  LEFTBAR_LEVEL_BONUS = 3000,

  -- Escalas
  SCALE_SOCIAL      = 1.15,   -- FriendsMicroButton (topo)
  SCALE_CHATMENU    = 1.25,   -- ChatFrameMenuButton (rodapé)  <-- maior
}
