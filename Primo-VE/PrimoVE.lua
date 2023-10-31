-- About PrimoVE.lua
--
-- Updated Primo VE for WebView2 by Mark Sullivan, IDS Project, sullivm@geneseo.edu
-- 10/31/2023
-- PrimoVE.lua provides a basic search for ISBN, ISSN, Title, and Phrase Searching for the Primo VE interface.
-- There is a config file that is associated with this Addon that needs to be set up in order for the Addon to work.
-- Please see the ReadMe.txt file for example configuration values that you can pull from your Primo New UI URL.
--
-- set AutoSearchISxN to true if you would like the Addon to automatically search for the ISxN.
-- set AutoSearchTitle to true if you would like the Addon to automatically search for the Title.


require "Atlas.AtlasHelpers";

-- Load the .NET System Assembly
luanet.load_assembly("System");
Types = {};
Types["Process"] = luanet.import_type("System.Diagnostics.Process");

local settings = {};
settings.AutoSearchISxN = GetSetting("AutoSearchISxN");
settings.AutoSearchOCLC = GetSetting("AutoSearchOCLC");
settings.AutoSearchTitle = GetSetting("AutoSearchTitle");
settings.WhichTitle = GetSetting("WhichTitle");
settings.PrimoVEURL = GetSetting("PrimoVEURL");
settings.BaseVEURL = GetSetting("BaseVEURL")
settings.DatabaseName = GetSetting("DatabaseName");
settings.SearchScope = GetSetting("SearchScope");
settings.BarcodeLocation = GetSetting("BarcodeLocation");

local interfaceMngr = nil;
local PrimoVEForm = {};
PrimoVEForm.Form = nil;
PrimoVEForm.Browser = nil;
PrimoVEForm.RibbonPage = nil;

local AliasForm = {}
AliasForm.Form = nil;
AliasForm.Alias = nil;


function Init()
    -- The line below makes this Addon work on all request types.
    if GetFieldValue("Transaction", "RequestType") ~= "" then
		interfaceMngr = GetInterfaceManager();

		-- Create browser
		PrimoVEForm.Form = interfaceMngr:CreateForm("PrimoVE", "Script");
		if (WebView2Enabled()) then
			PrimoVEForm.Browser = PrimoVEForm.Form:CreateBrowser("PrimoVE", "PrimoVE", "PrimoVE", "WebView2");
		else
			PrimoVEForm.Browser = PrimoVEForm.Form:CreateBrowser("PrimoVE", "PrimoVE", "PrimoVE", "Chromium");
		end
		
		AliasForm.Form = interfaceMngr:CreateForm("ALIAS", "Script");
		AliasForm.Alias = AliasForm.Form:CreateBrowser("ALIAS", "ALIAS Browser", "ALIAS");


		-- Hide the text label
		PrimoVEForm.Browser.TextVisible = false;
		AliasForm.Alias.TextVisible = false;

		-- Hide Alias and MaRC browsers 
		AliasForm.Alias.WebBrowser.Visible=false;


		-- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method. We can retrieve that one and add our buttons to it.
		PrimoVEForm.RibbonPage = PrimoVEForm.Form:GetRibbonPage("PrimoVE");
		-- The GetClientImage("Search32") pulls in the magnifying glass icon. There are other icons that can be used.
		-- Here we are adding a new button to the ribbon
		PrimoVEForm.RibbonPage:CreateButton("Search ISxN", GetClientImage("Search32"), "SearchISxN", "PrimoVE");
		PrimoVEForm.RibbonPage:CreateButton("Search OCLC#", GetClientImage("Search32"), "SearchOCLC", "PrimoVE");
		PrimoVEForm.RibbonPage:CreateButton("Search Title", GetClientImage("Search32"), "SearchTitle", "PrimoVE");
		PrimoVEForm.RibbonPage:CreateButton("Import Call Number/Location/Barcode", GetClientImage("Search32"), "ImportCallNumber", "PrimoVE");
		PrimoVEForm.RibbonPage:CreateButton("ALIAS License Check", GetClientImage("Search32"), "ProcessArticle", "PrimoVE");
		PrimoVEForm.RibbonPage:CreateButton("Open New Browser", GetClientImage("Web32"), "OpenInDefaultBrowser", "Utility");

		PrimoVEForm.Form:Show();
				
		if settings.AutoSearchISxN then
			SearchISxN();
		elseif settings.AutoSearchOCLC then
			SearchOCLC();
		elseif settings.AutoSearchTitle then
			SearchTitle();
		else 
			DefaultURL();
		end
	end
end

function DefaultURL()
		PrimoVEForm.Browser:Navigate(settings.PrimoVEURL);
end

-- This function searches for ISxN for both Loan and Article requests.
function SearchISxN()
    if GetFieldValue("Transaction", "ISSN") ~= "" then
		local ISXN = GetFieldValue("Transaction", "ISSN");
		i, j = string.find(ISXN, " ");
		if i>0 then
			t=split(ISXN," ");
			ISXN=t[1];
		end
		PrimoVEForm.Browser:Navigate(settings.BaseVEURL .. "/discovery/search?query=any,contains," .. ISXN .. "&tab=default_tab&search_scope=" .. settings.SearchScope .. "&sortby=rank&vid=" .. settings.DatabaseName .. "&lang=en_US&offset=0");
	else
		SearchTitle();
	end
end

function SearchOCLC()
    if GetFieldValue("Transaction", "ESPNumber") ~= "" then
		PrimoVEForm.Browser:Navigate(settings.BaseVEURL .. "/discovery/search?query=any,contains," .. GetFieldValue("Transaction", "ESPNumber") .. "&tab=default_tab&search_scope=" .. settings.SearchScope .. "&sortby=rank&vid=" .. settings.DatabaseName .. "&lang=en_US&offset=0");
	else
		SearchTitle();
	end
end



-- This function performs a standard search for LoanTitle for Loan requests and PhotoJournalTitle/PhotoArticleTitle for Article requests.
function SearchTitle()
    if GetFieldValue("Transaction", "RequestType") == "Loan" then  
			PrimoVEForm.Browser:Navigate(settings.BaseVEURL .. "/discovery/search?query=any,contains," ..  AtlasHelpers.UrlEncode(GetFieldValue("Transaction", "LoanTitle")) .. "&tab=default_tab&search_scope=" .. settings.SearchScope .. "&sortby=rank&vid=" .. settings.DatabaseName .. "&lang=en_US&offset=0");
	elseif GetFieldValue("Transaction", "RequestType") == "Article" then  
		if settings.WhichTitle then
			local articleTitle=GetFieldValue("Transaction", "PhotoArticleTitle");
			articleTitle=string.gsub(articleTitle,"'","");
			PrimoVEForm.Browser:Navigate(settings.BaseVEURL .. "/discovery/search?query=any,contains,'" .. articleTitle .. "'&tab=default_tab&search_scope=" .. settings.SearchScope .. "&sortby=rank&vid=" .. settings.DatabaseName .. "&lang=en_US&offset=0");
		else
			PrimoVEForm.Browser:Navigate(settings.BaseVEURL .. "/discovery/search?query=any,contains," .. GetFieldValue("Transaction", "PhotoJournalTitle") .. "&tab=default_tab&search_scope=" .. settings.SearchScope .. "&sortby=rank&vid=" .. settings.DatabaseName .. "&lang=en_US&offset=0");
		end
	else
		interfaceMngr:ShowMessage("The Journal Title is not available from request form", "Insufficient Information");
	end
end

function ImportCallNumber()
	local clicker = PrimoVEForm.Browser:EvaluateScript("document.getElementsByClassName('neutralized-button layout-full-width layout-display-flex md-button md-ink-ripple layout-row')[0].click()").Result;
	local tags = PrimoVEForm.Browser:EvaluateScript("document.getElementsByTagName('prm-location-items')[0].innerHTML").Result;
	if (tags == nil or tags=='') then
		interfaceMngr:ShowMessage("Open a full record with local items available.", "Record with physical holdings required");
		return;
	end
  
	local location_name = tags:match('collectionTranslation">(.-)<'):gsub('collectionTranslation">', '');
	local call_number = tags:match('callNumber" dir="auto">(.-)<'):gsub('callNumber" dir="auto">', '');
	
  
	if (location_name == nil or call_number == nil) then
		interfaceMngr:ShowMessage("Location or call number not found on this page.", "Information not found");
		return false;
	else
		SetFieldValue("Transaction", "Location", location_name);
		SetFieldValue("Transaction", "CallNumber", call_number);
	end
	Sleep(1);
	if BarcodeCheck() then
		ImportBarcode();
	end
	--ExecuteCommand("SwitchTab", {"Detail"});
end

function BarcodeCheck()
	--interfaceMngr:ShowMessage("Check", "Test");
	local tags = PrimoVEForm.Browser:EvaluateScript("document.getElementsByTagName('prm-location-items')[0].innerHTML").Result;
	local barcode = tags:match('Barcode: (.-)<');
	--interfaceMngr:ShowMessage(barcode, "Test");
	if (barcode == nil) then
		local clicker = PrimoVEForm.Browser:EvaluateScript("document.getElementsByClassName('md-2-line has-expand md-no-proxy md-with-secondary _md')[0].click()").Result;
		Sleep(1);
		return true;
	else 
		return true;
	end
end


function ImportBarcode()
	
	local tags = PrimoVEForm.Browser:EvaluateScript("document.getElementsByTagName('prm-location-items')[0].innerHTML").Result;
	local barcode = nil
	if (tags ~= nil) then
		barcode = tags:match('Barcode: (.-)<');
		if (barcode == nil) then
			interfaceMngr:ShowMessage("Click on item in list to view barcode.", "Record with physical holdings required");
		else
			barcode = tags:match('Barcode: (.-)<'):gsub('Barcode: ', '');
		end
	end
	if (settings.BarcodeLocation ~= nil and barcode ~= nil) then
		SetFieldValue("Transaction", settings.BarcodeLocation, barcode);
	end
end


function ProcessArticle()
    local providersearch = {};
	local providerlist = nil;
	for x=0,5 do
		providersearch[x] = PrimoVEForm.Browser:EvaluateScript("document.getElementsByClassName('item-title md-primoExplore-theme')[" .. x .. "].innerHTML").Result;
	end
	
	
	if providersearch[0] == nil then
		return false;
	end
	for i=0, #providersearch do
		if providersearch[i] ~= "" then
			if providerlist == nil then
				providerlist = providersearch[i];
			else
				providerlist = providerlist .. "|" .. providersearch[i];
			end
		end
	end -- for loop
						

	if string.len(providerlist)>1 then
		AliasForm.Alias:RegisterPageHandler("custom", "testAliasResponse", "Alias_License", false);
		AliasForm.Alias:Navigate("http://alias.idsproject.org/alias.aspx?linker=PRIMO&provider=" .. providerlist);
	end
end  --function

function testAliasResponse()
	local ALIAS_Results = AliasForm.Alias.WebBrowser.DocumentText;
	if string.len(ALIAS_Results)>1 and  string.find(ALIAS_Results, "<html>")==nil then
		
		return true;
	else
		return false;
	end 
end

function Alias_License()

	local ALIAS_Results = AliasForm.Alias.WebBrowser.DocumentText;
	local t = {};
	local tpairs = {};
	local providersearch = {};
	for x=0,5 do
		providersearch[x] = PrimoVEForm.Browser:EvaluateScript("document.getElementsByClassName('item-title md-primoExplore-theme')[" .. x .. "].innerHTML").Result;
	end
	t=split(ALIAS_Results,"|");
	for i=1, #(t)-1,2 do
		tpairs[string.gsub(t[i]," ","")]=t[i+1];
	end -- for loop

	for i=0, #providersearch do
		local ProviderData = PrimoVEForm.Browser:EvaluateScript("document.getElementsByClassName('item-title md-primoExplore-theme')[" .. i .. "].innerHTML").Result;
		PrimoVEForm.Browser:ExecuteScript("document.getElementsByClassName('item-title md-primoExplore-theme')[" .. i .. "].innerHTML += ' - " .. translateAliasCode(tpairs[string.gsub(ProviderData," ","")]) .. "'");
	end -- for loop
	

end 

function translateAliasCode(code)
            if code=="Y" then
                 return "ILL OK";
            elseif code=="YNP" then
                 return "ILL OK, Non-Profit Only";
            elseif code=="PE" then
                 return "Print First, Send Odyssey";
            elseif code=="PENP" then
                 return "Print First, Send Odyssey, Non-Profit Only";
            elseif code=="P" then
                 return "Print Only";
            elseif code=="PNP" then
                 return "Print Only, Non-Profit Only";
            elseif code=="S" then
                 return "License is Silent";
            elseif code=="N" then
                 return "ILL NOT OK";
            else
                 return "License Information Not Available";
          end
end

function split(pString, pPattern)
	local Table = {} -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = pString:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = pString:find(fpat, last_end)
	end
	if last_end <= #pString then
		cap = pString:sub(last_end)
		table.insert(Table, cap)
	end
	return Table
end

function OpenInDefaultBrowser()
	local currentUrl = PrimoVEForm.Browser.Address;
	
	if (currentUrl and currentUrl ~= "")then
		LogDebug("Opening Browser URL in default browser: " .. currentUrl);

		local process = Types["Process"]();
		process.StartInfo.FileName = currentUrl;
		process.StartInfo.UseShellExecute = true;
		process:Start();
	end
end

function WebView2Enabled()
    return AddonInfo.Browsers ~= nil and AddonInfo.Browsers.WebView2 ~= nil and AddonInfo.Browsers.WebView2 == true;
end

function Sleep(seconds)
    local endTime = os.time() + seconds
    while os.time() < endTime do
    end
end
