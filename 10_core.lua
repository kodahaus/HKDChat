-- GROUP 10_core: 2 file(s) merged

-- BEGIN 00_init.lua
 do
local ADDON, ns = ...
ns.addon  = ADDON
ns.once   = ns.once or {}
ns.frames = ns.frames or {}
function ns.log(...) print("|cff55ff55HKDChat:|r", ...) end


 end
-- END 00_init.lua

-- BEGIN 05_config.lua
 do
local ADDON, ns = ...

ns.CFG = {
  PANEL_W        = 600,
  EDGE_PADDING   = 0,
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
  LEFTBAR_W         = 56,
  LEFTBAR_PAD       = 6,
  LEFTBAR_STRATA    = "FULLSCREEN_DIALOG",
  LEFTBAR_LEVEL_BONUS = 3000,

  -- Escalas
  SCALE_SOCIAL_SIDEBAR = 1.30,
  SCALE_SOCIAL_DEFAULT = 1.15,
  SCALE_CHATMENU    = 1.5,   -- ChatFrameMenuButton (rodapé)  <-- maior

    -- Gap "entre janelas" (stack vertical)
  DOCK_STACK_GAP = 16,       -- <--- ajuste aqui se quiser mais/menos espaço
  -- Fudge extra para considerar abas inferiores que não contam no GetHeight()
  DOCK_TAB_FUDGE = 20,       -- <--- aumente se as abas ainda estiverem tocando
  -- Gap lateral quando as janelas ficam fora do painel (modo "fora")
  CHARFRAME_GAP = 12,        -- já era usado no layout
  -- Se true, ancora dentro do painel; se false, ancora fora na direita
  CHARFRAME_INSIDE = false,
}

 end
-- END 05_config.lua
