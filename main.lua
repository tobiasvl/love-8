local CPU = require 'cpu'
local moonshine = require 'moonshine'
local imgui = require 'imgui'

local keys_cosmac = {
    0x1,
    0x2,
    0x3,
    0xC,
    0x4,
    0x5,
    0x6,
    0xD,
    0x7,
    0x8,
    0x9,
    0xE,
    0xA,
    0x0,
    0xB,
    0xF
}

local keys_qwerty = {
    "1",
    "2",
    "3",
    "4",
    "q",
    "w",
    "e",
    "r",
    "a",
    "s",
    "d",
    "f",
    "z",
    "x",
    "c",
    "v"
}

local key_mapping = {}
local button_status = {}
for k, v in pairs(keys_cosmac) do
    key_mapping[keys_qwerty[k]] = v
    button_status[v] = false
end

local shaders = {}

local canvases = {}
local shaders = {
    scanlines = true,
    glow = true,
    chromasep = true,
    crt = true
}
local effect
local romfile

function love.load(arg)
    --min_dt = 1/60--60 --fps
    --next_time = love.timer.getTime()
    --debug.debug()
    canvases.display = love.graphics.newCanvas(64*8, 32*8)
    canvases.instructions = love.graphics.newCanvas(200, 200)

    CPU:init()

    romfile = arg[1] or "mini-lights-out.ch8"
    local file = love.filesystem.newFile("ROM/" .. romfile)
    local ok, err = file:open("r")
    if ok then
        CPU.rom_loaded = true
        CPU:read_rom(file)
        love.window.setTitle("LOVE-8 - " .. romfile)
    else
        print(err)
        CPU.rom_loaded = false
        love.window.setTitle("LOVE-8")
    end
    file:close()

    effect = moonshine(64*8, 32*8, moonshine.effects.scanlines)
        .chain(moonshine.effects.glow)
        .chain(moonshine.effects.chromasep)
        .chain(moonshine.effects.crt)
    effect.chromasep.angle = 0.15
    effect.chromasep.radius = 2
    effect.scanlines.width = 1
    effect.crt.distortionFactor = {1.02, 1.065}
    effect.glow.strength = 3
    effect.glow.min_luma = 0.9

    showDisplayWindow = true
    showKeypadWindow = true
    showInstructionsWindow = true
end

function love.filedropped(file)
    CPU:init()
    love.window.setTitle("LOVE-8")

    local ok, err = file:open("r")
    if ok then
        CPU:read_rom(file)
        CPU.rom_loaded = true
    else
        print(err)
        CPU.rom_loaded = false
    end
    file:close()
end

function love.update(dt)
    if CPU.rom_loaded and not pause then
        if CPU.delay > 0 then CPU.delay = CPU.delay - 1 end
        if CPU.sound > 0 then CPU.sound = CPU.sound - 1 end
        --next_time = next_time + min_dt

        local temp_key_status = {}
        for k, v in pairs(button_status) do
            temp_key_status[k] = CPU.key_status[k]
            if v then
                CPU.key_status[k] = v
            end
        end

        for i=1,30 do
            local opcode = CPU:cycle()
            CPU:decode(opcode)
        end

        for k, v in pairs(button_status) do
            CPU.key_status[k] = temp_key_status[k]
        end
    end
end

function love.draw()
    imgui.NewFrame()
    if showDisplayWindow then
        imgui.SetNextWindowPos(0, 20, "ImGuiCond_FirstUseEver")
        showDisplayWindow = imgui.Begin("Display", nil, { "NoCollapse", "MenuBar" })--, { "ImGuiWindowFlags_AlwaysAutoResize" })
        if imgui.BeginMenuBar() then
            if imgui.BeginMenu("Effects") then
                for k, v in pairs(shaders) do
                    if imgui.MenuItem(k, nil, shaders[k], true) then
                        shaders[k] = not shaders[k]
                        -- TODO improve this?
                        for k, v in pairs(shaders) do
                            if shaders[k] then
                                effect.enable(k)
                            else
                                effect.disable(k)
                            end
                        end
                    end
                end
                imgui.EndMenu()
            end
            if imgui.BeginMenu("Tools") then
                if imgui.MenuItem("Save screenshot", nil, false, true) then
                    canvases.display:newImageData():encode('png', romfile .. "-" .. os.time() .. ".png")
                end
                imgui.EndMenu()
            end
            imgui.EndMenuBar()
        end
        local win_x, win_y = imgui.GetWindowSize()
        if CPU.display then
            if CPU.drawflag then
                love.graphics.setCanvas(canvases.display)
                love.graphics.clear()
                effect(function()
                    love.graphics.setColor(1,1,1)
                    for x=0,63 do
                        for y=0,31 do
                            if CPU.screen[x][y]==1 then
                                love.graphics.rectangle("fill", x*8, y*8, 8, 8)
                            end
                        end
                    end
                end)
                love.graphics.setCanvas()
                CPU.drawflag = false
            end
        end
        imgui.Image(canvases.display, 64*8 + 8, 32*8)
        imgui.End()
    end

    if showInstructionsWindow then
        imgui.SetNextWindowPos(540, 20, "ImGuiCond_FirstUseEver")
        showInstructionsWindow = imgui.Begin("Instructions", true)
        love.graphics.push()
        love.graphics.setCanvas(canvases.instructions)
        love.graphics.clear()
        love.graphics.translate(-590, 0)
        love.graphics.setBlendMode('alpha', 'alphamultiply')
        local y = 0
        for i = CPU.pc - 16, CPU.pc + 16, 2 do
            if i == CPU.pc then
                love.graphics.print(">", 590, y)
            end
            love.graphics.print(string.format("%03x", i) .. ": " .. string.format("%02x%02x", CPU.rom[i], CPU.rom[i+1]), 600, y)
            y = y + 12
        end
        y = 0
        for i = 0, #CPU.v do
            love.graphics.print("V" .. string.format("%x", i) .. ": " .. CPU.v[i], 670, y)
            y = y + 12
        end
        love.graphics.print("I: " .. string.format("%03x", CPU.i), 740, 0)
        love.graphics.print("D: " .. CPU.delay, 740, 10)
        love.graphics.print("T: " .. CPU.sound, 740, 20)
        y = 25
        for i = #CPU.stack, 1, -1 do
            love.graphics.print(string.format("%03x", CPU.stack[i]), 740, 10 + y)
            y = y + 12
        end
        love.graphics.setCanvas()
        love.graphics.pop()
        imgui.Image(canvases.instructions, 200, 200)
        imgui.End()
    end

    if showKeypadWindow then
        imgui.SetNextWindowPos(540, 300, "ImGuiCond_FirstUseEver")
        showKeypadWindow = imgui.Begin("Keypad", true, { "NoScrollbar", "MenuBar" })
        if imgui.BeginMenuBar() then
            if imgui.BeginMenu("Layout") then
                imgui.MenuItem("Standard", nil, true, false)
                if imgui.IsItemHovered() then
                    imgui.SetTooltip("COSMAC VIP, HP48, and most others")
                end
                imgui.MenuItem("DREAM 6800", nil, false, false)
                if imgui.IsItemHovered() then
                    imgui.SetTooltip("DREAM 6800 assembled in Electronics Australia, and 40th anniversary reproduction")
                end
                imgui.MenuItem("DREAM 6800 prototype", nil, false, false)
                if imgui.IsItemHovered() then
                    imgui.SetTooltip("DREAM 6800 prototype and the CHIP-8 Classic Computer")
                end
                imgui.MenuItem("ETI-660 Standard", nil, false, false)
                if imgui.IsItemHovered() then
                    imgui.SetTooltip("Rectangular, ETI-660 assembled in Electronics Today International")
                end
                imgui.MenuItem("ETI-660", nil, false, false)
                if imgui.IsItemHovered() then
                    imgui.SetTooltip("Common square aftermarket keypad for ETI-660")
                end
                imgui.EndMenu()
            end
            imgui.EndMenuBar()
        end
        local win_w, win_h = imgui.GetWindowSize()
        imgui.PushButtonRepeat(true)
        for k, v in pairs(keys_cosmac) do
            if CPU.key_status[v] then
                imgui.PushStyleColor("ImGuiCol_Button", 117 / 255, 138 / 255, 204 / 255, 1)
                button_status[v] = imgui.Button(string.format("%X", v), (win_w / 5), (win_h / 5) - 5)
                imgui.PopStyleColor(1)
            else
                button_status[v] = imgui.Button(string.format("%X", v), (win_w / 5), (win_h / 5) - 4)
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(keys_qwerty[k])
            end
            if k % 4 ~= 0 then
                imgui.SameLine()
            end
        end
        imgui.PopButtonRepeat()
        imgui.End()
    end

    if imgui.BeginMainMenuBar() then
        if imgui.BeginMenu("File") then
            if imgui.MenuItem("Quit") then
                love.event.quit()
            end
            imgui.EndMenu()
        end
        if imgui.BeginMenu("Windows") then
            if imgui.MenuItem("Display", nil, showDisplayWindow, false) then
                showDisplayWindow = not showDisplayWindow
            end
            if imgui.MenuItem("Keypad", nil, showKeypadWindow, true) then
                showKeypadWindow = not showKeypadWindow
            end
            if imgui.MenuItem("Instructions", nil, showInstructionsWindow, true) then
                showInstructionsWindow = not showInstructionsWindow
            end
            imgui.EndMenu()
        end
        imgui.EndMainMenuBar()
    end

    imgui.Render()
end

function love.quit()
    imgui.ShutDown()
end

function love.keypressed(key)
    imgui.KeyPressed(key)
    if not imgui.GetWantCaptureKeyboard() then
        -- TODO: VIP used the sound timer for this, so a sound should be emitted while a key is held down
        if key_mapping[key] then
            CPU.key_status[key_mapping[key]] = true
        end

        if key == "space" then pause = not pause end
        if pause and key == "right" then
            if CPU.delay > 0 then CPU.delay = CPU.delay - 1 end
            if CPU.sound > 0 then CPU.sound = CPU.sound - 1 end
            --next_time = next_time + min_dt
            CPU:decode(CPU:cycle())
        end
    end
end

function love.keyreleased(key)
    imgui.KeyReleased(key)
    if not imgui.GetWantCaptureKeyboard() then
        -- TODO: VIP used the sound timer for this, so a sound should be emitted while a key is held down
        if key_mapping[key] then
            CPU.key_status[key_mapping[key]] = false
        end
    end
end

function love.mousemoved(x, y)
    imgui.MouseMoved(x, y, true)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end

function love.mousepressed(x, y, button)
    imgui.MousePressed(button)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end

function love.mousereleased(x, y, button)
    imgui.MouseReleased(button)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end

function love.wheelmoved(x, y)
    imgui.WheelMoved(y)
    if not imgui.GetWantCaptureMouse() then
        -- Pass event to the game
    end
end

function love.textinput(t)
    imgui.TextInput(t)
    if not imgui.GetWantCaptureKeyboard() then
        -- Pass event to the game
    end
end
