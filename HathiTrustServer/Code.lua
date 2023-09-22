local settings = {};
settings.FieldChoice = GetSetting("FieldChoice");
settings.TransactionStatus = GetSetting("TransactionStatus");

function Init()
RegisterSystemEventHandler("SystemTimerElapsed", "TimerElapsed");
end

function TimerElapsed()
	local connection = CreateManagedDatabaseConnection();
	connection.QueryString = "SELECT distinct TransactionNumber FROM Transactions WHERE TransactionStatus like '" .. settings.TransactionStatus .. "'";
	connection:Connect();
	local transactionsTable = connection:Execute();
	if transactionsTable.Rows.Count ~= nil then
		local transactionNumbers = {};
		for i = 0, transactionsTable.Rows.Count - 1 do
			ProcessDataContexts("TransactionNumber", transactionsTable.Rows:get_Item(i):get_Item("TransactionNumber"), "ImportURL");
		end
	end
end

function ImportURL()
	local tn = GetFieldValue("Transaction", "TransactionNumber");
	local url= nil;
	if GetFieldValue("Transaction", "ISSN") ~= "" then
		url="https://catalog.hathitrust.org/Search/Home?type%5B%5D=isn&lookfor%5B%5D=" .. GetFieldValue("Transaction", "ISSN") .. "&page=1&pagesize=100";
	else 
		url="https://catalog.hathitrust.org/Search/Home?adv=1&setft=true&lookfor%5B%5D=" .. GetFieldValue("Transaction", "LoanTitle") .. "&lookfor%5B%5D=" .. GetFieldValue("Transaction", "LoanAuthor") .. "&type%5B%5D=title&type%5B%5D=author&bool%5B%5D=AND";
	end
	luanet.load_assembly("System");
	WebClient = luanet.import_type("System.Net.WebClient");
	StreamReader = luanet.import_type("System.IO.StreamReader");
	myWebClient = WebClient();
	myStream = myWebClient:OpenRead(url);
	sr = StreamReader(myStream);
	hathi_data = sr:ReadToEnd();
	myStream:Close();
	if not string.find(hathi_data, "No results") then
		SetFieldValue("Transaction", settings.FieldChoice, url);
		SaveDataSource("Transaction");
	end


local func, errorMessage = loadstring(hathi_data);
if(not func) then
return;
end
local success, errorMessage = pcall(func);
if(not success) then
return;
end
DBCONN:Dispose();
DBCONN = nil;
end

function OnError(errorArgs)
LogDebug("*** Closing DB connection ***");
DBCONN:Dispose();
DBCONN = nil;
LogDebug("***********************");
LogDebug("*** HATHI_TRUST_ERROR ***");
LogDebug("***********************");
LogDebug("*** SCRIPT[" .. scriptErrorEventArgs.ScriptName .. "] ***");
LogDebug("*** METHOD[" .. scriptErrorEventArgs.ScriptMethod .. "] ***");
LogDebug("*** MESSAGE[" .. scriptErrorEventArgs.Message .. "]***");
end
