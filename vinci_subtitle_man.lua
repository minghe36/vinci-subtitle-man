-- MIT License
-- Copyright (c) 2024

-- 添加 decodeUnicode 函数
local function decodeUnicode(str)
    -- 将Unicode转换为UTF-8
    return str:gsub('\\u([%x%x%x%x])', function(hex)
        local code = tonumber(hex, 16)
        if code < 128 then
            return string.char(code)
        elseif code < 2048 then
            local b1 = math.floor(code / 64) + 192
            local b2 = code % 64 + 128
            return string.char(b1, b2)
        else
            local b1 = math.floor(code / 4096) + 224
            local b2 = math.floor((code % 4096) / 64) + 128
            local b3 = code % 64 + 128
            return string.char(b1, b2, b3)
        end
    end)
end

local ui = fu.UIManager
local dispatcher = bmd.UIDispatcher(ui)

-- 窗口ID和元素ID
local winID = "com.blackmagicdesign.resolve.VinciSubtitleMan"
local textID = "TextEdit"
local addSubsID = "AddSubs"
local transcribeID = "Transcribe"
local executeAllID = "ExecuteAll"
local insertTimelineID = "insertTimeline"
local browseFilesID = "BrowseButton"

-- 获取存储路径
local function getStoragePath()
    local separator = package.config:sub(1,1)
    local path
    
    if separator == '\\' then  -- Windows
        path = fusion:MapPath("Scripts:/Utility/vinci-subtitle-man/")
    else  -- macOS/Linux
        path = fusion:MapPath("Scripts:/Utility/vinci-subtitle-man/")
    end
    
    return path
end

-- 获取临时文件目录
local function getTempPath()
    local basePath = getStoragePath()
    local tempPath = basePath .. "temp/"
    
    -- 确保temp目录存在
    local function ensureDirectory(path)
        -- 在Windows和Unix系统上都可用的创建目录命令
        if package.config:sub(1,1) == '\\' then
            -- Windows
            os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '"')
        else
            -- Unix/Mac
            os.execute('mkdir -p "' .. path .. '"')
        end
    end
    
    -- 创建temp目录
    ensureDirectory(tempPath)
    
    return tempPath
end

-- 获取配置文件路径
local function getConfigPath()
    return getStoragePath() .. "config.txt"
end

-- 获取文件名的函数
local function getFileBaseName(project, timeline)
    -- 获取项目名和时间线名
    local projectName = project:GetName():gsub("%.%w+$", "")  -- 移除扩展名
    local timelineName = timeline:GetName():gsub("%.%w+$", "")  -- 移除扩展名
    
    -- 处理特殊字符
    projectName = projectName:gsub("[%/%\\%:%*%?%\"<>%|]", "_")
    timelineName = timelineName:gsub("[%/%\\%:%*%?%\"<>%|]", "_")
    
    -- 组合文件名
    return projectName .. "_" .. timelineName
end

-- 修改 readSrtContent 函数
local function readSrtContent(srtPath)
    -- 使用二进制模式打开文件
    local file = io.open(srtPath, "rb")
    if not file then
        print("无法打开字幕文件: " .. srtPath)
        return nil
    end
    
    -- 读取文件内容
    local content = file:read("*a")
    file:close()
    
    -- 检查是否包含UTF-8 BOM
    if content:sub(1,3) == '\239\187\191' then
        content = content:sub(4)  -- 去除BOM
    end
    
    -- 使用iconv命令转换编码
    local tmpFile = os.tmpname()
    local file = io.open(tmpFile, "wb")
    if file then
        file:write(content)
        file:close()
        
        -- 使用iconv转换编码
        os.execute(string.format('iconv -f UTF-8 -t UTF-8//IGNORE "%s" > "%s.tmp" && mv "%s.tmp" "%s"', 
            tmpFile, tmpFile, tmpFile, tmpFile))
        
        -- 读取转换后的内容
        file = io.open(tmpFile, "rb")
        if file then
            content = file:read("*a")
            file:close()
        end
        
        -- 清理临时文件
        os.remove(tmpFile)
    end
    
    return content
end

-- 添加时转换辅助函数
local function timeToMs(timeStr)
    local h, m, s, ms = timeStr:match("(%d+):(%d+):(%d+),(%d+)")
    return ((tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s)) * 1000) + tonumber(ms)
end

local function msToTime(ms)
    local h = math.floor(ms / (3600 * 1000))
    ms = ms % (3600 * 1000)
    local m = math.floor(ms / (60 * 1000))
    ms = ms % (60 * 1000)
    local s = math.floor(ms / 1000)
    ms = ms % 1000
    return string.format("%02d:%02d:%02d,%03d", h, m, s, ms)
end

-- 创建主窗口
local win = dispatcher:AddWindow({
    ID = winID,
    WindowTitle = "浩叔的智能字幕生成工具",
    Geometry = {200, 200, 1200, 1000},
    
    ui.VGroup{
        ID = "root",
        
        -- 主布局
        ui.HGroup{
            Weight = 1.0,
            
            ui.HGap(10),
            
            -- 左侧控制面板
            ui.VGroup{
                Weight = 0.0,
                MinimumSize = {400, 960},
                
                ui.VGap(4),
                ui.Label{
                    Text = "浩叔的智能字幕生成工具",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 24, Bold = true}
                },
                ui.VGap(35),
                ui.Label{
                    ID = "DialogBox",
                    Text = "等待任务",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 20},
                    Alignment = {AlignHCenter = true},
                    StyleSheet = [[
                        QLabel {
                            color: white;
                        }
                    ]]
                },
                ui.VGap(20),
                ui.Label{
                    Text = "第一步：",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 20}
                },
                ui.VGap(2),
                -- 主要按钮
                ui.Button{
                    ID = executeAllID,
                    Text = "生成字幕初稿",
                    MinimumSize = {150, 50},
                    MaximumSize = {1000, 50},
                    IconSize = {17, 17},
                    Font = ui.Font{PixelSize = 20}
                },
                ui.VGap(2),
                ui.Label{
                    Text = "选择转录模型",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 14}
                },
                ui.ComboBox{
                    ID = "ModelSelector",
                    Weight = 0,
                    MinimumSize = {200, 30},
                    MaximumSize = {2000, 30}
                },
                ui.VGap(2),
                ui.Label{
                    Text = "选择视频语言",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 14}
                },
                ui.ComboBox{
                    ID = "LanguageSelector",
                    Weight = 0,
                    MinimumSize = {200, 30},
                    MaximumSize = {2000, 30}
                },
                ui.VGap(10),
                ui.Label{
                    Text = "第二步：",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 20}
                },
                ui.VGap(2),
                ui.Button{
                    ID = transcribeID,
                    Text = "使用dify优化字幕",
                    MinimumSize = {150, 50},
                    MaximumSize = {1000, 50},
                    IconSize = {17, 17},
                    Font = ui.Font{PixelSize = 20}
                }, 
                ui.VGap(2),
                ui.Label{
                    Text = "dify key（必填）",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 14}
                },
                ui.LineEdit{
                    ID = "dify_key",
                    Text = "",
                    PlaceholderText = "",
                    Weight = 1,
                    MinimumSize = {200, 30},
                    MaximumSize = {2000, 30}
                },
                ui.Label{
                    Text = "文稿链接（选填）",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 14}
                },
                ui.LineEdit{
                    ID = "articleUrl",
                    Text = "",
                    PlaceholderText = "",
                    Weight = 1,
                    MinimumSize = {200, 30},
                    MaximumSize = {2000, 30}
                },
                ui.Label{
                    Text = "字幕优化规则（选填）",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 14}
                },
                ui.LineEdit{
                    ID = "rule",
                    Text = "",
                    PlaceholderText = "",
                    Weight = 1,
                    MinimumSize = {200, 30},
                    MaximumSize = {2000, 30}
                },
                ui.Button{
                    ID = "SaveConfig",
                    Text = "保存配置",
                    MinimumSize = {100, 30},
                    MaximumSize = {1000, 30},
                    Font = ui.Font{PixelSize = 14}
                },
                ui.VGap(10),
                ui.Label{
                    Text = "第三步：",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 20}
                },
                ui.VGap(2),
                ui.Button{
                    ID = insertTimelineID,
                    Text = "将字幕插入到当前时间线",
                    MinimumSize = {150, 50},
                    MaximumSize = {1000, 50},
                    IconSize = {17, 17},
                    Font = ui.Font{PixelSize = 20}
                }                        
            },
            
            ui.HGap(20),
            
            -- 右侧字幕列
            ui.VGroup{
                Weight = 1.0,
                ui.VGap(4),
                ui.Label{
                    Text = "字幕内容:",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 20}
                },
                ui.Label{
                    Text = "可直接编辑字幕内容",
                    Weight = 0,
                    Font = ui.Font{PixelSize = 14}
                },
                ui.VGap(1),
                ui.TextEdit{
                    ID = "SubtitleContent",
                    Weight = 1,
                    Font = ui.Font{PixelSize = 14},
                    StyleSheet = [[
                        QTextEdit {
                            padding: 8px;
                            line-height: 150%;
                        }
                    ]]
                },
                ui.VGap(1),
                ui.Button{
                    ID = "RefreshSubs",
                    Text = "更 新 字 幕",
                    MinimumSize = {200, 40},
                    MaximumSize = {1000, 40},
                    Font = ui.Font{PixelSize = 15}
                }
            }
        }
    }
})

-- 获取UI元素
local itm = win:GetItems()

-- 修改 saveSubtitlesToFile 函数，使用UTF-8编码写入
local function saveSubtitlesToFile(srtPath)
    local content = itm.SubtitleContent.PlainText
    if not content then
        print("字幕内容为nil")
        return false
    end
    
    print("字幕内容长度:", string.len(content or ""))
    
    -- 检查内容是否为空
    if string.len(content:gsub("%s+", "")) == 0 or content == "无字幕" then
        print("字幕内容为空或为'无字幕'")
        return false
    end
    
    -- 使用UTF-8编码入文件
    local file = io.open(srtPath, "w+b")
    if not file then
        print("无法打开文件进行写入:", srtPath)
        return false
    end
    
    -- 写入UTF-8 BOM
    file:write('\239\187\191')
    
    -- 写入内容
    local success, err = pcall(function()
        file:write(content)
        file:close()
    end)
    
    if not success then
        print("写入文件时发生错误:", err)
        return false
    end
    
    print("成功保存字幕到文件:", srtPath)
    return true
end

-- 保存配置(使用简单的文本格式)
local function saveConfig()
    local config = string.format(
        "dify_key=%s\narticleUrl=%s\nrule=%s",
        itm.dify_key.Text,
        itm.articleUrl.Text,
        itm.rule.Text
    )
    
    local file = io.open(getConfigPath(), "w")
    if file then
        file:write(config)
        file:close()
    end
end

-- 加载配置
local function loadConfig()
    local file = io.open(getConfigPath(), "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        -- 解析配置文件
        for line in content:gmatch("[^\r\n]+") do
            local key, value = line:match("(.+)=(.+)")
            if key and value then
                if key == "dify_key" then
                    itm.dify_key.Text = value
                elseif key == "articleUrl" then
                    itm.articleUrl.Text = value
                elseif key == "rule" then
                    itm.rule.Text = value
                end
            end
        end
    end
end

-- 事件处理函
local function OnClose(ev)
    saveConfig()
    dispatcher:ExitLoop()
end

local function OnBrowseFiles(ev)
    local selectedPath = fusion:RequestFile()
    if selectedPath then
        itm.FileLineTxt.Text = selectedPath
    end
end

-- 在文件开头添加获resolve对象的函数
local function getResolve()
    local resolve = bmd.scriptapp("Resolve")
    if not resolve then
        print("未能连接到 DaVinci Resolve")
        return nil
    end
    return resolve
end

-- 修改getCurrentTimeline函数
local function getCurrentTimeline()
    local resolve = getResolve()
    if not resolve then
        return nil, nil
    end

    local projectManager = resolve:GetProjectManager()
    if not projectManager then
        print("错: 未能获取项目管理器")
        return nil, nil
    end

    local project = projectManager:GetCurrentProject()
    if not project then
        print("误: 未找到当前项目")
        return nil, nil
    end
    
    local timeline = project:GetCurrentTimeline()
    if not timeline then
        if project:GetTimelineCount() > 0 then
            timeline = project:GetTimelineByIndex(1)
            project:SetCurrentTimeline(timeline)
        else
            print("错误: 当前项目没有时间线")
            return nil, nil
        end
    end
    
    return project, timeline
end

-- 修改清理渲染队列的函数
local function clearRenderQueue(project)
    -- 获取所有渲染任
    local renderJobs = project:GetRenderJobList()
    if not renderJobs then 
        print("没有找到渲染任务")
        return 
    end
    
    print("当前渲染队列任务数:", #renderJobs)
    
    -- 获取当前时间线名称作为比较
    local baseName = getFileBaseName(project, project:GetCurrentTimeline())
    print("当前音频文件基础名称:", baseName)
    
    -- 获取temp目录的标准化路径
    local tempPath = getTempPath():gsub("/$", "")  -- 移除末尾的斜杠
    print("Temp录路径:", tempPath)
    
    -- 遍历并只删除音频渲染任务
    for _, job in ipairs(renderJobs) do
        local jobId = job["JobId"]
        local jobName = job["RenderJobName"]
        local targetDir = (job["TargetDir"] or ""):gsub("/$", "")  -- 移除末尾的斜杠
        local customName = job["CustomName"]
        
        print("检查渲染任务:")
        print("- ID:", jobId)
        print("- 名称:", jobName)
        print("- 目标目录:", targetDir)
        print("- 自定义名称:", customName)
        
        -- 检查是否是我们生成的音频任务
        if jobId and targetDir then
            -- 标准化路径后比较
            if targetDir == tempPath then
                print("找到匹配的音频渲染任务:", jobId)
                local success = project:DeleteRenderJob(jobId)
                if success then
                    print("除音频渲务")
                else
                    print("删除音频渲染任务失败")
                end
            else
                print("目标目录不匹配")
                print("期望路径:", tempPath)
                print("实际路径:", targetDir)
            end
        else
            print("任务ID目目录为空")
        end
    end
end

-- 修改 renderAudio 函数
local function renderAudio()
    local resolve = getResolve()
    if not resolve then
        itm.DialogBox.Text = "错误: 未能连接到 DaVinci Resolve"
        return nil
    end

    local project, timeline = getCurrentTimeline()
    if not project or not timeline then
        itm.DialogBox.Text = "错误: 未找到时间线"
        return nil
    end
    
    -- 清理渲染队列
    clearRenderQueue(project)
    
    -- 使用新的文件名格式
    local baseName = getFileBaseName(project, timeline)
    
    -- 切换到编辑页面
    resolve:OpenPage("edit")
    
    -- 获取帧率
    local frame_rate = timeline:GetSetting("timelineFrameRate")
    
    -- 设置渲染参数
    project:LoadRenderPreset('Audio Only')
    project:SetRenderSettings({
        SelectAllFrames = 1,
        CustomName = baseName,
        TargetDir = getTempPath(),
        AudioCodec = "Linear PCM",
        ExportVideo = false,
        ExportAudio = true,
        AudioBitDepth = "16",
        AudioSampleRate = "48000",
        FileExtension = "wav"
    })
    
    -- 添加渲染任务
    local jobId = project:AddRenderJob()
    if not jobId then
        print("错误: 添加渲染任务失败")
        return nil
    end
    
    -- 开始渲染
    print("开始渲染...")
    if not project:StartRendering(jobId) then
        print("错误: 启动渲染失败")
        return nil
    end
    
    print("正在渲染音频...")
    itm.DialogBox.Text = "正在渲染音频..."
    
    -- 等待渲染完成
    while project:IsRenderingInProgress() do
        local status = project:GetRenderJobStatus(jobId)
        local progress = status and status["CompletionPercentage"] or 0
        print("进度: ", progress, "%")
        itm.DialogBox.Text = string.format("渲染进度: %d%%", progress)
        fu:Sleep(0.5)
    end
    
    print("渲染任务完成，等待文件写入...")
    itm.DialogBox.Text = "渲染任务完成，等待文件写入..."
    
    -- 统一使用正斜杠的路径
    local location = getTempPath():gsub("\\", "/") .. baseName .. ".wav"
    print("检查音频文件:", location)
    
    -- 等待文件写入完成
    local maxWaitTime = 30  -- 最多等待30秒
    local waitStart = os.time()
    
    while true do
        -- 检查文件是否存在且可以打开
        local file = io.open(location, "r")
        if file then
            file:close()
            print("音频文件生成成功:", location)
            itm.DialogBox.Text = "音频渲染完成!"
            return location, markIn, frame_rate
        end
        
        -- 检查是否超时
        if os.time() - waitStart > maxWaitTime then
            print("错误: 等待文件写入超时")
            itm.DialogBox.Text = "错误: 等待文件写入超时"
            return nil
        end
        
        -- 等待一段时间再检查
        fu:Sleep(1.0)
        print("等待文件写入...", location)
    end
end

-- 添加执行命令的函数
local function ExecuteCommand(command)
    -- 设置环境变量
    local path = os.getenv("PATH") or ""
    local newPath = "/usr/local/bin:/opt/homebrew/bin:" .. path  -- 添加可能的路径
    
    -- 使用完整环境设置来执行命令
    local fullCommand = string.format('export PATH="%s" && %s', newPath, command)
    local handle = io.popen(fullCommand .. " 2>&1")
    local result = handle:read("*a")
    local success = handle:close()
    return success, result
end

-- 改 getStableTsPath 函数
local function getStableTsPath()
    -- 首先检查环境变量
    local envPath = os.getenv("STABLE_TS_PATH")
    if envPath and io.open(envPath, "r") then
        print("从环境变量获取 stable-ts 路径: " .. envPath)
        return envPath
    end

    -- 尝试使用 which 命令
    local handle = io.popen("which stable-ts 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    result = result:gsub("%s+$", "")
    if result ~= "" and io.open(result, "r") then
        print("通过 which 命令找到 stable-ts 路径: " .. result)
        return result
    end

    -- 获取HOME环境变量
    local home = os.getenv("HOME")
    if not home then
        print("警告: 无法获取HOME环境变量")
        home = ""
    end

    -- 检查常见的安装位置
    local commonPaths = {
        "/usr/local/bin/stable-ts",
        "/usr/bin/stable-ts",
        "/opt/anaconda3/bin/stable-ts",
        "/opt/miniconda3/bin/stable-ts"
    }
    
    -- 如果有HOME环境变量，添加用户目录下的路径
    if home ~= "" then
        table.insert(commonPaths, home .. "/anaconda3/bin/stable-ts")
        table.insert(commonPaths, home .. "/miniconda3/bin/stable-ts")
        table.insert(commonPaths, home .. "/anaconda3/envs/stable-ts/bin/stable-ts")
        table.insert(commonPaths, home .. "/miniconda3/envs/stable-ts/bin/stable-ts")
    end

    for _, path in ipairs(commonPaths) do
        if io.open(path, "r") then
            print("在常见位置找到 stable-ts 路径: " .. path)
            return path
        end
    end

    print("没有找到 stable-ts")
    return nil
end

-- 修改 generateSubtitles 函数，移除 splitSubtitles 调用
local function generateSubtitles(audioPath, project, timeline)
    local stableTsPath = getStableTsPath()
    if not stableTsPath then
        print("错误: 未找到 stable-ts")
        return nil
    end

    -- 使用新的文件名格式
    local baseName = getFileBaseName(project, timeline)
    local srtPath = getTempPath() .. baseName .. ".srt"
    
    -- 检查并删除已存在的SRT文件
    local existingFile = io.open(srtPath, "r")
    if existingFile then
        existingFile:close()
        os.remove(srtPath)
        -- 等待文件系统完成删除操作
        fu:Sleep(0.1)
    end
    
    -- 获取选择的模型
    local modelMap = {
        [0] = "base",
        [1] = "small",
        [2] = "medium",
        [3] = "large"
    }
    local selectedModel = modelMap[itm.ModelSelector.CurrentIndex] or "small"
    
    -- 获取选择的语言
    local languageMap = {
        [0] = "zh",
        [1] = "en",
        [2] = "ja",
        [3] = "ko",
        [4] = "de",
        [5] = "fr"
    }
    local selectedLanguage = languageMap[itm.LanguageSelector.CurrentIndex] or "zh"
    
    -- 构建 stable-ts 命令
    local cmd = string.format(
        '"%s" "%s" -o "%s" --segment_level true --word_level false --language %s --model %s --initial_prompt "以下是%s的句子。"',
        stableTsPath, audioPath, srtPath, selectedLanguage, selectedModel,
        selectedLanguage == "zh" and "普通话" or "该语言"
    )
    
    print("开始生成字幕文件...")
    print("执行命令: " .. cmd)
    
    local success, output = ExecuteCommand(cmd)
    
    print("命令输出:")
    print(output)
    
    if not success then
        print("命令执行失败")
        return nil
    end
    
    local file = io.open(srtPath, "r")
    if file then
        file:close()
        print("字幕文件已生成: " .. srtPath)
        
        -- 更新显示
        local content = readSrtContent(srtPath)
        if content then
            itm.SubtitleContent.Text = content
        end
        
        return srtPath
    else
        print("生成字幕文件失败")
        return nil
    end
end

-- 添加读取SRT文件的函数
local function readSrtFile(srtPath)
    local file = io.open(srtPath, "r")
    if not file then
        print("无法打开字幕文件: " .. srtPath)
        return nil
    end

    local subtitles = {}
    local currentSubtitle = {}
    local lineNum = 1

    for line in file:lines() do
        if line:match("^%d+$") then
            -- 字幕序，开始新的字条目
            if currentSubtitle.text then
                table.insert(subtitles, currentSubtitle)
            end
            currentSubtitle = {index = tonumber(line)}
        elseif line:match("^%d%d:%d%d:%d%d,%d%d%d%s+%-%->%s+%d%d:%d%d:%d%d,%d%d%d$") then
            -- 时间码
            currentSubtitle.timecode = line
        elseif line ~= "" then
            -- 字文本
            if currentSubtitle.text then
                currentSubtitle.text = currentSubtitle.text .. " " .. line
            else
                currentSubtitle.text = line
            end
        end
    end

    -- 添加最后一条字幕
    if currentSubtitle.text then
        table.insert(subtitles, currentSubtitle)
    end

    file:close()
    return subtitles
end

-- 修改 OnGenerateSubtitles 函数，添加显示字幕部分
local function OnGenerateSubtitles(ev)
    local resolve = getResolve()
    if not resolve then
        itm.DialogBox.Text = "错误: 未能连接 DaVinci Resolve"
        return
    end

    -- 检查必填项
    if itm.dify_key.Text == "" then
        itm.DialogBox.Text = "错误: 请填写 dify key"
        return
    end
    
    -- 渲染音频件
    local audioFile, markIn, frameRate = renderAudio()
    if not audioFile then
        return
    end
    
    -- 获取时间线名称
    local project, timeline = getCurrentTimeline()
    local timelineName = timeline:GetName()
    timelineName = timelineName:gsub("%.%w+$", "")  -- 移除任何展名
    timelineName = timelineName:gsub("[%/%\\%:%*%?%\"<>%|]", "_")  -- 替换非法字符
    
    -- 生成字幕文件
    itm.DialogBox.Text = "正在生成字幕，先去喝杯水吧..."
    local srtPath = generateSubtitles(audioFile, project, timeline)  -- 传递project和timeline
    
    if srtPath then
        itm.DialogBox.Text = "字幕生成完成!"
        
        -- 读取并显示字幕内容
        local file = io.open(srtPath, "r")
        if file then
            local content = file:read("*a")
            file:close()
            itm.SubtitleContent.Text = content
            itm.DialogBox.Text = "字幕已生成并加载字幕框中"
        else
            itm.DialogBox.Text = "字幕文件读取失败"
        end
    else
        itm.DialogBox.Text = "字幕生成败!"
    end
    
    -- 更新状态
    resolve:OpenPage("edit")
end

-- 修改刷新字幕列表的事件处理函数，添加保存功能
local function OnRefreshSubtitles(ev)
    local project, timeline = getCurrentTimeline()
    if not project or not timeline then
        itm.DialogBox.Text = "错误: 未找到时间线"
        return
    end
    
    -- 使用新的文件名格式
    local baseName = getFileBaseName(project, timeline)
    local srtPath = getTempPath() .. baseName .. ".srt"
    print("准备保存字幕到文件:", srtPath)
    
    -- 保存当前编辑的字幕
    if saveSubtitlesToFile(srtPath) then
        print("字幕已保存到文件")
        itm.DialogBox.Text = "字幕已保存"
    else
        print("保存字幕失败")
        itm.DialogBox.Text = "保存字幕失败，请确保字幕内容不为空"
    end
end

-- 添加HTTP请求关函数
local function makeHttpRequest(url, method, headers, body)
    -- 建curl命令
    local headerStr = ""
    for k, v in pairs(headers) do
        headerStr = headerStr .. string.format(" --header '%s: %s'", k, v)
    end
    
    local bodyStr = ""
    if body then
        bodyStr = string.format(" --data-raw '%s'", body)
    end
    
    local cmd = string.format("curl -X %s '%s'%s%s", method, url, headerStr, bodyStr)
    
    -- 执行请求
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    return result
end

-- 读取整SRT文件内容的函数
local function readSrtContent(srtPath)
    local file = io.open(srtPath, "r")
    if not file then
        print("无法打开字幕文件: " .. srtPath)
        return nil
    end
    
    local content = file:read("*a")
    file:close()
    return content
end

-- 修改 optimizeSubtitles 函数，添加调试输出
local function optimizeSubtitles(apiKey, articleUrl, rule, subtitleContent)
    local url = "https://api.dify.ai/v1/workflows/run"
    local headers = {
        ["Authorization"] = "Bearer " .. apiKey,
        ["Content-Type"] = "application/json"
    }
    
    -- 转义JSON字符串中的特殊字符
    local function escapeJson(str)
        return str:gsub('"', '\\"'):gsub('\n', '\\n')
    end
    
    -- 构建JSON请求体
    local jsonBody = string.format([[{
        "inputs": {
            "articleUrl": "%s",
            "subtitle": "%s",
            "rule": "%s"
        },
        "response_mode": "streaming",
        "user": "vinci"
    }]], escapeJson(articleUrl or ""), escapeJson(subtitleContent), escapeJson(rule or ""))
    
    print("\n开始调用 Dify API:")
    print("请求URL:", url)
    print("请求头:", headers["Authorization"])
    print("求体:", jsonBody)
    
    -- 发送请求
    local response = makeHttpRequest(url, "POST", headers, jsonBody)
    print("\nDify API 响应:")
    print(response)
    
    return response
end

-- 修 processDifyResponse 函数
local function processDifyResponse(response, srtPath)
    print("开始处理Dify响应...")
    
    -- 修改 Unicode 解码函
    local function decodeUnicode(str)
        -- 处理 Unicode 转义序列
        local function unicodeToUtf8(unicode)
            local n = tonumber(unicode, 16)
            if not n then return "" end
            
            -- 单字节 ASCII
            if n < 0x80 then
                return string.char(n)
            end
            
            -- 双字节序列
            if n < 0x800 then
                local b1 = bit.bor(0xC0, bit.rshift(n, 6))
                local b2 = bit.bor(0x80, bit.band(n, 0x3F))
                return string.char(b1, b2)
            end
            
            -- 三字节序列
            local b1 = bit.bor(0xE0, bit.rshift(n, 12))
            local b2 = bit.bor(0x80, bit.band(bit.rshift(n, 6), 0x3F))
            local b3 = bit.bor(0x80, bit.band(n, 0x3F))
            return string.char(b1, b2, b3)
        end
        
        -- 替换所有 Unicode 转义序列
        local result = str:gsub("\\u(%x%x%x%x)", function(unicode)
            local utf8char = unicodeToUtf8(unicode)
            return utf8char or ""
        end)
        
        return result
    end
    
    -- 遍历每一行数据
    local newSubtitleContent = nil
    for line in response:gmatch("[^\r\n]+") do
        if line:match("^%s*data:%s*{") then
            -- 检查是否是workflow_finished事件
            if line:match('"event":%s*"workflow_finished"') then
                -- 提取outputs.result字段
                local result = line:match('"outputs":%s*{%s*"result":%s*"(.-)"[%s,}]')
                if result then
                    print("原始result内容:", result)
                    
                    -- 处理转义字符
                    newSubtitleContent = result
                        :gsub('\\"', '"')  -- 处理引号
                        :gsub('\\\\', '\\')  -- 处理反斜杠
                        :gsub('\\n', '\n')  -- 处理换行
                    
                    -- 码Unicode
                    newSubtitleContent = decodeUnicode(newSubtitleContent)
                    
                    print("处理后的字幕内容:", newSubtitleContent)
                    break
                end
            end
        end
    end
    
    if newSubtitleContent then
        -- 写入字幕文件
        local file = io.open(srtPath, "w")
        if file then
            file:write(newSubtitleContent)
            file:close()
            print("成功写入字幕文件")
            return true
        end
    end
    
    return false
end

-- 修改 OnOptimizeSubtitles 函数
local function OnOptimizeSubtitles(ev)
    local project, timeline = getCurrentTimeline()
    if not project or not timeline then
        itm.DialogBox.Text = "错误: 未到时间线"
        return
    end
    
    -- 检查必填项
    if itm.dify_key.Text == "" then
        itm.DialogBox.Text = "错误: 请填写 dify key"
        return
    end
    
    -- 使用新的文件名格式
    local baseName = getFileBaseName(project, timeline)
    local srtPath = getTempPath() .. baseName .. ".srt"
    print("尝试读取字幕文件:", srtPath)
    
    -- 读取SRT文件内容
    local subtitleContent = readSrtContent(srtPath)
    if not subtitleContent then
        itm.DialogBox.Text = "错误: 无法读取字幕文件"
        return
    end
    
    -- 调用Dify API
    itm.DialogBox.Text = "正在优化字幕中，站起来运动下..."
    local response = optimizeSubtitles(
        itm.dify_key.Text,
        itm.articleUrl.Text,
        itm.rule.Text,
        subtitleContent
    )
    
    if response then
        -- 处理响应并更新字幕
        if processDifyResponse(response, srtPath) then
            itm.DialogBox.Text = "字幕优化完成"
            
            -- 重新加载字幕显示
            local file = io.open(srtPath, "r")
            if file then
                local content = file:read("*a")
                file:close()
                itm.SubtitleContent.Text = content
                itm.DialogBox.Text = "字幕已更新"
            end
        else
            itm.DialogBox.Text = "字幕更新失败"
        end
    else
        itm.DialogBox.Text = "字幕优化失败"
    end
end

-- 修改导入字幕到时间线的函数
local function importSubtitlesToTimeline(srtPath)
    local resolve = getResolve()
    if not resolve then
        itm.DialogBox.Text = "错误: 未能连接到 DaVinci Resolve"
        return false
    end

    local project, timeline = getCurrentTimeline()
    if not project or not timeline then
        itm.DialogBox.Text = "错误: 未找到时间线"
        return false
    end

    -- 获取媒体池
    local mediaPool = project:GetMediaPool()
    if not mediaPool then
        itm.DialogBox.Text = "误: 无法获取媒体池"
        return false
    end

    -- 确保根文件夹中
    local rootFolder = mediaPool:GetRootFolder()
    mediaPool:SetCurrentFolder(rootFolder)

    -- 获取文件名（不包含路径）
    local srtFileName = srtPath:match("([^/\\]+)$")
    print("检查媒体池中是否存在:", srtFileName)

    -- 检查媒体池中是否已存在该SRT文件
    local existingItems = rootFolder:GetClipList()
    for _, item in ipairs(existingItems) do
        local clipName = item:GetName()
        if clipName == srtFileName then
            print("在媒体池中找到已存在的字幕文件:", clipName)
            -- 删已存在的字幕文件
            mediaPool:DeleteClips({item})
            print("已从媒体池中删除:", clipName)
            break
        end
    end

    -- 导入SRT文件
    local mediaPoolItems = mediaPool:ImportMedia(srtPath)
    if not mediaPoolItems or #mediaPoolItems == 0 then
        itm.DialogBox.Text = "错误: 导入字幕文件失败"
        return false
    end

    local mediaPoolItem = mediaPoolItems[1]
    print("成功: 字幕文件已导入到媒体池")

    -- 将字幕添加到时间线
    local success = mediaPool:AppendToTimeline({mediaPoolItem})
    if not success then
        itm.DialogBox.Text = "错误: 将字幕添加到时间线失败"
        return false
    end

    print("成功: 字幕已添加到时间线")
    itm.DialogBox.Text = "字幕已添加到时间线"
    return true
end

-- 添加插入字幕到时间线的事件处理函数
local function OnInsertTimeline(ev)
    local project, timeline = getCurrentTimeline()
    if not project or not timeline then
        itm.DialogBox.Text = "错误: 未找到时间线"
        return
    end
    
    -- 使用新的文件名格式
    local baseName = getFileBaseName(project, timeline)
    local srtPath = getTempPath() .. baseName .. ".srt"
    
    -- 检查字幕文件是否存在
    local file = io.open(srtPath, "r")
    if not file then
        itm.DialogBox.Text = "错误: 未找到字幕文件"
        return
    end
    file:close()
    
    -- 导入字幕到时间线
    if importSubtitlesToTimeline(srtPath) then
        itm.DialogBox.Text = "字幕已成功添加到时间线"
    end
end

-- 修改 loadExistingSubtitles 函数，使用UTF-8编码读取
local function loadExistingSubtitles()
    local project, timeline = getCurrentTimeline()
    if not project or not timeline then
        print("未找到项目或时间线")
        return
    end
    
    local baseName = getFileBaseName(project, timeline)
    local srtPath = getTempPath() .. baseName .. ".srt"
    print("查字幕件路径:", srtPath)
    
    -- 使用UTF-8编码打开件
    local file = io.open(srtPath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        
        -- 检查并去除UTF-8 BOM
        if content:sub(1,3) == '\239\187\191' then
            content = content:sub(4)
        end
        
        if content and #content > 0 then
            print("找到已存在的字幕文件:", srtPath)
            print("字幕内容长度:", #content)
            
            -- 设置字幕内容
            itm.SubtitleContent.Text = content
            itm.DialogBox.Text = "已加载现有字幕"
            print("成功加载字幕内容到界面")
        else
            print("字幕件为空")
            itm.SubtitleContent.Text = "无字幕"
        end
    else
        print("未找到现有字幕文件:", srtPath)
        itm.SubtitleContent.Text = "无字幕"
    end
end

-- 在初始化部分添加选项
local function initializeModelSelector()
    itm.ModelSelector:AddItem("base - 基础模型（较快）")
    itm.ModelSelector:AddItem("small - 小型模型（推荐）")
    itm.ModelSelector:AddItem("medium - 中型模型（较慢）")
    itm.ModelSelector:AddItem("large - 大型模型很慢）")
    itm.ModelSelector.CurrentIndex = 1  -- 默认选择small模型
end

-- 添加选器初始化函数
local function initializeLanguageSelector()
    itm.LanguageSelector:AddItem("中文 (zh)")
    itm.LanguageSelector:AddItem("英语 (en)")
    itm.LanguageSelector:AddItem("日 (ja)")
    itm.LanguageSelector:AddItem("韩语 (ko)")
    itm.LanguageSelector:AddItem("德语 (de)")
    itm.LanguageSelector:AddItem("法语 (fr)")
    itm.LanguageSelector.CurrentIndex = 0  -- 默认选择中文
end

-- 初始化
loadConfig()  -- 加载配置
loadExistingSubtitles()  -- 加载现有字
initializeModelSelector()  -- 初始化模型选择器
initializeLanguageSelector()  -- 初始化语言选择器

-- 注册事件处理函数
win.On[winID].Close = OnClose
win.On[browseFilesID].Clicked = OnBrowseFiles
win.On.SaveConfig.Clicked = saveConfig
win.On[executeAllID].Clicked = OnGenerateSubtitles
win.On.RefreshSubs.Clicked = OnRefreshSubtitles
win.On[transcribeID].Clicked = OnOptimizeSubtitles
win.On[insertTimelineID].Clicked = OnInsertTimeline

-- 显示窗口并运行事件循环
win:Show()
dispatcher:RunLoop()
win:Hide()
