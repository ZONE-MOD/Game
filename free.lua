local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {},
  LuaEventContainer = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
}

local ENetRole = import("ENetRole")
local EPawnState_1 = import("EPawnState")
local GameplayData_3 = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools_1 = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local KismetMathLibrary_1 = import("KismetMathLibrary")
local GameplayStatics_1 = import("GameplayStatics")
local InGameMarkTools_1 = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")

local var_85 = os.time(os.date("!*t"))
local var_151 = os.time({ year = 2028, month = 5, day = 15, hour = 6, min = 45, sec = 0 })

if var_85 <= var_151 then
    local logic_setting_graphics_1 = package.loaded["client.slua.logic.setting.logic_setting_graphics"] or require("client.slua.logic.setting.logic_setting_graphics")
    local GSC_FPS_1 = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
    local GSC_FPSFT_1 = package.loaded["client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT"] or require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
    local GraphicSettingDB_1 = package.loaded["client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB"] or require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")

    if logic_setting_graphics_1 then
        local var_132 = logic_setting_graphics_1.SetFPS
        function logic_setting_graphics_1.SetFPS(gameInstance, FPSLevel)
            if FPSLevel == 8 and GraphicSettingDB_1 then
                local var_234 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch)
                if not var_234 then
                    GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.FPSFineTuneSwitch, true)
                end
            end
            if var_132 then
                var_132(gameInstance, FPSLevel)
            end
            if FPSLevel == 8 and GraphicSettingDB_1 then
                GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.FPSFineTuneNum, 165)
                gameInstance:ExecuteCMD("t.MaxFPS", "165")
                gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
            end
        end
    end

    if GSC_FPS_1 and GSC_FPS_1.__inner_impl then
        local var_160 = GSC_FPS_1.__inner_impl
        function var_160:GetMaxFPSLevel() return 8, 8 end
        function var_160:CanChangeQualityAndFPSPreCheck() return true end
        function var_160:InitRealSupportFPS()
            local var_29 = {}
            for i = 1, 8 do var_29[i] = {true, true} end
            if GraphicSettingDB_1 then GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.RealSupportFPS, var_29, false) end
            return var_29
        end
        function var_160:SetFPSAndQualityEnable(bEnable)
            if self.UIRoot and self.UIRoot.Image_Mask then self:SetWidgetVisible(self.UIRoot.Image_Mask, false) end
        end
        function var_160:UpdateSelectedFPSState(selectedLevel)
            local var_37 = { [2]="NodeFps20", [3]="NodeFps25", [4]="NodeFps30", [5]="NodeFps40", [6]="NodeFps60", [7]="NodeFps90", [8]="NodeFps120" }
            if not self.UIRoot then return end
            for level, name in pairs(var_37) do
                if self.UIRoot[name] then
                    self:WidgetSelfHit(self.UIRoot[name])
                    self.UIRoot[name]:SetIsEnabled(true)
                    local var_54 = self.UIRoot["WidgetSwitcher_" .. level]
                    if var_54 then var_54:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) end
                end
            end
        end
        local var_58 = var_160.UpdateUI
        function var_160:UpdateUI()
            if var_58 then pcall(var_58, self) end
            self:SelfHitTestInvisible()
            self:InitRealSupportFPS()
            self:SetFPSAndQualityEnable(true)
            local var_222 = 8
            if GraphicSettingDB_1 then
                if GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.CustomTab) == 2 then
                    var_222 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.LobbyFPS) or 8
                else
                    var_222 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.SelectedFPS) or 8
                end
            end
            self:UpdateSelectedFPSState(var_222)
        end
        function var_160:DoClickFPS(FPSLevel)
            if slua.isValid(self.UIRoot) then
                if GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.CustomTab) == 2 then
                    GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.LobbyFPS, FPSLevel)
                else
                    GraphicSettingDB_1:UpdateSelectedFPS(FPSLevel)
                end
                self:UpdateSelectedFPSState(FPSLevel)
                if self:GetParentUI() then
                    self:GetParentUI():SaveQualityAndFPS()
                    self:GetParentUI():SetDirty(true)
                end
            end
        end
    end

    if GSC_FPSFT_1 and GSC_FPSFT_1.__inner_impl then
        local var_13 = GSC_FPSFT_1.__inner_impl
        local var_93, var_203 = 90, 5
        local function func_6(val, min, max) return val < min and min or (val > max and max or val) end
        function var_13:ShowOrHide()
            self:SelfHitTestInvisible()
            if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
        end
        function var_13:InitFPSFTSwitch()
            local sw = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch)
            if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(sw, true) end
            if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, sw) end
            if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
            if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
        end
        function var_13:InitFPSFTValue165()
            local var_202 = self.UIRoot
            local sw = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch)
            local var_69 = sw and GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneNum) or 165
            var_202.Slider_screen3:SetLocked(not sw)
            var_202.ProgressBar_screen3:SetFillColorAndOpacity(sw and FLinearColor(1,1,1,1) or FLinearColor(1,0.625,0.6,1))
            local var_60 = (var_69 - var_93) / (165 - var_93)
            var_202.Veihclescreen3:SetText(LocUtil.LocalizeResFormat(10567, var_69))
            var_202.Slider_screen3:SetValue(var_60)
            var_202.ProgressBar_screen3:SetPercent(var_60)
        end
        function var_13:OnFPSFTValueChange3(var_69)
            GraphicSettingDB_1:UpdateUIData(GraphicSettingDB_1.FPSFineTuneNum, var_69)
            self:InitFPSFTValue165()
            if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
            local var_43 = GraphicSettingDB_1.GetGameInstance and GraphicSettingDB_1.GetGameInstance()
            if var_43 then
                var_43:ExecuteCMD("t.MaxFPS", tostring(var_69))
                var_43:ExecuteCMD("r.FrameRateLimit", tostring(var_69))
            end
        end
        function var_13:OnFPSFTSliderValueChange3(var_174)
            if GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneSwitch) then
                local var_69 = KismetMathLibrary_1.FCeil(var_174 * (165 - var_93) / var_203) * var_203 + var_93
                self:OnFPSFTValueChange3(func_6(var_69, var_93, 165))
            end
        end
        function var_13:OnFPSFTAdd3()
            local var_69 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneNum)
            if var_69 then self:OnFPSFTValueChange3(math.min(165, var_69 + var_203)) end
        end
        function var_13:OnFPSFTMinus3()
            local var_69 = GraphicSettingDB_1:GetUIData(GraphicSettingDB_1.FPSFineTuneNum)
            if var_69 then self:OnFPSFTValueChange3(math.max(var_93, var_69 - var_203)) end
        end
        var_13.OnFPSFTAdd = var_13.OnFPSFTAdd3
        var_13.OnFPSFTMinus = var_13.OnFPSFTMinus3
        var_13.OnFPSFTSliderValueChange = var_13.OnFPSFTSliderValueChange3
    end
end

-- ============================================================
-- ============================================================
-- TESTED BYPASS LAYERS - FULL INTEGRATION
-- ============================================================
-- ============================================================

local function nop() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retNil() return nil end
local function retTrue() return true end
local function retEmptyString() return "" end

local function InitializeSLUABypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local loader = package.loaded["slua.loader"] or rawget(_G, "slua_loader")
        if loader then
            loader.verifyBytecode = retTrue
            loader.checkIntegrity = retTrue
            if loader.disableSignatureCheck then loader.disableSignatureCheck = retTrue end
        end
        local slua_serialize = package.loaded["slua.serialize"]
        if slua_serialize then slua_serialize.check = retTrue; slua_serialize.verify = retTrue end
        if jit and jit.attach then jit.attach(function() end, "bc") end
        if _G.slua_verify then _G.slua_verify = retTrue end
        if _G.check_slua_integrity then _G.check_slua_integrity = retTrue end
    end)
end

local function InitializeMD5Bypass()
    pcall(function()
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "pakchunk.EnableSignatureCheck 0")
            console.ExecuteConsoleCommand(nil, "s.VerifyPak 0")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
            console.ExecuteConsoleCommand(nil, "security.DisableChecks 1")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then
            CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
            CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
            CMode.GetContentDiffData = function() return true, "BYPASSED" end
            CMode.VerifyFileIntegrity = retTrue
        end
        if _G.MD5Hash then _G.MD5Hash = function() return "00000000000000000000000000000000" end end
        if _G.CRC32 then _G.CRC32 = function() return 0 end end
        if _G.SHA1 then _G.SHA1 = function() return "BYPASS" end end
        local FileHashChecker = package.loaded["common.file_hash_checker"]
        if FileHashChecker then
            FileHashChecker.CheckFileMD5 = retTrue; FileHashChecker.VerifyAll = retTrue
            FileHashChecker.GetHash = function() return "BYPASS" end
        end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then TssSdk.GetFileMD5 = function() return "BYPASS" end; TssSdk.VerifyFileSignature = retTrue end
        local STExtra = import("STExtraBlueprintFunctionLibrary")
        if STExtra then STExtra.CheckMD5 = retTrue; STExtra.GetMD5 = function() return "BYPASS" end; STExtra.VerifyFile = retTrue end
    end)
end

local function InitializeSkinBypass()
    pcall(function()
        local ptlog = package.loaded["client.slua.logic.download.report.puffer_tlog"]
        if ptlog then ptlog.ReportEvent = nop; ptlog.ReportDownloadResult = nop; ptlog.ReportODPTDError = nop; ptlog.ReportSkinError = nop end
        local AvatarUtils = package.loaded["AvatarUtils"]
        if AvatarUtils then AvatarUtils.CheckIsWeaponInBlackList = retFalse; AvatarUtils.IsValidAvatar = retTrue; AvatarUtils.CheckAvatarIntegrity = retTrue; AvatarUtils.ReportInvalidAvatar = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("FileCheckSubsystem")
        if sub then sub.StartCheck = nop; sub.ReportAbnormalFile = nop; sub.StopCheck = nop end
        local eqEx = package.loaded["client.slua.logic.report.EquipmentExceptionReport"]
        if eqEx then eqEx.Report = nop; eqEx.SendException = nop end
    end)
end

local function InitializeLogBlocker()
    pcall(function()
        local SMTD = import("ScreenshotMTDer")
        if SMTD then SMTD.MTDePicture = function() return "" end; SMTD.ReMTDePicture = function() return "" end; SMTD.HasCaptured = retTrue; SMTD.TakeScreenshot = nop end
        local TLog = package.loaded["TLog"] or _G.TLog
        if TLog then TLog.Info = nop; TLog.Warning = nop; TLog.Error = nop; TLog.Debug = nop; TLog.Report = nop; TLog.Send = nop; TLog.Flush = nop end
        local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
        if CrashSight then CrashSight.ReportException = nop; CrashSight.SetCustomData = nop; CrashSight.Log = nop; CrashSight.SendCrash = nop; CrashSight.ReportUserException = nop end
        local GRUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
        if GRUtils then GRUtils.BugglyPostExceptionFull = retFalse; GRUtils.CheckCanBugglyPostException = retFalse; GRUtils.ReplayReportData = nop; GRUtils.ReportGameException = nop; GRUtils.PostException = nop end
        local CTR = package.loaded["client.slua.logic.report.ClientToolsReport"]
        if CTR then CTR.SendReport = nop; CTR.SendException = nop; CTR.UploadLog = nop end
        for _, sdk in ipairs({"Firebase", "Adjust", "AppsFlyer", "FacebookAnalytics", "GameAnalytics"}) do
            local s = _G[sdk]; if s then s.logEvent = nop; s.trackEvent = nop; s.setEnabled = retFalse; s.sendEvent = nop; s.report = nop end
        end
    end)
end

local function InitializeScannerBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local subs = {"AFKReportorSubsystem", "ClientDataStatistcsSubsystem", "AvatarExceptionSubsystem", "ShootVerifySubSystemClient", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "FileCheckSubsystem", "BehaviorScoreSubsystem"}
            for _, name in ipairs(subs) do
                local sub = SubMgr:Get(name)
                if sub then
                    for k, v in pairs(sub) do
                        if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect")) then pcall(function() sub[k] = nop end) end
                    end
                    if sub.ReportPingDelayTimer then sub:RemoveGameTimer(sub.ReportPingDelayTimer); sub.ReportPingDelayTimer = nil end; sub.DelayCount = 0
                end
            end
        end
        local AvaEx = package.loaded["GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst"]
        if AvaEx then AvaEx.CheckAvatarException = nop; AvaEx.CheckAvatarExceptionOnce = nop; AvaEx.ReportAvatarException = nop; AvaEx.CheckSlotMeshVisible = retFalse; AvaEx.CheckPawnVisible = retFalse; AvaEx.CheckCanBugglyPostException = retFalse end
        local TssSdk = package.loaded["TssSdk"] or _G.TssSdk
        if TssSdk then
            local origData = TssSdk.OnRecvData
            TssSdk.OnRecvData = function(data) if type(data) == "string" and (data:find("report", 1, true) or data:find("exception", 1, true) or data:find("cheat", 1, true) or data:find("violation", 1, true) or data:find("hack", 1, true) or data:find("verify", 1, true)) then return end; if origData then origData(data) end end
            TssSdk.SendReportInfo = nop; TssSdk.ScanMemory = retTrue; TssSdk.IsEmulator = retFalse; TssSdk.GetTssSdkReportInfo = retEmptyString; TssSdk.CheckEnvironment = retTrue; TssSdk.VerifyProcess = retTrue
        end
    end)
end

local function InitializeReplayTelemetryBlocker()
    pcall(function()
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            for _, name in ipairs({"GameReportSubsystem", "ReplaySubsystem"}) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Trace") or k:find("Replay") or k:find("Record") or k:find("Save")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        local logRep = package.loaded["client.slua.logic.replay.logic_report_replay"]
        if logRep then logRep.ReportReplay = nop; logRep.SendReportReq = nop; logRep.UploadReplay = nop end
    end)
end

local function InitializeReportFlowBlocker()
    pcall(function()
        local flows = {"ReportAimFlow", "ReportHitFlow", "ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "ReportEquipmentFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "ReportCircleFlow", "ReportSecMrpcsFlow"}
        for _, f in ipairs(flows) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        for _, f in ipairs({"CheckReportSecAttackFlowWithAttackFlow", "CheckReportSecAttackFlow"}) do if _G[f] then _G[f] = retFalse end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = retFalse end end
        for _, f in ipairs({"IsEnableReportMrpcsInCircleFlow", "IsEnableReportMrpcsInPartCircleFlow", "IsEnableReportMrpcsFlow", "IsEnableReportAttackFlow", "IsEnableReportHitFlow", "IsEnableReportCircleFlow"}) do if _G[f] then _G[f] = retFalse end end
    end)
end

local function InitializePlayerSecurityBypass()
    pcall(function()
        for _, c in ipairs({"PlayerSecurityInfoCollector", "PlayerSecurityInfo", "SecurityInfoCollector", "ClientSecurityCollector", "PlayerAntiCheatCollector"}) do
            if _G[c] then for k, v in pairs(_G[c]) do if type(v) == "function" and (k:find("Report") or k:find("Collect") or k:find("Send") or k:find("Upload") or k:find("Record")) then _G[c][k] = nop end end end
        end
        local SecSub = require("GameLua.Mod.BaseMod.Common.Security.PlayerSecurityInfoSubsystem")
        if SecSub then SecSub.ReportData = nop; SecSub.CheckCheat = retFalse; SecSub.ValidatePlayer = retTrue; SecSub.CollectData = nop; SecSub.SendToServer = nop end
    end)
end

local function InitializeClientFlowBypass()
    pcall(function()
        for _, name in ipairs({"ClientSecMrpcsFlow", "MrpcsFlow", "MrpcsData", "ClientCircleFlowSubsystem", "ClientKillFlowSubsystem", "ClientSecPlayerKillFlow"}) do
            local sub = package.loaded[name] or _G[name]
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Flow") or k:find("Record") or k:find("Process")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeSwiftHawkBypass()
    pcall(function()
        for _, f in ipairs({"SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams", "SendSwiftHawkData"}) do if _G[f] then _G[f] = nop end; if _G.GameplayCallbacks and _G.GameplayCallbacks[f] then _G.GameplayCallbacks[f] = nop end end
        local sub = package.loaded["GameLua.Mod.BaseMod.Client.Security.SwiftHawkSubsystem"]
        if sub then sub.ReportData = nop; sub.SendReport = nop; sub.CollectTelemetry = nop end
    end)
end

local function InitializeCoronaLabBypass()
    pcall(function()
        if _G.CoronaLab then _G.CoronaLab.ReportData = nop; _G.CoronaLab.SendData = nop; _G.CoronaLab.CollectData = nop; _G.CoronaLab.Telemetry = nop end
        local sub = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr"):Get("CoronaLabSubsystem")
        if sub then sub.ReportData = nop; sub.SendToServer = nop; sub.CollectTelemetry = nop; sub.StopCollection = nop end
    end)
end

local function InitializeModifierExceptionBypass()
    pcall(function()
        if _G.bReportedModifierException then _G.bReportedModifierException = false end
        local sub = require("GameLua.Mod.BaseMod.Common.Security.ModifierExceptionSubsystem")
        if sub then sub.ReportException = nop; sub.CheckModifier = retTrue; sub.ValidateModifier = retTrue; sub.ReportModifierError = nop end
    end)
end

local function InitializeSimulateCharacterLocationBypass()
    pcall(function()
        local sub = require("GameLua.Mod.BaseMod.Gameplay.Simulate.SimulateCharacterSubsystem")
        if sub then sub.ReportLocation = nop; sub.SendLocationData = nop; sub.VerifyLocation = retTrue end
    end)
end

local function InitializeShootVerificationBypass()
    pcall(function()
        local sub = require("GameLua.Dev.Subsystem.ShootVerifySubSystemClient")
        if sub then sub.OnShootVerifyFailed = nop; sub.SendVerifyData = nop; sub.ReportBulletHit = nop; sub.UploadHitInfo = nop; sub.VerifyShot = retTrue end
        if _G.BulletHitInfoUploadData then _G.BulletHitInfoUploadData.Report = nop; _G.BulletHitInfoUploadData.Send = nop; _G.BulletHitInfoUploadData.Upload = nop end
    end)
end

local function InitializeNetworkPacketBlock()
    pcall(function()
        if not NetUtil then return end

        if type(NetUtil.SendTss) == "function" then
            NetUtil.SendTss = function() return nil end
        end
        if type(NetUtil.OnTssRsp) == "function" then
            NetUtil.OnTssRsp = function() return nil end
        end
        if type(NetUtil.GEMReportSubEvent) == "function" then
            NetUtil.GEMReportSubEvent = function() return nil end
        end

        if type(NetUtil.SendPkg) == "function" and not _G.__ZD_SendPkgHooked then
            _G.__ZD_SendPkgHooked = true
            local origSendPkg = NetUtil.SendPkg
            local blockedPkgs = {
                ["ReportAimFlow"]=1, ["ReportHitFlow"]=1,
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1,
                ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1,
                ["ReportMrpcsFlow"]=1, ["ReportPlayerBehavior"]=1,
                ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1,
                ["ReportPlayerPosition"]=1, ["ReportVehicleMoveFlow"]=1,
                ["ReportCircleFlow"]=1, ["ReportParachuteData"]=1,
                ["ReportEquipmentFlow"]=1, ["ReportPlayersPing"]=1,
                ["ReportPlayerIP"]=1, ["ReportDSNetSaturation"]=1,
                ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_speed_hack"]=1, ["report_wall_hack"]=1,
                ["report_modded_files"]=1, ["report_unrealnet_exception"]=1,
                ["tss_report"]=1, ["tss_sdk_report"]=1,
                ["on_tss_sdk_anti_data"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1,
                ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1,
                ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1,
                ["SwiftHawkData"]=1,
                ["detect_cheat"]=1, ["ban_player"]=1,
                ["client_anti_cheat_report"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1,
                ["ViolationReport"]=1, ["SecurityViolation"]=1,
                ["IntegrityCheck"]=1, ["SignatureVerify"]=1,
                ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1
            }
            NetUtil.SendPkg = function(pkgName, ...)
                if pkgName and blockedPkgs[pkgName] then
                    return nil
                end
                return origSendPkg(pkgName, ...)
            end
        end
    end)
end

local function InitializeHiggsBosonBypass()
    pcall(function()
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "Tick", "OnTick", "MHActiveLogic", "TriggerAvatarCheck", "StartAvatarCheck", "ReportItemID", "ReceiveAnyDamage", "OnWeaponHitRecord", "ShowSecurityAlert", "ServerReportAvatar", "ClientReportNetAvatar", "SendHisarData", "ValidateSecurityData", "StaticShowSecurityAlertInDev", "RPC_Client_ShootVertifyRes", "RPC_Server_ReportSimulateCharacterLocation", "DisableHiggsBoson", "CheckMHActive", "ReportViolation", "ProcessSecurityEvent", "ValidatePlayer", "CheckIntegrity"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.GetNetAvatarItemIDs = retEmpty; Higgs.GetCurWeaponSkinID = retZero; Higgs.IsMHActive = retFalse; Higgs.bMHActive = false; Higgs.bCallPreReplication = false
            if Higgs.BlackList then for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end end
        end
        _G.BlackList = {}
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false; if pc.HiggsBoson.ControlMHActive then pc.HiggsBoson:ControlMHActive(0) end end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false; pc.HiggsBosonComponent:ControlMHActive(0) end
        end
    end)
end

local function InitializeAntiCheatHooks()
    pcall(function()
        local HBC = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if HBC and HBC.StaticShowSecurityAlertInDev then HBC.StaticShowSecurityAlertInDev = nop end
    end)
    if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = nop; _G.AvatarCheckCallback.OnReportItemID = nop
        _G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
            if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then PlayerController.HiggsBosonComponent:ControlMHActive(0); PlayerController.HiggsBosonComponent.bMHActive = false end
        end
    end
end

local function InitializeAntiReport()
    pcall(function()
        for _, path in ipairs({"GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem", "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"}) do
            local sub = package.loaded[path]; if not sub then local s, r = pcall(require, path); if s and r then sub = r end end
            if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Record") or k:find("Send") or k:find("Upload") or k:find("Notify")) then pcall(function() sub[k] = nop end) end end end
        end
    end)
end

local function InitializeGameplayBypass()
    pcall(function()
        if not _G.GameplayCallbacks then _G.GameplayCallbacks = {} end
        if _G.GameplayCallbacks.IsBypassed then return end
        local GC = _G.GameplayCallbacks
        local reports = {"ReportAttackFlow", "ReportSecAttackFlow", "ReportFireArms", "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt", "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition", "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData", "SendTssSdkAntiDataToLobby", "ReportEquipmentFlow", "ReportAimFlow", "ReportPlayersPing", "ReportPlayerIP", "ReportPlayerFramePingRecord", "OnDSConnectionSaturated", "ReportDSNetSaturation", "ReportNetContinuousSaturate", "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow", "ClientSecMrpcsFlow", "SwiftHawk", "ClientSwiftHawk", "ClientSwiftHawkWithParams"}
        for _, f in ipairs(reports) do GC[f] = nop end
        GC.CheckReportSecAttackFlowWithAttackFlow = retFalse; GC.CheckReportSecAttackFlow = retFalse
        local origState = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, State, bPure, bSafe, Param)
            local s = State and string.lower(tostring(State)) or ""
            local blocked = {["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1, ["connectionexception"]=1, ["netdrivererror"]=1, ["banned"]=1, ["kicked"]=1, ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1, ["securityviolation"]=1}
            if blocked[s] then return end
            if origState then pcall(origState, UID, State, bPure, bSafe, Param) end
        end
        GC.OnPlayerNetConnectionClosed = nop; GC.OnPlayerActorChannelError = nop; GC.OnPlayerRPCValidateFailed = nop; GC.OnPlayerSpectateException = nop; GC.OnShutdownAfterError = nop; GC.IsBypassed = true
    end)
end

local function InitializeKillAllSubsystems()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not subMgr then return end
        local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "SimulateCharacterSubsystem", "ShootVerifySubSystemClient", "HiggsBosonComponent", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem", "ClientHawkEyePatrolSubsystem", "DSHawkEyePatrolSubsystem", "ClientDataStatistcsSubsystem", "AFKReportorSubsystem", "BehaviorScoreSubsystem", "FileCheckSubsystem", "MemoryCheckSubsystem", "SpeedCheckSubsystem", "WallCheckSubsystem", "AvatarExceptionSubsystem", "GameReportSubsystem", "ClientSecMrpcsFlowSubsystem", "MrpcsFlowSubsystem", "CircleFlowSubsystem", "SwiftHawkSubsystem", "AntiCheatSubsystem", "IntegrityCheckSubsystem", "SignatureVerifySubsystem", "MD5CheckSubsystem", "PakVerifySubsystem"}
        for _, name in ipairs(toKill) do
            local sub = subMgr:Get(name)
            if sub then
                for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Upload") or k:find("Verify") or k:find("Check") or k:find("Validate") or k:find("Scan") or k:find("Detect") or k:find("Collect") or k:find("Flow") or k:find("Heartbeat")) then pcall(function() sub[k] = nop end) end end
                if sub.timer then pcall(function() sub:RemoveGameTimer(sub.timer) end) end
                if sub.heartbeatTimer then pcall(function() sub:RemoveGameTimer(sub.heartbeatTimer) end) end
                if sub.reportTimer then pcall(function() sub:RemoveGameTimer(sub.reportTimer) end) end
            end
        end
    end)
end

local function InitializeFinalProtection()
    pcall(function()
        for _, flag in ipairs({"ENABLE_REPORT", "ENABLE_ANTI_CHEAT", "ENABLE_SECURITY", "ENABLE_TELEMETRY", "ENABLE_ANALYTICS", "ENABLE_CRASH_REPORT", "ENABLE_PERFORMANCE_REPORT"}) do if _G[flag] then _G[flag] = false end end
        local origReq = require
        local blocked = {"HiggsBosonComponent", "PlayerSecurityInfoSubsystem", "CoronaLabSubsystem", "ClientCircleFlowSubsystem", "ModifierExceptionSubsystem", "ShootVerifySubSystemClient", "ClientReportPlayerSubsystem", "DSReportPlayerSubsystem"}
        _G.require = function(m) for _, b in ipairs(blocked) do if m:find(b) then return {} end end; return origReq(m) end
    end)
end

local function InitializeOperationalStatsBypass()
    pcall(function()
        local subMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        local OperationalStatsSubsystem = (subMgr and subMgr:Get("OperationalStatsSubsystem")) or _G.OperationalStatsSubsystem
        if OperationalStatsSubsystem then
            OperationalStatsSubsystem.ReportOperationalStats = nop
            OperationalStatsSubsystem.AddOperationalStats = nop
            OperationalStatsSubsystem.HandleTouchBegin = nop
            OperationalStatsSubsystem.HandleTouchEnd = nop
            OperationalStatsSubsystem.OnInit = nop
            OperationalStatsSubsystem.HandleEnterFighting = nop
            OperationalStatsSubsystem.OnBattleResult = nop
            if OperationalStatsSubsystem.TimerHandle then
                pcall(function() OperationalStatsSubsystem:RemoveGameTimer(OperationalStatsSubsystem.TimerHandle) end)
                OperationalStatsSubsystem.TimerHandle = nil
            end
            OperationalStatsSubsystem.StatsData = {}
            print("[ULTIMATE BYPASS] OperationalStatsSubsystem blocked!")
        end
    end)
end

local function InitializeAggressiveComponentKiller()
    pcall(function()
        local names = {"HiggsBosonComponent","HiggsBoson","SecurityComponent",
            "AntiCheatComponent","CoronaLabComponent","SwiftHawkComponent",
            "GokubaComponent","PlayerSecurityComponent","BehaviorComponent",
            "ReportComponent"}
        _G.__ZD_KilledComponents = _G.__ZD_KilledComponents or setmetatable({}, { __mode = "k" })
        local function Kill(actor)
            if not (slua and slua.isValid and slua.isValid(actor)) then return 0 end
            local killed = 0
            for _, cn in ipairs(names) do
                local comp = actor[cn]
                if slua.isValid(comp) then
                    if _G.__ZD_KilledComponents[comp] then
                        if comp.bMHActive == true or comp.bEnabled == true then
                            pcall(function()
                                comp.bMHActive = false
                                comp.bEnabled = false
                            end)
                        end
                    else
                        killed = killed + 1
                        pcall(function()
                            comp.bMHActive = false
                            comp.bCallPreReplication = false
                            comp.bEnabled = false
                            comp.Enabled = false
                        end)
                        for k, v in pairs(comp) do
                            if type(v) == "function" then
                                pcall(function() comp[k] = nop end)
                            end
                        end
                        _G.__ZD_KilledComponents[comp] = true
                    end
                end
            end
            return killed
        end
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if slua and slua.isValid and slua.isValid(pc) then Kill(pc) end
            local GD = require("GameLua.GameCore.Data.GameplayData")
            local pl = GD.GetPlayerCharacter()
            if slua and slua.isValid and slua.isValid(pl) then Kill(pl) end
        end)
        if not _G.__ZD_AggressiveLoopStarted then
            _G.__ZD_AggressiveLoopStarted = true
            pcall(function()
                local ticker = require("common.time_ticker")
                if ticker and ticker.AddTimerLoop then
                    ticker.AddTimerLoop(0, function()
                        pcall(function()
                            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                            if slua and slua.isValid and slua.isValid(pc) then Kill(pc) end
                            local GD = require("GameLua.GameCore.Data.GameplayData")
                            local pl = GD.GetPlayerCharacter()
                            if slua and slua.isValid and slua.isValid(pl) then Kill(pl) end
                        end)
                    end, -1, 5.0)
                end
            end)
        end
    end)
end

_G.StartBypass_VIP_v3 = function()
    pcall(function()
        print("[ULTIMATE BYPASS] Starting initialization...")
        InitializeSLUABypass()
        InitializeMD5Bypass()
        InitializeSkinBypass()
        InitializeLogBlocker()
        InitializeScannerBlocker()
        InitializeReplayTelemetryBlocker()
        InitializeReportFlowBlocker()
        InitializePlayerSecurityBypass()
        InitializeClientFlowBypass()
        InitializeSwiftHawkBypass()
        InitializeCoronaLabBypass()
        InitializeModifierExceptionBypass()
        InitializeSimulateCharacterLocationBypass()
        InitializeShootVerificationBypass()
        InitializeNetworkPacketBlock()
        InitializeHiggsBosonBypass()
        InitializeAntiCheatHooks()
        InitializeAntiReport()
        InitializeGameplayBypass()
        InitializeKillAllSubsystems()
        InitializeOperationalStatsBypass()
        InitializeFinalProtection()
        InitializeAggressiveComponentKiller()
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end

-- ============================================================
-- END OF TESTED BYPASS LAYERS
-- ============================================================

-- ============================================================
-- ALWAYS-ON WALLHACK (WH) — like other features
-- ============================================================
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local LinearColor = import("LinearColor")

local CONFIG = {
    TICK_INTERVAL = 0.3,
    MAX_PAWNS_PER_TICK = 20,
    RESET_EVERY = 6,
}

local COLORS = {
    VISIBLE = LinearColor(255, 220, 0, 255),
    OCCLUDED = LinearColor(255, 0, 150, 255),
}

local CONSOLE_READY = false
local PROCESSED_PAWNS = {}
local TICK_COUNT = 0
local WH_TIMER = nil
local AVATAR_SLOTS = {0, 1, 2, 3, 4, 5, 6, 7}

local function SetupConsole()
    if CONSOLE_READY then return end
    pcall(function()
        local KismetSystemLibrary = import("KismetSystemLibrary")
        local world = slua.getWorld()
        if not KismetSystemLibrary or not world then return end

        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
        KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")

        CONSOLE_READY = true
        print("[Wallhack] Console ready")
    end)
end

local function ApplyWallhackToMesh(mesh)
    if not mesh or not slua.isValid(mesh) then return end

    pcall(function()
        local visColor = COLORS.VISIBLE
        local occColor = COLORS.OCCLUDED

        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)

        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)

        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visColor)
        mesh:SetIdeaOutlineOcclusionColor(occColor)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)

        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function IsPawnAlive(pawn)
    if not slua.isValid(pawn) then return false end
    if pawn.Health and pawn.Health > 0 then return true end
    return false
end

local function WallhackTick()
    pcall(function()
        local localPawn = GameplayData.GetPlayerCharacter()
        if not slua.isValid(localPawn) then return end

        SetupConsole()
        if not COLORS then return end

        TICK_COUNT = TICK_COUNT + 1
        if TICK_COUNT % CONFIG.RESET_EVERY == 0 then
            PROCESSED_PAWNS = {}
        end

        local myTeamId = localPawn.TeamID or 0

        local allPawns = Game:GetAllPlayerPawns() or {}
        local processedCount = 0

        for _, pawn in pairs(allPawns) do
            if processedCount >= CONFIG.MAX_PAWNS_PER_TICK then break end
            if not slua.isValid(pawn) or pawn == localPawn then goto continue end
            if pawn.PlayerKey and PROCESSED_PAWNS[pawn.PlayerKey] then goto continue end

            if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                pcall(function()
                    if slua.isValid(pawn.Mesh) then
                        ApplyWallhackToMesh(pawn.Mesh)
                    end

                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if slua.isValid(mesh) then
                                ApplyWallhackToMesh(mesh)
                            end
                        end
                    end

                    pcall(function()
                        local SkeletalMeshComponent = import("SkeletalMeshComponent")
                        if SkeletalMeshComponent then
                            local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if slua.isValid(comp) and comp ~= pawn.Mesh then
                                        ApplyWallhackToMesh(comp)
                                    end
                                end
                            end
                        end
                    end)

                    pcall(function()
                        local StaticMeshComponent = import("StaticMeshComponent")
                        if StaticMeshComponent then
                            local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if slua.isValid(comp) then
                                        ApplyWallhackToMesh(comp)
                                    end
                                end
                            end
                        end
                    end)

                    local weapon = pawn:GetCurrentWeapon()
                    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                        ApplyWallhackToMesh(weapon.Mesh)
                    end
                end)

                if pawn.PlayerKey then PROCESSED_PAWNS[pawn.PlayerKey] = true end
                processedCount = processedCount + 1
            end

            ::continue::
        end
    end)
end

local function StartWallhack()
    SetupConsole()
    if not COLORS then
        print("[Wallhack] Colors not initialized")
        return false
    end

    if WH_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end
        end)
        WH_TIMER = nil
    end

    if _G.Game and _G.Game.AddGameTimer then
        WH_TIMER = _G.Game:AddGameTimer(CONFIG.TICK_INTERVAL, true, WallhackTick)
        print("[Wallhack] Active (Game timer)")
        return true
    end

    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) and pc.AddGameTimer then
        WH_TIMER = pc:AddGameTimer(CONFIG.TICK_INTERVAL, true, WallhackTick)
        print("[Wallhack] Active (PC timer)")
        return true
    end

    print("[Wallhack] Could not start timer")
    return false
end

function _G.StartYellowWallhack()
    if WH_TIMER then
        print("[Wallhack] Already running")
        return
    end
    StartWallhack()
end

function _G.StopYellowWallhack()
    if WH_TIMER then
        pcall(function()
            if _G.Game then _G.Game:RemoveGameTimer(WH_TIMER) end
        end)
        WH_TIMER = nil
    end
    PROCESSED_PAWNS = {}
    CONSOLE_READY = false
    print("[Wallhack] Stopped")
end

pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(2.0, function()
            StartWallhack()
        end)
    else
        StartWallhack()
    end
end)
-- ============================================================
-- END ALWAYS-ON WALLHACK
-- ============================================================

_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData_3.GetPlayerCharacter()
    if not slua.isValid(player) then return result end

    local allCharacters = {}
    if GameplayData_3.GetAllPlayerCharacters then
        allCharacters = GameplayData_3.GetAllPlayerCharacters()
    elseif GameplayData_3.GameCharacters then
        for _, char in pairs(GameplayData_3.GameCharacters) do table.insert(allCharacters, char) end
    end

    local myTeam = player:GetTeamID()

    for _, actor in pairs(allCharacters) do
        if slua.isValid(actor) and actor ~= player and actor.GetTeamID and actor:IsAlive() then
            if actor:GetTeamID() ~= myTeam then
                local dist = player:GetDistanceTo(actor)
                if dist <= radius then
                    table.insert(result, actor)
                end
            end
        end
    end
    return result
end

_G.AimTouch = function()
    pcall(function()
        local player = GameplayData_3.GetPlayerCharacter()
        if not slua.isValid(player) then return end

        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then return end

        local isFiring = player.bIsWeaponFiring
        local isADS = player.bIsGunADS

        local weapon = nil
        if player.WeaponManagerComponent then
            weapon = player.WeaponManagerComponent.CurrentWeaponReplicated
        end
        if not weapon and type(player.GetCurrentShootWeapon) == "function" then
            weapon = player:GetCurrentShootWeapon()
        end

        local isShotgun = false
        if slua.isValid(weapon) then
            local wID = type(weapon.GetWeaponID) == "function" and weapon:GetWeaponID() or 0
            local wName = type(weapon.GetWeaponName) == "function" and weapon:GetWeaponName() or ""
            if (wID >= 1030000 and wID < 1040000) or wName:find("S686") or wName:find("S1897") or wName:find("S12") or wName:find("DBS") or wName:find("M1014") then
                isShotgun = true
            end
        end

        if isShotgun then
            if _G.LexusState.IsAutoFiring then
                pcall(function()
                    player.bIsWeaponFiring = false
                    if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                    if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                    local wepMgr = player.WeaponManagerComponent
                    if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
                end)
                _G.LexusState.IsAutoFiring = false
            end
            return
        end

        local hipCond = 1
        local hipPrio = 3
        local hipBone = 1
        local hipSpeed = 55
        local hipFOV = 15
        local hipDist = 60
        local hipVis = true
        local hipIgKnock = true
        local hipIgBot = true

        local scopeCond = 1
        local scopePrio = 1
        local scopeBone = 5
        local scopeSpeed = 39
        local scopeFOV = 15
        local scopeDist = 130
        local scopeVis = true
        local scopeIgKnock = true
        local scopeIgBot = true
        local scopePred = 0
        local scopeRecoil = 0

        local cond, prio, bone, speed, fov, maxDist, visCheck, igKnock, igBot, pred, recoilComp
        if isADS then
            cond = scopeCond
            prio = scopePrio
            bone = scopeBone
            speed = scopeSpeed
            fov = scopeFOV
            maxDist = scopeDist * 100
            visCheck = scopeVis
            igKnock = scopeIgKnock
            igBot = scopeIgBot
            pred = scopePred
            recoilComp = scopeRecoil
        else
            cond = hipCond
            prio = hipPrio
            bone = hipBone
            speed = hipSpeed
            fov = hipFOV
            maxDist = hipDist * 100
            visCheck = hipVis
            igKnock = hipIgKnock
            igBot = hipIgBot
            pred = 0
            recoilComp = 0
        end

        if cond == 1 and not isFiring then return end

        local enemies = _G.GetEnemyTargetsFromActors(maxDist)
        if not enemies or #enemies == 0 then return end

        local FVector2D = import("Vector2D")
        local UGameplayStatics = import("GameplayStatics")
        local KismetMathLibrary = import("KismetMathLibrary")

        local camManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        if not slua.isValid(camManager) then return end

        local camLoc = camManager:GetCameraLocation()
        if not camLoc then return end

        local ui_util = require("client.common.ui_util")
        if not ui_util then return end

        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize then return end

        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local FOV_RADIUS = (fov / 100.0) * (viewportSize.X / 2.0)

        local selBoneName = "head"
        if bone == 1 then selBoneName = "head"
        elseif bone == 2 then selBoneName = "spine_03"
        elseif bone == 3 then selBoneName = "spine_01"
        elseif bone == 4 then selBoneName = "pelvis" end

        local bestTarget = nil
        local bestScore = 99999999

        for _, target in ipairs(enemies) do
            if not slua.isValid(target) then goto continue end

            if igKnock and target.HealthStatus == 1 then goto continue end

            if igBot then
                local tIsBot = false
                if target.bIsAI == true or target.IsAI == true then tIsBot = true end
                local pState = target.PlayerState
                if slua.isValid(pState) and (pState.bIsABot or pState.bIsBot) then tIsBot = true end
                if tIsBot then goto continue end
            end

            if visCheck then
                local curTime = os.clock()
                local tId = type(target.GetUniqueID) == "function" and target:GetUniqueID() or tostring(target)
                _G.AimTouchVisCache = _G.AimTouchVisCache or {}
                if not _G.AimTouchVisCache[tId] or (curTime - _G.AimTouchVisCache[tId].time) > 0.2 then
                    local isHidden = true
                    pcall(function() if pc:LineOfSightTo(target) then isHidden = false end end)
                    _G.AimTouchVisCache[tId] = { hidden = isHidden, time = curTime }
                end
                if _G.AimTouchVisCache[tId].hidden then goto continue end
            end

            local tPos = target:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.GetSocketLocation) == "function" then
                    tPos = target:GetSocketLocation(selBoneName)
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then
                if type(target.K2_GetActorLocation) == "function" then
                    tPos = target:K2_GetActorLocation()
                    if tPos then
                        if bone == 1 then tPos.Z = tPos.Z + 70
                        elseif bone == 2 then tPos.Z = tPos.Z + 40
                        elseif bone == 3 then tPos.Z = tPos.Z + 20 end
                    end
                end
            end
            if not tPos or (tPos.X == 0 and tPos.Y == 0 and tPos.Z == 0) then goto continue end

            local screen = FVector2D()
            local success = pc:ProjectWorldLocationToScreen(tPos, screen, false)
            if not success or screen.X <= 0 or screen.Y <= 0 then goto continue end

            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local distScreen = math.sqrt(dx*dx + dy*dy)

            if distScreen > FOV_RADIUS then goto continue end

            local currentScore = distScreen
            if prio == 2 then currentScore = player:GetDistanceTo(target)
            elseif prio == 3 then currentScore = target.Health or 100
            elseif prio == 4 then
                local hp = target.Health or 100
                local maxhp = target.HealthMax or 100
                if maxhp <= 0 then maxhp = 100 end
                currentScore = hp / maxhp
            end

            if currentScore < bestScore then
                bestScore = currentScore
                bestTarget = target
            end

            ::continue::
        end

        if not slua.isValid(bestTarget) then return end

        local finalBonePos = bestTarget:GetBonePos(selBoneName, {X=0, Y=0, Z=0})
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.GetSocketLocation) == "function" then
                finalBonePos = bestTarget:GetSocketLocation(selBoneName)
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            if type(bestTarget.K2_GetActorLocation) == "function" then
                finalBonePos = bestTarget:K2_GetActorLocation()
                if finalBonePos then
                    if bone == 1 then finalBonePos.Z = finalBonePos.Z + 70
                    elseif bone == 2 then finalBonePos.Z = finalBonePos.Z + 40
                    elseif bone == 3 then finalBonePos.Z = finalBonePos.Z + 20 end
                end
            end
        end
        if not finalBonePos or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then return end

        if pred > 0 then
            pcall(function()
                local tVelocity = nil
                if type(bestTarget.GetVelocity) == "function" then
                    tVelocity = bestTarget:GetVelocity()
                end
                if tVelocity and (tVelocity.X ~= 0 or tVelocity.Y ~= 0) then
                    local distToEnemy = player:GetDistanceTo(bestTarget) / 100.0
                    local ToF = (distToEnemy / 800.0) * (pred / 50.0)
                    finalBonePos.X = finalBonePos.X + (tVelocity.X * ToF)
                    finalBonePos.Y = finalBonePos.Y + (tVelocity.Y * ToF)
                end
            end)
        end

        local rot = KismetMathLibrary.FindLookAtRotation(camLoc, finalBonePos)
        if not rot then return end

        local currentRot = pc:GetControlRotation()
        if not currentRot then return end

        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch

        if isADS then
            local camRot = nil
            if type(camManager.GetCameraRotation) == "function" then
                camRot = camManager:GetCameraRotation()
            end
            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end

        local smoothFactor = (speed / 100.0) * 0.3
        if smoothFactor < 0.01 then smoothFactor = 0.01 end

        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)

        if isADS and recoilComp > 0 and isFiring then
            local pullDown = (recoilComp / 50.0) * 1.5
            finalPitch = finalPitch - pullDown
        end

        local finalRot = { Pitch = finalPitch, Yaw = finalYaw, Roll = 0 }
        pc:SetControlRotation(finalRot, "AimTouch")

        if _G.LexusState.IsAutoFiring then
            pcall(function()
                player.bIsWeaponFiring = false
                if type(player.SetIsWeaponFiring) == "function" then player:SetIsWeaponFiring(false) end
                if slua.isValid(pc) and type(pc.SetIsWeaponFiring) == "function" then pc:SetIsWeaponFiring(false) end
                local wepMgr = player.WeaponManagerComponent
                if slua.isValid(wepMgr) then wepMgr.bIsWeaponFiring = false end
            end)
            _G.LexusState.IsAutoFiring = false
        end
    end)
end

function BRPlayerCharacterBase:ctor()
    self.bHasShownDevNotice = false
    self.bHasShownExpiredNotice = false
    self.AK_NativeESP_Ready = false
    self.ZoneTextTimer = nil
end

function BRPlayerCharacterBase:_PostConstruct()
    BRPlayerCharacterBase.__super._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
    print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
    self:StartAdvancedSystems()
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
    BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)

    self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
    if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
        local CheckFallingDistanceComponent_1 = import("CheckFallingDistanceComponent")
        if slua.isValid(CheckFallingDistanceComponent_1) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_1)) then
            print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
            Game:AddComponent(CheckFallingDistanceComponent_1, self, "CheckFallingDistanceComponent")
        end
    end
    if slua.isValid(self.STCharacterMovement) then
        self.STCharacterMovement.bPositiveBlowUp = true
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy then
        self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
        self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
        self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
            AttrName = { "bCanSelfRescue" }
        }, self.CharacterAttrChangeEvent, self)
    end
    if Client then
        printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
        GameplayData_3.AddCharacter(self.Object)
        self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
        self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
    else
        self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
            [1] = "FinishedState"
        }, self.HandleFinishedState, self)
    end

    EventSystem:postEvent(EVENTTYPE_SINGLETRAINING, EVENTID_CHARACTER_BEGINPLAY, self.Object)
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
    BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
    if Client and GameplayData_3.RemoveCharacter ~= nil then
        GameplayData_3.RemoveCharacter(self.Object)
    end
    if self.ZoneTextTimer then
        self:RemoveGameTimer(self.ZoneTextTimer)
        self.ZoneTextTimer = nil
    end
end

function BRPlayerCharacterBase:StartAdvancedSystems()
    if not Client then return end

    if not _G.BypassInitialized then
        _G.BypassInitialized = true
    end


    self:AddGameTimer(2.0, true, function()
        if not slua.isValid(self.Object) then return end
        if not self.Object.IsAlive or not self.Object:IsAlive() then return end

        local var_controller = GameplayData_3.GetPlayerControllerSafety and GameplayData_3.GetPlayerControllerSafety() or GameplayData_3.GetPlayerController()
        if slua.isValid(var_controller) and var_controller.Role == ENetRole.ROLE_AutonomousProxy then
            pcall(function()
                var_controller:DisplayGameTip("Create Hack @Zone_Mod")
            end)
        end
    end)

    _G.MagicUpdateVersion = _G.MagicUpdateVersion or 1
    _G.ZONEMODTickCount = _G.ZONEMODTickCount or 0
    _G.AK_OrigHitboxes = _G.AK_OrigHitboxes or {}
    _G.AK_Active_Marks_Cache = _G.AK_Active_Marks_Cache or {}
    _G.LexusState = _G.LexusState or { IsAutoFiring = false }

    self:AddGameTimer(0.1, true, function()
        if not slua.isValid(self.Object) then return end
        if not self.Object.IsAlive or not self.Object:IsAlive() then return end

        local GameplayData_2 = GameplayData_3.GetPlayerCharacter()
        if not slua.isValid(GameplayData_2) then return end

        if var_85 > var_151 then
            if self.Object == GameplayData_2 and not self.bHasShownExpiredNotice then
                if self.Object.IsAlive and self.Object:IsAlive() then
                    self.bHasShownExpiredNotice = true
                    pcall(function()
                        local logic_common_msg_box_1 = package.loaded["client.slua.logic.common.logic_common_msg_box"] or require("client.slua.logic.common.logic_common_msg_box")
                        if logic_common_msg_box_1 and logic_common_msg_box_1.Show then
                            logic_common_msg_box_1.Show(4, "NOTICE FROM ADMIN @ZONE_MOD", "YOUR MOD VERSION HAS EXPIRED\nPLEASE CONTACT TELEGRAM PERMIUM ZONE MOD TO PURCHASE", function()
                                local KismetSystemLibrary_2 = import("KismetSystemLibrary")
                                if KismetSystemLibrary_2 then KismetSystemLibrary_2.LaunchURL("https://t.me/Zone_Mod") end
                            end, function() end, "CONTACT ADMIN", "CANCEL")
                        end
                    end)
                end
            end
            return
        end

        if self.Object == GameplayData_2 and not self.bHasShownDevNotice then
            if self.Object.IsAlive and self.Object:IsAlive() then
                self.bHasShownDevNotice = true
            end
        end

        pcall(function()
            local PlayerChar = GameplayData_3.GetPlayerCharacter()
            if not slua.isValid(PlayerChar) then return end

            local CurrentWeapon = PlayerChar.GetCurrentWeapon and PlayerChar:GetCurrentWeapon()
            if not slua.isValid(CurrentWeapon) then return end

            local ShootEntity = CurrentWeapon.ShootWeaponEntity_GEN_VARIABLE or CurrentWeapon.ShootWeaponEntity
            if not slua.isValid(ShootEntity) then return end

            ShootEntity.GameDeviationFactor = 1.5
            ShootEntity.AccessoriesHRecoilFactor = 0.80
            ShootEntity.AccessoriesVRecoilFactor = 0.50
            ShootEntity.RecoilKickADS = 0.20
        end)

        _G.AimTouch()

        pcall(function()
            local percent = 27
            local fov = 90 + math.floor(percent / 10) * 10
            if fov < 90 then fov = 90 end
            if fov > 150 then fov = 150 end
            local cam = self.Object.ThirdPersonCameraComponent
            if slua.isValid(cam) then
                local isAiming = self.Object.bIsWeaponAiming or false
                if not isAiming then
                    cam.FieldOfView = fov
                end
            end
        end)

        if self.Role == ENetRole.ROLE_AutonomousProxy then
            _G.ZONEMODTickCount = _G.ZONEMODTickCount + 1

            if _G.ZONEMODTickCount % 50 == 0 then
                _G.MagicUpdateVersion = _G.MagicUpdateVersion + 1
            end

            if not self.AK_NativeESP_Ready then
                pcall(function()
                    local GamePlayTools_1 = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
                    local var_33 = GamePlayTools_1.GetCurrentConfig("ScreenMarkConfig")
                    if var_33 then
                        if var_33[1006] then
                            var_33[1006].bBindBlocked = true
                            var_33[1006].bBindOutScreen = true
                            var_33[1006].MaxWidgetNum = 99
                            var_33[1006].MaxShowDistance = 6000000
                            var_33[1006].bScaleByDistance = false
                            var_33[1006].BindSocketName = "root"
                            var_33[1006].bUseLuaWorldSocketName = true
                            var_33[1006].WorldPositionOffset = FVector(0, 0, -30)
                        end
                        if not var_33[9999] then
                            var_33[9999] = {
                                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                                MaxWidgetNum = 99,
                                MaxShowDistance = 6000000,
                                bBindOutScreen = true,
                                bBindBlocked = true,
                                bIsBindingActor = true,
                                BindSocketName = "head",
                                bUseLuaWorldSocketName = true,
                                WorldPositionOffset = FVector(0, 0, 50),
                                bNeedPreLoad = true,
                                Priority = 2
                            }
                            local InGameMarkTools_1 = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
                            if InGameMarkTools_1 and InGameMarkTools_1.ScreenMarkManager and InGameMarkTools_1.ScreenMarkManager.OnInitMarkGroupData then
                                pcall(function() InGameMarkTools_1.ScreenMarkManager:OnInitMarkGroupData(9999) end)
                            end
                        end
                    end
                    for k, var_76 in pairs(package.loaded) do
                        if type(k) == "string" and string.find(k, "ScreenMarkConfig") then
                            if type(var_76) == "table" then
                                if var_76[1006] then
                                    var_76[1006].bBindBlocked = true
                                    var_76[1006].bBindOutScreen = true
                                    var_76[1006].MaxWidgetNum = 99
                                    var_76[1006].MaxShowDistance = 6000000
                                    var_76[1006].bScaleByDistance = false
                                    var_76[1006].BindSocketName = "root"
                                    var_76[1006].bUseLuaWorldSocketName = true
                                    var_76[1006].WorldPositionOffset = FVector(0, 0, -30)
                                end
                                var_76[9999] = {
                                    UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                                    MaxWidgetNum = 99,
                                    MaxShowDistance = 6000000,
                                    bBindOutScreen = true,
                                    bBindBlocked = true,
                                    bIsBindingActor = true,
                                    BindSocketName = "head",
                                    bUseLuaWorldSocketName = true,
                                    WorldPositionOffset = FVector(0, 0, 50),
                                    bNeedPreLoad = true,
                                    Priority = 2
                                }
                            end
                        end
                    end

                    local SubsystemMgr_1 = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
                    local var_236 = SubsystemMgr_1:Get("ClientHPBarSubSystem")
                    if var_236 then
                        if var_236.SetPauseCheck then var_236:SetPauseCheck(true) end
                        if var_236.FocusActorCheckParam then
                            var_236.FocusActorCheckParam.CheckBlock = false
                            var_236.FocusActorCheckParam.CheckDistance = 1000000
                        end
                    end
                    if manager_1 and manager_1.GetUI then
                        local var_26 = manager_1.GetUI(manager_1.UI_Config_InGame.EnemyHpWidgetsMain)
                        if slua.isValid(var_26) then
                            if var_26.SetCheckBlock then var_26:SetCheckBlock(false) end
                            if var_26.UIRoot and var_26.UIRoot.CanvasPanel_HPBarWidgets then
                                if var_26.UIRoot.CanvasPanel_HPBarWidgets.SetRenderScale then
                                    var_26.UIRoot.CanvasPanel_HPBarWidgets:SetRenderScale(FVector2D(1.5, 1.5))
                                end
                            end
                        end
                    end
                end)
                self.AK_NativeESP_Ready = true
            end

            local var_95 = {}
            if GameplayData_3.GetAllPlayerCharacters then
                var_95 = GameplayData_3.GetAllPlayerCharacters()
            elseif GameplayData_3.GameCharacters then
                for _, char in pairs(GameplayData_3.GameCharacters) do table.insert(var_95, char) end
            end

            for cacheKey, cacheData in pairs(_G.AK_Active_Marks_Cache) do
                local var_77 = false
                if not slua.isValid(cacheData.actor) then
                    var_77 = true
                else
                    pcall(function()
                        local var_46 = cacheData.actor
                        if var_46.bHidden or (var_46.Mesh and var_46.Mesh.bHidden) then var_77 = true end
                        if type(var_46.IsDead) == "function" and var_46:IsDead() then var_77 = true
                        elseif var_46.bIsDead == true or var_46.bIsDeadFlag == true then var_77 = true end
                    end)
                end

                if var_77 then
                    pcall(function()
                        if InGameMarkTools_1 and InGameMarkTools_1.ClientRemoveMapMark then
                            InGameMarkTools_1.ClientRemoveMapMark(cacheData.hpMark)
                            if cacheData.distMark then InGameMarkTools_1.ClientRemoveMapMark(cacheData.distMark) end
                        end
                    end)
                    _G.AK_Active_Marks_Cache[cacheKey] = nil
                end
            end

            for _, enemy in pairs(var_95) do
                if slua.isValid(enemy) and enemy ~= GameplayData_2 and enemy.TeamID ~= GameplayData_2.TeamID then
                    local var_159 = false
                    local var_237 = false

                    pcall(function()
                        if type(enemy.IsNearDeath) == "function" then var_237 = enemy:IsNearDeath()
                        elseif enemy.bIsNearDeath ~= nil then var_237 = enemy.bIsNearDeath end

                        if type(enemy.IsDead) == "function" then var_159 = enemy:IsDead()
                        elseif enemy.bIsDead ~= nil then var_159 = enemy.bIsDead
                        elseif enemy.bIsDeadFlag ~= nil then var_159 = enemy.bIsDeadFlag end

                        if enemy.bHidden or (enemy.Mesh and enemy.Mesh.bHidden) then var_159 = true end

                        if not var_237 then
                            local var_169 = 100
                            if type(enemy.GetHealth) == "function" then var_169 = enemy:GetHealth()
                            elseif enemy.Health ~= nil then var_169 = enemy.Health end
                            if var_169 <= 0 then var_159 = true end
                        end
                    end)

                    if not var_159 then
                        if enemy.bHasAKNativeHPBar and enemy.AK_LastKnockState ~= nil and enemy.AK_LastKnockState ~= var_237 then
                            pcall(function()
                                if InGameMarkTools_1 and InGameMarkTools_1.ClientRemoveMapMark then
                                    InGameMarkTools_1.ClientRemoveMapMark(enemy.NativeHPBarMark)
                                    InGameMarkTools_1.ClientRemoveMapMark(enemy.NativeDistMark)
                                end
                            end)
                            enemy.bHasAKNativeHPBar = false
                            _G.AK_Active_Marks_Cache[tostring(enemy)] = nil
                        end
                        enemy.AK_LastKnockState = var_237

                        if not enemy.bHasAKNativeHPBar then
                            pcall(function()
                                if InGameMarkTools_1 and InGameMarkTools_1.ClientAddMapMark then
                                    enemy.NativeHPBarMark = InGameMarkTools_1.ClientAddMapMark(1006, FVector(0,0,0), 0, "", 4, enemy)
                                    enemy.NativeDistMark = InGameMarkTools_1.ClientAddMapMark(9999, FVector(0,0,0), 0, "", 4, enemy)
                                    enemy.bHasAKNativeHPBar = true
                                    _G.AK_Active_Marks_Cache[tostring(enemy)] = {
                                        actor = enemy,
                                        hpMark = enemy.NativeHPBarMark,
                                        distMark = enemy.NativeDistMark
                                    }
                                end
                            end)
                        end

                        local var_142 = enemy.Mesh or (enemy.getAvatarComponent2 and enemy:getAvatarComponent2())
                        if slua.isValid(var_142) then
                            if not var_142.LastHitboxUpdateVersion or var_142.LastHitboxUpdateVersion ~= _G.MagicUpdateVersion then
                                var_142.bIsAKHitboxModded = false
                            end
                            if not var_142.bIsAKHitboxModded then
                                pcall(function()
                                    local var_2 = var_142.PhysicsAssetOverride
                                    if not slua.isValid(var_2) and var_142.SkeletalMesh then var_2 = var_142.SkeletalMesh.PhysicsAsset end

                                    if slua.isValid(var_2) and var_2.SkeletalBodySetups then
                                        if not _G.AK_OrigHitboxes[var_7] then
                                            _G.AK_OrigHitboxes[var_7] = {}
                                        end
                                        local var_53 = _G.AK_OrigHitboxes[var_7]

                                        local magicHeadEnabled = true
                                        local headScale = 1.3
                                        local var_146 = {
                                            ["head"] = headScale,
                                        }

                                        local var_158 = var_2.SkeletalBodySetups
                                        local numBodySetups = 50
                                        pcall(function() if type(var_158.Num) == "function" then numBodySetups = var_158:Num() end end)
                                        for i = 1, numBodySetups do
                                            local var_49 = nil
                                            pcall(function() var_49 = type(var_158.Get) == "function" and var_158:Get(i-1) or var_158[i] end)

                                            if slua.isValid(var_49) then
                                                local var_233 = string.lower(tostring(var_49.BoneName))
                                                local var_16 = nil
                                                for k, _ in pairs(var_146) do
                                                    if string.find(var_233, k) then var_16 = k break end
                                                end

                                                if var_16 then
                                                    local var_24 = var_146[var_16]
                                                    local var_114 = var_49.AggGeom

                                                    local var_87 = var_114 and var_114.BoxElems or var_49.BoxElems
                                                    local var_215 = var_114 and var_114.SphereElems or var_49.SphereElems
                                                    local var_124 = var_114 and var_114.SphylElems or var_49.SphylElems

                                                    local var_12 = nil
                                                    if var_87 then pcall(function() var_12 = type(var_87.Get) == "function" and var_87:Get(0) or var_87[1] end) end
                                                    local var_82 = nil
                                                    if var_215 then pcall(function() var_82 = type(var_215.Get) == "function" and var_215:Get(0) or var_215[1] end) end
                                                    local var_138 = nil
                                                    if var_124 then pcall(function() var_138 = type(var_124.Get) == "function" and var_124:Get(0) or var_124[1] end) end

                                                    if not var_53[var_16] then
                                                        var_53[var_16] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                        if var_12 then var_53[var_16].Box = { X = var_12.X, Y = var_12.Y, Z = var_12.Z } end
                                                        if var_82 then var_53[var_16].Sphere = { Radius = var_82.Radius } end
                                                        if var_138 then var_53[var_16].Sphyl = { Radius = var_138.Radius, Length = var_138.Length } end
                                                    end

                                                    local var_136 = var_53[var_16]

                                                    if var_136.Box and var_12 then
                                                        var_12.X = var_136.Box.X * var_24
                                                        var_12.Y = var_136.Box.Y * var_24
                                                        var_12.Z = var_136.Box.Z * var_24
                                                        pcall(function() if type(var_87.Set) == "function" then var_87:Set(0, var_12) else var_87[1] = var_12 end end)
                                                        if var_114 then var_114.BoxElems = var_87; var_49.AggGeom = var_114 else var_49.BoxElems = var_87 end
                                                    end

                                                    if var_136.Sphere and var_82 then
                                                        var_82.Radius = var_136.Sphere.Radius * var_24
                                                        pcall(function() if type(var_215.Set) == "function" then var_215:Set(0, var_82) else var_215[1] = var_82 end end)
                                                        if var_114 then var_114.SphereElems = var_215; var_49.AggGeom = var_114 else var_49.SphereElems = var_215 end
                                                    end

                                                    if var_136.Sphyl and var_138 then
                                                        var_138.Radius = var_136.Sphyl.Radius * var_24
                                                        var_138.Length = var_136.Sphyl.Length * var_24
                                                        pcall(function() if type(var_124.Set) == "function" then var_124:Set(0, var_138) else var_124[1] = var_138 end end)
                                                        if var_114 then var_114.SphylElems = var_124; var_49.AggGeom = var_114 else var_49.SphylElems = var_124 end
                                                    end

                                                end
                                            end
                                        end
                                        pcall(function()
                                            if var_142.SetPhysicsAsset then var_142:SetPhysicsAsset(var_2) end
                                            var_142.PhysicsAssetOverride = var_2
                                            if var_142.RecreatePhysicsState then
                                                pcall(function() var_142:RecreatePhysicsState() end)
                                            end
                                        end)

                                    end
                                end)
                                var_142.bIsAKHitboxModded = true
                                var_142.LastHitboxUpdateVersion = _G.MagicUpdateVersion

                            end
                        end
                    end
                end
            end
        end
    end)

    if self.ZoneTextTimer then
        self:RemoveGameTimer(self.ZoneTextTimer)
        self.ZoneTextTimer = nil
    end

    self.ZoneTextTimer = self:AddGameTimer(0.1, true, function()
        if not slua.isValid(self.Object) then return end
        if not self.Object.IsAlive or not self.Object:IsAlive() then return end

        local var_controller = GameplayData_3.GetPlayerControllerSafety and GameplayData_3.GetPlayerControllerSafety() or GameplayData_3.GetPlayerController()
        if not slua.isValid(var_controller) then return end
        if var_controller.Role ~= ENetRole.ROLE_AutonomousProxy then return end

        local HUD = var_controller:GetHUD()
        if not slua.isValid(HUD) then return end

        local color = { R = 16, G = 232, B = 232, A = 255, r = 16, g = 232, b = 232, a = 255 }
        local text = ""

        HUD:AddDebugText(text, self.Object, 0.11, 
            { X = 0, Y = 0, Z = 180 }, 
            { X = 0, Y = 0, Z = 180 }, 
            color, true, false, true, nil, 1.5, true)
    end)
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
    local EMovementMode_1 = import("EMovementMode")
    if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode_1.MOVE_Swimming and self:CheckBaseIsMoveable() then
        print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
        self.CharacterMovement:SetBase(nil, "", true)
    end
    if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode_1.MOVE_Walking and manager_1.UI_Config_InGame.ParachuteOpenUI then
        print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
        manager_1.CloseUI(manager_1.UI_Config_InGame.ParachuteOpenUI)
    end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(var_131)
    if not slua.isValid(var_131) then
        return
    end
    print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(var_131)))
    if self.Role == ENetRole.ROLE_SimulatedProxy then
        self:ClearAttachToVehicleTimer()
        self.nUpdatePlayerAttachToVehicleCount = 0
        self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, function()
            if slua.isValid(self.Object) and slua.isValid(var_131) then
                self:UpdatePlayerAttachToVehicle(var_131)
            end
        end)
        self.nFixMeshContainerTimer = self:AddGameTimer(3, true, function()
            if slua.isValid(self.Object) and slua.isValid(var_131) then
                self:FixMeshContainerOffsetIfNeeded(var_131)
            end
        end)
    end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
    if not slua.isValid(uLastVehicle) then
        return
    end
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
    if self.Role == ENetRole.ROLE_SimulatedProxy then
        self:ClearAttachToVehicleTimer()
        self.nUpdatePlayerAttachToVehicleCount = 0
    end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(var_131)
    if not slua.isValid(self.Object) or not slua.isValid(var_131) then return end
    if not (slua.isValid(self.CapsuleComponent) and slua.isValid(self.Mesh)) or not slua.isValid(self.MeshContainer) then return end
    if not slua.isValid(self:GetCurrentVehicle()) then return end
    if Game:IsDriver(self.Object) then return end
    if not self.nUpdatePlayerAttachToVehicleCount then self.nUpdatePlayerAttachToVehicleCount = 0 end

    local ESTEPoseState_1 = import("ESTEPoseState")
    local var_177 = self.PoseState == ESTEPoseState_1.Stand
    local var_4 = self.CapsuleComponent:GetRelativeTransform():GetLocation()
    local var_196 = self.Mesh:GetRelativeTransform():GetLocation()
    local var_38 = self.MeshContainer:GetRelativeTransform():GetLocation().Z
    local var_71 = self.CapsuleComponent:GetScaledCapsuleRadius()
    local var_75 = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
    local var_5 = -1 * self.StandHalfHeight
    local var_207 = self.StandRadius
    local var_154 = self.StandHalfHeight
    local var_25 = FVector(0, 0, 0)
    local var_102 = FVector(0, 0, self.StandHalfHeight)
    local var_35 = 1.0
    local var_200 = var_4:Equals(var_102, var_35)
    local var_149 = var_196:Equals(var_25, var_35)
    local var_42 = var_35 > math.abs(var_38 - var_5)
    local var_118 = var_35 > math.abs(var_71 - var_207)
    local var_28 = var_35 > math.abs(var_75 - var_154)
    local var_104 = var_177 and var_200 and var_149 and var_42 and var_118 and var_28

    if not var_104 then self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1 else self.nUpdatePlayerAttachToVehicleCount = 0 end

    if self.nUpdatePlayerAttachToVehicleCount >= 3 and not var_104 then
        local var_235 = GameplayData_3.GetPlayerController()
        if var_235.ReportCrashKitFeature and var_235.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
            local var_14 = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(var_131.VehicleShapeType), tostring(self.PlayerKey), var_177 and 1 or 0, var_200 and 1 or 0, var_149 and 1 or 0, var_42 and 1 or 0, var_118 and 1 or 0, var_28 and 1 or 0, var_4:ToString(), tostring(var_71), tostring(var_75), var_196:ToString(), tostring(var_38))
            var_235.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(var_14)
        end
        self.nUpdatePlayerAttachToVehicleCount = 0
    end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(var_131)
    if not slua.isValid(self.Object) or not slua.isValid(var_131) then return end
    if not slua.isValid(self.MeshContainer) then return end
    if not slua.isValid(self:GetCurrentVehicle()) then return end
    if Game:IsDriver(self.Object) then return end
    local var_35 = 1.0
    local var_5 = -1 * self.StandHalfHeight
    local var_38 = self.MeshContainer:GetRelativeTransform():GetLocation().Z
    if var_35 <= math.abs(var_38 - var_5) then
        self:SetMeshContainerOffsetZ(var_5)
    end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
    if self.nUpdatePlayerAttachToVehicleTimer then
        self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
        self.nUpdatePlayerAttachToVehicleTimer = nil
    end
    if self.nFixMeshContainerTimer then
        self:RemoveGameTimer(self.nFixMeshContainerTimer)
        self.nFixMeshContainerTimer = nil
    end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
    BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
    if self.Object ~= uPawn then return end
    if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
        local var_235 = self:GetPlayerControllerSafety()
        if slua.isValid(var_235) then
            var_235:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
    local EPawnState_1 = import("EPawnState")
    if PawnState == EPawnState_1.SwitchPP then
        local var_235 = self:GetPlayerControllerSafety()
        if slua.isValid(var_235) then
            var_235:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
        end
    end
end

function BRPlayerCharacterBase:HandleFinishedState()
    if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
        self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
    end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
    if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
        local EGameModeType_1 = import("EGameModeType")
        local MatchModeIdsConfig_1 = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
        local var_229 = CGameMode.GameModeType
        local var_181 = tonumber(CGameState.GameModeID)
        local var_197 = var_229 == EGameModeType_1.ETypicalGameMode or var_229 == EGameModeType_1.EFourInOneGameMode or var_229 == EGameModeType_1.EHeavyWeaponGameMode
        local var_144 = not MatchModeIdsConfig_1[var_181]
        return var_197 and var_144
    end
    return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
    BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
    local EParachuteState_1 = import("EParachuteState")
    if not Client then
        local var_209 = self:GetPlayerControllerSafety()
        if slua.isValid(var_209) and var_209.CheckParachuteOpenFeature then
            if NewParachuteState == EParachuteState_1.PS_Opening then
                if var_209.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
                    var_209.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
                end
            elseif NewParachuteState == EParachuteState_1.PS_None then
                if var_209.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
                    var_209.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
                end
                if var_209.CheckParachuteOpenFeature.ClearTimerAndState then
                    var_209.CheckParachuteOpenFeature:ClearTimerAndState()
                end
            end
        end
    end
end

function BRPlayerCharacterBase:OnLanded()
    if self.HandleOnLanded then self:HandleOnLanded(-1) end
    if not Client then
        local var_209 = self:GetPlayerControllerSafety()
        if slua.isValid(var_209) and var_209.CheckParachuteOpenFeature then
            if var_209.CheckParachuteOpenFeature.ClearTimerAndState then
                var_209.CheckParachuteOpenFeature:ClearTimerAndState()
            end
            if var_209.CheckParachuteOpenFeature.ResetCheckShowUI then
                var_209.CheckParachuteOpenFeature:ResetCheckShowUI()
            end
        end
    end
end

function BRPlayerCharacterBase:IsWarGameMode()
    local GameplayData_3 = require("GameLua.GameCore.Data.GameplayData")
    local var_164 = GameplayData_3:GetGameState()
    local STExtraGameStateBase_1 = import("STExtraGameStateBase")
    if slua.isValid(var_164) and Game:IsClassOf(var_164, STExtraGameStateBase_1) then
        local EGameModeType_1 = import("EGameModeType")
        return var_164.GameModeType == EGameModeType_1.EWarGameMode
    else
        return false
    end
end

function BRPlayerCharacterBase:BPOnRecycled()
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:BPOnRespawned()
    if Client then self:ResetMeshRelativeLocationAndRotation() end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData_3.RemoveCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
    if Client then
        self:ResetMeshRelativeLocationAndRotation()
        GameplayData_3.AddCharacter(self.Object)
    end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
    if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
        local var_188 = FRotator(0, -90, 0)
        local var_63 = FVector(0, 0, 0)
        if self.Mesh.K2_SetRelativeRotation then
            self.Mesh:K2_SetRelativeRotation(var_188, false, nil, false)
        end
        self:CacheInitialMeshOffset(var_63, var_188)
    end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
    local KismetSystemLibrary_1 = import("KismetSystemLibrary")
    local var_156 = KismetSystemLibrary_1.IsDedicatedServer(self)
    if not var_156 then return end
    local var_147 = self:GetPlayerControllerSafety()
    if not slua.isValid(var_147) then return end
    local var_40 = self.CharacterAvatarComp2_BP
    if not slua.isValid(var_40) then return end
    local CommerAvatarDataUtil_1 = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
    local var_22 = CommerAvatarDataUtil_1:ChangeVehicleSkinByClothes(var_147, var_40)
    local ESTExtraVehicleShapeType_1 = import("ESTExtraVehicleShapeType")
    if var_22 then
        local AvatarUtils_1 = import("AvatarUtils")
        if AvatarUtils_1.GetVehicleShapeBySkinID(var_22) == ESTExtraVehicleShapeType_1.VST_Horse then
            local var_190 = self:GetPlayerStateSafety()
            if slua.isValid(var_190) then
                var_190:AddGeneralCount(468, 1, false)
            end
        end
    end
end

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
    EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
    local var_235 = self:GetControllerSafety()
    if slua.isValid(var_235) then
        if not self:GetEnsure() then
            local EStateType_1 = import("EStateType")
            if var_235:GetCurrentStateType() ~= EStateType_1.State_ParachuteJump and var_235:GetCurrentStateType() ~= EStateType_1.State_ParachuteOpen then
                local ESTEPoseState_1 = import("ESTEPoseState")
                self:SwitchPoseState(ESTEPoseState_1.Stand, true, true, true, false)
                var_235:ReInitParachuteItem()
                var_235:ServerChangeStatePC(EStateType_1.State_ParachuteJump)
            end
        else
            EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
        end
    end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(var_65, uNewMovementBase, uOldMovementBase)
    if var_65 ~= self.Object then return end
    local var_70 = self:GetMedievalCraneFromBase(uNewMovementBase)
    if var_70 and var_70.AddCharacter then
        var_70:AddCharacter(self.Object)
    else
        var_70 = self:GetMedievalCraneFromBase(uOldMovementBase)
        if var_70 and var_70.RemoveCharacter then
            var_70:RemoveCharacter(self.Object)
        end
    end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
    if not slua.isValid(Base) or not Base.GetOwner then return end
    local var_6 = Base:GetOwner()
    if not slua.isValid(var_6) then return end
    if not var_6.AddCharacter then return end
    return var_6
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
    local var_56 = self:GetPlayerStateSafety()
    if not slua.isValid(var_56) then return false end
    if var_56.CanUseFlaregun == false and self:IsLocallyControlled() then
        local var_235 = self:GetPlayerControllerSafety()
        if slua.isValid(var_235) then
            var_235:DisplayGameTipWithMsgID(48532)
        end
    end
    return not var_56.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
    self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
    local var_66 = self.NearDeatchComponent
    if self:IsNearDeath() and slua.isValid(var_66) and self.bCanNearDeathGiveup == true then
        local var_56 = self:GetPlayerStateSafety()
        if slua.isValid(var_56) then var_56:AddGeneralCount(1613, 1, false) end
        var_66:TriggerGotoDieExplictly(self.Object)
    end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
    local STExtraBlueprintFunctionLibrary_1 = import("STExtraBlueprintFunctionLibrary")
    if STExtraBlueprintFunctionLibrary_1.IsDevelopment() then
        self:MulticastRPC_GmPlayAction(actionId)
    end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
    if not Client then return end
    local var_231 = self:GetPlayEmoteComponent()
    if not slua.isValid(var_231) then return end
    local log_filter_1 = require("common.log_filter")
    log_filter_1.SetLogTreeEnable(true)
    local var_238 = CDataTable.GetTableData("EmoteBPTable", actionId)
    if not var_238 then return end
    local var_3 = var_238.Path
    local var_18 = slua.loadObject(var_3)
    local var_168 = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
    local var_15 = var_18()
    var_231:OnLoadEmoteAssetBegin(var_15, actionId, var_168, "")
    local tb = FuncUtil.LuaArrayToTable(var_168)
    local asset_util_1 = require("common.asset_util")
    local var_64 = function() var_231:OnLoadEmoteAssetEnd(var_15, actionId, 0) end
    asset_util_1.GetAssetsArrayAsyncParallel(tb, var_64)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
    if slua.isValid(self.ParachuteComponent) then
        self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
    end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
    self.Super:OnPlayerEnterCarryBoxState()
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState() end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
    if self.CarryDeadBoxFeature then self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt) end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
    if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
        self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
    end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
    self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
    return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
    return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
    if self:HasState(EPawnState_1.SpecialSuit) then
        self:TriggerEntrySkillWithID(4301101, true)
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
    self.Super:SwitchCameraToParachuteOpening()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
    self.Super:SwitchCameraToParachuteFalling()
    if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
        self.ParachuteFormation:OverlayFormationCameraParams()
    end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
    self.Super:SwitchCameraToNormal()
    if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
        self.ParachuteFormation:OnLandingClearFormationCamera()
    end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
    if self:HasState(EPawnState_1.AttachToOther) then
        local var_92 = self:GetWeaponBySlot(Slot)
        if slua.isValid(var_92) then
            local var_145 = var_92:GetWeaponID()
            local var_225 = GamePlayTools_1.GetCurrentConfig("AttachToOtherConfig")
            if var_225 and var_225.CheckIsWeaponInBlackList and var_225.CheckIsWeaponInBlackList(var_145) then
                local var_235 = self:GetPlayerControllerSafety()
                if Client and slua.isValid(var_235) and var_235.Role == ENetRole.ROLE_AutonomousProxy then
                    var_235:DisplayGameTipWithMsgID(47306)
                end
                return false
            end
        end
    end
    return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ============================================================
-- BYPASS TRIGGER — uses TESTED bypass code (StartBypass_VIP_v3)
-- ============================================================
local function func_8()
    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
    end)

    local GameplayData_3 = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData_3 then return end

    pcall(function()
        local GameplayData_1 = GameplayData_3.GetPlayerCharacter and GameplayData_3.GetPlayerCharacter()
        if slua.isValid(GameplayData_1) then
            if BRPlayerCharacterBase.StartAdvancedSystems then
                GameplayData_1.StartAdvancedSystems = BRPlayerCharacterBase.StartAdvancedSystems
            end

            if GameplayData_1.bHasShownDevNotice == nil then
                GameplayData_1.bHasShownDevNotice = false
                GameplayData_1.bHasShownExpiredNotice = false
                GameplayData_1.bIsDeadFlag = false
                GameplayData_1.AK_NativeESP_Ready = false
            end

            if type(GameplayData_1.StartAdvancedSystems) == "function" then
                pcall(function()
                    GameplayData_1:StartAdvancedSystems()
                end)
            end
        end
    end)
end

pcall(function()
    require("common.time_ticker").AddTimerOnce(0.5, func_8)
end)

local class_1 = require("class")
local CharacterBase_1 = require("GameLua.GameCore.Framework.CharacterBase")
local var_59 = class_1(CharacterBase_1, nil, BRPlayerCharacterBase)

return require("combine_class").DeclareFeature(var_59, {
    { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
    { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
    { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
    { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
    { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
    { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
    { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
    { BuildSkateFeature = "GameLua.Mod.BaseMod.Gameplay.Feature.PlayerCharacterBuildVehicleFeature" },
    { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
    { ParachuteFormation = "GameLua.Mod.BaseMod.Gameplay.Feature.ParachuteFormationFeature" }
}, "BRPlayerCharacterBase")
