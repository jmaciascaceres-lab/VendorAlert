-- VendorAlert: registro de gastos en reparaciones e ingresos por ventas
-- Guarda totales por día (por personaje) para calcular semana, mes y total.
local ADDON_NAME, ns = ...
local T = CreateFrame("Frame")
local L = ns.L
local S -- ns.CharDB.stats

local KEEP_DAYS = 70 -- días de historial diario que se conservan
local merchantOpen = false
local lastMoney, lastRepairCost = 0, 0

----------------------------------------------------------------------
-- Datos
----------------------------------------------------------------------
local function Today() return date("%Y-%m-%d") end

local function DayTime(key)
    local y, m, d = key:match("^(%d+)-(%d+)-(%d+)$")
    if not y then return end
    return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
end

local function Prune()
    local limit = time() - KEEP_DAYS * 86400
    for key in pairs(S.days) do
        local t = DayTime(key)
        if not t or t < limit then S.days[key] = nil end
    end
end

local function Add(kind, amount)
    if not S or not amount or amount <= 0 then return end
    local key = Today()
    local day = S.days[key]
    if not day then
        day = { repair = 0, sales = 0 }
        S.days[key] = day
    end
    day[kind] = day[kind] + amount
    S.total[kind] = S.total[kind] + amount
    if ns.RefreshStats then ns.RefreshStats() end
end

-- Devuelve { week = {repair, sales}, month = {...}, total = {...} }
function ns.GetStats()
    local now = date("*t")
    local sinceMonday = (now.wday + 5) % 7 -- wday: 1 = domingo
    local weekStart = time({ year = now.year, month = now.month, day = now.day - sinceMonday, hour = 0 })

    local week, month = { repair = 0, sales = 0 }, { repair = 0, sales = 0 }
    for key, v in pairs(S and S.days or {}) do
        local t = DayTime(key)
        if t then
            if t >= weekStart then
                week.repair, week.sales = week.repair + v.repair, week.sales + v.sales
            end
            local d = date("*t", t)
            if d.year == now.year and d.month == now.month then
                month.repair, month.sales = month.repair + v.repair, month.sales + v.sales
            end
        end
    end
    local total = S and S.total or { repair = 0, sales = 0 }
    return { week = week, month = month, total = { repair = total.repair, sales = total.sales } }
end

function ns.PrintStats()
    local st = ns.GetStats()
    local function line(name, v)
        ns.Print(L.STATS_LINE:format(name, ns.Money(v.repair), ns.Money(v.sales)))
    end
    line(L.WEEK, st.week)
    line(L.MONTH, st.month)
    line(L.TOTAL, st.total)
end

function ns.ResetStats()
    StaticPopupDialogs["VENDORALERT_RESET_STATS"].text = L.RESET_CONFIRM
    StaticPopup_Show("VENDORALERT_RESET_STATS")
end

StaticPopupDialogs["VENDORALERT_RESET_STATS"] = {
    text = "",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function()
        wipe(S.days)
        S.total.repair, S.total.sales = 0, 0
        ns.Print(L.STATS_CLEARED)
        if ns.RefreshStats then ns.RefreshStats() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

----------------------------------------------------------------------
-- Detección
----------------------------------------------------------------------
local function RepairCost()
    if not CanMerchantRepair() then return 0 end
    return GetRepairAllCost() or 0
end

-- Si el coste de reparación bajó, esa diferencia es lo que se pagó
local function CheckRepair()
    local cost = RepairCost()
    if cost < lastRepairCost then Add("repair", lastRepairCost - cost) end
    lastRepairCost = cost
end

-- El núcleo la llama al abrir un vendedor, antes de reparar automáticamente
function ns.OnMerchantShow()
    merchantOpen = true
    lastMoney = GetMoney()
    lastRepairCost = RepairCost()
end

T:SetScript("OnEvent", function(_, event)
    if not merchantOpen then return end
    if event == "PLAYER_MONEY" then
        local money = GetMoney()
        local delta = money - lastMoney
        lastMoney = money
        if delta > 0 then Add("sales", delta) end -- los pagos (compras, reparaciones) son negativos
        CheckRepair()
    elseif event == "UPDATE_INVENTORY_DURABILITY" or event == "MERCHANT_UPDATE" then
        CheckRepair()
    elseif event == "MERCHANT_CLOSED" then
        CheckRepair()
        merchantOpen = false
    end
end)

for _, e in ipairs({ "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY", "MERCHANT_UPDATE", "MERCHANT_CLOSED" }) do
    T:RegisterEvent(e)
end

table.insert(ns.onLoad, function()
    local C = ns.CharDB
    C.stats = C.stats or {}
    S = C.stats
    S.days = S.days or {}
    S.total = S.total or { repair = 0, sales = 0 }
    Prune()
end)
