local M = {}

local ns_id = vim.api.nvim_create_namespace("GhostAIVirtualText")
local current_suggestion = nil

-- ==========================================
-- YAPILANDIRMA VE SAĞLAYICILAR (ADAPTERS)
-- ==========================================
M.config = {
    -- Hangi LLM kullanılacak? "minimax" veya "ollama" yazabilirsin.
    active_provider = "minimax", 
    
    providers = {
        ollama = {
            url = "http://localhost:11434/api/generate",
            model = "qwen2.5-coder:1.5b"
        },
        minimax = {
            url = "https://api.minimax.io/v1/text/chatcompletion_v2",
            model = "MiniMax-M2.7",
            api_key = os.getenv("MINIMAX_API_KEY") -- Terminalden export ile alınır
        }
    }
}

local function log_info(msg)
    vim.notify("[Ghost AI] " .. msg, vim.log.levels.INFO)
end

local function log_error(msg)
    vim.notify("[Ghost AI Error] " .. msg, vim.log.levels.ERROR)
end

-- ==========================================
-- KESİŞİM TEMİZLEYİCİ (OVERLAP DETECTOR)
-- ==========================================
local function clean_overlap(prefix, suggestion)
    -- LLM'in ürettiği metnin başı ile, imleçten önceki metnin sonu çakışıyorsa temizler.
    -- Modelin "std::co" üzerine "cout" önermesi durumunda "co"yu siler.
    local max_overlap = math.min(#prefix, #suggestion)
    
    for i = max_overlap, 1, -1 do
        local prefix_end = string.sub(prefix, -i)
        local suggestion_start = string.sub(suggestion, 1, i)
        
        if prefix_end == suggestion_start then
            return string.sub(suggestion, i + 1)
        end
    end
    
    return suggestion
end

local function get_context()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] - 1
    local col = cursor[2]

    -- KURAL 1: Hedef (Objective) Kılavuzu
    local top_lines = vim.api.nvim_buf_get_lines(bufnr, 0, 15, false)
    local header_context = table.concat(top_lines, "\n")

    -- KURAL 2: Bağlam (Context) Penceresi - Üst/Alt 50 satır
    local start_row = math.max(0, row - 50)
    local end_row = row + 50
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

    local cursor_line_idx = row - start_row + 1
    local current_line = lines[cursor_line_idx]
    
    local prefix = string.sub(current_line, 1, col)
    local suffix = string.sub(current_line, col + 1)
    
    lines[cursor_line_idx] = prefix .. "<CURSOR>" .. suffix
    local code_content = table.concat(lines, "\n")

    return header_context, code_content, row, col
end

local function render_ghost_text(text, row, col)
    M.clear_ghost_text()
    if not text or text == "" then return end

    local bufnr = vim.api.nvim_get_current_buf()
    local lines = {}
    for s in text:gmatch("[^\r\n]+") do
        table.insert(lines, s)
    end

    if #lines == 0 then return end

    current_suggestion = { text = text, row = row, col = col, lines = lines }

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
        virt_text = { { lines[1], "Comment" } },
        virt_text_pos = "inline",
        hl_mode = "combine",
    })

    if #lines > 1 then
        local virt_lines = {}
        for i = 2, #lines do
            table.insert(virt_lines, { { lines[i], "Comment" } })
        end
        vim.api.nvim_buf_set_extmark(bufnr, ns_id, row, col, {
            virt_lines = virt_lines,
        })
    end
end

function M.clear_ghost_text()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    current_suggestion = nil
end

function M.accept_ghost_text()
    if not current_suggestion then return false end
    
    local bufnr = vim.api.nvim_get_current_buf()
    local row = current_suggestion.row
    local col = current_suggestion.col

    local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local prefix = string.sub(current_line, 1, col)
    local suffix = string.sub(current_line, col + 1)

    local new_lines = {}
    for i, line in ipairs(current_suggestion.lines) do
        new_lines[i] = line
    end

    new_lines[1] = prefix .. new_lines[1]
    new_lines[#new_lines] = new_lines[#new_lines] .. suffix

    vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, new_lines)

    local end_row = row + #new_lines - 1
    local end_col = string.len(current_suggestion.lines[#new_lines])
    if #new_lines == 1 then
        end_col = col + string.len(current_suggestion.lines[1])
    end
    
    vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })

    M.clear_ghost_text()
    log_info("Öneri kabul edildi.")
    
    vim.cmd("startinsert")
    return true
end

function M.request_autocomplete()
    local header_context, code_context, row, col = get_context()
    local provider_name = M.config.active_provider
    local provider = M.config.providers[provider_name]
    
    local bufnr = vim.api.nvim_get_current_buf()
    local current_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    local prefix = string.sub(current_line, 1, col)

    local system_prompt = "You are a pure-logic code autocomplete engine.\n" ..
                          "CRITICAL INSTRUCTION 1: Read the 'FILE OBJECTIVE' below. This is the top of the file containing the expected JSON return format and rules.\n" ..
                          "CRITICAL INSTRUCTION 2: Read the 'CURRENT CONTEXT'. Find the <CURSOR>.\n" ..
                          "CRITICAL INSTRUCTION 3: Return ONLY the raw code (max 50 words) that replaces <CURSOR>. No markdown, no explanations, no prefix/suffix repetition.\n\n" ..
                          "=== FILE OBJECTIVE (TOP LINES) ===\n" ..
                          header_context .. "\n" ..
                          "==================================\n"

    local curl_args = { "curl", "-s", "-X", "POST", provider.url, "-H", "Content-Type: application/json" }
    local payload = {}

    if provider_name == "minimax" then
        if not provider.api_key or provider.api_key == "" then
            log_error("MiniMax API Key eksik. Terminalden 'export MINIMAX_API_KEY=...' yapmalısın.")
            return
        end
        table.insert(curl_args, "-H")
        table.insert(curl_args, "Authorization: Bearer " .. provider.api_key)
        
        payload = {
            model = provider.model,
            messages = {
                { role = "system", content = system_prompt },
                { role = "user", content = "=== CURRENT CONTEXT ===\n" .. code_context }
            }
        }
    elseif provider_name == "ollama" then
        payload = {
            model = provider.model,
            prompt = system_prompt .. "\n=== CURRENT CONTEXT ===\n" .. code_context,
            stream = false,
            options = { temperature = 0.0, num_predict = 75 }
        }
    else
        log_error("Geçersiz sağlayıcı: " .. provider_name)
        return
    end

    table.insert(curl_args, "-d")
    table.insert(curl_args, vim.fn.json_encode(payload))
    
    log_info(provider_name:upper() .. " servisine istek gönderiliyor...")

    vim.fn.jobstart(curl_args, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if not data or #data == 0 or data[1] == "" then return end
            local response_str = table.concat(data, "")
            
            local ok, parsed = pcall(vim.fn.json_decode, response_str)
            if not ok or not parsed then
                log_error("JSON Parse hatası.")
                return
            end

            local content = ""
            if provider_name == "minimax" and parsed.choices and parsed.choices[1] and parsed.choices[1].message then
                content = parsed.choices[1].message.content
            elseif provider_name == "ollama" and parsed.response then
                content = parsed.response
            else
                log_error("Servisten beklenen formatta veri dönmedi.")
                return
            end
            
            content = string.gsub(content, "^```%w*\n", "")
            content = string.gsub(content, "```$", "")
            content = string.gsub(content, "^%s+", "")

            -- LLM'in fazladan ürettiği prefix kesişimlerini temizle (Savunma Kalkanı)
            content = clean_overlap(prefix, content)

            vim.schedule(function()
                render_ghost_text(content, row, col)
                log_info("Öneri alındı.")
            end)
        end,
        on_stderr = function(_, data)
            if data and #data > 1 and data[1] ~= "" then
                log_error("cURL Hatası: " .. table.concat(data, "\n"))
            end
        end,
        on_exit = function(_, code)
            if code ~= 0 then
                log_error("Bağlantı kurulamadı. (Kod: " .. code .. ")")
            end
        end
    })
end

-- ==========================================
-- FILE TEMPLATE GENERATOR (DOSYA ŞABLONU ÜRETİCİ)
-- ==========================================
local function starts_with(str, prefix)
    return string.sub(str, 1, #prefix) == prefix
end

local function ends_with(str, suffix)
    return suffix == "" or string.sub(str, -#suffix) == suffix
end

local function get_comment_delimiters()
    local commentstring = vim.bo.commentstring
    if not commentstring or commentstring == "" then
        local filetype = vim.bo.filetype
        if filetype == "python" or filetype == "sh" or filetype == "bash" or filetype == "ruby" or filetype == "yaml" then
            return "# ", ""
        elseif filetype == "lua" or filetype == "sql" then
            return "-- ", ""
        else
            return "// ", ""
        end
    end
    
    local prefix, suffix = commentstring:match("^([^%%]*)%%s(.*)$")
    prefix = prefix or "// "
    suffix = suffix or ""
    return prefix, suffix
end

local function is_comment_line(line, prefix, suffix)
    local trimmed = vim.trim(line)
    if trimmed == "" then return false end
    
    -- Check common indicators as fallbacks
    local common_indicators = { "#", "//", "--", "/*", "<!--" }
    for _, indicator in ipairs(common_indicators) do
        if starts_with(trimmed, indicator) then
            return true
        end
    end
    
    -- Check buffer-specific comment prefix
    local clean_prefix = vim.trim(prefix)
    if clean_prefix ~= "" and starts_with(trimmed, clean_prefix) then
        return true
    end
    
    return false
end

local function extract_prompt_text(line, prefix, suffix)
    local cleaned = vim.trim(line)
    
    -- Remove common comment indicators at the start
    local common_start = { "//", "--", "/*", "<!--", "#" }
    for _, start_ind in ipairs(common_start) do
        if starts_with(cleaned, start_ind) then
            cleaned = vim.trim(string.sub(cleaned, #start_ind + 1))
            break
        end
    end
    
    -- Remove common comment indicators at the end
    local common_end = { "*/", "-->" }
    for _, end_ind in ipairs(common_end) do
        if ends_with(cleaned, end_ind) then
            cleaned = vim.trim(string.sub(cleaned, 1, #cleaned - #end_ind))
            break
        end
    end
    
    -- Also remove specific prefix/suffix if they are different and still present
    local clean_prefix = vim.trim(prefix)
    if clean_prefix ~= "" and starts_with(cleaned, clean_prefix) then
        cleaned = vim.trim(string.sub(cleaned, #clean_prefix + 1))
    end
    local clean_suffix = vim.trim(suffix)
    if clean_suffix ~= "" and ends_with(cleaned, clean_suffix) then
        cleaned = vim.trim(string.sub(cleaned, 1, #cleaned - #clean_suffix))
    end
    
    return cleaned
end

local function format_helper_lines(content, prefix, suffix)
    local lines = {}
    
    -- Ensure the helper header is there
    local header_text = "=== Ghost AI Helper Templates ==="
    table.insert(lines, prefix .. header_text .. suffix)
    
    local raw_lines = vim.split(content, "\n", { trimempty = true })
    for _, line in ipairs(raw_lines) do
        local trimmed = vim.trim(line)
        -- Skip any markdown code block markers
        if not trimmed:match("^```") then
            -- If the model already output the header or footer, skip it
            if not trimmed:find("Ghost AI Helper Templates") and not trimmed:find("====*") then
                local clean_line = trimmed
                
                -- Strip prefix if it starts with it
                local clean_prefix = vim.trim(prefix)
                if clean_prefix ~= "" and starts_with(clean_line, clean_prefix) then
                    clean_line = string.sub(clean_line, #clean_prefix + 1)
                end
                
                -- Strip suffix if it ends with it
                local clean_suffix = vim.trim(suffix)
                if clean_suffix ~= "" and ends_with(clean_line, clean_suffix) then
                    clean_line = string.sub(clean_line, 1, #clean_line - #clean_suffix)
                end
                
                -- Re-wrap with the correct prefix and suffix
                table.insert(lines, prefix .. clean_line .. suffix)
            end
        end
    end
    
    -- Ensure the helper footer is there, and limit lines to 50
    local footer_text = "=================================="
    -- Limit raw lines so that total including header and footer is max 50
    while #lines > 49 do
        table.remove(lines, #lines)
    end
    table.insert(lines, prefix .. footer_text .. suffix)
    
    return lines
end

function M.generate_file_template(prompt_text)
    local bufnr = vim.api.nvim_get_current_buf()
    local provider_name = M.config.active_provider
    local provider = M.config.providers[provider_name]
    local prefix, suffix = get_comment_delimiters()
    local file_name = vim.fs.basename(vim.api.nvim_buf_get_name(bufnr))
    local filetype = vim.bo.filetype

    local system_prompt = "You are a helpful programming assistant.\n" ..
                          "The user is starting a new file: '" .. file_name .. "' (language: " .. filetype .. ").\n" ..
                          "They wrote this description comment: '" .. prompt_text .. "'.\n" ..
                          "Generate helper guidelines, technologies to use, patterns, keyword reminders, engineering steps, and quick code templates to assist them.\n" ..
                          "CRITICAL RULES:\n" ..
                          "1. Every single line of your output MUST start with the comment prefix: '" .. prefix .. "' and end with the comment suffix: '" .. suffix .. "'\n" ..
                          "2. The very first line of your output MUST be: " .. prefix .. "=== Ghost AI Helper Templates ===" .. suffix .. "\n" ..
                          "3. The very last line of your output MUST be: " .. prefix .. "==================================" .. suffix .. "\n" ..
                          "4. Total output must be maximum 50 lines.\n" ..
                          "5. Do NOT use markdown code blocks. Output raw lines starting with '" .. prefix .. "'.\n" ..
                          "6. Make it extremely useful, providing code snippets/patterns (commented out) and keywords (e.g. std::cout, #include <iostream>, etc.).\n"

    local curl_args = { "curl", "-s", "-X", "POST", provider.url, "-H", "Content-Type: application/json" }
    local payload = {}

    if provider_name == "minimax" then
        if not provider.api_key or provider.api_key == "" then
            log_error("MiniMax API Key eksik. Terminalden 'export MINIMAX_API_KEY=...' yapmalısın.")
            return
        end
        table.insert(curl_args, "-H")
        table.insert(curl_args, "Authorization: Bearer " .. provider.api_key)
        
        payload = {
            model = provider.model,
            messages = {
                { role = "system", content = system_prompt },
                { role = "user", content = "Generate helper templates for: " .. prompt_text }
            }
        }
    elseif provider_name == "ollama" then
        payload = {
            model = provider.model,
            prompt = system_prompt .. "\nGenerate helper templates for: " .. prompt_text,
            stream = false,
            options = { temperature = 0.2, num_predict = 400 }
        }
    else
        log_error("Geçersiz sağlayıcı: " .. provider_name)
        return
    end

    table.insert(curl_args, "-d")
    table.insert(curl_args, vim.fn.json_encode(payload))
    
    log_info("Dosya açıklaması algılandı. Şablonlar üretiliyor...")

    vim.fn.jobstart(curl_args, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if not data or #data == 0 or data[1] == "" then return end
            local response_str = table.concat(data, "")
            
            local ok, parsed = pcall(vim.fn.json_decode, response_str)
            if not ok or not parsed then
                log_error("JSON Parse hatası.")
                return
            end

            local content = ""
            if provider_name == "minimax" and parsed.choices and parsed.choices[1] and parsed.choices[1].message then
                content = parsed.choices[1].message.content
            elseif provider_name == "ollama" and parsed.response then
                content = parsed.response
            else
                log_error("Servisten beklenen formatta veri dönmedi.")
                return
            end
            
            local formatted_lines = format_helper_lines(content, prefix, suffix)

            vim.schedule(function()
                if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, formatted_lines)
                    log_info("Şablonlar başarıyla eklendi!")
                end
            end)
        end,
        on_stderr = function(_, data)
            if data and #data > 1 and data[1] ~= "" then
                log_error("cURL Hatası: " .. table.concat(data, "\n"))
            end
        end,
        on_exit = function(_, code)
            if code ~= 0 then
                log_error("Bağlantı kurulamadı. (Kod: " .. code .. ")")
            end
        end
    })
end

local function check_and_generate_template()
    local bufnr = vim.api.nvim_get_current_buf()
    
    -- Sadece normal dosya tamponları için çalıştır
    if vim.bo[bufnr].buftype ~= "" then return end
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    if #lines == 0 then return end

    local first_line = lines[1]
    local prefix, suffix = get_comment_delimiters()
    
    if not is_comment_line(first_line, prefix, suffix) then
        return
    end

    -- Şablon zaten eklenmiş mi kontrol et
    local content_str = table.concat(lines, "\n")
    if content_str:find("Ghost AI Helper Templates") then
        return
    end

    -- Heuristic: Kod satırı sayısını say
    local non_comment_count = 0
    for _, line in ipairs(lines) do
        local t = vim.trim(line)
        if t ~= "" then
            if not is_comment_line(line, prefix, suffix) then
                non_comment_count = non_comment_count + 1
            end
        end
    end

    if non_comment_count > 5 then
        -- Zaten kod yazılmış bir dosya ise şablon ekleme
        return
    end

    local prompt_text = extract_prompt_text(first_line, prefix, suffix)
    if prompt_text == "" then return end

    M.generate_file_template(prompt_text)
end

function M.setup()
    -- Normal modda tetikleyici (Alt + Q)
    vim.keymap.set("n", "<M-q>", function()
        M.request_autocomplete()
    end, { desc = "Request Ghost AI Autocomplete", noremap = true, silent = true })

    -- Normal modda kabul edici (Tab)
    vim.keymap.set("n", "<Tab>", function()
        if current_suggestion then
            M.accept_ghost_text()
        else
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
        end
    end, { desc = "Accept AI Autocomplete", noremap = true, silent = true })
    
    -- İmleç hareketi veya ekleme moduna geçişte temizlik
    vim.api.nvim_create_autocmd({"CursorMoved", "InsertEnter"}, {
        callback = function()
            M.clear_ghost_text()
        end
    })

    -- Dosya kaydedildiğinde otomatik şablon üreticiyi tetikle
    vim.api.nvim_create_autocmd("BufWritePost", {
        callback = function()
            check_and_generate_template()
        end
    })
end

return M

