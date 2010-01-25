NeedyGreedy = LibStub("AceAddon-3.0"):NewAddon("NeedyGreedy", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("NeedyGreedy", {
    type = "launcher",
    label = "Needy Greedy",
    icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
    OnClick = function(frame, button)
        local detached = NeedyGreedy.db.profile.detachedTooltip
        if button == "RightButton" then
            InterfaceOptionsFrame_OpenToCategory("NeedyGreedy")
        elseif detached then
            NeedyGreedy:ToggleDisplay()
        end
    end,
    OnEnter = function(frame)
        if not NeedyGreedy.db.profile.detachedTooltip then
            NeedyGreedy:ShowReportFrame(frame)
        else
            NeedyGreedy:ShowInfoTooltip(frame)
        end
    end,
    OnLeave = function()
        if not NeedyGreedy.db.profile.detachedTooltip then
            NeedyGreedy:HideReportFrame()
        else
            NeedyGreedy:HideInfoTooltip(frame)
        end
    end,
})

local report = {}
local items = {}

local options = {
    name = "NeedyGreedy",
    desc = "Displays a table of items and the roll choices players have made on them",
    handler = NeedyGreedy,
    type = "group",
    args = {
        nItems = {
            name = "Display Items",
            desc = "Number of item columns in the display window",
            type = "range",
            min = 1,
            max = 10,
            step = 1,
            get = "GetNItems",
            set = "SetNItems"
        },
        expiry = {
            name = "Expiry Time",
            desc = "Minutes after item is received before it is removed from display (0 = forever)",
            type = "range",
            min = 0,
            max = 60,
            step = 1,
            get = "GetExpiry",
            set = "SetExpiry"
        },
        quality = {
            name = "Minimum Quality",
            desc = "Minimum quality of item to be displayed",
            type = "select",
            values = {
                [ITEM_QUALITY_UNCOMMON] = ITEM_QUALITY2_DESC,
                [ITEM_QUALITY_RARE] = ITEM_QUALITY3_DESC,
                [ITEM_QUALITY_EPIC] = ITEM_QUALITY4_DESC
            },
            style = "dropdown",
            get = "GetQuality",
            set = "SetQuality"
        },
        displayIcons = {
            name = "Display Icons",
            desc = "Display icons for rolls types instead of text strings",
            type = "toggle",
            get = "GetDisplayIcons",
            set = "SetDisplayIcons",
        },
        detachedTooltip = {
            name = "Detach Tooltip",
            desc = "Display the roll information in a standalone window",
            type = "toggle",
            get = "GetDetachedTooltip",
            set = "SetDetachedTooltip",
        },
        displayTextLink = {
            name = "Display Item Names",
            desc = "Show the item names as a header",
            type = "toggle",
            get = "GetDisplayTextLink",
            set = "SetDisplayTextLink",
        },
    }
}

local defaults = {
    profile = {
        nItems = 2,
        expiry = 5,
        quality = ITEM_QUALITY_EPIC,
        displayIcons = true,
        detachedTooltip = false,
        displayTextLink = false,
    }
}

local iconSize = 27
local NEEDYGREEDY_CHOICE = {
    ["need"] = {
        ["string"] = "|c00FF0000" .. NEED .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-Dice-Up:" .. iconSize .. "|t",
    },
    ["greed"] = {
        ["string"] = "|c0000FF00" .. GREED .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-Coin-Up:" .. iconSize .. "|t",
    },
    ["pass"] = {
        ["string"] = "|c00CCCCCC" .. PASS .. "|r",
        ["icon"] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:16|t",
    },
    ["disenchant"] = {
        ["string"] = "|c00FF00FF" .. ROLL_DISENCHANT .. "|r",
        ["icon"] = "|TInterface\\Buttons\\UI-GroupLoot-DE-Up:" .. iconSize .. "|t",
    }
}

-- Funky colors for text strings
local yC = "|cffFFCC00" -- Golden
local eC = "|cffEDA55F" -- Orange
local gC = "|cff00FF00" -- Green

function NeedyGreedy:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("NeedyGreedyDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshTooltip")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshTooltip")
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("NeedyGreedy", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("NeedyGreedy")
    self:RegisterChatCommand("ngt", "TestItemList")
    self:RegisterChatCommand("needygreedy", function() InterfaceOptionsFrame_OpenToCategory("NeedyGreedy") end)
end

function NeedyGreedy:OnEnable()
    self:RegisterEvent("PARTY_MEMBERS_CHANGED")
    self:RegisterEvent("START_LOOT_ROLL")
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:ScheduleRepeatingTimer("ExpireItems", 1)
end

function NeedyGreedy:OnDisable()
    if self.tooltip then
        self:HideReportFrame()
    end
end

function NeedyGreedy:ToggleDisplay()
    if self.tooltip then
        self:HideReportFrame()
    else
        self:ShowReportFrame()
    end
end

function NeedyGreedy:PARTY_MEMBERS_CHANGED()
    if self.tooltip then
        self:RefreshTooltip()
    end
end



-- Chat scanning and loot recording
function NeedyGreedy:START_LOOT_ROLL(event, rollid)
    local texture, name, count, quality = GetLootRollItemInfo(rollid)
    local link = GetLootRollItemLink(rollid)
    if quality >= self.db.profile.quality then
        items[rollid] = {
            texture = texture,
            link = link,
            assigned = "",
            received = 0,
            choices = {},
            rolls = {}
        }
        self:UpdateReport()
    end
end

function NeedyGreedy:CHAT_MSG_LOOT(event, msg)
    local me = UnitName("player")
    local player, link, number

    link = self:unformat(LOOT_ROLL_YOU_WON, msg)
    if link then
        self:RecordAwarded(link, me)
        return
    end

    player, link = self:unformat(LOOT_ROLL_WON, msg)
    if player then
        self:RecordAwarded(link, player)
        return
    end

    link = self:unformat(LOOT_ROLL_ALL_PASSED, msg)
    if link then
        self:RecordAwarded(link, "---")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED_AUTO, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED_AUTO_FEMALE, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    link = self:unformat(LOOT_ROLL_NEED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "need")
        return
    end

    link = self:unformat(LOOT_ROLL_GREED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "greed")
        return
    end

    link = self:unformat(LOOT_ROLL_PASSED_SELF, msg)
    if link then
        self:RecordChoice(link, me, "pass")
        return
    end

    link = self:unformat(LOOT_ROLL_PASSED_SELF_AUTO, msg)
    if link then
        self:RecordChoice(link, me, "pass")
        return
    end

    player, link = self:unformat(LOOT_ROLL_NEED, msg)
    if player then
        self:RecordChoice(link, player, "need")
        return
    end

    player, link = self:unformat(LOOT_ROLL_GREED, msg)
    if player then
        self:RecordChoice(link, player, "greed")
        return
    end

    player, link = self:unformat(LOOT_ROLL_PASSED, msg)
    if player then
        self:RecordChoice(link, player, "pass")
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_NEED, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_GREED, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end

    link = self:unformat(LOOT_ITEM_PUSHED_SELF, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    link, number = self:unformat(LOOT_ITEM_PUSHED_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    link = self:unformat(LOOT_ITEM_SELF, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    link, number = self:unformat(LOOT_ITEM_SELF_MULTIPLE, msg)
    if link then
        self:RecordReceived(link, me)
        return
    end

    player, link = self:unformat(LOOT_ITEM, msg)
    if player then
        self:RecordReceived(link, player)
        return
    end

    player, link, number = self:unformat(LOOT_ITEM_MULTIPLE, msg)
    if player then
        self:RecordReceived(link, player)
        return
    end

    -- To handle new disenchant rules
    link = self:unformat(LOOT_ROLL_DISENCHANT_SELF, msg)
    if link then
        self:RecordChoice(link, me, "disenchant")
        return
    end

    player, link = self:unformat(LOOT_ROLL_DISENCHANT, msg)
    if link then
        self:RecordChoice(link, player, "disenchant")
        return
    end

    player, link = self:unformat(LOOT_ROLL_DISENCHANT, msg)
    if link then
        self:RecordChoice(link, player, "disenchant")
        return
    end

    number, link, player = self:unformat(LOOT_ROLL_ROLLED_DE, msg)
    if number then
        self:RecordRoll(link, player, number)
        return
    end
end

function NeedyGreedy:RecordChoice(link, player, choice)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.choices[player] = choice
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordRoll(link, player, number)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.rolls[player] = number
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordAwarded(link, player)
    for rollid, record in pairs(items) do
        if record.assigned == "" and record.link == link then
            record.assigned = player
            break
        end
    end
    self:UpdateReport()
end

function NeedyGreedy:RecordReceived(link, player)
    for rollid, record in pairs(items) do
        if record.received == 0 and record.link == link then
            record.received = GetTime()
            break
        end
        -- Since players receive disenchanted items not link
        if record.choices[player] == "disenchant" and record.assigned == player and record.received == 0 then
            record.received = GetTime()
        end
    end
    self:UpdateReport()
end



-- Tooltip Information Formatting
function NeedyGreedy:PageLeft()
    report.firstItem = report.firstItem - self.db.profile.nItems
    if report.firstItem < 1 then
        report.firstItem = 1
    end
    self:UpdateReport()
end

function NeedyGreedy:PageRight()
    local count = NeedyGreedy:CountItems()
    report.firstItem = report.firstItem + self.db.profile.nItems
    if count == 0 then
        report.firstItem = 1
    elseif report.firstItem > count then
        report.firstItem = count
    end
    self:UpdateReport()
end

function NeedyGreedy:GetSortedPlayers()
    local list = {}

    if GetNumRaidMembers() > 0 then
        for i = 1,MAX_RAID_MEMBERS do
            name = GetRaidRosterInfo(i)
            if name then
                table.insert(list, name)
            end
        end
    else
        for _, unit in ipairs({"player", "party1", "party2", "party3", "party4"}) do
            local name = UnitName(unit)
            if name then
                table.insert(list, name)
            end
        end
    end
    table.sort(list)
    return list
end

function NeedyGreedy:GetNumPlayers()
    local nraid = GetNumRaidMembers()
    if nraid > 0 then
        return nraid
    else
        return GetNumPartyMembers() + 1
    end
end

function NeedyGreedy:ColorizeName(name)
    -- Derived by hand from RAID_CLASS_COLORS because deriving it in lua seemed tricky
    -- Might not be that hard: str_format("%02x%02x%02x", r * 255, g * 255, b * 255)
    local map = {
        HUNTER = "|c00ABD473",
        WARLOCK = "|c009482C9",
        PRIEST = "|c00FFFFFF",
        PALADIN = "|c00F58CBA",
        MAGE = "|c0069CCF0",
        ROGUE = "|c00FFF569",
        DRUID = "|c00FF7D0A",
        SHAMAN = "|c002459FF",
        WARRIOR = "|c00C79C6E",
        DEATHKNIGHT = "|c00C41F3A"
    }
    local _, class = UnitClass(name)
    local color

    if class then
        color = map[class]
    end
    if not color then
        color = GRAY_FONT_COLOR_CODE
    end
    return color .. name .. "|r"
end

function NeedyGreedy:ChoiceText(choice)
    local style = "string"
    if self.db.profile.displayIcons == true then style = "icon" end

    if choice then
          if NEEDYGREEDY_CHOICE[choice][style] then
              return NEEDYGREEDY_CHOICE[choice][style]
          end
    end
    return ""
end

function NeedyGreedy:RollText(number)
    if number then
        return " " .. number
    else
        return ""
    end
end

function NeedyGreedy:AssignedText(item)
    if item.received == 0 then
        return "|c00FF0000" .. item.assigned .. "|r"
    else
        return "|c0000FF00" .. item.assigned .. "|r"
    end
end

-- Return a list of rollids ordered from most recent to least recent
function NeedyGreedy:SortRollids()
    local rollids = {}
    for rollid, _ in pairs(items) do
        table.insert(rollids, rollid)
    end
    table.sort(rollids, function(a, b) return a > b end)
    return rollids
end

function NeedyGreedy:CountItems()
    local i = 0
    for _, _ in pairs(items) do
        i = i + 1
    end
    return i
end

function NeedyGreedy:ExpireItems()
    local now = GetTime()
    local update = false

    if self.db.profile.expiry == 0 then
        return
    end
    for rollid, record in pairs(items) do
        if record.received > 0 and now - record.received >= self.db.profile.expiry * 60 then
            items[rollid] = nil
            update = true
        end
    end
    if update then
        self:UpdateReport()
    end
end

function NeedyGreedy:unformat(fmt, msg)
    local pattern = string.gsub(string.gsub(fmt, "(%%s)", "(.+)"), "(%%d)", "(.+)")
    local _, _, a1, a2, a3, a4 = string.find(msg, pattern)
    return a1, a2, a3, a4
end



-- Config option getters and setters
function NeedyGreedy:GetNItems(info)
    return self.db.profile.nItems
end

function NeedyGreedy:SetNItems(info, nItems)
    self.db.profile.nItems = nItems
    self:RefreshTooltip()
end

function NeedyGreedy:GetExpiry(info)
    return self.db.profile.expiry
end

function NeedyGreedy:SetExpiry(info, expiry)
    self.db.profile.expiry = expiry
    self:ExpireItems()
end

function NeedyGreedy:GetQuality(info)
    return self.db.profile.quality
end

function NeedyGreedy:SetQuality(info, quality)
    self.db.profile.quality = quality
end

function NeedyGreedy:GetDisplayIcons(info)
    return self.db.profile.displayIcons
end

function NeedyGreedy:SetDisplayIcons(info, displayIcons)
    self.db.profile.displayIcons = displayIcons
    self:UpdateReport()
end

function NeedyGreedy:GetDetachedTooltip(info)
    return self.db.profile.detachedTooltip
end

function NeedyGreedy:SetDetachedTooltip(info, detachedTooltip)
    self.db.profile.detachedTooltip = detachedTooltip
    if detachedTooltip then
        self:ShowReportFrame()
    else
        self:HideReportFrame()
        -- Return to page one
        report.firstItem = 1
    end
end

function NeedyGreedy:GetDisplayTextLink(info)
    return self.db.profile.displayTextLink
end

function NeedyGreedy:SetDisplayTextLink(info, displayTextLink)
    self.db.profile.displayTextLink = displayTextLink
    self:UpdateReport()
end



-- Detachable QTip Frames
local LibQTip = LibStub('LibQTip-1.0')

function NeedyGreedy:ShowReportFrame(frame)
    -- Acquire a tooltip
    self.tooltip = LibQTip:Acquire("NeedyGreedyReport", 1, "LEFT")

    -- Add columns here because tooltip:Clear() preserves columns
    for i = 1, self.db.profile.nItems do
        self.tooltip:AddColumn("LEFT")
    end

    -- Add two columns for left and right buttons if detached
    if self.db.profile.detachedTooltip then
        self.tooltip:AddColumn("RIGHT")
        self.tooltip:AddColumn("LEFT")
    end

    -- Fill in the info
    self:PopulateReportTooltip()

    if self.db.profile.detachedTooltip then
        -- To make tooltip detached
        self.tooltip:ClearAllPoints()
        self.tooltip:SetFrameStrata("FULLSCREEN")
        self.tooltip:EnableMouse(true)
        self.tooltip:SetResizable(true)
        self.tooltip:SetFrameLevel(1)
        self.tooltip:SetMovable(true)
        self.tooltip:SetClampedToScreen(true)

        if not self.db.profile.reportFramePos then
            self.db.profile.reportFramePos = {
                anchor1 = "CENTER",
                anchor2 = "CENTER",
                x = 0,
                y = 0
            }
        end
        self.tooltip:SetPoint(self.db.profile.reportFramePos.anchor1, nil, self.db.profile.reportFramePos.anchor2,
            self.db.profile.reportFramePos.x, self.db.profile.reportFramePos.y)

        -- Make it move !
        self.tooltip:SetScript("OnMouseDown", function() self.tooltip:StartMoving() end)
        self.tooltip:SetScript("OnMouseUp", function()
            -- Make it remember
            self.tooltip:StopMovingOrSizing()
            local anchor1, _, anchor2, x, y = self.tooltip:GetPoint()
            self.db.profile.reportFramePos.anchor1 = anchor1
            self.db.profile.reportFramePos.anchor2 = anchor2
            self.db.profile.reportFramePos.x = x
            self.db.profile.reportFramePos.y = y
        end)

    else
        if frame then self.tooltip:SmartAnchorTo(frame) end
    end

    -- Show it, et voilà !
    self.tooltip:Show()
end

function NeedyGreedy:HideReportFrame()
    if self.tooltip then
        self.tooltip:Hide()
        LibQTip:Release(self.tooltip)
        self.tooltip = nil
    end
end

function NeedyGreedy:PopulateReportTooltip()
    local nItems = self.db.profile.nItems
    local players = self:GetSortedPlayers()
    self.tooltip:Clear()

    self:AddHeaderText(self.tooltip)

    -- Verify that report.firstItem is set reasonably
    local sorted = self:SortRollids()
    local count = self:CountItems()

    if not(report.firstItem) then report.firstItem = 1 end
    if count == 0 then
        report.firstItem = 1
    elseif report.firstItem > count then
        report.firstItem = count
    end

    -- Create icon headers
    local headerline, _ = self.tooltip:AddLine("")
    for i = 1, nItems do
        local index = report.firstItem + i - 1
        local texture = ""
        local item = nil
        if index <= count then
            local rollID = sorted[index]
            item = items[rollID]
            texture = "|T" .. item.texture .. ":40|t"
        end
        self.tooltip:SetCell(headerline, i + 1, texture, nil, "CENTER", nil, nil, nil, nil, nil, 60)
        if item then
            self.tooltip:SetCellScript(headerline, i + 1, "OnEnter", function()
                GameTooltip:SetOwner(self.tooltip, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.link)
            end )
            self.tooltip:SetCellScript(headerline, i + 1, "OnLeave", function()
                GameTooltip:Hide()
            end )
        end
    end

    -- Now add item link names
    if self.db.profile.displayTextLink then
        headerline, _ = self.tooltip:AddLine("")
        for i = 1, nItems do
            local index = report.firstItem + i - 1
            local text = ""
            local item = nil
            if index <= count then
                local rollID = sorted[index]
                item = items[rollID]
                text= item.link
            end
            self.tooltip:SetCell(headerline, i + 1, text, nil, nil, nil, nil, nil, nil, nil, 60)
            if item then
                self.tooltip:SetCellScript(headerline, i + 1, "OnEnter", function()
                    GameTooltip:SetOwner(self.tooltip, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(item.link)
                end )
                self.tooltip:SetCellScript(headerline, i + 1, "OnLeave", function()
                    GameTooltip:Hide()
                end )
            end
        end
    end

    -- Create table with party names and their rolls
    for i, name in ipairs(players) do
        local rollTable = {}
        table.insert(rollTable, self:ColorizeName(name))

        for i = 1, nItems do
            local index = report.firstItem + i - 1
            if index <= count then
                local rollID = sorted[index]
                local item = items[rollID]
                table.insert(rollTable, self:ChoiceText(item.choices[name]) .. self:RollText(item.rolls[name]))
            end
        end

        self.tooltip:AddLine(unpack(rollTable))
    end

    self.tooltip:AddSeparator()

    -- Display winner
    local winnerTable = {yC .. "Winner|r"}
    for i = 1, nItems do
        local index = report.firstItem + i - 1
        if index <= count then
            local rollID = sorted[index]
            local item = items[rollID]
            table.insert(winnerTable, self:AssignedText(item))
        end
    end
    self.tooltip:AddLine(unpack(winnerTable))

    -- Display left and right arrows if frame is detached
    if self.db.profile.detachedTooltip then
        self:AddPagerArrows(self.tooltip)
    else
        self:AddInfoText(self.tooltip)
    end
end

function NeedyGreedy:AddHeaderText(tooltip)
    tooltip:AddHeader(yC .. "NeedyGreedy|r")
    tooltip:AddLine("")
end

function NeedyGreedy:AddPagerArrows(tooltip)
    local nItems = self.db.profile.nItems
    local count = self:CountItems()

    local lineNum, _ = tooltip:AddLine("")
    local colNum = nItems + 2

    if report.firstItem > 1 then
        tooltip:SetCell(lineNum, colNum, "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Up:" .. iconSize .. "|t")
        tooltip:SetCellScript(lineNum, colNum, "OnMouseUp", function() self:PageLeft() end)
    else
        tooltip:SetCell(lineNum, colNum, "|TInterface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled:" .. iconSize .. "|t")
    end

    if report.firstItem + nItems - 1 < count then
        tooltip:SetCell(lineNum, colNum + 1, "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Up:" .. iconSize .. "|t")
        tooltip:SetCellScript(lineNum, colNum + 1, "OnMouseUp", function() self:PageRight() end)
    else
        tooltip:SetCell(lineNum, colNum + 1, "|TInterface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled:" .. iconSize .. "|t")
    end

    -- Set the page # text
    local pageText = ""
    if nItems == 1 then
        pageText = tostring(report.firstItem)
    elseif count == 0 then
        pageText = "None"
    elseif count == 1 or report.firstItem == count then
        pageText = string.format("%d of %d", report.firstItem, count)
    else
        local lastitem = report.firstItem + nItems - 1
        if (lastitem > count) then
            lastitem = count
        end
        pageText = string.format("%d-%d of %d", report.firstItem, lastitem, count)
    end

    tooltip:SetCell(lineNum, colNum - 1, yC .. pageText)
end

function NeedyGreedy:AddInfoText(tooltip)
    local helpText = ""
    if self.db.profile.detachedTooltip then
        helpText = helpText .. eC .. "Click|r " .. gC .. "to hide/show detached tooltip\n|r"
    end
    helpText = helpText .. eC .. "Right-Click|r " .. gC .. "to open configuration menu|r"
    tooltip:AddLine("")
    local lineNum = tooltip:AddLine()
    tooltip:SetCell(lineNum, 1, helpText, nil, tooltip:GetColumnCount())
end

function NeedyGreedy:UpdateReport()
    if self.tooltip and self.tooltip:IsShown() then
        self:PopulateReportTooltip()
    end
end

function NeedyGreedy:RefreshTooltip()
    if self.tooltip then
        self:HideReportFrame()
        self:ShowReportFrame()
    end
end

function NeedyGreedy:ShowInfoTooltip(frame)
    -- Acquire a tooltip
    self.infoTooltip = LibQTip:Acquire("NeedyGreedyInfo", 1, "LEFT")

    -- Fill in the info
    self:AddHeaderText(self.infoTooltip)
    self:AddInfoText(self.infoTooltip)

    self.infoTooltip:SmartAnchorTo(frame)

    -- Show it, et voilà !
    self.infoTooltip:Show()
end

function NeedyGreedy:HideInfoTooltip()
    if self.infoTooltip then
        self.infoTooltip:Hide()
        LibQTip:Release(self.infoTooltip)
        self.infoTooltip = nil
    end
end


-- Unit tests
function NeedyGreedy:TestItemList()
    items[1] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_04",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "",
        received = 0,
        choices = {},
        rolls = {}
    }
    items[2] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_05",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "",
        received = 0,
        choices = {Matsuri = "disenchant", Lubov = "greed"},
        rolls = {Matsuri = "- 61", Lubov = "- 98"}
    }
    items[3] = {
        texture = "Interface\\Icons\\INV_Weapon_ShortBlade_06",
        link = "|cff0070dd|Hitem:2169:0:0:0:0:0:0:1016630800:80|h[Buzzer Blade]|h|r",
        assigned = "Matsuri",
        received = GetTime(),
        choices = {Shalii = "pass", Matsuri = "need"},
        rolls = {Shalii = "", Matsuri = " - 42"}
    }
    self:UpdateReport()
end
