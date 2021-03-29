-- About GoogleCombined.lua (version 2.6, 3/29/2021)
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
settings.WhichGoogle = GetSetting("WhichGoogle");
settings.Article = GetSetting("Article");

local interfaceMngr = nil;
local SearchForm = {};

SearchForm.Form = nil;
SearchForm.Browser = nil;
SearchForm.RibbonPage = nil;
SearchForm.Google= nil;
SearchForm.GoogleScholar= nil;
SearchForm.GoogleBooks= nil;
SearchForm.URLBox = nil;

require "Atlas.AtlasHelpers";


function Init()
        interfaceMngr = GetInterfaceManager();
 
        -- Create a form
        SearchForm.Form = interfaceMngr:CreateForm("Google Search", "Script");
        -- Add a browser
        SearchForm.Browser = SearchForm.Form:CreateBrowser("Google Search", "Google Search Browser", "Google Search", "Chromium");
        -- Hide the text label
        SearchForm.Browser.TextVisible = false;
		
 
        -- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method.  
		-- We can retrieve that one and add our buttons to it.
        SearchForm.RibbonPage = SearchForm.Form:GetRibbonPage("Google Search");

        -- Create the buttons
        SearchForm.Google= SearchForm.RibbonPage:CreateButton("Search Google", GetClientImage("Search32"), "GoogleSearch", "Google Combined Search");
        SearchForm.GoogleScholar= SearchForm.RibbonPage:CreateButton("Search Google Scholar", GetClientImage("Search32"), "GoogleScholarSearch", "Google Combined Search");
        SearchForm.GoogleBooks= SearchForm.RibbonPage:CreateButton("Search Google Books", GetClientImage("Search32"), "GoogleBookSearch", "Google Combined Search");
		SearchForm.RibbonPage:CreateButton("Open New Browser", GetClientImage("Web32"), "OpenInDefaultBrowser", "Utility");

        -- Hide buttons for Loan/Article
        if GetFieldValue("Transaction", "RequestType") == "Loan" then
            -- SearchForm.GoogleScholar.BarButton.Enabled = false;
            settings.SearchText = GetFieldValue("Transaction", "LoanTitle");
        else
            -- SearchForm.GoogleBooks.BarButton.Enabled = false;
            settings.SearchText = GetFieldValue("Transaction", "PhotoArticleTitle");
        end
        -- After we add all of our buttons and form elements, we can show the form.
        SearchForm.Form:Show();

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


function GoogleScholarSearch()
	SearchForm.Browser:RegisterPageHandler("custom", "URLChanged", "URLSet", true);
	SearchForm.Browser:Navigate("http://scholar.google.com/scholar?q=" .. AtlasHelpers.UrlEncode(settings.SearchText));
end

function GoogleBookSearch()
	SearchForm.Browser:RegisterPageHandler("custom", "URLChanged", "URLSet", true);
	SearchForm.Browser:Navigate("http://books.google.com/books?q=" .. AtlasHelpers.UrlEncode(settings.SearchText));
end

function GoogleSearch()
	SearchForm.Browser:RegisterPageHandler("custom", "URLChanged", "URLSet", true);
	SearchForm.Browser:Navigate("http://google.com/search?q=" .. AtlasHelpers.UrlEncode(settings.SearchText));
end

function OpenInDefaultBrowser()
	local currentUrl = SearchForm.Browser.Address;
	
	if (currentUrl and currentUrl ~= "")then
		LogDebug("Opening Browser URL in default browser: " .. currentUrl);

		local process = Types["Process"]();
		process.StartInfo.FileName = currentUrl;
		process.StartInfo.UseShellExecute = true;
		process:Start();
	end
end
