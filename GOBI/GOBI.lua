-- About GOBI.lua
-- IDS Project, Mark Sullivan, sullivm@geneseo.edu
-- GOBI.lua does an GOBI search for the ISBN or Title for loans.
-- scriptActive must be set to true for the script to run.
--
-- 2.1 UPDATE by Andrew Morgan, emeraldflarexii@hotmail.com/Pages/Login
-- Converted to use the Chromium browser.
-- Cleaned up some settings and added a setting to choose which field to import the price.


local settings = {};
settings.Email= GetSetting("Email");
settings.password= GetSetting("Password");
settings.pricefield = GetSetting("PriceField");

local interfaceMngr = nil;
local GOBISearchForm = {};
GOBISearchForm.Form = nil;
GOBISearchForm.Browser = nil;
GOBISearchForm.RibbonPage = nil;

require "Atlas.AtlasHelpers";

function Init()
	if GetFieldValue("Transaction", "RequestType") == "Loan" then
		interfaceMngr = GetInterfaceManager();
		--Create Form
		GOBISearchForm.Form = interfaceMngr:CreateForm("GOBI", "Script");
		 -- Create browser
		if (WebView2Enabled()) then
			GOBISearchForm.Browser = GOBISearchForm.Form:CreateBrowser("GOBI Search", "GOBI Search Browser", "GOBI Search", "WebView2");
		else
			GOBISearchForm.Browser = GOBISearchForm.Form:CreateBrowser("GOBI Search", "GOBI Search Browser", "GOBI Search", "Chromium");
		end-- Hide the text label
		GOBISearchForm.Browser.TextVisible = false;

		-- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method.  We can retrieve that one and add our buttons to it.
		GOBISearchForm.RibbonPage = GOBISearchForm.Form:GetRibbonPage("GOBI Search");
		-- Imports price from first Item in list.  
		GOBISearchForm.RibbonPage:CreateButton("Search ISBN", GetClientImage("Search32"), "SearchISBN", "GOBI Search");
		GOBISearchForm.RibbonPage:CreateButton("Search Title", GetClientImage("Search32"), "SearchTitle", "GOBI Search");
		GOBISearchForm.RibbonPage:CreateButton("Import Price", GetClientImage("Search32"), "PullPrice", "GOBI Search");
	   
		GOBISearchForm.Form:Show();
		
		Search();
	end
end

function Search()
	GOBISearchForm.Browser:RegisterPageHandler("formExists", "loginForm", "GOBILoaded", false);
	GOBISearchForm.Browser:Navigate("http://www.gobi3.com/Pages/Login.aspx");	
end

function GOBILoaded()
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('guser').value = '" .. settings.Email .. "'");
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('gpword').value = '" .. settings.password .. "'");
	GOBISearchForm.Browser:ExecuteScript("document.forms['loginForm'].submit()");

	GOBISearchForm.Browser:RegisterPageHandler("formExists", "basicsearchform", "StartSearch", false);
end

function loadStandardSearch()
  GOBISearchForm.Browser:RegisterPageHandler("formExists", "frmMain", "StartSearch", false);
  GOBISearchForm.Browser:Navigate("http://www.gobi3.com/hx/gobi.ashx?location=searchstandardparms");
end


function StartSearch()
	local isXn = GetFieldValue("Transaction", "ISSN");
	if isXn:len()<8 then
		SearchTitle()
	else
		SearchISBN()
	end
end

function SearchISBN()
	local isbn = GetFieldValue("Transaction", "ISSN");
	
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('basicsearchinputtype').value = 'Isbn'");
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('basicsearchinput').value = '" .. isbn .. "'");
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('basicsearchsubmit').click()");
end

function SearchTitle()
	local title = GetFieldValue("Transaction", "LoanTitle");

	GOBISearchForm.Browser:ExecuteScript("document.getElementById('basicsearchinputtype').value = 'Title'");
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('basicsearchinputmode').value = 'AdvancedAll'");
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('basicsearchinput').value = '" .. title .. "'");
	GOBISearchForm.Browser:ExecuteScript("document.getElementById('basicsearchsubmit').click()");
end

function PullPrice()
  
	local doctext = GOBISearchForm.Browser:EvaluateScript("document.documentElement.outerHTML").Result;
	interfaceMngr:ShowMessage(doctext, "Test1");
	local selected = doctext:match('class="focused".-Item Key:'):gsub('class="focused"', ''):gsub('Item Key:', '');
	local price = selected:match('class="US%-List" data%-currencyamount="[^"]+'):gsub('class="US%-List" data%-currencyamount="', ""):gsub('"', '');
	price = price:gsub("%s", "");
	interfaceMngr:ShowMessage(price, "Test1");

	--SetFieldValue("Transaction", settings.pricefield, price);
	--ExecuteCommand("Save", "Transaction");
	--ExecuteCommand("SwitchTab", "Detail");
end
function WebView2Enabled()
    return AddonInfo.Browsers ~= nil and AddonInfo.Browsers.WebView2 ~= nil and AddonInfo.Browsers.WebView2 == true;
end
