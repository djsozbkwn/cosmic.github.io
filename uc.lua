-- // Universal Chat v4 // --
local SUPABASE_URL = "https://kwlcycmqncfoxeurymlo.supabase.co"
local SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt3bGN5Y21xbmNmb3hldXJ5bWxvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3NjYzOTAsImV4cCI6MjA5MzM0MjM5MH0.d23vzj-OzLUqLVhLdC1pe-AMmBRpqPzczWFFObzc_74"

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")
local HttpService    = game:GetService("HttpService")
local StarterGui     = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Marketplace    = game:GetService("MarketplaceService")

local lp = Players.LocalPlayer

local POLL_RATE    = 2
local NOTIF_RATE   = 3
local MAX_MSGS     = 60
local W, H         = 560, 315
local DEF_CH       = "global"
local CHANNELS     = {"global", "trade", "help"}

local channelCache = {}
local lastMsgId    = {}
local pollConn     = nil
local notifConn    = nil
local currentCh    = DEF_CH
local msgRows      = {}
local tabBtns      = {}
local isDrag       = false
local dragStart, startPos
local isMin        = false
local settingsOpen = false

local httpReq = (syn and syn.request) or (http and http.request) or (request) or
    function(o)
        local ok, r = pcall(function()
            return HttpService:RequestAsync({Url=o.Url,Method=o.Method,Headers=o.Headers,Body=o.Body})
        end)
        return ok and r or nil
    end

local function req(method, path, body)
    local opts = {
        Url    = SUPABASE_URL .. path,
        Method = method,
        Headers = {
            ["Content-Type"]  = "application/json",
            ["apikey"]        = SUPABASE_KEY,
            ["Authorization"] = "Bearer " .. SUPABASE_KEY,
            ["Prefer"]        = "return=representation",
        },
    }
    if body then opts.Body = HttpService:JSONEncode(body) end
    local ok, res = pcall(httpReq, opts)
    if not ok or not res then return nil end
    if type(res) == "table" and res.Body and #res.Body > 2 then
        local ok2, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if ok2 then return d end
    end
    return true
end

local function getChannel(name)
    if channelCache[name] then return channelCache[name] end
    local f = req("GET", "/rest/v1/channels?name=eq."..name.."&select=id")
    if type(f)=="table" and #f>0 then channelCache[name]=f[1].id; return f[1].id end
    req("POST", "/rest/v1/channels", {name=name})
    task.wait(0.4)
    local g = req("GET", "/rest/v1/channels?name=eq."..name.."&select=id")
    if type(g)=="table" and #g>0 then channelCache[name]=g[1].id; return g[1].id end
    return nil
end

-- // UI SETUP // --
local C = {
    BG      = Color3.fromRGB(10, 10, 16),
    PANEL   = Color3.fromRGB(16, 16, 26),
    HEADER  = Color3.fromRGB(14, 14, 22),
    BORDER  = Color3.fromRGB(35, 35, 58),
    ACCENT  = Color3.fromRGB(110, 185, 255),
    ACCENT2 = Color3.fromRGB(255, 135, 80),
    GREEN   = Color3.fromRGB(80, 220, 140),
    TEXT    = Color3.fromRGB(215, 215, 230),
    SUB     = Color3.fromRGB(100, 100, 135),
    INBG    = Color3.fromRGB(20, 20, 32),
    TBON    = Color3.fromRGB(25, 25, 45),
    TBOFF   = Color3.fromRGB(13, 13, 20),
    SYS     = Color3.fromRGB(255, 140, 80),
    RED     = Color3.fromRGB(255, 80, 80),
}

local function cr(inst, r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 6); c.Parent=inst end
local function sk(inst, col, t) local s=Instance.new("UIStroke"); s.Color=col or C.BORDER; s.Thickness=t or 1; s.Parent=inst end

local function f(parent, props)
    local o = Instance.new("Frame")
    o.BorderSizePixel = 0
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent = parent
    return o
end

local function el(cls, parent, props)
    local o = Instance.new(cls)
    if o:IsA("GuiObject") then o.BorderSizePixel=0 end
    if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
        o.BackgroundTransparency=1
    end
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent = parent
    return o
end

local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad), props):Play()
end

local sg = Instance.new("ScreenGui")
sg.Name="UniversalChat"; sg.ResetOnSpawn=false; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
sg.Parent = lp:WaitForChild("PlayerGui")

local main = f(sg, {
    Size=UDim2.new(0,W,0,H), Position=UDim2.new(0.5,-W/2,1,-H-70),
    BackgroundColor3=C.BG,
})
cr(main, 12); sk(main, C.BORDER)

-- shadow
local shad = Instance.new("ImageLabel")
shad.Size=UDim2.new(1,40,1,40); shad.Position=UDim2.new(0,-20,0,-20)
shad.BackgroundTransparency=1; shad.Image="rbxassetid://6014261993"
shad.ImageColor3=Color3.new(0,0,0); shad.ImageTransparency=0.65
shad.ScaleType=Enum.ScaleType.Slice; shad.SliceCenter=Rect.new(49,49,450,450)
shad.ZIndex=0; shad.Parent=main

-- HEADER
local hdr = f(main, {Size=UDim2.new(1,0,0,38), BackgroundColor3=C.HEADER, ZIndex=4})
cr(hdr, 12)
f(hdr, {Size=UDim2.new(1,0,0,12), Position=UDim2.new(0,0,1,-12), BackgroundColor3=C.HEADER, ZIndex=4})
sk(hdr, C.BORDER)

local function macDot(x, col)
    local d=f(hdr,{Size=UDim2.new(0,9,0,9),Position=UDim2.new(0,x,0.5,-4.5),BackgroundColor3=col,ZIndex=5})
    cr(d,5)
end
macDot(12, Color3.fromRGB(255,95,87))
macDot(26, Color3.fromRGB(255,189,46))
macDot(40, Color3.fromRGB(40,200,64))

local hdrLbl = el("TextLabel", hdr, {
    Size=UDim2.new(1,0,1,0),
    Text="â—ˆ  UNIVERSAL CHAT  Â·  #"..DEF_CH:upper(),
    TextColor3=C.ACCENT, TextSize=12, Font=Enum.Font.GothamBold,
    TextXAlignment=Enum.TextXAlignment.Center, ZIndex=5,
})

local minBtn = el("TextButton", hdr, {
    Size=UDim2.new(0,24,0,20), Position=UDim2.new(1,-28,0.5,-10),
    BackgroundColor3=C.TBON, BackgroundTransparency=0,
    Text="â€”", TextColor3=C.SUB, TextSize=10, Font=Enum.Font.GothamBold, ZIndex=6,
})
cr(minBtn,4)

-- TABS
local tabBar = f(main, {
    Size=UDim2.new(1,0,0,28), Position=UDim2.new(0,0,0,38),
    BackgroundColor3=C.PANEL,
})
do
    local l=Instance.new("UIListLayout"); l.FillDirection=Enum.FillDirection.Horizontal
    l.SortOrder=Enum.SortOrder.LayoutOrder; l.Padding=UDim.new(0,3); l.Parent=tabBar
    local p=Instance.new("UIPadding"); p.PaddingLeft=UDim.new(0,6)
    p.PaddingTop=UDim.new(0,4); p.PaddingBottom=UDim.new(0,4); p.Parent=tabBar
end

-- CHAT AREA
local chatWrap = f(main, {
    Size=UDim2.new(1,0,1,-110), Position=UDim2.new(0,0,0,66),
    BackgroundColor3=C.BG, ClipsDescendants=true,
})

local scroll = Instance.new("ScrollingFrame")
scroll.Size=UDim2.new(1,-4,1,-4); scroll.Position=UDim2.new(0,2,0,2)
scroll.BackgroundTransparency=1; scroll.ScrollBarThickness=2
scroll.ScrollBarImageColor3=C.ACCENT
scroll.CanvasSize=UDim2.new(0,0,0,0); scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
scroll.ScrollingDirection=Enum.ScrollingDirection.Y; scroll.Parent=chatWrap
do
    local l=Instance.new("UIListLayout"); l.SortOrder=Enum.SortOrder.LayoutOrder
    l.Padding=UDim.new(0,0); l.Parent=scroll
    local p=Instance.new("UIPadding"); p.PaddingLeft=UDim.new(0,10); p.PaddingRight=UDim.new(0,10)
    p.PaddingTop=UDim.new(0,6); p.PaddingBottom=UDim.new(0,6); p.Parent=scroll
end

-- DIVIDER
f(main, {Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-44), BackgroundColor3=C.BORDER})

-- INPUT AREA
local inputArea = f(main, {
    Size=UDim2.new(1,0,0,44), Position=UDim2.new(0,0,1,-44),
    BackgroundColor3=C.PANEL,
})
cr(inputArea, 12)
f(inputArea, {Size=UDim2.new(1,0,0,12), BackgroundColor3=C.PANEL})

local inputWrap = f(inputArea, {
    Size=UDim2.new(1,-12,0,28), Position=UDim2.new(0,6,0,9),
    BackgroundColor3=C.INBG,
})
cr(inputWrap, 6); sk(inputWrap, C.BORDER)

local inputBox = el("TextBox", inputWrap, {
    Size=UDim2.new(1,-120,1,0), Position=UDim2.new(0,10,0,0),
    BackgroundColor3=C.INBG, BackgroundTransparency=0,
    Text="", PlaceholderText="Message #"..DEF_CH.."...",
    TextColor3=C.TEXT, PlaceholderColor3=C.SUB,
    TextSize=12, Font=Enum.Font.Gotham,
    TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false,
})

local settBtn = el("TextButton", inputWrap, {
    Size=UDim2.new(0,26,0,20), Position=UDim2.new(1,-92,0.5,-10),
    BackgroundColor3=C.TBON, BackgroundTransparency=0,
    Text="âš™", TextColor3=C.SUB, TextSize=13, Font=Enum.Font.GothamBold,
})
cr(settBtn, 5)

local sendBtn = el("TextButton", inputWrap, {
    Size=UDim2.new(0,56,0,20), Position=UDim2.new(1,-60,0.5,-10),
    BackgroundColor3=C.ACCENT, BackgroundTransparency=0,
    Text="SEND", TextColor3=Color3.fromRGB(8,8,18),
    TextSize=11, Font=Enum.Font.GothamBold,
})
cr(sendBtn, 5)

-- // SETTINGS PANEL // --
local settPanel = f(main, {
    Size=UDim2.new(0,220,0,0), Position=UDim2.new(1,-226,1,-50),
    BackgroundColor3=C.PANEL, ClipsDescendants=true, ZIndex=20, Visible=false,
})
cr(settPanel, 8); sk(settPanel, C.BORDER)

local settLayout = Instance.new("UIListLayout")
settLayout.SortOrder=Enum.SortOrder.LayoutOrder; settLayout.Padding=UDim.new(0,1)
settLayout.Parent=settPanel
local settPad = Instance.new("UIPadding")
settPad.PaddingLeft=UDim.new(0,8); settPad.PaddingRight=UDim.new(0,8)
settPad.PaddingTop=UDim.new(0,8); settPad.PaddingBottom=UDim.new(0,8)
settPad.Parent=settPanel

local function settTitle(txt)
    el("TextLabel", settPanel, {
        Size=UDim2.new(1,0,0,16), BackgroundTransparency=1,
        Text=txt, TextColor3=C.SUB, TextSize=9, Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left, ZIndex=21,
    })
end

local function settInput(ph)
    local wrap = f(settPanel, {
        Size=UDim2.new(1,0,0,26), BackgroundColor3=C.INBG, ZIndex=21,
    })
    cr(wrap, 5); sk(wrap, C.BORDER)
    local tb = el("TextBox", wrap, {
        Size=UDim2.new(1,-8,1,0), Position=UDim2.new(0,6,0,0),
        BackgroundColor3=C.INBG, BackgroundTransparency=0,
        Text="", PlaceholderText=ph, TextColor3=C.TEXT, PlaceholderColor3=C.SUB,
        TextSize=11, Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left, ClearTextOnFocus=false, ZIndex=22,
    })
    return tb
end

local function settActionBtn(txt, col)
    local btn = el("TextButton", settPanel, {
        Size=UDim2.new(1,0,0,26), BackgroundColor3=col or C.TBON, BackgroundTransparency=0,
        Text=txt, TextColor3=C.TEXT, TextSize=11, Font=Enum.Font.GothamBold, ZIndex=21,
    })
    cr(btn, 5)
    return btn
end

settTitle("PING PLAYER")
local pingInput = settInput("Username...")
local pingBtn   = settActionBtn("ðŸ“£  Send Ping", Color3.fromRGB(30,40,60))

local sepLine = f(settPanel, {Size=UDim2.new(1,0,0,1), BackgroundColor3=C.BORDER})

settTitle("INVITE TO GAME")
local inviteBtn = settActionBtn("ðŸŽ®  Send Invite", Color3.fromRGB(20,45,30))

local SETT_H = 8+16+4+26+4+26+4+1+4+16+4+26+8
settPanel.Size = UDim2.new(0,220,0,0)

local function toggleSettings()
    settingsOpen = not settingsOpen
    settPanel.Visible = true
    if settingsOpen then
        tw(settPanel, {Size=UDim2.new(0,220,0,SETT_H)})
        tw(settBtn, {TextColor3=C.ACCENT})
    else
        tw(settPanel, {Size=UDim2.new(0,220,0,0)})
        tw(settBtn, {TextColor3=C.SUB})
        task.delay(0.2, function() if not settingsOpen then settPanel.Visible=false end end)
    end
end

settBtn.MouseButton1Click:Connect(toggleSettings)

-- // CORE FUNCTIONS // --
local appendMsg, appendSys

local function scrollToBottom()
    task.defer(function()
        scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
    end)
end

appendMsg = function(name, content, ts, isSelf, msgType)
    msgType = msgType or "chat"

    local row = f(scroll, {
        Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y,
        BackgroundColor3 = isSelf and Color3.fromRGB(18,22,36) or C.BG,
        BackgroundTransparency = isSelf and 0 or 1,
        LayoutOrder=#msgRows+1,
    })
    if isSelf then cr(row, 4) end

    local rowPad = Instance.new("UIPadding")
    rowPad.PaddingLeft=UDim.new(0,4); rowPad.PaddingRight=UDim.new(0,4)
    rowPad.PaddingTop=UDim.new(0,3); rowPad.PaddingBottom=UDim.new(0,3)
    rowPad.Parent=row

    el("TextLabel", row, {
        Size=UDim2.new(0,40,0,14), Position=UDim2.new(0,0,0,1),
        Text=ts, TextColor3=C.SUB, TextSize=9, Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    el("TextLabel", row, {
        Size=UDim2.new(0,130,0,14), Position=UDim2.new(0,43,0,1),
        Text=name, TextColor3=isSelf and C.ACCENT or C.ACCENT2,
        TextSize=11, Font=Enum.Font.GothamBold,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
    })

    if msgType == "invite" then
        local invData = HttpService:JSONDecode(content)
        local card = f(row, {
            Size=UDim2.new(1,-4,0,48), Position=UDim2.new(0,2,0,18),
            BackgroundColor3=Color3.fromRGB(15,30,20),
        })
        cr(card,6); sk(card, C.GREEN, 1)
        el("TextLabel", card, {
            Size=UDim2.new(1,-60,1,0), Position=UDim2.new(0,8,0,0),
            Text="ðŸŽ®  "..invData.gameName.."\nby "..name,
            TextColor3=C.GREEN, TextSize=11, Font=Enum.Font.GothamBold,
            TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true,
        })
        local joinBtn = el("TextButton", card, {
            Size=UDim2.new(0,50,0,22), Position=UDim2.new(1,-56,0.5,-11),
            BackgroundColor3=C.GREEN, BackgroundTransparency=0,
            Text="JOIN", TextColor3=Color3.fromRGB(8,20,10),
            TextSize=10, Font=Enum.Font.GothamBold,
        })
        cr(joinBtn, 5)
        joinBtn.MouseButton1Click:Connect(function()
            pcall(function()
                TeleportService:TeleportToPlaceInstance(invData.placeId, invData.jobId, lp)
            end)
        end)
    else
        el("TextLabel", row, {
            Size=UDim2.new(1,-4,0,0), Position=UDim2.new(0,2,0,17),
            AutomaticSize=Enum.AutomaticSize.Y,
            Text=content,
            TextColor3=isSelf and Color3.fromRGB(175,210,245) or C.TEXT,
            TextSize=12, Font=Enum.Font.Gotham,
            TextXAlignment=Enum.TextXAlignment.Left, TextWrapped=true,
        })
    end

    table.insert(msgRows, row)
    if #msgRows > MAX_MSGS then table.remove(msgRows,1):Destroy() end
    scrollToBottom()
end

appendSys = function(msg)
    local row = f(scroll, {
        Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, LayoutOrder=#msgRows+1,
    })
    el("TextLabel", row, {
        Size=UDim2.new(1,0,1,0), Text="â—† "..msg, TextColor3=C.SYS,
        TextSize=9, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left,
    })
    table.insert(msgRows, row)
    scrollToBottom()
end

local function sendMessage(chName, content, msgType)
    local id = getChannel(chName)
    if not id then return end
    req("POST", "/rest/v1/messages", {
        channel_id  = id,
        player_name = lp.Name,
        player_id   = tostring(lp.UserId),
        content     = content,
        msg_type    = msgType or "chat",
    })
end

local function fetchNew(chId, chName)
    local path = "/rest/v1/messages?channel_id=eq."..chId
        .."&select=id,player_name,player_id,content,created_at,msg_type"
        .."&order=id.asc&limit=50"
    if lastMsgId[chName] then
        path = path.."&id=gt."..lastMsgId[chName]
    end
    local msgs = req("GET", path)
    if type(msgs)~="table" or #msgs==0 then return end
    lastMsgId[chName] = msgs[#msgs].id
    for _, m in ipairs(msgs) do
        if chName == currentCh then
            local ts     = (m.created_at or ""):sub(12,19)
            local isSelf = tostring(m.player_id)==tostring(lp.UserId)
            appendMsg(m.player_name, m.content, ts, isSelf, m.msg_type)
        end
    end
end

local function startPolling(chName)
    if pollConn then pollConn:Disconnect(); pollConn=nil end
    currentCh = chName
    local chId = getChannel(chName)
    if not chId then appendSys("ERR: no channel '"..chName.."'"); return end
    if not lastMsgId[chName] then
        local seed = req("GET", "/rest/v1/messages?channel_id=eq."..chId.."&select=id&order=id.desc&limit=1")
        lastMsgId[chName] = (type(seed)=="table" and #seed>0) and seed[1].id or "00000000-0000-0000-0000-000000000000"
    end
    local e=0
    pollConn = RunService.Heartbeat:Connect(function(dt)
        e=e+dt; if e<POLL_RATE then return end; e=0
        task.spawn(fetchNew, chId, chName)
    end)
    appendSys("Joined #"..chName)
end

-- // NOTIFICATIONS // --
local lastNotifId = nil
local function pollNotifications()
    local path = "/rest/v1/notifications?target_username=eq."..lp.Name
        .."&seen=eq.false&select=id,sender_username,type,message,place_id,job_id,game_name&order=id.asc&limit=10"
    if lastNotifId then path = path.."&id=gt."..lastNotifId end
    local notifs = req("GET", path)
    if type(notifs)~="table" or #notifs==0 then return end
    lastNotifId = notifs[#notifs].id
    for _, n in ipairs(notifs) do
        req("PATCH", "/rest/v1/notifications?id=eq."..n.id, {seen=true})
        if n.type == "ping" then
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "ðŸ“£ Pinged by "..n.sender_username,
                    Text  = n.message or "You were pinged!",
                    Duration = 6,
                })
            end)
            appendSys("ðŸ“£ "..n.sender_username.." pinged you!")
        elseif n.type == "invite" then
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "ðŸŽ® Invite from "..n.sender_username,
                    Text  = "Join "..( n.game_name or "their game"),
                    Duration = 8,
                })
            end)
            appendSys("ðŸŽ® Invite from "..n.sender_username.." â€” check chat")
            local invContent = HttpService:JSONEncode({
                gameName = n.game_name or "Unknown",
                placeId  = n.place_id or "",
                jobId    = n.job_id or "",
            })
            appendMsg(n.sender_username, invContent, os.date("%H:%M:%S"), false, "invite")
        end
    end
end

do
    local e=0
    notifConn = RunService.Heartbeat:Connect(function(dt)
        e=e+dt; if e<NOTIF_RATE then return end; e=0
        task.spawn(pollNotifications)
    end)
end

-- // SEND PING // --
pingBtn.MouseButton1Click:Connect(function()
    local target = pingInput.Text:gsub("%s+","")
    if target=="" then appendSys("ERR: enter username"); return end
    pingInput.Text=""
    req("POST", "/rest/v1/notifications", {
        target_username = target,
        sender_username = lp.Name,
        type            = "ping",
        message         = lp.Name.." pinged you in Universal Chat!",
    })
    appendSys("ðŸ“£ Pinged "..target)
    toggleSettings()
end)

-- // SEND INVITE // --
inviteBtn.MouseButton1Click:Connect(function()
    local jobId   = game.JobId
    local placeId = game.PlaceId
    local gameName = "Unknown Game"
    pcall(function()
        gameName = Marketplace:GetProductInfo(placeId).Name
    end)
    local chId = getChannel(currentCh)
    if not chId then return end

    local invContent = HttpService:JSONEncode({
        gameName = gameName,
        placeId  = tostring(placeId),
        jobId    = jobId,
    })

    req("POST", "/rest/v1/messages", {
        channel_id  = chId,
        player_name = lp.Name,
        player_id   = tostring(lp.UserId),
        content     = invContent,
        msg_type    = "invite",
    })
    appendSys("ðŸŽ® Invite sent to #"..currentCh)
    toggleSettings()
end)

-- // TABS // --
local function setTab(ch)
    currentCh = ch
    hdrLbl.Text = "â—ˆ  UNIVERSAL CHAT  Â·  #"..ch:upper()
    inputBox.PlaceholderText = "Message #"..ch.."..."
    for n,b in pairs(tabBtns) do
        b.BackgroundColor3 = n==ch and C.TBON or C.TBOFF
        b.TextColor3       = n==ch and C.ACCENT or C.SUB
    end
    task.spawn(startPolling, ch)
end

local function addTab(ch, order)
    local btn = el("TextButton", tabBar, {
        Size=UDim2.new(0,68,1,0),
        BackgroundColor3=ch==DEF_CH and C.TBON or C.TBOFF, BackgroundTransparency=0,
        Text="#"..ch, TextColor3=ch==DEF_CH and C.ACCENT or C.SUB,
        TextSize=11, Font=Enum.Font.GothamBold, LayoutOrder=order,
    })
    cr(btn, 4); tabBtns[ch]=btn
    btn.MouseButton1Click:Connect(function() setTab(ch) end)
end

for i,ch in ipairs(CHANNELS) do addTab(ch,i) end

local addChBtn = el("TextButton", tabBar, {
    Size=UDim2.new(0,22,1,0), BackgroundColor3=C.TBOFF, BackgroundTransparency=0,
    Text="+", TextColor3=C.SUB, TextSize=14, Font=Enum.Font.GothamBold, LayoutOrder=99,
})
cr(addChBtn,4)

addChBtn.MouseButton1Click:Connect(function()
    inputBox:CaptureFocus()
    inputBox.PlaceholderText="New channel name..."
    local conn
    conn = inputBox.FocusLost:Connect(function(enter)
        conn:Disconnect()
        local newCh = inputBox.Text:lower():gsub("%s+","")
        inputBox.Text=""
        inputBox.PlaceholderText="Message #"..currentCh.."..."
        if enter and newCh~="" and not tabBtns[newCh] then
            table.insert(CHANNELS, newCh)
            addTab(newCh, #CHANNELS)
            setTab(newCh)
        end
    end)
end)

-- // SEND // --
local function doSend()
    local txt = inputBox.Text
    if not txt or txt:gsub("%s+","")=="" then return end
    inputBox.Text=""
    local ch, body = txt:match("^/(%a+)%s+(.+)$")
    if ch and body then
        task.spawn(sendMessage, ch:lower(), body, "chat")
    else
        task.spawn(sendMessage, currentCh, txt, "chat")
    end
end

sendBtn.MouseButton1Click:Connect(doSend)
inputBox.FocusLost:Connect(function(enter) if enter then doSend() end end)

-- // HOVER FX // --
sendBtn.MouseEnter:Connect(function() tw(sendBtn,{BackgroundColor3=Color3.fromRGB(140,210,255)}) end)
sendBtn.MouseLeave:Connect(function() tw(sendBtn,{BackgroundColor3=C.ACCENT}) end)

-- // DRAG // --
hdr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        isDrag=true; dragStart=i.Position; startPos=main.Position
    end
end)
hdr.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then isDrag=false end
end)
UIS.InputChanged:Connect(function(i)
    if isDrag and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-dragStart
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)

-- // MINIMIZE // --
minBtn.MouseButton1Click:Connect(function()
    isMin=not isMin
    chatWrap.Visible=not isMin; tabBar.Visible=not isMin; inputArea.Visible=not isMin
    tw(main, {Size=isMin and UDim2.new(0,W,0,38) or UDim2.new(0,W,0,H)})
    minBtn.Text=isMin and "â–¡" or "â€”"
    if settingsOpen and isMin then toggleSettings() end
end)

-- // INIT // --
appendSys("Universal Chat loaded â€” welcome, "..lp.Name)
appendSys("âš™ gear button â†’ ping & invite  |  /channel msg")

do
    local seed = req("GET", "/rest/v1/notifications?target_username=eq."..lp.Name.."&select=id&order=id.desc&limit=1")
    if type(seed)=="table" and #seed>0 then lastNotifId=seed[1].id end
end

task.spawn(startPolling, DEF_CH)
