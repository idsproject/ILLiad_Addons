-- About HathitTrust.lua
-- IDS Project 2021
-- Uses Chromium
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
		HathiSearchForm.Browser = HathiSearchForm.Form:CreateBrowser("Hathi", "Hathi", "Search", "Chromium");
	
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
	HathiSearchForm.Browser:RegisterPageHandler("formExists", "searchcoll", "HathiLoaded", false);
	HathiSearchForm.Browser:Navigate("https://babel.hathitrust.org/cgi/ls?a=page;page=advanced");	
end

function HathiLoaded()
   if GetFieldValue("Transaction", "ISSN") ~= "" then
	  HathiSearchForm.Browser:ExecuteScript("document.getElementById('field1').value = 'isn'");
	  HathiSearchForm.Browser:ExecuteScript("document.getElementById('field-search-text-input-1-1').value = '" .. GetFieldValue("Transaction", "ISSN") .. "'");
   else 
      HathiSearchForm.Browser:ExecuteScript("document.getElementById('field1').value = 'title'");
	  HathiSearchForm.Browser:ExecuteScript("document.getElementById('field-search-text-input-1-1').value = '" .. GetFieldValue("Transaction", "LoanTitle") .. "'");
   end
	HathiSearchForm.Browser:ExecuteScript("document.forms['searchcoll'].submit()");
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
