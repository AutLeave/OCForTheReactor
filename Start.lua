--此模块仅适用于单OC组件
local computer = require("computer")
local component = require("component")
local transposer = component.transposer
local redstone = component.redstone
local reactor = component.reactor_chamber
---------------------
--上：1 --下：0 --北：2 --南：3 --西：4 --东：5 （方向用于转运器访问容器）
---------------------
local inputBox = 3
local outputBox = 2
local reactorSide = 4
---------------------
--配置数据
local config = {
    Freezeee = { --配置名称
        {
            name = "gregtech:gt.360k_Helium_Coolantcell",
            changeName = -1,
            dmg = 90, --损坏大于90%就更换
            count = 14,
            slot = {3,6,9,10,15,22,26,29,33,40,45,46,49,52}
        },
        {
            name = "gregtech:gt.reactorUraniumQuad",
            changeName= "IC2:reactorUraniumQuaddepleted",
            dmg = -1,
            count = 40,
            slot = {1,2,4,5,7,8,11,12,13,14,16,17,18,19,20,21,23,24,25,27,
                    28,30,31,32,34,35,36,37,38,39,41,42,43,44,47,48,50,51,53,54}
        }
    }
}
---------------------
--开机(函数第一个数字为反应堆相对于红石IO端口的方向，默认IO放在反应堆上方)
local function start() 
    redstone.setOutput(0,14)
end

--关机
local function stop() 
    redstone.setOutput(0,0)
end

--检查输入箱子
local function checkInputBox(itemName, itemCount)
    local itemSum = 0
    local inputBoxItems = transposer.getAllStacks(inputBox)

    for slot = 1, inputBoxItems.count() do
        local item = inputBoxItems[slot]

        if item and item.name == itemName then
            itemSum = itemSum + item.size
        end
    end

    return itemSum >= itemCount
end

--配置选择
local function configSelect()
    print("\n当前配置方案有：")
    for name, _ in pairs(config) do
        print("--- " .. name)
    end

    print("\n请输入你要以哪个配置文件运行(直接输配置名)：")
    local projectName = io.read()
    local project = config[projectName]

    if not project then
        print("输入有误，没有该配置，请重启重新输入")
        os.exit(0)
    end

    return project
end

--填充反应堆
local function firstInsertItem(project)
    local inputBoxItems = transposer.getAllStacks(inputBox)

    for _,itemConfig in ipairs(project) do
        for _, slot in ipairs(itemConfig.slot) do           --slot为反应堆位置编号
            for BoxSlot = 1, inputBoxItems.count() do       --BoxSlot为输入箱子所需要转移的物品所在的位置编号
                local item = inputBoxItems[BoxSlot]
                if item and item.name == itemConfig.name then
                    transposer.transferItem(inputBox, reactorSide, 1, BoxSlot, slot)
                    print("已将" .. itemConfig.name .. "放置进反应堆")
                break
                end
            end
        end
    end
end

--反应堆热能监测
local function checkHeat()
    local heat = reactor.getHeat()
    if heat >= 1000 then
        stop()
        print("过热，已停机，请处理热量等待机器重启")
        return false
    end

    if heat < 1000 then
        start()
        return true
    end
end


--移除物品
local function removeItem(slot, removeBox)
    for i = 1, 5 do
        if transposer.transferItem(reactorSide, removeBox, 1, slot) == 0 then
            print("移除失败，可能是输出箱子满了，请处理")
            os.sleep(10)
        else
            print("移除物品成功")
            return true
        end
    end
    return false
end

--添加物品
local function insertItem(sinkSlot, itemName)
    for i = 1, 5 do
        if checkInputBox(itemName, 1) then
            local inputBoxItems = transposer.getAllStacks(inputBox)

            for slot = 1, inputBoxItems.count() do
                local item = inputBoxItems[slot]
                if item and item.name == itemName then
                    transposer.transferItem(inputBox, reactorSide, 1, slot, sinkSlot)
                    print("添加物品" .. itemName .."成功")
                    return true
                end
            end
        else
            print("输入箱子中没有" .. itemName .. "物品，请补充")
            os.sleep(10)
        end
    end
    return false
end

--替换物品
local function replaceItem(slot, removeBox, itemName)
    stop()

    if removeItem(slot, removeBox) then
        if insertItem(slot, itemName) then
            return true
        end
    end
    return false
end

--检查反应堆状态
local function checkReactor(project)
    local reactorItems = transposer.getAllStacks(reactorSide)
    
    local itemCount = reactorItems.count()
    if itemCount == 0 then
        print("反应堆为空")
        return false
    end

    local statusChanged = false
    for _, itemConfig in ipairs(project) do
        for _, slot in ipairs(itemConfig.slot) do
            local item = reactorItems[slot]

            if itemConfig.dmg ~= -1 then
                if item and item.damage and item.damage >= itemConfig.dmg then
                    print(itemConfig.name .. "需要更换，正在更换")
                    if replaceItem(slot, outputBox, itemConfig.name) then
                        statusChanged = true
                    end
                elseif not item then
                    print("位置：" .. slot .. "缺失物品，正在补充")
                    stop()
                    if insertItem(slot, itemConfig.name) then
                        statusChanged = true
                    end
                end
            
            else
                if item and item.name ~= itemConfig.name 
                    and item.name == itemConfig.changeName then
                        print("某燃料棒已耗尽，正在更换")
                        if replaceItem(slot, outputBox, itemConfig.name) then
                            statusChanged = true
                        end
                elseif not item then
                    print("位置：" .. slot .. "缺失物品，正在补充")
                    stop()
                    if insertItem(slot, itemConfig.name) then
                        statusChanged = true
                    end
                end
            end
        end
    end

    return statusChanged
end

--显示反应堆状态--40s刷新
local function displayStatus(project)
    os.execute("cls")
    print("-------当前反应堆状态--------\n")
    print("热量为：" .. reactor.getHeat())

    local reactorItems = transposer.getAllStacks(reactorSide)
    print("\n------内部状态-------\n")
    for _, itemConfig in ipairs(project) do
        local count = 0
        for _, slot in ipairs(itemConfig.slot) do
            local item = reactorItems[slot]
            if item and item.name == itemConfig.name then
                count = count + 1
            end
        end

        print(string.format("%-40s: %d/%d 位置验证完成",itemConfig.name, count, #itemConfig.slot))
    end

    print("\n-----------------------\n")
end

--主循环监控反应堆
local function MainLoop(project)
    print("--------正在启动反应堆--------")
    local lastStatusTime = computer.uptime()

    while true do
        ::continue::
        if checkReactor(project) then
            os.sleep(1)
            goto continue
        end

        if not checkHeat() then
            os.sleep(3)
        end

        --玩家手动暂停程序，未实装
        --if playerStop() then
            --stop()
        --else
            --start()
        --end

        --玩家手动关闭程序，未实装
        --if playerEnd() then
            --os.exit(0)
        --end

        --电容检测自动启停，未实装
        --if isEnergyEnough() then
            --stop()
        --else
            --start()
        --end
            

        if computer.uptime() - lastStatusTime >= 40 then
            displayStatus(project)
            lastStatusTime = computer.uptime()
        end

        os.sleep(1)
    end
end

--初次运行反应堆，从0开始放置
local function firstInsertItemCheck(project)
    --检查输入箱子材料是否足够
    local isEnough = true
    for _, itemConfig in ipairs(project) do
        if not checkInputBox(itemConfig.name, itemConfig.count) then
            print(itemConfig.name .. "不足，应有数量为：" .. itemConfig.count)
            isEnough = false
        end
    end

    if not isEnough then
        print("等待30s后重新检查")
        os.sleep(30)
        return firstInsertItemCheck(project)
    end

    firstInsertItem(project)
    MainLoop(project)
end

--初次启动，进行检查反应堆
local function startReactor()
    local project = configSelect() --加载配置

    local isOK = checkReactor(project)
    if not isOK then
        firstInsertItemCheck(project)
    end

    MainLoop(project)
end

--检测组件和反应堆是否成功识别
local function checkSystem()
    print("--正在检查组件和反应堆是否成功安装--")
    if redstone then
        print("红石IO端口正常")
    else
        print("红石IO端口异常,正在中止程序")
        os.exit(0)
    end

    if transposer then
        print("转运器正常")
    else
        print("转运器异常,正在中止程序")
        os.exit(0)
    end

    if reactor then
        print("适配器正常且反应堆正常识别")
    else
        print("适配器异常或反应堆无法识别,正在中止程序")
        os.exit(0)
    end
    print("自检完成，正在启动反应堆")
end

--主程序
local function Mainstart()
    stop()
    checkSystem()
    startReactor()
end

---------------------
--程序开始
print("正在检查反应堆，请注意，不要在反应堆运行期间关闭主机，后果自负")
Mainstart()