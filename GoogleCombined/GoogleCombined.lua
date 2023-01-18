-- About GoogleCombined.lua (version 2.9, 1/11/2022)
-- Author:  Mark Sullivan, SUNY Geneseo, IDS Project, sullivm@geneseo.edu
-- GoogleCombined.lua does a search of Google, Google Books and Google Scholar.  Current URL is in the textbox at the top of the Addon for easy cut & paste.
-- 
-- autoSearch (boolean) determines whether the search is performed automatically when a request is opened or not.
-- New version uses Chromium for better stability

-- Load the .NET System Assembly
luanet.load_assembly("System");
Types = {};
Types["Process"] = luanet.import_type("System.Diagnostics.Process");

local settings = {};
settings.AutoSearch = GetSetting("AutoSearch");
settings.SearchText = '';
local interfaceMngr = nil;
local googleSearchForm = {};
googleSearchForm.Form = nil;
googleSearchForm.Browser = nil;
googleSearchForm.RibbonPage = nil;

require "Atlas.AtlasHelpers";

function Init()
	if GetFieldValue("Transaction", "RequestType") == "Article" then
		interfaceMngr = GetInterfaceManager();
		
		-- Create a form
		googleSearchForm.Form = interfaceMngr:CreateForm("Google Combined Search", "Script");
				-- Add a text field for the URL
		googleSearchForm.URLBox= googleSearchForm.Form:CreateTextEdit("URL:", "URL");
		
		-- Add a browser
		googleSearchForm.Browser = googleSearchForm.Form:CreateBrowser("Google Scholar Search", "Google Scholar Search Browser", "Google Scholar Search","Chromium");
		
		-- Hide the text label
		googleSearchForm.Browser.TextVisible = false;
		
		-- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method.  We can retrieve that one and add our buttons to it.
		googleSearchForm.RibbonPage = googleSearchForm.Form:GetRibbonPage("Google Scholar Search");
		
		-- Create the search button
		googleSearchForm.Google= googleSearchForm.RibbonPage:CreateButton("Search Google", GetClientImage("Search32"), "GoogleSearch", "Google Combined Search");
        googleSearchForm.GoogleScholar= googleSearchForm.RibbonPage:CreateButton("Search Google Scholar", GetClientImage("Search32"), "GoogleScholarSearch", "Google Combined Search");
        googleSearchForm.GoogleBooks= googleSearchForm.RibbonPage:CreateButton("Search Google Books", GetClientImage("Search32"), "GoogleBookSearch", "Google Combined Search");
		googleSearchForm.RibbonPage:CreateButton("Open New Browser", GetClientImage("Web32"), "OpenInDefaultBrowser", "Utility");
		
		-- After we add all of our buttons and form elements, we can show the form.
		googleSearchForm.Form:Show();
		-- Determine Search
		if GetFieldValue("Transaction", "RequestType") == "Loan" then
            settings.SearchText = GetFieldValue("Transaction", "LoanTitle");
        else
            settings.SearchText = GetFieldValue("Transaction", "PhotoArticleTitle");
        end
        -- Search when opened if autoSearch is true
		if settings.AutoSearch then
			if settings.Article == false then
				if settings.WhichGoogle=="Books" then
					GoogleBookSearch();
				elseif settings.WhichGoogle=="Scholar" then
					GoogleScholarSearch();
				else
					GoogleSearch();
				end
			else
				if settings.WhichGoogle=="Standard" then
					GoogleSearch();
				elseif GetFieldValue("Transaction", "RequestType") == "Loan" then
					GoogleBookSearch();
				else
					GoogleScholarSearch();
				end
			end
		end
	end
end

function GoogleScholarSearch()
	googleSearchForm.Browser:Navigate("http://scholar.google.com/scholar?q=" .. AtlasHelpers.UrlEncode(settings.SearchText));	
	googleSearchForm.URLBox.Value="http://scholar.google.com/scholar?q=" .. AtlasHelpers.UrlEncode(settings.SearchText);
end

function GoogleBookSearch()
	googleSearchForm.Browser:Navigate("http://books.google.com/books?q=" .. AtlasHelpers.UrlEncode(settings.SearchText));	
	googleSearchForm.URLBox.Value="http://books.google.com/books?q=" .. AtlasHelpers.UrlEncode(settings.SearchText);
end

function GoogleSearch()
	googleSearchForm.Browser:Navigate("http://www.google.com/search?q=" .. AtlasHelpers.UrlEncode(settings.SearchText));	
	googleSearchForm.URLBox.Value="http://google.com/search?q=" .. AtlasHelpers.UrlEncode(settings.SearchText);
end

function OpenInDefaultBrowser()
	local currentUrl = googleSearchForm.Browser.Address;
	
	if (currentUrl and currentUrl ~= "")then
		LogDebug("Opening Browser URL in default browser: " .. currentUrl);

		local process = Types["Process"]();
		process.StartInfo.FileName = currentUrl;
		process.StartInfo.UseShellExecute = true;
		process:Start();
	end
end

