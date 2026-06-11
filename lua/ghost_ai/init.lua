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
end

return M

