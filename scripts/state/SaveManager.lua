-- ============================================================================
-- SaveManager: 存档管理
-- ============================================================================
local GameState = require("state.GameState")

local SaveManager = {}
local SAVE_FILE = "fishing_save.json"
local SAVE_VERSION = 1

--- 保存游戏
function SaveManager:save()
    local saveData = {
        version = SAVE_VERSION,
        timestamp = os.time(),
        state = GameState:serialize(),
    }
    local file = File(SAVE_FILE, FILE_WRITE)
    if file:IsOpen() then
        file:WriteString(cjson.encode(saveData))
        file:Close()
        print("[SaveManager] 存档成功")
        return true
    end
    print("[SaveManager] 存档失败: 无法打开文件")
    return false
end

--- 加载游戏
function SaveManager:load()
    if not fileSystem:FileExists(SAVE_FILE) then
        print("[SaveManager] 无存档文件，初始化新游戏")
        return false
    end
    local file = File(SAVE_FILE, FILE_READ)
    if not file:IsOpen() then
        print("[SaveManager] 读取存档失败")
        return false
    end
    local content = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, content)
    if not ok or not data then
        print("[SaveManager] 解析存档失败")
        return false
    end

    if data.version and data.state then
        GameState:deserialize(data.state)
        print("[SaveManager] 存档加载成功, 版本:" .. data.version)
        return true
    end
    return false
end

--- 自动存档计时器
SaveManager.autoSaveTimer_ = 0

function SaveManager:update(dt)
    self.autoSaveTimer_ = self.autoSaveTimer_ + dt
    if self.autoSaveTimer_ >= 30 then
        self.autoSaveTimer_ = 0
        self:save()
    end
end

return SaveManager
