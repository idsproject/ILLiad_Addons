-- IDS Network HathiTrust Server Addon
-- Minimal, rebuilt version – 2025-12-09

------------------------------------------------------------
-- Settings
------------------------------------------------------------
local settings = {}
settings.FieldChoice                = GetSetting("FieldChoice")
settings.BorDocDelTransactionStatus = GetSetting("BorDocDelTransactionStatus")
settings.LendingTransactionStatus   = GetSetting("LendingTransactionStatus")
settings.RouteToBorDocDel           = GetSetting("RouteToBorDocDel")
settings.RouteToLending             = GetSetting("RouteToLending")
settings.FlagThis                   = GetSetting("FlagThis")
settings.RequestType                = GetSetting("RequestType")
settings.NVTGC                      = GetSetting("NVTGC")

------------------------------------------------------------
-- .NET types and helpers
------------------------------------------------------------
luanet.load_assembly("System")

local Types = {}
Types["System.Net.WebClient"]            = luanet.import_type("System.Net.WebClient")
Types["System.Text.Encoding"]            = luanet.import_type("System.Text.Encoding")
Types["System.Net.ServicePointManager"]  = luanet.import_type("System.Net.ServicePointManager")
Types["System.Net.SecurityProtocolType"] = luanet.import_type("System.Net.SecurityProtocolType")

------------------------------------------------------------
-- Lua helpers + JSON / Atlas helpers
------------------------------------------------------------
require("JsonParser")
require("AtlasHelpers")

-- URL escape helper (pure Lua, no System.Uri)
local function esc(s)
    if s == nil then return "" end
    s = tostring(s)
    -- Normalize line breaks to spaces
    s = s:gsub("\r\n", " "):gsub("\n", " "):gsub("\r", " ")
    -- Percent-encode everything not in [A-Za-z0-9-_.~]
    s = s:gsub("([^%w%-_%.~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return s
end

------------------------------------------------------------
-- Init: hook up timer
------------------------------------------------------------
function Init()
    RegisterSystemEventHandler("SystemTimerElapsed", "TimerElapsed")
end

------------------------------------------------------------
-- TimerElapsed: select candidate transactions
------------------------------------------------------------
function TimerElapsed(eventArgs)
    local connection = CreateManagedDatabaseConnection()
	local reqType = settings.RequestType
    local NVTGC   = settings.NVTGC

    -- Normalize RequestType into a SQL-safe IN list
    if reqType == "Article" then
        reqType = " AND t.RequestType ='Article'"
	elseif reqType == "Loan" then
		reqType = " AND t.RequestType ='Loan'"
	else
		reqType = " AND (t.RequestType ='Article' OR t.RequestType ='Loan')"
    end

    -- Optional NVTGC filter
    local nvtgcClause = ""
    if NVTGC ~= nil and NVTGC ~= "" and NVTGC ~= "ALL" then
        nvtgcClause = " AND t.username in (select u.username from users u where u.username=t.UserName and u.NVTGC='" .. NVTGC .. "' )"
    end
 
    connection.QueryString =
        "SELECT DISTINCT t.TransactionNumber " ..
        "FROM Transactions t " ..
        "WHERE t.TransactionStatus IN ('" .. settings.BorDocDelTransactionStatus .. "','" .. settings.LendingTransactionStatus .. "')" ..
		reqType .. nvtgcClause ..
        "  AND t.TransactionNumber NOT IN (" ..
        "      SELECT DISTINCT n.TransactionNumber " ..
        "      FROM Notes n " ..
        "      WHERE t.TransactionNumber=n.TransactionNumber AND n.Note LIKE '%HathiTrust%'" ..
        "  )"

    local ok, resultOrErr = pcall(function()
        connection:Connect()
        return connection:Execute()
    end)

    if not ok then
        -- SQL / ADO.NET error – just bail out quietly
        if connection ~= nil then
            connection:Dispose()
            connection = nil
        end
        return
    end

    local transactionsTable = resultOrErr

    if transactionsTable ~= nil and
       transactionsTable.Rows ~= nil and
       transactionsTable.Rows.Count ~= nil and
       transactionsTable.Rows.Count > 0 then

        for i = 0, transactionsTable.Rows.Count - 1 do
            local tn = transactionsTable.Rows:get_Item(i):get_Item("TransactionNumber")

            -- Protect per-transaction processing too
            pcall(function()
                ProcessDataContexts("TransactionNumber", tn, "BeginHathiCheck")
            end)
        end
    end

    if connection ~= nil then
        connection:Dispose()
        connection = nil
    end
end

------------------------------------------------------------
-- BeginHathiCheck: per-transaction processing
------------------------------------------------------------
function BeginHathiCheck()
    local ok, hasUrlOrErr = pcall(function()
        return HathiTrustAPICall()
    end)

    if not ok then
        -- HathiTrustAPICall threw an error; ignore for now
        return
    end

    local hasUrl = hasUrlOrErr

    if hasUrl then
        -- Flag, if configured
        if settings.FlagThis ~= nil and settings.FlagThis ~= "" then
            FlagRequest()
        end

        -- Route based on Processtype
        local procType = GetFieldValue("Transaction", "Processtype")

        if settings.RouteToBorDocDel ~= nil and settings.RouteToBorDocDel ~= "" and procType ~= "Lending" then
            RouteRequest(settings.RouteToBorDocDel)
        elseif settings.RouteToLending ~= nil and settings.RouteToLending ~= "" and procType == "Lending" then
            RouteRequest(settings.RouteToLending)
        end
    end
end

------------------------------------------------------------
-- FlagRequest: add a transaction flag
------------------------------------------------------------
function FlagRequest()
    local tn   = GetFieldValue("Transaction", "TransactionNumber")
    local flag = settings.FlagThis

    if flag ~= nil and flag ~= "" then
        ExecuteCommand("AddTransactionFlag", { tn, flag })
        ExecuteCommand("AddNote", { tn, "HathiTrust: flag '" .. flag .. "' added by server addon." })
    end
end

------------------------------------------------------------
-- RouteRequest: route transaction to a queue
------------------------------------------------------------
function RouteRequest(queue)
    if queue == nil or queue == "" then return end
    local tn = GetFieldValue("Transaction", "TransactionNumber")
    ExecuteCommand("Route", { tn, queue })
end

------------------------------------------------------------
-- HathiTrustAPICall: call the HathiTrust Bib API and store URL
------------------------------------------------------------
function HathiTrustAPICall()
    local tn        = GetFieldValue("Transaction", "TransactionNumber")
    local ESPNumber = GetFieldValue("Transaction", "ESPNumber") or ""
    local issn      = GetFieldValue("Transaction", "ISSN") or ""
    local title     = GetFieldValue("Transaction", "LoanTitle") or ""
    local author    = GetFieldValue("Transaction", "LoanAuthor") or ""

    -- Decide identifier + type (oclc / issn / isbn)
    local identifier = ""
    local searchType = ""

    if ESPNumber ~= "" then
        identifier = AtlasHelpers.Trim(ESPNumber)
        searchType = "oclc"
    elseif issn ~= "" then
        local cleaned = AtlasHelpers.Trim(issn):gsub("[%-%s]", "")
        local len = cleaned:len()
        if len == 8 then
            identifier = cleaned
            searchType = "issn"
        elseif len == 10 or len == 13 then
            identifier = cleaned
            searchType = "isbn"
        end
    end

    if identifier == "" or searchType == "" then
        ExecuteCommand("AddNote", { tn,
            "HathiTrust: No valid OCLC/ISSN/ISBN available for Bib API lookup. (Title: " ..
            title .. "; Author: " .. author .. ")" })
        SaveDataSource("Transaction")
        return false
    end

    local apiUrl = "https://catalog.hathitrust.org/api/volumes/full/" ..
                   searchType .. "/" .. esc(identifier) .. ".json"

    -- Try to set TLS 1.2 (ignore errors)
    pcall(function()
        Types["System.Net.ServicePointManager"].SecurityProtocol =
            Types["System.Net.SecurityProtocolType"].Tls12
    end)

    -- Create WebClient safely
    local okClient, clientOrErr = pcall(function()
        local c = Types["System.Net.WebClient"]()
        c.Encoding = Types["System.Text.Encoding"].UTF8
        return c
    end)

    if not okClient then
        ExecuteCommand("AddNote", { tn,
            "HathiTrust: Error creating WebClient for Bib API at " .. apiUrl })
        SaveDataSource("Transaction")
        return false
    end

    local client = clientOrErr

    -- Download JSON safely
    local okDownload, responseString = pcall(function()
        return client:DownloadString(apiUrl)
    end)

    client:Dispose()

    if not okDownload then
        ExecuteCommand("AddNote", { tn,
            "HathiTrust: Error calling Bib API at " .. apiUrl })
        SaveDataSource("Transaction")
        return false
    end

    -- Parse JSON safely
    local okParse, response = pcall(function()
        return JsonParser:ParseJSON(responseString)
    end)

    if not okParse or not response then
        ExecuteCommand("AddNote", { tn,
            "HathiTrust: Unable to parse Bib API response for " .. identifier })
        SaveDataSource("Transaction")
        return false
    end

    -- Interpret Bib API response
    local recordsCount = 0
    if response.records then
        for _ in pairs(response.records) do
            recordsCount = recordsCount + 1
        end
    end

    if recordsCount == 0 or not response.items or #response.items == 0 then
        ExecuteCommand("AddNote", { tn,
            "HathiTrust: No items found in Bib API response for " .. identifier })
        SaveDataSource("Transaction")
        return false
    end

    local recordNumber = response.items[1].fromRecord
    local finalUrl = nil

    if recordsCount > 1 or #response.items > 1 then
        -- Multiple items/records: use record URL
        if response.records[recordNumber] and response.records[recordNumber].recordURL then
            finalUrl = response.records[recordNumber].recordURL
        end
    else
        -- Single record/item: prefer itemURL, fall back to recordURL
        if response.items[1].itemURL and response.items[1].itemURL ~= "" then
            finalUrl = response.items[1].itemURL
        elseif response.records[recordNumber] and response.records[recordNumber].recordURL then
            finalUrl = response.records[recordNumber].recordURL
        end
    end

    if not finalUrl or finalUrl == "" then
        ExecuteCommand("AddNote", { tn,
            "HathiTrust: Bib API returned data but no usable record/item URL for " .. identifier })
        SaveDataSource("Transaction")
        return false
    end

    -- Store the URL in the configured field and add a note
    local fieldChoice = settings.FieldChoice
    if fieldChoice ~= nil and fieldChoice ~= "" then
        SetFieldValue("Transaction", fieldChoice, finalUrl)
        ExecuteCommand("AddNote", { tn, "HathiTrust URL: " .. finalUrl })
    else
        ExecuteCommand("AddNote", { tn, "HathiTrust URL (no field configured): " .. finalUrl })
    end

    SaveDataSource("Transaction")
    return true
end
