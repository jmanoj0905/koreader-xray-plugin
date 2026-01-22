-- AIHelper - Google Gemini & ChatGPT for X-Ray
local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("json")
local logger = require("logger")

local AIHelper = {}

-- AI Provider settings (default values)
AIHelper.providers = {
    gemini = {
        name = "Google Gemini",
        enabled = true,
        api_key = nil,
        model = "gemini-2.5-flash", -- Default model
    },
    chatgpt = {
        name = "ChatGPT",
        enabled = true,
        api_key = nil,
        endpoint = "https://api.openai.com/v1/chat/completions",
        model = "gpt-4o-mini", -- Varsayılan model (uygun maliyet/performans)
    }
}

-- Set Gemini model
function AIHelper:setGeminiModel(model_name)
    if not model_name or #model_name == 0 then return false end
    self.providers.gemini.model = model_name
    self:saveModelToConfig(model_name)
    return true
end

-- Set ChatGPT model
function AIHelper:setChatGPTModel(model_name)
    if not model_name or #model_name == 0 then return false end
    self.providers.chatgpt.model = model_name
    self:saveModelToConfig(model_name, "chatgpt")
    return true
end

-- Set default provider 
function AIHelper:setDefaultProvider(provider_name)
    if not provider_name or (provider_name ~= "gemini" and provider_name ~= "chatgpt") then 
        return false 
    end
    self.default_provider = provider_name
    self:saveProviderToConfig(provider_name)
    logger.info("AIHelper: Default provider changed to:", provider_name)
    return true
end

-- Save model preference to config file
function AIHelper:saveModelToConfig(model_name, provider)
    provider = provider or "gemini"
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)
    
    local model_file = xray_dir .. "/" .. provider .. "_model.txt"
    local file = io.open(model_file, "w")
    if file then
        file:write(model_name)
        file:close()
        return true
    end
    return false
end

-- Save provider preference to config file 
function AIHelper:saveProviderToConfig(provider_name)
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)
    
    local provider_file = xray_dir .. "/default_provider.txt"
    local file = io.open(provider_file, "w")
    if file then
        file:write(provider_name)
        file:close()
        logger.info("AIHelper: Saved default provider:", provider_name)
        return true
    end
    logger.warn("AIHelper: Failed to save provider preference")
    return false
end

-- Initialize AIHelper
function AIHelper:init()
    self:loadConfig()
    self:loadModelFromFile()
    self:loadLanguage()
    logger.info("AIHelper: Initialized with Gemini model:", self.providers.gemini.model)
    logger.info("AIHelper: ChatGPT model:", self.providers.chatgpt.model)
end

-- Load configuration
function AIHelper:loadConfig()
    local success, config = pcall(require, "config")
    if success and config then
        if config.gemini_api_key then self.providers.gemini.api_key = config.gemini_api_key end
        if config.gemini_model then self.providers.gemini.model = config.gemini_model end
        if config.chatgpt_api_key then self.providers.chatgpt.api_key = config.chatgpt_api_key end
        if config.chatgpt_model then self.providers.chatgpt.model = config.chatgpt_model end
        if config.default_provider then self.default_provider = config.default_provider end
        if config.settings then self.settings = config.settings end
    end
end

-- Load model preference
function AIHelper:loadModelFromFile()
    local DataStorage = require("datastorage")
    
    -- Gemini model
    local gemini_file = DataStorage:getSettingsDir() .. "/xray/gemini_model.txt"
    local file = io.open(gemini_file, "r")
    if file then
        local model = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if model and #model > 0 then
            self.providers.gemini.model = model
        end
    end
    
    -- ChatGPT model
    local chatgpt_file = DataStorage:getSettingsDir() .. "/xray/chatgpt_model.txt"
    file = io.open(chatgpt_file, "r")
    if file then
        local model = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if model and #model > 0 then
            self.providers.chatgpt.model = model
        end
    end
    
    -- Default provider (YENI)
    local provider_file = DataStorage:getSettingsDir() .. "/xray/default_provider.txt"
    file = io.open(provider_file, "r")
    if file then
        local provider = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if provider and (provider == "gemini" or provider == "chatgpt") then
            self.default_provider = provider
            logger.info("AIHelper: Loaded default provider from file:", provider)
        end
    end
        -- Gemini API Key
    local gemini_key_file = DataStorage:getSettingsDir() .. "/xray/gemini_api_key.txt"
    file = io.open(gemini_key_file, "r")
    if file then
        local key = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if key and #key > 0 then
            self.providers.gemini.api_key = key
            logger.info("AIHelper: Loaded Gemini API key from file")
        end
    end
    
    -- ChatGPT API Key
    local chatgpt_key_file = DataStorage:getSettingsDir() .. "/xray/chatgpt_api_key.txt"
    file = io.open(chatgpt_key_file, "r")
    if file then
        local key = file:read("*a"):match("^%s*(.-)%s*$")
        file:close()
        if key and #key > 0 then
            self.providers.chatgpt.api_key = key
            logger.info("AIHelper: Loaded ChatGPT API key from file")
        end
    end
end


-- Save API Key preference to file
function AIHelper:saveAPIKeyToFile(provider, api_key)
    local DataStorage = require("datastorage")
    local settings_dir = DataStorage:getSettingsDir()
    local xray_dir = settings_dir .. "/xray"
    local lfs = require("libs/libkoreader-lfs")
    lfs.mkdir(xray_dir)
    
    local key_file = xray_dir .. "/" .. provider .. "_api_key.txt"
    local file = io.open(key_file, "w")
    if file then
        file:write(api_key)
        file:close()
        logger.info("AIHelper: Saved", provider, "API key to file")
        return true
    end
    logger.warn("AIHelper: Failed to save", provider, "API key")
    return false
end

-- Get book data from AI
function AIHelper:getBookData(title, author, provider_name, context)
    self:loadModelFromFile() -- Refresh model
    local provider = provider_name or "gemini"
    local provider_config = self.providers[provider]
    
    if not provider_config or not provider_config.api_key then
        return nil, "error_no_api_key"
    end
    
    -- Context ile prompt oluştur
    local prompt = self:createPrompt(title, author, context)
    
    logger.info("AIHelper: Using provider:", provider, "Model:", provider_config.model)
    if context and context.spoiler_free then
        logger.info("AIHelper: Spoiler-free mode active, reading:", context.reading_percent, "%")
    end
    
    if provider == "gemini" then
        return self:callGemini(prompt, provider_config)
    elseif provider == "chatgpt" then
        return self:callChatGPT(prompt, provider_config)
    end
    return nil, "error_unknown_provider"
end

-- Check network
function AIHelper:checkNetworkConnectivity()
    local socket = require("socket")
    local success, err = pcall(function()
        local tcp = socket.tcp()
        tcp:settimeout(3)
        local result = tcp:connect("8.8.8.8", 53)
        tcp:close()
        return result
    end)
    return success
end

-- Load language
function AIHelper:loadLanguage()
    local DataStorage = require("datastorage")
    local f = io.open(DataStorage:getSettingsDir() .. "/xray/language.txt", "r")
    self.current_language = f and f:read("*a"):match("^%s*(.-)%s*$") or "en"
    if f then f:close() end
    self:loadPrompts()
end

-- Load prompts
function AIHelper:loadPrompts()
    local success, prompts = pcall(require, "prompts/" .. self.current_language)
    if not success then
        success, prompts = pcall(require, "prompts/en")
    end
    self.prompts = prompts or {}
end

-- Create prompt
function AIHelper:createPrompt(title, author, context)
    if not self.prompts then self:loadLanguage() end

    -- Get language-appropriate fallback for unknown author
    local strings = self:getFallbackStrings()
    local unknown_author = strings.unknown_author or "Unknown"

    -- Use spoiler-free prompt if context indicates it
    if context and context.spoiler_free then
        local template = self.prompts.spoiler_free or self.prompts.main
        return string.format(template, title, author or unknown_author, context.reading_percent)
    else
        -- Full book prompt
        local template = self.prompts.main
        return string.format(template, title, author or unknown_author)
    end
end

function AIHelper:getFallbackStrings()
    if not self.prompts then self:loadPrompts() end
    return self.prompts.fallback or {}
end

-- Call Google Gemini API (FIXED VERSION)
function AIHelper:callGemini(prompt, config)
    logger.info("AIHelper: Calling Google Gemini API")
    
    if not self:checkNetworkConnectivity() then
        return nil, "error_no_network", "No internet connection"
    end
    
    local model = config.model or "gemini-2.5-flash"
    local url = "https://generativelanguage.googleapis.com/v1beta/models/" .. model .. ":generateContent?key=" .. config.api_key
    
    -- GÜVENLİK FİLTRELERİNİ KAPAT (Dostoyevski vb. için şart)
    local safety_settings = {
        { category = "HARM_CATEGORY_HARASSMENT", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_HATE_SPEECH", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold = "BLOCK_NONE" },
        { category = "HARM_CATEGORY_DANGEROUS_CONTENT", threshold = "BLOCK_NONE" }
    }

    local request_body = json.encode({
        contents = {{ parts = {{ text = prompt }} }},
        safetySettings = safety_settings,
        generationConfig = {
            temperature = 0.0,  -- Deterministic output for consistency
            topK = 1,           -- Only most likely token for consistency
            topP = 1.0,         -- Disable nucleus sampling for consistency
            maxOutputTokens = 8192,
            responseMimeType = "application/json" -- JSON Modu
        }
    })
    
    -- RETRY LOGIC with exponential backoff
    local max_retries = 3
    for attempt = 1, max_retries + 1 do
        if attempt > 1 then
             local socket = require("socket")
             local wait_time = 3 * attempt  -- Exponential backoff: 3, 6, 9 seconds
             logger.info("AIHelper: Retrying Gemini request (attempt " .. attempt .. "), waiting " .. wait_time .. "s")
             socket.sleep(wait_time)
        end

        local response_body = {}
        local res, code, headers, status = https.request{
            url = url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#request_body),
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
            timeout = 120
        }

        local response_text = table.concat(response_body)
        local code_num = tonumber(code)

        logger.info("AIHelper: API Code:", code_num, "Length:", #response_text)

        if code_num == 200 then
            local success, data = pcall(json.decode, response_text)
            if not success then return nil, "error_json_parse" end

            -- CRASH PROTECTION: Null check
            if data and data.candidates and data.candidates[1] then
                local candidate = data.candidates[1]

                -- Blocked by safety filter?
                if candidate.finishReason == "SAFETY" then
                     logger.warn("AIHelper: BLOCKED BY SAFETY FILTER")
                     return nil, "error_safety", "Blocked by Google Safety Filter."
                end

                if candidate.content and candidate.content.parts and candidate.content.parts[1] then
                    return self:parseAIResponse(candidate.content.parts[1].text)
                else
                    logger.warn("AIHelper: No text in response")
                    return nil, "error_api", "API returned empty response."
                end
            else
                return nil, "error_api", "Invalid response format"
            end
        elseif code_num == 503 or code_num == 502 or code_num == 500 then
             logger.warn("AIHelper: " .. code_num .. " Service Error (Retrying...)")
        else
             return nil, "error_" .. tostring(code_num), "Error Code: " .. tostring(code_num)
        end
    end

    return nil, "error_timeout", "Request timed out"
end

-- Call ChatGPT API (COMPLETE IMPLEMENTATION)
function AIHelper:callChatGPT(prompt, config)
    logger.info("AIHelper: Calling ChatGPT API")
    
    if not self:checkNetworkConnectivity() then
        return nil, "error_no_network", "No internet connection"
    end
    
    local model = config.model or "gpt-4o-mini"
    local url = config.endpoint or "https://api.openai.com/v1/chat/completions"
    
    -- System instruction ekle (eğer prompts'ta varsa)
    local system_instruction = self.prompts and self.prompts.system_instruction or 
        "You are an expert literary critic. Respond ONLY with valid JSON format."
    
    local request_body = json.encode({
        model = model,
        messages = {
            {
                role = "system",
                content = system_instruction
            },
            {
                role = "user",
                content = prompt
            }
        },
        temperature = 0.0,      -- Deterministic output for consistency
        max_tokens = 8192,
        top_p = 1.0,            -- Disable nucleus sampling for consistency
        seed = 42,              -- Fixed seed for reproducibility
        response_format = { type = "json_object" } -- JSON mode zorla
    })
    
    logger.info("AIHelper: ChatGPT request size:", #request_body)
    
    -- RETRY LOGIC with exponential backoff
    local max_retries = 3
    for attempt = 1, max_retries + 1 do
        if attempt > 1 then
             local socket = require("socket")
             local wait_time = 3 * attempt  -- Exponential backoff: 3, 6, 9 seconds
             logger.info("AIHelper: Retrying ChatGPT request (attempt " .. attempt .. "), waiting " .. wait_time .. "s")
             socket.sleep(wait_time)
        end

        local response_body = {}
        local res, code, headers, status = https.request{
            url = url,
            method = "POST",
            headers = {
                ["Content-Type"] = "application/json",
                ["Authorization"] = "Bearer " .. config.api_key,
                ["Content-Length"] = tostring(#request_body),
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
            timeout = 120
        }

        local response_text = table.concat(response_body)
        local code_num = tonumber(code)

        logger.info("AIHelper: ChatGPT API Code:", code_num, "Length:", #response_text)

        if code_num == 200 then
            local success, data = pcall(json.decode, response_text)
            if not success then
                logger.warn("AIHelper: JSON parse error")
                return nil, "error_json_parse"
            end

            -- CRASH PROTECTION: OpenAI response structure
            if data and data.choices and data.choices[1] then
                local choice = data.choices[1]

                -- Content filter check
                if choice.finish_reason == "content_filter" then
                    logger.warn("AIHelper: BLOCKED BY CONTENT FILTER")
                    return nil, "error_safety", "Blocked by OpenAI content filter."
                end

                if choice.message and choice.message.content then
                    local content = choice.message.content
                    logger.info("AIHelper: ChatGPT response received, parsing...")
                    return self:parseAIResponse(content)
                else
                    logger.warn("AIHelper: No content in ChatGPT response")
                    return nil, "error_api", "API returned empty response."
                end
            else
                -- Log error message if present
                if data and data.error then
                    logger.warn("AIHelper: ChatGPT API Error:", data.error.message or "Unknown")
                    return nil, "error_api", data.error.message or "API Error"
                end
                return nil, "error_api", "Invalid response format"
            end
        elseif code_num == 429 then
            logger.warn("AIHelper: 429 Rate Limit (Retrying...)")
            -- Wait longer for rate limit
            if attempt <= max_retries then
                local socket = require("socket")
                socket.sleep(5 * attempt)
            end
        elseif code_num == 503 or code_num == 502 or code_num == 500 then
            logger.warn("AIHelper: " .. code_num .. " Service Error (Retrying...)")
        elseif code_num == 401 then
            return nil, "error_401", "Invalid API key"
        else
            logger.warn("AIHelper: Unexpected error code:", code_num)
            return nil, "error_" .. tostring(code_num), "Error Code: " .. tostring(code_num)
        end
    end

    return nil, "error_timeout", "Request timed out"
end

function AIHelper:parseAIResponse(text)
    -- Temizlik
    local json_text = text:gsub("```json", ""):gsub("```", ""):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Parse
    local success, data = pcall(json.decode, json_text)
    
    -- Eğer başarısızsa, {} arasını bulmaya çalış
    if not success then
        local first = json_text:find("{")
        local last_brace = nil
        for i = #json_text, 1, -1 do
            if json_text:sub(i,i) == "}" then last_brace = i; break end
        end
        if first and last_brace then
             json_text = json_text:sub(first, last_brace)
             success, data = pcall(json.decode, json_text)
        end
    end

    if success and data then
        return self:validateAndCleanData(data)
    end
    return nil
end

function AIHelper:validateAndCleanData(data)
    -- Type validation - data must be a table
    if type(data) ~= "table" then
        logger.warn("AIHelper: validateAndCleanData received non-table:", type(data))
        return nil
    end

    local strings = self:getFallbackStrings()

    -- Helper to ensure string value with fallback
    local function ensureString(v, d)
        return (type(v) == "string" and #v > 0) and v or d or ""
    end

    -- Helper to get field value with case-insensitive fallback (type-safe)
    local function getField(obj, ...)
        if type(obj) ~= "table" then return nil end
        local keys = {...}
        for _, key in ipairs(keys) do
            if obj[key] ~= nil then return obj[key] end
            -- Try lowercase version
            local lower_key = string.lower(key)
            if obj[lower_key] ~= nil then return obj[lower_key] end
            -- Try capitalized version
            local cap_key = key:sub(1,1):upper() .. key:sub(2)
            if obj[cap_key] ~= nil then return obj[cap_key] end
        end
        return nil
    end

    -- 1. AUTHOR & BOOK (Smart matching with case handling)
    data.book_title = getField(data, "book_title", "title", "bookTitle") or strings.unknown_book
    data.author = getField(data, "author", "book_author", "Author") or strings.unknown_author
    data.author_bio = getField(data, "author_bio", "authorBio", "AuthorBio", "bio") or ""
    data.summary = getField(data, "summary", "book_summary", "Summary") or ""

    -- 2. CHARACTERS (Standardized field extraction with relationships)
    local chars = getField(data, "characters", "Characters") or {}
    local valid_chars = {}
    for _, c in ipairs(chars) do
        if type(c) == "table" then
            -- Extract relationships
            local relationships_raw = getField(c, "relationships", "Relationships") or {}
            local valid_relationships = {}
            if type(relationships_raw) == "table" then
                for _, rel in ipairs(relationships_raw) do
                    if type(rel) == "table" then
                        local rel_char = getField(rel, "character", "name", "Character")
                        local rel_type = getField(rel, "relation", "relationship", "type", "Relation")
                        if rel_char and rel_type then
                            table.insert(valid_relationships, {
                                character = ensureString(rel_char, ""),
                                relation = ensureString(rel_type, "")
                            })
                        end
                    end
                end
            end

            table.insert(valid_chars, {
                name = ensureString(getField(c, "name", "Name", "character_name"), strings.unnamed_character),
                role = ensureString(getField(c, "role", "Role", "character_role"), strings.not_specified),
                description = ensureString(getField(c, "description", "Description", "desc"), strings.no_description),
                gender = ensureString(getField(c, "gender", "Gender"), ""),
                occupation = ensureString(getField(c, "occupation", "Occupation", "job"), ""),
                relationships = valid_relationships
            })
        end
    end
    data.characters = valid_chars

    -- 3. HISTORICAL FIGURES (Standardized field extraction)
    local hists = getField(data, "historical_figures", "historicalFigures", "historical") or {}
    local valid_hists = {}
    for _, h in ipairs(hists) do
        if type(h) == "table" then
            table.insert(valid_hists, {
                name = ensureString(getField(h, "name", "Name"), strings.unnamed_person),
                biography = ensureString(getField(h, "biography", "Biography", "bio"), strings.no_biography),
                role = ensureString(getField(h, "role", "Role"), ""),
                birth_year = getField(h, "birth_year", "birthYear", "born"),
                death_year = getField(h, "death_year", "deathYear", "died"),
                importance_in_book = ensureString(getField(h, "importance_in_book", "importance", "importanceInBook"), "Referenced in book"),
                context_in_book = ensureString(getField(h, "context_in_book", "context", "contextInBook"), "Historical reference")
            })
        end
    end
    data.historical_figures = valid_hists

    -- 4. LOCATIONS (Standardized)
    local locs = getField(data, "locations", "Locations") or {}
    local valid_locs = {}
    for _, loc in ipairs(locs) do
        if type(loc) == "table" then
            table.insert(valid_locs, {
                name = ensureString(getField(loc, "name", "Name"), "Unknown Location"),
                description = ensureString(getField(loc, "description", "Description"), ""),
                importance = ensureString(getField(loc, "importance", "Importance", "significance"), "")
            })
        end
    end
    data.locations = valid_locs

    -- 5. THEMES (Standardized - can be array of strings or objects)
    local themes_raw = getField(data, "themes", "Themes") or {}
    local valid_themes = {}
    if type(themes_raw) == "table" then
        for _, theme in ipairs(themes_raw) do
            if type(theme) == "string" and #theme > 0 then
                table.insert(valid_themes, theme)
            elseif type(theme) == "table" then
                -- Handle object format: {name: "theme", description: "..."}
                local theme_name = getField(theme, "name", "theme", "title")
                if type(theme_name) == "string" and #theme_name > 0 then
                    table.insert(valid_themes, theme_name)
                end
            end
        end
    end
    data.themes = valid_themes

    -- 6. TIMELINE (Standardized with story_phase and summary)
    local timeline = getField(data, "timeline", "Timeline", "events") or {}
    local valid_timeline = {}
    for _, event in ipairs(timeline) do
        if type(event) == "table" then
            -- Validate characters array
            local event_chars = getField(event, "characters", "Characters") or {}
            local valid_event_chars = {}
            if type(event_chars) == "table" then
                for _, char_name in ipairs(event_chars) do
                    if type(char_name) == "string" and #char_name > 0 then
                        table.insert(valid_event_chars, char_name)
                    end
                end
            end

            table.insert(valid_timeline, {
                event = ensureString(getField(event, "event", "Event", "title"), ""),
                chapter = ensureString(getField(event, "chapter", "Chapter"), ""),
                importance = ensureString(getField(event, "importance", "Importance", "significance"), ""),
                story_phase = ensureString(getField(event, "story_phase", "storyPhase", "phase"), ""),
                summary = ensureString(getField(event, "summary", "Summary", "description"), ""),
                characters = valid_event_chars
            })
        end
    end
    data.timeline = valid_timeline

    return data
end

function AIHelper:setAPIKey(provider, api_key)
    if self.providers[provider] then
        self.providers[provider].api_key = api_key:gsub("%s+", "")
        self:saveAPIKeyToFile(provider, api_key)
        return true
    end
    return false
end

function AIHelper:testAPIKey(provider)
    local provider_config = self.providers[provider]
    
    if not provider_config then
        return false, "Unknown provider"
    end
    
    if not provider_config.api_key or #provider_config.api_key == 0 then
        return false, "AI API Key not set"
    end
    
    if not self:checkNetworkConnectivity() then
        return false, "No internet connection!"
    end
    
    logger.info("AIHelper: Testing", provider, "API key")
    
    local test_prompt = "Test: 'OK'"
    
    if provider == "gemini" then
        local result, error_code, error_msg = self:callGemini(test_prompt, provider_config)
        if result then
            return true, "Success"
        else
            return false, error_msg or ("Error: " .. (error_code or "Unknown"))
        end
        
    elseif provider == "chatgpt" then
        local result, error_code, error_msg = self:callChatGPT(test_prompt, provider_config)
        if result then
            return true, "Success"
        else
            return false, error_msg or ("Error: " .. (error_code or "Unknown"))
        end
    end
    
    return false, "Unsupported provider"
end

return AIHelper
