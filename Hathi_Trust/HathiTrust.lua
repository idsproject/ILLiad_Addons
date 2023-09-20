-- About HathitTrust.lua
-- IDS Project 2023
-- Uses Chromium or WebView2
--
-- This Addon does an ISBN or Title search using Hathi Trust (http://www.hathitrust.org).
-- ISBN will be run if one is available.
-- scriptActive must be set to true for the script to run.
-- autoSearch (boolean) determines whether the search is performed automatically when a request is opened or not.
--

-- Load the .NET System Assembly
luanet.load_assembly("System");
Types = {};
Types["Process"] = luanet.import_type("System.Diagnostics.Process");
local settings = {};
-- set scriptActive to true for this script to run, false to stop it from running.
settings.scriptActive = GetSetting("Active");
-- set autoSearch to true for this script to automatically run the search when the request is opened.
settings.autoSearch = GetSetting("AutoSearch");

require "Atlas.AtlasHelpers";
-- don't change anything below this line
local interfaceMngr = nil;
local HathiSearchForm = {};
HathiSearchForm.Form = nil;
HathiSearchForm.Browser = nil;
HathiSearchForm.RibbonPage = nil;
function Init()
	if settings.scriptActive then

		interfaceMngr = GetInterfaceManager();
		HathiSearchForm.Form = interfaceMngr:CreateForm("Hathi Search", "Script");
	
		-- Add a browser
		if (WebView2Enabled()) then
			HathiSearchForm.Browser = HathiSearchForm.Form:CreateBrowser("Hathi", "Hathi", "Search", "WebView2");
		else
			HathiSearchForm.Browser = HathiSearchForm.Form:CreateBrowser("Hathi", "Hathi", "Search", "Chromium");
		end
	
		-- Hide the text label
		HathiSearchForm.Browser.TextVisible = false;
	
		-- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method.  We can retrieve that one and add our buttons to it.
		HathiSearchForm.RibbonPage = HathiSearchForm.Form:GetRibbonPage("Search");
		
		HathiSearchForm.RibbonPage:CreateButton("Search", GetClientImage("Search32"), "Search", "Hathi");
		HathiSearchForm.RibbonPage:CreateButton("Open New Browser", GetClientImage("Web32"), "OpenInDefaultBrowser", "Utility")

		HathiSearchForm.Form:Show();
		
		if settings.autoSearch then
			Search();
		end
	end
end

function Search()
		
   if GetFieldValue("Transaction", "ISSN") ~= "" then
	  HathiSearchForm.Browser:Navigate("https://catalog.hathitrust.org/Search/Home?type%5B%5D=isn&lookfor%5B%5D=" .. GetFieldValue("Transaction", "ISSN") .. "&page=1&pagesize=100");
   else 
      HathiSearchForm.Browser:Navigate("https://catalog.hathitrust.org/Search/Home?adv=1&setft=true&lookfor%5B%5D=" .. GetFieldValue("Transaction", "LoanTitle") .. "&lookfor%5B%5D=" .. GetFieldValue("Transaction", "LoanAuthor") .. "&type%5B%5D=title&type%5B%5D=author&bool%5B%5D=AND");
   end
   
end


function WebView2Enabled()
    return AddonInfo.Browsers ~= nil and AddonInfo.Browsers.WebView2 ~= nil and AddonInfo.Browsers.WebView2 == true;
end

function OpenInDefaultBrowser()
	local currentUrl = HathiSearchForm.Browser.Address;
	
	if (currentUrl and currentUrl ~= "")then
		LogDebug("Opening Browser URL in default browser: " .. currentUrl);

		local process = Types["Process"]();
		process.StartInfo.FileName = currentUrl;
		process.StartInfo.UseShellExecute = true;
		process:Start();
	end
end
