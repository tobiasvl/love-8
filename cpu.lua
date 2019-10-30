local bit = bit or require 'bit32'

local stack = {}

function stack:new()
    self.__index = self
    return setmetatable({}, self)
end

function stack:pop()
    if #self == 0 then
        print("Attempted to pop empty stack!")
    end
    return table.remove(self)
end

function stack:push(element)
    table.insert(self, element)
    if #self > 12 then
        print("Warning: VIP stack limit reached")
    end
end

local CPU = {
    rom = {},
    rom_loaded = false,
    pc = 0,
    v = {},
    i = 0,
    stack = stack:new(),
    delay = 0,
    sound = 0,
    key_status = {},
    screen = {},
    display = false,
    instructions = {}
}

function CPU:new()
    self.__index = self
    return setmetatable({}, self)
end

function CPU:init()
    for i=0,0xFFF do
        self.rom[i] = 0
    end

    for i=0x0,0xF do
        self.key_status[i] = false
    end

    for x=0,0xF do
        self.v[x] = 0
    end

    for x=0,63 do
        self.screen[x] = {}
        --for y=0,31 do
        --    screen[x][y] = 0
        --end
    end

    self.pc = 0x1FC

    self.instructions = require 'instructions'
end

function CPU:decode(opcode)
    local opcode2 = bit.band(opcode, 0xF000)
    self.instructions[opcode2](self, opcode)
end

function CPU:read_rom(file)
    -- The font, originally located at memory page 81 in an overlapping fashion
    -- with a jump table at location 00 and numbers at (in ascending order)
    -- 30, 39, 22, 2A, 3E, 20, 24, 34, 26, 28, 2E, 18, 14, 1C, 10, 12
    -- We just store them consecutively here for convenience
    local fontset = {
        0xF0, 0x90, 0x90, 0x90, 0xF0, -- 0
        0x20, 0x60, 0x20, 0x20, 0x70, -- 1
        0xF0, 0x10, 0xF0, 0x80, 0xF0, -- 2
        0xF0, 0x10, 0xF0, 0x10, 0xF0, -- 3
        0x90, 0x90, 0xF0, 0x10, 0x10, -- 4
        0xF0, 0x80, 0xF0, 0x10, 0xF0, -- 5
        0xF0, 0x80, 0xF0, 0x90, 0xF0, -- 6
        0xF0, 0x10, 0x20, 0x40, 0x40, -- 7
        0xF0, 0x90, 0xF0, 0x90, 0xF0, -- 8
        0xF0, 0x90, 0xF0, 0x10, 0xF0, -- 9
        0xF0, 0x90, 0xF0, 0x90, 0x90, -- A
        0xE0, 0x90, 0xE0, 0x90, 0xE0, -- B
        0xF0, 0x80, 0x80, 0x80, 0xF0, -- C
        0xE0, 0x90, 0x90, 0x90, 0xE0, -- D
        0xF0, 0x80, 0xF0, 0x80, 0xF0, -- E
        0xF0, 0x80, 0xF0, 0x80, 0x80  -- F
    }

    -- The CHIP-8 program actually starts at 01FC, by first clearing
    -- the screen, and then turning on the display. In case any ROMs
    -- actually do this during execution, we make sure to adhere to this.
    self.rom[0x1FD] = 0xE0
    self.rom[0x1FF] = 0x4B

    for i, byte in ipairs(fontset) do
        self.rom[0x050+(i-1)] = byte
    end

    local address = 0x200
    while (not file:isEOF()) do 
        -- TODO: should be 0x69F with 2K RAM
        if address > 0xE8F then
            print("Warning: ROM spills into VIP memory reserved for variables and display refresh")
        end

        local byte, len = file:read(1)
        -- Dropped files don't seem to report EOF
        if len ~= 1 or not string.byte(byte) then
            break
        end
        self.rom[address] = string.byte(byte)
        address = address + 1
    end
end

function CPU:cycle()
    local byte1 = self.rom[self.pc]
    local byte2 = self.rom[self.pc+1]

    local opcode = bit.bor(bit.lshift(byte1, 8), byte2)

    self.pc = self.pc + 2

    return opcode
end

return CPU