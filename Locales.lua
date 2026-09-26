-- VendorAlert: traducciones / translations
-- Para añadir un idioma: copia el bloque "en", tradúcelo y añádelo a LANGS.
-- To add a language: copy the "en" block, translate it and add it to LANGS.
local ADDON_NAME, ns = ...

local strings = {}

strings.en = {
    -- Alerts
    VENDOR_NEAR     = "Vendor nearby: %s!",
    REASON_BAGS     = "bags at %d%%",
    REASON_DUR      = "durability at %d%% (repairs here)",
    LOW_DUR         = "Low durability! Your gear is at %d%%",
    TEST_NAME       = "Test",
    -- Vendor actions
    REPAIRED        = "gear repaired for %s",
    NO_GOLD         = "not enough gold to repair (%s)",
    SOLD            = "%d grey items sold for %s",
    LEARNED         = "vendor learned: %s",
    LEARNED_REPAIR  = " (repairs)",
    -- Commands
    ON              = "on",
    OFF             = "off",
    SET_THRESHOLD   = "bag alert at %d%%",
    SET_DUR         = "durability warning below %d%%",
    SET_SELL        = "auto-sell greys %s",
    SET_REPAIR      = "auto-repair %s",
    SET_SOUND       = "sound %s",
    SET_TONE        = "custom sound %s (file: Sounds\\alert.mp3 or alert.ogg)",
    ICON_HIDDEN     = "minimap icon hidden",
    ICON_SHOWN      = "minimap icon shown",
    VENDORS_CLEARED = "learned vendor list cleared",
    LANG_SET        = "language: English",
    LANG_USAGE      = "usage: /va lang en | es | auto",
    STATUS1         = "bags %d/%d (%d%%) | durability %d%% | %d vendors (%d repair)",
    STATUS2         = "bag threshold %d%% | durability threshold %d%% | sell %s | repair %s | sound %s",
    HELP1           = "commands: /va notes | /va stats | /va resetstats | /va icon | /va lang en|es",
    HELP2           = "/va threshold 80 | /va durability 30 | /va sell | /va repair | /va sound | /va tone | /va test | /va reset",
    -- Stats
    WEEK            = "Week",
    MONTH           = "Month",
    TOTAL           = "Total",
    STATS_LINE      = "%s: repairs %s | sales %s",
    RESET_CONFIRM   = "Clear the repair and sales record for this character?",
    STATS_CLEARED   = "repair and sales record cleared",
    -- Window
    TAB_NOTES       = "Notes",
    TAB_STATS       = "Expenses",
    PLACEHOLDER     = "Write your to-dos here...",
    COL_REPAIRS     = "Repairs",
    COL_SALES       = "Sales",
    COL_BALANCE     = "Balance",
    STATS_INFO      = "Sales: everything you sell to vendors. The week starts on Monday. Data for this character.",
    RESET_BUTTON    = "Reset",
    -- Minimap tooltip
    TT_BAGS         = "Bags",
    TT_DUR          = "Durability",
    TT_WEEK_REPAIRS = "Repairs (week)",
    TT_WEEK_SALES   = "Sales (week)",
    TT_LEFT         = "Left-click: notes",
    TT_RIGHT        = "Right-click: expenses",
    TT_DRAG         = "Drag: move icon",
}

strings.es = {
    -- Alertas
    VENDOR_NEAR     = "¡Vendedor cerca: %s!",
    REASON_BAGS     = "bolsas al %d%%",
    REASON_DUR      = "durabilidad al %d%% (repara aquí)",
    LOW_DUR         = "¡Durabilidad baja! Tu equipo está al %d%%",
    TEST_NAME       = "Prueba",
    -- Acciones en el vendedor
    REPAIRED        = "equipo reparado por %s",
    NO_GOLD         = "no tienes oro suficiente para reparar (%s)",
    SOLD            = "%d objetos grises vendidos por %s",
    LEARNED         = "vendedor aprendido: %s",
    LEARNED_REPAIR  = " (repara)",
    -- Comandos
    ON              = "activado",
    OFF             = "desactivado",
    SET_THRESHOLD   = "alerta de bolsas al %d%%",
    SET_DUR         = "aviso de durabilidad bajo el %d%%",
    SET_SELL        = "vender grises %s",
    SET_REPAIR      = "reparar automáticamente %s",
    SET_SOUND       = "sonido %s",
    SET_TONE        = "sonido personalizado %s (archivo: Sounds\\alerta.mp3 o alerta.ogg)",
    ICON_HIDDEN     = "icono del minimapa oculto",
    ICON_SHOWN      = "icono del minimapa visible",
    VENDORS_CLEARED = "lista de vendedores borrada",
    LANG_SET        = "idioma: español",
    LANG_USAGE      = "uso: /va idioma es | en | auto",
    STATUS1         = "bolsas %d/%d (%d%%) | durabilidad %d%% | %d vendedores (%d reparan)",
    STATUS2         = "umbral bolsas %d%% | umbral durabilidad %d%% | vender %s | reparar %s | sonido %s",
    HELP1           = "comandos: /va notas | /va gastos | /va borrargastos | /va icono | /va idioma es|en",
    HELP2           = "/va umbral 80 | /va durabilidad 30 | /va vender | /va reparar | /va sonido | /va tono | /va prueba | /va reset",
    -- Gastos
    WEEK            = "Semana",
    MONTH           = "Mes",
    TOTAL           = "Total",
    STATS_LINE      = "%s: reparaciones %s | ventas %s",
    RESET_CONFIRM   = "¿Borrar el registro de reparaciones y ventas de este personaje?",
    STATS_CLEARED   = "registro de gastos borrado",
    -- Ventana
    TAB_NOTES       = "Notas",
    TAB_STATS       = "Gastos",
    PLACEHOLDER     = "Escribe aquí tus pendientes...",
    COL_REPAIRS     = "Reparaciones",
    COL_SALES       = "Ventas",
    COL_BALANCE     = "Balance",
    STATS_INFO      = "Ventas: todo lo que vendes a vendedores. La semana empieza el lunes. Datos de este personaje.",
    RESET_BUTTON    = "Reiniciar",
    -- Icono del minimapa
    TT_BAGS         = "Bolsas",
    TT_DUR          = "Durabilidad",
    TT_WEEK_REPAIRS = "Reparaciones (semana)",
    TT_WEEK_SALES   = "Ventas (semana)",
    TT_LEFT         = "Clic izquierdo: notas",
    TT_RIGHT        = "Clic derecho: gastos",
    TT_DRAG         = "Arrastrar: mover el icono",
}

ns.LANGS = { en = true, es = true }
ns.lang = "en"

-- ns.L.CLAVE devuelve el texto en el idioma activo (o en inglés si falta)
ns.L = setmetatable({}, {
    __index = function(_, key)
        local active = strings[ns.lang]
        return (active and active[key]) or strings.en[key] or key
    end,
})

-- Idioma según el cliente del juego: español para esES/esMX, inglés para el resto
function ns.DetectLanguage()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "esES" or locale == "esMX" then return "es" end
    return "en"
end

-- setting: "auto", "en" o "es"
function ns.SetLanguage(setting)
    ns.lang = (setting == "auto" or not ns.LANGS[setting]) and ns.DetectLanguage() or setting
    if ns.ApplyLanguage then ns.ApplyLanguage() end
end
