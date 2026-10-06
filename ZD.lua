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
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local ESpecialMovementType = import("ESpecialMovementType")
local ESpiderSwingMoveState = import("ESpiderSwingMoveState")
local ESurviveWeaponPropSlot = import("ESurviveWeaponPropSlot")
local EParachuteState = import("EParachuteState")
local EMovementMode = import("EMovementMode")
local EStateType = import("EStateType")
local ESTEPoseState = import("ESTEPoseState")
local EGameModeType = import("EGameModeType")
local STExtraGameStateBase = import("STExtraGameStateBase")
local UKismetSystemLibrary = import("KismetSystemLibrary")
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
    if self.Role == ENetRole.ROLE_AutonomousProxy then
      pcall(function()
        if _G.ZDSessionTelemetryStartMatch then
          _G.ZDSessionTelemetryStartMatch(self)
        end
      end)
    end
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfigDisable then
    local EDynamicSimpleQueryConfigDisableMask = import("EDynamicSimpleQueryConfigDisableMask")
    self.STCharacterMovement:SetDynamicSimpleQueryConfigDisable(EDynamicSimpleQueryConfigDisableMask.Bit0, true)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  if Client and self.Role == ENetRole.ROLE_AutonomousProxy then
    pcall(function()
      if _G.ZDSessionTelemetryExitMatch then
        _G.ZDSessionTelemetryExitMatch(true)
      end
    end)
  end
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local uGameState = GameplayData:GetGameState()
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  
  function loadLater()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
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
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  if self:HasState(EPawnState.WebSwing) and Slot ~= ESurviveWeaponPropSlot.SWPS_None and slua.isValid(self.STCharacterMovement) then
    local SpiderSwingObj = self.STCharacterMovement:GetSpecialMoveObjBySpecialMoveType(ESpecialMovementType.SPECIAL_MOVE_SpiderSwing)
    if slua.isValid(SpiderSwingObj) then
      local nCurState = SpiderSwingObj:GetCurMoveState()
      if nCurState == ESpiderSwingMoveState.Launching or nCurState == ESpiderSwingMoveState.Swinging then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck blocked by SpiderSwing state: " .. tostring(nCurState))
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end





local function Notify(msg) local s = "[زد] " .. tostring(msg)
pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end




local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}



local ACTIVE_CONFIG_DEFAULTS = {
    EspVip = false,
    EspVipPro = false,
    EspAdvancedRadar = false,
    Esp3ShowName = true,
    Esp3ShowHP = true,
    EspItem_Master = false,
    EspItem_Selected = {},
    AimTouchEnable = false,
    AimTouchFOV = 30,
    ModEmote = false,
    ModSkin = false,
    SkinDeadBox = false,
    SkinAttachment = false,
    SkinOpenLink = false,
    KillMessage = false,
    KillCountUI = false,
    UnlockFPS = false,
    IpadView = false,
    WallXuyenTuong = false,
    ColorBodyV2 = false,
    ColorBodyNew = false,
    WhiteBody = false,
    BlackSky = false,
    RemoveFog = false,
    RemoveGrass = false,
}

local ACTIVE_CONFIG_KEYS = {}
for key in pairs(ACTIVE_CONFIG_DEFAULTS) do
    ACTIVE_CONFIG_KEYS[key] = true
end

-- Keep existing values for current menu options, but physically drop all stale/hidden option keys.
do
    local previous = type(_G.LexusConfig) == "table" and _G.LexusConfig or {}
    local current = {}
    for key, defaultValue in pairs(ACTIVE_CONFIG_DEFAULTS) do
        if previous[key] ~= nil then
            current[key] = previous[key]
        else
            current[key] = defaultValue
        end
    end
    if type(previous.EspItem_Selected) == "table" then
        current.EspItem_Selected = previous.EspItem_Selected
    end
    _G.LexusConfig = current
end


_G.LexusState = _G.LexusState or { 
    LoopToken = 0, 
    NativeESPReady = false,
    GraphicsUnlocked = false, 
    MenuStep = 0, 
    LastCmdTime = 0,
    TrackedMarks = {},
    EnemyMarks = {},
    LastAimbotCheckTime = 0, 
    CustomTextData = nil,     
    PrevGraphicsState = {},
    RuntimeCleanupDone = false
}

_G.LexusState.KillLimit = _G.LexusState.KillLimit or {}
_G.LexusState.KillLimit.MatchKills = tonumber(_G.LexusState.KillLimit.MatchKills) or 0
_G.LexusState.KillLimit.Reached = _G.LexusState.KillLimit.Reached == true
_G.LexusState.KillLimit.CleanupDone = _G.LexusState.KillLimit.CleanupDone == true
_G.LexusState.KillLimit.Cleaning = false
_G.LexusState.KillLimit.PopupShown = _G.LexusState.KillLimit.PopupShown == true
_G.LexusState.KillLimit.SeenKillRecords = type(_G.LexusState.KillLimit.SeenKillRecords) == "table" and _G.LexusState.KillLimit.SeenKillRecords or {}
_G.LexusState.KillLimit.DisabledConfig = type(_G.LexusState.KillLimit.DisabledConfig) == "table" and _G.LexusState.KillLimit.DisabledConfig or nil


local limitTime = 1791912600
local currentTime = 0
local isExpired = false
-- 2026-10-13 21:00:00 UTC+3:30




-- Client-side clock validation removed intentionally.
-- License/update timing is based only on authoritative server time.
local function ZD_GetServerTime()
    local okUtil, TimeUtil = pcall(require, "client.common.time_util")
    if okUtil and TimeUtil and type(TimeUtil.GetServerTimeInSec) == "function" then
        local ok, t = pcall(TimeUtil.GetServerTimeInSec)
        t = ok and tonumber(t) or 0
        if t > 1700000000 then
            return t
        end
    end

    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then
        local ok, mod = pcall(require, "client.logic.common.TimeManager")
        if ok and mod then
            tm = mod
        end
    end

    if tm and type(tm.GetServerTime) == "function" then
        local okServer, serverTime = pcall(tm.GetServerTime)
        serverTime = okServer and tonumber(serverTime) or 0
        if serverTime > 1700000000 then
            return serverTime
        end
    end

    return 0
end

pcall(function()
    currentTime = ZD_GetServerTime()
    if currentTime > 0 then
        isExpired = currentTime > limitTime
    else
        -- Keep the existing fail-open behavior when server time cannot be read.
        currentTime = 0
        isExpired = false
    end
end)









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
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1, ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["report_players_ping"]=1,
                ["report_player_ip"]=1, ["report_net_saturate"]=1, ["report_speed_hack"]=1, ["report_wall_hack"]=1, ["report_aim_bot"]=1, ["report_esp_usage"]=1,
                ["report_modded_files"]=1, ["detect_cheat"]=1, ["ban_player"]=1, ["client_anti_cheat_report"]=1,
                ["ClientSecMrpcsFlow"]=1, ["MrpcsData"]=1, ["CheckReportSecAttackFlow"]=1, ["CheckReportSecAttackFlowWithAttackFlow"]=1, ["RPC_ClientCoronaLab"]=1,
                ["CoronaLabReport"]=1, ["CoronaLabData"]=1, ["PlayerSecurityInfo"]=1, ["ReportSecurityInfo"]=1, ["SendSecurityData"]=1, ["ClientCircleFlow"]=1,
                ["IsEnableReportMrpcsInCircleFlow"]=1, ["IsEnableReportMrpcsInPartCircleFlow"]=1, ["bReportedModifierException"]=1,
                ["ReportModifierException"]=1, ["RPC_Server_ReportSimulateCharacterLocation"]=1, ["ReportSimulateCharacterLocation"]=1, ["RPC_Client_ShootVertifyRes"]=1,
                ["BulletHitInfoUploadData"]=1, ["ShootVerifyFailed"]=1, ["report_unrealnet_exception"]=1, ["tss_sdk_report"]=1, ["SwiftHawk"]=1, ["ClientSwiftHawk"]=1, ["ClientSwiftHawkWithParams"]=1, ["SwiftHawkReport"]=1, ["SwiftHawkData"]=1,
                ["AntiCheatReport"]=1, ["CheatDetection"]=1, ["ViolationReport"]=1, ["SecurityViolation"]=1, ["IntegrityCheck"]=1, ["SignatureVerify"]=1
            }
            NetUtil.SendPacket = function(packetName, ...) if blocked[packetName] then return nil end; return orig(packetName, ...) end
            NetUtil.IsBypassed = true
        end
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            local blockedRPC = {"RPC_Server_ClientSecMrpcsFlow", "RPC_Server_SwiftHawk", "RPC_Server_ClientSwiftHawkWithParams", "RPC_Server_ReportSimulateCharacterLocation", "RPC_Client_ShootVertifyRes", "RPC_ClientCoronaLab"}
            _G.SendRPC = function(rpcName, ...) for _, b in ipairs(blockedRPC) do if rpcName == b then return nil end end; return origRPC(rpcName, ...) end
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
        print("[ULTIMATE BYPASS] Complete - All Security Systems Disabled")
    end)
end




local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end




local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end




local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    
    local isAI = false
    local hasChecked = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true; hasChecked = true end
        if type(pawn.IsBot) == "function" and pawn:IsBot() then isAI = true; hasChecked = true end
        
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) then
            hasChecked = true
            if pState.bIsABot == true or pState.bIsBot == true then isAI = true end
            if type(pState.IsBot) == "function" and pState:IsBot() then isAI = true end
        end
        
        if not isAI then
            local name = pawn.PlayerName or (type(pawn.GetPlayerName) == "function" and pawn:GetPlayerName()) or ""
            if name ~= "" and (name:find("Cobra") or name:find("Target") or name:find("bot_") or name:find("b_")) then
                isAI = true
                hasChecked = true
            end
        end
    end)
    if hasChecked then markData.AK_IS_BOT = isAI end
    return isAI, hasChecked
end








local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,

        
        "/storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        fileName
    }

    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
                table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName)
            end
        end
    end)

    return paths
end

local ConfigFileName = "ZDMOD_settings.json"
local LegacyConfigFileName = "ZONE_MOD_settings.txt"
_G.LastConfigSaveStr = _G.LastConfigSaveStr or ""
_G.ZONE_MOD_SAVED_KEY = _G.ZONE_MOD_SAVED_KEY or nil
_G.ZONE_MOD_SETTINGS_PATH = _G.ZONE_MOD_SETTINGS_PATH or nil

local ACTIVE_CUSTOM_TEXT_DEFAULTS = {
    IpadViewFOV = 120,
}
local ACTIVE_CUSTOM_TEXT_KEYS = { IpadViewFOV = true }

local function SanitizeActiveRuntimeConfig()
    local cfg = _G.LexusConfig or {}
    for key in pairs(cfg) do
        if not ACTIVE_CONFIG_KEYS[key] then cfg[key] = nil end
    end
    for key, defaultValue in pairs(ACTIVE_CONFIG_DEFAULTS) do
        if cfg[key] == nil then cfg[key] = defaultValue end
    end
    if type(cfg.EspItem_Selected) ~= "table" then cfg.EspItem_Selected = {} end

    local textData = _G.LexusState.CustomTextData
    if type(textData) ~= "table" then textData = {} end
    for key in pairs(textData) do
        if not ACTIVE_CUSTOM_TEXT_KEYS[key] then textData[key] = nil end
    end
    for key, defaultValue in pairs(ACTIVE_CUSTOM_TEXT_DEFAULTS) do
        if textData[key] == nil then textData[key] = defaultValue end
    end
    _G.LexusState.CustomTextData = textData
end

SanitizeActiveRuntimeConfig()


_G.SaveModSettings = function()
    local killLimit = _G.LexusState and _G.LexusState.KillLimit
    if killLimit and killLimit.Reached then return true end

    local ok, result = pcall(function()
        local savedKey = _G.ZONE_MOD_SAVED_KEY
        local data = {
            "return {",
            "Version = 2,",
            "AccessKey = " .. (savedKey and string.format("%q", tostring(savedKey)) or "nil") .. ",",
            "LexusConfig = {"
        }

        for k, v in pairs(_G.LexusConfig or {}) do
            if ACTIVE_CONFIG_KEYS[k] then
                local tv = type(v)
                if tv == "boolean" or tv == "number" then
                    data[#data + 1] = "  [" .. string.format("%q", tostring(k)) .. "] = " .. tostring(v) .. ","
                elseif tv == "string" then
                    data[#data + 1] = "  [" .. string.format("%q", tostring(k)) .. "] = " .. string.format("%q", v) .. ","
                end
            end
        end

        data[#data + 1] = "},"
        data[#data + 1] = "CustomTextData = {"
        if _G.LexusState and type(_G.LexusState.CustomTextData) == "table" then
            for k, v in pairs(_G.LexusState.CustomTextData) do
                if ACTIVE_CUSTOM_TEXT_KEYS[k] then
                    local tv = type(v)
                    if tv == "boolean" or tv == "number" then
                        data[#data + 1] = "  [" .. string.format("%q", tostring(k)) .. "] = " .. tostring(v) .. ","
                    elseif tv == "string" then
                        data[#data + 1] = "  [" .. string.format("%q", tostring(k)) .. "] = " .. string.format("%q", v) .. ","
                    end
                end
            end
        end

        data[#data + 1] = "}"
        data[#data + 1] = "}"
        local content = table.concat(data, "\n")

        if content == _G.LastConfigSaveStr and _G.ZONE_MOD_SETTINGS_PATH then
            local existing = nil
            pcall(function() existing = io.open(_G.ZONE_MOD_SETTINGS_PATH, "r") end)
            if existing then
                existing:close()
                return true
            end
        end

        local paths = GetConfigPaths(ConfigFileName)
        local function tryWrite(path)
            local f = nil
            pcall(function() f = io.open(path, "w") end)
            if not f then
                pcall(function()
                    local dir = path:match("^(.*)/[^/]+$")
                    if dir and os and os.execute then
                        os.execute('mkdir -p "' .. dir .. '"')
                    end
                end)
                pcall(function() f = io.open(path, "w") end)
            end
            if not f then return false end
            local writeOK = pcall(function()
                f:write(content)
                f:flush()
                f:close()
            end)
            if not writeOK then
                pcall(function() f:close() end)
                return false
            end
            return true
        end

        for _, path in ipairs(paths) do
            if tryWrite(path) then
                _G.ZONE_MOD_SETTINGS_PATH = path
                _G.LastConfigSaveStr = content
                return true
            end
        end
        return false
    end)
    return ok and result == true
end


_G.LoadModSettings = function()
    local ok, loaded = pcall(function()
        local content = nil
        local paths = GetConfigPaths(ConfigFileName)

        
        if _G.ZONE_MOD_SETTINGS_PATH then
            local f = nil
            pcall(function() f = io.open(_G.ZONE_MOD_SETTINGS_PATH, "r") end)
            if f then
                content = f:read("*a")
                f:close()
            end
        end

        if not content then
            for _, path in ipairs(paths) do
                local f = nil
                pcall(function() f = io.open(path, "r") end)
                if f then
                    content = f:read("*a")
                    f:close()
                    _G.ZONE_MOD_SETTINGS_PATH = path
                    break
                end
            end
        end

        
        if not content and LegacyConfigFileName ~= ConfigFileName then
            local legacyPaths = GetConfigPaths(LegacyConfigFileName)
            for _, path in ipairs(legacyPaths) do
                local f = nil
                pcall(function() f = io.open(path, "r") end)
                if f then
                    content = f:read("*a")
                    f:close()
                    
                    _G.ZONE_MOD_SETTINGS_PATH = nil
                    break
                end
            end
        end

        if not content or content == "" then
            return false
        end

        local loader = loadstring or load
        if type(loader) ~= "function" then return false end

        local chunk = loader(content)
        if type(chunk) ~= "function" then return false end
        local savedData = chunk()
        if type(savedData) ~= "table" then return false end

        if type(savedData.AccessKey) == "string" and savedData.AccessKey ~= "" then
            _G.ZONE_MOD_SAVED_KEY = savedData.AccessKey
        end

        if type(savedData.LexusConfig) == "table" then
            _G.LexusConfig = _G.LexusConfig or {}
            for k, v in pairs(savedData.LexusConfig) do
                if ACTIVE_CONFIG_KEYS[k] then
                    local tv = type(v)
                    if tv == "boolean" or tv == "number" or tv == "string" then
                        _G.LexusConfig[k] = v
                    elseif k == "EspItem_Selected" and type(v) == "table" then
                        _G.LexusConfig[k] = v
                    end
                end
            end
        end

        if type(savedData.CustomTextData) == "table" then
            _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
            for k, v in pairs(savedData.CustomTextData) do
                if ACTIVE_CUSTOM_TEXT_KEYS[k] then
                    local tv = type(v)
                    if tv == "boolean" or tv == "number" or tv == "string" then
                        _G.LexusState.CustomTextData[k] = v
                    end
                end
            end
        end

        SanitizeActiveRuntimeConfig()
        _G.LastConfigSaveStr = content
        return true
    end)
    return ok and loaded == true
end


local function AutoSaveLoop()
    pcall(function()
        if _G.SaveModSettings then _G.SaveModSettings() end
    end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(3.0, AutoSaveLoop)
        end
    end)
end


pcall(function() _G.LoadModSettings() end)


pcall(function()
    local fov = tonumber(_G.LexusConfig.AimTouchFOV or 30) or 30
    if fov < 1 then fov = 1 end
    if fov > 100 then fov = 100 end
    _G.LexusConfig.AimTouchFOV = fov
end)
SanitizeActiveRuntimeConfig()
if not _G.ModConfigLoaded then
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end

_G.ReadLiveConfig = function()
    if _G.SaveModSettings then return _G.SaveModSettings() end
    return false
end





function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    
    local function T(faText, _unused)
        return faText
    end

    SanitizeActiveRuntimeConfig()

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    
    local FakeTextMap = {
        [999000] = T("@ZONE_MOD - ZD V4 ♝"),
        [999001] = T("♛ESP PLAYER♛"),
        [999002] = T("♛ESP ITEMS♛"),
        [999003] = T("♛AIM MENU♛"),
        [999004] = T("♛SPICHIAL MENU♛"),
        [999005] = T("♛SKIN MOD♛"),
        [999006] = T("E")
    }

    
    if LocUtil and not LocUtil._IsModMenuHooked_V2 then
        local hookFuncs = {"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}
        for _, funcName in ipairs(hookFuncs) do
            if LocUtil[funcName] then
                local old_func = LocUtil[funcName]
                LocUtil[funcName] = function(id)
                    if FakeTextMap[id] then
                        return FakeTextMap[id]
                    end
                    if type(id) == "string" and not tonumber(id) then
                        return id
                    end
                    if old_func then
                        return old_func(id)
                    end
                    return ""
                end
            end
        end
        LocUtil._IsModMenuHooked_V2 = true
    end

    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    
    if not SettingPageDefine.ModMenu then
        local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
        
        local StackESP = {
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = T("OLD ESP"), GetFunc = function() return _G.LexusConfig.EspVip end, SetFunc = function(c,v) _G.LexusConfig.EspVip = v return true end },

            { Key = "ModMenu_ESP3_Ex", UI = AliasMap.TitleSwitcher, Text = T("ESP BOX 2"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.EspVipPro end, SetFunc = function(c,v) _G.LexusConfig.EspVipPro = v return true end },
            { Key = "ModMenu_ESP3_Name", UI = AliasMap.Switcher, Text = T(" SHOW NAME "), ExpandHandle = "ModMenu_ESP3_Ex", GetFunc = function() return _G.LexusConfig.Esp3ShowName end, SetFunc = function(c,v) _G.LexusConfig.Esp3ShowName = v return true end },
            { Key = "ModMenu_ESP3_HP", UI = AliasMap.Switcher, Text = T(" SHOW HP ENEMY "), ExpandHandle = "ModMenu_ESP3_Ex", GetFunc = function() return _G.LexusConfig.Esp3ShowHP end, SetFunc = function(c,v) _G.LexusConfig.Esp3ShowHP = v return true end },

            { Key = "ModMenu_AdvancedRadar", UI = AliasMap.Switcher, Text = T("✦ ESP PRO ✦"), GetFunc = function() return _G.LexusConfig.EspAdvancedRadar end, SetFunc = function(c,v) _G.LexusConfig.EspAdvancedRadar = v return true end }
        }

        local StackItems = {
            { Key = "ModMenu_EspItem_Ex", UI = AliasMap.TitleSwitcher, Text = T("Items (70m)"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.EspItem_Master end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Master = v return true end },
            { Key = "ModMenu_EspItem_CAT_AR", UI = AliasMap.TitleSwitcher, Text = T("   Rifles"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_101001", UI = AliasMap.Switcher, Text = T("      AKM"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:AKM"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:AKM"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101002", UI = AliasMap.Switcher, Text = T("      M16A4"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:M16A4"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:M16A4"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101003", UI = AliasMap.Switcher, Text = T("      SCAR-L"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:SCAR-L"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:SCAR-L"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101004", UI = AliasMap.Switcher, Text = T("      M416"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:M416"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:M416"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101005", UI = AliasMap.Switcher, Text = T("      Groza"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:Groza"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:Groza"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101006", UI = AliasMap.Switcher, Text = T("      AUG"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:AUG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:AUG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101007", UI = AliasMap.Switcher, Text = T("      QBZ"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:QBZ"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:QBZ"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101008", UI = AliasMap.Switcher, Text = T("      M762"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:M762"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:M762"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101009", UI = AliasMap.Switcher, Text = T("      Mk47 Mutant"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:Mk47 Mutant"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:Mk47 Mutant"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101010", UI = AliasMap.Switcher, Text = T("      G36C"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:G36C"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:G36C"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101011", UI = AliasMap.Switcher, Text = T("      AC-VAL"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:AC-VAL"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:AC-VAL"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101012", UI = AliasMap.Switcher, Text = T("      Honey Badger"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:Honey Badger"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:Honey Badger"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101100", UI = AliasMap.Switcher, Text = T("      FAMAS"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:FAMAS"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:FAMAS"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101101", UI = AliasMap.Switcher, Text = T("      ASM Abakan AR"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:ASM Abakan AR"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:ASM Abakan AR"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_101102", UI = AliasMap.Switcher, Text = T("      ACE32"), ExpandHandle = "ModMenu_EspItem_CAT_AR", GetFunc = function() return _G.LexusConfig.EspItem_Selected["AR:ACE32"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["AR:ACE32"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_SMG", UI = AliasMap.TitleSwitcher, Text = T("   SMG"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_102001", UI = AliasMap.Switcher, Text = T("      UZI"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:UZI"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:UZI"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_102002", UI = AliasMap.Switcher, Text = T("      UMP45"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:UMP45"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:UMP45"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_102003", UI = AliasMap.Switcher, Text = T("      Vector"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:Vector"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:Vector"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_102004", UI = AliasMap.Switcher, Text = T("      Thompson SMG"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:Thompson SMG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:Thompson SMG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_102005", UI = AliasMap.Switcher, Text = T("      PP-19 Bizon"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:PP-19 Bizon"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:PP-19 Bizon"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_102007", UI = AliasMap.Switcher, Text = T("      MP5K"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:MP5K"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:MP5K"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_102008", UI = AliasMap.Switcher, Text = T("      JS9"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:JS9"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:JS9"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_102105", UI = AliasMap.Switcher, Text = T("      P90"), ExpandHandle = "ModMenu_EspItem_CAT_SMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["SMG:P90"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["SMG:P90"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Sniper", UI = AliasMap.TitleSwitcher, Text = T("   Sniper"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_103001", UI = AliasMap.Switcher, Text = T("      Kar98K"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:Kar98K"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:Kar98K"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103002", UI = AliasMap.Switcher, Text = T("      M24"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:M24"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:M24"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103003", UI = AliasMap.Switcher, Text = T("      AWM"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:AWM"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:AWM"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103004", UI = AliasMap.Switcher, Text = T("      SKS"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:SKS"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:SKS"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103005", UI = AliasMap.Switcher, Text = T("      VSS"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:VSS"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:VSS"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103006", UI = AliasMap.Switcher, Text = T("      Mini14"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:Mini14"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:Mini14"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103007", UI = AliasMap.Switcher, Text = T("      Mk14"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:Mk14"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:Mk14"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103008", UI = AliasMap.Switcher, Text = T("      Win94"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:Win94"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:Win94"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103009", UI = AliasMap.Switcher, Text = T("      SLR"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:SLR"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:SLR"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103010", UI = AliasMap.Switcher, Text = T("      QBU"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:QBU"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:QBU"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103011", UI = AliasMap.Switcher, Text = T("      Mosin Nagant"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:Mosin Nagant"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:Mosin Nagant"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103012", UI = AliasMap.Switcher, Text = T("      AMR"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:AMR"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:AMR"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103100", UI = AliasMap.Switcher, Text = T("      Mk12"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:Mk12"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:Mk12"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103101", UI = AliasMap.Switcher, Text = T("      TR-2A Air Gun"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:TR-2A Air Gun"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:TR-2A Air Gun"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103102", UI = AliasMap.Switcher, Text = T("      DSR"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:DSR"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:DSR"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103103", UI = AliasMap.Switcher, Text = T("      Sniper Rifle"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:Sniper Rifle"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:Sniper Rifle"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_103105", UI = AliasMap.Switcher, Text = T("      SR"), ExpandHandle = "ModMenu_EspItem_CAT_Sniper", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Sniper:SR"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Sniper:SR"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Shotgun", UI = AliasMap.TitleSwitcher, Text = T("   Shotgun"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_104001", UI = AliasMap.Switcher, Text = T("      S686"), ExpandHandle = "ModMenu_EspItem_CAT_Shotgun", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Shotgun:S686"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Shotgun:S686"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_104002", UI = AliasMap.Switcher, Text = T("      S1897"), ExpandHandle = "ModMenu_EspItem_CAT_Shotgun", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Shotgun:S1897"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Shotgun:S1897"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_104003", UI = AliasMap.Switcher, Text = T("      S12K"), ExpandHandle = "ModMenu_EspItem_CAT_Shotgun", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Shotgun:S12K"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Shotgun:S12K"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_104004", UI = AliasMap.Switcher, Text = T("      DBS"), ExpandHandle = "ModMenu_EspItem_CAT_Shotgun", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Shotgun:DBS"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Shotgun:DBS"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_104100", UI = AliasMap.Switcher, Text = T("      SPAS-12"), ExpandHandle = "ModMenu_EspItem_CAT_Shotgun", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Shotgun:SPAS-12"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Shotgun:SPAS-12"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_104101", UI = AliasMap.Switcher, Text = T("      M1014"), ExpandHandle = "ModMenu_EspItem_CAT_Shotgun", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Shotgun:M1014"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Shotgun:M1014"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_104102", UI = AliasMap.Switcher, Text = T("      NS2000"), ExpandHandle = "ModMenu_EspItem_CAT_Shotgun", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Shotgun:NS2000"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Shotgun:NS2000"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_LMG", UI = AliasMap.TitleSwitcher, Text = T("   LMG"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_105001", UI = AliasMap.Switcher, Text = T("      M249"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:M249"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:M249"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105002", UI = AliasMap.Switcher, Text = T("      DP-28"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:DP-28"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:DP-28"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105003", UI = AliasMap.Switcher, Text = T("      M134"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:M134"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:M134"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105010", UI = AliasMap.Switcher, Text = T("      MG3"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:MG3"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:MG3"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105101", UI = AliasMap.Switcher, Text = T("      Gatling"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Gatling"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Gatling"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105115", UI = AliasMap.Switcher, Text = T("      Lib Gatling MG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Lib Gatling MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Lib Gatling MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105004", UI = AliasMap.Switcher, Text = T("      Flamethrower"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Flamethrower"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Flamethrower"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105006", UI = AliasMap.Switcher, Text = T("      M2 Fixed MG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:M2 Fixed MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:M2 Fixed MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105007", UI = AliasMap.Switcher, Text = T("      Gatling Fixed MG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Gatling Fixed MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Gatling Fixed MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105008", UI = AliasMap.Switcher, Text = T("      Mounted Flamethrower"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Mounted Flamethrower"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Mounted Flamethrower"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105009", UI = AliasMap.Switcher, Text = T("      M2 Mounted MG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:M2 Mounted MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:M2 Mounted MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105102", UI = AliasMap.Switcher, Text = T("      Vehicle SG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Vehicle SG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Vehicle SG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105103", UI = AliasMap.Switcher, Text = T("      RPG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:RPG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:RPG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105105", UI = AliasMap.Switcher, Text = T("      PowPow MG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:PowPow MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:PowPow MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105106", UI = AliasMap.Switcher, Text = T("      Tank Cannon"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Tank Cannon"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Tank Cannon"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105107", UI = AliasMap.Switcher, Text = T("      Tank MG"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Tank MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Tank MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105108", UI = AliasMap.Switcher, Text = T("      Tank Flare Gun"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Tank Flare Gun"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Tank Flare Gun"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105116", UI = AliasMap.Switcher, Text = T("      Lib Autocannon"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Lib Autocannon"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Lib Autocannon"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105117", UI = AliasMap.Switcher, Text = T("      Jet Missile"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Jet Missile"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Jet Missile"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_105118", UI = AliasMap.Switcher, Text = T("      Jet Autocannon"), ExpandHandle = "ModMenu_EspItem_CAT_LMG", GetFunc = function() return _G.LexusConfig.EspItem_Selected["LMG:Jet Autocannon"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["LMG:Jet Autocannon"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Pistol", UI = AliasMap.TitleSwitcher, Text = T("   Pistols"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_106001", UI = AliasMap.Switcher, Text = T("      P92"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:P92"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:P92"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106002", UI = AliasMap.Switcher, Text = T("      P1911"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:P1911"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:P1911"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106003", UI = AliasMap.Switcher, Text = T("      R1895"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:R1895"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:R1895"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106004", UI = AliasMap.Switcher, Text = T("      P18C"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:P18C"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:P18C"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106005", UI = AliasMap.Switcher, Text = T("      R45"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:R45"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:R45"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106006", UI = AliasMap.Switcher, Text = T("      Sawed-off"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Sawed-off"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Sawed-off"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106008", UI = AliasMap.Switcher, Text = T("      Skorpion"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Skorpion"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Skorpion"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106010", UI = AliasMap.Switcher, Text = T("      Desert Eagle"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Desert Eagle"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Desert Eagle"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106007", UI = AliasMap.Switcher, Text = T("      Flare Gun"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Flare Gun"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Flare Gun"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106011", UI = AliasMap.Switcher, Text = T("      Dual MP7"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Dual MP7"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Dual MP7"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106012", UI = AliasMap.Switcher, Text = T("      Welding Gun"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Welding Gun"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Welding Gun"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106013", UI = AliasMap.Switcher, Text = T("      Stun Gun"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Stun Gun"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Stun Gun"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106101", UI = AliasMap.Switcher, Text = T("      Vehicle Flare"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Vehicle Flare"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Vehicle Flare"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106106", UI = AliasMap.Switcher, Text = T("      Flare (Empty)"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Flare (Empty)"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Flare (Empty)"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106107", UI = AliasMap.Switcher, Text = T("      Respawn Flare"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Respawn Flare"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Respawn Flare"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_106203", UI = AliasMap.Switcher, Text = T("      Magnet Gun"), ExpandHandle = "ModMenu_EspItem_CAT_Pistol", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Pistol:Magnet Gun"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Pistol:Magnet Gun"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Special", UI = AliasMap.TitleSwitcher, Text = T("   Special"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_107001", UI = AliasMap.Switcher, Text = T("      Crossbow"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Crossbow"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Crossbow"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107002", UI = AliasMap.Switcher, Text = T("      RPG-7"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:RPG-7"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:RPG-7"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107003", UI = AliasMap.Switcher, Text = T("      Riot shield"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Riot shield"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Riot shield"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107004", UI = AliasMap.Switcher, Text = T("      Combat Drone"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Combat Drone"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Combat Drone"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107005", UI = AliasMap.Switcher, Text = T("      Panzerfaust"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Panzerfaust"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Panzerfaust"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107007", UI = AliasMap.Switcher, Text = T("      Tactical Crossbow"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Tactical Crossbow"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Tactical Crossbow"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107008", UI = AliasMap.Switcher, Text = T("      Explosive Bow"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Explosive Bow"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Explosive Bow"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107010", UI = AliasMap.Switcher, Text = T("      M79 Smoke Launcher"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:M79 Smoke Launcher"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:M79 Smoke Launcher"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107019", UI = AliasMap.Switcher, Text = T("      Atlas Gauntlet"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Atlas Gauntlet"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Atlas Gauntlet"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107020", UI = AliasMap.Switcher, Text = T("      Explosive Crossbow"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Explosive Crossbow"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Explosive Crossbow"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107021", UI = AliasMap.Switcher, Text = T("      Mercury Hammer"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Mercury Hammer"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Mercury Hammer"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107022", UI = AliasMap.Switcher, Text = T("      Fishbones Rocket"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Fishbones Rocket"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Fishbones Rocket"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107031", UI = AliasMap.Switcher, Text = T("      Summer Grenade Launcher"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Summer Grenade Launcher"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Summer Grenade Launcher"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107032", UI = AliasMap.Switcher, Text = T("      Summer Bazooka"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Summer Bazooka"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Summer Bazooka"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107033", UI = AliasMap.Switcher, Text = T("      Summer MG"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Summer MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Summer MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107034", UI = AliasMap.Switcher, Text = T("      Color Bazooka"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Color Bazooka"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Color Bazooka"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107035", UI = AliasMap.Switcher, Text = T("      Bubble MG"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Bubble MG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Bubble MG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107036", UI = AliasMap.Switcher, Text = T("      Snowball Blaster"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Snowball Blaster"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Snowball Blaster"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107037", UI = AliasMap.Switcher, Text = T("      Water Orb Blaster"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Water Orb Blaster"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Water Orb Blaster"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107092", UI = AliasMap.Switcher, Text = T("      MGL"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:MGL"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:MGL"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107093", UI = AliasMap.Switcher, Text = T("      M202 Quad RPG"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:M202 Quad RPG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:M202 Quad RPG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107094", UI = AliasMap.Switcher, Text = T("      AT4-A Laser Missile"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:AT4-A Laser Missile"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:AT4-A Laser Missile"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107096", UI = AliasMap.Switcher, Text = T("      M79 Sawed-off"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:M79 Sawed-off"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:M79 Sawed-off"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107097", UI = AliasMap.Switcher, Text = T("      M79"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:M79"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:M79"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107099", UI = AliasMap.Switcher, Text = T("      M3E1-A"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:M3E1-A"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:M3E1-A"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107901", UI = AliasMap.Switcher, Text = T("      Zombie Piercer"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Zombie Piercer"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Zombie Piercer"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107903", UI = AliasMap.Switcher, Text = T("      Mounted RPG"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Mounted RPG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Mounted RPG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107904", UI = AliasMap.Switcher, Text = T("      Helicopter RPG"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:Helicopter RPG"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:Helicopter RPG"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_107911", UI = AliasMap.Switcher, Text = T("      M3E1-B Missile"), ExpandHandle = "ModMenu_EspItem_CAT_Special", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Special:M3E1-B Missile"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Special:M3E1-B Missile"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Melee", UI = AliasMap.TitleSwitcher, Text = T("   Melee"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_108001", UI = AliasMap.Switcher, Text = T("      Machete"), ExpandHandle = "ModMenu_EspItem_CAT_Melee", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Melee:Machete"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Melee:Machete"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_108002", UI = AliasMap.Switcher, Text = T("      Crowbar"), ExpandHandle = "ModMenu_EspItem_CAT_Melee", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Melee:Crowbar"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Melee:Crowbar"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_108003", UI = AliasMap.Switcher, Text = T("      Sickle"), ExpandHandle = "ModMenu_EspItem_CAT_Melee", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Melee:Sickle"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Melee:Sickle"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_108004", UI = AliasMap.Switcher, Text = T("      Pan"), ExpandHandle = "ModMenu_EspItem_CAT_Melee", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Melee:Pan"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Melee:Pan"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_108005", UI = AliasMap.Switcher, Text = T("      Dagger"), ExpandHandle = "ModMenu_EspItem_CAT_Melee", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Melee:Dagger"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Melee:Dagger"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_108006", UI = AliasMap.Switcher, Text = T("      Mutation Blade"), ExpandHandle = "ModMenu_EspItem_CAT_Melee", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Melee:Mutation Blade"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Melee:Mutation Blade"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_108007", UI = AliasMap.Switcher, Text = T("      Mutation Gauntlets"), ExpandHandle = "ModMenu_EspItem_CAT_Melee", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Melee:Mutation Gauntlets"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Melee:Mutation Gauntlets"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Scope", UI = AliasMap.TitleSwitcher, Text = T("   Scopes"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_203001", UI = AliasMap.Switcher, Text = T("      Red Dot Sight"), ExpandHandle = "ModMenu_EspItem_CAT_Scope", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Scope:Red Dot Sight"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Scope:Red Dot Sight"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_203002", UI = AliasMap.Switcher, Text = T("      Holographic Sight"), ExpandHandle = "ModMenu_EspItem_CAT_Scope", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Scope:Holographic Sight"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Scope:Holographic Sight"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_203003", UI = AliasMap.Switcher, Text = T("      2x Scope"), ExpandHandle = "ModMenu_EspItem_CAT_Scope", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Scope:2x Scope"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Scope:2x Scope"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_203004", UI = AliasMap.Switcher, Text = T("      4x Scope"), ExpandHandle = "ModMenu_EspItem_CAT_Scope", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Scope:4x Scope"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Scope:4x Scope"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_203005", UI = AliasMap.Switcher, Text = T("      8x Scope"), ExpandHandle = "ModMenu_EspItem_CAT_Scope", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Scope:8x Scope"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Scope:8x Scope"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_203014", UI = AliasMap.Switcher, Text = T("      3x Scope"), ExpandHandle = "ModMenu_EspItem_CAT_Scope", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Scope:3x Scope"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Scope:3x Scope"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_203015", UI = AliasMap.Switcher, Text = T("      6x Scope"), ExpandHandle = "ModMenu_EspItem_CAT_Scope", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Scope:6x Scope"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Scope:6x Scope"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Grenade", UI = AliasMap.TitleSwitcher, Text = T("   Grenades"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_602001", UI = AliasMap.Switcher, Text = T("      Stun Grenade"), ExpandHandle = "ModMenu_EspItem_CAT_Grenade", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Grenade:Stun Grenade"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Grenade:Stun Grenade"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_602002", UI = AliasMap.Switcher, Text = T("      Smoke Grenade"), ExpandHandle = "ModMenu_EspItem_CAT_Grenade", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Grenade:Smoke Grenade"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Grenade:Smoke Grenade"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_602003", UI = AliasMap.Switcher, Text = T("      Molotov"), ExpandHandle = "ModMenu_EspItem_CAT_Grenade", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Grenade:Molotov"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Grenade:Molotov"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_602004", UI = AliasMap.Switcher, Text = T("      Frag Grenade"), ExpandHandle = "ModMenu_EspItem_CAT_Grenade", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Grenade:Frag Grenade"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Grenade:Frag Grenade"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_CAT_Med", UI = AliasMap.TitleSwitcher, Text = T("   Medical"), ExpandHandle = "ModMenu_EspItem_Ex", ExpandIndex = 0, GetFunc = function() return false end, SetFunc = function(c,v) return true end },
            { Key = "ModMenu_EspItem_601001", UI = AliasMap.Switcher, Text = T("      Energy Drink"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Nước Tăng Lực"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Nước Tăng Lực"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601002", UI = AliasMap.Switcher, Text = T("      Adrenaline Syringe"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Tiêm Adrenaline"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Tiêm Adrenaline"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601003", UI = AliasMap.Switcher, Text = T("      Painkiller"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Thuốc Giảm Đau"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Thuốc Giảm Đau"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601004", UI = AliasMap.Switcher, Text = T("      Bandage"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Băng Gạc"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Băng Gạc"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601005", UI = AliasMap.Switcher, Text = T("      First Aid Kit"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Bộ Sơ Cứu"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Bộ Sơ Cứu"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601006", UI = AliasMap.Switcher, Text = T("      Med Kit"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Bộ Cứu Thương"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Bộ Cứu Thương"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601009", UI = AliasMap.Switcher, Text = T("      Quick Bandage"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Băng Gạc Nhanh"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Băng Gạc Nhanh"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601010", UI = AliasMap.Switcher, Text = T("      Quick First Aid"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Sơ Cứu Nhanh"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Sơ Cứu Nhanh"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601011", UI = AliasMap.Switcher, Text = T("      Military Bandage"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Băng Gạc QĐ"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Băng Gạc QĐ"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601012", UI = AliasMap.Switcher, Text = T("      Boost Drink"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Nước Đậm Đặc"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Nước Đậm Đặc"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601077", UI = AliasMap.Switcher, Text = T("      Sơ Cứu Chiến Thuật"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Sơ Cứu Chiến Thuật"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Sơ Cứu Chiến Thuật"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601078", UI = AliasMap.Switcher, Text = T("      Sơ Cứu Toàn Năng"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Sơ Cứu Toàn Năng"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Sơ Cứu Toàn Năng"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601079", UI = AliasMap.Switcher, Text = T("      Cứu Thương Toàn Năng"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Cứu Thương Toàn Năng"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Cứu Thương Toàn Năng"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601085", UI = AliasMap.Switcher, Text = T("      Cứu Thương Nhanh"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Cứu Thương Nhanh"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Cứu Thương Nhanh"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601095", UI = AliasMap.Switcher, Text = T("      AED (Revive)"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Máy AED (Hồi Sinh)"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Máy AED (Hồi Sinh)"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_601096", UI = AliasMap.Switcher, Text = T("      Combat Preparation"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Chuẩn Bị Chiến Đấu"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Chuẩn Bị Chiến Đấu"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_602054", UI = AliasMap.Switcher, Text = T("      Tiếp Tế Y Tế"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Tiếp Tế Y Tế"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Tiếp Tế Y Tế"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end },
            { Key = "ModMenu_EspItem_602069", UI = AliasMap.Switcher, Text = T("      Cứu Trợ Khẩn Cấp"), ExpandHandle = "ModMenu_EspItem_CAT_Med", GetFunc = function() return _G.LexusConfig.EspItem_Selected["Med:Cứu Trợ Khẩn Cấp"] == true end, SetFunc = function(c,v) _G.LexusConfig.EspItem_Selected["Med:Cứu Trợ Khẩn Cấp"] = v if not v and _G.ClearItemESPSelection then _G.ClearItemESPSelection() end return true end }
        }
        local StackAimbotV2 = {
            {
                Key = "ModMenu_AimbotV2_Enable",
                UI = AliasMap.Switcher,
                Text = T(" AUTO AIM 70M SAFE"),
                GetFunc = function()
                    return _G.LexusConfig.AimTouchEnable
                end,
                SetFunc = function(c, v)
                    _G.LexusConfig.AimTouchEnable = v
                    return true
                end
            },
            {
                Key = "ModMenu_AimbotV2_FOV",
                UI = AliasMap.Slider,
                Text = T("AIM FOV ( 1 TO 45 SAFE )"),
                MinValue = 1,
                MaxValue = 100,
                min = 1,
                max = 100,
                Min = 1,
                Max = 100,
                GetFunc = function()
                    local v = tonumber(_G.LexusConfig.AimTouchFOV or 30) or 30
                    if v < 1 then v = 1 end
                    if v > 100 then v = 100 end
                    return math.floor(v + 0.5)
                end,
                SetFunc = function(c, v)
                    local val = math.floor((tonumber(v) or 30) + 0.5)
                    if val < 1 then val = 1 end
                    if val > 100 then val = 100 end
                    _G.LexusConfig.AimTouchFOV = val
                    return true
                end
            }
        }

        local StackSkin = {
            
            { Key = "ModMenu_ModEmote", UI = AliasMap.Switcher, Text = T("  Emote"), GetFunc = function() return _G.LexusConfig.ModEmote end, SetFunc = function(c,v) _G.LexusConfig.ModEmote = v return true end },
            { Key = "ModMenu_ModSkin", UI = AliasMap.Switcher, Text = T(" Skin"), GetFunc = function() return _G.LexusConfig.ModSkin end, SetFunc = function(c,v) _G.LexusConfig.ModSkin = v return true end },
            { Key = "ModMenu_SkinDeadBox", UI = AliasMap.Switcher, Text = T(" LootBox"), GetFunc = function() return _G.LexusConfig.SkinDeadBox end, SetFunc = function(c,v) _G.LexusConfig.SkinDeadBox = v return true end },
            { Key = "ModMenu_SkinAttachment", UI = AliasMap.Switcher, Text = T(" Attachment"), GetFunc = function() return _G.LexusConfig.SkinAttachment end, SetFunc = function(c,v) _G.LexusConfig.SkinAttachment = v return true end },
            { Key = "ModMenu_KillMessage", UI = AliasMap.Switcher, Text = T(" KillMessage"), GetFunc = function() return _G.LexusConfig.KillMessage end, SetFunc = function(c,v) _G.LexusConfig.KillMessage = v return true end },
            { Key = "ModMenu_KillCountUI", UI = AliasMap.Switcher, Text = T(" KillCount"), GetFunc = function() return _G.LexusConfig.KillCountUI end, SetFunc = function(c,v) _G.LexusConfig.KillCountUI = v return true end },
            { Key = "ModMenu_SkinOpenLink", UI = AliasMap.Switcher, Text = T("→ HOW TO USE ? "), GetFunc = function() return _G.LexusConfig.SkinOpenLink end, SetFunc = function(c,v) _G.LexusConfig.SkinOpenLink = v; if v == true then pcall(function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/Zone_Mod/1400") end end) end return true end },
        }

        local StackCombat = {            
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = T("♖ Ipad View"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.IpadView end, SetFunc = function(c,v) _G.LexusConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = T(" Fov Ipad View"), ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.LexusState.CustomTextData.IpadViewFOV or 120) - 90 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.IpadViewFOV = 90 + v return true end },
            
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = T(" Unlock 165 Fps"), GetFunc = function() return _G.LexusConfig.UnlockFPS end, SetFunc = function(c,v) _G.LexusConfig.UnlockFPS = v; if v then _G.LexusState.GraphicsUnlocked = false end return true end },
            
            { Key = "ModMenu_WallXuyenTuong", UI = AliasMap.Switcher, Text = T(" Old WallHack"), GetFunc = function() return _G.LexusConfig.WallXuyenTuong end, SetFunc = function(c,v) _G.LexusConfig.WallXuyenTuong = v return true end },
            { Key = "ModMenu_ColorBodyV2", UI = AliasMap.Switcher, Text = T(" Color WallHack"), GetFunc = function() return _G.LexusConfig.ColorBodyV2 end, SetFunc = function(c,v) _G.LexusConfig.ColorBodyV2 = v return true end },
            { Key = "ModMenu_ColorBodyNew", UI = AliasMap.Switcher, Text = T("✦ WH PRO ✦"), GetFunc = function() return _G.LexusConfig.ColorBodyNew end, SetFunc = function(c,v) _G.LexusConfig.ColorBodyNew = v return true end },
            
            { Key = "ModMenu_WhiteBody", UI = AliasMap.Switcher, Text = T(" Whit Body"), GetFunc = function() return _G.LexusConfig.WhiteBody end, SetFunc = function(c,v) _G.LexusConfig.WhiteBody = v return true end },
            { Key = "ModMenu_BlackSky", UI = AliasMap.Switcher, Text = T(" Black Sky"), GetFunc = function() return _G.LexusConfig.BlackSky end, SetFunc = function(c,v) _G.LexusConfig.BlackSky = v return true end },
            { Key = "ModMenu_RemoveFog", UI = AliasMap.Switcher, Text = T(" Remove Fog"), GetFunc = function() return _G.LexusConfig.RemoveFog end, SetFunc = function(c,v) _G.LexusConfig.RemoveFog = v return true end },
            { Key = "ModMenu_RemoveGrass", UI = AliasMap.Switcher, Text = T(" Remove Grass"), GetFunc = function() return _G.LexusConfig.RemoveGrass end, SetFunc = function(c,v) _G.LexusConfig.RemoveGrass = v return true end }
         }                          
        

        
        local function WrapStackSave(stack)
            for _, item in ipairs(stack) do
                if item and type(item.SetFunc) == "function" and not item.__ZONE_MOD_SaveWrapped then
                    local originalSetFunc = item.SetFunc
                    item.SetFunc = function(c, v)
                        local result = originalSetFunc(c, v)
                        if result ~= false and _G.SaveModSettings then
                            pcall(_G.SaveModSettings)
                        end
                        return result
                    end
                    item.__ZONE_MOD_SaveWrapped = true
                end
            end
        end
        WrapStackSave(StackESP)
        WrapStackSave(StackItems)
        WrapStackSave(StackAimbotV2)
        WrapStackSave(StackSkin)
        WrapStackSave(StackCombat)

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = 999000, 
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "Cat_ESP", Text = 999001, Stack = StackESP },
                { Key = "Cat_Items", Text = 999002, Stack = StackItems },
                { Key = "Cat_AimbotV2", Text = 999003, Stack = StackAimbotV2 },
                { Key = "Cat_Combat", Text = 999004, Stack = StackCombat },
                { Key = "Cat_Skin", Text = 999005, Stack = StackSkin }
            }
        }
        
        table.insert(SettingCatalog, 1, SettingPageDefine.ModMenu)
    end

    local UIManager = _G.UIManager
    if UIManager and not UIManager._IsModMenuHooked then
        local old_ShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, ...)
            local args = {...}
            local n = select('#', ...) 
            
            if config and config.keyName then
                local lowerKeyName = string.lower(config.keyName)
                if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
                    local catalog = args[1]
                    if type(catalog) == "table" and catalog[1] and type(catalog[1]) == "table" and catalog[1].Key then
                        local hasModMenu = false
                        for _, page in ipairs(catalog) do
                            if type(page) == "table" and page.Key == "ModMenu" then
                                hasModMenu = true
                                break
                            end
                        end
                        if not hasModMenu then
                            table.insert(catalog, 1, SettingPageDefine.ModMenu)
                        end
                    end
                end
            end
            local table_unpack = table.unpack or unpack
            return old_ShowUI(config, table_unpack(args, 1, n))
        end
        UIManager._IsModMenuHooked = true
    end
end

local function ShowLexusVIPMenu() 
    if _G.LexusMenuAlreadyShown then return end
    if _G.LexusState.MenuStep ~= 0 then return end

    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return end

        local function Step_ScamAlert()
            local title = "هشدار کلاهبرداری"
            local content = "برای دور ماندن از فروشندگان جعلی و کلاهبرداران، فقط از منبع اصلی استفاده کنید. (@ZONE_MOD)"
            local btn1 = "عضویت"
            local btn2 = "بستن"

            Msg.Show(1, title, content, function() local Web = require("client.slua.logic.url.logic_webview_sdk"); if Web and Web.OpenURL then Web:OpenURL("https://t.me/@ZONE_MOD") end end, function() end, btn1, btn2)
            _G.LexusState.MenuStep = 99
            _G.LexusMenuAlreadyShown = true
        end

        local function Step_Welcome()
            local title = "به منوی ویژه ZD V4 خوش آمدید"
            local content = "به منوی ویژه خوش آمدید.\nاز امکانات آن استفاده کنید و ایمن بازی کنید."
            local btn1 = "باز کردن منوی بازی"
            local btn2 = "بستن"

            Msg.Show(1, title, content, 
            function() 
                _G.InitModMenuTab()
                Notify("منوی ویژه افزوده شد!\nاز تنظیمات (آیکن چرخ‌دنده) ← منوی ویژه را برای استفاده باز کنید.")
                Step_ScamAlert()
            end, 
            function() end, btn1, btn2)
        end

        _G.LexusLang = "FA"
        _G.LexusState.MenuStep = 1
        Step_Welcome() 
    end)
end




local function InitializeGraphicsUnlock() 
    if isExpired then return end
    if _G.LexusState.GraphicsUnlocked or currentTime > limitTime then return end

    pcall(function()
        local SettingCfg = require("client.logic.setting.setting_config")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        if SettingCfg then
            if SettingCfg.TpViewValue then SettingCfg.TpViewValue.max = 160 end
            if SettingCfg.FpViewValue then SettingCfg.FpViewValue.max = 160 end
        end
        if GraphicSettingDB then
            if GraphicSettingDB.TpViewValue then GraphicSettingDB.TpViewValue.max = 160 end
        end
    end)

    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GSC_FPSFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        
        local KismetMathLibrary = import("KismetMathLibrary") or _G.KismetMathLibrary
        local FLinearColor = import("LinearColor") or _G.FLinearColor

        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then 
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end

        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
            function fps_impl:InitRealSupportFPS()
                local RealSupportFPS = {}
                for i = 1, 8 do RealSupportFPS[i] = {true, true} end
                if GraphicSettingDB then GraphicSettingDB:UpdateUIData(GraphicSettingDB.RealSupportFPS, RealSupportFPS, false) end
                return RealSupportFPS
            end
            function fps_impl:UpdateSelectedFPSState(selectedLevel)
                if not slua.isValid(self.UIRoot) then return end
                for level = 2, 8 do
                    local name = "NodeFps" .. (({[2]=20,[3]=25,[4]=30,[5]=40,[6]=60,[7]=90,[8]=120})[level] or 120)
                    local widget = self.UIRoot[name]
                    if slua.isValid(widget) then
                        widget:SetIsEnabled(true) 
                        pcall(function() widget:SetRenderOpacity(1.0) end)
                        local switcher = self.UIRoot["WidgetSwitcher_" .. level]
                        if slua.isValid(switcher) then 
                            switcher:SetActiveWidgetIndex(level == selectedLevel and 0 or 1) 
                        end
                    end
                end
            end
        end

        if GSC_FPSFT and GSC_FPSFT.__inner_impl then
            local ft_impl = GSC_FPSFT.__inner_impl
            local NMinFPS, NStep = 90, 5
            local function clamp(value, min, max)
                if value < min then return min end
                if max < value then return max end
                return value
            end
            local function lerp(a, b, t) return a + (b - a) * t end
            local function _getColorByPercent(start, finish, percent)
                if not FLinearColor then return nil end
                return FLinearColor(lerp(start.R, finish.R, percent), lerp(start.G, finish.G, percent), lerp(start.B, finish.B, percent), lerp(start.A, finish.A, percent))
            end
            
            ft_impl.ShowOrHide = function(self)
                self:SelfHitTestInvisible()
                if self.InitFPSFTSwitch then self:InitFPSFTSwitch() end
            end

            ft_impl.InitFPSFTSwitch = function(self)
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                if self.UIRoot.Setting_Switch then self.UIRoot.Setting_Switch:SetSwitcherEnable2(FPSFineTuneSwitch, true) end
                if self.UIRoot.CanvasPanel_8 then self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, FPSFineTuneSwitch) end
                if self.UIRoot.WidgetSwitcher_0 then self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2) end
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
            end

            ft_impl.InitFPSFTValue165 = function(self)
                local itemRoot = self.UIRoot
                local FPSFineTuneSwitch = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch)
                local FPSFineTuneNum = 165
                if FPSFineTuneSwitch then
                    FPSFineTuneNum = GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneNum) or 165
                    itemRoot.Slider_screen3:SetLocked(false)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 1.0, 1.0, 1.0))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 1.0, 1.0, 1.0))
                    end
                else
                    itemRoot.Slider_screen3:SetLocked(true)
                    if FLinearColor then
                        itemRoot.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1.0, 0.625, 0.6, 1))
                        itemRoot.Slider_screen3:SetSliderHandleColor(FLinearColor(1.0, 0.625, 0.6, 1.0))
                    end
                end
                local FPSFineTunePer = (FPSFineTuneNum - NMinFPS) / (165 - NMinFPS)
                
                itemRoot.Veihclescreen3:SetText(tostring(FPSFineTuneNum))
                itemRoot.Slider_screen3:SetValue(FPSFineTunePer)
                itemRoot.ProgressBar_screen3:SetPercent(FPSFineTunePer)
                
                if FLinearColor then
                    local startColor = FLinearColor(1.0, 1.0, 1.0, 1.0)
                    local midColor = FLinearColor(1.0, 0.54, 0.11, 1.0)
                    local endColor = FLinearColor(1.0, 0.23, 0.15, 1.0)
                    local sliderColor = FPSFineTunePer < 0.4 and startColor or _getColorByPercent(midColor, endColor, (FPSFineTunePer - 0.4) / 0.6)
                    itemRoot.Slider_screen3:SetSliderHandleColor(sliderColor)
                end
            end

            ft_impl.OnFPSFTValueChange3 = function(self, FPSFineTuneNum)
                GraphicSettingDB:UpdateUIData(GraphicSettingDB.FPSFineTuneNum, FPSFineTuneNum)
                if self.InitFPSFTValue165 then self:InitFPSFTValue165() end
                if self:GetParentUI() then self:GetParentUI():SetDirty(true) end
                local gameInstance = GraphicSettingDB.GetGameInstance and GraphicSettingDB.GetGameInstance()
                if gameInstance then
                    gameInstance:ExecuteCMD("t.MaxFPS", tostring(FPSFineTuneNum))
                    gameInstance:ExecuteCMD("r.FrameRateLimit", tostring(FPSFineTuneNum))
                end
            end

            ft_impl.OnFPSFTSliderValueChange3 = function(self, value)
                if GraphicSettingDB:GetUIData(GraphicSettingDB.FPSFineTuneSwitch) and KismetMathLibrary then
                    local FPSFineTuneNum = KismetMathLibrary.FCeil(value * (165 - NMinFPS) / NStep) * NStep + NMinFPS
                    self:OnFPSFTValueChange3(clamp(FPSFineTuneNum, NMinFPS, 165))
                end
            end
            
            ft_impl.OnFPSFTAdd = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTAdd2 = ft_impl.OnFPSFTAdd3
            ft_impl.OnFPSFTMinus2 = ft_impl.OnFPSFTMinus3
            ft_impl.OnFPSFTSliderValueChange = ft_impl.OnFPSFTSliderValueChange3
            ft_impl.OnFPSFTSliderValueChange2 = ft_impl.OnFPSFTSliderValueChange3
        end
    end)
    _G.LexusState.GraphicsUnlocked = true
    Notify("گرافیک و ۱۶۵ فریم‌برثانیه باز شد (نسخهٔ ارتقایافته)")
end




local function InitializeNativeESP() 
    if _G.LexusState.NativeESPReady then return end
    pcall(function() 
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools") 
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig") 
        local function ApplyCfg(cfg)
            if not cfg then return end 
            if cfg[1006] then 
                cfg[1006].bBindBlocked = true;
                cfg[1006].bBindOutScreen = true; 
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000; 
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"; 
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30) 
            end 
            
            cfg[9999] = { 
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
        ApplyCfg(currentMarkCfg) 
        for k, cfg in pairs(package.loaded) do 
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then 
                ApplyCfg(cfg) 
            end 
        end 
    end)
    _G.LexusState.NativeESPReady = true 
    Notify("سامانهٔ رادار داخلی راه‌اندازی شد") 
end




local function GetAllSkeletalMeshes(enemy, markData, includeWeapon)
    if not Valid(enemy) then return {} end

    local curTime = os.clock()
    local cached = markData and markData.CachedMeshes

    
    
    if cached and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 3.0) then
        local cacheIsValid = true
        for i = 1, #cached do
            if not Valid(cached[i]) then
                cacheIsValid = false
                break
            end
        end

        if not cacheIsValid then
            local writeIndex = 1
            for readIndex = 1, #cached do
                local cachedMesh = cached[readIndex]
                if Valid(cachedMesh) then
                    cached[writeIndex] = cachedMesh
                    writeIndex = writeIndex + 1
                end
            end
            for clearIndex = writeIndex, #cached do
                cached[clearIndex] = nil
            end
        end

        if not includeWeapon then
            return cached
        end

        
        
        local meshes = {}
        for i = 1, #cached do
            meshes[i] = cached[i]
        end

        local weapon = nil
        pcall(function()
            if type(enemy.GetCurrentWeapon) == "function" then
                weapon = enemy:GetCurrentWeapon()
            end
        end)
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            meshes[#meshes + 1] = weapon.Mesh
        end
        return meshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then
        meshes[1] = enemy.Mesh
    end

    pcall(function()
        local SkeletalMeshClass = _G.__ZD_SkeletalMeshComponentClass
        if not SkeletalMeshClass then
            SkeletalMeshClass = import("SkeletalMeshComponent")
            if SkeletalMeshClass then
                _G.__ZD_SkeletalMeshComponentClass = SkeletalMeshClass
            end
        end

        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i - 1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        meshes[#meshes + 1] = comp
                    end
                end
            end
        end
    end)

    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end

    if not includeWeapon then
        return meshes
    end

    local workingMeshes = {}
    for i = 1, #meshes do
        workingMeshes[i] = meshes[i]
    end

    local weapon = nil
    pcall(function()
        if type(enemy.GetCurrentWeapon) == "function" then
            weapon = enemy:GetCurrentWeapon()
        end
    end)
    if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
        workingMeshes[#workingMeshes + 1] = weapon.Mesh
    end
    return workingMeshes
end




local function UndoWallXuyenTuong(enemy, markData)
    pcall(function()
        if markData.WallhackApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
                    for i = 0, 10 do 
                        local matInterface = mesh:GetMaterial(i)
                        if Valid(matInterface) then
                            local baseMat = matInterface:GetBaseMaterial()
                            if Valid(baseMat) then baseMat.bDisableDepthTest = false end
                        end
                    end
                end
            end
            markData.WallhackApplied = false
        end
    end)
end

local function ApplyWallXuyenTuong(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then 
                pcall(function()
                    if type(mesh.SetRenderCustomDepth) == "function" then
                        mesh:SetRenderCustomDepth(true)
                    end
                    if type(mesh.SetCustomDepthStencilValue) == "function" then
                        mesh:SetCustomDepthStencilValue(252) 
                    end
                end)
                for i = 0, 10 do 
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        baseMat.bDisableDepthTest = true
                        baseMat.BlendMode = 2 
                    end
                end
            end
        end
    end)
end

local function ApplyColorBodyV2(enemy, pc, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        
        
        local curTime = os.clock()
        if markData.LastVisCheckTime == nil or (curTime - markData.LastVisCheckTime) > 0.3 then
            markData.LastVisCheckTime = curTime
            local isHidden = true
            pcall(function()
                if Valid(pc) and type(pc.LineOfSightTo) == "function" then
                    if pc:LineOfSightTo(enemy) then isHidden = false else isHidden = true end
                end
            end)
            markData.CachedHiddenState = isHidden
        end
        
        local hidden = markData.CachedHiddenState
        if hidden == nil then hidden = true end
        
        local cData = _G.LexusState.CustomTextData or {}
        local hiddenColor = {R = cData.HiddenR or 150, G = cData.HiddenG or 0, B = cData.HiddenB or 0, A = cData.HiddenA or 25}
        local visibleColor = {R = cData.VisibleR or 0, G = cData.VisibleG or 150, B = cData.VisibleB or 0, A = cData.VisibleA or 25}
        
        local finalColor = hidden and hiddenColor or visibleColor
        local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
        local currentMeshCount = #meshes
        local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
        
        
        if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end
        
        
        if isMeshChanged and markData.MIDs then
            markData.MIDs = {}
        end

        markData.LastHiddenState = hidden
        markData.LastMeshCount = currentMeshCount
        markData.LastColorHash = colorHash
        markData.ColorApplied = true
        
        for meshIndex, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    mesh.LDMaxDrawDistance = -99999
                    mesh.MaxDrawDistanceOffset = -99999
                    mesh.CachedMaxDrawDistance = -99999
                    mesh.UseScopeDistanceCulling = true
                    mesh.PrimitiveShadingStrategy = 1
                    mesh.ShadingRate = 6
                end)
                for i = 0, 10 do
                    local matInterface = mesh:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        local matName = tostring(baseMat)
                        if string.find(matName, "Master_Mask", 1, true) then
                            if not markData.MIDs then markData.MIDs = {} end
                            
                            
                            local meshKey = "Mesh_" .. tostring(meshIndex)
                            
                            if not markData.MIDs[meshKey] then markData.MIDs[meshKey] = {} end
                            local mid = markData.MIDs[meshKey][i]
                            if not Valid(mid) then
                                mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
                                markData.MIDs[meshKey][i] = mid
                            end
                            if Valid(mid) then
                                mid:SetVectorParameterValue("颜色", finalColor)
                                mid:SetVectorParameterValue("Extra Light Color", finalColor)
                                mid:SetVectorParameterValue("Para_Color", finalColor)
                                mid:SetVectorParameterValue("Para_ColorTint", finalColor)
                                mid:SetVectorParameterValue("Para_Color_1", finalColor)
                                mid:SetVectorParameterValue("Tint", finalColor)
                                mid:SetVectorParameterValue("Color", finalColor)
                                mid:SetVectorParameterValue("BaseColor", finalColor)
                                mid:SetVectorParameterValue("BodyColor", finalColor)
                                mid:SetVectorParameterValue("MainColor", finalColor)
                                mid:SetVectorParameterValue("DiffuseColor", finalColor)
                                mid:SetVectorParameterValue("EmissiveColor", finalColor)
                                mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function UndoColorBodyV2(enemy, markData)
    pcall(function()
        if markData.ColorApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        mesh.PrimitiveShadingStrategy = 0
                        mesh.ShadingRate = 1
                    end)
                    local meshKey = "Mesh_" .. tostring(meshIndex)
                    if markData.MIDs and markData.MIDs[meshKey] then
                        for i, mid in pairs(markData.MIDs[meshKey]) do
                            if Valid(mid) then
                                local defC = {R=1, G=1, B=1, A=1}
                                mid:SetVectorParameterValue("颜色", defC)
                                mid:SetVectorParameterValue("Extra Light Color", defC)
                                mid:SetVectorParameterValue("Para_Color", defC)
                                mid:SetVectorParameterValue("Para_ColorTint", defC)
                                mid:SetVectorParameterValue("Para_Color_1", defC)
                                mid:SetVectorParameterValue("Tint", defC)
                                mid:SetVectorParameterValue("Color", defC)
                                mid:SetVectorParameterValue("BaseColor", defC)
                                mid:SetVectorParameterValue("BodyColor", defC)
                                mid:SetVectorParameterValue("MainColor", defC)
                                mid:SetVectorParameterValue("DiffuseColor", defC)
                                mid:SetVectorParameterValue("EmissiveColor", defC)
                            end
                        end
                    end
                end
            end
            markData.ColorApplied = false
            markData.LastColorHash = ""
            markData.LastHiddenState = nil
        end
    end)
end





local function ApplyColorBodyNew(enemy, markData)
    pcall(function()
        
        if not _G.ConsoleNewWallReady then
            local KismetSystemLibrary = import("KismetSystemLibrary")
            local world = slua.getWorld()
            if KismetSystemLibrary and world then
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
                KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
                _G.ConsoleNewWallReady = true
            end
        end

        
        local meshes = GetAllSkeletalMeshes(enemy, markData, true)
        
        local isBot = markData.AK_IS_BOT or false
        local currentMeshCount = #meshes
        
        
        
        local stateHash = (isBot and "BOT" or "PLAYER") .. "_" .. tostring(currentMeshCount)
        
        if markData.LastColorNewHash == stateHash and markData.ColorNewApplied then
            return 
        end
        
        
        markData.LastColorNewHash = stateHash
        markData.ColorNewApplied = true

        
        local LinearColorClass = import("LinearColor") or _G.FLinearColor
        local c_vis = LinearColorClass and LinearColorClass(0, 100, 0, 1) or {R=0, G=100, B=0, A=1}
        local c_occ = LinearColorClass and LinearColorClass(100, 0, 0, 1) or {R=100, G=0, B=0, A=1}
        local c_bVis = LinearColorClass and LinearColorClass(49, 48, 0, 100) or {R=49, G=48, B=0, A=100}
        local c_bOcc = LinearColorClass and LinearColorClass(9, 1.5, 45, 100) or {R=9, G=1.5, B=45, A=100}

        local visColor = isBot and c_bVis or c_vis
        local occColor = isBot and c_bOcc or c_occ

        for _, mesh in ipairs(meshes) do
            if Valid(mesh) then
                pcall(function()
                    if type(mesh.SetDrawDyeing) == "function" then
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
                    end
                end)
            end
        end
    end)
end

local function UndoColorBodyNew(enemy, markData)
    pcall(function()
        if markData.ColorNewApplied then
            local meshes = GetAllSkeletalMeshes(enemy, markData, true)

            for _, mesh in ipairs(meshes) do
                if Valid(mesh) then
                    pcall(function()
                        if type(mesh.SetDrawDyeing) == "function" then
                            mesh:SetDrawDyeing(false)
                            mesh:SetDrawHighlight(false)
                            mesh:SetDrawIdeaOutline(false)
                            mesh:SetRenderCustomDepth(false)
                        end
                    end)
                end
            end
            markData.ColorNewApplied = false
            markData.LastColorNewHash = "" 
        end
    end)
end








_G.GetEnemyTargetsFromActors = function(radius)
    local result = {}
    local player = GameplayData.GetPlayerCharacter()

    if not slua.isValid(player) then
        return result
    end

    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then
        allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then
        for _, char in pairs(GameplayData.GameCharacters) do
            table.insert(allCharacters, char)
        end
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

_G.AimbotV2 = function()
    pcall(function()
        if not _G.LexusConfig.AimTouchEnable then
            _G.LexusState.AimbotV2TargetCache = nil
            return
        end

        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then
            _G.LexusState.AimbotV2TargetCache = nil
            return
        end

        local pc = player:GetPlayerControllerSafety()
        if not slua.isValid(pc) then
            _G.LexusState.AimbotV2TargetCache = nil
            return
        end

        
        local currentVehicle = nil
        pcall(function()
            currentVehicle = player.CurrentVehicle
            if not slua.isValid(currentVehicle) and type(player.GetCurrentVehicle) == "function" then
                currentVehicle = player:GetCurrentVehicle()
            end
            if not slua.isValid(currentVehicle) and type(player.GetVehicle) == "function" then
                currentVehicle = player:GetVehicle()
            end
        end)
        if slua.isValid(currentVehicle) then
            _G.LexusState.AimbotV2TargetCache = nil
            return
        end

        
        local isFiring = player.bIsWeaponFiring == true or player.bIsWeaponFiring == 1
        if not isFiring then
            return
        end

        local isADS = player.bIsGunADS == true
            or player.bIsWeaponAiming == true
            or player.bIsWeaponAiming == 1

        
        
        local rawFov = tonumber(_G.LexusConfig.AimTouchFOV or 30) or 30
        if rawFov < 1 then rawFov = 1 end
        if rawFov > 100 then rawFov = 100 end
        local fovVal = rawFov * 0.35
        if fovVal < 0.35 then fovVal = 0.35 end
        if fovVal > 35 then fovVal = 35 end

        
        local speedVal = 70
        local boneName = "spine_03" 
        local maxDistCm = 7000
        local useVisCheck = true

        _G.LexusState.AimbotV2Runtime = _G.LexusState.AimbotV2Runtime or {}
        local AimRuntime = _G.LexusState.AimbotV2Runtime

        if not AimRuntime.Vector2D then pcall(function() AimRuntime.Vector2D = import("Vector2D") end) end
        if not AimRuntime.GameplayStatics then pcall(function() AimRuntime.GameplayStatics = import("GameplayStatics") end) end
        if not AimRuntime.KismetMathLibrary then pcall(function() AimRuntime.KismetMathLibrary = import("KismetMathLibrary") end) end
        if not AimRuntime.UIUtil then pcall(function() AimRuntime.UIUtil = require("client.common.ui_util") end) end

        local FVector2D = AimRuntime.Vector2D
        local UGameplayStatics = AimRuntime.GameplayStatics
        local KismetMathLibrary = AimRuntime.KismetMathLibrary
        if not FVector2D or not UGameplayStatics or not KismetMathLibrary or not AimRuntime.UIUtil then
            return
        end

        if AimRuntime.PC ~= pc or not slua.isValid(AimRuntime.CameraManager) then
            AimRuntime.PC = pc
            AimRuntime.CameraManager = UGameplayStatics.GetPlayerCameraManager(pc, 0)
        end

        local camManager = AimRuntime.CameraManager
        if not slua.isValid(camManager) then
            return
        end

        local camLoc = camManager:GetCameraLocation()
        if not camLoc then
            return
        end

        local ui_util = AimRuntime.UIUtil

        local viewportSize = ui_util.GetViewportSize()
        if not viewportSize or not viewportSize.X or viewportSize.X <= 0 then
            return
        end

        local centerX = viewportSize.X * 0.5
        local centerY = viewportSize.Y * 0.5
        local fovRadius = (fovVal / 100.0) * (viewportSize.X / 2.0)

        
        
        local now = os.clock()
        local cache = _G.LexusState.AimbotV2TargetCache
        local enemies = nil

        if cache and cache.player ~= player then
            _G.AimTouchVisCache = {}
            _G.AimTouchBotCache = {}
            cache = nil
            _G.LexusState.AimbotV2TargetCache = nil
        end

        if not cache
            or cache.pc ~= pc
            or cache.radius ~= maxDistCm
            or (now - (cache.time or 0)) >= 0.05 then

            enemies = _G.GetEnemyTargetsFromActors(maxDistCm)

            cache = {
                player = player,
                pc = pc,
                radius = maxDistCm,
                time = now,
                enemies = enemies
            }

            _G.LexusState.AimbotV2TargetCache = cache
        else
            enemies = cache.enemies
        end

        if not enemies or #enemies == 0 then
            return
        end

        _G.AimTouchVisCache = _G.AimTouchVisCache or {}
        _G.AimTouchBotCache = _G.AimTouchBotCache or {}

        local bestTarget = nil
        local bestScore = 99999999

        for _, target in ipairs(enemies) do
            if not slua.isValid(target) then
                goto continue
            end

            
            if target.HealthStatus == 1 then
                goto continue
            end

            
            
            local targetKey = GetSafeEnemyKey(target)
            local isBot = _G.AimTouchBotCache[targetKey]

            if isBot == nil then
                isBot = false

                local markData = {}
                pcall(function()
                    if _G.LexusState.EnemyMarks and _G.LexusState.EnemyMarks[targetKey] then
                        markData = _G.LexusState.EnemyMarks[targetKey]
                    end
                end)

                pcall(function()
                    local detected = false

                    if type(CheckIsAI) == "function" then
                        local result, checked = CheckIsAI(target, markData)
                        if checked and result == true then
                            detected = true
                        end
                    end

                    if target.bIsAI == true or target.IsAI == true then
                        detected = true
                    end

                    local pState = target.PlayerState
                        or (type(target.GetPlayerState) == "function" and target:GetPlayerState())

                    if slua.isValid(pState) then
                        if pState.bIsABot == true
                            or pState.bIsBot == true
                            or (type(pState.IsBot) == "function" and pState:IsBot()) then
                            detected = true
                        end
                    end

                    if type(target.IsBot) == "function" and target:IsBot() then
                        detected = true
                    end

                    isBot = detected
                end)

                _G.AimTouchBotCache[targetKey] = isBot
            end

            if isBot then
                goto continue
            end

            
            
            if useVisCheck and type(pc.LineOfSightTo) == "function" then
                local visData = _G.AimTouchVisCache[targetKey]
                if not visData or (now - (visData.time or 0)) >= 0.10 then
                    local visible = false
                    pcall(function()
                        local losResult = pc:LineOfSightTo(target)
                        visible = (losResult == true or losResult == 1)
                    end)

                    visData = {
                        visible = visible,
                        time = now
                    }

                    _G.AimTouchVisCache[targetKey] = visData
                end

                if not visData.visible then
                    goto continue
                end
            end

            
            local targetPos = nil

            pcall(function()
                targetPos = target:GetBonePos(
                    boneName,
                    {X = 0, Y = 0, Z = 0}
                )
            end)

            if not targetPos
                or (targetPos.X == 0 and targetPos.Y == 0 and targetPos.Z == 0) then
                pcall(function()
                    if type(target.GetSocketLocation) == "function" then
                        targetPos = target:GetSocketLocation(boneName)
                    end
                end)
            end

            if not targetPos
                or (targetPos.X == 0 and targetPos.Y == 0 and targetPos.Z == 0) then
                pcall(function()
                    if type(target.K2_GetActorLocation) == "function" then
                        targetPos = target:K2_GetActorLocation()
                        if targetPos then
                            targetPos.Z = targetPos.Z + 40
                        end
                    end
                end)
            end

            if not targetPos
                or (targetPos.X == 0 and targetPos.Y == 0 and targetPos.Z == 0) then
                goto continue
            end

            local screen = FVector2D()
            local success = false

            pcall(function()
                local result = pc:ProjectWorldLocationToScreen(targetPos, screen, false)
                success = (result == true or result == 1)
                    and screen.X > 0
                    and screen.Y > 0
            end)

            if not success then
                goto continue
            end

            local dx = screen.X - centerX
            local dy = screen.Y - centerY
            local screenDist = math.sqrt(dx * dx + dy * dy)

            if screenDist > fovRadius then
                goto continue
            end

            
            if screenDist < bestScore then
                bestScore = screenDist
                bestTarget = target
            end

            ::continue::
        end

        if not slua.isValid(bestTarget) then
            return
        end

        local finalBonePos = nil

        pcall(function()
            finalBonePos = bestTarget:GetBonePos(
                boneName,
                {X = 0, Y = 0, Z = 0}
            )
        end)

        if not finalBonePos
            or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            pcall(function()
                if type(bestTarget.GetSocketLocation) == "function" then
                    finalBonePos = bestTarget:GetSocketLocation(boneName)
                end
            end)
        end

        if not finalBonePos
            or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            pcall(function()
                if type(bestTarget.K2_GetActorLocation) == "function" then
                    finalBonePos = bestTarget:K2_GetActorLocation()
                    if finalBonePos then
                        finalBonePos.Z = finalBonePos.Z + 40
                    end
                end
            end)
        end

        if not finalBonePos
            or (finalBonePos.X == 0 and finalBonePos.Y == 0 and finalBonePos.Z == 0) then
            return
        end

        local rot = KismetMathLibrary.FindLookAtRotation(
            camLoc,
            finalBonePos
        )

        if not rot then
            return
        end

        local currentRot = pc:GetControlRotation()
        if not currentRot then
            return
        end

        local deltaYaw = rot.Yaw - currentRot.Yaw
        local deltaPitch = rot.Pitch - currentRot.Pitch

        
        
        if isADS then
            local camRot = nil

            pcall(function()
                if type(camManager.GetCameraRotation) == "function" then
                    camRot = camManager:GetCameraRotation()
                end
            end)

            if camRot then
                deltaYaw = deltaYaw - (camRot.Yaw - currentRot.Yaw)
                deltaPitch = deltaPitch - (camRot.Pitch - currentRot.Pitch)
            end
        end

        if deltaYaw > 180 then deltaYaw = deltaYaw - 360 end
        if deltaYaw < -180 then deltaYaw = deltaYaw + 360 end
        if deltaPitch > 180 then deltaPitch = deltaPitch - 360 end
        if deltaPitch < -180 then deltaPitch = deltaPitch + 360 end

        
        local smoothFactor = (speedVal / 100.0) * 0.2
        if smoothFactor < 0.01 then
            smoothFactor = 0.01
        end

        local finalPitch = currentRot.Pitch + (deltaPitch * smoothFactor)
        local finalYaw = currentRot.Yaw + (deltaYaw * smoothFactor)

        local finalRot = {
            Pitch = finalPitch,
            Yaw = finalYaw,
            Roll = 0
        }

        pc:SetControlRotation(finalRot, "AimbotV2")
    end)
end


_G.AimTouch = _G.AimbotV2







local ItemDatabase = {
    
    [101001] = { name = "AKM", cat = "AR", color = C_AR }, [101002] = { name = "M16A4", cat = "AR", color = C_AR },
    [101003] = { name = "SCAR-L", cat = "AR", color = C_AR }, [101004] = { name = "M416", cat = "AR", color = C_AR },
    [101005] = { name = "Groza", cat = "AR", color = C_AR }, [101006] = { name = "AUG", cat = "AR", color = C_AR },
    [101007] = { name = "QBZ", cat = "AR", color = C_AR }, [101008] = { name = "M762", cat = "AR", color = C_AR },
    [101009] = { name = "Mk47 Mutant", cat = "AR", color = C_AR }, [101010] = { name = "G36C", cat = "AR", color = C_AR },
    [101011] = { name = "AC-VAL", cat = "AR", color = C_AR }, [101012] = { name = "Honey Badger", cat = "AR", color = C_AR },
    [101100] = { name = "FAMAS", cat = "AR", color = C_AR }, [101101] = { name = "ASM Abakan AR", cat = "AR", color = C_AR },
    [101102] = { name = "ACE32", cat = "AR", color = C_AR },
    
    [102001] = { name = "UZI", cat = "SMG", color = C_SMG }, [102002] = { name = "UMP45", cat = "SMG", color = C_SMG },
    [102003] = { name = "Vector", cat = "SMG", color = C_SMG }, [102004] = { name = "Thompson SMG", cat = "SMG", color = C_SMG },
    [102005] = { name = "PP-19 Bizon", cat = "SMG", color = C_SMG }, [102007] = { name = "MP5K", cat = "SMG", color = C_SMG },
    [102008] = { name = "JS9", cat = "SMG", color = C_SMG }, [102105] = { name = "P90", cat = "SMG", color = C_SMG },
    
    [103001] = { name = "Kar98K", cat = "Sniper", color = C_Sniper }, [103002] = { name = "M24", cat = "Sniper", color = C_Sniper },
    [103003] = { name = "AWM", cat = "Sniper", color = C_Sniper }, [103004] = { name = "SKS", cat = "Sniper", color = C_Sniper },
    [103005] = { name = "VSS", cat = "Sniper", color = C_Sniper }, [103006] = { name = "Mini14", cat = "Sniper", color = C_Sniper },
    [103007] = { name = "Mk14", cat = "Sniper", color = C_Sniper }, [103008] = { name = "Win94", cat = "Sniper", color = C_Sniper },
    [103009] = { name = "SLR", cat = "Sniper", color = C_Sniper }, [103010] = { name = "QBU", cat = "Sniper", color = C_Sniper },
    [103011] = { name = "Mosin Nagant", cat = "Sniper", color = C_Sniper }, [103012] = { name = "AMR", cat = "Sniper", color = C_Sniper },
    [103100] = { name = "Mk12", cat = "Sniper", color = C_Sniper }, [103101] = { name = "TR-2A Air Gun", cat = "Sniper", color = C_Sniper },
    [103102] = { name = "DSR", cat = "Sniper", color = C_Sniper }, [103103] = { name = "Sniper Rifle", cat = "Sniper", color = C_Sniper },
    [103104] = { name = "Sniper Rifle", cat = "Sniper", color = C_Sniper }, [103105] = { name = "SR", cat = "Sniper", color = C_Sniper },
    
    [104001] = { name = "S686", cat = "Shotgun", color = C_Shotgun }, [104002] = { name = "S1897", cat = "Shotgun", color = C_Shotgun },
    [104003] = { name = "S12K", cat = "Shotgun", color = C_Shotgun }, [104004] = { name = "DBS", cat = "Shotgun", color = C_Shotgun },
    [104100] = { name = "SPAS-12", cat = "Shotgun", color = C_Shotgun }, [104101] = { name = "M1014", cat = "Shotgun", color = C_Shotgun },
    [104102] = { name = "NS2000", cat = "Shotgun", color = C_Shotgun },
    
    [105001] = { name = "M249", cat = "LMG", color = C_LMG }, [105002] = { name = "DP-28", cat = "LMG", color = C_LMG },
    [105003] = { name = "M134", cat = "LMG", color = C_LMG }, [105010] = { name = "MG3", cat = "LMG", color = C_LMG },
    [105101] = { name = "Gatling", cat = "LMG", color = C_LMG }, [105115] = { name = "Lib Gatling MG", cat = "LMG", color = C_LMG },
    [105004] = { name = "Flamethrower", cat = "LMG", color = C_LMG }, [105006] = { name = "M2 Fixed MG", cat = "LMG", color = C_LMG },
    [105007] = { name = "Gatling Fixed MG", cat = "LMG", color = C_LMG }, [105008] = { name = "Mounted Flamethrower", cat = "LMG", color = C_LMG },
    [105009] = { name = "M2 Mounted MG", cat = "LMG", color = C_LMG }, [105102] = { name = "Vehicle SG", cat = "LMG", color = C_LMG },
    [105103] = { name = "RPG", cat = "LMG", color = C_LMG }, [105104] = { name = "RPG", cat = "LMG", color = C_LMG },
    [105105] = { name = "PowPow MG", cat = "LMG", color = C_LMG }, [105106] = { name = "Tank Cannon", cat = "LMG", color = C_LMG },
    [105107] = { name = "Tank MG", cat = "LMG", color = C_LMG }, [105108] = { name = "Tank Flare Gun", cat = "LMG", color = C_LMG },
    [105116] = { name = "Lib Autocannon", cat = "LMG", color = C_LMG }, [105117] = { name = "Jet Missile", cat = "LMG", color = C_LMG },
    [105118] = { name = "Jet Autocannon", cat = "LMG", color = C_LMG },
    
    [106001] = { name = "P92", cat = "Pistol", color = C_Pistol }, [106002] = { name = "P1911", cat = "Pistol", color = C_Pistol },
    [106003] = { name = "R1895", cat = "Pistol", color = C_Pistol }, [106004] = { name = "P18C", cat = "Pistol", color = C_Pistol },
    [106005] = { name = "R45", cat = "Pistol", color = C_Pistol }, [106006] = { name = "Sawed-off", cat = "Pistol", color = C_Pistol },
    [106008] = { name = "Skorpion", cat = "Pistol", color = C_Pistol }, [106010] = { name = "Desert Eagle", cat = "Pistol", color = C_Pistol },
    [106007] = { name = "Flare Gun", cat = "Pistol", color = C_Pistol }, [106009] = { name = "Flare Gun", cat = "Pistol", color = C_Pistol },
    [106011] = { name = "Dual MP7", cat = "Pistol", color = C_Pistol }, [106012] = { name = "Welding Gun", cat = "Pistol", color = C_Pistol },
    [106013] = { name = "Stun Gun", cat = "Pistol", color = C_Pistol }, [106101] = { name = "Vehicle Flare", cat = "Pistol", color = C_Pistol },
    [106103] = { name = "Flare Gun", cat = "Pistol", color = C_Pistol }, [106106] = { name = "Flare (Empty)", cat = "Pistol", color = C_Pistol },
    [106107] = { name = "Respawn Flare", cat = "Pistol", color = C_Pistol }, [106203] = { name = "Magnet Gun", cat = "Pistol", color = C_Pistol },
    
    [107001] = { name = "Crossbow", cat = "Special", color = C_Special }, [107002] = { name = "RPG-7", cat = "Special", color = C_Special },
    [107003] = { name = "Riot shield", cat = "Special", color = C_Special }, [107004] = { name = "Combat Drone", cat = "Special", color = C_Special },
    [107005] = { name = "Panzerfaust", cat = "Special", color = C_Special }, [107006] = { name = "RPG-7", cat = "Special", color = C_Special },
    [107007] = { name = "Tactical Crossbow", cat = "Special", color = C_Special }, [107008] = { name = "Explosive Bow", cat = "Special", color = C_Special },
    [107009] = { name = "Explosive Bow", cat = "Special", color = C_Special }, [107010] = { name = "M79 Smoke Launcher", cat = "Special", color = C_Special },
    [107019] = { name = "Atlas Gauntlet", cat = "Special", color = C_Special }, [107020] = { name = "Explosive Crossbow", cat = "Special", color = C_Special },
    [107021] = { name = "Mercury Hammer", cat = "Special", color = C_Special }, [107022] = { name = "Fishbones Rocket", cat = "Special", color = C_Special },
    [107031] = { name = "Summer Grenade Launcher", cat = "Special", color = C_Special }, [107032] = { name = "Summer Bazooka", cat = "Special", color = C_Special },
    [107033] = { name = "Summer MG", cat = "Special", color = C_Special }, [107034] = { name = "Color Bazooka", cat = "Special", color = C_Special },
    [107035] = { name = "Bubble MG", cat = "Special", color = C_Special }, [107036] = { name = "Snowball Blaster", cat = "Special", color = C_Special },
    [107037] = { name = "Water Orb Blaster", cat = "Special", color = C_Special }, [107092] = { name = "MGL", cat = "Special", color = C_Special },
    [107093] = { name = "M202 Quad RPG", cat = "Special", color = C_Special }, [107094] = { name = "AT4-A Laser Missile", cat = "Special", color = C_Special },
    [107095] = { name = "M202 Quad RPG", cat = "Special", color = C_Special }, [107096] = { name = "M79 Sawed-off", cat = "Special", color = C_Special },
    [107097] = { name = "M79", cat = "Special", color = C_Special }, [107098] = { name = "MGL", cat = "Special", color = C_Special },
    [107099] = { name = "M3E1-A", cat = "Special", color = C_Special }, [107901] = { name = "Zombie Piercer", cat = "Special", color = C_Special },
    [107903] = { name = "Mounted RPG", cat = "Special", color = C_Special }, [107904] = { name = "Helicopter RPG", cat = "Special", color = C_Special },
    [107911] = { name = "M3E1-B Missile", cat = "Special", color = C_Special },
    
    [108001] = { name = "Machete", cat = "Melee", color = C_Melee }, [108002] = { name = "Crowbar", cat = "Melee", color = C_Melee },
    [108003] = { name = "Sickle", cat = "Melee", color = C_Melee }, [108004] = { name = "Pan", cat = "Melee", color = C_Melee },
    [108005] = { name = "Dagger", cat = "Melee", color = C_Melee }, [108006] = { name = "Mutation Blade", cat = "Melee", color = C_Melee },
    [108007] = { name = "Mutation Gauntlets", cat = "Melee", color = C_Melee },
    
    [203001] = { name = "Red Dot Sight", cat = "Scope", color = C_Scope }, [203002] = { name = "Holographic Sight", cat = "Scope", color = C_Scope },
    [203003] = { name = "2x Scope", cat = "Scope", color = C_Scope }, [203004] = { name = "4x Scope", cat = "Scope", color = C_Scope },
    [203005] = { name = "8x Scope", cat = "Scope", color = C_Scope }, [203014] = { name = "3x Scope", cat = "Scope", color = C_Scope },
    [203015] = { name = "6x Scope", cat = "Scope", color = C_Scope },
    
    [602001] = { name = "Stun Grenade", cat = "Grenade", color = C_Grenade }, [602002] = { name = "Smoke Grenade", cat = "Grenade", color = C_Grenade },
    [602003] = { name = "Molotov", cat = "Grenade", color = C_Grenade }, [602004] = { name = "Frag Grenade", cat = "Grenade", color = C_Grenade },
    
    
    [601001] = { name = "Nước Tăng Lực", cat = "Med", color = C_Med }, [601002] = { name = "Tiêm Adrenaline", cat = "Med", color = C_Med },
    [601003] = { name = "Thuốc Giảm Đau", cat = "Med", color = C_Med }, [601004] = { name = "Băng Gạc", cat = "Med", color = C_Med },
    [601005] = { name = "Bộ Sơ Cứu", cat = "Med", color = C_Med }, [601006] = { name = "Bộ Cứu Thương", cat = "Med", color = C_Med },
    [601009] = { name = "Băng Gạc Nhanh", cat = "Med", color = C_Med }, [601010] = { name = "Sơ Cứu Nhanh", cat = "Med", color = C_Med },
    [601011] = { name = "Băng Gạc QĐ", cat = "Med", color = C_Med }, [601012] = { name = "Nước Đậm Đặc", cat = "Med", color = C_Med },
    [601020] = { name = "Băng Gạc", cat = "Med", color = C_Med }, [601021] = { name = "Bộ Sơ Cứu", cat = "Med", color = C_Med },
    [601022] = { name = "Bộ Cứu Thương", cat = "Med", color = C_Med }, [601023] = { name = "Tiêm Adrenaline", cat = "Med", color = C_Med },
    [601061] = { name = "Bộ Cứu Thương", cat = "Med", color = C_Med }, [601077] = { name = "Sơ Cứu Chiến Thuật", cat = "Med", color = C_Med },
    [601078] = { name = "Sơ Cứu Toàn Năng", cat = "Med", color = C_Med }, [601079] = { name = "Cứu Thương Toàn Năng", cat = "Med", color = C_Med },
    [601080] = { name = "Băng Gạc QĐ", cat = "Med", color = C_Med }, [601081] = { name = "Nước Đậm Đặc", cat = "Med", color = C_Med },
    [601084] = { name = "Sơ Cứu Nhanh", cat = "Med", color = C_Med }, [601085] = { name = "Cứu Thương Nhanh", cat = "Med", color = C_Med },
    [601095] = { name = "Máy AED (Hồi Sinh)", cat = "Med", color = C_Med }, [601096] = { name = "Chuẩn Bị Chiến Đấu", cat = "Med", color = C_Med },
    [602054] = { name = "Tiếp Tế Y Tế", cat = "Med", color = C_Med }, [602069] = { name = "Cứu Trợ Khẩn Cấp", cat = "Med", color = C_Med }
}

_G.CachedItems = {}
_G.LastScanItemTime = 0
_G.AppliedItemESP = {}

_G.RunOptimizedItemESP = function(pc)
    local curTime = os.clock()

    
    if curTime - _G.LastScanItemTime > 1.0 then
        _G.LastScanItemTime = curTime
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end

        


        
        if _G.LexusConfig.EspItem_Master then
            local APickUpWrapperActor = import("PickUpWrapperActor") or import("STPickupWrapperActor")
            if APickUpWrapperActor then
                local Actors = Game:GetActorsByClass(APickUpWrapperActor)
                _G.CachedItems = {}
                if Actors then
                    local count = Actors:Num() or 0
                    for i = 0, count - 1 do
                        local item = Actors:Get(i)
                        if slua.isValid(item) then
                            local dist = player:GetDistanceTo(item)
                            local itemId = item.DefineID and item.DefineID.TypeSpecificID or item.DefineId
                            local itemData = ItemDatabase[itemId]
                            local isFlare = itemData and itemData.name == "Flare Gun"
                            if (isFlare and dist <= 2000000) or ((not isFlare) and dist <= 7000) then
                                if itemData then
                                    local itemSelectKey = itemData.cat .. ":" .. itemData.name
                                    local isShow = _G.LexusConfig.EspItem_Selected[itemSelectKey] == true

                                    
                                    if isShow then
                                        table.insert(_G.CachedItems, item)

                                        local iId = tostring(item)
                                        if not _G.AppliedItemESP[iId] then
                                            local meshes = {}
                                            if item.GetPickupMesh then
                                                local pMesh = item:GetPickupMesh()
                                                if slua.isValid(pMesh) then table.insert(meshes, pMesh) end
                                            end
                                            local childs = item:GetComponentsByClass(import("StaticMeshComponent"))
                                            if childs then
                                                for _, v in pairs(childs) do
                                                    if slua.isValid(v) then table.insert(meshes, v) end
                                                end
                                            end
                                            for _, mesh in pairs(meshes) do
                                                pcall(function() mesh:SetRenderCustomDepth(true) end)
                                                for mi = 0, 8 do
                                                    local mid = mesh:CreateAndSetMaterialInstanceDynamic(mi)
                                                    if slua.isValid(mid) then
                                                        local colorVisible = {R = 50, G = 50, B = 0, A = 10}
                                                        pcall(function()
                                                            mid:SetVectorParameterValue("LightColor", colorVisible)
                                                            mid:SetVectorParameterValue("ParaScaleOffset", {R = 3, G = 3, B = 0, A = 0})
                                                            mid:SetScalarParameterValue("RimLight", 999)
                                                            mid:SetScalarParameterValue("Brightness", 999)
                                                            mid:SetScalarParameterValue("Exposure", 999)
                                                        end)
                                                    end
                                                end
                                            end
                                            _G.AppliedItemESP[iId] = item
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else 
            _G.AppliedItemESP = {}
            _G.CachedItems = {}
        end
    end

    
    if _G.LexusConfig.EspItem_Master and slua.isValid(pc) and pc.MyHUD then
        local hud = pc.MyHUD
        local player = GameplayData.GetPlayerCharacter()
        for _, item in ipairs(_G.CachedItems) do
            if slua.isValid(item) then
                local itemId = item.DefineID and item.DefineID.TypeSpecificID or item.DefineId
                if itemId and ItemDatabase[itemId] then
                    local itemData = ItemDatabase[itemId]
                    local dist = (player.GetDistanceTo and player:GetDistanceTo(item) or 0) / 100
                    local displayText = string.format("%s [%.0f m]", itemData.name, dist)
                    local textColor = {R = itemData.color.R, G = itemData.color.G, B = itemData.color.B, A = 255}
                    hud:AddDebugText(
                        displayText, item, 0.06, 
                        {X=0, Y=0, Z=50}, {X=0, Y=0, Z=50}, 
                        textColor, true, false, true, nil, 0.8, true
                    )
                end
            end
        end
    end
end









_G.BoxESP = (function()
    local SlateBlueprintLibrary = nil
    local WidgetLayoutLibrary = nil
    local FVector2D = nil
    local FVector = nil
    local FLinearColor = nil
    local FSlateColor = nil

    pcall(function()
        SlateBlueprintLibrary = import("SlateBlueprintLibrary") or import("/Script/UMG.SlateBlueprintLibrary")
        WidgetLayoutLibrary = import("WidgetLayoutLibrary") or import("/Script/UMG.WidgetLayoutLibrary")
        FVector2D = import("Vector2D")
        FVector = import("Vector")
        FLinearColor = import("LinearColor")
        FSlateColor = import("SlateColor") or import("/Script/SlateCore.SlateColor")
    end)

    local function IsValid(obj)
        if not obj then return false end
        if slua and slua.isValid then
            return slua.isValid(obj)
        end
        return true
    end

    local TempProjVec2D = FVector2D and FVector2D(0, 0) or nil
    local ColorWhite = FLinearColor and FLinearColor(1.0, 1.0, 1.0, 1.0) or nil
    local ColorRed = FLinearColor and FLinearColor(1.0, 0.15, 0.15, 1.0) or nil
    local ColorGreen = FLinearColor and FLinearColor(0.0, 1.0, 0.05, 1.0) or nil
    local ColorYellow = FLinearColor and FLinearColor(1.0, 0.95, 0.0, 1.0) or nil
    local ColorBlue = FLinearColor and FLinearColor(0.18, 0.62, 1.0, 1.0) or nil

    local SlateColorRed = (FSlateColor and ColorRed) and FSlateColor(ColorRed) or ColorRed
    local SlateColorGreen = (FSlateColor and ColorGreen) and FSlateColor(ColorGreen) or ColorGreen

    
    local ENEMY_COUNTER_PLAYER_URLS = {
    }
    local ENEMY_COUNTER_BOT_URLS = {
    }
    local EnemyCounterTextureCache = {}
    
    local BADGE_WIDTH = 106
    local BADGE_HEIGHT = 28
    local BADGE_GAP = 3
    local COUNTER_ICON_SIZE = 18

    local function FileExists(path)
        if not path or path == "" then return false end
        local f = io.open(path, "r")
        if f then f:close() return true end
        return false
    end

    local function GetPossibleLocalPaths(filename)
        return {
            "/storage/emulated/0/Android/data/com.tencent.ig/files/" .. filename,
            "/storage/emulated/0/Android/data/com.pubg.krmobile/files/" .. filename,
            "/storage/emulated/0/Android/data/com.vng.pubgmobile/files/" .. filename,
            "/storage/emulated/0/Android/data/com.rekoo.pubgm/files/" .. filename,
            "/storage/emulated/0/Android/data/com.tencent.tmgp.pubgmhd/files/" .. filename,
            filename
        }
    end

    local function LoadBadgeTexture(imgWidget, urls, filename, typeKey, counterData)
        if not imgWidget or not IsValid(imgWidget) then return end

        if EnemyCounterTextureCache[typeKey] and IsValid(EnemyCounterTextureCache[typeKey]) then
            pcall(function()
                imgWidget:SetBrushFromTexture(EnemyCounterTextureCache[typeKey], false)
                imgWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end)
            if counterData then
                if typeKey == "Player" then counterData.PlayerLoaded = true end
                if typeKey == "Bot" then counterData.BotLoaded = true end
            end
            return
        end

        local function applyTex(tex)
            if tex and IsValid(tex) and IsValid(imgWidget) then
                EnemyCounterTextureCache[typeKey] = tex
                if counterData then
                    if typeKey == "Player" then counterData.PlayerLoaded = true end
                    if typeKey == "Bot" then counterData.BotLoaded = true end
                end
                pcall(function()
                    imgWidget:SetBrushFromTexture(tex, false)
                    imgWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                end)
                return true
            end
            return false
        end

        local localPaths = GetPossibleLocalPaths(filename)
        for _, localPath in ipairs(localPaths) do
            if FileExists(localPath) then
                local tex = nil
                pcall(function()
                    local asset_util = package.loaded["common.asset_util"] or require("common.asset_util")
                    if asset_util and asset_util.GetAssetSync then tex = asset_util.GetAssetSync(localPath) end
                end)
                if not tex then
                    pcall(function() if CGame and CGame.LoadObject then tex = CGame:LoadObject(localPath) end end)
                end
                if tex and applyTex(tex) then return end
            end
        end

        local function tryDownloadUrl(urlIndex)
            if urlIndex > #urls then return end
            local url = urls[urlIndex]
            local bDownloaded = false

            pcall(function()
                local AsyncTaskDownloadImage = import("AsyncTaskDownloadImage") or import("/Script/UMG.AsyncTaskDownloadImage")
                if AsyncTaskDownloadImage and AsyncTaskDownloadImage.DownloadImage then
                    local task = AsyncTaskDownloadImage.DownloadImage(url)
                    if task and task.OnSuccess then
                        task.OnSuccess:Add(function(tex)
                            if not bDownloaded and tex then
                                bDownloaded = true
                                applyTex(tex)
                            end
                        end)
                        if task.OnFail then
                            task.OnFail:Add(function()
                                if not bDownloaded then tryDownloadUrl(urlIndex + 1) end
                            end)
                        end
                    end
                end
            end)

            if not bDownloaded then
                pcall(function()
                    local mm = _G.ModuleManager or package.loaded["GameLua.GameCore.Module.ModuleManager"]
                    if not mm then pcall(function() mm = require("GameLua.GameCore.Module.ModuleManager") end) end
                    local imgMgr = nil
                    if mm and mm.GetModule and mm.CommonModuleConfig then
                        imgMgr = mm.GetModule(mm.CommonModuleConfig.image_download_mgr)
                    end
                    if not imgMgr then pcall(function() imgMgr = require("client.slua.logic.image_download.image_download_mgr") end) end
                    if imgMgr and imgMgr.DownloadImageByHttpWrapper then
                        imgMgr:DownloadImageByHttpWrapper(url, function(tex)
                            if not bDownloaded and tex then bDownloaded = true; applyTex(tex) end
                        end, function()
                            if not bDownloaded then tryDownloadUrl(urlIndex + 1) end
                        end)
                    end
                end)
            end

            if not bDownloaded then
                pcall(function()
                    local util = package.loaded["client.slua_ui_framework.util"]
                    if not util then pcall(function() util = require("client.slua_ui_framework.util") end) end
                    if util and util.SetTexture then
                        util.SetTexture(imgWidget, url, {
                            sync = false,
                            onDownloadSuccess = function(tex)
                                if not bDownloaded and tex then bDownloaded = true; applyTex(tex) end
                            end
                        })
                    end
                end)
            end
        end

        tryDownloadUrl(1)
    end

    
    local BoxESP = {
        bActive = false,
        bShowLines = true,
        bShowCounter = true,
        ESPCanvas = nil,
        BoxWidgets = {},
        LineWidgets = {},

        CounterData = {
            BgPlayer = nil,
            SlotBgPlayer = nil,
            BgBot = nil,
            SlotBgBot = nil,
            ImgPlayer = nil,
            SlotPlayer = nil,
            ImgBot = nil,
            SlotBot = nil,
            TxtPlayer = nil,
            SlotTxtPlayer = nil,
            TxtBot = nil,
            SlotTxtBot = nil,
            LastPlayerCount = -1,
            LastBotCount = -1,
            PlayerLoaded = false,
            BotLoaded = false,
            LastDownloadRetry = 0,
            bCreated = false
        },

        HealthColor = { R = 0.0, G = 1.0, B = 0.0, A = 1.0 },
        HealthBgColor = { R = 0.0, G = 0.0, B = 0.0, A = 0.85 },
        HealthBarWidth = 2.0,
        CornerColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 },
        CornerThickness = 1.0,
        CornerLengthRatio = 0.28,
        SnapLineThickness = 1.0,
        SnapLineOriginY = 48, 


        _CanvasScaleX = 1.0,
        _CanvasScaleY = 1.0,
        _CanvasOffsetX = 0.0,
        _CanvasOffsetY = 0.0,
        _LastCanvas = nil,
        _LastTransformTime = 0,
        _LastHeavyUpdateTime = 0,
        _LastVisCheckTime = 0,
        _VisCheckCache = {}
    }

    function BoxESP.GetMainCanvas()
        if BoxESP.ESPCanvas and IsValid(BoxESP.ESPCanvas) then
            return BoxESP.ESPCanvas
        end

        local InGameUITools = package.loaded["GameLua.Mod.BaseMod.Common.UI.InGameUITools"]
        if not InGameUITools then
            pcall(function() InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools") end)
        end
        if not InGameUITools then return nil end

        local MainUI = nil
        if InGameUITools.GetMainControlBaseUI then
            MainUI = InGameUITools.GetMainControlBaseUI()
        end
        if not IsValid(MainUI) then return nil end

        local ParentCanvas = nil
        if MainUI.CanvasPanel_0 and IsValid(MainUI.CanvasPanel_0) then
            ParentCanvas = MainUI.CanvasPanel_0
        elseif MainUI.CanvasPanel_42 and IsValid(MainUI.CanvasPanel_42) then
            ParentCanvas = MainUI.CanvasPanel_42
        end

        if ParentCanvas then
            BoxESP.ESPCanvas = ParentCanvas
            BoxESP._LastCanvas = ParentCanvas
        end
        return ParentCanvas
    end

    function BoxESP.CreateESPWidget(ParentCanvas)
        if not FLinearColor or not FVector2D then return nil end

        local CornerContainer = CGame:NewObjectFromPath("/Script/UMG.CanvasPanel", ParentCanvas)
        if not IsValid(CornerContainer) then return nil end

        local CornerMainSlot = ParentCanvas:AddChildToCanvas(CornerContainer)
        if not CornerMainSlot then return nil end

        CornerMainSlot:SetAutoSize(false)
        CornerMainSlot:SetZOrder(995)
        CornerMainSlot:SetAlignment(FVector2D(0.5, 0.5))

        local whiteColor = FLinearColor(
            BoxESP.CornerColor.R,
            BoxESP.CornerColor.G,
            BoxESP.CornerColor.B,
            BoxESP.CornerColor.A
        )

        local function CreateBorderLine()
            local border = CGame:NewObjectFromPath("/Script/UMG.Border", CornerContainer)
            if border and IsValid(border) then
                border:SetBrushColor(whiteColor)
                border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                local slot = CornerContainer:AddChildToCanvas(border)
                if slot then slot:SetAutoSize(false) end
                return { widget = border, slot = slot }
            end
            return nil
        end

        local CornerLines = {
            TopLeft_H = CreateBorderLine(),
            TopLeft_V = CreateBorderLine(),
            TopRight_H = CreateBorderLine(),
            TopRight_V = CreateBorderLine(),
            BottomLeft_H = CreateBorderLine(),
            BottomLeft_V = CreateBorderLine(),
            BottomRight_H = CreateBorderLine(),
            BottomRight_V = CreateBorderLine()
        }

        local BgImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
        if not IsValid(BgImage) then return nil end
        BgImage:SetColorAndOpacity(FLinearColor(BoxESP.HealthBgColor.R, BoxESP.HealthBgColor.G, BoxESP.HealthBgColor.B, BoxESP.HealthBgColor.A))
        BgImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

        local BgSlot = ParentCanvas:AddChildToCanvas(BgImage)
        if not BgSlot then return nil end
        BgSlot:SetAutoSize(false)
        BgSlot:SetZOrder(998)
        BgSlot:SetAlignment(FVector2D(0.5, 1.0))

        local HealthImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
        if not IsValid(HealthImage) then return nil end
        HealthImage:SetColorAndOpacity(FLinearColor(BoxESP.HealthColor.R, BoxESP.HealthColor.G, BoxESP.HealthColor.B, BoxESP.HealthColor.A))
        HealthImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

        local HealthSlot = ParentCanvas:AddChildToCanvas(HealthImage)
        if not HealthSlot then return nil end
        HealthSlot:SetAutoSize(false)
        HealthSlot:SetZOrder(999)
        HealthSlot:SetAlignment(FVector2D(0.5, 1.0))

        local function CreateStyledTextBlock(defaultColor, fontSize, alignment)
            local txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas)
            local slot = nil
            if txt and IsValid(txt) then
                txt:SetText("")
                local intSize = math.floor(fontSize or 10)
                if txt.Font then
                    local newFont = txt.Font
                    newFont.Size = intSize
                    if newFont.OutlineSettings then
                        newFont.OutlineSettings.OutlineSize = 1
                        newFont.OutlineSettings.OutlineColor = FLinearColor(0.0, 0.0, 0.0, 1.0)
                    end
                    if txt.SetFont then txt:SetFont(newFont) else txt.Font = newFont end
                end

                if txt.SetFontSize then txt:SetFontSize(intSize) end
                txt:SetJustification(1)
                if txt.SetHorizontalAlignment then txt:SetHorizontalAlignment(1) end
                if txt.SetVerticalAlignment then txt:SetVerticalAlignment(1) end
                if txt.SetAutoWrapText then txt:SetAutoWrapText(false) end

                if FSlateColor then
                    txt:SetColorAndOpacity(FSlateColor(defaultColor))
                else
                    txt:SetColorAndOpacity(defaultColor)
                end

                if txt.SetShadowOffset then txt:SetShadowOffset(FVector2D(0.0, 0.0)) end
                if txt.SetShadowColorAndOpacity then txt:SetShadowColorAndOpacity(FLinearColor(0.0, 0.0, 0.0, 0.0)) end
                txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)

                slot = ParentCanvas:AddChildToCanvas(txt)
                if slot then
                    slot:SetAutoSize(true)
                    slot:SetZOrder(1000)
                    slot:SetAlignment(alignment or FVector2D(0.5, 0.0))
                end
            end
            return txt, slot
        end

        local WeaponWidget, WeaponSlot = CreateStyledTextBlock(ColorYellow, 10, FVector2D(0.5, 1.0))
        local NameWidget, NameSlot = CreateStyledTextBlock(ColorBlue, 10, FVector2D(0.5, 0.0))
        local DistWidget, DistSlot = CreateStyledTextBlock(ColorWhite, 10, FVector2D(0.5, 0.0))
        local StateWidget, StateSlot = CreateStyledTextBlock(ColorGreen, 10, FVector2D(0.5, 0.0))

        local FlagImage = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
        local FlagSlot = nil
        if FlagImage and IsValid(FlagImage) then
            FlagImage:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            FlagSlot = ParentCanvas:AddChildToCanvas(FlagImage)
            if FlagSlot then
                FlagSlot:SetAutoSize(false)
                FlagSlot:SetSize(FVector2D(14, 16))
                FlagSlot:SetZOrder(1000)
                FlagSlot:SetAlignment(FVector2D(0.5, 1.0))
            end
        end

        return {
            CornerContainer = CornerContainer,
            CornerSlot = CornerMainSlot,
            Corners = CornerLines,
            BgWidget = BgImage,
            BgSlot = BgSlot,
            HealthWidget = HealthImage,
            HealthSlot = HealthSlot,
            WeaponWidget = WeaponWidget,
            WeaponSlot = WeaponSlot,
            FlagWidget = FlagImage,
            FlagSlot = FlagSlot,
            NameWidget = NameWidget,
            NameSlot = NameSlot,
            DistWidget = DistWidget,
            DistSlot = DistSlot,
            StateWidget = StateWidget,
            StateSlot = StateSlot,
            _cachedWeapon = "",
            _cachedNation = nil,
            _cachedName = "",
            _cachedDist = "",
            _cachedState = "",
            _cachedIsCover = false,
            _cachedIsKnocked = false,
            _lastScanTime = 0,
            lastW = 0,
            lastH = 0,
            bVisible = true
        }
    end

    function BoxESP.UpdateCornerDimensions(boxData, width, height)
        if boxData.lastW and boxData.lastH then
            if math.abs(width - boxData.lastW) < 1.5 and math.abs(height - boxData.lastH) < 1.5 then
                return
            end
        end
        boxData.lastW = width
        boxData.lastH = height

        local t = BoxESP.CornerThickness
        local cLen = math.max(7, math.min(width, height) * BoxESP.CornerLengthRatio)
        local C = boxData.Corners

        boxData.CornerSlot:SetSize(FVector2D(width, height))

        if C.TopLeft_H and C.TopLeft_H.slot then
            C.TopLeft_H.slot:SetPosition(FVector2D(0, 0))
            C.TopLeft_H.slot:SetSize(FVector2D(cLen, t))
        end
        if C.TopLeft_V and C.TopLeft_V.slot then
            C.TopLeft_V.slot:SetPosition(FVector2D(0, 0))
            C.TopLeft_V.slot:SetSize(FVector2D(t, cLen))
        end

        if C.TopRight_H and C.TopRight_H.slot then
            C.TopRight_H.slot:SetPosition(FVector2D(width - cLen, 0))
            C.TopRight_H.slot:SetSize(FVector2D(cLen, t))
        end
        if C.TopRight_V and C.TopRight_V.slot then
            C.TopRight_V.slot:SetPosition(FVector2D(width - t, 0))
            C.TopRight_V.slot:SetSize(FVector2D(t, cLen))
        end

        if C.BottomLeft_H and C.BottomLeft_H.slot then
            C.BottomLeft_H.slot:SetPosition(FVector2D(0, height - t))
            C.BottomLeft_H.slot:SetSize(FVector2D(cLen, t))
        end
        if C.BottomLeft_V and C.BottomLeft_V.slot then
            C.BottomLeft_V.slot:SetPosition(FVector2D(0, height - cLen))
            C.BottomLeft_V.slot:SetSize(FVector2D(t, cLen))
        end

        if C.BottomRight_H and C.BottomRight_H.slot then
            C.BottomRight_H.slot:SetPosition(FVector2D(width - cLen, height - t))
            C.BottomRight_H.slot:SetSize(FVector2D(cLen, t))
        end
        if C.BottomRight_V and C.BottomRight_V.slot then
            C.BottomRight_V.slot:SetPosition(FVector2D(width - t, height - cLen))
            C.BottomRight_V.slot:SetSize(FVector2D(t, cLen))
        end
    end

    function BoxESP.UpdateCanvasTransform(PC)
        if not BoxESP.ESPCanvas or not IsValid(BoxESP.ESPCanvas) then return end

        local success = false
        if SlateBlueprintLibrary and SlateBlueprintLibrary.AbsoluteToLocal then
            local cg = BoxESP.ESPCanvas:GetCachedGeometry()
            if cg then
                local pt0 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(0, 0))
                local pt1 = SlateBlueprintLibrary.AbsoluteToLocal(cg, FVector2D(100, 100))
                if pt0 and pt1 then
                    BoxESP._CanvasScaleX = (pt1.X - pt0.X) / 100
                    BoxESP._CanvasScaleY = (pt1.Y - pt0.Y) / 100
                    BoxESP._CanvasOffsetX = pt0.X
                    BoxESP._CanvasOffsetY = pt0.Y
                    success = true
                end
            end
        end

        if not success and WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
            local scale = WidgetLayoutLibrary.GetViewportScale(PC) or 1.0
            BoxESP._CanvasScaleX = 1.0 / scale
            BoxESP._CanvasScaleY = 1.0 / scale
            BoxESP._CanvasOffsetX = 0
            BoxESP._CanvasOffsetY = 0
        end
    end

    function BoxESP.ProjectWorldToCanvasLocal(PC, WorldLoc)
        if not IsValid(PC) or not WorldLoc or not TempProjVec2D then return false, 0, 0 end

        local res = PC:ProjectWorldLocationToScreen(WorldLoc, TempProjVec2D, true)
        if (res == true or res == 1) and (TempProjVec2D.X ~= 0 or TempProjVec2D.Y ~= 0) then
            local finalX = TempProjVec2D.X * BoxESP._CanvasScaleX + BoxESP._CanvasOffsetX
            local finalY = TempProjVec2D.Y * BoxESP._CanvasScaleY + BoxESP._CanvasOffsetY
            return true, finalX, finalY
        end
        return false, 0, 0
    end

    
    function BoxESP.GetSnapLineStartPos(PC, ParentCanvas)
        local screenPixelW, screenPixelH = 0, 0
        local scale = 1.0

        pcall(function()
            if PC and PC.GetViewportSize then
                local vs = FVector2D(0, 0)
                PC:GetViewportSize(vs)
                if vs and vs.X and vs.X > 200 then
                    screenPixelW = vs.X
                    screenPixelH = vs.Y
                end
            end
        end)

        if screenPixelW <= 200 then
            pcall(function()
                if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportSize then
                    local vs = WidgetLayoutLibrary.GetViewportSize(PC)
                    if vs and vs.X and vs.X > 200 then
                        screenPixelW = vs.X
                        screenPixelH = vs.Y
                    end
                end
            end)
        end

        pcall(function()
            if WidgetLayoutLibrary and WidgetLayoutLibrary.GetViewportScale then
                local s = WidgetLayoutLibrary.GetViewportScale(PC)
                if s and type(s) == "number" and s > 0 then scale = s end
            end
        end)

        if screenPixelW <= 200 then
            screenPixelW = 1920 * scale
            screenPixelH = 1080 * scale
        end

        local centerPixelX = screenPixelW / 2.0
        local centerPixelY = BoxESP.SnapLineOriginY * scale

        local fromX = centerPixelX * BoxESP._CanvasScaleX + BoxESP._CanvasOffsetX
        local fromY = centerPixelY * BoxESP._CanvasScaleY + BoxESP._CanvasOffsetY
        return fromX, fromY
    end

    function BoxESP.CreateSnapLine(ParentCanvas)
        if not IsValid(ParentCanvas) then return nil end
        local border = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
        if not IsValid(border) then return nil end

        border:SetBrushColor(ColorWhite)
        border:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        border.RenderTransformPivot = FVector2D(0.0, 0.5)
        border:SetRenderTransformPivot(FVector2D(0.0, 0.5))

        local slot = ParentCanvas:AddChildToCanvas(border)
        if slot then
            slot:SetAutoSize(false)
            slot:SetZOrder(990)
        end
        return { Widget = border, Slot = slot, bVisible = true }
    end

    function BoxESP.UpdateSnapLine(KeyStr, toX, toY, fromX, fromY, CustomColor, ParentCanvas)
        local lineData = BoxESP.LineWidgets[KeyStr]
        if not lineData or not IsValid(lineData.Widget) then
            lineData = BoxESP.CreateSnapLine(ParentCanvas)
            if not lineData or not lineData.Widget or not lineData.Slot then return end
            BoxESP.LineWidgets[KeyStr] = lineData
        end

        if not lineData.bVisible then
            lineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            lineData.bVisible = true
        end

        if CustomColor then
            pcall(function() lineData.Widget:SetBrushColor(CustomColor) end)
        end

        local dx = toX - fromX
        local dy = toY - fromY
        local length = math.sqrt(dx * dx + dy * dy)
        local angle = (math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)) * (180.0 / math.pi)
        local t = BoxESP.SnapLineThickness or 1.0

        if not lineData._CachedPosVec then
            lineData._CachedPosVec = FVector2D(fromX, fromY - t * 0.5)
            lineData._CachedSizeVec = FVector2D(length, t)
        else
            lineData._CachedPosVec.X = fromX
            lineData._CachedPosVec.Y = fromY - t * 0.5
            lineData._CachedSizeVec.X = length
            lineData._CachedSizeVec.Y = t
        end

        pcall(function()
            lineData.Slot:SetPosition(lineData._CachedPosVec)
            lineData.Slot:SetSize(lineData._CachedSizeVec)
            lineData.Widget:SetRenderAngle(angle)
        end)
    end

    function BoxESP.HideSnapLine(KeyStr)
        local lineData = BoxESP.LineWidgets[KeyStr]
        if lineData and lineData.Widget and IsValid(lineData.Widget) and lineData.bVisible then
            lineData.Widget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            lineData.bVisible = false
        end
    end

    
    function BoxESP.CreateEnemyCounter(ParentCanvas, centerX, topY)
        local CD = BoxESP.CounterData
        if CD.BgPlayer and IsValid(CD.BgPlayer) and CD.BgBot and IsValid(CD.BgBot)
            and CD.ImgPlayer and IsValid(CD.ImgPlayer) and CD.ImgBot and IsValid(CD.ImgBot) then
            return true
        end

        
        local bgPlayer = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
        local slotBgPlayer = nil
        if bgPlayer and IsValid(bgPlayer) then
            pcall(function() bgPlayer:SetBrushColor(FLinearColor(0.88, 0.055, 0.035, 0.96)) end)
            pcall(function() bgPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            slotBgPlayer = ParentCanvas:AddChildToCanvas(bgPlayer)
            if slotBgPlayer then
                slotBgPlayer:SetAutoSize(false)
                slotBgPlayer:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
                slotBgPlayer:SetPosition(FVector2D(centerX - BADGE_WIDTH - (BADGE_GAP * 0.5), topY))
                slotBgPlayer:SetZOrder(1003)
            end
        end

        local bgBot = CGame:NewObjectFromPath("/Script/UMG.Border", ParentCanvas)
        local slotBgBot = nil
        if bgBot and IsValid(bgBot) then
            pcall(function() bgBot:SetBrushColor(FLinearColor(0.02, 0.72, 0.07, 0.96)) end)
            pcall(function() bgBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible) end)
            slotBgBot = ParentCanvas:AddChildToCanvas(bgBot)
            if slotBgBot then
                slotBgBot:SetAutoSize(false)
                slotBgBot:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
                slotBgBot:SetPosition(FVector2D(centerX + (BADGE_GAP * 0.5), topY))
                slotBgBot:SetZOrder(1003)
            end
        end

        local imgPlayer = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
        local slotPlayer = nil
        if imgPlayer and IsValid(imgPlayer) then
            imgPlayer:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            slotPlayer = ParentCanvas:AddChildToCanvas(imgPlayer)
            if slotPlayer then
                slotPlayer:SetAutoSize(false)
                slotPlayer:SetSize(FVector2D(COUNTER_ICON_SIZE, COUNTER_ICON_SIZE))
                slotPlayer:SetPosition(FVector2D(centerX - BADGE_WIDTH - (BADGE_GAP * 0.5) + 4, topY + 5))
                slotPlayer:SetZOrder(1005)
            end
        end

        local imgBot = CGame:NewObjectFromPath("/Script/UMG.Image", ParentCanvas)
        local slotBot = nil
        if imgBot and IsValid(imgBot) then
            imgBot:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            slotBot = ParentCanvas:AddChildToCanvas(imgBot)
            if slotBot then
                slotBot:SetAutoSize(false)
                slotBot:SetSize(FVector2D(COUNTER_ICON_SIZE, COUNTER_ICON_SIZE))
                slotBot:SetPosition(FVector2D(centerX + (BADGE_GAP * 0.5) + 4, topY + 5))
                slotBot:SetZOrder(1005)
            end
        end

        local function MakeCounterText(posX, posY, initialText)
            local txt = CGame:NewObjectFromPath("/Script/UMG.TextBlock", ParentCanvas)
            local sl = nil
            if txt and IsValid(txt) then
                txt:SetText(initialText or "0")
                if txt.Font then
                    local font = txt.Font
                    font.Size = 10
                    if font.OutlineSettings then
                        font.OutlineSettings.OutlineSize = 0.0
                        font.OutlineSettings.OutlineColor = FLinearColor(0, 0, 0, 0)
                    end
                    txt.Font = font
                end
                if txt.SetFontSize then txt:SetFontSize(10) end
                txt:SetJustification(1)
                pcall(function() txt:SetAutoWrapText(false) end)
                if FSlateColor then
                    txt:SetColorAndOpacity(FSlateColor(ColorWhite))
                else
                    txt:SetColorAndOpacity(ColorWhite)
                end
                txt:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                sl = ParentCanvas:AddChildToCanvas(txt)
                if sl then
                    sl:SetAutoSize(true)
                    sl:SetAlignment(FVector2D(0.5, 0.5))
                    sl:SetPosition(FVector2D(posX, posY))
                    sl:SetZOrder(1010)
                end
            end
            return txt, sl
        end

        
        local enemyTextX = centerX - BADGE_WIDTH - (BADGE_GAP * 0.5) + (BADGE_WIDTH * 0.66)
        local botTextX = centerX + (BADGE_GAP * 0.5) + (BADGE_WIDTH * 0.66)
        local txtPlayer, slotTxtPlayer = MakeCounterText(enemyTextX, topY + (BADGE_HEIGHT * 0.5), "ENEMY : 0")
        local txtBot, slotTxtBot = MakeCounterText(botTextX, topY + (BADGE_HEIGHT * 0.5), "BOT : 0")

        LoadBadgeTexture(imgPlayer, ENEMY_COUNTER_PLAYER_URLS, "ic_danger_enemy.png", "Player", CD)
        LoadBadgeTexture(imgBot, ENEMY_COUNTER_BOT_URLS, "ic_clear_boot.png", "Bot", CD)

        CD.BgPlayer = bgPlayer
        CD.SlotBgPlayer = slotBgPlayer
        CD.BgBot = bgBot
        CD.SlotBgBot = slotBgBot
        CD.ImgPlayer = imgPlayer
        CD.SlotPlayer = slotPlayer
        CD.ImgBot = imgBot
        CD.SlotBot = slotBot
        CD.TxtPlayer = txtPlayer
        CD.SlotTxtPlayer = slotTxtPlayer
        CD.TxtBot = txtBot
        CD.SlotTxtBot = slotTxtBot
        CD.bCreated = true
        return true
    end

    function BoxESP.UpdateEnemyCounterDisplay(realCount, botCount, ParentCanvas, centerX, topY)
        local CD = BoxESP.CounterData
        if not BoxESP.bShowCounter then
            local col = UEnums.ESlateVisibility.Collapsed
            if CD.BgPlayer and IsValid(CD.BgPlayer) then CD.BgPlayer:SetWidgetVisibility(col) end
            if CD.BgBot and IsValid(CD.BgBot) then CD.BgBot:SetWidgetVisibility(col) end
            if CD.ImgPlayer and IsValid(CD.ImgPlayer) then CD.ImgPlayer:SetWidgetVisibility(col) end
            if CD.ImgBot and IsValid(CD.ImgBot) then CD.ImgBot:SetWidgetVisibility(col) end
            if CD.TxtPlayer and IsValid(CD.TxtPlayer) then CD.TxtPlayer:SetWidgetVisibility(col) end
            if CD.TxtBot and IsValid(CD.TxtBot) then CD.TxtBot:SetWidgetVisibility(col) end
            return
        end

        if not BoxESP.CreateEnemyCounter(ParentCanvas, centerX, topY) then return end

        local now = os.clock()
        if (not CD.PlayerLoaded or not CD.BotLoaded) and (now - CD.LastDownloadRetry > 2.0) then
            CD.LastDownloadRetry = now
            if not CD.PlayerLoaded and CD.ImgPlayer then LoadBadgeTexture(CD.ImgPlayer, ENEMY_COUNTER_PLAYER_URLS, "ic_danger_enemy.png", "Player", CD) end
            if not CD.BotLoaded and CD.ImgBot then LoadBadgeTexture(CD.ImgBot, ENEMY_COUNTER_BOT_URLS, "ic_clear_boot.png", "Bot", CD) end
        end

        pcall(function()
            if CD.SlotBgPlayer then
                CD.SlotBgPlayer:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
                CD.SlotBgPlayer:SetPosition(FVector2D(centerX - BADGE_WIDTH - (BADGE_GAP * 0.5), topY))
            end
            if CD.SlotBgBot then
                CD.SlotBgBot:SetSize(FVector2D(BADGE_WIDTH, BADGE_HEIGHT))
                CD.SlotBgBot:SetPosition(FVector2D(centerX + (BADGE_GAP * 0.5), topY))
            end
            if CD.SlotPlayer then
                CD.SlotPlayer:SetSize(FVector2D(COUNTER_ICON_SIZE, COUNTER_ICON_SIZE))
                CD.SlotPlayer:SetPosition(FVector2D(centerX - BADGE_WIDTH - (BADGE_GAP * 0.5) + 4, topY + 5))
            end
            if CD.SlotBot then
                CD.SlotBot:SetSize(FVector2D(COUNTER_ICON_SIZE, COUNTER_ICON_SIZE))
                CD.SlotBot:SetPosition(FVector2D(centerX + (BADGE_GAP * 0.5) + 4, topY + 5))
            end
            if CD.SlotTxtPlayer then
                CD.SlotTxtPlayer:SetPosition(FVector2D(centerX - BADGE_WIDTH - (BADGE_GAP * 0.5) + (BADGE_WIDTH * 0.66), topY + (BADGE_HEIGHT * 0.5)))
            end
            if CD.SlotTxtBot then
                CD.SlotTxtBot:SetPosition(FVector2D(centerX + (BADGE_GAP * 0.5) + (BADGE_WIDTH * 0.66), topY + (BADGE_HEIGHT * 0.5)))
            end

            if CD.LastPlayerCount ~= realCount then
                if CD.TxtPlayer and IsValid(CD.TxtPlayer) then CD.TxtPlayer:SetText("ENEMY : " .. tostring(realCount)) end
                CD.LastPlayerCount = realCount
            end

            if CD.LastBotCount ~= botCount then
                if CD.TxtBot and IsValid(CD.TxtBot) then CD.TxtBot:SetText("BOT : " .. tostring(botCount)) end
                CD.LastBotCount = botCount
            end

            local vis = UEnums.ESlateVisibility.SelfHitTestInvisible
            if CD.BgPlayer and IsValid(CD.BgPlayer) then CD.BgPlayer:SetWidgetVisibility(vis) end
            if CD.BgBot and IsValid(CD.BgBot) then CD.BgBot:SetWidgetVisibility(vis) end
            if CD.ImgPlayer and IsValid(CD.ImgPlayer) then CD.ImgPlayer:SetWidgetVisibility(vis) end
            if CD.ImgBot and IsValid(CD.ImgBot) then CD.ImgBot:SetWidgetVisibility(vis) end
            if CD.TxtPlayer and IsValid(CD.TxtPlayer) then CD.TxtPlayer:SetWidgetVisibility(vis) end
            if CD.TxtBot and IsValid(CD.TxtBot) then CD.TxtBot:SetWidgetVisibility(vis) end
        end)
    end

    function BoxESP.HideWidget(boxData)
        if not boxData or not boxData.bVisible then return end
        boxData.bVisible = false
        local collapsed = UEnums.ESlateVisibility.Collapsed
        if boxData.CornerContainer then boxData.CornerContainer:SetWidgetVisibility(collapsed) end
        if boxData.BgWidget then boxData.BgWidget:SetWidgetVisibility(collapsed) end
        if boxData.HealthWidget then boxData.HealthWidget:SetWidgetVisibility(collapsed) end
        if boxData.WeaponWidget then boxData.WeaponWidget:SetWidgetVisibility(collapsed) end
        if boxData.FlagWidget then boxData.FlagWidget:SetWidgetVisibility(collapsed) end
        if boxData.NameWidget then boxData.NameWidget:SetWidgetVisibility(collapsed) end
        if boxData.DistWidget then boxData.DistWidget:SetWidgetVisibility(collapsed) end
        if boxData.StateWidget then boxData.StateWidget:SetWidgetVisibility(collapsed) end
    end

    function BoxESP.ShowWidget(boxData)
        if not boxData or boxData.bVisible then return end
        boxData.bVisible = true
        local visible = UEnums.ESlateVisibility.SelfHitTestInvisible
        if boxData.CornerContainer then boxData.CornerContainer:SetWidgetVisibility(visible) end
        if boxData.BgWidget then boxData.BgWidget:SetWidgetVisibility(visible) end
        if boxData.HealthWidget then boxData.HealthWidget:SetWidgetVisibility(visible) end
        if boxData.WeaponWidget then boxData.WeaponWidget:SetWidgetVisibility(visible) end
        if boxData.FlagWidget then boxData.FlagWidget:SetWidgetVisibility(visible) end
        if boxData.NameWidget then boxData.NameWidget:SetWidgetVisibility(visible) end
        if boxData.DistWidget then boxData.DistWidget:SetWidgetVisibility(visible) end
        if boxData.StateWidget then boxData.StateWidget:SetWidgetVisibility(visible) end
    end

    function BoxESP.UpdateESP()
        local enabled = (_G.LexusConfig and _G.LexusConfig.EspAdvancedRadar == true)
        if BoxESP.bActive ~= enabled then
            BoxESP.bActive = enabled
            if not enabled then
                local collapsed = UEnums.ESlateVisibility.Collapsed
                for _, boxData in pairs(BoxESP.BoxWidgets) do
                    BoxESP.HideWidget(boxData)
                end
                for key in pairs(BoxESP.LineWidgets) do
                    BoxESP.HideSnapLine(key)
                end
                local cd = BoxESP.CounterData
                if cd.BgPlayer and IsValid(cd.BgPlayer) then cd.BgPlayer:SetWidgetVisibility(collapsed) end
                if cd.BgBot and IsValid(cd.BgBot) then cd.BgBot:SetWidgetVisibility(collapsed) end
                if cd.ImgPlayer and IsValid(cd.ImgPlayer) then cd.ImgPlayer:SetWidgetVisibility(collapsed) end
                if cd.ImgBot and IsValid(cd.ImgBot) then cd.ImgBot:SetWidgetVisibility(collapsed) end
                if cd.TxtPlayer and IsValid(cd.TxtPlayer) then cd.TxtPlayer:SetWidgetVisibility(collapsed) end
                if cd.TxtBot and IsValid(cd.TxtBot) then cd.TxtBot:SetWidgetVisibility(collapsed) end
                BoxESP._VisCheckCache = {}
            end
        end
        if not enabled then return end

        local ParentCanvas = BoxESP.GetMainCanvas()
        if not ParentCanvas then return end

        local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or _G.GameplayData
        if not GameplayData then return end

        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if not IsValid(LocalPlayer) then return end

        local PC = GameplayData.GetPlayerController and GameplayData.GetPlayerController()
        if not IsValid(PC) then return end

        local curTime = os.clock and os.clock() or 0
        if BoxESP._LastUpdateTime and (curTime - BoxESP._LastUpdateTime) < 0.02 then return end
        BoxESP._LastUpdateTime = curTime
        if BoxESP._LastCanvas ~= ParentCanvas or (curTime - BoxESP._LastTransformTime > 1.0) then
            BoxESP.UpdateCanvasTransform(PC)
            BoxESP._LastCanvas = ParentCanvas
            BoxESP._LastTransformTime = curTime
        end

        local bRunHeavyTasks = (curTime - BoxESP._LastHeavyUpdateTime > 0.15)
        if bRunHeavyTasks then
            BoxESP._LastHeavyUpdateTime = curTime
        end

        local bUpdateVisCheck = (curTime - BoxESP._LastVisCheckTime > 0.12)
        if bUpdateVisCheck then
            BoxESP._LastVisCheckTime = curTime
        end

        local fromX, fromY = BoxESP.GetSnapLineStartPos(PC, ParentCanvas)

        local TeamID = LocalPlayer.TeamID or (LocalPlayer.GetTeamID and LocalPlayer:GetTeamID()) or 0
        local AllPawns = (Game and Game.GetAllPlayerPawns and Game:GetAllPlayerPawns()) or {}
        local SeenKeys = {}
        local RealPlayerCount = 0
        local BotCount = 0

        for Key, Pawn in pairs(AllPawns) do
            if IsValid(Pawn) and Pawn ~= LocalPlayer then
                local pawnTeam = Pawn.TeamID or (Pawn.GetTeamID and Pawn:GetTeamID()) or -1
                local isAlive = (Pawn.Health and Pawn.Health > 0) or (Pawn.IsAlive and Pawn:IsAlive())

                if isAlive and pawnTeam ~= TeamID then
                    local KeyStr = tostring(Key)
                    SeenKeys[KeyStr] = true

                    local ping = (Pawn.PlayerState and Pawn.PlayerState.Ping) or Pawn.Ping or (Pawn.GetPing and Pawn:GetPing()) or -1
                    ping = tonumber(ping) or -1
                    local isBot = (ping >= 0 and ping <= 3) or Pawn.bIsAI or Pawn.bIsAIBot or Pawn.bIsABot or (Game and Game.IsAI and Game:IsAI(Pawn))

                    if isBot then
                        BotCount = BotCount + 1
                    else
                        RealPlayerCount = RealPlayerCount + 1
                    end

                    local Loc = Pawn.K2_GetActorLocation and Pawn:K2_GetActorLocation()
                    if not Loc and Pawn.RootComponent then
                        Loc = Pawn.RootComponent:K2_GetComponentLocation()
                    end

                    if Loc then
                        local topWorldPos = nil
                        local bottomWorldPos = nil

                        local mesh = Pawn.Mesh or (Pawn.GetMesh and Pawn:GetMesh()) or Pawn.CharacterMesh0
                        if mesh and mesh.GetSocketLocation then
                            local hLoc = mesh:GetSocketLocation("Head") or mesh:GetSocketLocation("head")
                            if hLoc and (hLoc.X ~= 0 or hLoc.Y ~= 0 or hLoc.Z ~= 0) then
                                topWorldPos = FVector(hLoc.X, hLoc.Y, hLoc.Z + 15)
                            end
                            local rLoc = mesh:GetSocketLocation("root") or mesh:GetSocketLocation("Root")
                            if rLoc and (rLoc.X ~= 0 or rLoc.Y ~= 0 or rLoc.Z ~= 0) then
                                bottomWorldPos = rLoc
                            end
                        end

                        local isProne = false
                        local isCrouch = false
                        if Pawn.bIsProning or Pawn.bIsProne or (Pawn.IsProne and Pawn:IsProne()) or Pawn.PoseState == 2 or Pawn.PoseState == "Prone" then
                            isProne = true
                        elseif Pawn.bIsCrouched or (Pawn.IsCrouched and Pawn:IsCrouched()) or Pawn.PoseState == 1 or Pawn.PoseState == "Crouch" then
                            isCrouch = true
                        end

                        if not topWorldPos or not bottomWorldPos then
                            local topOffset = isProne and 18 or (isCrouch and 50 or 88)
                            local bottomOffset = isProne and -22 or (isCrouch and -68 or -90)
                            topWorldPos = topWorldPos or FVector(Loc.X, Loc.Y, Loc.Z + topOffset)
                            bottomWorldPos = bottomWorldPos or FVector(Loc.X, Loc.Y, Loc.Z + bottomOffset)
                        end

                        local bTopOk, topX, topY = BoxESP.ProjectWorldToCanvasLocal(PC, topWorldPos)
                        local bBottomOk, bottomX, bottomY = BoxESP.ProjectWorldToCanvasLocal(PC, bottomWorldPos)

                        local boxData = BoxESP.BoxWidgets[KeyStr]
                        if not boxData then
                            boxData = BoxESP.CreateESPWidget(ParentCanvas)
                            if boxData then BoxESP.BoxWidgets[KeyStr] = boxData end
                        end

                        if boxData and IsValid(boxData.CornerContainer) then
                            if bTopOk and bBottomOk then
                                local boxHeight = math.max(28, math.abs(bottomY - topY))
                                local boxWidth = math.max(15, boxHeight * (isProne and 1.1 or (isCrouch and 0.7 or 0.55)))

                                local centerX = (topX + bottomX) * 0.5
                                local centerY = (topY + bottomY) * 0.5
                                local boxTopY = centerY - (boxHeight * 0.5)
                                local boxBottomY = centerY + (boxHeight * 0.5)

                                BoxESP.UpdateCornerDimensions(boxData, boxWidth, boxHeight)
                                boxData.CornerSlot:SetPosition(FVector2D(centerX, centerY))
                                BoxESP.ShowWidget(boxData)

                                local healthBarWidth = BoxESP.HealthBarWidth or 2.0
                                local healthCenterX = centerX - (boxWidth * 0.5) - 2.5 - (healthBarWidth * 0.5)
                                local health = Pawn.Health or (Pawn.GetHealth and Pawn:GetHealth()) or 100
                                local healthMax = Pawn.HealthMax or (Pawn.GetHealthMax and Pawn:GetHealthMax()) or 100
                                if healthMax <= 0 then healthMax = 100 end

                                local healthPercent = math.max(0, math.min(1, health / healthMax))
                                local currentHealthHeight = boxHeight * healthPercent

                                boxData.BgSlot:SetSize(FVector2D(healthBarWidth, boxHeight))
                                boxData.BgSlot:SetPosition(FVector2D(healthCenterX, boxBottomY))
                                boxData.HealthSlot:SetSize(FVector2D(healthBarWidth, currentHealthHeight))
                                boxData.HealthSlot:SetPosition(FVector2D(healthCenterX, boxBottomY))

                                if bRunHeavyTasks or boxData._cachedWeapon == "" then
                                    local wep = (Pawn.GetCurrentWeapon and Pawn:GetCurrentWeapon())
                                        or (Pawn.GetCurrentShootWeapon and Pawn:GetCurrentShootWeapon())
                                        or (Pawn.WeaponManagerComponent and Pawn.WeaponManagerComponent.CurrentWeaponReplicated)
                                    local weaponName = "Fist"
                                    if wep and IsValid(wep) then
                                        local wn = (type(wep.GetWeaponName) == "function" and wep:GetWeaponName()) or wep.WeaponName
                                        if wn and wn ~= "" then
                                            weaponName = tostring(wn):gsub("^BP_", ""):gsub("_C$", ""):gsub("_Wrapper$", "")
                                        end
                                    end
                                    if boxData._cachedWeapon ~= weaponName then
                                        boxData.WeaponWidget:SetText(weaponName)
                                        boxData._cachedWeapon = weaponName
                                    end
                                end
                                boxData.WeaponSlot:SetPosition(FVector2D(centerX, boxTopY - 3.5))

                                if bRunHeavyTasks or not boxData._cachedNation then
                                    local playerNation = (Pawn.PlayerState and Pawn.PlayerState.Nation) or Pawn.Nation or ""
                                    playerNation = tostring(playerNation or "")
                                    if playerNation == "" or playerNation == "nil" or playerNation == "0" then
                                        playerNation = "G1"
                                    end

                                    if boxData._cachedNation ~= playerNation then
                                        local cfg = (CDataTable and CDataTable.GetTableData) and CDataTable.GetTableData("RegionConfig", playerNation)
                                        if not cfg or not cfg.res_path or cfg.res_path == "" then
                                            cfg = (CDataTable and CDataTable.GetTableData) and CDataTable.GetTableData("RegionConfig", "G1")
                                        end
                                        local flagPath = (cfg and cfg.res_path) or "/Game/UMG/Texture/Atlas/NationalflagUI/Frames/T_icon_flag_iland_png.T_icon_flag_iland_png"

                                        if boxData.FlagWidget and IsValid(boxData.FlagWidget) then
                                            local bSet = false
                                            if boxData.FlagWidget.SetBrushResourceFromPathSync then
                                                boxData.FlagWidget:SetBrushResourceFromPathSync(flagPath, false)
                                                bSet = true
                                            end
                                            if not bSet and boxData.FlagWidget.SetBrushFromPathAsync then
                                                boxData.FlagWidget:SetBrushFromPathAsync(flagPath, false)
                                                bSet = true
                                            end
                                            if not bSet then
                                                local util = package.loaded["client.slua_ui_framework.util"]
                                                if not util then pcall(function() util = require("client.slua_ui_framework.util") end) end
                                                if util and util.SetTexture then
                                                    util.SetTexture(boxData.FlagWidget, flagPath, { sync = true })
                                                    bSet = true
                                                end
                                            end
                                            if not bSet then
                                                local asset_util = package.loaded["common.asset_util"]
                                                if not asset_util then pcall(function() asset_util = require("common.asset_util") end) end
                                                local flagTex = (asset_util and asset_util.GetAssetSync and asset_util.GetAssetSync(flagPath))
                                                             or (CGame and CGame.LoadObject and CGame:LoadObject(flagPath))
                                                if flagTex and boxData.FlagWidget.SetBrushFromTexture then
                                                    boxData.FlagWidget:SetBrushFromTexture(flagTex, false)
                                                    bSet = true
                                                end
                                            end
                                            boxData.FlagWidget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                                        end
                                        boxData._cachedNation = playerNation
                                    end
                                end
                                if boxData.FlagSlot then
                                    boxData.FlagSlot:SetPosition(FVector2D(centerX, boxTopY - 22.0))
                                end

                                if bRunHeavyTasks or boxData._cachedName == "" then
                                    local playerName = isBot and "Bot" or (Pawn.PlayerName or Pawn.PlayerNamePublic or (Pawn.GetPlayerName and Pawn:GetPlayerName()) or "Player")
                                    playerName = tostring(playerName)
                                    if boxData._cachedName ~= playerName then
                                        boxData.NameWidget:SetText(playerName)
                                        boxData._cachedName = playerName
                                    end
                                end
                                boxData.NameSlot:SetPosition(FVector2D(centerX, boxBottomY + 4.0))

                                local distVal = math.floor(LocalPlayer:GetDistanceTo(Pawn) / 100.0)
                                local distStr = tostring(distVal) .. "m"
                                if boxData._cachedDist ~= distStr then
                                    boxData.DistWidget:SetText(distStr)
                                    boxData._cachedDist = distStr
                                end
                                boxData.DistSlot:SetPosition(FVector2D(centerX, boxBottomY + 20.5))

                                if bUpdateVisCheck or BoxESP._VisCheckCache[KeyStr] == nil then
                                    BoxESP._VisCheckCache[KeyStr] = (PC and PC.LineOfSightTo and PC:LineOfSightTo(Pawn)) or false
                                end
                                local isVisible = BoxESP._VisCheckCache[KeyStr]

                                if bRunHeavyTasks or boxData._cachedState == "" then
                                    local isKnocked = (Pawn.HealthStatus == 1 or Pawn.bIsKnocked or (Pawn.IsKnocked and Pawn:IsKnocked()))
                                    local stateStr = "Open"
                                    local slateCol = SlateColorGreen
                                    if isKnocked then
                                        stateStr = "Knocked"
                                        slateCol = SlateColorRed
                                    elseif not isVisible then
                                        stateStr = "Cover"
                                        slateCol = SlateColorRed
                                    end

                                    if boxData._cachedState ~= stateStr then
                                        boxData.StateWidget:SetText(stateStr)
                                        boxData.StateWidget:SetColorAndOpacity(slateCol)
                                        boxData._cachedState = stateStr
                                    end
                                end
                                boxData.StateSlot:SetPosition(FVector2D(centerX, boxBottomY + 37.0))

                                if BoxESP.bShowLines then
                                    local lineColor = isVisible and ColorGreen or ColorRed
                                    
                                    local lineFromX = fromX + (centerX < fromX and -10 or 10)
                                    BoxESP.UpdateSnapLine(KeyStr, centerX, boxTopY, lineFromX, fromY, lineColor, ParentCanvas)
                                else
                                    BoxESP.HideSnapLine(KeyStr)
                                end
                            else
                                BoxESP.HideWidget(boxData)
                                BoxESP.HideSnapLine(KeyStr)
                            end
                        end
                    end
                end
            end
        end

        for KeyStr, boxData in pairs(BoxESP.BoxWidgets) do
            if not SeenKeys[KeyStr] then
                BoxESP.HideWidget(boxData)
            end
        end
        for KeyStr, _ in pairs(BoxESP.LineWidgets) do
            if not SeenKeys[KeyStr] then
                BoxESP.HideSnapLine(KeyStr)
                BoxESP._VisCheckCache[KeyStr] = nil
            end
        end

        
        local counterTopY = 34
        BoxESP.UpdateEnemyCounterDisplay(RealPlayerCount, BotCount, ParentCanvas, fromX, counterTopY)
    end


    _G.BoxESP = BoxESP
    return BoxESP
end)()





local function MainLoop()
    if isExpired then return end

    local _killLimitState = _G.LexusState.KillLimit
    if _killLimitState and _killLimitState.Reached and not _killLimitState.Cleaning then
        -- After 12 kills, keep ESP alive but skip all non-ESP systems.
        if _G.BoxESP then pcall(_G.BoxESP.UpdateESP) end
        if _G.LexusConfig and _G.LexusConfig.EspItem_Master and _G.RunOptimizedItemESP then
            local _pc = nil
            pcall(function()
                if GameplayData and GameplayData.GetPlayerController then
                    local c = GameplayData.GetPlayerController()
                    if Valid(c) then _pc = c end
                end
            end)
            if _pc then pcall(_G.RunOptimizedItemESP, _pc) end
        end
        return
    end

    if _G.BoxESP then pcall(_G.BoxESP.UpdateESP) end

    
    
    
    SanitizeActiveRuntimeConfig()

    if not GameplayData then return end
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    
    
    if not Valid(localPlayer) then 
        if not _G.LexusState.RuntimeCleanupDone then
            
            
            if _G.LexusState.TrackedMarks then
                for markId, _ in pairs(_G.LexusState.TrackedMarks) do
                    SafeRemoveMark(markId)
                end
            end
            _G.LexusState.TrackedMarks = {} 
            
            
            for key, data in pairs(_G.LexusState.EnemyMarks) do
                if data and data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do midTable[k] = nil end
                    end
                    data.MIDs = nil
                end
            end
            
            _G.LexusState.EnemyMarks = {}
            _G.LexusState.PrevGraphicsState = {}
            _G.LexusState.AimbotV2TargetCache = nil
            _G.AimTouchVisCache = {}
            _G.AimTouchBotCache = {}

            _G.LexusState.RuntimeCleanupDone = true
        end
        return 
    end

    _G.LexusState.RuntimeCleanupDone = false

    
    
    _G.LexusState.MainLoopCache = _G.LexusState.MainLoopCache or {}
    local MainLoopCache = _G.LexusState.MainLoopCache

    if MainLoopCache.SecurityCommonUtils == nil then
        pcall(function() MainLoopCache.SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    end
    if MainLoopCache.HUD ~= (pc and pc.MyHUD or nil) then
        MainLoopCache.HUD = pc and pc.MyHUD or nil
    end

    local Cached_SecurityCommonUtils = MainLoopCache.SecurityCommonUtils
    local Cached_MyHUD = MainLoopCache.HUD

    if _G.LexusConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()
    if not (_G.LexusState.KillLimit and _G.LexusState.KillLimit.Cleaning) then
        ShowLexusVIPMenu()
    end
    
    
    if _G.LexusConfig.EspItem_Master then
        _G.RunOptimizedItemESP(pc)
    end
    
    
    if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
        pcall(function()
            local targetTPP = _G.LexusState.CustomTextData.IpadViewFOV or 120
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= targetTPP then uTPPCam.FieldOfView = targetTPP end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 90 then uTPPCam.FieldOfView = 90 end
            end
        end)
    end

    
    
    
    if _G.LexusConfig.AimTouchEnable then
        pcall(function()
            local ui_util = require("client.common.ui_util")
            if ui_util then
                local vp = ui_util.GetViewportSize()
                if vp then
                    _G.__AimTouch_ViewportX = vp.X
                    _G.__AimTouch_CenterX = vp.X * 0.5
                    _G.__AimTouch_CenterY = vp.Y * 0.5
                end
            end
        end)
        _G.AimbotV2()
    end

    if _G.LexusConfig.ModSkin then
        local curTime = os.clock()
        
        if not _G.LastSkinUpdateTime or (curTime - _G.LastSkinUpdateTime) > 2.5 then
            _G.LastSkinUpdateTime = curTime
            pcall(function()
                local isAlive = type(localPlayer.IsAlive) == "function" and localPlayer:IsAlive() or true
                if isAlive then
                    if _G.HandlePetLogic then _G.HandlePetLogic() end
                    
                    if _G.LexusConfig.SkinDeadBox and _G.DeadBox_TemperRequest and _G.NeedCheckDeadBoxTimer > 0 then
                        _G.DeadBox_TemperRequest(pc)
                    end

                    if _G.AddOutfit then
                        
                        if _G.AddOutfit.isInRealMatch() then
                            
                            _G.AddOutfitLobbyRestored = false 
                            
                            
                            local ticker = require("common.time_ticker")
                            if ticker and ticker.AddTimerOnce then
                                _G.AddOutfit.matchApplyAllSlots(localPlayer)
                                ticker.AddTimerOnce(0.2, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() then 
                                        _G.AddOutfit.matchApplyHat(localPlayer) 
                                    end
                                end)
                                ticker.AddTimerOnce(0.4, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() then 
                                        _G.AddOutfit.matchApplyWeaponSkin(localPlayer) 
                                    end
                                end)
                                ticker.AddTimerOnce(0.6, function()
                                    if slua.isValid(localPlayer) and _G.AddOutfit.isInRealMatch() and _G.AddOutfit.isCharacterAirborne(localPlayer) then
                                        _G.AddOutfit.applyAirborneSlots(localPlayer, true)
                                    end
                                end)
                            else
                                _G.AddOutfit.matchApplyAllSlots(localPlayer)
                                _G.AddOutfit.matchApplyHat(localPlayer)
                                _G.AddOutfit.matchApplyWeaponSkin(localPlayer)
                                if _G.AddOutfit.isCharacterAirborne(localPlayer) then
                                    _G.AddOutfit.applyAirborneSlots(localPlayer, true)
                                end
                            end
                        else
                            
                            _G.AddOutfit.reapplyLobbyEquipped()
                        end
                    end
                end
            end)
        end
    end

    
    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    

    local now = os.clock()
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.LexusConfig.RemoveGrass and not _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
                _G.LexusState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.LexusConfig.RemoveGrass and _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1")
                gi:ExecuteCMD("grass.DiscardDataOnLoad", "0")
                _G.LexusState.PrevGraphicsState.RemoveGrass = false
            end

            
            if _G.LexusConfig.RemoveFog and not _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "0")           
                gi:ExecuteCMD("r.VolumetricFog", "0") 
                _G.LexusState.PrevGraphicsState.RemoveFog = true
            elseif not _G.LexusConfig.RemoveFog and _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.SkyAtmosphere", "1") 
                gi:ExecuteCMD("r.Fog", "1")           
                gi:ExecuteCMD("r.VolumetricFog", "1") 
                _G.LexusState.PrevGraphicsState.RemoveFog = false
            end
            
            if _G.LexusConfig.WhiteBody and not _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "2")
                gi:ExecuteCMD("r.CharacterDiffusePower", "5")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "100")
                _G.LexusState.PrevGraphicsState.WhiteBody = true
            elseif not _G.LexusConfig.WhiteBody and _G.LexusState.PrevGraphicsState.WhiteBody then
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                _G.LexusState.PrevGraphicsState.WhiteBody = false
            end
            
            if _G.LexusConfig.ColorBodyV2 and not _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "4")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "200")
                gi:ExecuteCMD("r.CharacterDiffusePower", "200")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = true
            elseif not _G.LexusConfig.ColorBodyV2 and _G.LexusState.PrevGraphicsState.ColorBodyV2 then
                gi:ExecuteCMD("r.CharacterMinShadowFactor", "1")
                gi:ExecuteCMD("r.CharacterDiffuseOffset", "0")
                gi:ExecuteCMD("r.CharacterDiffusePower", "1")
                _G.LexusState.PrevGraphicsState.ColorBodyV2 = false
            end
            
            
            if _G.LexusConfig.BlackSky and not _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.LexusState.PrevGraphicsState.BlackSky = true
            elseif not _G.LexusConfig.BlackSky and _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.LexusState.PrevGraphicsState.BlackSky = false
            end
        end
    end)

    pcall(function()
        local allCharacters = {}
        if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
        elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end
        
        local currentValidKeys = {}
        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer then
                currentValidKeys[GetSafeEnemyKey(enemy)] = true
            end
        end
        
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if not currentValidKeys[key] then
                    SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                
                
                if _G.AimTouchVisCache and _G.AimTouchVisCache[key] then
                    _G.AimTouchVisCache[key] = nil
                end
                
                if data.MIDs then
                    for meshStr, midTable in pairs(data.MIDs) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs = nil
                end
                data.enemy = nil
                data.CachedMeshes = nil
                _G.LexusState.EnemyMarks[key] = nil
            end
        end

        local realCount = 0
        local aiCount = 0
        local mLoc = nil
        pcall(function() if type(localPlayer.K2_GetActorLocation) == "function" then mLoc = localPlayer:K2_GetActorLocation() end end)

        for _, enemy in pairs(allCharacters) do
            if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
                local bIsReallyDead = false
                pcall(function()
                    if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                    elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead
                    elseif enemy.bIsDeadFlag ~= nil then bIsReallyDead = enemy.bIsDeadFlag end
                    if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
                end)

                local eKey = GetSafeEnemyKey(enemy)
                _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or { enemy = enemy }
                local markData = _G.LexusState.EnemyMarks[eKey]
                markData.enemy = enemy 

                if not bIsReallyDead then
                    
                    
                    if markData.lastEnemyActor ~= enemy then
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        
                        markData.lastEnemyActor = enemy
                        markData.LastUIComp = nil
                        markData.LastFrameUIState = nil
                    end
                    
                    local eMesh = nil
                    pcall(function() eMesh = enemy.Mesh or (type(enemy.getAvatarComponent2) == "function" and enemy:getAvatarComponent2() or nil) end)
                    local aLoc = nil
                    pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                    local isBotResult, isStateLoaded = CheckIsAI(enemy, markData)
                    local isBot = markData.AK_IS_BOT or false

                    local currentMeshCount = 0
                    if Valid(eMesh) then
                        local tempMeshes = GetAllSkeletalMeshes(enemy, markData)
                        currentMeshCount = #tempMeshes
                    end
                    local isMeshChanged = (markData.LastMeshCountWall ~= currentMeshCount)

                    
                    if _G.LexusConfig.WallXuyenTuong then
                        if isMeshChanged or not markData.WallhackApplied then
                            ApplyWallXuyenTuong(enemy, markData)
                            markData.WallhackApplied = true
                            markData.LastMeshCountWall = currentMeshCount
                        end
                    else
                        UndoWallXuyenTuong(enemy, markData)
                    end

                    
                    if _G.LexusConfig.ColorBodyV2 then 
                        
                        ApplyColorBodyV2(enemy, pc, markData) 
                    else
                        UndoColorBodyV2(enemy, markData)
                    end
                    
                    
                    if _G.LexusConfig.ColorBodyNew then 
                        ApplyColorBodyNew(enemy, markData)
                    else
                        UndoColorBodyNew(enemy, markData)
                    end

                    
                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.LexusConfig.EspVipPro or _G.LexusConfig.EspVip
                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    if showFrameUI then
                        pcall(function()
                            local SecurityCommonUtils = Cached_SecurityCommonUtils
                            local show = true
                            if enemy.HealthStatus and SecurityCommonUtils and SecurityCommonUtils.IsHealthStatusAlive then 
                                if not SecurityCommonUtils.IsHealthStatusAlive(enemy.HealthStatus) then show = false end
                            end
                            if show and mLoc then
                                if aLoc and SecurityCommonUtils and SecurityCommonUtils.IsVector then
                                    if SecurityCommonUtils.IsVector(aLoc) and SecurityCommonUtils.IsVector(mLoc) then
                                        if aLoc.Z >= 150000 or FVector.Dist2D(mLoc, aLoc) > 50000 then show = false end
                                    end
                                end
                            end
                            if show then
                                if enemy.Replay_IsEnemyFrameUIExisted and not enemy:Replay_IsEnemyFrameUIExisted() then enemy:Replay_CreateEnemyFrameUI(true, true) end
                                if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(true) end
                                if enemy.Replay_UpdateEnemyFrameUI then enemy:Replay_UpdateEnemyFrameUI(hpRatio) end
                                
                                local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if markData.LastFrameUIState ~= "VISIBLE" then
                                        if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(0) end
                                        if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(false) end
                                        markData.LastFrameUIState = "VISIBLE"
                                    end
                                end
                            end
                        end)
                    else
                        pcall(function()
                            if enemy.Replay_SetVisiableOfFrameUI then enemy:Replay_SetVisiableOfFrameUI(false) end
                            local uiComp = enemy.EnemyFrameUI or (type(enemy.GetEnemyFrameUI) == "function" and enemy:GetEnemyFrameUI())
                            if Valid(uiComp) then
                                if markData.LastFrameUIState ~= "HIDDEN" then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                    markData.LastFrameUIState = "HIDDEN"
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspVipPro then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    local hpPercent = hpRatio
                                    local isKnock = (currentHp <= 0 and enemy.HealthStatus == 1)
                                    
                                    local hpColor = C_GREEN
                                    if hpPercent < 0.3 then hpColor = C_RED
                                    elseif hpPercent < 0.7 then hpColor = C_YELLOW end
                                    if isKnock then hpColor = C_RED end
                                    
                                    
                                    if _G.LexusConfig.Esp3ShowName then
                                        local enemyName = "Enemy"
                                        pcall(function() if enemy.PlayerName then enemyName = enemy.PlayerName elseif type(enemy.GetPlayerName) == "function" then enemyName = enemy:GetPlayerName() end end)
                                        if enemyName == "" then enemyName = "Enemy" end
                                        if isKnock then enemyName = "زمین‌خورده: " .. enemyName end
                                        hud:AddDebugText(enemyName, enemy, 0.06, {X=0, Y=0, Z=-370}, {X=0, Y=0, Z=-370}, C_WHITE, true, false, true, nil, dynamicScale * 1.1, true)
                                    end
                                    
                                    
                                    if _G.LexusConfig.Esp3ShowHP then
                                        if not isKnock then
                                            local segments = 6
                                            local filled = math.floor(hpPercent * segments)
                                            local startZ = 20
                                            local spacing = 10.0 * dynamicScale 
                                            for j = 1, segments do
                                                local color = (j <= filled) and hpColor or {R=30,G=30,B=30,A=180}
                                                hud:AddDebugText("█", enemy, 0.06, {X=0, Y=-115, Z=startZ + (j * spacing)}, {X=0, Y=-115, Z=startZ + (j * spacing)}, color, true, false, true, nil, dynamicScale * 1.2, true)
                                            end
                                            hud:AddDebugText(string.format("%d%%", math.floor(hpPercent * 100)), enemy, 0.06, {X=0, Y=-60, Z=startZ - 12}, {X=0, Y=-60, Z=startZ - 12}, hpColor, true, false, true, nil, dynamicScale * 0.8, true)
                                        else
                                            hud:AddDebugText("DOWN", enemy, 0.06, {X=0, Y=-115, Z=50}, {X=0, Y=-115, Z=50}, C_RED, true, false, true, nil, dynamicScale * 1.0, true)
                                        end
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspVip then
                        if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                        if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                    end

                    

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        
                        if markData.MIDs then
                            for meshStr, midTable in pairs(markData.MIDs) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs = nil
                        end
                        
                        pcall(function()
                            local eObj = markData.enemy
                            if Valid(eObj) then 
                                if eObj.Replay_SetVisiableOfFrameUI then eObj:Replay_SetVisiableOfFrameUI(false) end
                                local uiComp = eObj.EnemyFrameUI or (type(eObj.GetEnemyFrameUI) == "function" and eObj:GetEnemyFrameUI())
                                if Valid(uiComp) then
                                    if type(uiComp.SetVisibility) == "function" then uiComp:SetVisibility(2) end 
                                    if type(uiComp.SetHiddenInGame) == "function" then uiComp:SetHiddenInGame(true) end
                                end
                            end
                            

                        end)

                        markData.IsCleanedUp = true
                    end
                end
            end
        end

    end)
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1 
local myToken = _G.LexusState.LoopToken

_G.ZD_ShowKillLimitAlert = function()
    local state = _G.LexusState.KillLimit
    if not state or state.PopupShown then return true end

    local ok, shown = pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if not Msg or not Msg.Show then return false end

        local title = "سیستم انتی‌بن"
        local content = "ما تا الان تمام ریپورت هایی که شده اید رو از سیستم پابجی پاک کردیم\n برای جلوگیری از مسدود شدن حساب شما قابلیت ها در این مچ غیرفعال شدند\nZD TEAM @ZONE_MOD"
        local btn1 = "متوجه شدم"
        local btn2 = "بستن"

        Msg.Show(1, title, content, function() end, function() end, btn1, btn2)
        return true
    end)

    if ok and shown then
        state.PopupShown = true
        return true
    end
    return false
end

_G.ZD_KillLimitCleanup = function()
    local state = _G.LexusState.KillLimit
    if not state or state.CleanupDone or state.Cleaning then return end

    state.Cleaning = true
    local savedBools = {}
    for key, value in pairs(_G.LexusConfig or {}) do
        if type(value) == "boolean" then
            -- Preserve every current ESP option; disable everything else.
            local isESP = type(key) == "string" and key:match("^Esp") ~= nil
            if isESP then
                savedBools[key] = value
            else
                savedBools[key] = value
                _G.LexusConfig[key] = false
            end
        end
    end
    state.DisabledConfig = { Bools = savedBools }

    pcall(MainLoop)

    pcall(function()
        if _G.__ZD_RGB_WATERMARK and _G.__ZD_RGB_WATERMARK.destroy then
            _G.__ZD_RGB_WATERMARK:destroy()
        end
    end)

    state.Cleaning = false
    state.CleanupDone = true
    _G.LexusState.LoopToken = myToken + 1
end

_G.ZD_RegisterMatchKill = function(record)
    local state = _G.LexusState.KillLimit
    if not state or state.Reached then return true end
    if type(record) ~= "table" and type(record) ~= "userdata" then return false end

    local key = tostring(record)
    if state.SeenKillRecords[key] then return false end
    state.SeenKillRecords[key] = true

    state.MatchKills = (state.MatchKills or 0) + 1
    if state.MatchKills >= 12 then
        state.Reached = true
        state.CleanupDone = false
        state.PopupShown = false
        pcall(_G.ZD_ShowKillLimitAlert)
        pcall(_G.ZD_KillLimitCleanup)
        return true
    end
    return false
end

local function ExpiredTick()
    if not _G.LexusNotifiedPopup then
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then
                Msg.Show(1, "مدت استفاده از نسخه به پایان رسیده است", "مدت استفاده از نسخهٔ شما به پایان رسیده است!\nبرای تمدید با مدیر تماس بگیرید.\nبرای دریافت نسخهٔ اصلی از منبع معرفی‌شده استفاده کنید.", 
                function() 
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://t.me/ZONE_MOD") end 
                end, 
                function() end, "تماس با سازنده", "بستن")
                _G.LexusNotifiedPopup = true 
            end
        end)
        
        if not _G.LexusNotifiedPopup then
            local okTicker, ticker = pcall(require, "common.time_ticker") 
            if okTicker and ticker and ticker.AddTimerOnce then 
                ticker.AddTimerOnce(2.0, ExpiredTick) 
            end
        end
    end
end

local ZONE_MOD_LoginUI = (function()
local Module = {}
function Module.new(env)
    env = env or _G
    local require = env.require or require
    local function global(name)
        local ok, value = pcall(function() return env[name] end)
        if ok then return value end
    end
    local UI = { _status = "Enter your key", _busy = false, _data = nil }
    local function member(object, name)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[name] end)
        if ok then return value end
    end
    local function valid(object)
        local check = member(global("slua"), "isValid")
        if object == nil then return false end
        if type(check) == 'function' then
            local ok, result = pcall(check, object)
            if ok and result == true then return true end
        end
        local game = global('Game')
        local fallback = member(game, 'IsValid')
        if type(fallback) == 'function' then
            local ok, result = pcall(fallback, game, object)
            return ok and result == true
        end
        return true
    end
    local function imported(name)
        local loader = global("import")
        if type(loader) ~= "function" then return nil end
        local ok, result = pcall(loader, name)
        if ok then return result end
    end
    local function construct(class, ...)
        if class == nil then return nil end
        local ok, result = pcall(class, ...)
        if ok then return result end
    end
    local function vector(x, y)
        local ctor = global("FVector2D") or imported("Vector2D")
        assert(ctor ~= nil, "UI_VECTOR2D_UNAVAILABLE")
        local value = construct(ctor, x, y)
        assert(value ~= nil, "UI_VECTOR2D_CONSTRUCT_FAILED")
        return value
    end
    local function color(r, g, b, a)
        local ctor = global("FLinearColor") or imported("LinearColor")
        assert(ctor ~= nil, "UI_LINEAR_COLOR_UNAVAILABLE")
        local value = construct(ctor, r, g, b, a)
        assert(value ~= nil, "UI_LINEAR_COLOR_CONSTRUCT_FAILED")
        return value
    end
    local function visibility(widget, value)
        local setter = member(widget, "SetWidgetVisibility") or member(widget, "SetVisibility")
        assert(type(setter) == "function", "UI_VISIBILITY_UNAVAILABLE")
        setter(widget, value)
    end
    local function setTextStyle(widget, size, textColor)
        pcall(function()
            local font = widget.Font
            if font then
                font.Size = math.max(1, math.floor(size * (UI._scale or 1) + 0.5))
                local assigned = pcall(function() widget.Font = font end)
                if not assigned then widget:SetFont(font) end
            end
        end)
        pcall(function() widget:SetAutoWrapText(true) end)
        pcall(function()
            local slate = construct(imported("SlateColor"), textColor)
            if slate then widget:SetColorAndOpacity(slate) end
        end)
    end
    local function detach(data)
        if not data then return end
        data.visible = false
        pcall(function() if valid(data.input) then data.input:SetText("") end end)
        if data.event and data.eventHandle ~= nil then
            pcall(function() data.event:Remove(data.eventHandle) end)
        end
        if valid(data.container) then
            pcall(function() data.container:RemoveFromParent() end)
        end
        if valid(data.modalBlocker) then
            pcall(function() data.modalBlocker:RemoveFromParent() end)
        end
        data.onSubmit = nil
    end
    function UI.Destroy()
        local previous = UI._data
        UI._data = nil
        detach(previous)
    end
    function UI.Hide()
        local data = UI._data
        if not data or data.hiddenApplied then return true end
        data.visible = false
        local ok = pcall(function()
            if valid(data.input) then data.input:SetText("") end
            if valid(data.container) then visibility(data.container, data.hidden) end
            if valid(data.modalBlocker) then visibility(data.modalBlocker, data.hidden) end
        end)
        if ok then data.hiddenApplied = true end
        return ok
    end
    function UI.SetStatus(message)
        UI._status = type(message) == "string" and message:sub(1, 160) or "Login unavailable"
        local data = UI._data
        if data and data.deliveredStatus == UI._status then return true end
        if data and valid(data.status) then
            local ok = pcall(function() data.status:SetText(UI._status) end)
            if ok then data.deliveredStatus = UI._status end
            return ok
        end
        return false
    end
    function UI.SetBusy(busy)
        UI._busy = busy == true
        local data = UI._data
        if data then
            if data.deliveredBusy == UI._busy then return true end
            local buttonOK = pcall(function() data.button:SetIsEnabled(not UI._busy) end)
            local inputOK = pcall(function() data.input:SetIsEnabled(not UI._busy) end)
            if buttonOK and inputOK then
                data.deliveredBusy = UI._busy
                return true
            end
        end
        return false
    end
    function UI.Animate(now)
        local data = UI._data
        if not data or not data.visible then return false end
        if type(now) ~= "number" then return false end

        
        local wave = 0.5 + 0.5 * math.sin(now * 2.35)
        local wave2 = 0.5 + 0.5 * math.sin(now * 2.35 + math.pi * 0.5)
        local cyanA = 0.68 + wave * 0.32
        local violetA = 0.58 + wave2 * 0.42

        pcall(function()
            if valid(data.accent) then
                data.accent:SetBrushColor(color(0.0, 0.82, 1.0, cyanA))
            end
            if valid(data.bottomGlow) then
                data.bottomGlow:SetBrushColor(color(0.06, 0.22, 0.92, violetA))
            end
            if valid(data.leftGlow) then
                data.leftGlow:SetBrushColor(color(0.06, 0.22, 0.92, violetA))
            end
            if valid(data.rightGlow) then
                data.rightGlow:SetBrushColor(color(0.10, 0.68, 1.0, cyanA))
            end
            if valid(data.cardEdge) then
                data.cardEdge:SetBrushColor(color(0.0, 0.72, 1.0, 0.28 + wave * 0.42))
            end
            if valid(data.inputEdge) then
                data.inputEdge:SetBrushColor(color(0.05, 0.62, 1.0, 0.38 + wave2 * 0.42))
            end
            if valid(data.buttonGlow) then
                data.buttonGlow:SetBrushColor(color(0.0, 0.72, 1.0, 0.16 + wave * 0.34))
            end
            if valid(data.buttonEdge) then
                data.buttonEdge:SetBrushColor(color(0.0, 0.78, 1.0, 0.35 + wave2 * 0.55))
            end
            if valid(data.button) and not UI._busy then
                pcall(function()
                    data.button:SetBackgroundColor(color(
                        0.0,
                        0.58 + wave * 0.12,
                        0.92 + wave * 0.08,
                        0.96
                    ))
                end)
            end
        end)
        pcall(function()
            if valid(data.statusDot) then
                data.statusDot:SetBrushColor(color(0.0, 0.78, 1.0, 0.55 + wave * 0.45))
            end
        end)
        return true
    end
    local function fitScale(parent)
        local result = 1
        pcall(function()
            local size = parent:GetCachedGeometry():GetLocalSize()
            local width, height = size.X, size.Y
            if type(width) == 'number' and type(height) == 'number' and width > 24 and height > 24 then
                result = math.min(1, (width - 24) / 760, (height - 24) / 430)
            end
        end)
        return result
    end
    function UI.Show(onSubmit)
        if type(onSubmit) ~= "function" then return false, "UI_SUBMIT_REQUIRED" end
        local data = UI._data
        if data and valid(data.parent) and math.abs(fitScale(data.parent) - (data.scale or 1)) > 0.001 then
            UI.Destroy()
            data = nil
        end
        if data and valid(data.container) and valid(data.parent) then
            local ok = data.visible or pcall(function()
                visibility(data.modalBlocker, data.visibleEnum)
                visibility(data.container, data.visibleEnum)
            end)
            if ok then
                data.onSubmit, data.visible, data.hiddenApplied = onSubmit, true, false
                UI.SetStatus(UI._status)
                UI.SetBusy(UI._busy)
                return true
            end
        end
        UI.Destroy()
        
        local parent = nil
        local uiTools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        assert(type(uiTools) == "table" and type(uiTools.GetMainControlBaseUI) == "function",
            "UI_GET_MAIN_CONTROL_BASE_UI_UNAVAILABLE")
        local root = uiTools.GetMainControlBaseUI()
        assert(valid(root), "UI_MAIN_CONTROL_BASE_UI_INVALID")
        parent = member(root, "CanvasPanel_42")
        if not valid(parent) then parent = member(root, "CanvasPanel_0") end
        if not valid(parent) then return false, "UI_CANVAS_NOT_READY" end
        local game = global("CGame")
        if type(member(game, "NewObjectFromPath")) ~= "function" then return false, "UI_FACTORY_UNAVAILABLE" end
        local enums = member(global("UEnums"), "ESlateVisibility")
        local visibleEnum, hidden = member(enums, "Visible"), member(enums, "Collapsed")
        local passive = member(enums, "SelfHitTestInvisible")
        if visibleEnum == nil or hidden == nil or passive == nil then return false, "UI_ENUM_UNAVAILABLE" end
        UI._scale = fitScale(parent)
        data = {
            parent = parent, visible = false, onSubmit = onSubmit,
            visibleEnum = visibleEnum, hidden = hidden, scale = UI._scale
        }
        local okBuild, buildError = xpcall(function()
            local function make(class, outer)
                local widget = game:NewObjectFromPath("/Script/UMG." .. class, outer)
                assert(valid(widget), "UI_WIDGET_UNAVAILABLE")
                local clip = member(member(global('UEnums'), 'EWidgetClipping'), 'ClipToBounds')
                if clip ~= nil then pcall(function() widget:SetClipping(clip) end) end
                return widget
            end

            local W, H = 760, 430

            
            
            data.modalBlocker = make("Border", parent)
            data.modalBlocker:SetBrushColor(color(0, 0, 0, 0))
            visibility(data.modalBlocker, visibleEnum)
            local modalSlot = parent:AddChildToCanvas(data.modalBlocker)
            assert(valid(modalSlot), "UI_MODAL_SLOT_UNAVAILABLE")
            modalSlot:SetAutoSize(false)
            modalSlot:SetPosition(vector(0, 0))
            pcall(function()
                local parentSize = parent:GetCachedGeometry():GetLocalSize()
                if parentSize and parentSize.X and parentSize.Y and parentSize.X > 24 and parentSize.Y > 24 then
                    modalSlot:SetSize(vector(parentSize.X, parentSize.Y))
                else
                    modalSlot:SetSize(vector(4096, 4096))
                end
            end)
            modalSlot:SetZOrder(100000)
            data.modalSlot = modalSlot

            data.container = make("CanvasPanel", parent)

            local function add(widget, x, y, width, height, z)
                local slot = data.container:AddChildToCanvas(widget)
                assert(valid(slot), "UI_SLOT_UNAVAILABLE")
                slot:SetAutoSize(false)
                slot:SetPosition(vector(x * UI._scale, y * UI._scale))
                slot:SetSize(vector(width * UI._scale, height * UI._scale))
                slot:SetZOrder(z)
                return slot
            end

            local function text(class, value, size, r, g, b, a)
                local w = make(class, data.container)
                w:SetText(value)
                setTextStyle(w, size, color(r, g, b, a or 1))
                visibility(w, passive)
                return w
            end

            
            local shadow = make("Border", data.container)
            shadow:SetBrushColor(color(0, 0, 0, 0.55))
            visibility(shadow, visibleEnum)
            add(shadow, 10, 12, W, H, 0)

            local shell = make("Border", data.container)
            shell:SetBrushColor(color(0.008, 0.018, 0.055, 0.99))
            visibility(shell, visibleEnum)
            add(shell, 0, 0, W, H, 1)

            local topGlow = make("Border", data.container)
            topGlow:SetBrushColor(color(0.0, 0.82, 1.0, 1))
            visibility(topGlow, visibleEnum)
            add(topGlow, 0, 0, W, 4, 8)
            data.accent = topGlow

            local bottomGlow = make("Border", data.container)
            bottomGlow:SetBrushColor(color(0.05, 0.30, 0.95, 0.90))
            visibility(bottomGlow, visibleEnum)
            add(bottomGlow, 0, H - 4, W, 4, 8)
            data.bottomGlow = bottomGlow

            local leftGlow = make("Border", data.container)
            leftGlow:SetBrushColor(color(0.05, 0.30, 0.95, 1))
            visibility(leftGlow, visibleEnum)
            add(leftGlow, 0, 0, 4, H, 8)
            data.leftGlow = leftGlow

            local rightGlow = make("Border", data.container)
            rightGlow:SetBrushColor(color(0.10, 0.72, 1.0, 0.82))
            visibility(rightGlow, visibleEnum)
            add(rightGlow, W - 3, 0, 3, H, 8)
            data.rightGlow = rightGlow

            
            local header = make("Border", data.container)
            header:SetBrushColor(color(0.015, 0.045, 0.10, 0.98))
            visibility(header, visibleEnum)
            add(header, 22, 18, W - 44, 72, 2)

            local brand = text("TextBlock", "BUY KEY @ZONE_MOD", 25, 0.94, 0.97, 1)
            add(brand, 42, 31, 270, 34, 9)

            local subtitle = text("TextBlock", "SECURE ACCESS // KEY GATE", 7.5, 0.35, 0.78, 0.98)
            add(subtitle, 44, 63, 300, 16, 9)

            local activeBox = make("Border", data.container)
            activeBox:SetBrushColor(color(0.015, 0.08, 0.16, 0.96))
            visibility(activeBox, visibleEnum)
            add(activeBox, W - 178, 32, 132, 38, 5)

            data.statusDot = make("Border", data.container)
            data.statusDot:SetBrushColor(color(1.0, 0.20, 0.20, 1))
            visibility(data.statusDot, visibleEnum)
            add(data.statusDot, W - 164, 46, 8, 10, 7)

            local activeText = text("TextBlock", "LOCKED", 9, 0.25, 1.0, 0.72)
            add(activeText, W - 150, 40, 86, 20, 9)

            local divider = make("Border", data.container)
            divider:SetBrushColor(color(0.0, 0.82, 1.0, 0.22))
            visibility(divider, visibleEnum)
            add(divider, 22, 100, W - 44, 2, 4)

            
            local identity = make("Border", data.container)
            identity:SetBrushColor(color(0.012, 0.05, 0.10, 0.94))
            visibility(identity, visibleEnum)
            add(identity, 22, 116, 202, 282, 2)

            local mark = text("TextBlock", "ZONE", 34, 0.10, 0.90, 1)
            add(mark, 44, 135, 150, 48, 9)

            local brand2 = text("TextBlock", "Online System", 15, 0.96, 0.97, 1)
            add(brand2, 44, 185, 155, 24, 9)

            local line1 = make("Border", data.container)
            line1:SetBrushColor(color(0.0, 0.72, 1.0, 0.72))
            visibility(line1, visibleEnum)
            add(line1, 44, 219, 142, 2, 5)

            local info = text("TextBlock", "KEY STATUS", 7.5, 0.45, 0.62, 0.76)
            add(info, 44, 239, 150, 17, 9)
            local info2 = text("TextBlock", "WAITING FOR KEY", 10, 0.25, 1.0, 0.72)
            add(info2, 44, 258, 150, 22, 9)

            local info3 = text("TextBlock", "KEY VALIDATION", 7.5, 0.45, 0.62, 0.76)
            add(info3, 44, 291, 150, 17, 9)
            local info4 = text("TextBlock", "LOCAL KEY GATE", 10, 0.0, 0.78, 1.0)
            add(info4, 44, 310, 150, 22, 9)

            local tag = make("Border", data.container)
            tag:SetBrushColor(color(0.0, 0.65, 1.0, 0.10))
            visibility(tag, visibleEnum)
            add(tag, 44, 337, 158, 34, 5)
            local tagText = text("TextBlock", "ZD SYSTEM // ONLINE", 7.5, 0.25, 0.88, 1.0)
            add(tagText, 56, 345, 138, 18, 9)

            
            local card = make("Border", data.container)
            card:SetBrushColor(color(0.008, 0.025, 0.07, 0.99))
            visibility(card, visibleEnum)
            add(card, 242, 116, W - 264, 282, 2)

            local cardEdge = make("Border", data.container)
            cardEdge:SetBrushColor(color(0.0, 0.70, 1.0, 0.48))
            visibility(cardEdge, visibleEnum)
            add(cardEdge, 242, 116, 3, 282, 5)
            data.cardEdge = cardEdge

            local title = text("TextBlock", "Safe Mod-ZD", 22, 0.97, 0.98, 1)
            add(title, 266, 132, W - 308, 32, 9)

            local subtitle2 = text("TextBlock", "Enter key to continue", 9, 0.42, 0.74, 0.90)
            add(subtitle2, 268, 164, W - 310, 20, 9)

            local section = text("TextBlock", "ACCESS KEY", 8, 0.35, 0.88, 0.98)
            add(section, 268, 194, W - 310, 18, 9)

            local inputBg = make("Border", data.container)
            inputBg:SetBrushColor(color(0.01, 0.035, 0.09, 1))
            visibility(inputBg, visibleEnum)
            add(inputBg, 266, 215, W - 308, 54, 2)

            local inputEdge = make("Border", data.container)
            inputEdge:SetBrushColor(color(0.0, 0.72, 1.0, 0.55))
            visibility(inputEdge, passive)
            add(inputEdge, 266, 215, 3, 54, 6)
            data.inputEdge = inputEdge

            data.input = make("EditableTextBox", data.container)
            assert(type(member(data.input, "GetText")) == "function", "UI_INPUT_UNAVAILABLE")
            data.input:SetText("")
            setTextStyle(data.input, 15, color(0.94, 0.96, 1, 1))
            pcall(function() data.input:SetHintText("ENTER ACCESS KEY") end)
            pcall(function() data.input:SetIsPassword(false) end)
            pcall(function() data.input:SetIsReadOnly(false) end)
            pcall(function() data.input.AllowContextMenu = true end)
            local enumRoot = global("UEnums")
            local keyboard = member(member(enumRoot, "EVirtualKeyboardType"), "Default")
            local trigger = member(member(enumRoot, "EVirtualKeyboardTrigger"), "OnAllFocusEvents")
            if keyboard ~= nil then pcall(function() data.input.KeyboardType = keyboard end) end
            if trigger ~= nil then pcall(function() data.input.VirtualKeyboardTrigger = trigger end) end
            visibility(data.input, visibleEnum)
            add(data.input, 282, 221, W - 384, 42, 20)
            pcall(function() data.input:SetIsEnabled(true) end)

            local hint = text("TextBlock", "Key is checked locally for this session.", 7.5, 0.34, 0.52, 0.68)
            add(hint, 268, 274, W - 310, 18, 9)

            local statusBg = make("Border", data.container)
            statusBg:SetBrushColor(color(0.008, 0.03, 0.08, 0.98))
            visibility(statusBg, visibleEnum)
            add(statusBg, 266, 299, W - 308, 42, 2)

            data.status = text("TextBlock", UI._status, 8.5, 0.76, 0.92, 0.96)
            data.deliveredStatus = UI._status
            pcall(function() data.status:SetAutoWrapText(true) end)
            add(data.status, 284, 304, W - 384, 30, 9)

            local loginButton = make("Button", data.container)
            visibility(loginButton, visibleEnum)
            pcall(function() loginButton:SetBackgroundColor(color(0.0, 0.68, 1.0, 0.96)) end)
            local label = make("TextBlock", loginButton)
            label:SetText("LOGIN  //  SAVE & START")
            setTextStyle(label, 12, color(0.006, 0.012, 0.035, 1))
            visibility(label, passive)
            pcall(function() loginButton:AddChild(label) end)
            add(loginButton, 266, 348, W - 308, 48, 20)
            pcall(function() loginButton:SetIsEnabled(true) end)
            pcall(function() loginButton:SetVisibility(visibleEnum) end)
            data.button = loginButton

            local buttonEdge = make("Border", data.container)
            buttonEdge:SetBrushColor(color(0.90, 0.05, 0.05, 0.65))
            visibility(buttonEdge, passive)
            add(buttonEdge, 266, 348, W - 308, 2, 21)
            data.buttonEdge = buttonEdge

            local buttonGlow = make("Border", data.container)
            buttonGlow:SetBrushColor(color(0.0, 0.72, 1.0, 0.35))
            
            visibility(buttonGlow, passive)
            add(buttonGlow, 266, 348, W - 308, 48, 7)
            data.buttonGlow = buttonGlow

            local footer = text("TextBlock", "ZONE VIP  •  KEY GATE  •  SECURE SESSION", 7, 0.25, 0.70, 0.95)
            add(footer, 242, 408, W - 264, 15, 9)

            data.event = data.button.OnClicked
            assert(type(member(data.event, "Add")) == "function", "UI_BUTTON_UNAVAILABLE")
            data.eventHandle = data.event:Add(function()
                if UI._data ~= data or not data.visible or UI._busy then return end
                local readOK, key = pcall(function() return data.input:GetText() end)
                if not readOK or type(key) ~= "string" then
                    UI.SetStatus("Unable to read the access key")
                    return
                end
                key = key:match("^%s*(.-)%s*$")
                if key == "" or #key > 512 then
                    UI.SetStatus("Enter a valid access key")
                    return
                end
                local submitOK = pcall(data.onSubmit, key)
                if not submitOK then
                    UI.SetBusy(false)
                    UI.SetStatus("Login could not start")
                end
            end)

            local slot = parent:AddChildToCanvas(data.container)
            assert(valid(slot), "UI_SLOT_UNAVAILABLE")
            slot:SetAutoSize(false)
            slot:SetSize(vector(W * UI._scale, H * UI._scale))
            
            slot:SetZOrder(100001)
            local anchors = slot:GetAnchors()
            anchors.Minimum, anchors.Maximum = vector(0.5, 0.5), vector(0.5, 0.5)
            slot:SetAnchors(anchors)
            slot:SetAlignment(vector(0.5, 0.5))
            slot:SetPosition(vector(0, 0))
            visibility(data.modalBlocker, visibleEnum)
            
            
            visibility(data.container, passive)
        end, debug.traceback)
        if not okBuild then
            detach(data)
            UI._lastError = tostring(buildError)
            print("[@ZONE_MOD] Key panel build error: " .. UI._lastError)
            return false, "UI_BUILD_ERROR"
        end
        data.visible = true
        UI._data = data
        UI.SetBusy(UI._busy)
        return true
    end
    function UI.ShowNotice(message)
        local shown, reason = UI.Show(function() return false end)
        if not shown then return false, reason end
        UI.SetStatus(message)
        UI.SetBusy(true)
        return true
    end
    return UI
end
return Module
end)()






local ZONE_MOD_KEY_GATE = (function()
    local GATE_KEY = "ZD-ZONE-1122"
    local Gate = {
        unlocked = (_G.ZONE_MOD_SAVED_KEY == GATE_KEY),
        lastUIError = nil
    }

    function Gate:IsUnlocked()
        return self.unlocked == true
    end

    function Gate:Unlock()
        self.unlocked = true
        if self.ui then
            self.ui.SetBusy(false)
            self.ui.Hide()
        end
    end

    function Gate:Submit(key)
        key = type(key) == "string" and key:match("^%s*(.-)%s*$") or ""
        if key == GATE_KEY then
            _G.ZONE_MOD_SAVED_KEY = key
            if _G.SaveModSettings then pcall(_G.SaveModSettings) end
            self:Unlock()
            return true
        end
        if self.ui then
            self.ui.SetBusy(false)
            self.ui.SetStatus("Invalid key. Enter the valid access key.")
        end
        return false
    end

    function Gate:Ensure()
        if self.unlocked then return true end

        if not self.ui then
            local ok, ui = xpcall(function()
                return ZONE_MOD_LoginUI.new(_G)
            end, debug.traceback)
            if not ok or type(ui) ~= "table" then
                self.lastUIError = tostring(ui or "UI_CONSTRUCTION_FAILED")
                print("[@ZONE_MOD] Key panel constructor error:\n" .. self.lastUIError)
                return false, "UI_CONSTRUCTION_FAILED"
            end
            self.ui = ui
        end

        local okShow, shown, reason = xpcall(function()
            return self.ui.Show(function(key)
                self:Submit(key)
            end)
        end, debug.traceback)
        if not okShow then
            self.lastUIError = tostring(shown)
            print("[@ZONE_MOD] Key panel Show error:\n" .. self.lastUIError)
            return false, "UI_SHOW_ERROR"
        end
        if not shown then
            self.lastUIError = reason or self.ui._lastError
            if self.lastUIError then
                print("[@ZONE_MOD] Key panel unavailable: " .. tostring(self.lastUIError))
            end
            return false, reason
        end
        self.ui.SetStatus("Enter your key")
        self.ui.SetBusy(false)
        return true
    end

    return Gate
end)()

_G.__ZONE_MOD_KEY_GATE = ZONE_MOD_KEY_GATE


local function FastTick()
    if isExpired then
        if not _G.LexusNotifiedExpire then
            Notify("مدت استفاده از نسخه به پایان رسیده است! برای تمدید با مدیر تماس بگیرید.")
            _G.LexusNotifiedExpire = true
            ExpiredTick()
        end
        return
    end

    if myToken ~= _G.LexusState.LoopToken then
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.10, FastTick)
        end
        return
    end

    
    if not ZONE_MOD_KEY_GATE:IsUnlocked() then
        local shown, reason = ZONE_MOD_KEY_GATE:Ensure()
        if not shown and reason then
            print("[@ZONE_MOD] Gate waiting: " .. tostring(reason))
        end
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and ticker.AddTimerOnce then
            ticker.AddTimerOnce(0.10, FastTick)
        end
        return
    end

    pcall(MainLoop)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.01, FastTick)
    end
end



FastTick()




local function InitAllModSystems()
    if isExpired then return end 

    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
    end)

    local GameplayData = package.loaded["GameLua.GameCore.Data.GameplayData"] or require("GameLua.GameCore.Data.GameplayData")
    if not GameplayData then return end

    pcall(function()
        local LocalPlayer = GameplayData.GetPlayerCharacter and GameplayData.GetPlayerCharacter()
        if slua.isValid(LocalPlayer) then
            if LocalPlayer.bHasShownDevNotice == nil then
                LocalPlayer.bHasShownDevNotice = false 
                LocalPlayer.bHasShownExpiredNotice = false 
                LocalPlayer.bIsDeadFlag = false
            end
        end
    end)
end

if not isExpired then
    pcall(function() 
        require("common.time_ticker").AddTimerOnce(0.5, InitAllModSystems) 
    end)
end





_G.BaseAttachToIndex = {
    [201010]=1, [201005]=1, [201004]=1, [201009]=2, [201003]=2, [201002]=2, 
    [201011]=3, [201007]=3, [201006]=3, [204012]=4, [204005]=4, [204008]=4, 
    [204011]=5, [204004]=5, [204007]=5, [204013]=6, [204006]=6, [204009]=6, 
    [203001]=7, [203002]=8, [203003]=9, [203014]=10, [203004]=11, [203015]=12, [203005]=13, 
    [202002]=14, [202001]=15, [202004]=16, [202005]=17, [202007]=18, [202006]=19, 
    [205002]=20, [205003]=20, [205001]=20, [203018]=21, [204014]=22 
}


_G.VIP_Attachments = {
    
    [1101004236]={1010042307,1010042306,1010042308,1010042304,1010042300,1010042305,1010042299,1010042298,1010042297,1010042296,1010042295,1010042294,0,1010042314,1010042309,1010042316,1010042317,1010042318,1010042310,1010042315,1010042319,0},
    [1101001116]={1010011106,1010011107,1010011108,0,1010011109,1010011112,1010011105,1010011104,1010011103,0,1010011102,0,0,0,0,0,0,0,0,0,0,0},
    [1101001128]={1010011232,1010011233,1010011234,1010011228,1010011227,1010011229,1010011226,1010011225,1010011224,1010011223,1010011222,0,0,0,0,0,0,0,0,0,0,0},
    [1101001154]={1010011487,1010011488,1010011489,1010011493,1010011490,1010011494,1010011486,1010011485,1010011484,1010011483,1010011482,1010011497,0,0,0,0,0,0,0,0,1010011498,0},
    [1101001174]={1010011667,1010011668,1010011669,1010011673,1010011670,1010011674,1010011666,1010011665,1010011664,1010011663,1010011662,0,0,0,0,0,0,0,0,0,0,0},
    [1101001213]={1010012067,1010012068,1010012069,1010012072,1010012070,1010012073,1010012066,1010012065,1010012064,1010012063,1010012062,0,0,0,0,0,0,0,0,0,1010012074,0},
    [1101001231]={1010012267,1010012268,1010012269,1010012273,1010012272,1010012274,1010012266,1010012265,1010012264,1010012263,1010012262,1010012075,0,0,0,0,0,0,0,0,1010012275,0},
    [1101001242]={1010012357,1010012358,1010012359,1010012363,1010012362,1010012364,1010012356,1010012355,1010012354,1010012353,1010012352,1010012276,0,0,0,0,0,0,0,0,1010012365,0},
    [1101001249]={1010012437,1010012438,1010012439,1010012443,1010012442,1010012444,1010012436,1010012435,1010012434,1010012433,1010012432,1010012366,0,0,0,0,0,0,0,0,1010012445,0},
    [1101001256]={1010012588,1010012589,1010012590,1010012593,1010012592,1010012594,1010012587,1010012586,1010012585,1010012584,1010012583,1010012582,0,0,0,0,0,0,0,0,1010012595,0},
    [1101001265]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101001276]={1010012698,1010012699,1010012700,1010012703,1010012702,1010012704,1010012697,1010012696,1010012695,1010012694,1010012693,1010012692,0,0,0,0,0,0,0,0,1010012705,0},
    [1101002029]={1010020249,1010020250,1010020255,1010020247,1010020246,1010020248,1010020240,1010020239,1010020238,1010020237,1010020236,1010020235,0,0,0,0,0,0,0,1010020257,1010020256,1010020258},
    [1101002056]={1010020519,0,0,1010020517,1010020516,1010020518,1010020500,1010020509,1010020508,1010020507,1010020506,1010020505,0,0,0,0,0,0,0,0,0,0},
    [1101002081]={1010020768,1010020769,1010020770,1010020766,1010020760,1010020767,1010020759,1010020758,1010020757,1010020756,1010020755,1010020776,0,0,0,0,0,0,0,1010020775,1010020777,1010020778},
    [1101003070]={1010030654,1010030653,1010030655,1010030649,1010030648,1010030650,1010030647,1010030646,1010030645,1010030644,1010030643,1010030642,0,1010030658,1010030656,1010030660,1010030662,1010030659,1010030657,0,1010030663,0},
    [1101003080]={1010030754,1010030753,1010030755,1010030749,1010030748,1010030750,1010030747,1010030746,1010030745,1010030744,1010030743,1010030742,0,1010030758,1010030756,1010030760,1010030762,1010030759,1010030757,0,1010030763,0},
    [1101003099]={1010030943,1010030944,1010030945,1010030939,1010030938,1010030942,1010030937,1010030936,1010030935,1010030934,1010030933,1010030932,0,1010030947,1010030946,1010030948,1010030949,1010030953,1010030952,0,1010030955,0},
    [1101003119]={1010031139,1010031140,1010031142,1010031138,1010031137,1010031146,1010031136,1010031135,1010031134,1010031133,1010031132,0,0,1010031144,1010031143,0,0,0,1010031145,0,0,0},
    [1101003146]={1010031229,1010031230,1010031237,1010031228,1010031227,1010031242,1010031226,1010031225,1010031224,1010031223,1010031222,0,0,1010031239,1010031238,0,0,0,1010031240,0,0,0},
    [1101003167]={1010031609,1010031610,1010031613,1010031608,1010031607,1010031617,1010031606,1010031605,1010031604,1010031603,1010031602,1010031618,0,1010031615,1010031614,1010031620,1010031622,1010031619,1010031616,0,1010031623,0},
    [1101003181]={1010031765,1010031764,1010031766,1010031759,1010031758,1010031763,1010031757,1010031756,1010031755,1010031754,1010031753,1010031752,0,1010031769,1010031767,1010031773,1010031774,1010031772,1010031768,0,1010031775,0},
    [1101003195]={1010031912,1010031911,1010031913,1010031908,1010031907,1010031909,1010031906,1010031905,1010031904,1010031903,1010031902,1010031901,0,1010031916,1010031914,1010031918,1010031919,1010031917,1010031915,0,1010031921,0},
    [1101003208]={1010032034,1010032033,1010032045,1010032029,1010032028,1010032032,1010032027,1010032026,1010032025,1010032024,1010032023,1010032022,0,1010032038,1010032036,1010032042,1010032043,1010032039,1010032037,0,1010032044,0},
    [1101004046]={1010040474,1010040475,1010040476,1010040472,1010040471,1010040473,1010040470,1010040469,1010040468,1010040467,1010040466,1010040481,0,1010040479,1010040477,1010040482,1010040483,1010040484,1010040478,1010040480,1010040485,0},
    [1101004062]={1010040578,1010040577,1010040579,1010040575,1010040570,1010040576,1010040569,1010040568,1010040567,1010040566,1010040565,1010040564,0,1010040585,1010040580,1010040587,1010040588,1010040589,1010040584,1010040586,1010040590,1010040594},
    [1101004098]={1010040924,1010040926,1010040925,0,1010040937,1010040938,1010040935,1010040934,1010040929,1010040928,1010040927,0,0,1010040939,1010040945,0,0,0,1010040944,1010040936,0,0},
    [1101004138]={1010041136,1010041137,1010041138,1010041134,1010041129,1010041135,1010041128,1010041127,1010041126,1010041125,1010041124,0,0,1010041145,1010041139,0,0,0,1010041144,1010041146,0,0},
    [1101004163]={1010041570,1010041574,1010041575,1010041568,1010041567,1010041569,1010041566,1010041565,1010041564,1010041560,1010041554,0,0,1010041578,1010041576,0,0,0,1010041577,1010041579,0,0},
    [1101004201]={1010041956,1010041957,1010041958,1010041950,1010041949,1010041955,1010041948,1010041947,1010041946,1010041945,1010041944,1010041967,0,1010041965,1010041959,0,0,0,1010041960,1010041966,0,0},
    [1101004209]={1010042038,1010042037,1010042039,1010042035,1010042034,1010042036,1010042029,1010042028,1010042027,1010042026,1010042025,1010042024,0,1010042046,1010042044,1010042048,1010042049,1010042054,1010042045,1010042047,1010042055,0},
    [1101004218]={1010042128,1010042127,1010042129,1010042125,1010042124,1010042126,1010042119,1010042118,1010042117,1010042116,1010042115,1010042114,0,1010042136,1010042134,1010042138,1010042139,1010042144,1010042135,1010042137,1010042145,0},
    [1101004226]={1010042238,1010042237,1010042239,1010042235,1010042234,1010042236,1010042233,1010042232,1010042231,1010042219,1010042218,1010042217,0,1010042243,1010042241,1010042245,1010042246,1010042247,1010042242,1010042244,1010042248,0},
    [1101004246]={1010042406,1010042407,1010042408,1010042404,1010042400,1010042405,1010042399,1010042398,1010042397,1010042396,1010042395,1010042394,0,1010042414,1010042409,1010042416,1010042417,1010042418,1010042410,1010042415,1010042419,1010042420},
    [1101005038]={0,0,1010050327,1010050329,1010050328,1010050330,1010050326,1010050325,1010050324,1010050323,1010050322,1010050334,0,0,0,0,0,0,0,0,0,0},
    [1101005052]={0,0,1010050467,1010050469,1010050468,1010050470,1010050466,1010050465,1010050464,1010050463,1010050462,1010050473,0,0,0,0,0,0,0,0,0,0},
    [1101005098]={0,0,1010050928,1010050930,1010050929,1010050932,1010050927,1010050926,1010050925,1010050924,1010050923,1010050922,0,0,0,0,0,0,0,0,0,0},
    [1101006062]={1010060573,1010060572,1010060574,1010060564,1010060563,1010060571,1010060562,1010060561,1010060554,1010060553,1010060552,1010060551,0,1010060583,1010060581,1010060591,1010060592,1010060584,1010060582,0,1010060593,0},
    [1101006075]={1010060702,1010060701,1010060703,1010060698,1010060697,1010060699,1010060696,1010060695,1010060694,1010060693,1010060692,1010060691,0,1010060706,1010060704,1010060708,1010060709,1010060707,1010060705,0,1010060711,0},
    [1101006085]={1010060796,1010060795,1010060797,1010060793,1010060789,1010060794,1010060788,1010060787,1010060786,1010060785,1010060784,1010060783,0,1010060800,1010060798,1010060804,1010060805,1010060803,1010060799,0,1010060806,0},
    [1101007046]={1010070410,1010070413,1010070414,1010070408,1010070407,1010070409,1010070406,1010070405,1010070404,1010070403,1010070402,1010070418,0,1010070417,1010070415,1010070420,1010070422,1010070419,1010070416,0,1010070423,0},
    [1101007062]={1010070579,1010070578,1010070581,1010070576,1010070575,1010070577,1010070574,1010070573,1010070572,1010070571,1010070569,1010070568,0,1010070584,1010070582,1010070585,1010070586,1010070587,1010070583,0,1010070588,0},
    [1101007071]={1010070663,1010070662,1010070664,1010070659,1010070658,1010070660,1010070657,1010070656,1010070655,1010070654,1010070653,1010070652,0,1010070667,1010070665,1010070668,1010070669,1010070670,1010070666,0,1010070672,0},
    [1101008051]={1010080463,1010080464,1010080465,1010080459,1010080458,1010080462,1010080457,1010080456,1010080455,1010080454,1010080453,1010080452,0,1010080467,1010080466,1010080468,1010080469,1010080473,1010080472,0,1010080475,0},
    [1101008061]={1010080563,1010080564,1010080565,1010080559,1010080558,1010080562,1010080557,1010080556,1010080555,1010080554,1010080553,0,0,1010080567,1010080566,0,0,0,1010080572,0,0,0},
    [1101008070]={1010080609,1010080612,1010080613,1010080608,1010080607,1010080617,1010080606,1010080605,1010080604,1010080603,1010080602,0,0,1010080615,1010080614,0,0,0,1010080616,0,0,0},
    [1101008081]={1010080740,1010080743,1010080745,1010080738,1010080737,1010080739,1010080736,1010080735,1010080734,1010080733,1010080732,1010080748,0,1010080747,1010080746,1010080750,1010080752,1010080749,1010080744,0,1010080753,0},
    [1101008104]={1010080980,1010080982,1010080984,1010080978,1010080977,1010080979,1010080976,1010080975,1010080974,1010080973,1010080972,1010080992,0,1010080986,1010080985,1010080989,1010080987,1010080993,1010080983,0,1010080988,0},
    [1101008116]={1010081110,1010081112,1010081114,1010081108,1010081107,1010081109,1010081106,1010081105,1010081104,1010081103,1010081102,0,0,1010081116,1010081115,0,0,0,1010081113,0,0,0},
    [1101008126]={1010081210,1010081225,1010081226,1010081208,1010081207,1010081209,1010081206,1010081205,1010081204,1010081203,1010081202,1010081218,0,1010081217,1010081216,1010081219,1010081220,1010081222,1010081214,1010081228,1010081227,1010081229},
    [1101008136]={1010081314,1010081315,1010081316,1010081312,1010081308,1010081313,1010081307,1010081306,1010081305,1010081304,1010081303,1010081302,0,1010081318,1010081317,1010081322,1010081323,1010081325,1010081324,0,1010081326,0},
    [1101008146]={1010081401,1010081402,1010081403,1010081398,1010081397,1010081399,1010081396,1010081395,1010081394,1010081393,1010081392,1010081391,0,1010081405,1010081404,1010081406,1010081407,1010081409,1010081408,0,1010081411,0},
    [1101008154]={1010081531,1010081532,1010081533,1010081528,1010081527,1010081529,1010081526,1010081525,1010081524,1010081523,1010081522,1010081521,0,1010081541,1010081534,1010081542,1010081543,1010081545,1010081544,0,1010081546,0},
    [1101008163]={1010081582,1010081583,1010081584,1010081579,1010081578,1010081580,1010081577,1010081576,1010081575,1010081574,1010081573,1010081572,0,1010081586,1010081585,1010081587,1010081588,1010081590,1010081589,0,1010081592,0},
    [1101012033]={1010120284,1010120285,1010120286,1010120280,1010120279,1010120283,1010120278,1010120277,1010120276,1010120275,1010120274,1010120273,0,0,0,0,0,0,0,0,1010120287,0},
    [1101100012]={1011000066,1011000067,1011000068,0,0,0,1011000058,1011000057,1011000056,1011000055,1011000054,1011000053,0,0,0,0,0,0,0,0,1011000073,0},
    [1101102007]={1011010025,1011010024,1011010026,1011010020,1011010019,1011010023,1011010018,1011010017,1011010016,1011010015,1011010014,1011010013,0,0,0,0,0,0,0,0,1011010027,0},
    [1101102017]={1011020027,1011020028,1011020029,1011020025,1011020024,1011020026,1011020019,1011020018,1011020017,1011020016,1011020015,1011020014,0,1011020036,1011020034,1011020038,1011020039,1011020044,1011020035,1011020037,1011020045,1011020047},
    [1101102025]={1011020127,1011020128,1011020129,1011020125,1011020124,1011020126,1011020119,1011020118,1011020117,1011020116,1011020115,1011020114,0,1011020136,1011020134,1011020138,1011020139,1011020144,1011020135,1011020137,1011020145,0},
    [1101102041]={1011020214,1011020215,1011020216,1011020212,1011020211,1011020213,1011020209,1011020208,1011020207,1011020206,1011020205,1011020204,0,1011020219,1011020217,1011020222,1011020223,1011020224,1011020218,1011020221,1011020225,1011020229},
    [1101102049]={1011020356,1011020357,1011020358,1011020354,1011020350,1011020355,1011020349,1011020348,1011020347,1011020346,1011020345,1011020344,0,1011020364,1011020359,1011020366,1011020367,1011020368,1011020360,1011020365,1011020369,1011020370},
    [1101101007]={1011020436,1011020437,1011020438,1011020434,1011020430,1011020435,1011020429,1011020428,1011020427,1011020426,1011020425,1011020424,0,1011020444,1011020439,1011020446,1011020447,1011020448,1011020440,1011020445,1011020449,1011020450},
    [1102001120]={1020011137,1020011138,1020011139,1020011135,1020011134,1020011136,1020011133,1020011132,0,0,0,0,0,0,0,0,0,0,0,1020011142,0,0},
    [1102001130]={1020011247,1020011248,1020011249,1020011245,1020011244,1020011246,1020011243,1020011242,0,0,0,0,0,0,0,0,0,0,0,1020011250,0,0},
    [1102002043]={1020020372,1020020374,1020020373,1020020383,1020020380,1020020384,1020020379,1020020378,1020020377,1020020376,1020020375,1020020388,0,1020020385,1020020387,0,0,0,1020020386,0,0,0},
    [1102002061]={1020020552,1020020554,1020020553,1020020563,1020020562,1020020564,1020020559,1020020558,1020020557,1020020556,1020020555,1020020578,0,1020020565,1020020567,1020020573,1020020574,1020020572,1020020566,0,1020020569,0},
    [1102002136]={1020021314,1020021313,1020021315,1020021309,1020021308,1020021312,1020021307,1020021306,1020021305,1020021304,1020021303,1020021302,0,1020021318,1020021316,1020021323,1020021324,1020021322,1020021317,0,1020021325,0},
    [1102002424]={1020024193,1020024192,1020024194,1020024189,1020024188,1020024190,1020024187,1020024186,1020024185,1020024184,1020024183,1020024182,0,1020024197,1020024195,1020024199,1020024200,1020024198,1020024196,0,1020024202,0},
    [1102003080]={1020030755,1020030756,1020030758,0,1020030749,1020030754,1020030748,1020030747,1020030746,1020030745,1020030744,1020030764,0,1020030760,0,1020030759,1020030757,0,0,1020030765,0,0},
    [1102003100]={1020030956,1020030957,1020030958,1020030954,1020030950,1020030955,1020030949,1020030948,1020030947,1020030946,1020030945,1020030944,0,1020030964,0,1020030960,1020030959,1020030965,0,1020030967,1020030966,1020030968},
    [1102005064]={1020050588,1020050589,1020050590,0,0,0,1020050587,1020050586,1020050585,1020050584,1020050583,1020050582,0,0,0,0,0,0,0,0,1020050592,0},
    [1103001101]={1030010954,1030010955,1030010956,0,0,0,0,0,0,0,1030010953,1030010952,1030010951,0,0,0,0,0,0,1030010957,0,1030010958},
    [1103001146]={1030011344,1030011345,1030011346,0,0,0,0,0,0,0,1030011343,1030011342,1030011341,0,0,0,0,0,0,1030011347,0,1030011348},
    [1103001154]={1030011484,1030011485,1030011486,0,0,0,0,0,0,0,1030011483,1030011482,1030011481,0,0,0,0,0,0,1030011487,0,1030011488},
    [1103001179]={1030011738,1030011739,1030011741,0,0,0,1030011737,1030011736,1030011735,1030011734,1030011733,1030011732,1030011731,0,0,0,0,0,0,1030011742,1030011743,1030011744},
    [1103001191]={1030011858,1030011859,1030011861,0,0,0,1030011857,1030011856,1030011855,1030011854,1030011853,1030011852,1030011851,0,0,0,0,0,0,1030011862,1030011863,1030011864},
    [1103001202]={1030011948,1030011949,1030011950,0,0,0,1030011947,1030011946,1030011945,1030011944,1030011943,1030011942,1030011941,0,0,0,0,0,0,1030011951,1030011952,1030011953},
    [1103002030]={1030020245,1030020246,1030020247,1030020252,1030020249,1030020253,1030020258,1030020257,1030020256,1030020255,1030020244,1030020243,1030020242,0,0,0,0,0,0,1030020248,0,0},
    [1103002059]={1030020544,1030020545,1030020546,1030020542,1030020539,1030020543,1030020538,1030020537,1030020536,1030020535,1030020534,1030020533,1030020532,0,0,0,0,0,0,1030020547,1030020548,0},
    [1103002087]={1030020824,1030020825,1030020826,0,0,0,1030020818,1030020817,1030020816,1030020815,1030020814,1030020813,1030020812,0,0,0,0,0,0,1030020827,1030020828,0},
    [1103002106]={1030021009,1030021010,1030021012,1030021015,1030021014,1030021016,1030021008,1030021007,1030021006,1030021005,1030021004,1030021003,1030021002,0,0,0,0,0,0,1030021013,1030021017,0},
    [1103002113]={1030021079,1030021080,1030021082,1030021085,1030021084,1030021086,1030021078,1030021077,1030021076,1030021075,1030021074,1030021073,1030021072,0,0,0,0,0,0,1030021083,1030021087,0},
    [1103003022]={1030030165,1030030166,1030030167,1030030172,1030030169,1030030173,0,0,0,0,1030030164,1030030163,1030030162,0,0,0,0,0,0,0,0,0},
    [1103003030]={1030030256,1030030257,1030030258,1030030254,1030030253,1030030255,1030030248,1030030247,1030030246,1030030245,1030030244,1030030243,1030030242,0,0,0,0,0,0,1030030259,1030030249,0},
    [1103003042]={1030030374,1030030375,1030030376,1030030372,1030030369,1030030373,0,0,0,0,1030030364,1030030363,1030030362,0,0,0,0,0,0,1030030377,0,0},
    [1103003051]={1030030458,1030030459,1030030460,1030030456,1030030455,1030030457,0,0,0,0,1030030454,1030030453,1030030452,0,0,0,0,0,0,1030030463,0,0},
    [1103003062]={1030030568,1030030569,1030030570,1030030566,1030030565,1030030567,0,0,0,0,1030030564,1030030563,1030030562,0,0,0,0,0,0,1030030572,0,0},
    [1103003079]={1030030744,1030030745,1030030746,1030030742,1030030740,1030030743,1030030738,1030030737,1030030736,1030030735,1030030734,1030030733,1030030732,0,0,0,0,0,0,1030030747,1030030739,0},
    [1103003087]={1030030825,1030030826,1030030827,1030030823,1030030824,1030030824,1030030818,1030030817,1030030816,1030030815,1030030814,1030030813,1030030812,0,0,0,0,0,0,1030030828,1030030819,0},
    [1103004037]={1030040315,1030040316,1030040317,1030040325,1030040324,1030040323,0,0,0,0,1030040314,1030040313,1030040312,1030040327,1030040326,0,0,0,1030040328,1030040329,0,0},
    [1103006030]={1030060245,1030060246,1030060247,0,1030060253,1030060252,0,0,0,0,1030060244,1030060243,1030060242,0,0,0,0,0,0,0,0,0},
    [1103007028]={1030070233,1030070234,1030070235,1030070226,1030070225,1030070227,1030070218,1030070217,1030070216,1030070215,1030070214,1030070213,1030070212,0,0,0,0,0,0,1030070236,1030070219,0},
    [1103012010]={0,0,0,0,0,0,1030120038,1030120037,1030120036,1030120035,1030120034,1030120033,1030120032,0,0,0,0,0,0,0,0,0},
    [1103012019]={0,0,0,0,0,0,1030120138,1030120137,1030120136,1030120135,1030120134,1030120133,1030120132,0,0,0,0,0,0,0,0,0},
    [1103012031]={0,0,0,0,0,0,1030120258,1030120257,1030120256,1030120255,1030120254,1030120253,1030120252,0,0,0,0,0,0,0,0,0},
    [1103012039]={0,0,0,0,0,0,1030120339,1030120338,1030120337,1030120336,1030120335,1030120334,1030120333,0,0,0,0,0,0,0,0,0},
    [1103102007]={1031020026,1031020027,1031020028,1031020024,1031020023,1031020025,1031020019,1031020018,1031020017,1031020016,1031020015,1031020014,1031020013,0,0,0,0,0,0,1031020029,0,0},
    [1105001034]={0,0,0,0,1050010287,1050010289,1050010286,1050010285,1050010284,1050010283,1050010282,0,0,0,0,0,0,0,0,1050010292,0,0},
    [1105001048]={0,0,0,1050010429,1050010428,1050010434,1050010427,1050010426,1050010425,1050010424,1050010423,0,0,0,0,0,0,0,0,1050010435,0,1050010436},
    [1105001069]={0,0,0,1050010639,1050010638,1050010640,1050010637,1050010636,1050010635,1050010634,1050010633,1050010645,0,0,0,0,0,0,0,1050010643,1050010646,1050010644},
    [1105002091]={0,0,0,0,0,0,1050020847,1050020846,1050020845,1050020844,1050020843,1050020842,0,0,0,0,0,0,0,0,0,1050020848},
    [1105010019]={0,0,0,0,0,0,1050100144,1050100143,1050100142,1050100141,1050100139,1050100138,0,0,0,0,0,0,0,0,0,0},
    
    [1101006098] = {1010060925,1010060926,1010060927,1010060919,0,1010060924,1010060918,1010060917,1010060916,1010060915,1010060914,1010060913,0,1010060930,1010060928,1010060929,1010060935,1010060934,1010060933,0,1010060936,0},

    
    [1101006106] = {1010061004,1010061005,1010061006,1010060999,1010061000,1010061003,1010060998,1010060997,1010060996,1010060995,1010060994,1010060993,0,1010061009,1010061007,1010061008,1010061014,1010061013,1010061010,0,1010061015,0},
}


local cached_GameplayStatics = nil
local cached_PlayerTombBox = nil
local cached_ActorClass = nil
_G.NeedCheckDeadBoxTimer = 0

_G.DeadBox_TemperRequest = function(PlayerController)
    if not _G.LexusConfig.SkinDeadBox or _G.NeedCheckDeadBoxTimer <= 0 then return end
    
    local curTime = os.clock()
    if _G.LastCheckDeadBoxTime and (curTime - _G.LastCheckDeadBoxTime) < 2.0 then return end
    _G.LastCheckDeadBoxTime = curTime
    _G.NeedCheckDeadBoxTimer = _G.NeedCheckDeadBoxTimer - 1

    local PlayerCharacter = PlayerController:GetPlayerCharacterSafety()
    if not slua.isValid(PlayerCharacter) then return end
    
    if not cached_GameplayStatics then
        cached_GameplayStatics = import("GameplayStatics")
        cached_ActorClass = import("Actor")
        cached_PlayerTombBox = import("PlayerTombBox")
    end
    
    if not _G.CachedActorArray_DB then
        _G.CachedActorArray_DB = slua.Array(UEnums.EPropertyClass.Object, cached_ActorClass)
    end
    
    local UI_Util = require("client.common.ui_util")
    local GameInstance = UI_Util and UI_Util.GetGameInstance()
    if not GameInstance or not cached_GameplayStatics then return end

    
    local myPlayerKey = PlayerController.PlayerKey
    local currentBoxSkinId = 0
    pcall(function()
        local curVeh = PlayerCharacter.CurrentVehicle or (type(PlayerCharacter.GetCurrentVehicle) == "function" and PlayerCharacter:GetCurrentVehicle())
        if slua.isValid(curVeh) and _G.CurrentEquipVehicleID and _G.CurrentEquipVehicleID ~= 0 then
            currentBoxSkinId = tonumber(tostring(_G.CurrentEquipVehicleID) .. "1") or 0
        else
            
            local curWeapon = PlayerCharacter.GetCurrentWeapon and PlayerCharacter:GetCurrentWeapon() or PlayerCharacter.CurrentWeapon
            if slua.isValid(curWeapon) then
                local defineIDObj = curWeapon.GetItemDefineID and curWeapon:GetItemDefineID()
                local curWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
                
                
                if curWeaponID > 0 and _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[curWeaponID] then
                    local skinID = _G.AddOutfitLastAppliedSkin[curWeaponID]
                    if skinID and skinID > 1000000 then 
                        currentBoxSkinId = skinID 
                    end
                end
            end
        end
    end)

    if currentBoxSkinId == 0 then return end

    local deadBoxes = cached_GameplayStatics.GetAllActorsOfClass(GameInstance, cached_PlayerTombBox, _G.CachedActorArray_DB)
    if not deadBoxes then return end
    
    local count = type(deadBoxes.Num) == "function" and deadBoxes:Num() or #deadBoxes
    for i = 1, count do
        local deadBoxActor = type(deadBoxes.Get) == "function" and deadBoxes:Get(i-1) or deadBoxes[i]
        if slua.isValid(deadBoxActor) and not deadBoxActor.bIsTDSkinApplied then
            local damageCauser = deadBoxActor.DamageCauser
            
            if slua.isValid(damageCauser) and damageCauser.PlayerKey == myPlayerKey then
                local DeadBoxAvatarComponent = deadBoxActor.DeadBoxAvatarComponent_BP
                if slua.isValid(DeadBoxAvatarComponent) then
                    pcall(function()
                        DeadBoxAvatarComponent:ResetItemAvatar()
                        DeadBoxAvatarComponent:PreChangeItemAvatar(currentBoxSkinId)
                        DeadBoxAvatarComponent:SyncChangeItemAvatar(currentBoxSkinId)
                    end)
                    deadBoxActor.bIsTDSkinApplied = true
                end
            end
        end
    end
end


local F = {}
local DEBUG = false  
function F.log(...)
    if DEBUG then print("[AddOutfit]", ...) end
end

local MATCH_CONFIG = {
    outfitRes = 0,        
    hatRes    = 0,        
    maskRes   = 0,
    glassRes  = 0,
    tshirtRes = 0,        
    pantsRes  = 0,        
    shoesRes  = 0,        
    bagRes    = 0,        
    helmetRes = 0,        
    weaponSkins = {},
}


local ITEMS = {
    
    
    
    703029, 703044, 703046, 703048, 1400010, 1400062, 1400070, 1400083, 1400100, 1400106, 1400112, 1400117, 1400134, 1407917, 1400170, 
    1400172, 1400173, 1400174, 1400175, 1400177, 1400179, 1400180, 1400228, 1400231, 1400233, 1400236, 1400237, 1400238, 1400242, 1400244,
    202408070, 202408071, 202408072, 202408073, 202408074, 202408075,
    1407905, 1407906, 1407907, 1407908, 1407909, 1407910, 1407911, 1407912, 1407913, 1407914, 1407915, 1407916, 1410585,
    
    
    
    
    1101004163, 
    1101004201, 
    1101004209, 
    1101004218, 
    1101004226, 
    1101004236, 
    1101004246, 
    1101004046, 
    1101004062, 
    1101004078, 
    1101004086, 
    1101004098, 
    1101004138, 

    
    1101001174, 
    1101001213, 
    1101001242, 
    1101001265, 
    1101001276, 
    1101001063, 
    1101001089, 
    1101001103, 
    1101001116, 
    1101001128, 
    1101001143, 
    1101001154, 
    1101001231, 
    1101001249, 
    1101001256, 
    1101001042, 
    1101001068, 

    
    1101003146, 
    1101003167, 
    1101003227, 
    1101003057, 
    1101003070, 
    1101003080, 
    1101003099, 
    1101003119, 
    1101003188, 
    1101003195, 
    1101003208, 
    1101003219, 
    1101003173, 
    1101003212, 

    
    1101008081, 
    1101008104, 
    1101008146, 
    1101008154, 
    1101008051, 
    1101008061, 
    1101008070, 
    1101008116, 
    1101008126, 
    1101008136, 
    1101008163, 
    1101008026, 
    1101008036, 

    
    1101006062, 
    1101006085, 
    1101006075, 
    1101006033, 
    1101006044, 
    1101006067, 

    
    1101005038, 
    1101005052, 
    1101005098, 
    1101005019, 
    1101005025, 
    1101005043, 
    1101005082, 
    1101005090, 
    1101005105, 

    
    1101007046, 
    1101007062, 
    1101007071, 
    1101007025, 
    1101007036, 
    1101007079, 
    1101009019, 
    1101010029, 
    1101012033, 
    1101012009, 
    1101012018, 
    1101012024, 
    1101100012, 
    1101100018, 
    1101101007, 
    1101102025, 
    1101102041, 
    1101102049, 
    1101102007, 
    1101102017, 
    1101102032, 

    
    1102001120, 
    1102001130, 
    1102001024, 
    1102001036, 
    1102001058, 
    1102001069, 
    1102001089, 
    1102001103, 
    1102001102, 
    1102002438, 
    1102002446, 
    1102002043, 
    1102002061, 
    1102002136, 
    1102002424, 
    1102002053, 
    1102002070, 
    1102002090, 
    1102002112, 
    1102002117, 
    1102002129, 
    1102002143, 
    1102003080, 
    1102003100, 
    1102003020, 
    1102003031, 
    1102003039, 
    1102003052, 
    1102003065, 
    1102003072, 
    1102003090, 
    1102004018, 
    1102004034, 
    1102004048, 
    1102005064, 
    1102005007, 
    1102005020, 
    1102005041, 
    1102005052, 
    1102005057, 
    1102005072, 
    1102005078, 
    1102007019, 
    1102007022, 
    1102105012, 
    1102105028, 
    1102105018, 

    
    1103001202, 
    1103001060, 
    1103001079, 
    1103001101, 
    1103001129, 
    1103001146, 
    1103001154, 
    1103001179, 
    1103001191, 
    1103001085, 
    1103001160, 
    1103001183, 
    1103002030, 
    1103002059, 
    1103002087, 
    1103002106, 
    1103002156, 
    1103002049, 
    1103002047, 
    1103002094, 
    1103003022, 
    1103003030, 
    1103003042, 
    1103003051, 
    1103003062, 
    1103003079, 
    1103003087, 
    1103003099, 
    1103003092, 
    1103004037, 
    1103004046, 
    1103004058, 
    1103004080, 
    1103004087, 
    1103005024, 
    1103005048, 
    1103009022, 
    1103009037, 
    1103009051, 
    1103009042, 
    1103006030, 
    1103006046, 
    1103006058, 
    1103006063, 
    1103006075, 
    1103007028, 
    1103007020, 
    1103007038, 
    1103007043, 
    1103012010, 
    1103012019, 
    1103012031, 
    1103012039, 
    1103012024, 
    1103100007, 
    1103102007, 
    1103103007, 

    
    1104001035, 
    1104002022, 
    1104002049, 
    1104003026, 
    1104003037, 
    1104003046, 
    1104004035, 
    1104004041, 
    1104004051, 
    1104004024, 
    1104102004, 
    1105001034, 
    1105001048, 
    1105001069, 
    1105001020, 
    1105001054, 
    1105001062, 
    1105001075, 
    1105002091, 
    1105002018, 
    1105002035, 
    1105002058, 
    1105002063, 
    1105002071, 
    1105002076, 
    1105002083, 
    1105002096, 
    1105010019, 
    1105010008, 
    1105010026, 

    
    1106008013, 
    1106008022, 
    1106011008, 
    1106011003, 
    1107001018, 
    1107098003, 
    1108001057, 
    1108001064, 
    1108001069, 
    1108001081, 
    1108001085, 
    1108001098, 
    1108001104, 
    1108002059, 
    1108004125, 
    1108004160, 
    1108004145, 
    1108004283, 
    1108004337, 
    1108004356, 
    1108004365, 
    1108004377, 
    1108004416, 
    1108005050, 

    
    
    
    
    1961007, 
    1961010, 
    1961012, 
    1961013, 
    1961014, 
    1961015, 
    1961147, 
    1961148, 
    1961149, 
    1907054, 
    1907058, 
    1907059, 

    
    1961016, 
    1961017, 
    1961018, 
    1961029, 
    1961030, 
    1961031, 
    1961032, 
    1903074, 
    1903075, 
    1903076, 

    
    1961020, 
    1961021, 
    1961024, 
    1961025, 
    1961144, 
    1961145, 
    1903079, 
    1903080, 
    1908066, 
    1908067, 

    
    1961041, 
    1961042, 
    1961043, 
    1961044, 
    1961045, 
    1961046, 
    1961047, 
    1961151, 
    1961152, 
    1961153, 

    
    1961048, 
    1961049, 
    1915005, 
    1915006, 
    1915007, 
    1908084, 
    1908085, 

    
    1961051, 
    1961052, 
    1961053, 
    1961054, 
    1961055, 
    1961056, 
    1961057, 

    
    1961137, 
    1961138, 
    1961139, 
    1903200, 
    1903201, 
    1908094, 
    1908095, 
    1915008, 
    1915009, 

    
    1961038, 
    1961039, 
    1961040, 
    1908075, 
    1908076, 
    1908077, 
    1908078, 

    
    1961036, 
    1961037, 
    1961050, 
    1961136, 
    1961150, 
    1903088, 
    1903089, 
    1903090, 
    1903189, 
    1903190, 
    1908086, 
    1908088, 
    1908089, 
    1908188, 
    1908189, 

    
    1961062, 
    1961063, 
    1961064, 
    1903218, 
    1903219, 
    1908108, 
    1908109, 
    1915021, 
    1915022, 

    
    1961058, 
    1961059, 
    1903210, 
    1903211, 
    1961068, 
    1961069, 

    
    1961060, 
    1961061, 

    
    1961065, 
    1961066, 
    1961067, 
    1903220, 
    1903221, 
    1903222, 
    1903223, 

    
    1961140, 
    1961141, 
    1961142, 
    1961143, 

    
    1903071, 
    1903072, 
    1903073, 

    
    1901073, 
    1901074, 
    1901075, 
    1901076, 

    
    
    
    
    1401000, 
    1401001, 
    1401002, 
    1401003, 
    1401005, 
    1401006, 
    1401007, 
    1401008, 
    1401009, 
    1401010, 
    1401011, 
    1401012, 
    1401013, 
    1401014, 
    1401015, 
    1401016, 
    1401017, 
    1401018, 
    1401019, 
    1401020, 
    1401021, 
    1401022, 
    1401023, 
    1401024, 
    1401025, 
    1401026, 
    1401027, 
    1401028, 
    1401029, 
    1401031, 
    1401032, 
    1401033, 
    1401034, 
    1401035, 
    1401036, 
    1401037, 
    1401038, 
    1401039, 
    1401040, 
    1401041, 
    1401043, 
    1401044, 
    1401045, 
    1401046, 
    1401047, 
    1401048, 
    1401050, 
    1401051, 
    1401052, 
    1401053, 
    1401054, 
    1401055, 
    1401056, 
    1401057, 
    1401059, 
    1401060, 
    1401061, 
    1401062, 
    1401063, 
    1401064, 
    1401065, 
    1401066, 
    1401067, 
    1401068, 
    1401071, 
    1401072, 
    1401074, 
    1401085, 
    1401086, 
    1401087, 
    1401088, 
    1401089, 
    1401090, 
    1401091, 
    1401092, 
    1401094, 
    1401095, 
    1401096, 
    1401097, 
    1401098, 
    1401100, 
    1401102, 
    1401103, 
    1401104, 
    1401106, 
    1401107, 
    1401108, 
    1401109, 
    1401111, 
    1401112, 
    1401113, 
    1401115, 
    1401117, 
    1401119, 
    1401122, 
    1401124, 
    1401125, 
    1401127, 
    1401128, 
    1401129, 
    1401130, 
    1401131, 
    1401133, 
    1401134, 
    1401135, 
    1401137, 
    1401138, 
    1401139, 
    1401140, 
    1401141, 
    1401142, 
    1401145, 
    1401146, 
    1401147, 
    1401148, 
    1401149, 
    1401150, 
    1401151, 
    1401152, 
    1401153, 
    1401154, 
    1401155, 
    1401156, 
    1401157, 
    1401159, 
    1401160, 
    1401161, 
    1401163, 
    1401164, 
    1401165, 
    1401167, 
    1401168, 
    1401169, 
    1401170, 
    1401171, 
    1401174, 
    1401177, 
    1401178, 
    1401179, 
    1401181, 
    1401182, 
    1401183, 
    1401184, 
    1401186, 
    1401187, 
    1401188, 
    1401189, 
    1401190, 
    1401191, 
    1401192, 
    1401193, 
    1401194, 
    1401195, 
    1401196, 
    1401197, 
    1401198, 
    1401200, 
    1401201, 
    1401204, 
    1401205, 
    1401208, 
    1401209, 
    1401210, 
    1401212, 
    1401213, 
    1401215, 
    1401216, 
    1401217, 
    1401218, 
    1401219, 
    1401220, 
    1401221, 
    1401222, 
    1401223, 
    1401224, 
    1401225, 
    1401227, 
    1401228, 
    1401231, 
    1401232, 
    1401233, 
    1401234, 
    1401235, 
    1401236, 
    1401237, 
    1401238, 
    1401239, 
    1401240, 
    1401241, 
    1401242, 
    1401243, 
    1401244, 
    1401245, 
    1401246, 
    1401247, 
    1401248, 
    1401249, 
    1401250, 
    1401252, 
    1401254, 
    1401255, 
    1401256, 
    1401257, 
    1401258, 
    1401259, 
    1401260, 
    1401261, 
    1401262, 
    1401263, 
    1401264, 
    1401265, 
    1401266, 
    1401267, 
    1401268, 
    1401269, 
    1401270, 
    1401271, 
    1401272, 
    1401273, 
    1401274, 
    1401275, 
    1401276, 
    1401277, 
    1401278, 
    1401280, 
    1401281, 
    1401282, 
    1401283, 
    1401284, 
    1401285, 
    1401286, 
    1401287, 
    1401289, 
    1401290, 
    1401291, 
    1401292, 
    1401294, 
    1401295, 
    1401296, 
    1401298, 
    1401299, 
    1401300, 
    1401301, 
    1401302, 
    1401303, 
    1401308, 
    1401309, 
    1401310, 
    1401311, 
    1401312, 
    1401313, 
    1401314, 
    1401315, 
    1401316, 
    1401317, 
    1401318, 
    1401319, 
    1401320, 
    1401323, 
    1401324, 
    1401325, 
    1401326, 
    1401330, 
    1401332, 
    1401334, 
    1401335, 
    1401336, 
    1401337, 
    1401338, 
    1401339, 
    1401340, 
    1401343, 
    1401345, 
    1401346, 
    1401347, 
    1401349, 
    1401351, 
    1401353, 
    1401355, 
    1401356, 
    1401357, 
    1401360, 
    1401361, 
    1401362, 
    1401363, 
    1401364, 
    1401365, 
    1401366, 
    1401367, 
    1401368, 
    1401369, 
    1401370, 
    1401371, 
    1401372, 
    1401373, 
    1401374, 
    1401375, 
    1401376, 
    1401377, 
    1401378, 
    1401379, 
    1401380, 
    1401381, 
    1401382, 
    1401383, 
    1401385, 
    1401386, 
    1401387, 
    1401388, 
    1401389, 
    1401390, 
    1401391, 
    1401392, 
    1401393, 
    1401394, 
    1401395, 
    1401396, 
    1401397, 
    1401398, 
    1401399, 
    1401400, 
    1401401, 
    1401402, 
    1401403, 
    1401404, 
    1401405, 
    1401406, 
    1401407, 
    1401408, 
    1401409, 
    1401410, 
    1401411, 
    1401412, 
    1401413, 
    1401416, 
    1401417, 
    1401418, 
    1401419, 
    1401420, 
    1401421, 
    1401422, 
    1401423, 
    1401424, 
    1401425, 
    1401426, 
    1401427, 
    1401428, 
    1401429, 
    1401430, 
    1401431, 
    1401432, 
    1401433, 
    1401434, 
    1401435, 
    1401436, 
    1401437, 
    1401438, 
    1401439, 
    1401440, 
    1401441, 
    1401442, 
    1401443, 
    1401444, 
    1401445, 
    1401446, 
    1401447, 
    1401448, 
    1401449, 
    1401450, 
    1401451, 
    1401452, 
    1401453, 
    1401454, 
    1401455, 
    1401456, 
    1401457, 
    1401458, 
    1401459, 
    1401460, 
    1401461, 
    1401462, 
    1401463, 
    1401464, 
    1401465, 
    1401466, 
    1401467, 
    1401468, 
    1401469, 
    1401470, 
    1401471, 
    1401472, 
    1401473, 
    1401474, 
    1401475, 
    1401476, 
    1401477, 
    1401478, 
    1401479, 
    1401480, 
    1401481, 
    1401482, 
    1401483, 
    1401484, 
    1401485, 
    1401486, 
    1401487, 
    1401488, 
    1401489, 
    1401490, 
    1401491, 
    1401492, 
    1401493, 
    1401494, 
    1401495, 
    1401496, 
    1401497, 
    1401498, 
    1401499, 
    1401500, 
    1401511, 
    1401513, 
    1401515, 
    1401516, 
    1401517, 
    1401519, 
    1401520, 
    1401521, 
    1401526, 
    1401527, 
    1401528, 
    1401529, 
    1401530, 
    1401531, 
    1401532, 
    1401534, 
    1401538, 
    1401540, 
    1401541, 
    1401542, 
    1401543, 
    1401544, 
    1401545, 
    1401546, 
    1401547, 
    1401548, 
    1401549, 
    1401551, 
    1401554, 
    1401555, 
    1401556, 
    1401610, 
    1401611, 
    1401613, 
    1401615, 
    1401616, 
    1401617, 
    1401618, 
    1401619, 
    1401620, 
    1401621, 
    1401622, 
    1401623, 
    1401624, 
    1401625, 
    1401628, 
    1401629, 
    1401811, 
    1401813, 
    1401814, 
    1401815, 
    1401816, 
    1401817, 
    1401820, 
    1401822, 
    1401823, 
    1401824, 
    1401826, 
    1401827, 
    1401828, 
    1401829, 
    1401832, 
    1401833, 
    1401835, 
    1401836, 
    1401837, 
    1401838, 
    1401839, 
    1401840, 
    1401841, 
    1401842, 
    1401843, 
    1401844, 
    1401845, 
    1401846, 

    
    4151001, 
    4151002, 
    4151003, 
    4151004, 
    4151006, 
    4151010, 
    4151012, 
    4151013, 
    4151014, 
    4151015, 
    4151017, 
    4151018, 
    4151019, 
    4151020, 
    4151021, 
    4151022, 
    4151023, 
    4151024, 
    4151025, 
    4151026, 
    4151027, 
    4151028, 
    4151029, 
    4151030, 
    4151031, 
    4151032, 
    4151034, 
    4151035, 
    4151036, 
    4151037, 
    4151038, 
    4151040, 
    4151041, 
    4151042, 
    4151043, 
    4151044, 
    4151045, 
    4151046, 
    4151056, 
    4151057, 
    4151058, 
    4151059, 
    4151060, 
    4151061, 
    4151062, 
    4151063, 
    4151064, 
    4151065, 
    4151066, 
    4151067, 
    4151068, 
    4151069, 
    4151070, 
    4151071, 
    4151072, 
    4151073, 
    4151074, 
    4151075, 
    4151076, 
    4151077, 
    4151078, 
    4151079, 
    4151080, 
    4151083, 
    4151084, 
    4151085, 
    4151086, 
    4151087, 
    4151089, 
    4151090, 
    4151091, 
    4151092, 
    4151093, 
    4151094, 
    4151095, 
    4151096, 
    4151097, 
    4151098, 
    4151099, 
    4151103, 
    4151104, 
    4151105, 
    4151106, 
    4151107, 
    4151108, 
    4151109, 
    4151110, 
    4151111, 
    4151112, 
    4151113, 
    4151114, 
    4151115, 
    4151117, 
    4151118, 
    4151119, 
    4151120, 
    4151121, 
    4151122, 
    4151123, 
    4151124, 
    4151125, 
    4151126, 
    4151127, 
    4151128, 
    4151129, 
    4151130, 
    4151131, 
    4151132, 
    4151133, 
    4151134, 
    4151135, 
    4151138, 
    4151139, 
    4151140, 
    4151141, 
    4151142, 
    4151143, 
    202408087,
    202408061,
    1102001001,
    4152031, 
    4152035, 
    4152036, 
    4152037, 
    4152038, 
    4152039, 
    4152041, 
    4152042, 
    4152043, 
    4152044, 
    4152045, 
    4152046, 
    4152058, 
    4152059, 
    4152060, 
    4152061, 
    4152063, 
    4152066, 
    4152067, 
    4152068, 
    4152069, 
    4152070, 
    4152076, 
    4152077, 
    4152078, 
    4152079, 
    4152080, 
    4152092, 
    4152093, 
    4152094, 
    4152095, 
    4152096, 
    4152097, 
    4152098, 
    4152099, 
    4152116, 

    
    
    
    
    1407895, 
    1407856, 
    1405628, 
    1406469, 
    1405870, 
    1407140, 
    1407142, 
    1407141, 
    1407550, 
    1406638, 
    1406641, 
    1406872, 
    1406971, 
    1407103, 
    1407219, 
    1407366, 
    1407512, 
    1407625, 
    1407667, 

    
    1407870, 
    1407871, 
    1407812, 
    1407758, 
    1407286, 
    1407329, 
    1407391, 
    1407392, 
    1407387, 
    1407440, 
    1406985, 
    1407470, 
    1407471, 
    1407522, 
    1407330, 
    1407523, 
    1407558, 
    1407559, 
    1407572, 
    1407682, 
    1407695, 
    1407696, 
    1407632, 
    1407573, 
    1406398, 
    1406399, 
    1406482, 
    1406483, 
    1406555, 
    1406573, 
    1406574, 
    1406656, 
    1406657, 
    1406742, 
    1406744, 
    1406789, 
    1406823, 
    1406824, 
    1406897, 
    1407277, 
    1406891, 
    1405623, 
    1400687, 
    1407618, 

    
    1406937, 
    1406938, 
    1406939, 
    1406947, 
    1406948, 
    1406950, 
    1406951, 
    1406952, 
    1406953, 
    1406954, 
    1407264, 
    1407265, 
    1407266, 
    1407267, 
    1407268, 
    1407269, 
    1407270, 
    1407271, 

    
    1406385, 
    1406386, 
    1406387, 
    1406388, 
    1406389, 

    
    1407563, 
    1407565, 
    1407566, 
    1407567, 
    1407568, 
    1407569, 

    
    1407672, 
    1407673, 
    1407674, 
    1407675, 
    1407676, 
    1407677, 
    1407678, 
    1407679, 

    
    1406132, 
    1406133, 
    1406134, 
    1406135, 
    1406161, 
    1406162, 
    1406163, 
    1406164, 
    1406178, 
    1406179, 
    1406180, 
    1406181, 
    1407346, 
    1407347, 
    1407348, 
    1407349, 
    1407350, 
    1407745, 
    1407746, 
    1407747, 
    1407748, 
    1407749, 
    1407750, 
    1407751, 
    1407826, 
    1407827, 
    1407828, 
    1407829, 
    1407687, 
    1407688, 

    
    1406648, 
    1406649, 
    1406728, 
    1406729, 
    1406730, 
    1406731, 
    1407206, 
    1407401, 
    1407402, 
    1407404, 
    1407405, 
    1407408, 
    1407769, 
    1407770, 
    1407771, 
    1407772, 
    1407773, 
    1407794, 
    1407795, 
    1407796, 
    1407798, 
    1407800, 
    1407801, 
    1407846, 
    1407848, 
    1407901, 
    1407902, 

    
    1405160, 
    1405161, 
    1405186, 
    1405662, 
    1405663, 
    1406020, 
    1406398, 
    1406399, 
    1406456, 
    1406568, 
    1406569, 
    1406732, 
    1406733, 
    1406764, 

    
    
    
    
    1400569, 
    1400650, 
    1400651, 
    1404000, 
    1404002, 
    1404003, 
    1404048, 
    1404049, 
    1404050, 
    1404051, 
    1404016, 
    1404017, 
    1404042, 
    1404043, 
    1404044, 
    1404045, 
    1404340, 
    1403038, 
    1403064, 

    
    402001, 
    402037, 
    402043, 
    402045, 
    1400158, 
    1402005, 
    1403100, 
    403010, 
    403028, 
    403181, 
    403182, 
    403183, 
    403192, 
    404006, 
    404008, 
    404013, 
    404015, 
    404026, 
    404028, 
    404084, 
    404100, 
    405001, 
    405002, 
    405019, 
    405044, 
    1400013, 

    
    1404142, 
    1404143, 
    1404218, 
    1404219, 
    1404326, 
    1404327, 
    1404405, 
    1404406, 
    1404411, 
    1404412, 
    1404413, 
    1404414, 
    1404426, 
    1404427, 
    1404428, 
    1404508, 
    1400324, 
    1400325, 
    452001, 452002, 452003, 
    
        
    12201301, 
    12216101, 
    12212201, 
    12219207, 
    12209001, 
    12219561, 
    12210001, 
    12219022, 
    12208801, 
    12210801, 
    12200701, 
    12219242, 
    12206001, 
    12205401, 
    12205201, 
    12212601, 
    12205601, 
    12219208, 
    12212001, 
    12206801, 
    12209801, 
    12211401, 
    12207001, 
    12211801, 
    12207901, 
    12203401, 
    12204001, 
    12201801, 
    12215601, 
    12215532, 
    12213201, 
    12215529, 
    12219053, 
    12204601, 
    12215701, 
    12219003, 
    12219004, 
    12219009, 
    12219216, 
    
    
    
    1404198, 1410085, 1404366, 1403137, 1410480, 1403028, 1400158, 40605011, 1404323, 1406001, 1403002,


    
    
    1502001183, 
    1502001194, 
    1502001093, 
    1502001305, 
    1502001320, 
    1502001105, 
    1502001364, 
    1502001373, 
    1502001402, 
    1502001403, 
    1502001427, 
    1502001443, 
    1502001450, 
    1502001471, 
    1502001480, 
    1502001490, 
    1502001495, 
    1502001001, 
    1502001004, 
    1502001005, 
    1502001046, 
    1502001058, 
    1502001064, 
    1502001073, 
    1502001078, 
    1502001086, 
    1502001099, 
    1502001115, 
    1502001133, 
    1502001145, 
    1502001154, 
    1502001175, 
    1502001230, 
    1502001248, 
    1502001264, 
    1502001276, 
    1502001294, 
    1502001301, 
    1502001357, 
    1502001381, 
    1502001416, 
    1502001453, 

    
    
    
    1501001174, 
    1501001220, 
    1501001265, 
    1501001548, 
    1501001559, 
    1501001567, 
    1501001577, 
    1501001607, 
    1501001061, 
    1501001062, 
    1501001082, 
    1501001112, 
    1501001133, 
    1501001243, 
    1501001273, 
    1501001304, 
    1501001331, 
    1501001340, 
    1501001376, 
    1501001400, 
    1501001463, 
    1501001476, 
    1501001480, 
    1501001487, 
    1501001521, 
    1501001539, 
    1501001540, 
    1501001554, 
    1501001587, 
    1501001597, 
    1501001632, 
    1501001643, 
    1501001650, 
    1501001683, 
    1501001715, 
    1501001720, 
    
        
    1501001024, 
    1502001014, 
    1502001439, 
    1502001069, 
    1502001023, 
    

    
    
    1400092, 1400101, 1400122, 
    1404191, 
    1405128, 1405129, 140224445, 140224445, 
    1407961, 1407962, 1407963, 1407964, 1407965, 1407966, 1407967, 1407968, 1407969, 1407970, 1407971, 1502001508, 1502002508, 1502003508, 1411134, 1411133, 1411135, 1403771, 1403770, 1407994, 1407993, 1101006106, 1101006098, 4151145, 1903230, 1903231, 1903232, 1908117, 1908118, 1908119, 19116002, 19116003, 19116004, 1961070, 1961071, 1961072, 1961073, 1408045, 1408038, 1407990,1407922, 
    1407704, 
    1400782, 
    1407614, 
    1407276, 
    1410356, 
    40605012, 
    401035, 
}

local INS_BASE = 2000000000
local PKG_SLOT = 3
local MELEE_ID = 108
local HAT_SUB = 401
local MASK_SUB = 402
local OUTFIT_SUB = 403
local PANTS_SUB = 404
local SHOES_SUB = 405
local GLASS_SUB = 407
local GLIDER_SUB = 415      
local GLOVES_SUB = 452
local GLIDER_SUBS = { [413] = true, [414] = true, [415] = true }

F.CUST_SLOT = {
    NONE = 0,
    HeadEquipemtSlot = 1,
    HairEquipemtSlot = 2,
    HatEquipemtSlot = 3,
    FaceEquipemtSlot = 4,
    ClothesEquipemtSlot = 5,
    PantsEquipemtSlot = 6,
    ShoesEquipemtSlot = 7,
    BackpackEquipemtSlot = 8,
    HelmetEquipemtSlot = 9,
    ArmorEquipemtSlot = 10,
    ParachuteEquipemtSlot = 11,
    GlassEquipemtSlot = 12,
    NightVisionEquipemtSlot = 13,
    BeardEquipemtSlot = 14,
    GlideEquipemtSlot = 15,
    HandEffectEquipemtSlot = 16,
    BackPack_PendantSlot = 17,
}
_G.CustSlotType = F.CUST_SLOT

local CHASSIS_LIGHT_SUB = 7302
local CHASSIS_LIGHT_IDS = { [7302001] = true, [7302002] = true }
local DEFAULT_CHASSIS_LIGHT = 7302002
local PARACHUTE_SUB = 701   
local DEFAULT_PARACHUTE_RES = 703001  
local TAB_SUIT = 10
local TAB_CLOTHES = 3
local PAGE_AVATAR = 1
local PAGE_VEHICLE = 6
local PAGE_PARACHUTE = 5
local HALL_THEME_TYPE = 202
local SUBTYPE_DEFAULT_TAB = {
    [401] = 1, [402] = 2, [403] = 10, [404] = 4, [405] = 5, [407] = 14,
    [501] = 15, [504] = 15, [502] = 16, [505] = 16,
}
local HAT_SUBS = { [401] = true }
local HELMET_SUBS = { [502] = true, [505] = true }
local HEAD_SUBS = { [401] = true } 
local BAG_SUBS = { [501] = true, [504] = true }
local FACE_SUBS = { [402] = true, [407] = true }
local BODY_SUBS = { [404] = true, [405] = true, [501] = true, [504] = true, [502] = true, [505] = true }
local GUN_SUB = { [101]=true, [102]=true, [103]=true, [104]=true, [105]=true, [106]=true, [107]=true }
local NET_OK = NetErrorCode_NONE or "ok"

local R = { insToRes = {}, resToIns = {}, byWeapon = {} }
local _matchApplied = false

_G.AddOutfitPersist = _G.AddOutfitPersist or { path = nil, dirty = false, scheduled = false, loaded = nil, lastWritten = nil, configVehicleSlots = nil, configWeapons = nil, configSlots = nil, lobbyVehicleSubType = nil, lobbyVehicleIns = nil, lobbyVehicleResID = nil, hallThemeResID = nil, hallThemeIns = nil, configChassisLight = nil, configChassisLightMap = nil }
local PERSIST = _G.AddOutfitPersist

F.persistMarkDirty = function() end

local PERF = {
    lobbySynced     = false,
    mappingsDirty   = true,
    desiredSkins    = nil,
    skinTarget      = {},
    matchActive     = false,
    lastBootstrapAt = 0,
    wearDoneThisMatch = false,  
}
local MATCH_TICK_SEC    = 3.0
local MATCH_MAX_SEC     = 45.0
local BOOTSTRAP_COOLDOWN = 2.0
local INJECT_RETRY_MAX  = 5
local INJECT_RETRY_SEC  = 3.0

function F.lobbyState()
    _G.AddOutfitLobbyState = _G.AddOutfitLobbyState or {
        wardrobeRefreshed = false,
        reapplyScheduled  = false,
        reapplyDone       = false,
        outfitResolved    = false,
        skinResolved      = false,
        cachedOutfit      = nil,
        cachedSkin        = nil,
        injectRefreshGen  = 0,
        lobbySynced       = false,
    }
    return _G.AddOutfitLobbyState
end

local LOBBY = setmetatable({}, {
    __index = function(_, k) return F.lobbyState()[k] end,
    __newindex = function(_, k, v) F.lobbyState()[k] = v end,
})

function F.invalidateLobbyResolved()
    LOBBY.outfitResolved = false
    LOBBY.skinResolved   = false
    LOBBY.cachedOutfit   = nil
    LOBBY.cachedSkin     = nil
end

function F.perfInvalidateLobby()
    LOBBY.lobbySynced   = false
    PERF.mappingsDirty = true
    PERF.desiredSkins  = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    F.invalidateLobbyResolved()
end

function F.cache()
    _G.AddOutfitEquippedCache = _G.AddOutfitEquippedCache or {
        outfitRes = nil, outfitIns = nil,
        hatRes = nil, hatIns = nil,
        maskRes = nil, maskIns = nil,
        glassRes = nil, glassIns = nil,
        tshirtRes = nil, tshirtIns = nil,
        pantsRes = nil, pantsIns = nil,
        shoesRes = nil, shoesIns = nil,
        bagRes = nil, bagIns = nil,
        helmetRes = nil, helmetIns = nil,
        weapons = {},
        vehicleSlots = {},  
        hallThemeRes = nil, hallThemeIns = nil,
        parachuteRes = nil, parachuteIns = nil,
        gliderRes = nil, gliderIns = nil,
        glovesRes = nil, glovesIns = nil,
    }
    return _G.AddOutfitEquippedCache
end

function F.cfg(resID)
    if not resID or not CDataTable or not CDataTable.GetTableData then return nil end
    return CDataTable.GetTableData("Item", resID)
end

function F.subType(c)
    return c and (c.ItemSubType or c.itemSubType) or nil
end

function F.wardrobeTab(resID)
    local c = F.cfg(resID)
    return c and tonumber(c.WardrobeTab) or 0
end

function F.depotResID(v)
    return v and tonumber(v.resID or v.res_id) or nil
end

function F.resToCustSlot(resID, st)
    resID, st = tonumber(resID), tonumber(st)
    if not resID or resID <= 0 then return nil end
    st = st or F.subType(F.cfg(resID))
    if st == HAT_SUB or HAT_SUBS[st] then return F.CUST_SLOT.HatEquipemtSlot end
    if st == OUTFIT_SUB then return F.CUST_SLOT.ClothesEquipemtSlot end
    if st == PANTS_SUB then return F.CUST_SLOT.PantsEquipemtSlot end
    if st == SHOES_SUB then return F.CUST_SLOT.ShoesEquipemtSlot end
    if st == MASK_SUB then return F.CUST_SLOT.FaceEquipemtSlot end
    if st == GLASS_SUB then return F.CUST_SLOT.GlassEquipemtSlot end
    if st == GLOVES_SUB then return F.CUST_SLOT.HandEffectEquipemtSlot end
    if BAG_SUBS[st] then return F.CUST_SLOT.BackpackEquipemtSlot end
    if HELMET_SUBS[st] then return F.CUST_SLOT.HelmetEquipemtSlot end
    if F.isParachuteRes(resID) or st == PARACHUTE_SUB then return F.CUST_SLOT.ParachuteEquipemtSlot end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then return F.CUST_SLOT.GlideEquipemtSlot end
    return nil
end

function F.isSuitRes(resID)
    if F.subType(F.cfg(resID)) ~= OUTFIT_SUB then return false end
    return F.wardrobeTab(resID) ~= TAB_CLOTHES
end

function F.isTshirtRes(resID)
    return F.subType(F.cfg(resID)) == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES
end

function F.weaponIdFromSkin(resID)
    local m = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("WeaponSkinMapping", resID)
    if not m then return nil end
    return m.WeaponID or m.WeaponId
end

function F.isValidWeaponId(weaponID)
    weaponID = tonumber(weaponID)
    if not weaponID or weaponID <= 0 then return false end
    if weaponID == MELEE_ID then return true end
    return weaponID >= 101000 and weaponID < 108000
end

function F.isValidWeaponPersistEntry(weaponID, resID)
    weaponID, resID = tonumber(weaponID), tonumber(resID)
    if not F.isValidWeaponId(weaponID) or not resID or resID <= 0 then return false end
    if weaponID == resID then return false end
    if resID >= 1800000 and resID < 1810000 then return false end
    if resID >= 1900000 and resID < 2000000 then return false end
    if F.isInjectedRes(resID) then
        local wid = tonumber(F.weaponIdFromSkin(resID))
        return wid and wid == weaponID
    end
    local wid = tonumber(F.weaponIdFromSkin(resID))
    return wid and wid == weaponID
end

function F.sanitizeConfigWeapons(wmap)
    if type(wmap) ~= "table" then return {} end
    local clean = {}
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        if F.isValidWeaponPersistEntry(wid, res) then clean[wid] = res end
    end
    return clean
end

function F.indexWeaponSkin(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    if not (GUN_SUB[st] or st == MELEE_ID) then return end
    local wid = F.weaponIdFromSkin(resID)
    wid = tonumber(wid)
    if not wid or wid <= 0 then return end
    R.byWeapon[wid] = R.byWeapon[wid] or {}
    R.byWeapon[wid][resID] = insID
end

function F.isInjectedIns(ins)
    return ins and R.insToRes[tonumber(ins)] ~= nil
end

function F.isInjectedRes(res)
    return res and R.resToIns[tonumber(res)] ~= nil
end

function F.isWeaponSkinRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    return GUN_SUB[st] or st == MELEE_ID
end

function F.isWeaponSkinIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local res = R.insToRes[insID]
    return res and F.isWeaponSkinRes(res)
end

function F.cleanArmoryPollution()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if not Arm.rsp_list then return end
        if Arm.rsp_list.install_list then
            for wid, entry in pairs(Arm.rsp_list.install_list) do
                local ins = tonumber(entry and entry.skin_id)
                if ins and not F.isWeaponSkinIns(ins) then
                    Arm.rsp_list.install_list[wid] = nil
                end
            end
        end
        if Arm.rsp_list.skin_list then
            for wid, skins in pairs(Arm.rsp_list.skin_list) do
                if type(skins) == "table" then
                    for resID in pairs(skins) do
                        if not F.isWeaponSkinRes(tonumber(resID)) then
                            skins[resID] = nil
                        end
                    end
                end
            end
        end
    end)
end

function F.depotSubType(insID, resID)
    resID = tonumber(resID) or tonumber(R.insToRes[insID])
    local st = F.subType(F.cfg(resID))
    if st then return st end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    return d and tonumber(d.itemSubType)
end

function F.tryLocalWearByIns(insID)
    insID = tonumber(insID)
    if not insID then return false end
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end 
    local resID = R.insToRes[insID]
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not resID and d then resID = tonumber(d.resID or d.res_id) end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)

    local function mapLocal()
        if not R.insToRes[insID] then
            R.insToRes[insID] = resID
            R.resToIns[resID] = insID
        end
    end

    if st == GLOVES_SUB then mapLocal(); F.putOnGloves(insID) return true end
    F.clearItemExpire(d, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if F.isParachuteRes(resID) then mapLocal(); return F.putOnParachute(insID) end
    if F.isGlideRes(resID) or GLIDER_SUBS[st] then mapLocal(); return F.putOnGlider(insID) end

    if st == OUTFIT_SUB then
        mapLocal()
        if F.isSuitRes(resID) or F.wardrobeTab(resID) == TAB_SUIT then
            F.putOnOutfit(insID)
        else
            F.putOnRoleWear(insID)
        end
        return true
    end
    if st == HAT_SUB or HEAD_SUBS[st] then mapLocal(); F.putOnHat(insID) return true end
    if FACE_SUBS[st] then mapLocal(); F.putOnFaceAccessory(insID) return true end
    if BODY_SUBS[st] or HELMET_SUBS[st] then mapLocal(); F.putOnRoleWear(insID) return true end

    if not F.isInjectedIns(insID) then return false end
    if GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.equipWeaponSkin(wid, insID) end
        return true
    end
    if st == MELEE_ID then F.equipWeaponSkin(MELEE_ID, insID) return true end
    if F.isHallThemeRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnHallTheme(insID)
    end
    if F.isVehicleRes(resID) and (F.isInjectedIns(insID) or F.isInjectedRes(resID)) then
        mapLocal()
        return F.putOnVehicle(insID)
    end
    return false
end

function F.isHallThemeRes(resID)
    local c = F.cfg(tonumber(resID))
    if not c then return false end
    local t = c.ItemType or c.itemType
    return t == HALL_THEME_TYPE
end

function F.isResourcesReady(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if not F.isInjectedRes(resID) then return true end
    local ready = false
    pcall(function()
        local PufferConst = require("client.slua.logic.download.puffer_const")
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and mgr.GetStateByItemID then
            local st = mgr:GetStateByItemID(resID)
            ready = st == PufferConst.ENUM_DownloadState.Done
        end
    end)
    return ready
end

function F.requestResourceDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isInjectedRes(resID) then return end
    if F.isResourcesReady(resID) then return end
    _G.AddOutfitDownloadQueued = _G.AddOutfitDownloadQueued or {}
    if _G.AddOutfitDownloadQueued[resID] then return end
    _G.AddOutfitDownloadQueued[resID] = true
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PM.Download(PufferConst.ENUM_DownloadType.ODPAK, { resID }, "AddOutfit", function()
            _G.AddOutfitDownloadQueued[resID] = nil
        end)
    end)
end

function F.ensureInjectedResources()
    for res in pairs(R.resToIns) do
        F.requestResourceDownload(tonumber(res))
    end
end

function F.restorePufferHooks()
    pcall(function()
        local mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
        if mgr and _G.AddOutfitPufferOrig then
            mgr.GetStateByItemID = _G.AddOutfitPufferOrig
        end
    end)
    pcall(function()
        local PM = require("client.slua.logic.download.puffer.puffer_manager")
        if PM and _G.AddOutfitPufferGetStateOrig then
            PM.GetState = _G.AddOutfitPufferGetStateOrig
        end
    end)
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local vacImpl = VAC and VAC.__inner_impl
        if vacImpl and _G.AddOutfitVehOrigAssets then
            vacImpl.LuaIsAssetsAlreadyAvailable = _G.AddOutfitVehOrigAssets
        end
    end)
end

function F.invalidateSocialWearCache()
    local s = _G.AddOutfitSocialState
    if s then
        s.wearPatchKey, s.snapshotKey, s.fullSnapshot, s.lastHandSkin = nil, nil, nil, nil
    end
end

function F.clearWeaponEquippedMark(weaponID)
    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if weaponID then
        _G.AddOutfitWeaponEquipped[tonumber(weaponID)] = nil
    else
        for k in pairs(_G.AddOutfitWeaponEquipped) do _G.AddOutfitWeaponEquipped[k] = nil end
    end
end

function F.isWeaponVisuallyEquipped(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID then return false end
    return _G.AddOutfitWeaponEquipped and _G.AddOutfitWeaponEquipped[weaponID] == insID
end

function F.saveWeaponToCache(weaponID, resID, insID)
    F.clearWeaponEquippedMark(weaponID)
    weaponID, resID, insID = tonumber(weaponID), tonumber(resID), tonumber(insID)
    if not F.isValidWeaponPersistEntry(weaponID, resID) then return end
    local cch = F.cache()
    cch.weapons[weaponID] = { resID = resID, insID = insID or 0 }
    PERSIST.configWeapons = PERSIST.configWeapons or {}
    PERSIST.configWeapons[weaponID] = resID
    _G.AddOutfitLastAppliedSkin = {}
    _matchApplied = false
    F.perfInvalidateLobby()
    F.invalidateSocialWearCache()
    F.persistMarkDirty()
    F.log("ذاكرة سكن", weaponID, "→", resID)
end

function F.cacheWeaponSkinFromIns(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or insID <= 0 then return end
    if F.isInjectedIns(insID) then
        F.saveWeaponToCache(weaponID, R.insToRes[insID], insID)
        return
    end
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        if d and d.resID and tonumber(d.resID) > 0 then
            F.saveWeaponToCache(weaponID, tonumber(d.resID), insID)
        end
    end)
end

function F.saveEquip(resID, insID)
    resID, insID = tonumber(resID), tonumber(insID)
    if not resID or not insID then return end
    local c = F.cfg(resID)
    local st = F.subType(c)
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = resID, insID
            _G.AddOutfitLastLobbyTshirtRes = resID
            F.persistRememberSlot("tshirt", resID)
        else
            cch.outfitRes, cch.outfitIns = resID, insID
            _G.AddOutfitLastLobbyOutfitRes = resID
            F.persistRememberSlot("outfit", resID)
            F.invalidateSocialWearCache()
        end
    elseif st == HAT_SUB then
        cch.hatRes, cch.hatIns = resID, insID
        _G.AddOutfitLastLobbyHatRes = resID
        F.persistRememberSlot("hat", resID)
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = resID, insID
        _G.AddOutfitLastLobbyMaskRes = resID
        F.persistRememberSlot("mask", resID)
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = resID, insID
        _G.AddOutfitLastLobbyGlassRes = resID
        F.persistRememberSlot("glass", resID)
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = resID, insID
        _G.AddOutfitLastLobbyPantsRes = resID
        F.persistRememberSlot("pants", resID)
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = resID, insID
        _G.AddOutfitLastLobbyShoesRes = resID
        F.persistRememberSlot("shoes", resID)
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = resID, insID
        _G.AddOutfitLastLobbyBagRes = resID
        F.persistRememberSlot("bag", resID)
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = resID, insID
        _G.AddOutfitLastLobbyHelmetRes = resID
        F.persistRememberSlot("helmet", resID)
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = resID, insID
        _G.AddOutfitLastLobbyParachuteRes = resID
        F.persistRememberSlot("parachute", resID)
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = resID, insID
        _G.AddOutfitLastLobbyGliderRes = resID
        F.persistRememberSlot("glider", resID)
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = resID, insID
        _G.AddOutfitLastLobbyGlovesRes = resID
        F.persistRememberSlot("gloves", resID)
    elseif GUN_SUB[st] then
        local wid = F.weaponIdFromSkin(resID)
        if wid then F.saveWeaponToCache(wid, resID, insID) end
    elseif st == MELEE_ID then
        F.saveWeaponToCache(MELEE_ID, resID, insID)
    end
    _matchApplied = false
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.findWornInsBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return nil end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    return ins, res
                end
            end
        end
    end
    return nil
end

function F.syncHatCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(HAT_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.hatRes, cch.hatIns = tonumber(res), ins
            return
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        local headIns = tonumber(bag and bag.head_show) or 0
        if headIns <= 0 then return end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(headIns) or wd:GetHallDepotItemDataByInsID(headIns)
        if not d or not d.resID or tonumber(d.resID) <= 0 then return end
        local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
        if HEAD_SUBS[st] then
            cch.hatRes, cch.hatIns = tonumber(d.resID), headIns
        end
    end)
end

function F.syncFaceCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(MASK_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.maskRes, cch.maskIns = tonumber(res), ins
            _G.AddOutfitLastLobbyMaskRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLASS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glassRes, cch.glassIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlassRes = tonumber(res)
        end
    end)
end

function F.syncBodyCacheFromLobby()
    local cch = F.cache()
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.wardrobeTab(r) == TAB_CLOTHES end)
        if ins and res and tonumber(res) > 0 then
            cch.tshirtRes, cch.tshirtIns = tonumber(res), ins
            _G.AddOutfitLastLobbyTshirtRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(PANTS_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.pantsRes, cch.pantsIns = tonumber(res), ins
            _G.AddOutfitLastLobbyPantsRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(SHOES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.shoesRes, cch.shoesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyShoesRes = tonumber(res)
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(GLOVES_SUB)
        if ins and res and tonumber(res) > 0 then
            cch.glovesRes, cch.glovesIns = tonumber(res), ins
            _G.AddOutfitLastLobbyGlovesRes = tonumber(res)
        end
    end)
    pcall(function()
        for st in pairs(BAG_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.bagRes, cch.bagIns = tonumber(res), ins
                _G.AddOutfitLastLobbyBagRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        for st in pairs(HELMET_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res and tonumber(res) > 0 then
                cch.helmetRes, cch.helmetIns = tonumber(res), ins
                _G.AddOutfitLastLobbyHelmetRes = tonumber(res)
                break
            end
        end
    end)
    pcall(function()
        local ins, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        if ins and res and tonumber(res) > 0 then
            cch.outfitRes, cch.outfitIns = tonumber(res), ins
            _G.AddOutfitLastLobbyOutfitRes = tonumber(res)
        end
    end)
end

function F.syncAirborneCacheFromLobby(saveToConfig)
    local cch = F.cache()
    local cfgPara = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    local cfgGlide = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    local changed = false

    local function maybeSave(slotName, res)
        if not saveToConfig or not res or res <= 0 then return end
        if slotName == "parachute" and res == DEFAULT_PARACHUTE_RES
            and cfgPara and cfgPara > 0 and cfgPara ~= DEFAULT_PARACHUTE_RES then
            return
        end
        F.persistRememberSlot(slotName, res)
        changed = true
    end

    local function applyPara(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isParachuteRes(res) then return end
        if cfgPara and cfgPara > 0 and not saveToConfig then
            if res == cfgPara then cch.parachuteIns = ins end
            return
        end
        if res == DEFAULT_PARACHUTE_RES and not saveToConfig then return end
        if cch.parachuteRes ~= res or cch.parachuteIns ~= ins then
            cch.parachuteRes, cch.parachuteIns = res, ins
            _G.AddOutfitLastLobbyParachuteRes = res
            maybeSave("parachute", res)
        end
    end

    local function applyGlide(res, ins)
        res, ins = tonumber(res), tonumber(ins)
        if not res or not ins or not F.isGlideRes(res) then return end
        if cfgGlide and cfgGlide > 0 and not saveToConfig then
            if res == cfgGlide then cch.gliderIns = ins end
            return
        end
        if cch.gliderRes ~= res or cch.gliderIns ~= ins then
            cch.gliderRes, cch.gliderIns = res, ins
            _G.AddOutfitLastLobbyGliderRes = res
            maybeSave("glider", res)
        end
    end

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local paraIns = tonumber(fbd.GetParachute and fbd:GetParachute()) or 0
        if paraIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(paraIns) or wd:GetHallDepotItemDataByInsID(paraIns)
            applyPara(d and tonumber(d.resID), paraIns)
        end
        local glideIns = tonumber(fbd.GetAircraftOrGliding and fbd:GetAircraftOrGliding()) or 0
        if glideIns > 0 then
            local d = wd:GetValidHallDepotItemDataByInsID(glideIns) or wd:GetHallDepotItemDataByInsID(glideIns)
            applyGlide(d and tonumber(d.resID), glideIns)
        end
    end)
    pcall(function()
        for st in pairs(GLIDER_SUBS) do
            local ins, res = F.findWornInsBySubType(st)
            if ins and res then applyGlide(res, ins) break end
        end
        local ins, res = F.findWornInsBySubType(PARACHUTE_SUB)
        if ins and res then applyPara(res, ins) end
    end)
    if changed then F.persistMarkDirty() end
end

function F.syncWeaponCacheFromLobby(force)
    if LOBBY.lobbySynced and not force then return end
    LOBBY.lobbySynced = true
    PERF.mappingsDirty = true
    PERF.desiredSkins = nil
    for k in pairs(PERF.skinTarget) do PERF.skinTarget[k] = nil end
    local cch = F.cache()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.weapon_skin_list then
            for weaponID, entry in pairs(bag.weapon_skin_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and (entry.skin_id or entry.skinId)) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm.rsp_list and Arm.rsp_list.install_list then
            for weaponID, entry in pairs(Arm.rsp_list.install_list) do
                weaponID = tonumber(weaponID)
                local insID = tonumber(entry and entry.skin_id) or 0
                if weaponID and weaponID > 0 and insID > 0 then
                    local res
                    if F.isInjectedIns(insID) then
                        res = tonumber(R.insToRes[insID])
                    else
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(insID)
                            or wd:GetHallDepotItemDataByInsID(insID)
                        res = d and tonumber(d.resID)
                    end
                    if res and res > 0 and F.isValidWeaponPersistEntry(weaponID, res) then
                        cch.weapons[weaponID] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end)
    F.syncHatCacheFromLobby()
    F.syncFaceCacheFromLobby()
    F.syncBodyCacheFromLobby()
end

function F.getCachedWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    if weaponID <= 0 then return nil end
    F.syncWeaponCacheFromLobby()
    local w = F.cache().weapons[weaponID]
    if w and w.resID and w.resID > 0 then return w.resID end
    return nil
end

function F.getMatchWeaponSkin(weaponID)
    weaponID = tonumber(weaponID) or 0
    local fromCache = F.getCachedWeaponSkin(weaponID)
    if fromCache then return fromCache end
    if MATCH_CONFIG.weaponSkins then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponID])
        if fixed and fixed > 0 then return fixed end
    end
    return nil
end

function F.removeRoleWearBySubType(st, filterFn)
    st = tonumber(st)
    if not st then return end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local AvatarData = require("client.logic.data.AvatarData")
    for _, ins in pairs(AvatarData.GetRoleWear()) do
        ins = tonumber(ins)
        if ins and ins > 0 then
            local d = wd:GetHallDepotItemDataByInsID(ins)
            if d and tonumber(d.itemSubType) == st then
                local res = tonumber(d.resID)
                if not filterFn or filterFn(res, d) then
                    AvatarData.RemoveRoleWearDataByValue(ins)
                end
            end
        end
    end
end

function F.syncFashionBagRolewear()
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SaveRolewearToFashionBag(fbd:GetFashionBagUseIndex())
    end)
end

local _ticker
pcall(function() _ticker = require("common.time_ticker") end)
function F.later(sec, fn)
    if _G.SetTimer then pcall(_G.SetTimer, sec, fn) return end
    if _ticker and _ticker.AddTimer then pcall(_ticker.AddTimer, sec, fn) end
end

function F.getPC()
    if slua_GameFrontendHUD then
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if ok and gd then
        local pc = gd.GetPlayerController()
        if slua.isValid(pc) then return pc end
    end
    return nil
end

function F.syncVehicleSlotsToDataMgr()
    local cch = F.cache()
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        local arr = DataMgr.VehicleSlotList[subType]
        if not arr then arr = {}; DataMgr.VehicleSlotList[subType] = arr end
        for k in pairs(arr) do arr[k] = nil end
        for idx, e in pairs(slots or {}) do
            if e and tonumber(e.insID) and tonumber(e.insID) > 0 then
                arr[tonumber(idx)] = tonumber(e.insID)
            end
        end
    end
end

function F.mergeInjectedIntoVehicleSlotList(serverList)
    serverList = serverList or {}
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            local arr = serverList[subType]
            if not arr then arr = {}; serverList[subType] = arr end
            for idx, e in pairs(slots) do
                idx = tonumber(idx)
                local insID = e and tonumber(e.insID)
                if idx and insID and insID > 0 and F.isInjectedIns(insID) then
                    arr[idx] = insID
                end
            end
        end
    end
    local cfg = PERSIST.configVehicleSlots
    if cfg then
        for subType, slotMap in pairs(cfg) do
            subType = tonumber(subType)
            if subType and type(slotMap) == "table" then
                local arr = serverList[subType]
                if not arr then arr = {}; serverList[subType] = arr end
                for idx, res in pairs(slotMap) do
                    idx, res = tonumber(idx), tonumber(res)
                    local ins = res and R.resToIns[res]
                    if idx and ins and F.isInjectedIns(ins) then
                        arr[idx] = ins
                    end
                end
            end
        end
    end
    return serverList
end

function F.applyVehicleSlotsFromConfigMap(slotMap)
    if not slotMap or not next(slotMap) then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local any = false
    for subType, slots in pairs(slotMap) do
        subType = tonumber(subType)
        if subType then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, res in pairs(slots) do
                idx, res = tonumber(idx), tonumber(res)
                local ins = res and R.resToIns[res]
                if idx and ins then
                    cch.vehicleSlots[subType][idx] = { resID = res, insID = ins }
                    any = true
                end
            end
        end
    end
    return any
end

function F.notifyVehicleSlotUI()
    pcall(function()
        local WRH = require("client.network.Protocol.WardrobeNewHandler")
        WRH.on_depot_modify_combat_vehicle_rsp(0, DataMgr.VehicleSlotList or {})
    end)
end

function F.mergeInjectedVehicleSkinTable(serverTable)
    serverTable = serverTable or {}
    local cfg = PERSIST.configVehicleSlots
    if not cfg then return serverTable end
    for subType, slotMap in pairs(cfg) do
        subType = tonumber(subType)
        if subType and type(slotMap) == "table" then
            local res = tonumber(slotMap[1] or slotMap["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                serverTable[subType] = ins
            end
        end
    end
    local cch = F.cache()
    for subType, slots in pairs(cch.vehicleSlots or {}) do
        subType = tonumber(subType)
        local e = slots and (slots[1] or slots["1"])
        local insID = e and tonumber(e.insID)
        if subType and insID and insID > 0 and F.isInjectedIns(insID) then
            serverTable[subType] = insID
        end
    end
    return serverTable
end

function F.equipVehicleTypesFromConfig(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
    local subTypes = {}
    for st in pairs(slotMap) do
        local n = tonumber(st)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    local any, lobbyRes, lobbyIns = false, nil, nil
    for _, subType in ipairs(subTypes) do
        local slots = slotMap[subType] or slotMap[tostring(subType)]
        if type(slots) == "table" then
            local res = tonumber(slots[1] or slots["1"])
            local ins = res and R.resToIns[res]
            if ins and F.isInjectedIns(ins) then
                DataMgr.vehicleSkinInsIDTable[subType] = ins
                any = true
                if not lobbyIns then
                    lobbyRes, lobbyIns = res, ins
                end
            end
        end
    end
    if any then
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    return any, lobbyRes, lobbyIns
end

function F.applyLobbyVehicleDisplay(resID, insID, showVehicle)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or insID <= 0 then return end
    _G.AddOutfitApplyingConfig = true
    pcall(function() DataMgr.vst_skin = insID end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        HallThemeUtils.ProcPutOnVehicle({ res_id = resID, instid = insID }, showVehicle ~= false)
    end)
    pcall(F.applyVehicleSkinsToPC)
    _G.AddOutfitApplyingConfig = false
end

function F.setLobbyVehicleManual(subType, resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    subType = tonumber(subType)
    if not insID then return end
    if F.isChassisLightId(resID) or subType == CHASSIS_LIGHT_SUB then return end
    if resID and not F.isVehicleRes(resID) then return end
    if not F.isInjectedIns(insID) and not F.isVehicleRes(resID) then return end
    if not resID then resID = R.insToRes[insID] end
    if not subType and resID then subType = tonumber(F.vehicleSubType(resID)) end
    _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
    _G.AddOutfitLobbyVeh.manual = true
    _G.AddOutfitLobbyVeh.subType = subType
    _G.AddOutfitLobbyVeh.resID = resID
    _G.AddOutfitLobbyVeh.insID = insID
    PERSIST.lobbyVehicleSubType = subType
    PERSIST.lobbyVehicleIns = insID
    PERSIST.lobbyVehicleResID = resID
    F.persistMarkDirty()
end

function F.resolveLobbyVehicle(slotMap)
    slotMap = slotMap or PERSIST.configVehicleSlots
    local L = _G.AddOutfitLobbyVeh or {}
    local st = tonumber(PERSIST.lobbyVehicleSubType) or tonumber(L.subType)
    local res = tonumber(PERSIST.lobbyVehicleResID) or tonumber(L.resID)
    if res and res > 0 then
        local ins = R.resToIns[res]
        if ins then
            if not st then st = tonumber(F.vehicleSubType(res)) end
            return res, ins, st
        end
    end
    local ins = tonumber(PERSIST.lobbyVehicleIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then
        res = R.insToRes[ins] or res
        if not st and res then st = tonumber(F.vehicleSubType(res)) end
        return res, ins, st
    end
    if st and slotMap then
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    local subTypes = {}
    for s in pairs(slotMap or {}) do
        local n = tonumber(s)
        if n then subTypes[#subTypes + 1] = n end
    end
    table.sort(subTypes)
    if subTypes[1] then
        st = subTypes[1]
        local slots = slotMap[st] or slotMap[tostring(st)]
        local res = slots and tonumber(slots[1] or slots["1"])
        ins = res and R.resToIns[res]
        if ins then return res, ins, st end
    end
    return nil, nil, nil
end

function F.syncLobbyVehicleResFromIns()
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0 then return end
    local ins = tonumber(PERSIST.lobbyVehicleIns)
    if ins and R.insToRes[ins] then
        PERSIST.lobbyVehicleResID = R.insToRes[ins]
        F.persistMarkDirty()
    end
end

function F.hasExplicitLobbyVehicle()
    local res = tonumber(PERSIST.lobbyVehicleResID)
    local st = tonumber(PERSIST.lobbyVehicleSubType)
    if F.isChassisLightId(res) or st == CHASSIS_LIGHT_SUB then return false end
    if res and res > 0 and not F.isVehicleRes(res) then return false end
    if res and res > 0 then return true end
    if (tonumber(PERSIST.lobbyVehicleIns) or 0) > 0 then return true end
    local L = _G.AddOutfitLobbyVeh
    if L and L.manual and ((tonumber(L.resID) or 0) > 0 or (tonumber(L.insID) or 0) > 0) then return true end
    return false
end

function F.shouldApplyLobbyFromConfig(silent)
    if not F.hasExplicitLobbyVehicle() then return false end
    local _, lobbyIns = F.resolveLobbyVehicle(PERSIST.configVehicleSlots)
    if not lobbyIns then return false end
    local cur = tonumber(DataMgr.vst_skin)
    if cur == lobbyIns then return false end
    return true
end

function F.reapplyVehicleSlotsFromConfig(silent)
    local slotMap = PERSIST.configVehicleSlots
    if not slotMap or not next(slotMap) then return false end
    if not F.applyVehicleSlotsFromConfigMap(slotMap) then return false end
    F.syncVehicleSlotsToDataMgr()
    F.notifyVehicleSlotUI()
    F.equipVehicleTypesFromConfig(slotMap)
    if F.shouldApplyLobbyFromConfig(silent) then
        local lobbyRes, lobbyIns = F.resolveLobbyVehicle(slotMap)
        if lobbyIns then
            F.applyLobbyVehicleDisplay(lobbyRes, lobbyIns, not silent)
        elseif not silent then
            pcall(F.applyVehicleSkinsToPC)
            F.perfInvalidateLobby()
        end
    end
    return true
end

function F.applyHallThemeDisplay(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not resID then return false end
    if not F.isInjectedIns(insID) then return false end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    _G.AddOutfitApplyingTheme = true
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        HT.ProcPutOnHallTheme({ res_id = resID, instid = insID }, nil)
    end)
    _G.AddOutfitApplyingTheme = false
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    return true
end

function F.setHallThemeManual(resID, insID)
    insID = tonumber(insID)
    resID = tonumber(resID)
    if not insID or not F.isInjectedIns(insID) then return end
    if not resID then resID = R.insToRes[insID] end
    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
    _G.AddOutfitLobbyTheme.manual = true
    _G.AddOutfitLobbyTheme.resID = resID
    _G.AddOutfitLobbyTheme.insID = insID
    PERSIST.hallThemeResID = resID
    PERSIST.hallThemeIns = insID
    local cch = F.cache()
    cch.hallThemeRes, cch.hallThemeIns = resID, insID
    F.persistMarkDirty()
end

function F.resolveHallTheme()
    local L = _G.AddOutfitLobbyTheme or {}
    local res = tonumber(PERSIST.hallThemeResID) or tonumber(L.resID)
    if res and R.resToIns[res] then return res, R.resToIns[res] end
    local ins = tonumber(PERSIST.hallThemeIns) or tonumber(L.insID)
    if ins and F.isInjectedIns(ins) then return R.insToRes[ins], ins end
    return nil, nil
end

function F.shouldApplyHallThemeFromConfig(silent)
    local _, ins = F.resolveHallTheme()
    if not ins then return false end
    local cur = nil
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        cur = tonumber(HT.GetThemeInstId())
    end)
    if cur == ins then return false end
    if _G.AddOutfitLobbyTheme and _G.AddOutfitLobbyTheme.manual then return true end
    if silent and cur and cur > 0 and F.isInjectedIns(cur) then return false end
    return true
end

function F.putOnHallTheme(insID)
    insID = tonumber(insID)
    if not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if F.applyHallThemeDisplay(resID, insID) then
        F.setHallThemeManual(resID, insID)
        return true
    end
    return false
end

function F.reapplyHallThemeFromConfig(silent)
    if not F.shouldApplyHallThemeFromConfig(silent) then return false end
    local res, ins = F.resolveHallTheme()
    if not res or not ins then return false end
    return F.applyHallThemeDisplay(res, ins)
end

function F.syncVehicleCacheFromDataMgr()
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        subType = tonumber(subType)
        if subType and type(slots) == "table" then
            cch.vehicleSlots[subType] = cch.vehicleSlots[subType] or {}
            for idx, insID in pairs(slots) do
                idx, insID = tonumber(idx), tonumber(insID)
                if idx and insID and insID > 0 then
                    local res = R.insToRes[insID]
                    if not res then
                        pcall(function()
                            local d = wd:GetHallDepotItemDataByInsID(insID)
                            res = d and tonumber(d.resID)
                        end)
                    end
                    if res and res > 0 then
                        cch.vehicleSlots[subType][idx] = { resID = res, insID = insID }
                    end
                end
            end
        end
    end
end

function F.vehicleSubType(resID)
    local c = F.cfg(resID)
    return c and (c.ItemSubType or c.itemSubType)
end

function F.modifyInjectedVehicleSlot(insID, slotIndex, equip)
    insID = tonumber(insID)
    slotIndex = tonumber(slotIndex)
    if not insID or not slotIndex then return false end
    local resID = R.insToRes[insID]
    if not resID and insID >= INS_BASE then
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            resID = d and tonumber(d.resID or d.res_id)
        end)
    end
    if not resID then return false end
    local st = F.vehicleSubType(resID)
    if not st or tonumber(st) < 900 then return false end
    local cch = F.cache()
    cch.vehicleSlots = cch.vehicleSlots or {}
    cch.vehicleSlots[st] = cch.vehicleSlots[st] or {}
    if equip then
        for _, slots in pairs(cch.vehicleSlots) do
            for i, e in pairs(slots) do
                if e and tonumber(e.insID) == insID then slots[i] = nil end
            end
        end
        cch.vehicleSlots[st][slotIndex] = { resID = resID, insID = insID }
        PERSIST.configVehicleSlots = PERSIST.configVehicleSlots or {}
        PERSIST.configVehicleSlots[st] = PERSIST.configVehicleSlots[st] or {}
        PERSIST.configVehicleSlots[st][slotIndex] = resID
    else
        local e = cch.vehicleSlots[st][slotIndex]
        if e and tonumber(e.insID) == insID then
            cch.vehicleSlots[st][slotIndex] = nil
            if PERSIST.configVehicleSlots and PERSIST.configVehicleSlots[st] then
                PERSIST.configVehicleSlots[st][slotIndex] = nil
            end
        end
    end
    F.syncVehicleSlotsToDataMgr()
    if equip and slotIndex == 1 then
        DataMgr.vehicleSkinInsIDTable = DataMgr.vehicleSkinInsIDTable or {}
        DataMgr.vehicleSkinInsIDTable[st] = insID
        pcall(function()
            local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
            TabSurveillance.VehicleChange()
        end)
    end
    F.persistMarkDirty()
    F.notifyVehicleSlotUI()
    return true
end

function F.buildVstInBattleFromSlots()
    local vst = {}
    local function insToRes(insID)
        insID = tonumber(insID)
        if not insID or insID <= 0 then return nil end
        local res = R.insToRes[insID]
        if res and res > 0 then return res end
        pcall(function()
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            res = d and tonumber(d.resID)
        end)
        if res and res > 0 then return res end
        if insID >= 1000000 and F.cfg(insID) then return insID end
        return nil
    end
    local function fillFromSlots(subType, slots)
        subType = tonumber(subType)
        if not subType or type(slots) ~= "table" then return end
        local resList = {}
        for idx = 1, 8 do
            local val = slots[idx] or slots[tostring(idx)]
            local res = insToRes(val)
            if not res and type(val) == "table" then
                res = tonumber(val.resID or val.res_id)
            end
            if res and res > 0 then resList[#resList + 1] = res end
        end
        if #resList > 0 then vst[subType] = resList end
    end
    for subType, slots in pairs(DataMgr.VehicleSlotList or {}) do
        fillFromSlots(subType, slots)
    end
    if not next(vst) then
        local cch = F.cache()
        for subType, slots in pairs(cch.vehicleSlots or {}) do
            local resList = {}
            for idx = 1, 8 do
                local e = slots[idx]
                local res = e and tonumber(e.resID)
                if res and res > 0 then resList[#resList + 1] = res end
            end
            if #resList > 0 then vst[tonumber(subType)] = resList end
        end
    end
    if not next(vst) then
        local bySub = {}
        for res, _ in pairs(R.resToIns) do
            res = tonumber(res)
            local c = F.cfg(res)
            local st = c and tonumber(F.subType(c))
            if res and st and st >= 900 then
                bySub[st] = bySub[st] or {}
                bySub[st][#bySub[st] + 1] = res
            end
        end
        for st, list in pairs(bySub) do
            table.sort(list)
            vst[st] = list
        end
    end
    return vst
end

function F.isVehicleSkinAllowed(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if F.isInjectedRes(skinId) then return true end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do
            if tonumber(res) == skinId then return true end
        end
    end
    if R.resToIns[skinId] then
        local c = F.cfg(skinId)
        local st = F.subType(c)
        if st and tonumber(st) >= 900 then return true end
    end
    return false
end

function F.isSkinInVehiclePCList(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    local pc = F.getPC()
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return false end
    local UAvatarUtils = import("AvatarUtils")
    local shape = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    if shape and shape >= 0 then
        local entry = pc.VehicleAvatarSkinList:Get(shape)
        if entry and entry.SkinList then
            for _, id in pairs(entry.SkinList) do
                if tonumber(id) == skinId then return true end
            end
        end
    end
    return false
end

function F.shouldHandleVehicleSkinClick(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    return F.isVehicleSkinAllowed(resID) or F.isSkinInVehiclePCList(resID)
end

function F.getMatchVehicle()
    local found = nil
    pcall(function()
        local subs = SubsystemMgr:Get("VehicleControlUISubSystem")
        if subs and subs.GetVehicleUserComponent then
            local uuc = subs:GetVehicleUserComponent()
            if slua.isValid(uuc) and slua.isValid(uuc.Vehicle) then found = uuc.Vehicle end
        end
    end)
    if slua.isValid(found) then return found end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.GetPlayerCharacterSafety then
        local char = pc:GetPlayerCharacterSafety()
        if slua.isValid(char) then
            if char.GetCurrentVehicle then
                local v = char:GetCurrentVehicle()
                if slua.isValid(v) then return v end
            end
            if char.CurrentVehicle and slua.isValid(char.CurrentVehicle) then
                return char.CurrentVehicle
            end
        end
    end
    return nil
end

function F.applyClientVehicleSkin(skinId, vehicle, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    vehicle = vehicle or F.getMatchVehicle()
    if not slua.isValid(vehicle) then return false end

    local UAvatarUtils = import("AvatarUtils")
    pcall(function()
        if slua.isValid(pc) then
            pc.ShowVehicleSkin = skinId
            local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
            if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
                pc.VehicleAvatarList:Add(shapeType, skinId)
            end
        end
    end)

    local applied = false
    local av = nil
    pcall(function()
        if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end
        if not slua.isValid(av) then av = vehicle.VehicleAvatarComponent_BP end
    end)

    if slua.isValid(av) then
        pcall(function() if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end end)
        pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
        pcall(function()
            if slua.isValid(pc) and av.SetVehicleNetAvatarData then
                av:SetVehicleNetAvatarData(pc)
            end
        end)
        pcall(function()
            if av.ChangeItemAvatar then
                av:ChangeItemAvatar(skinId, false)
                applied = true
            elseif av.PreChangeVehicleAvatar then
                av:PreChangeVehicleAvatar(skinId)
                applied = true
            end
        end)
        pcall(function()
            if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end
        end)
    end

    pcall(function()
        local battleCls = import("VehicleAvatarComponentBattleBase")
        local battleAv = vehicle:GetComponentByClass(battleCls)
        if slua.isValid(battleAv) then
            if battleAv.ChangeVehicleAvatar then
                battleAv:ChangeVehicleAvatar(skinId, false)
                applied = true
            end
            pcall(function()
                local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
                local uid = pc and pc.PlayerUID or 0
                local bTire = VehiclePlateLicenseUtil.NeedOpenHighTire(tonumber(uid), skinId)
                if battleAv.PreChangeHighTireLight then
                    battleAv:PreChangeHighTireLight(skinId, bTire)
                end
            end)
        end
    end)

    pcall(function()
        if vehicle.ChangeVehicleAvatar and slua.isValid(pc) then
            vehicle:ChangeVehicleAvatar(pc)
            applied = true
        end
    end)

    pcall(function() if vehicle.ForceNetUpdate then vehicle:ForceNetUpdate() end end)
    pcall(function() if slua.isValid(pc) and pc.ForceNetUpdate then pc:ForceNetUpdate() end end)
    return applied
end

function F.getVehicleSkinIds()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then
            seen[res] = true
            out[#out + 1] = res
        end
    end
    for _, list in pairs(F.buildVstInBattleFromSlots()) do
        for _, res in ipairs(list) do add(res) end
    end
    for res in pairs(R.resToIns) do
        local c = F.cfg(tonumber(res))
        local st = c and tonumber(F.subType(c))
        if st and st >= 900 then add(res) end
    end
    return out
end

function F.buildVehVst(skinIds)
    local bySub = {}
    for _, skinId in ipairs(skinIds or {}) do
        local subType = 961
        local ok, c = pcall(function() return CDataTable.GetTableData("Item", skinId) end)
        if ok and c and c.ItemSubType then subType = c.ItemSubType end
        bySub[subType] = bySub[subType] or {}
        bySub[subType][#bySub[subType] + 1] = skinId
    end
    return bySub
end

function F.directInjectVehicleSkinList(pc, skinIds)
    if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return end
    local UAvatarUtils = import("AvatarUtils")
    for _, skinId in ipairs(skinIds or {}) do
        local shapeType = nil
        pcall(function() shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId) end)
        if shapeType and shapeType >= 0 then
            pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
            local entry = pc.VehicleAvatarSkinList:Get(shapeType)
            if entry and entry.SkinList then
                pcall(function() entry.SkinList:Add(skinId) end)
            end
        end
    end
end

function F.mergeVstIntoPlayerInfo(playerInfo)
    if not playerInfo then return end
    F.syncVehicleCacheFromDataMgr()
    local vst = F.buildVehVst(F.getVehicleSkinIds())
    if not next(vst) then return end
    playerInfo.vst_in_battle = playerInfo.vst_in_battle or {}
    for subType, list in pairs(vst) do
        playerInfo.vst_in_battle[subType] = list
    end
    local first
    for _, list in pairs(vst) do first = list[1]; break end
    if first and first > 0 then playerInfo.vst_skin = first end
end

function F.applyVehicleSkinsToPC(pc)
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end
    local skinIds = F.getVehicleSkinIds()
    if #skinIds == 0 then return false end
    local vst = F.buildVehVst(skinIds)
    local avatarList, avatarSkinList = {}, {}
    for _, skinList in pairs(vst) do
        local itemArray = {}
        for _, resid in ipairs(skinList) do
            if resid and resid > 0 then
                itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
                avatarList[#avatarList + 1] = { ItemTableID = resid, Count = 1 }
            end
        end
        if #itemArray > 0 then
            avatarSkinList[#avatarSkinList + 1] = { Items = itemArray }
        end
    end
    pcall(function() pc.bEnableFuzzyAvatarOnClient = false end)
    pcall(function() pc.ShowVehicleSkin = skinIds[1] end)
    if #avatarList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarList = avatarList
            pc:InitVehicleAvatarList()
        end)
    end
    if #avatarSkinList > 0 then
        pcall(function()
            pc.InitialVehicleAvatarSkinList = avatarSkinList
            pc:InitVehicleAvatarSkinList()
        end)
    end
    F.directInjectVehicleSkinList(pc, skinIds)
    return true
end

function F.serverChangeVehicleAvatar(skinId, pc)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    pc = pc or F.getPC()
    if not slua.isValid(pc) then return false end

    F.applyVehicleSkinsToPC(pc)

    pcall(function()
        pc.ShowVehicleSkin = skinId
        local UAvatarUtils = import("AvatarUtils")
        local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
        if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
            pc.VehicleAvatarList:Add(shapeType, skinId)
        end
        F.directInjectVehicleSkinList(pc, { skinId })
    end)

    local ok = false
    pcall(function()
        if pc.ServerChangeVehicleAvatar then
            pc:ServerChangeVehicleAvatar(skinId)
            ok = true
        end
    end)

    pcall(function()
        if pc.PlayerState and slua.isValid(pc.PlayerState) then
            pc.PlayerState.nVst_skin = skinId
        end
    end)

    pcall(function() pc:ForceNetUpdate() end)
    return ok
end

_G.AddOutfitVehSel = _G.AddOutfitVehSel or { override = nil, overrideVehicle = nil, byShape = {} }
local VEHSEL = _G.AddOutfitVehSel
_G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or { manual = false, subType = nil, resID = nil, insID = nil }
local _vehTickLastApply = 0
local VEH_SWITCH_EFFECT_ID = 7303001

function F.prepVehicleSwitchEffect(av, vehicle)
    if not slua.isValid(av) then return end
    if not F.isInRealMatch() then
        pcall(function() av.curSwitchEffectId = 0 end)
        return
    end
    pcall(function()
        av.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
        local defaultId = 0
        pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
        local curId = 0
        if slua.isValid(vehicle) then
            pcall(function() curId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
            if curId <= 0 then
                pcall(function() curId = tonumber(vehicle.ClientUsedAvatarID) or 0 end)
            end
        end
        if curId <= 0 then curId = defaultId end
        if not av.lastEquipedAvatarId or av.lastEquipedAvatarId <= 0 then
            av.lastEquipedAvatarId = curId > 0 and curId or defaultId
        end
    end)
end

function F.isParachuteRes(resID)
    return F.subType(F.cfg(tonumber(resID))) == PARACHUTE_SUB
end

function F.isGlideRes(resID)
    resID = tonumber(resID)
    if not resID then return false end
    local st = F.subType(F.cfg(resID))
    if GLIDER_SUBS[st] then return true end
    local ok, r = pcall(function()
        local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
        if MDH.IsGlideByItemID and MDH.IsGlideByItemID(resID) then return true end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        return wd.IsGlideType(st)
    end)
    return ok and r == true
end

function F.isVehicleRes(resID)
    resID = tonumber(resID)
    if not resID or F.isChassisLightId(resID) then return false end
    local st = tonumber(F.subType(F.cfg(resID)))
    return st and st >= 900 and st < 7000 and st ~= CHASSIS_LIGHT_SUB
end

function F.ensureInjectedItemAlive(entity, resID, insID)
    entity = entity or F.getEntity()
    insID = tonumber(insID) or (resID and R.resToIns[tonumber(resID)])
    resID = tonumber(resID) or (insID and R.insToRes[insID])
    if not entity or not insID then return end
    pcall(function()
        local d = entity:GetDataByInsID(insID)
        if d then
            d.expire_ts = 0
            d.expireTS = 0
            d.valid_hours = 0
        end
    end)
end

function F.sanitizeAllInjectedExpire()
    local entity = F.getEntity()
    if not entity then return end
    for res, ins in pairs(R.resToIns) do
        F.ensureInjectedItemAlive(entity, res, ins)
    end
end

function F.putOnVehicle(insID)
    insID = tonumber(insID)
    if not insID then return false end
    local resID = R.insToRes[insID]
    if not resID or not F.isVehicleRes(resID) then return false end
    F.ensureInjectedItemAlive(nil, resID, insID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return false
    end
    local item = {
        res_id = resID, resID = resID,
        instid = insID, ins_id = insID, insID = insID,
        expire_ts = 0, expireTS = 0, count = 1,
    }
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    F.setLobbyVehicleManual(F.vehicleSubType(resID), resID, insID)
    pcall(function()
        local TabSurveillance = require("client.slua.logic.wardrobe.tab_surveillance")
        TabSurveillance.VehicleChange()
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
        end
    end)
    return true
end

function F.isChassisLightId(id)
    return CHASSIS_LIGHT_IDS[tonumber(id)] == true
end

function F.getDesiredChassisLight(vehicleSkinId)
    vehicleSkinId = tonumber(vehicleSkinId)
    local map = PERSIST.configChassisLightMap
    if vehicleSkinId and map and map[vehicleSkinId] then
        local v = tonumber(map[vehicleSkinId])
        if F.isChassisLightId(v) then return v end
    end
    local def = tonumber(PERSIST.configChassisLight) or DEFAULT_CHASSIS_LIGHT
    return F.isChassisLightId(def) and def or DEFAULT_CHASSIS_LIGHT
end

function F.saveChassisLight(vehicleSkinId, lightId)
    vehicleSkinId = tonumber(vehicleSkinId)
    lightId = tonumber(lightId)
    if not F.isChassisLightId(lightId) then return end
    PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
    if vehicleSkinId and vehicleSkinId > 0 then
        PERSIST.configChassisLightMap[vehicleSkinId] = lightId
    else
        PERSIST.configChassisLight = lightId
    end
    F.requestResourceDownload(lightId)
    F.persistMarkDirty()
end

function F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local lic = nil
    pcall(function()
        if vehicle.GetLicenseComponent then lic = vehicle:GetLicenseComponent() end
    end)
    if slua.isValid(lic) then return lic end
    pcall(function() lic = vehicle.BP_Lobby_VehicleLicenseComponent end)
    if slua.isValid(lic) then return lic end
    pcall(function()
        local cls = import("VehicleLicenseNumberComponent")
        lic = vehicle:GetComponentByClass(cls)
    end)
    return slua.isValid(lic) and lic or nil
end

function F.applyVehicleChassisLight(vehicle, skinId, lightId)
    
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end 
    
    skinId = tonumber(skinId)
    lightId = tonumber(lightId) or F.getDesiredChassisLight(skinId)
    if not F.isChassisLightId(lightId) then return false end
    if not slua.isValid(vehicle) then return false end
    if skinId and skinId > 0 then
        F.requestResourceDownload(skinId)
    end
    F.requestResourceDownload(lightId)
    local applied = false
    pcall(function()
        if vehicle.SetChassisLightShowData then
            vehicle:SetChassisLightShowData(lightId)
            applied = true
        end
    end)
    local lic = F.getVehicleLicenseComp(vehicle)
    if not slua.isValid(lic) then return applied end
    pcall(function()
        local vid = skinId
        if not vid or vid <= 0 then
            pcall(function()
                if vehicle.GetAvatarId then vid = tonumber(vehicle:GetAvatarId()) end
            end)
        end
        if not vid or vid <= 0 then
            pcall(function() vid = tonumber(lic.LicensePlate and lic.LicensePlate.ItemID) end)
        end
        if vid and vid > 0 then
            lic.curVehicleAvatarId = vid
            if lic.ChangeNetData_ItemID then
                lic:ChangeNetData_ItemID(vid)
            elseif lic.LicensePlate then
                lic.LicensePlate.ItemID = vid
            end
        end
        if lic.LicensePlate then
            lic.LicensePlate.ChassisLightId = lightId
        end
        if lic.SetChassisLightData and vid and vid > 0 then
            lic:SetChassisLightData(vid, lightId)
        elseif lic.PreChangeChassisLight then
            lic:PreChangeChassisLight()
        end
        applied = true
    end)
    return applied
end

function F.scheduleChassisLightApply(vehicle, skinId)
    skinId = tonumber(skinId)
    local vref = slua.isValid(vehicle) and vehicle or nil
    local function try()
        local v = slua.isValid(vref) and vref or F.getCurrentVehicleForSkin()
        if slua.isValid(v) then
            F.applyVehicleChassisLight(v, skinId)
        end
    end
    F.later(0.4, try)
    F.later(1.1, try)
end

function F.getVehicleShape(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local shape = vehicle.VehicleShapeType
    if shape and tonumber(shape) >= 0 then return tonumber(shape) end
    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local defId = vehicle.AvatarDefaultCfg and vehicle.AvatarDefaultCfg.TypeSpecificID
        if defId and tonumber(defId) > 0 then
            shape = UAvatarUtils.GetVehicleShapeBySkinID(tonumber(defId))
        end
    end)
    return shape and tonumber(shape) >= 0 and tonumber(shape) or nil
end

function F.getDesiredVehicleSkinForShape(shape)
    shape = tonumber(shape)
    if not shape or shape < 0 then return nil end
    F.syncVehicleCacheFromDataMgr()
    local UAvatarUtils = import("AvatarUtils")
    local vst = F.buildVstInBattleFromSlots()
    for _, list in pairs(vst) do
        local skin = list and tonumber(list[1])
        if skin and skin > 0 then
            local s = UAvatarUtils.GetVehicleShapeBySkinID(skin)
            if s == shape then return skin end
        end
    end
    local pc = F.getPC()
    if slua.isValid(pc) and pc.VehicleAvatarList then
        local skin = tonumber(pc.VehicleAvatarList:Get(shape))
        if skin and skin > 0 then return skin end
    end
    return nil
end

function F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(vehicle) then return nil end
    local av = nil
    pcall(function() av = vehicle.VehicleAvatar end)
    if slua.isValid(av) then return av end
    pcall(function() if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end end)
    if slua.isValid(av) then return av end
    pcall(function() av = vehicle.VehicleAvatarComponent_BP end)
    if slua.isValid(av) then return av end
    return nil
end

function F.getCurrentVehicleForSkin()
    local char = F.getLocalChar()
    if char and slua.isValid(char) then
        local v = nil
        pcall(function() v = char.CurrentVehicle end)
        if slua.isValid(v) then return v end
    end
    return F.getMatchVehicle()
end

function F.forceVehicleAvatar(skinId, vehicle)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end
    if not F.isResourcesReady(skinId) then
        F.requestResourceDownload(skinId)
        return false
    end
    vehicle = slua.isValid(vehicle) and vehicle or F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return false end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return false end
    local applied = false
    F.prepVehicleSwitchEffect(av, vehicle)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
        av:ChangeItemAvatar(skinId, true)
        applied = true
        _G.CurrentEquipVehicleID = skinId
    end)
    if applied then F.scheduleChassisLightApply(vehicle, skinId) end
    return applied
end

function F.vehicleAvatarTemper()
    local vehicle = F.getCurrentVehicleForSkin()
    if not slua.isValid(vehicle) then return end
    local av = F.getVehicleAvatarComp(vehicle)
    if not slua.isValid(av) then return end

    local defaultId = 0
    pcall(function() defaultId = tonumber(av:GetDefaultAvatarID()) or 0 end)
    if defaultId <= 0 then return end

    local shape = nil
    pcall(function() shape = tonumber(import("AvatarUtils").GetVehicleShapeBySkinID(defaultId)) end)

    local skinId = nil
    if VEHSEL.override and slua.isValid(VEHSEL.overrideVehicle) and VEHSEL.overrideVehicle == vehicle then
        skinId = VEHSEL.override
    end
    if not skinId and shape then skinId = VEHSEL.byShape[shape] end
    if not skinId then skinId = F.getDesiredVehicleSkinForShape(shape) end
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 or skinId == defaultId then return end

    local cur = 0
    pcall(function() cur = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) or 0 end)
    if cur <= 0 then
        pcall(function() cur = tonumber(vehicle.GetVehicleSkinItemID and vehicle:GetVehicleSkinItemID()) or 0 end)
    end
    if cur == skinId then return end

    F.forceVehicleAvatar(skinId, vehicle)
end

function F.vehicleSkinTick()
    F.vehicleAvatarTemper()
    
    
    pcall(function()
        local char = F.getLocalChar()
        if char then F.matchApplyFaceWear(char) end
    end)

    local now = os.clock()
    if now - _vehTickLastApply < 5.0 then return end
    _vehTickLastApply = now
    F.applyVehicleSkinsToPC()
end

function F.startVehicleSkinTicker()
    pcall(function()
        if not _ticker then return end
        if _G.AddOutfitVehTickerId then return end
        if _ticker.AddTimerLoop then
            _G.AddOutfitVehTickerId = _ticker.AddTimerLoop(1.0, function()
                local state = _G.LexusState and _G.LexusState.KillLimit
                if state and state.Reached then return end
                local fn = _G.AddOutfit and _G.AddOutfit.vehicleSkinTick
                if fn then pcall(fn) end
            end, -1, 1.0)
        end
    end)
end

function F.matchApplyVehicleSkin(skinId)
    skinId = tonumber(skinId)
    if not skinId or skinId <= 0 then return false end

    local vehicle = F.getCurrentVehicleForSkin()

    VEHSEL.override = skinId
    VEHSEL.overrideVehicle = slua.isValid(vehicle) and vehicle or nil

    pcall(function()
        local UAvatarUtils = import("AvatarUtils")
        local shape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(skinId))
        if shape and shape >= 0 then VEHSEL.byShape[shape] = skinId end
        local av = F.getVehicleAvatarComp(vehicle)
        if slua.isValid(av) then
            local defaultId = tonumber(av:GetDefaultAvatarID()) or 0
            if defaultId > 0 then
                local defShape = tonumber(UAvatarUtils.GetVehicleShapeBySkinID(defaultId))
                if defShape and defShape >= 0 then VEHSEL.byShape[defShape] = skinId end
            end
        end
    end)

    F.applyVehicleSkinsToPC(F.getPC())
    local ok = F.forceVehicleAvatar(skinId, vehicle)
    F.startVehicleSkinTicker()
    return ok
end

function F.autoApplyVehicleSkinOnEnter(vehicle)
    if not slua.isValid(vehicle) then return end
    F.syncVehicleCacheFromDataMgr()
    F.applyVehicleSkinsToPC(F.getPC())
    F.startVehicleSkinTicker()
    F.later(0.35, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.9, function() pcall(F.vehicleAvatarTemper) end)
    F.later(0.5, function()
        local skinId = nil
        pcall(function() skinId = tonumber(vehicle.GetAvatarId and vehicle:GetAvatarId()) end)
        F.scheduleChassisLightApply(vehicle, skinId)
    end)
end

local function GetOutfitConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName
    }
    pcall(function()
        if os and os.getenv then
            local homeDir = os.getenv("HOME")
            if homeDir and homeDir ~= "" then
                table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName)
            end
        end
    end)
    return paths
end

local CONFIG_PATHS = GetOutfitConfigPaths("ZONE_MOD_outfit.json")

local PERSIST_SLOTS = {
    { "outfit", "outfitRes", "outfitIns", "AddOutfitLastLobbyOutfitRes" },
    { "tshirt", "tshirtRes", "tshirtIns", "AddOutfitLastLobbyTshirtRes" },
    { "pants",  "pantsRes",  "pantsIns",  "AddOutfitLastLobbyPantsRes"  },
    { "shoes",  "shoesRes",  "shoesIns",  "AddOutfitLastLobbyShoesRes"  },
    { "hat",    "hatRes",    "hatIns",    "AddOutfitLastLobbyHatRes"    },
    { "mask",   "maskRes",   "maskIns",   "AddOutfitLastLobbyMaskRes"   },
    { "glass",  "glassRes",  "glassIns",  "AddOutfitLastLobbyGlassRes"  },
    { "bag",    "bagRes",    "bagIns",    "AddOutfitLastLobbyBagRes"    },
    { "helmet", "helmetRes", "helmetIns", "AddOutfitLastLobbyHelmetRes" },
    { "parachute", "parachuteRes", "parachuteIns", "AddOutfitLastLobbyParachuteRes" },
    { "glider", "gliderRes", "gliderIns", "AddOutfitLastLobbyGliderRes" },
    { "gloves", "glovesRes", "glovesIns", "AddOutfitLastLobbyGlovesRes" },
}

function F.isPersistableWearRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return false end
    if F.isInjectedRes(resID) then return true end
    if F.isParachuteRes(resID) or F.isGlideRes(resID) then return true end
    if PERSIST.configSlots then
        for _, v in pairs(PERSIST.configSlots) do
            if tonumber(v) == resID then return true end
        end
    end
    return false
end

function F.persistRememberSlot(slotName, resID)
    slotName = slotName and tostring(slotName)
    resID = tonumber(resID)
    if not slotName or not resID or resID <= 0 then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    PERSIST.configSlots[slotName] = resID
end

function F.persistForgetSlot(slotName)
    if PERSIST.configSlots and slotName then
        PERSIST.configSlots[tostring(slotName)] = nil
    end
end

function F.persistLoadSlotsFromSaved(saved)
    if type(saved) ~= "table" then return end
    PERSIST.configSlots = PERSIST.configSlots or {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]])
        if res and res > 0 then PERSIST.configSlots[s[1]] = res end
    end
    F.applyPersistSlotsToCache()
end

function F.resolveInsForRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return nil end
    if R.resToIns[resID] then return R.resToIns[resID] end
    local ins
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local list = wd.GetHallDepotItemListByResID and wd:GetHallDepotItemListByResID(resID)
        if list then
            for _, v in pairs(list) do
                local id = tonumber(v.insID or v.instid or v.ins_id)
                if id and id > 0 then ins = id break end
            end
        end
        if not ins then
            local d = wd.GetValidHallDepotItemDataByInsID and wd:GetValidHallDepotItemDataByInsID(resID)
            if not d and wd.GetHallDepotItemDataByResID then
                d = wd:GetHallDepotItemDataByResID(resID)
            end
            if d then ins = tonumber(d.insID or d.instid or d.ins_id) end
        end
    end)
    return ins
end

function F.applyPersistSlotsToCache()
    if not PERSIST.configSlots then return end
    local cch = F.cache()
    for _, s in ipairs(PERSIST_SLOTS) do
        local slotName, cacheResKey, cacheInsKey, globalKey = s[1], s[2], s[3], s[4]
        local res = tonumber(PERSIST.configSlots[slotName])
        if res and res > 0 then
            cch[cacheResKey] = res
            _G[globalKey] = res
            local ins = F.resolveInsForRes(res)
            if ins and ins > 0 then cch[cacheInsKey] = ins end
        end
    end
end

function F.getDesiredGliderRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.glider)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("gliderRes", "gliderRes", "AddOutfitLastLobbyGliderRes")
end

function F.getDesiredParachuteRes()
    F.applyPersistSlotsToCache()
    local r = tonumber(PERSIST.configSlots and PERSIST.configSlots.parachute)
    if r and r > 0 then return r end
    F.syncAirborneCacheFromLobby()
    return F.getDesiredWear("parachuteRes", "parachuteRes", "AddOutfitLastLobbyParachuteRes")
end

function F.getAvatarComp2(char)
    if not char or not slua.isValid(char) then return nil end
    local comp
    pcall(function()
        if char.getAvatarComponent2 then
            comp = char:getAvatarComponent2()
        end
        if (not comp or not slua.isValid(comp)) and char.AvatarComponent2 then
            comp = char.AvatarComponent2
        end
        if (not comp or not slua.isValid(comp)) and char.CharacterAvatarComp2_BP then
            comp = char.CharacterAvatarComp2_BP
        end
    end)
    return comp
end

function F.isCharacterAirborne(char)
    if not char or not slua.isValid(char) then return false end
    local ok, r = pcall(function()
        local EParachuteState = import("EParachuteState")
        local st = char.ParachuteState
        return st and st ~= EParachuteState.PS_None
    end)
    return ok and r == true
end

function F.reapplyWeaponsFromConfig()
    local wmap = F.sanitizeConfigWeapons(PERSIST.configWeapons)
    local dropped = false
    for k in pairs(PERSIST.configWeapons or {}) do
        if not wmap[tonumber(k) or k] then dropped = true break end
    end
    PERSIST.configWeapons = wmap
    if dropped then F.persistMarkDirty() end
    if not next(wmap) then return false end
    local cch = F.cache()
    local any = false
    for wid, res in pairs(wmap) do
        wid, res = tonumber(wid), tonumber(res)
        local ins = res and R.resToIns[res]
        if wid and ins and F.isInjectedIns(ins) then
            cch.weapons[wid] = { resID = res, insID = ins }
            if F.equipWeaponSkin(wid, ins) then
                any = true
            else
                F.syncWeaponArmorySilent(wid, ins)
            end
        end
    end
    return any
end

function F.persistEncode()
    local cch = F.cache()
    local parts = {}
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
            or tonumber(cch[s[2]])
        if res and res > 0 and F.isPersistableWearRes(res) then
            parts[#parts + 1] = string.format('  "%s": %d', s[1], res)
        end
    end
    local wparts = {}
    local wmap = {}
    for wid, res in pairs(F.sanitizeConfigWeapons(PERSIST.configWeapons)) do
        wmap[wid] = res
    end
    for wid, w in pairs(cch.weapons or {}) do
        local res = w and tonumber(w.resID)
        wid = tonumber(wid)
        if F.isValidWeaponPersistEntry(wid, res) then wmap[wid] = res end
    end
    for wid, res in pairs(wmap) do
        wparts[#wparts + 1] = string.format('    "%d": %d', wid, res)
    end
    table.sort(wparts)
    parts[#parts + 1] = '  "weapons": {\n' .. table.concat(wparts, ",\n") .. "\n  }"
    local vparts = {}
    local function appendVehicleSlots(src)
        for subType, slots in pairs(src or {}) do
            local sparts = {}
            if type(slots) == "table" then
                for idx, val in pairs(slots) do
                    local res = type(val) == "table" and tonumber(val.resID) or tonumber(val)
                    if res and res > 0 then
                        sparts[#sparts + 1] = string.format('      "%d": %d', tonumber(idx), res)
                    end
                end
            end
            table.sort(sparts)
            if #sparts > 0 then
                vparts[#vparts + 1] = string.format('    "%d": {\n%s\n    }', tonumber(subType), table.concat(sparts, ",\n"))
            end
        end
    end
    local hasCacheSlots = false
    for _ in pairs(cch.vehicleSlots or {}) do hasCacheSlots = true; break end
    if hasCacheSlots then
        appendVehicleSlots(cch.vehicleSlots)
    elseif PERSIST.configVehicleSlots then
        appendVehicleSlots(PERSIST.configVehicleSlots)
    end
    table.sort(vparts)
    parts[#parts + 1] = '  "vehicleSlots": {\n' .. table.concat(vparts, ",\n") .. "\n  }"
    if PERSIST.lobbyVehicleSubType and PERSIST.lobbyVehicleSubType > 0
        and PERSIST.lobbyVehicleSubType ~= CHASSIS_LIGHT_SUB
        and not F.isChassisLightId(PERSIST.lobbyVehicleResID)
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleSubType": %d', PERSIST.lobbyVehicleSubType)
    end
    if PERSIST.lobbyVehicleResID and PERSIST.lobbyVehicleResID > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID) then
        parts[#parts + 1] = string.format('  "lobbyVehicleResID": %d', PERSIST.lobbyVehicleResID)
    end
    if PERSIST.lobbyVehicleIns and PERSIST.lobbyVehicleIns > 0
        and F.isVehicleRes(PERSIST.lobbyVehicleResID or R.insToRes[PERSIST.lobbyVehicleIns]) then
        parts[#parts + 1] = string.format('  "lobbyVehicleIns": %d', PERSIST.lobbyVehicleIns)
    end
    local hres = tonumber(cch.hallThemeRes) or tonumber(PERSIST.hallThemeResID)
    if hres and hres > 0 and F.isInjectedRes(hres) then
        parts[#parts + 1] = string.format('  "hallTheme": %d', hres)
    end
    local cl = tonumber(PERSIST.configChassisLight)
    if F.isChassisLightId(cl) then
        parts[#parts + 1] = string.format('  "chassisLight": %d', cl)
    end
    local cmap = PERSIST.configChassisLightMap
    if cmap and next(cmap) then
        local cparts = {}
        for vid, lid in pairs(cmap) do
            vid, lid = tonumber(vid), tonumber(lid)
            if vid and vid > 0 and F.isChassisLightId(lid) then
                cparts[#cparts + 1] = string.format('    "%d": %d', vid, lid)
            end
        end
        table.sort(cparts)
        if #cparts > 0 then
            parts[#parts + 1] = '  "chassisLightMap": {\n' .. table.concat(cparts, ",\n") .. "\n  }"
        end
    end
    return "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
end

function F.persistWrite(txt)
    if not (io and io.open) then return false end
    if PERSIST.path then
        local f
        pcall(function() f = io.open(PERSIST.path, "w") end)
        if f then f:write(txt) f:close() return true end
        PERSIST.path = nil
    end
    for _, p in ipairs(CONFIG_PATHS) do
        local f
        pcall(function() f = io.open(p, "w") end)
        if not f then
            pcall(function()
                local dir = p:match("^(.*)/[^/]+$")
                if dir and os and os.execute then os.execute('mkdir -p "' .. dir .. '"') end
            end)
            pcall(function() f = io.open(p, "w") end)
        end
        if f then
            f:write(txt) f:close()
            PERSIST.path = p
            return true
        end
    end
    return false
end

function F.persistFlush()
    if not PERSIST.dirty then return end
    PERSIST.dirty = false
    pcall(function()
        local txt = F.persistEncode()
        if txt == PERSIST.lastWritten then return end
        if F.persistWrite(txt) then
            PERSIST.lastWritten = txt
        end
    end)
end

F.persistMarkDirty = function()
    PERSIST.dirty = true
    if PERSIST.scheduled then return end
    PERSIST.scheduled = true
    F.later(2.0, function()
        PERSIST.scheduled = false
        F.persistFlush()
    end)
end

function F.persistParse(txt)
    if not txt or #txt == 0 then return nil end
    local out = { weapons = {}, vehicleSlots = {} }
    local parsed = false
    pcall(function()
        local t = json and json.decode and json.decode(txt)
        if type(t) == "table" then
            for k, v in pairs(t) do
                if k == "weapons" and type(v) == "table" then
                    for wk, wv in pairs(v) do
                        local wid, res = tonumber(wk), tonumber(wv)
                        if F.isValidWeaponPersistEntry(wid, res) then out.weapons[wid] = res end
                    end
                elseif k == "vehicleSlots" and type(v) == "table" then
                    for stk, slotMap in pairs(v) do
                        local st = tonumber(stk)
                        if st then
                            out.vehicleSlots[st] = out.vehicleSlots[st] or {}
                            for idxStr, res in pairs(slotMap) do
                                local idx, r = tonumber(idxStr), tonumber(res)
                                if idx and r and r > 0 then out.vehicleSlots[st][idx] = r end
                            end
                        end
                    end
                elseif k == "chassisLightMap" and type(v) == "table" then
                    out.chassisLightMap = {}
                    for vk, lv in pairs(v) do
                        local vid, lid = tonumber(vk), tonumber(lv)
                        if vid and lid and F.isChassisLightId(lid) then
                            out.chassisLightMap[vid] = lid
                        end
                    end
                else
                    local n = tonumber(v)
                    if n and n > 0 then out[k] = n end
                end
            end
            parsed = true
        end
    end)
    if not parsed then
        for k, v in txt:gmatch('"([%w_]+)"%s*:%s*(%d+)') do
            local n = tonumber(v)
            if n and n > 0 then
                local wid = tonumber(k)
                if wid and F.isValidWeaponPersistEntry(wid, n) then
                    out.weapons[wid] = n
                elseif not wid then
                    out[k] = n
                end
            end
        end
    end
    return out
end

function F.persistLoadFromDisk()
    if not (io and io.open) then return end
    pcall(function()
        for _, p in ipairs(CONFIG_PATHS) do
            local f
            pcall(function() f = io.open(p, "r") end)
            if f then
                local txt = f:read("*a")
                f:close()
                PERSIST.path = p
                PERSIST.lastWritten = txt
                PERSIST.loaded = F.persistParse(txt)
                F.persistLoadSlotsFromSaved(PERSIST.loaded)
                if PERSIST.loaded and PERSIST.loaded.vehicleSlots then
                    PERSIST.configVehicleSlots = PERSIST.loaded.vehicleSlots
                end
                if PERSIST.loaded and PERSIST.loaded.weapons then
                    local raw = PERSIST.loaded.weapons
                    PERSIST.configWeapons = F.sanitizeConfigWeapons(raw)
                    if next(raw) and not next(PERSIST.configWeapons) then
                        F.persistMarkDirty()
                    elseif next(raw) then
                        for wid, res in pairs(raw) do
                            if not F.isValidWeaponPersistEntry(tonumber(wid), tonumber(res)) then
                                F.persistMarkDirty()
                                break
                            end
                        end
                    end
                end
                PERSIST.lobbyVehicleSubType = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleSubType)
                PERSIST.lobbyVehicleResID = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleResID)
                PERSIST.lobbyVehicleIns = tonumber(PERSIST.loaded and PERSIST.loaded.lobbyVehicleIns)
                if PERSIST.lobbyVehicleSubType or PERSIST.lobbyVehicleIns or PERSIST.lobbyVehicleResID then
                    if F.isChassisLightId(PERSIST.lobbyVehicleResID)
                        or PERSIST.lobbyVehicleSubType == CHASSIS_LIGHT_SUB
                        or not F.isVehicleRes(PERSIST.lobbyVehicleResID) then
                        PERSIST.lobbyVehicleSubType = nil
                        PERSIST.lobbyVehicleResID = nil
                        PERSIST.lobbyVehicleIns = nil
                    else
                        _G.AddOutfitLobbyVeh = _G.AddOutfitLobbyVeh or {}
                        _G.AddOutfitLobbyVeh.manual = true
                        _G.AddOutfitLobbyVeh.subType = PERSIST.lobbyVehicleSubType
                        _G.AddOutfitLobbyVeh.resID = PERSIST.lobbyVehicleResID
                        _G.AddOutfitLobbyVeh.insID = PERSIST.lobbyVehicleIns
                    end
                end
                PERSIST.hallThemeResID = tonumber(PERSIST.loaded and PERSIST.loaded.hallTheme)
                PERSIST.hallThemeIns = nil
                if PERSIST.hallThemeResID then
                    _G.AddOutfitLobbyTheme = _G.AddOutfitLobbyTheme or {}
                    _G.AddOutfitLobbyTheme.manual = true
                    _G.AddOutfitLobbyTheme.resID = PERSIST.hallThemeResID
                end
                PERSIST.configChassisLight = tonumber(PERSIST.loaded and PERSIST.loaded.chassisLight)
                if PERSIST.loaded and PERSIST.loaded.chassisLightMap then
                    PERSIST.configChassisLightMap = PERSIST.loaded.chassisLightMap
                end
                return
            end
        end
    end)
end

function F.persistApplyLoaded()
    local saved = PERSIST.loaded
    if not saved then return end
    PERSIST.loaded = nil
    local cch = F.cache()
    local any = false
    for _, s in ipairs(PERSIST_SLOTS) do
        local res = tonumber(saved[s[1]]) or tonumber(PERSIST.configSlots and PERSIST.configSlots[s[1]])
        if res and res > 0 and not cch[s[2]] then
            local ins = R.resToIns[res]
            if ins then
                cch[s[2]], cch[s[3]] = res, ins
                _G[s[4]] = res
                any = true
            end
        end
    end
    PERSIST.configWeapons = F.sanitizeConfigWeapons(saved.weapons or PERSIST.configWeapons)
    if saved.weapons and F.reapplyWeaponsFromConfig() then
        any = true
    end
    if saved.vehicleSlots then
        PERSIST.configVehicleSlots = saved.vehicleSlots
        if F.reapplyVehicleSlotsFromConfig(true) then
            any = true
        end
    end
    if saved.hallTheme then
        PERSIST.hallThemeResID = tonumber(saved.hallTheme)
        if PERSIST.hallThemeResID and F.reapplyHallThemeFromConfig(true) then
            any = true
        end
    end
    if saved.chassisLight then
        PERSIST.configChassisLight = tonumber(saved.chassisLight)
    end
    if saved.chassisLightMap then
        PERSIST.configChassisLightMap = saved.chassisLightMap
    end
    if any then
        _matchApplied = false
        F.perfInvalidateLobby()
    end
end

function F.getEntity()
    local ok, dc = pcall(require, "client.slua.logic.wardrobe.logic_wardrobe_data_center")
    if not ok or not dc then return nil end
    local ok2, e = pcall(dc.GetWardrobeData)
    return ok2 and e or nil
end

function F.firstInsForRes(entity, resID)
    local arr = entity.ResIDToIndexArrayMap and entity.ResIDToIndexArrayMap[resID]
    if not arr then return nil end
    for _, idx in pairs(arr) do
        local d = entity._data[idx]
        if d and d.count and d.count > 0 then return d.insID end
    end
    return nil
end

function F.injectOne(entity, resID, insID)
    local ownedIns = F.firstInsForRes(entity, resID)
    if ownedIns then
        F.ensureInjectedItemAlive(entity, resID, ownedIns)
        R.resToIns[resID] = ownedIns
        R.insToRes[ownedIns] = resID
        F.indexWeaponSkin(resID, ownedIns)
        return true
    end
    local row = {
        instid = insID,
        res_id = resID,
        count = 1,
        lock_cnt = 0,
        isnew = 0,
        valid_hours = 0,
        expire_ts = 0,
    }
    entity:AddData(row)
    pcall(function()
        if entity.LoadConfigForData and CDataTable and CDataTable.GetTableData then
            local idx = entity._DataCount
            if idx and entity._data[idx] then
                entity:LoadConfigForData(entity._data[idx], CDataTable.GetTableData)
            end
        end
    end)
    R.insToRes[insID] = resID
    R.resToIns[resID] = insID
    F.indexWeaponSkin(resID, insID)
    return true
end

function F.reviveExpiredOwned(entity)
    entity = entity or F.getEntity()
    if not entity or not entity.bInit or not entity._data then return end
    local now = 0
    pcall(function()
        local TimeUtil = require("client.common.time_util")
        now = tonumber(TimeUtil.GetServerTimeInSec()) or 0
    end)
    if now <= 0 then return end
    _G.AddOutfitRevived = _G.AddOutfitRevived or {}
    local n = 0
    for i = 1, (entity._DataCount or #entity._data) do
        local d = entity._data[i]
        if d then
            local exp = tonumber(d.expire_ts or d.expireTS) or 0
            local res = tonumber(d.res_id or d.resID)
            local ins = tonumber(d.instid or d.insID)
            if exp > 0 and exp <= now and res and ins and (tonumber(d.count) or 0) > 0 then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
                _G.AddOutfitRevived[res] = ins
                n = n + 1
            end
        end
    end
end

function F.mergeRevivedIntoMaps()
    for res, ins in pairs(_G.AddOutfitRevived or {}) do
        if not R.resToIns[res] then
            R.resToIns[res] = ins
            R.insToRes[ins] = res
            F.indexWeaponSkin(res, ins)
        end
    end
end

function F.injectArmory(resID, insID)
    local wid = F.weaponIdFromSkin(resID)
    if not wid then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.skin_list = Arm.rsp_list.skin_list or {}
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    if not Arm.rsp_list.skin_list[wid] then Arm.rsp_list.skin_list[wid] = {} end
    Arm.rsp_list.skin_list[wid][resID] = { is_open = 1 }
    Arm.WardrobeInsList = Arm.WardrobeInsList or {}
    Arm.WardrobeInsList[resID] = insID
end

function F.mergeInjectedArmorySkins()
    for _, skins in pairs(R.byWeapon) do
        for resID, insID in pairs(skins) do
            F.injectArmory(resID, insID)
        end
    end
end

function F.injectAll(entity)
    if _G.LexusConfig and _G.LexusConfig.ModSkin == false then return false end 
    entity = entity or F.getEntity()
    if not entity or not entity.bInit then return false end
    local n, nNew = 0, 0
    for i, resID in ipairs(ITEMS) do
        local insID = INS_BASE + i
        local had = R.resToIns[resID] ~= nil
        if F.injectOne(entity, resID, insID) then
            n = n + 1
            if not had then nNew = nNew + 1 end
            local c = F.cfg(resID)
            if GUN_SUB[F.subType(c)] or F.subType(c) == MELEE_ID then
                F.injectArmory(resID, insID)
            end
        end
    end
    if not _G.AddOutfitUnexpireDone then
        _G.AddOutfitUnexpireDone = true
        pcall(F.reviveExpiredOwned, entity)
    end
    F.mergeRevivedIntoMaps()
    F.sanitizeAllInjectedExpire()
    F.ensureInjectedResources()
    return n > 0
end

function F.refreshWardrobe()
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_GUN_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_GUN_LIST, -1)
            end
        end
    end)
end

function F.refreshWardrobeOnce()
    if LOBBY.wardrobeRefreshed then return end
    LOBBY.wardrobeRefreshed = true
    F.refreshWardrobe()
end

function F.scheduleInjectRefresh()
    LOBBY.injectRefreshGen = (LOBBY.injectRefreshGen or 0) + 1
    local gen = LOBBY.injectRefreshGen
    F.later(0.4, function()
        if gen ~= LOBBY.injectRefreshGen then return end
        F.refreshWardrobe()
    end)
end

function F.putOnOutfit(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    if not F.isSuitRes(resID) then
        if F.isTshirtRes(resID) then return F.putOnRoleWear(insID) end
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local suitFilter = function(r) return F.isSuitRes(r) end
    local oldIns, oldRes = F.findWornInsBySubType(OUTFIT_SUB, suitFilter)
    F.removeRoleWearBySubType(OUTFIT_SUB, suitFilter)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(OUTFIT_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local av = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        av:AddToWearInfo(OUTFIT_SUB, insID, resID, 0, 0)
        F.syncFashionBagRolewear()
    end)
end

function F.putOnHat(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or HAT_SUB

    local oldIns, oldRes = F.findWornInsBySubType(st)
    if not oldIns and st ~= HAT_SUB then
        oldIns, oldRes = F.findWornInsBySubType(HAT_SUB)
    end
    F.removeRoleWearBySubType(st)
    if st ~= HAT_SUB then F.removeRoleWearBySubType(HAT_SUB) end
    F.saveEquip(resID, insID)

    local slot = 1
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        fbd:SetHeadShow(insID)
        F.syncFashionBagRolewear()
    end)
    F.invalidateSocialWearCache()
end

function F.putOnFaceAccessory(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not FACE_SUBS[st] then return end

    local oldIns, oldRes = F.findWornInsBySubType(st)
    F.removeRoleWearBySubType(st)
    F.saveEquip(resID, insID)

    local slot = (st == MASK_SUB) and 2 or 6
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.canRoleWear(resID, st)
    st = st or F.subType(F.cfg(resID))
    if FACE_SUBS[st] or BODY_SUBS[st] then return true end
    if st == GLOVES_SUB then return true end
    if st == OUTFIT_SUB and F.wardrobeTab(resID) == TAB_CLOTHES then return true end
    return false
end

F.putOnRoleWear = function(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end
    local st = F.subType(F.cfg(resID)) or tonumber(d.itemSubType)
    if not F.canRoleWear(resID, st) then return end

    local filterFn
    if st == OUTFIT_SUB then
        filterFn = function(r) return F.wardrobeTab(r) == TAB_CLOTHES end
    end
    local oldIns, oldRes = F.findWornInsBySubType(st, filterFn)
    F.removeRoleWearBySubType(st, filterFn)
    F.saveEquip(resID, insID)

    local slot = PKG_SLOT
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(st)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            DataMgr.equipmentSkinInsIDTable = DataMgr.equipmentSkinInsIDTable or {}
            DataMgr.equipmentSkinInsIDTable[st] = insID
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if st == 504 or st == 501 then
                    DataMgr.equipmentSkinInsIDTable[504] = insID
                    bag.bag_skin = insID
                elseif st == 505 or st == 502 then
                    DataMgr.equipmentSkinInsIDTable[505] = insID
                    bag.helmet_skin = insID
                end
            end
        end)
    end

    pcall(function() F.syncFashionBagRolewear() end)
    F.invalidateSocialWearCache()
end

function F.putOnGloves(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d0 = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d0 and tonumber(d0.resID or d0.res_id)
    end
    if not resID or resID <= 0 then return end
    if not R.insToRes[insID] then R.insToRes[insID] = resID; R.resToIns[resID] = insID end
    F.ensureDepotItemValid(insID, resID)
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
    local d = wd:GetHallDepotItemDataByInsID(insID)
    if not d then return end

    local oldIns, oldRes = F.findWornInsBySubType(GLOVES_SUB)
    F.removeRoleWearBySubType(GLOVES_SUB)
    F.saveEquip(resID, insID)

    local slot = 8
    pcall(function()
        local wfu = require("client.slua.logic.wardrobe.fashionbag.wardrobe_fashion_utils")
        local idx = wfu.GetRoleWearIndexBySubType and wfu:GetRoleWearIndexBySubType(GLOVES_SUB)
        if idx then slot = idx end
    end)

    local olditem
    if oldIns and oldIns ~= insID then
        olditem = { res_id = oldRes or R.insToRes[oldIns], count = 1, instid = oldIns }
    end

    local WRH = require("client.network.Protocol.WardRobeHandler")
    local item = { res_id = resID, count = 1, instid = insID, color = d.color, pattern = d.pattern, expire_ts = 0 }
    WRH.on_depot_put_on_rsp(NET_OK, item, olditem, slot, insID, oldIns or 0)

    pcall(function()
        local logic_wardrobe_avatar = require("client.slua.logic.wardrobe.logic_wardrobe_avatar")
        logic_wardrobe_avatar:AddToWearInfo(GLOVES_SUB, insID, resID, d.color or 0, d.pattern or 0)
        DataMgr.UpdateRoleWearData(insID, oldIns or 0)
        logic_wardrobe_avatar:AvatarChange(resID, true, d.color, d.pattern)
    end)
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl.SetClickItemInsId then wl:SetClickItemInsId(insID) end
    end)
    pcall(function()
        if EventSystem and EVENTTYPE_WARDROBE then
            if EVENTID_WARDROBE_UPDATE_ITEM_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST)
            end
            if EVENTID_WARDROBE_UPDATE_AVATAR_LIST then
                EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_AVATAR_LIST)
            end
        end
    end)
    F.invalidateSocialWearCache()
end

function F.ensureDepotItemValid(insID, resID)
    insID = tonumber(insID)
    if not insID then return end
    pcall(function()
        local entity = F.getEntity()
        if entity and entity.GetDataByInsID then
            local d = entity:GetDataByInsID(insID)
            if d then
                d.expire_ts = 0
                if d.expireTS ~= nil then d.expireTS = 0 end
                if d.valid_hours ~= nil then d.valid_hours = 0 end
            end
        end
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local hd = wd:GetHallDepotItemDataByInsID(insID)
        if hd then
            hd.expire_ts = 0
            if hd.expireTS ~= nil then hd.expireTS = 0 end
            if hd.valid_hours ~= nil then hd.valid_hours = 0 end
        end
    end)
end

function F.clearItemExpire(itemData, insID, resID)
    F.ensureDepotItemValid(insID, resID)
    if type(itemData) == "table" then
        itemData.expireTS = 0
        itemData.expire_ts = 0
        itemData.expireTs = 0
    end
end

function F.onGlideClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    local isGlide = resID and F.isGlideRes(resID)
    if not isGlide and itemData.itemSubType then
        isGlide = GLIDER_SUBS[tonumber(itemData.itemSubType)] == true
    end
    if insID and resID and isGlide then
        F.saveEquip(resID, insID)
        if F.putOnGlider(insID) then
            pcall(function()
                if self.ShowGlide then self:ShowGlide(resID) end
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitGlideClickOrig then
        F.clearItemExpire(itemData, insID, resID)
        return _G.AddOutfitGlideClickOrig(self, itemData)
    end
end

function F.onParachuteClick(self, itemData)
    if not itemData then return end
    local insID = tonumber(itemData.ins_id)
    local resID = tonumber(itemData.res_id)
    F.clearItemExpire(itemData, insID, resID)
    if insID and resID and F.isParachuteRes(resID) then
        F.saveEquip(resID, insID)
        if F.putOnParachute(insID) then
            pcall(function()
                if self.ChangeItemStatus then self:ChangeItemStatus(insID, true) end
            end)
            return
        end
    end
    if _G.AddOutfitParaClickOrig then
        return _G.AddOutfitParaClickOrig(self, itemData)
    end
end

function F.hookAirborneClick()
    pcall(function()
        local WG = require("client.slua.umg.Wardrobe.subtab_gliding")
        if WG then
            if not WG._AddOutfitGlideWrapped then
                WG._AddOutfitGlideWrapped = true
                _G.AddOutfitGlideClickOrig = WG.ClickItem
            end
            WG.ClickItem = function(self, itemData)
                return F.onGlideClick(self, itemData)
            end
        end
        local WP = require("client.slua.umg.Wardrobe.subtab_parachute")
        if WP then
            if not WP._AddOutfitParaWrapped then
                WP._AddOutfitParaWrapped = true
                _G.AddOutfitParaClickOrig = WP.ClickItem
            end
            WP.ClickItem = function(self, itemData)
                return F.onParachuteClick(self, itemData)
            end
        end
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd and not fbd._AddOutfitAirborneFBHooked then
            fbd._AddOutfitAirborneFBHooked = true
            local oG = fbd.UpdateAircraftOrGliding
            fbd.UpdateAircraftOrGliding = function(self, putOnID, bAircraft)
                local r = oG(self, putOnID, bAircraft)
                local ins = tonumber(putOnID)
                if ins and ins > 0 then
                    local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                    local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                    local res = d and tonumber(d.resID)
                    if res and F.isGlideRes(res) then F.saveEquip(res, ins) end
                end
                return r
            end
            local oP = fbd.UpdateParachute
            if oP then
                fbd.UpdateParachute = function(self, insID)
                    local r = oP(self, insID)
                    local ins = tonumber(insID)
                    if ins and ins > 0 then
                        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                        local d = wd:GetValidHallDepotItemDataByInsID(ins) or wd:GetHallDepotItemDataByInsID(ins)
                        local res = d and tonumber(d.resID)
                        if res and F.isParachuteRes(res) then F.saveEquip(res, ins) end
                    end
                    return r
                end
            end
        end
    end)
    pcall(function()
        if not ModuleManager or not ModuleManager.GetModule then return end
        local FB = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.FashionBagEditUtils)
        if FB and not FB._AddOutfitFBBagHooked then
            FB._AddOutfitFBBagHooked = true
            local o = FB.PutOnFashionBagItem
            FB.PutOnFashionBagItem = function(self, itemData)
                if itemData then
                    F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
                end
                local r = o(self, itemData)
                if itemData then
                    local res = tonumber(itemData.res_id)
                    local ins = tonumber(itemData.ins_id)
                    if res and ins and (F.isGlideRes(res) or F.isParachuteRes(res)) then
                        F.saveEquip(res, ins)
                    end
                end
                return r
            end
        end
    end)
end

function F.putOnParachute(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or not F.isParachuteRes(resID) then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.SetParachute then fbd:SetParachute(insID) end
        if fbd.UpdateParachute then fbd:UpdateParachute(insID) end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.putOnGlider(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local d = wd:GetValidHallDepotItemDataByInsID(insID) or wd:GetHallDepotItemDataByInsID(insID)
        resID = d and tonumber(d.resID)
    end
    if not resID or resID <= 0 then return false end
    local st = F.depotSubType(insID, resID)
    if not F.isGlideRes(resID) and not GLIDER_SUBS[st] then return false end
    if not R.insToRes[insID] then R.insToRes[insID] = resID end
    F.ensureDepotItemValid(insID, resID)
    F.saveEquip(resID, insID)
    F.ensureInjectedItemAlive(nil, resID, insID)
    local ready = F.isResourcesReady(resID)
    if not ready then F.requestResourceDownload(resID) end
    local bAircraft = false
    pcall(function()
        local ModelDisplayTypeHelper = require("client.logic.avatar.ModelDisplayTypeHelper")
        local st = F.subType(F.cfg(resID))
        bAircraft = ModelDisplayTypeHelper.IsGlideSmoke(st)
    end)
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateAircraftOrGliding then
            fbd:UpdateAircraftOrGliding(insID, bAircraft)
        elseif fbd.SetGliding then
            fbd:SetGliding(insID)
            if DataMgr.UpdateEffect then DataMgr.UpdateEffect(insID) end
        end
    end)
    if ready then
        local item = {
            res_id = resID, resID = resID,
            instid = insID, ins_id = insID, insID = insID,
            expire_ts = 0, expireTS = 0, count = 1,
        }
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_on_rsp(NET_OK, item, nil, 1, insID, 0)
    end
    return true
end

function F.syncAirborneToDataMgr()
    F.applyPersistSlotsToCache()
    local cch = F.cache()
    local paraRes = F.getDesiredParachuteRes()
    local gliderRes = F.getDesiredGliderRes()
    if paraRes and paraRes > 0 and not cch.parachuteIns then
        cch.parachuteIns = F.resolveInsForRes(paraRes)
        cch.parachuteRes = paraRes
    end
    if gliderRes and gliderRes > 0 and not cch.gliderIns then
        cch.gliderIns = F.resolveInsForRes(gliderRes)
        cch.gliderRes = gliderRes
    end
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if cch.parachuteIns and tonumber(cch.parachuteIns) > 0 then
            if fbd.SetParachute then fbd:SetParachute(cch.parachuteIns) end
            if DataMgr.roleData then DataMgr.roleData.parachute = tostring(cch.parachuteIns) end
        end
        if cch.gliderIns and tonumber(cch.gliderIns) > 0 then
            local bAircraft = false
            if cch.gliderRes then
                pcall(function()
                    local MDH = require("client.logic.avatar.ModelDisplayTypeHelper")
                    bAircraft = not MDH.IsGlideSmoke(F.subType(F.cfg(cch.gliderRes)))
                end)
            end
            if fbd.UpdateAircraftOrGliding then
                fbd:UpdateAircraftOrGliding(cch.gliderIns, bAircraft)
            elseif fbd.SetGliding then
                fbd:SetGliding(cch.gliderIns)
                if DataMgr.UpdateEffect then DataMgr.UpdateEffect(cch.gliderIns) end
            end
            if DataMgr.roleData then
                if bAircraft then
                    DataMgr.roleData.aircraft_put_id = tostring(cch.gliderIns)
                    DataMgr.gliding = cch.gliderIns
                else
                    DataMgr.roleData.gliding = tostring(cch.gliderIns)
                end
            end
        end
    end)
end

function F.putOnGenericInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    if not F.isResourcesReady(resID) then
        F.requestResourceDownload(resID)
        return
    end
    F.saveEquip(resID, insID)
    local WRH = require("client.network.Protocol.WardRobeHandler")
    WRH.on_depot_put_on_rsp(NET_OK, { res_id = resID, count = 1, instid = insID }, nil, 1, insID, 0)
end

function F.clearEquipCache(resID)
    local st = F.subType(F.cfg(resID))
    local cch = F.cache()
    if st == OUTFIT_SUB then
        if F.wardrobeTab(resID) == TAB_CLOTHES then
            cch.tshirtRes, cch.tshirtIns = nil, nil
            _G.AddOutfitLastLobbyTshirtRes = nil
            F.persistForgetSlot("tshirt")
        else
            cch.outfitRes, cch.outfitIns = nil, nil
            _G.AddOutfitLastLobbyOutfitRes = nil
            F.persistForgetSlot("outfit")
        end
    elseif st == HAT_SUB or HEAD_SUBS[st] then
        cch.hatRes, cch.hatIns = nil, nil
        _G.AddOutfitLastLobbyHatRes = nil
        F.persistForgetSlot("hat")
    elseif st == MASK_SUB then
        cch.maskRes, cch.maskIns = nil, nil
        _G.AddOutfitLastLobbyMaskRes = nil
        F.persistForgetSlot("mask")
    elseif st == GLASS_SUB then
        cch.glassRes, cch.glassIns = nil, nil
        _G.AddOutfitLastLobbyGlassRes = nil
        F.persistForgetSlot("glass")
    elseif st == PANTS_SUB then
        cch.pantsRes, cch.pantsIns = nil, nil
        _G.AddOutfitLastLobbyPantsRes = nil
        F.persistForgetSlot("pants")
    elseif st == SHOES_SUB then
        cch.shoesRes, cch.shoesIns = nil, nil
        _G.AddOutfitLastLobbyShoesRes = nil
        F.persistForgetSlot("shoes")
    elseif BAG_SUBS[st] then
        cch.bagRes, cch.bagIns = nil, nil
        _G.AddOutfitLastLobbyBagRes = nil
        F.persistForgetSlot("bag")
    elseif HELMET_SUBS[st] then
        cch.helmetRes, cch.helmetIns = nil, nil
        _G.AddOutfitLastLobbyHelmetRes = nil
        F.persistForgetSlot("helmet")
    elseif st == PARACHUTE_SUB then
        cch.parachuteRes, cch.parachuteIns = nil, nil
        _G.AddOutfitLastLobbyParachuteRes = nil
        F.persistForgetSlot("parachute")
    elseif F.isGlideRes(resID) then
        cch.gliderRes, cch.gliderIns = nil, nil
        _G.AddOutfitLastLobbyGliderRes = nil
        F.persistForgetSlot("glider")
    elseif st == GLOVES_SUB then
        cch.glovesRes, cch.glovesIns = nil, nil
        _G.AddOutfitLastLobbyGlovesRes = nil
        F.persistForgetSlot("gloves")
    end
    _matchApplied = false
    F.invalidateSocialWearCache()
    F.perfInvalidateLobby()
    F.persistMarkDirty()
end

function F.takeOffInjected(insID)
    insID = tonumber(insID)
    local resID = R.insToRes[insID]
    if not resID then return end
    local st = F.subType(F.cfg(resID))

    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        WRH.on_depot_put_down_rsp(NET_OK, { res_id = resID, count = 1 }, insID)
    end)

    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        AvatarData.RemoveRoleWearDataByValue(insID)
    end)
    if st == HAT_SUB or HEAD_SUBS[st] then
        pcall(function()
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag and tonumber(bag.head_show) == insID then fbd:SetHeadShow(0) end
        end)
    end
    if BAG_SUBS[st] or HELMET_SUBS[st] then
        pcall(function()
            local t = DataMgr.equipmentSkinInsIDTable
            if t then
                for _, k in ipairs({ st, 504, 505 }) do
                    if tonumber(t[k]) == insID then t[k] = 0 end
                end
            end
            local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
            local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
            if bag then
                if tonumber(bag.bag_skin) == insID then bag.bag_skin = 0 end
                if tonumber(bag.helmet_skin) == insID then bag.helmet_skin = 0 end
            end
        end)
    end

    F.clearEquipCache(resID)
    pcall(function() F.syncFashionBagRolewear() end)
end

function F.syncWeaponArmorySilent(weaponID, insID)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return end
    local resID = R.insToRes[insID]
    if not resID then return end
    local Arm = require("client.logic.armory.logic_armory")
    Arm.rsp_list = Arm.rsp_list or { skin_list = {}, install_list = {} }
    Arm.rsp_list.install_list = Arm.rsp_list.install_list or {}
    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    pcall(function()
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        if fbd.UpdateCurrentFashionBagWeaponSkin then
            fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
        end
    end)
end

function F.equipWeaponSkin(weaponID, insID, forceVisual)
    weaponID, insID = tonumber(weaponID), tonumber(insID)
    if not weaponID or not insID or not F.isInjectedIns(insID) then return false end
    local resID = R.insToRes[insID]
    if not resID then return false end

    _G.AddOutfitWeaponEquipped = _G.AddOutfitWeaponEquipped or {}
    if not forceVisual and F.isWeaponVisuallyEquipped(weaponID, insID) then
        F.syncWeaponArmorySilent(weaponID, insID)
        return false
    end
    F.saveEquip(resID, insID)

    local Arm = require("client.logic.armory.logic_armory")
    local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
    local HT = require("client.logic.lobby.hall_theme_utils")
    local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")

    F.injectArmory(resID, insID)
    Arm.rsp_list.install_list[weaponID] = { skin_id = insID }
    if fbd.UpdateCurrentFashionBagWeaponSkin then
        fbd:UpdateCurrentFashionBagWeaponSkin(weaponID, insID)
    end

    local bagIdx = fbd:GetFashionBagUseIndex()
    HT.proc_skin_list_chg("weapon_skin", weaponID, insID, bagIdx, {})

    wgl:SetGunID(weaponID)
    wgl:UpdateCurrentGunAvatar(weaponID, insID)

    if EventSystem and EVENTTYPE_ARMORY and EVENTID_ARMORY_EQUIP_STAT_CHANGE then
        EventSystem:postEvent(EVENTTYPE_ARMORY, EVENTID_ARMORY_EQUIP_STAT_CHANGE, resID)
    end
    if EventSystem and EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
        EventSystem:postEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, resID)
    end
    _G.AddOutfitWeaponEquipped[weaponID] = insID
    return true
end

local SOCIAL = _G.AddOutfitSocialState or {}
_G.AddOutfitSocialState = SOCIAL
SOCIAL.debGen = SOCIAL.debGen or 0
SOCIAL.wearPatchKey = SOCIAL.wearPatchKey or nil
SOCIAL.snapshotKey = SOCIAL.snapshotKey or nil
SOCIAL.fullSnapshot = SOCIAL.fullSnapshot or nil

function F.socialDebounce(sec, fn)
    SOCIAL.debGen = (SOCIAL.debGen or 0) + 1
    local gen = SOCIAL.debGen
    F.later(sec, function()
        if gen ~= SOCIAL.debGen then return end
        pcall(fn)
    end)
end

function F.getLobbyCurPage()
    local p = nil
    pcall(function()
        local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
        if LMC.GetCurPage then p = LMC.GetCurPage() end
    end)
    return p
end

function F.isLobbyLeftPage()
    return ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left
end

function F.getWeaponSkinResFast()
    local cch = F.cache()
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local w = wid > 0 and cch.weapons[wid] or nil
    if w and w.resID and w.resID > 0 then return w.resID end
    for _, ww in pairs(cch.weapons) do
        if ww.resID and ww.resID > 0 then return ww.resID end
    end
    return nil
end

function F.resolveLobbyWeaponSkinRes()
    if LOBBY.skinResolved then return LOBBY.cachedSkin end
    local wid = tonumber(DataMgr.Weapon_ID) or 0
    local skin = F.getWeaponSkinResFast()
    if skin and skin > 0 then return skin end

    if wid > 0 then
        local fromMatch = F.getMatchWeaponSkin(wid)
        if fromMatch and fromMatch > 0 then return fromMatch end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, s in pairs(MATCH_CONFIG.weaponSkins) do
            s = tonumber(s)
            if s and s > 0 then return s end
        end
    end

    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local entry = Arm.rsp_list and Arm.rsp_list.install_list
            and Arm.rsp_list.install_list[wid > 0 and wid or 101004]
        local insID = tonumber(entry and entry.skin_id) or 0
        if insID > 0 and F.isInjectedIns(insID) then
            skin = tonumber(R.insToRes[insID])
        elseif insID > 0 then
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(insID)
            if d and d.resID then skin = tonumber(d.resID) end
        end
    end)
    if skin and skin > 0 then return skin end

    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl.GetSkinIdByWeaponID and wid > 0 then
            local insID = tonumber(wgl:GetSkinIdByWeaponID(wid)) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                skin = tonumber(R.insToRes[insID])
            end
        end
    end)
    LOBBY.skinResolved = true
    LOBBY.cachedSkin = (skin and skin > 0) and skin or nil
    return LOBBY.cachedSkin
end

function F.resolveLobbyOutfitRes()
    if LOBBY.outfitResolved then return LOBBY.cachedOutfit end
    local cch = F.cache()
    local outfitRes = tonumber(cch.outfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    outfitRes = tonumber(_G.AddOutfitLastLobbyOutfitRes) or 0
    if outfitRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = outfitRes
        return outfitRes
    end
    if MATCH_CONFIG.outfitRes and tonumber(MATCH_CONFIG.outfitRes) > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = tonumber(MATCH_CONFIG.outfitRes)
        return LOBBY.cachedOutfit
    end

    local injectedRes, anyRes
    pcall(function()
        local AvatarData = require("client.logic.data.AvatarData")
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        local function resFromIns(ins)
            ins = tonumber(ins)
            if not ins or ins <= 0 then return nil end
            if F.isInjectedIns(ins) then return tonumber(R.insToRes[ins]) end
            local d = wd:GetHallDepotItemDataByInsID(ins)
            return d and tonumber(d.resID) or nil
        end
        for _, ins in pairs(AvatarData.GetRoleWear()) do
            local res = resFromIns(ins)
            if res and F.isSuitRes(res) then
                if F.isInjectedRes(res) then injectedRes = res end
                anyRes = anyRes or res
            end
        end
        local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
        local bag = fbd.GetCurrentFashionBag and fbd:GetCurrentFashionBag()
        if bag and bag.rolewear_list then
            for _, ins in pairs(bag.rolewear_list) do
                local res = resFromIns(ins)
                if res and F.isSuitRes(res) then
                    if F.isInjectedRes(res) then injectedRes = res end
                    anyRes = anyRes or res
                end
            end
        end
    end)
    if injectedRes and injectedRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = injectedRes
        return injectedRes
    end
    if anyRes and anyRes > 0 then
        LOBBY.outfitResolved = true
        LOBBY.cachedOutfit = anyRes
        return anyRes
    end
    LOBBY.outfitResolved = true
    LOBBY.cachedOutfit = nil
    return nil
end

function F.rememberLobbyOutfitRes(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 or not F.isSuitRes(resID) then return end
    _G.AddOutfitLastLobbyOutfitRes = resID
    F.invalidateLobbyResolved()
    local cch = F.cache()
    if not cch.outfitRes or cch.outfitRes <= 0 then
        cch.outfitRes = resID
        if F.isInjectedRes(resID) then cch.outfitIns = R.resToIns[resID] end
    end
end

function F.wearPatchKey()
    local outfit = F.resolveLobbyOutfitRes() or 0
    local skin = F.resolveLobbyWeaponSkinRes() or 0
    local openGun = 1
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then openGun = lds.data.OpenGun and 1 or 0 end
    end)
    return outfit .. "_" .. skin .. "_" .. openGun
end

function F.syncDepotShowWeaponFlags(depot)
    depot = depot or {}
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data then
            if lds.data.OpenGun ~= nil then depot.weapon = lds.data.OpenGun end
            if lds.data.OpenSocialWeapon ~= nil then depot.social_weapon = lds.data.OpenSocialWeapon end
        end
    end)
    return depot
end

function F.applyInjectedPspace(roleData)
    if not roleData then return end
    roleData.bshow = true
    roleData.pspace_wear_ext = roleData.pspace_wear_ext or {}
    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 }
        roleData.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { skinRes, 0, 0 }
        roleData.depot_show_info = roleData.depot_show_info or {}
        if roleData.depot_show_info.weapon == nil then
            roleData.depot_show_info.weapon = true
        end
    end
    roleData.depot_show_info = F.syncDepotShowWeaponFlags(roleData.depot_show_info)
end

function F.patchSelfWearCache(force)
    local key = F.wearPatchKey()
    if not force and SOCIAL.wearPatchKey == key then return false end
    SOCIAL.wearPatchKey = key
    SOCIAL.snapshotKey = nil
    SOCIAL.fullSnapshot = nil

    local myUid = tonumber(DataMgr.roleData.uid)
    if not myUid then return false end

    local changed = false
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local d = BD:GetCacheData(myUid)
        if not d then
            BD:OnHandleMsgDataAndCallback(myUid, F.buildLocalRoleDataForCoupleAvatar())
            return true
        end
        local oldCloth = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local oldSkin = d.pspace_wear_ext and d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        F.applyInjectedPspace(d)
        local nc = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH]
        local ns = d.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN]
        if oldCloth ~= nc or oldSkin ~= ns or not d.bshow then changed = true end
    end)
    return force or changed
end

function F.requestSocialAvatarRefresh()
    pcall(function()
        if EventSystem and EVENTTYPE_LOBBY_SOCIAL and EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR then
            EventSystem:postEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_SOCIAL_LOBBY_REFRESH_AVATAR)
        end
    end)
end

function F.onSocialWearDirty(forceRefresh)
    SOCIAL.lastHandSkin = nil
    if F.patchSelfWearCache(forceRefresh) then
        F.requestSocialAvatarRefresh()
    end
end

function F.buildLocalRoleDataForCoupleAvatar()
    local key = F.wearPatchKey()
    if SOCIAL.fullSnapshot and SOCIAL.snapshotKey == key then
        return SOCIAL.fullSnapshot
    end
    F.syncWeaponCacheFromLobby()
    local cch = F.cache()
    local ad = DataMgr.avatarData or {}
    local gender = tonumber(ad.gamegender) or 2
    if gender < 1 then gender = 2 end

    local data = {
        uid = DataMgr.roleData.uid,
        gender = gender,
        bshow = true,
        pspace_wear_ext = {
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HEAD] = { tonumber(ad.headid) or 401993, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_HAIR] = { tonumber(ad.hairid) or 40601001, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON] = { 0, 0, 0 },
            [ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN] = { 0, 0, 0 },
        },
        depot_show_info = {
            weapon = true, social_weapon = true, idle = true,
            helmet = true, bag = true, vehicle = true, hand = true,
        },
    }

    local outfitRes = F.resolveLobbyOutfitRes()
    if outfitRes and outfitRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_CLOTH] = { outfitRes, 0, 0 }
    end

    local skinRes = F.resolveLobbyWeaponSkinRes()
    if skinRes and skinRes > 0 then
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPON][1] = 0
        data.pspace_wear_ext[ENUM_AVATAR_SHOW_TYPE.SHOW_POS_WEAPONSKIN][1] = skinRes
    end
    data.depot_show_info = F.syncDepotShowWeaponFlags(data.depot_show_info)
    SOCIAL.fullSnapshot = data
    SOCIAL.snapshotKey = F.wearPatchKey()
    return data
end

local _myUidCached
function F.isMyWearData(wearData)
    if not wearData then return false end
    if not _myUidCached then
        pcall(function() _myUidCached = tonumber(DataMgr.roleData.uid) end)
    end
    return _myUidCached and tonumber(wearData.uid) == _myUidCached
end

function F.mergeInjectedWeaponIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local skinRes = F.resolveLobbyWeaponSkinRes()
    wearData.depot_show_info = F.syncDepotShowWeaponFlags(wearData.depot_show_info)
    if not skinRes or skinRes <= 0 then return end
    wearData.mainWeaponInfo = wearData.mainWeaponInfo or {
        weaponResId = 0, weaponSkinId = 0,
        diyInfo = { diyWeaponId = 0, diyDefaultScheme = false, diyScheme = nil },
    }
    if wearData.mainWeaponInfo.weaponSkinId == skinRes
        and (tonumber(wearData.mainWeaponInfo.weaponResId) or 0) == 0 then
        return
    end
    wearData.mainWeaponInfo.weaponSkinId = skinRes
    wearData.mainWeaponInfo.weaponResId = 0
end

function F.equipSocialHandWeapon(avatar, skinRes)
    if not avatar or not skinRes or skinRes <= 0 then return end
    if SOCIAL.lastHandSkin == skinRes then return end
    SOCIAL.lastHandSkin = skinRes
    pcall(function()
        avatar:PutonEquipment(skinRes, nil, { bIsUse = true })
    end)
end

function F.shouldShowHandWeapon()
    local show = true
    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        if lds.data and lds.data.OpenGun ~= nil then
            show = lds.data.OpenGun ~= false
        end
    end)
    return show
end

function F.mergeInjectedOutfitIntoWearData(wearData)
    if not F.isMyWearData(wearData) then return end
    local outfitRes = F.resolveLobbyOutfitRes()
    if not outfitRes or outfitRes <= 0 then return end
    F.rememberLobbyOutfitRes(outfitRes)
    local AvatarData = require("client.logic.data.AvatarData")
    local converted = AvatarData.ConvertToAvatarCustom({ outfitRes, 0, 0 })
    if not converted then return end
    wearData.WearInfoList = wearData.WearInfoList or {}
    local replaced = false
    for i, e in ipairs(wearData.WearInfoList) do
        if e and e.ItemID and F.isSuitRes(e.ItemID) then
            wearData.WearInfoList[i] = converted
            replaced = true
            break
        end
    end
    if not replaced then
        table.insert(wearData.WearInfoList, converted)
    end
end

function F.mergeInjectedIntoWearData(wearData)
    if not wearData then return end
    F.mergeInjectedWeaponIntoWearData(wearData)
    F.mergeInjectedOutfitIntoWearData(wearData)
end

function F.reapplyLobbyEquipped()
    if not GameStatus or not GameStatus.IsInLobbyOrMainCity or not GameStatus.IsInLobbyOrMainCity() then
        return
    end
    F.syncWeaponCacheFromLobby()
    F.applyPersistSlotsToCache()
    local curPage = F.getLobbyCurPage()

    if ENUM_LobbyPageType and curPage == ENUM_LobbyPageType.Left then
        F.onSocialWearDirty(true)
        return
    end

    local cch = F.cache()
    if cch.outfitIns and F.isInjectedIns(cch.outfitIns) then
        F.putOnOutfit(cch.outfitIns)
    end
    if cch.hatIns and F.isInjectedIns(cch.hatIns) then
        F.putOnHat(cch.hatIns)
    end
    if cch.maskIns and F.isInjectedIns(cch.maskIns) then
        F.putOnRoleWear(cch.maskIns)
    end
    if cch.glassIns and F.isInjectedIns(cch.glassIns) then
        F.putOnRoleWear(cch.glassIns)
    end
    if cch.tshirtIns and F.isInjectedIns(cch.tshirtIns) then
        F.putOnRoleWear(cch.tshirtIns)
    end
    if cch.pantsIns and F.isInjectedIns(cch.pantsIns) then
        F.putOnRoleWear(cch.pantsIns)
    end
    if cch.shoesIns and F.isInjectedIns(cch.shoesIns) then
        F.putOnRoleWear(cch.shoesIns)
    end
    if cch.bagIns and F.isInjectedIns(cch.bagIns) then
        F.putOnRoleWear(cch.bagIns)
    end
    if cch.helmetIns and F.isInjectedIns(cch.helmetIns) then
        F.putOnRoleWear(cch.helmetIns)
    end
    if cch.parachuteIns then
        F.putOnParachute(cch.parachuteIns)
    end
    if cch.gliderIns then
        F.putOnGlider(cch.gliderIns)
    end
    if cch.glovesIns and F.isInjectedIns(cch.glovesIns) then
        F.putOnGloves(cch.glovesIns)
    end

    local mainWid = tonumber(DataMgr.Weapon_ID) or 0
    local w = mainWid > 0 and cch.weapons[mainWid] or nil
    if w and w.resID and w.resID > 0 then
        if w.insID and F.isInjectedIns(w.insID) then
            F.equipWeaponSkin(mainWid, w.insID)
        else
            pcall(function() DataMgr.InitWeaponData(mainWid, w.resID, w.insID or 0) end)
        end
    end

    pcall(function()
        local uid = tostring(DataMgr.roleData.uid)
        local LAM = require("client.logic.avatar.LobbyAvatarManager")
        local TAM = require("client.logic.avatar.logic_team_avatar_manager")
        if w and w.resID and w.resID > 0 and TAM.GetAvatarByUid(uid) then
            LAM.EquipWeapon(uid, { weaponId = mainWid, skinId = w.resID }, nil, true)
        end
    end)

    F.reapplyVehicleSlotsFromConfig(true)
    F.reapplyHallThemeFromConfig(true)
    F.reapplyWeaponsFromConfig()
    pcall(F.applyVehicleSkinsToPC)
end

F.scheduleLobbyReapplyOnce = function()
    if LOBBY.reapplyDone or LOBBY.reapplyScheduled then return end
    LOBBY.reapplyScheduled = true
    F.later(2.0, function()
        LOBBY.reapplyScheduled = false
        if LOBBY.reapplyDone then return end
        LOBBY.reapplyDone = true
        F.reapplyLobbyEquipped()
    end)
end

function F.hookLobbySwipePersistence()
    if _G.AddOutfitLobbySwipeHooked then return end
    _G.AddOutfitLobbySwipeHooked = true
    pcall(function()
        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
        local oRsp = BD.on_get_avatar_show_rsp
        BD.on_get_avatar_show_rsp = function(self, res, target_uid, data)
            oRsp(self, res, target_uid, data)
                if tonumber(target_uid) == tonumber(DataMgr.roleData.uid) then
                F.patchSelfWearCache(true)
                SOCIAL.forceAvatarRedraw = true
                SOCIAL.lastHandSkin = nil
                if ENUM_LobbyPageType and F.getLobbyCurPage() == ENUM_LobbyPageType.Left then
                    F.requestSocialAvatarRefresh()
                end
            end
        end
    end)

    pcall(function()
        local AC = require("client.slua.logic.avatar.avatar_common")
        local oGetWear = AC.GetWearDataFromRoleData
        AC.GetWearDataFromRoleData = function(roleData)
            local wearData = oGetWear(roleData)
            if wearData and roleData and tonumber(roleData.uid) == tonumber(DataMgr.roleData.uid)
                and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            return wearData
        end
        local oUp = AC.UpdateAvatar
        AC.UpdateAvatar = function(avatar, wearData, isShowWeapon, isShowHelmet, isShowBag)
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                F.mergeInjectedIntoWearData(wearData)
            end
            local showGun = isShowWeapon and F.shouldShowHandWeapon()
            if wearData and wearData.depot_show_info then
                showGun = showGun and wearData.depot_show_info.weapon ~= false
            end
            if F.isMyWearData(wearData) and F.isLobbyLeftPage() then
                for _, e in ipairs(wearData.WearInfoList or {}) do
                    if e and e.ItemID and F.isInjectedRes(e.ItemID) and F.isSuitRes(e.ItemID) then
                        F.rememberLobbyOutfitRes(e.ItemID)
                        break
                    end
                end
            end
            local ret = oUp(avatar, wearData, showGun, isShowHelmet, isShowBag)
            if showGun and F.isMyWearData(wearData) and avatar and F.isLobbyLeftPage() then
                local skin = tonumber(wearData.mainWeaponInfo and wearData.mainWeaponInfo.weaponSkinId) or 0
                if skin <= 0 then skin = F.resolveLobbyWeaponSkinRes() or 0 end
                if skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
            end
            return ret
        end
    end)

    pcall(function()
        local CA = require("client.logic.avatar.CoupleAvatar")
        local Cfg = require("client.slua.logic.lobby.Left.CoupleAvatarConfig")
        local oMulti = CA._UpdateMultiAvatar
        if oMulti then
            CA._UpdateMultiAvatar = function(self, avatar, avatarType)
                local isSelf = avatarType == Cfg.AvatarType.Self
                    and self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
                if isSelf and F.isLobbyLeftPage() then
                    pcall(function()
                        local BD = ModuleManager.GetModule(ModuleManager.DataModuleConfig.BasicDataAvatarWearInfo)
                        local d = BD:GetCacheData(tonumber(self.SelfUID))
                        if d then F.applyInjectedPspace(d) end
                    end)
                    if SOCIAL.forceAvatarRedraw then
                        self.CompareDataCache[avatarType] = nil
                        SOCIAL.forceAvatarRedraw = nil
                    end
                end
                oMulti(self, avatar, avatarType)
                if isSelf and F.isLobbyLeftPage() and self.isShowWeapon ~= false and F.shouldShowHandWeapon() then
                    local skin = F.resolveLobbyWeaponSkinRes()
                    if skin and skin > 0 then F.equipSocialHandWeapon(avatar, skin) end
                end
            end
        end
        local oHideCheck = CA.CheckSelfIsHideAvatar
        CA.CheckSelfIsHideAvatar = function(self, nSelfUId, tRoleData)
            if F.isLobbyLeftPage() and tostring(nSelfUId) == tostring(DataMgr.roleData.uid) then
                return false
            end
            return oHideCheck(self, nSelfUId, tRoleData)
        end

        local oUpdate = CA.Update
        CA.Update = function(self)
            if not F.isLobbyLeftPage() then
                return oUpdate(self)
            end
            local isSelf = self.SelfUID and tostring(self.SelfUID) == tostring(DataMgr.roleData.uid)
            local oHide = CA.HideAvatars
            if isSelf then
                CA.HideAvatars = function() end
            end
            local ok, err = pcall(oUpdate, self)
            CA.HideAvatars = oHide
        end

        local oRecv = CA.OnReceiveData
        CA.OnReceiveData = function(self, uid, data)
            if F.isLobbyLeftPage() and uid == self.SelfUID and tostring(uid) == tostring(DataMgr.roleData.uid) then
                if data then
                    F.applyInjectedPspace(data)
                else
                    data = F.buildLocalRoleDataForCoupleAvatar()
                end
            end
            return oRecv(self, uid, data)
        end
    end)

    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_START then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_START, function(_, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    local o = F.resolveLobbyOutfitRes()
                    if o then F.rememberLobbyOutfitRes(o) end
                    F.patchSelfWearCache(true)
                    SOCIAL.forceAvatarRedraw = true
                end
            end)
        end
        if EVENTTYPE_LOBBY and EVENTID_SWITCHTO_PAGE_END then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_SWITCHTO_PAGE_END, function(_, _, _, toPage)
                if ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Left then
                    F.syncWeaponCacheFromLobby()
                    SOCIAL.lastHandSkin = nil
                    F.socialDebounce(0.45, function()
                        F.onSocialWearDirty(true)
                    end)
                elseif ENUM_LobbyPageType and toPage == ENUM_LobbyPageType.Mid then
                    SOCIAL.wearPatchKey = nil
                    F.invalidateLobbyResolved()
                    if not LOBBY.reapplyDone then
                        F.socialDebounce(0.5, F.scheduleLobbyReapplyOnce)
                    end
                end
            end)
        end
        if EVENTTYPE_LOBBY_SOCIAL and EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA then
            EventSystem:registEvent(EVENTTYPE_LOBBY_SOCIAL, EVENTID_GOT_SOCIAL_LOBBY_SHOW_DATA, function(_, _, nUId)
                if tonumber(nUId) == tonumber(DataMgr.roleData.uid) then
                    F.socialDebounce(0.2, function() F.patchSelfWearCache(false) end)
                end
            end)
        end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function()
                SOCIAL.wearPatchKey = nil
                SOCIAL.snapshotKey = nil
                F.syncWeaponCacheFromLobby()
                
                local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
                if curPage == ENUM_LobbyPageType.Left then
                    F.socialDebounce(0.25, function() F.onSocialWearDirty(true) end)
                end
                
                
                F.socialDebounce(0.3, function()
                    if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
                end)
            end)
        end
    end)

    pcall(function()
        local lds = require("client.slua.logic.wardrobe.logic_display_setting")
        local oSwitch = lds.SwitchGun
        lds.SwitchGun = function(...)
            local r = oSwitch(...)
            SOCIAL.wearPatchKey = nil
            
            local curPage = ENUM_LobbyPageType and F.getLobbyCurPage()
            if curPage == ENUM_LobbyPageType.Left then
                F.socialDebounce(0.2, function() F.onSocialWearDirty(true) end)
            end
            
            
            F.socialDebounce(0.3, function()
                if F.reapplyLobbyEquipped then F.reapplyLobbyEquipped() end
            end)
            
            return r
        end
    end)
end

function F.hookDepotInit()
    pcall(function()
        local WDE = require("client.slua.logic.wardrobe.WardrobeDataEntity")
        if WDE._AddOutfitInitHooked then return end
        WDE._AddOutfitInitHooked = true
        local orig = WDE.InitData
        WDE.InitData = function(self, pkg)
            orig(self, pkg)
            _G.AddOutfitUnexpireDone = false
            pcall(function()
                if F.injectAll(self) then
                    F.scheduleInjectRefresh()
                    LOBBY.reapplyDone = false
                    LOBBY.reapplyScheduled = false
                    F.scheduleLobbyReapplyOnce()
                end
            end)
        end
    end)
end

function F.hookWardrobeData()
    pcall(function()
        local wd = require("client.slua.logic.wardrobe.wardrobe_data")
        if wd._AddOutfitDataHooked then return end
        wd._AddOutfitDataHooked = true
        local function wrapGet(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, insID, ...)
                insID = tonumber(insID)
                local r
                if F.isInjectedIns(insID) then
                    local e = F.getEntity()
                    if e then r = e:GetDataByInsID(insID) end
                else
                    r = o(self, insID, ...)
                end
                if r and (F.isInjectedIns(insID) or F.isInjectedRes(r.resID or r.res_id)) then
                    r.expire_ts = 0
                    r.expireTS = 0
                    r.valid_hours = 0
                end
                return r
            end
        end
        wrapGet("GetHallDepotItemDataByInsID")
        wrapGet("GetValidHallDepotItemDataByInsID")
        local function wrapBool(name)
            local o = wd[name]
            if not o then return end
            wd[name] = function(self, id, ...)
                if F.isInjectedRes(tonumber(id)) or F.isInjectedIns(tonumber(id)) then return true end
                return o(self, id, ...)
            end
        end
        wrapBool("HasItem")
        wrapBool("HasValidItem")
        wrapBool("CheckHasPermanentItem")
    end)
end

function F.hookPageFilter()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPageFilterHooked then return end
        wl._AddOutfitPageFilterHooked = true
        local o1 = wl.IsValidCurrentPageItem
        wl.IsValidCurrentPageItem = function(self, mainTab, subTab, v, t)
            if v and F.isInjectedRes(v.resID) then
                local itemTab = tonumber(v.subTabType) or F.wardrobeTab(v.resID)
                if itemTab and itemTab == subTab then
                    if mainTab == PAGE_AVATAR or mainTab == PAGE_VEHICLE then return true end
                    if mainTab == PAGE_PARACHUTE and F.isHallThemeRes(v.resID) then return true end
                end
            end
            return o1(self, mainTab, subTab, v, t)
        end
        local o2 = wl.IsCanUse
        wl.IsCanUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o2(self, resId)
        end
        local o3 = wl.IsCharacterUse
        wl.IsCharacterUse = function(self, resId)
            if F.isInjectedRes(resId) then return true end
            return o3(self, resId)
        end
        local o4 = wl.GetWardrobeInsIdByResId
        wl.GetWardrobeInsIdByResId = function(self, resid)
            resid = tonumber(resid)
            if F.isInjectedRes(resid) then return R.resToIns[resid] end
            return o4(self, resid)
        end
    end)
end

function F.hookArmory()
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        if Arm._AddOutfitArmoryHooked then return end
        Arm._AddOutfitArmoryHooked = true
        local oa = Arm.get_weapon_skin_list_rsp
        Arm.get_weapon_skin_list_rsp = function(a, b, c, d)
            oa(a, b, c, d)
            F.mergeInjectedArmorySkins()
        end
        local oi = Arm.install_weapon_skin
        Arm.install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return oi(cd, wid, ins)
        end
    end)
    pcall(function()
        local AH = require("client.network.Protocol.ArmoryHandler")
        if AH._AddOutfitArmorySendHooked then return end
        AH._AddOutfitArmorySendHooked = true
        local o = AH.send_install_weapon_skin
        AH.send_install_weapon_skin = function(cd, wid, ins)
            ins = tonumber(ins)
            if F.isWeaponSkinIns(ins) then
                wid = tonumber(F.weaponIdFromSkin(R.insToRes[ins]) or wid)
                F.equipWeaponSkin(wid, ins)
                return
            end
            return o(cd, wid, ins)
        end
    end)
end

function F.hookGunSkinId()
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        if wgl._AddOutfitGunSkinHooked then return end
        wgl._AddOutfitGunSkinHooked = true
        local o = wgl.GetSkinIdByWeaponID
        wgl.GetSkinIdByWeaponID = function(self, wid)
            local c = F.cache()
            local w = c.weapons[wid]
            if w and F.isWeaponSkinIns(w.insID) then return w.insID end
            local Arm = require("client.logic.armory.logic_armory")
            if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                local sid = Arm.rsp_list.install_list[wid].skin_id
                if sid and F.isWeaponSkinIns(sid) then return sid end
            end
            return o(self, wid)
        end
    end)
end

function F.hookPutOn()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutOnHooked then return end
        WRH._AddOutfitPutOnHooked = true
        local o = WRH.send_depot_put_on_req
        WRH.send_depot_put_on_req = function(insID, extra)
            insID = tonumber(insID)
            if F.tryLocalWearByIns(insID) then return end
            return o(insID, extra)
        end
    end)
end

function F.hookPutDown()
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        if WRH._AddOutfitPutDownHooked then return end
        WRH._AddOutfitPutDownHooked = true
        local o = WRH.send_depot_put_down_req
        WRH.send_depot_put_down_req = function(insID)
            if F.isInjectedIns(tonumber(insID)) then
                F.takeOffInjected(insID)
                return
            end
            return o(insID)
        end
        local ob = WRH.send_depot_batch_put_down_req
        WRH.send_depot_batch_put_down_req = function(instid_list)
            local rest = {}
            for _, id in ipairs(instid_list or {}) do
                if F.isInjectedIns(tonumber(id)) then
                    F.takeOffInjected(id)
                else
                    rest[#rest + 1] = id
                end
            end
            if #rest > 0 then return ob(rest) end
        end
    end)
end

function F.hookVehicleSwitchEffect()
    if _G.AddOutfitVehSwitchHooked then return end
    pcall(function()
        local VAC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")
        local impl = VAC and VAC.__inner_impl
        if not impl or impl._AddOutfitVehSwitchHooked then return end
        impl._AddOutfitVehSwitchHooked = true

        if not _G.AddOutfitVehOrigCanSwitch then
            _G.AddOutfitVehOrigCanSwitch = impl.CheckCanPlaySkinSwitchEffect
        end
        impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            return true
        end

        if not _G.AddOutfitVehOrigShowSwitch then
            _G.AddOutfitVehOrigShowSwitch = impl.ShowVehicleSwitchEffect
        end
        impl.ShowVehicleSwitchEffect = function(self)
            if self.IsLobbyActor and self:IsLobbyActor() then return false end
            if not F.isInRealMatch() then return false end
            if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
                self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
            end
            local vehicleActor = self:GetOwner()
            if not slua.isValid(vehicleActor) then return false end
            if self.uSwitchEffectActor then
                self:StopSkinSwitchEffect()
                pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                self.uSwitchEffectActor = nil
            end
            if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
                local defId = 0
                pcall(function() defId = self:GetDefaultAvatarID() or 0 end)
                self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or defId or 0
            end
            local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
            local bIsLobbyActor = self:IsLobbyActor()
            local world = slua_GameFrontendHUD:GetWorld()
            local VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
            local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
            local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
            self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
            if not slua.isValid(self.uSwitchEffectActor) then
                self.uSwitchEffectActor = nil
                return false
            end
            self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
            self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
            self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
            pcall(function() self:HideParticles() end)
            self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
            self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
            self.uSwitchEffectActor:StartVehicleSwitchEffect(
                vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
            self.uOldVehicleMeshAnimClass = nil
            return true
        end

        if not _G.AddOutfitVehOrigBeginPlay then
            _G.AddOutfitVehOrigBeginPlay = impl.ReceiveBeginPlay
        end
        local oBegin = _G.AddOutfitVehOrigBeginPlay
        impl.ReceiveBeginPlay = function(self)
            oBegin(self)
            pcall(function()
                if self.uSwitchEffectActor then
                    self:StopSkinSwitchEffect()
                    pcall(function() self.uSwitchEffectActor:K2_DestroyActor() end)
                    self.uSwitchEffectActor = nil
                end
                self.lastEquipedAvatarId = 0
                if self.IsLobbyActor and self:IsLobbyActor() then
                    self.curSwitchEffectId = 0
                elseif F.isInRealMatch() then
                    self.curSwitchEffectId = VEH_SWITCH_EFFECT_ID
                else
                    self.curSwitchEffectId = 0
                end
            end)
        end

        if impl.LuaIsAssetsAlreadyAvailable and not _G.AddOutfitVehOrigAssets then
            _G.AddOutfitVehOrigAssets = impl.LuaIsAssetsAlreadyAvailable
            impl.LuaIsAssetsAlreadyAvailable = function(self, avatarId)
                if F.isVehicleSkinAllowed(tonumber(avatarId)) then return true end
                return _G.AddOutfitVehOrigAssets(self, avatarId)
            end
        end

        _G.AddOutfitVehSwitchHooked = true
    end)
end

function F.hookVehicleChassisLight()
    if _G.AddOutfitVehChassisHooked then return end
    pcall(function()
        local LIC = require("GameLua.Activity.Commercialize.Actor.ActorComponent.BP_VehicleLicenseComponentBase")
        if LIC and LIC.CheckHasVehicleDownloaded and not _G.AddOutfitVehOrigLicDownload then
            _G.AddOutfitVehOrigLicDownload = LIC.CheckHasVehicleDownloaded
            LIC.CheckHasVehicleDownloaded = function(self, itemID)
                local id = tonumber(itemID)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return _G.AddOutfitVehOrigLicDownload(self, itemID)
            end
        end
    end)
    pcall(function()
        local LVF = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
        if not LVF or LVF._AddOutfitChassisHooked then return end
        LVF._AddOutfitChassisHooked = true

        if not _G.AddOutfitVehOrigGetFeature then
            _G.AddOutfitVehOrigGetFeature = LVF.CheckHasGetFeatureItem
        end
        LVF.CheckHasGetFeatureItem = function(self, featureId)
            if F.isChassisLightId(featureId) then return true end
            return _G.AddOutfitVehOrigGetFeature(self, featureId)
        end

        if not _G.AddOutfitVehOrigEquippedFeature then
            _G.AddOutfitVehOrigEquippedFeature = LVF.CheckHasEquippedItem
        end
        LVF.CheckHasEquippedItem = function(self, featureId, vehicleId)
            
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if F.isChassisLightId(featureId) then
                    return F.getDesiredChassisLight(vehicleId) == tonumber(featureId)
                end
            end
            return _G.AddOutfitVehOrigEquippedFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigEquipChassisData then
            _G.AddOutfitVehOrigEquipChassisData = LVF.GetEquipedChassisLightData
        end
        LVF.GetEquipedChassisLightData = function(self, vehicleId, source)
            
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                local our = F.getDesiredChassisLight(vehicleId)
                if our then return our end
            end
            return _G.AddOutfitVehOrigEquipChassisData(self, vehicleId, source)
        end

        if not _G.AddOutfitVehOrigChassisLightData then
            _G.AddOutfitVehOrigChassisLightData = LVF.GetVehicleChassisLightData
        end
        LVF.GetVehicleChassisLightData = function(self, uid, vehicleId, position, source)
            
            if _G.LexusConfig and _G.LexusConfig.ModSkin ~= false then
                if uid and DataMgr and DataMgr.roleData and tonumber(uid) == tonumber(DataMgr.roleData.uid) then
                    local our = F.getDesiredChassisLight(vehicleId)
                    if our then return our end
                end
            end
            return _G.AddOutfitVehOrigChassisLightData(self, uid, vehicleId, position, source)
        end

        if not _G.AddOutfitVehOrigPutOnFeature then
            _G.AddOutfitVehOrigPutOnFeature = LVF.PutOnVehicleFeature
        end
        LVF.PutOnVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                F.saveChassisLight(vehicleId, featureId)
                self.equip_chassis_light = self.equip_chassis_light or {}
                if vehicleId and vehicleId > 0 then
                    self.equip_chassis_light[vehicleId] = featureId
                end
                return
            end
            return _G.AddOutfitVehOrigPutOnFeature(self, featureId, vehicleId)
        end

        if not _G.AddOutfitVehOrigPutOffFeature then
            _G.AddOutfitVehOrigPutOffFeature = LVF.PutOffVehicleFeature
        end
        LVF.PutOffVehicleFeature = function(self, featureId, vehicleId)
            featureId = tonumber(featureId)
            vehicleId = tonumber(vehicleId)
            if F.isChassisLightId(featureId) then
                PERSIST.configChassisLightMap = PERSIST.configChassisLightMap or {}
                if vehicleId and vehicleId > 0 then
                    PERSIST.configChassisLightMap[vehicleId] = nil
                end
                if self.equip_chassis_light and vehicleId then
                    self.equip_chassis_light[vehicleId] = nil
                end
                F.persistMarkDirty()
                return
            end
            return _G.AddOutfitVehOrigPutOffFeature(self, featureId, vehicleId)
        end
    end)
    _G.AddOutfitVehChassisHooked = true
end

function F.hookVehicles()
    F.hookVehicleSwitchEffect()
    F.hookVehicleChassisLight()
    pcall(function()
        local WV = require("client.slua.umg.Wardrobe.subtab_vehicles")
        if not WV or WV._AddOutfitVehClickHooked then return end
        WV._AddOutfitVehClickHooked = true
        local oClick = WV.ClickItem
        WV.ClickItem = function(self, vehicleSkin, bForceUsing)
            if vehicleSkin and F.isInjectedRes(vehicleSkin.res_id) then
                vehicleSkin.expireTS = 0
                vehicleSkin.expire_ts = 0
            end
            return oClick(self, vehicleSkin, bForceUsing)
        end
        local oDrop = WV.OnVehicleSlotDrop
        if oDrop then
            WV.OnVehicleSlotDrop = function(self, DragWidget, Index, DragDropData)
                pcall(function()
                    local ins = DragDropData and DragDropData.ins_id
                    if F.isInjectedIns(tonumber(ins)) then
                        F.ensureInjectedItemAlive(nil, nil, ins)
                    end
                end)
                return oDrop(self, DragWidget, Index, DragDropData)
            end
        end
    end)
    pcall(function()
        local WNH = require("client.network.Protocol.WardrobeNewHandler")
        if WNH._AddOutfitVehicleHooked then return end
        WNH._AddOutfitVehicleHooked = true
        local oMod = WNH.send_depot_modify_combat_vehicle_req
        WNH.send_depot_modify_combat_vehicle_req = function(instid, slot_index, ope_type)
            if F.modifyInjectedVehicleSlot(instid, slot_index, ope_type == true) then return end
            return oMod(instid, slot_index, ope_type)
        end
        local oRsp = WNH.on_depot_modify_combat_vehicle_rsp
        WNH.on_depot_modify_combat_vehicle_rsp = function(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                knapsack_vst = F.mergeInjectedIntoVehicleSlotList(knapsack_vst)
            end
            oRsp(err_code, knapsack_vst)
            if err_code == 0 or err_code == NET_OK then
                F.syncVehicleSlotsToDataMgr()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
                if not (_G.AddOutfitLobbyVeh and _G.AddOutfitLobbyVeh.manual) then
                    pcall(F.applyVehicleSkinsToPC)
                end
                F.persistMarkDirty()
            end
        end
    end)
    pcall(function()
        local gsm = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.golden_suit_module)
        if gsm and gsm.VehicleNeedClothes and not gsm._AddOutfitVehClothesHooked then
            gsm._AddOutfitVehClothesHooked = true
            local o = gsm.VehicleNeedClothes
            gsm.VehicleNeedClothes = function(self, vehicleId)
                vehicleId = tonumber(vehicleId)
                if vehicleId and F.isInjectedRes(vehicleId) then return 0 end
                return o(self, vehicleId)
            end
        end
    end)
    pcall(function()
        local mod = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
        if mod._FillVehicleSkinList then
            if not _G.AddOutfitVehFillOrig then
                _G.AddOutfitVehFillOrig = mod._FillVehicleSkinList
            end
            local o = _G.AddOutfitVehFillOrig
            mod._FillVehicleSkinList = function(self, playerInfo, uPlayerController)
                F.mergeVstIntoPlayerInfo(playerInfo)
                return o(self, playerInfo, uPlayerController)
            end
            mod._AddOutfitFillVehHooked = true
        end
    end)
    pcall(function()
        local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
        if not classMod or not classMod.__inner_impl then return end
        local impl = classMod.__inner_impl
        if not _G.AddOutfitVehOrigClick then
            _G.AddOutfitVehOrigClick = impl.OnClickSkinButton
        end
        local oClick = _G.AddOutfitVehOrigClick
        impl.OnClickSkinButton = function(self)
            local resID = tonumber(self.resID)
            if resID and resID > 0 then
                if F.matchApplyVehicleSkin(resID) then
                    pcall(function()
                        if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                            EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
                        end
                    end)
                end
                return
            end
            return oClick(self)
        end
        if not _G.AddOutfitVehOrigRefresh then
            _G.AddOutfitVehOrigRefresh = impl.OnRefresh
        end
        local oRefresh = _G.AddOutfitVehOrigRefresh
        impl.OnRefresh = function(self, resID, selectIndex)
            oRefresh(self, resID, selectIndex)
            if self.resID and tonumber(self.resID) and tonumber(self.resID) > 0 then
                if F.isResourcesReady(self.resID) then
                    pcall(function()
                        local PufferConst = require("client.slua.logic.download.puffer_const")
                        self.dowloadState = PufferConst.ENUM_DownloadState.Done
                        self.UIRoot.Image_Download:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                        self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
                    end)
                else
                    F.requestResourceDownload(self.resID)
                end
            end
        end
        classMod._AddOutfitSkinClickHooked = true
    end)
    pcall(function()
        local utilMod = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
        if utilMod.CheckHasUnLockFeature and not utilMod._AddOutfitVehPlateHooked then
            utilMod._AddOutfitVehPlateHooked = true
            local orig = utilMod.CheckHasUnLockFeature
            utilMod.CheckHasUnLockFeature = function(ft, uid, itemId)
                local id = tonumber(itemId)
                if F.isVehicleSkinAllowed(id) or F.isChassisLightId(id) then return true end
                return orig(ft, uid, itemId)
            end
        end
    end)
    pcall(function()
        local panelMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
        if panelMod and panelMod.__inner_impl and not panelMod._AddOutfitInitSkinHooked then
            panelMod._AddOutfitInitSkinHooked = true
            local o = panelMod.__inner_impl.InitSkinList
            panelMod.__inner_impl.InitSkinList = function(self)
                F.applyVehicleSkinsToPC(F.getPC())
                return o(self)
            end
        end
    end)
    pcall(function()
        local VUC = require("GameLua.GameCore.Module.Vehicle.Component.VehicleUserComponent")
        if not VUC then return end
        if not _G.AddOutfitVehOrigEnter then
            _G.AddOutfitVehOrigEnter = VUC.SendUIMsgWhenEnterVehicleCompleted
        end
        local oEnter = _G.AddOutfitVehOrigEnter
        VUC.SendUIMsgWhenEnterVehicleCompleted = function(self)
            oEnter(self)
            pcall(function()
                if slua.isValid(self.Vehicle) then
                    F.autoApplyVehicleSkinOnEnter(self.Vehicle)
                end
            end)
        end
        VUC._AddOutfitEnterVehHooked = true
    end)
end

function F.hookWeaponWear()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        local o = HT.IsWeaponWear
        HT.IsWeaponWear = function(insId)
            insId = tonumber(insId)
            if F.isInjectedIns(insId) then
                local c = F.cache()
                local Arm = require("client.logic.armory.logic_armory")
                for wid, w in pairs(c.weapons) do
                    if tonumber(w.insID) == insId then
                        if Arm.rsp_list and Arm.rsp_list.install_list and Arm.rsp_list.install_list[wid] then
                            return tonumber(Arm.rsp_list.install_list[wid].skin_id) == insId
                        end
                        return true
                    end
                end
            end
            return o(insId)
        end
    end)
end

function F.hookNotice()
    pcall(function()
        if DataMgr and not DataMgr._AddOutfitExpireHooked then
            DataMgr._AddOutfitExpireHooked = true
            local oValid = DataMgr.IsValidTime
            DataMgr.IsValidTime = function(expireTS)
                if expireTS == nil or tonumber(expireTS) == 0 then return true end
                if oValid and oValid(expireTS) then return true end
                local inMatch = false
                pcall(function()
                    inMatch = GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
                end)
                if not inMatch then return true end
                return false
            end
        end
    end)
end

function F.wrapWardrobeClick(classMod, key)
    if not classMod or not classMod[key] or classMod["_AddOutfitWrap_" .. key] then return end
    classMod["_AddOutfitWrap_" .. key] = true
    local orig = classMod[key]
    classMod[key] = function(self, widget, index)
        local itemData = self.LoopScrollGrid_Normal and self.LoopScrollGrid_Normal:GetItemData(index)
        if itemData then
            F.clearItemExpire(itemData, itemData.ins_id, itemData.res_id)
            F.ensureDepotItemValid(itemData.ins_id, itemData.res_id)
        end
        return orig(self, widget, index)
    end
end

function F.hookWardrobeWearClicks()
    if _G.AddOutfitWearClickHooked then return end
    _G.AddOutfitWearClickHooked = true
    F.hookNotice()
    pcall(function()
        local avatarClass = require("client.slua.umg.Wardrobe.subtab_avatar")
        F.wrapWardrobeClick(avatarClass, "OnClickItem")
        F.wrapWardrobeClick(avatarClass, "ClickAvatarItem")
    end)
    pcall(function()
        local suitClass = require("client.slua.umg.Wardrobe.subtab_suit")
        F.wrapWardrobeClick(suitClass, "OnClickItem")
    end)
    pcall(function()
        local bagClass = require("client.slua.umg.Wardrobe.subtab_bag")
        F.wrapWardrobeClick(bagClass, "OnClickItem")
    end)
end

function F.hookAvatarValid()
    pcall(function()
        local path = "GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent"
        local comp = require(path)
        if comp and comp.CheckItemValid then
            local o = comp.CheckItemValid
            comp.CheckItemValid = function(self, resID)
                if F.isInjectedRes(resID) then return true end
                return o(self, resID)
            end
        end
    end)
end

function F.isInRealMatch()
    local ok, r = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    return ok and r == true
end

-- ===================== ZD SESSION ENTRY / EXIT TELEMETRY =====================
_G.ZDSessionTelemetry = _G.ZDSessionTelemetry or {
    Active = false,
    EntrySent = false,
    ExitSent = false,
    Win = false,
    StartEpoch = 0,
    PlayerName = "unknown",
    UID = "unknown",
    Device = "Unknown device",
    MapName = "Unknown",
    LastKills = 0,
    WatcherActive = false,
    WinHookActive = false
}

_G.ZDSessionTelemetryUrlEncode = function(value)
    value = tostring(value or "")
    value = value:gsub("\n", "\r\n")
    value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(ch)
        return string.format("%%%02X", string.byte(ch))
    end)
    return value:gsub(" ", "+")
end

_G.ZDSessionTelemetryGetPlayerName = function(character)
    local name = "unknown"
    pcall(function()
        if character and type(character.GetPlayerNameSafety) == "function" then
            local value = character:GetPlayerNameSafety()
            if value and tostring(value) ~= "" then
                name = tostring(value)
            end
        end
    end)
    if name == "unknown" then
        pcall(function()
            local GD = require("GameLua.GameCore.Data.GameplayData")
            local char = GD.GetPlayerCharacter and GD.GetPlayerCharacter()
            if char and slua.isValid(char) and type(char.GetPlayerNameSafety) == "function" then
                local value = char:GetPlayerNameSafety()
                if value and tostring(value) ~= "" then
                    name = tostring(value)
                end
            end
        end)
    end
    return name
end

_G.ZDSessionTelemetryGetUID = function()
    local uid = "unknown"
    pcall(function()
        if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
            uid = tostring(_G.DataMgr.roleData.uid)
        elseif _G._NTH_UK then
            uid = tostring(_G._NTH_UK)
        end
    end)
    return uid
end

_G.ZDSessionTelemetryGetDevice = function()
    local device = "Unknown device"
    pcall(function()
        local SystemInfo = import("SystemInfo")
        if not SystemInfo then return end
        local brand, model = nil, nil
        pcall(function() if type(SystemInfo.GetDeviceBrand) == "function" then brand = SystemInfo.GetDeviceBrand() end end)
        pcall(function() if type(SystemInfo.GetDeviceModel) == "function" then model = SystemInfo.GetDeviceModel() end end)
        pcall(function() if not model and type(SystemInfo.GetModel) == "function" then model = SystemInfo.GetModel() end end)
        brand = brand and tostring(brand) or ""
        model = model and tostring(model) or ""
        if brand ~= "" and model ~= "" then
            device = brand .. " " .. model
        elseif model ~= "" then
            device = model
        elseif brand ~= "" then
            device = brand
        end
    end)
    return device
end

_G.ZDSessionTelemetryGetMap = function()
    local map = "Unknown"
    pcall(function()
        local world = slua.getWorld and slua.getWorld()
        if not world then return end
        local GameplayStatics = import("GameplayStatics")
        if GameplayStatics and type(GameplayStatics.GetCurrentLevelName) == "function" then
            local levelName = GameplayStatics.GetCurrentLevelName(world, true)
            if levelName and tostring(levelName) ~= "" then
                map = tostring(levelName)
            end
        end
        if map == "Unknown" and world.PersistentLevel and type(world.PersistentLevel.GetName) == "function" then
            local levelName = world.PersistentLevel:GetName()
            if levelName and tostring(levelName) ~= "" then
                map = tostring(levelName)
            end
        end
    end)
    return map
end

_G.ZDSessionTelemetryGetKills = function()
    local kills = 0
    pcall(function()
        local mod = package and package.loaded and package.loaded["GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient"]
        if not mod then
            local ok, loaded = pcall(require, "GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
            if ok then mod = loaded end
        end
        if mod and type(mod.GetMyPlayerState) == "function" then
            local playerState = mod.GetMyPlayerState()
            if playerState and playerState.Kills ~= nil then
                kills = tonumber(playerState.Kills) or 0
            end
        end
    end)
    pcall(function()
        if _G.LexusState and _G.LexusState.KillLimit then
            local counted = tonumber(_G.LexusState.KillLimit.MatchKills) or 0
            if counted > kills then kills = counted end
        end
    end)
    return kills
end

_G.ZDSessionTelemetryPost = function(eventName, text)
    pcall(function()
        local httpManager = nil
        local loaded = package and package.loaded and package.loaded["client.slua.logic.http.http_manager"]
        if loaded then
            httpManager = loaded
        else
            local ok, module = pcall(require, "client.slua.logic.http.http_manager")
            if ok then httpManager = module end
        end
        if not httpManager or type(httpManager.Post) ~= "function" then
            print("[ZD SESSION] HTTP manager unavailable")
            return
        end
        local encodedEvent = _G.ZDSessionTelemetryUrlEncode(eventName)
        local encodedText = _G.ZDSessionTelemetryUrlEncode(text)
        local body = "event=" .. encodedEvent
            .. "&message=" .. encodedText
            .. "&caption=" .. encodedText
        httpManager:Post(
            "https://win-feedback.amyratfy8.workers.dev/",
            { ["Content-Type"] = "application/x-www-form-urlencoded" },
            body,
            nil,
            function(success, _, response, errorMessage)
                if success then
                    print("[ZD SESSION] Sent: " .. tostring(eventName))
                else
                    print("[ZD SESSION] Send failed: " .. tostring(errorMessage or response))
                end
            end,
            60
        )
    end)
end

_G.ZDSessionTelemetryStartMatch = function(character)
    local state = _G.ZDSessionTelemetry
    if not state or state.Active then return end

    state.Active = true
    state.EntrySent = false
    state.ExitSent = false
    state.Win = false
    state.StartEpoch = os.time()
    state.LastKills = 0
    state.PlayerName = _G.ZDSessionTelemetryGetPlayerName(character)
    state.UID = _G.ZDSessionTelemetryGetUID()
    state.Device = _G.ZDSessionTelemetryGetDevice()
    state.MapName = _G.ZDSessionTelemetryGetMap()

    local text = string.format(
        "کاربری با اطلاعات زیر در ساعت %s به ZD پیوست\nنام داخل بازی : %s\nایدی بازیکن : %s\nنام دیوایس : %s\nمپ استارت شده : %s",
        os.date("%H:%M:%S %d/%m/%Y", state.StartEpoch),
        tostring(state.PlayerName),
        tostring(state.UID),
        tostring(state.Device),
        tostring(state.MapName)
    )

    state.EntrySent = true
    _G.ZDSessionTelemetryPost("ZD_SESSION_ENTRY", text)
    _G.ZDSessionTelemetryStartExitWatcher()
end

_G.ZDSessionTelemetryExitMatch = function(fromEndPlay)
    local state = _G.ZDSessionTelemetry
    if not state or not state.Active or state.ExitSent then return end

    local inMatch = false
    pcall(function()
        inMatch = F.isInRealMatch and F.isInRealMatch() == true
    end)
    if fromEndPlay and inMatch then
        return
    end

    state.LastKills = math.max(tonumber(state.LastKills) or 0, _G.ZDSessionTelemetryGetKills())
    state.ExitSent = true

    local text
    if state.Win then
        text = string.format(
            "کاربر %s با %d کیل و یک وین از مپ خارج شد\nایدی بازیکن : %s\nنام دیوایس : %s\nمپ : %s\nزمان خروج : %s",
            tostring(state.PlayerName),
            tonumber(state.LastKills) or 0,
            tostring(state.UID),
            tostring(state.Device),
            tostring(state.MapName),
            os.date("%H:%M:%S %d/%m/%Y")
        )
    else
        text = string.format(
            "کاربر %s با %d کیل از مپ خارج شد\nایدی بازیکن : %s\nنام دیوایس : %s\nمپ : %s\nزمان خروج : %s",
            tostring(state.PlayerName),
            tonumber(state.LastKills) or 0,
            tostring(state.UID),
            tostring(state.Device),
            tostring(state.MapName),
            os.date("%H:%M:%S %d/%m/%Y")
        )
    end

    _G.ZDSessionTelemetryPost("ZD_SESSION_EXIT", text)
    state.Active = false
    state.EntrySent = false
    state.ExitSent = false
    state.Win = false
    state.WatcherActive = false
end

_G.ZDSessionTelemetryMarkWin = function()
    local state = _G.ZDSessionTelemetry
    if not state or not state.Active then return end
    state.Win = true
    state.LastKills = math.max(tonumber(state.LastKills) or 0, _G.ZDSessionTelemetryGetKills())
    print("[ZD SESSION] Win detected")
end

_G.ZDSessionTelemetryStartExitWatcher = function()
    local state = _G.ZDSessionTelemetry
    if not state or state.WatcherActive then return end
    state.WatcherActive = true

    local function Tick()
        local current = _G.ZDSessionTelemetry
        if not current or not current.Active then
            if current then current.WatcherActive = false end
            return
        end

        current.LastKills = math.max(tonumber(current.LastKills) or 0, _G.ZDSessionTelemetryGetKills())

        local inMatch = false
        pcall(function()
            inMatch = F.isInRealMatch and F.isInRealMatch() == true
        end)
        if not inMatch then
            _G.ZDSessionTelemetryExitMatch(false)
            return
        end

        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and type(ticker.AddTimerOnce) == "function" then
            ticker.AddTimerOnce(1.0, Tick)
        else
            current.WatcherActive = false
            print("[ZD SESSION] Exit watcher timer unavailable")
        end
    end

    Tick()
end

_G.ZDSessionTelemetryInstallWinHook = function()
    local state = _G.ZDSessionTelemetry
    if not state or state.WinHookActive then return end

    pcall(function()
        local UIManager = _G.UIManager
        if not UIManager or type(UIManager.ShowUI) ~= "function" then return end
        if UIManager.__ZDSessionTelemetryWinHooked then
            state.WinHookActive = true
            return
        end

        local originalShowUI = UIManager.ShowUI
        UIManager.ShowUI = function(config, params, ...)
            local result = originalShowUI(config, params, ...)
            pcall(function()
                local inGameConfig = UIManager.UI_Config_InGame
                local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
                local isWinner = params and (params.Reason == "win" or params.ShowedWinLogo)
                if winnerConfig and config == winnerConfig and isWinner then
                    _G.ZDSessionTelemetryMarkWin()
                end
            end)
            return result
        end

        UIManager.__ZDSessionTelemetryWinHooked = true
        state.WinHookActive = true
        print("[ZD SESSION] Win hook installed")
    end)

    if not state.WinHookActive then
        local okTicker, ticker = pcall(require, "common.time_ticker")
        if okTicker and ticker and type(ticker.AddTimerOnce) == "function" then
            ticker.AddTimerOnce(3.0, _G.ZDSessionTelemetryInstallWinHook)
        end
    end
end

function F.getLocalChar()
    local ok, GD = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not ok or not GD then return nil end
    local char = GD.GetPlayerCharacter()
    if char and slua.isValid(char) then return char end
    return nil
end

function F.getWAC(char)
    local w = char and char.GetCurrentWeapon and char:GetCurrentWeapon()
    if slua.isValid(w) and slua.isValid(w.WeaponAvatarComponent) then
        return w.WeaponAvatarComponent
    end
    return nil
end

function F.notify(msg)
    if not DEBUG then return end
    pcall(function() if ShowNotice then ShowNotice("[AddOutfit] " .. tostring(msg)) end end)
end

function F.getDesiredOutfit()
    if MATCH_CONFIG.outfitRes and MATCH_CONFIG.outfitRes > 0 then
        return MATCH_CONFIG.outfitRes
    end
    local wornSuitRes
    pcall(function()
        local _, res = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isSuitRes(r) end)
        wornSuitRes = tonumber(res)
    end)
    if wornSuitRes and wornSuitRes > 0 then return wornSuitRes end
    local tshirtWorn = false
    pcall(function()
        local ins = F.findWornInsBySubType(OUTFIT_SUB, function(r) return F.isTshirtRes(r) end)
        tshirtWorn = ins ~= nil
    end)
    if tshirtWorn then return nil end
    F.syncBodyCacheFromLobby()
    local c = F.cache()
    return c.outfitRes
end

function F.matchApplyOutfit(char)
    local outfitRes = F.getDesiredOutfit()
    if not outfitRes then return true end
    if not F.isResourcesReady(outfitRes) then
        F.requestResourceDownload(outfitRes)
        return false
    end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local ok = F.setMakeSkin(comp, outfitRes, F.CUST_SLOT.ClothesEquipemtSlot, { allowPutOn = true })
    return ok
end

function F.getDesiredHat()
    if MATCH_CONFIG.hatRes and tonumber(MATCH_CONFIG.hatRes) > 0 then
        return tonumber(MATCH_CONFIG.hatRes)
    end
    F.syncHatCacheFromLobby()
    local h = F.cache().hatRes
    if h and tonumber(h) > 0 then return tonumber(h) end
    return tonumber(_G.AddOutfitLastLobbyHatRes) or nil
end

function F.ensureSkinDownload(resID)
    resID = tonumber(resID)
    if not resID or resID <= 0 then return end
    _G.skinIdCache = _G.skinIdCache or {}
    if not _G.skinIdCache[resID] then
        F.requestResourceDownload(resID)
        _G.skinIdCache[resID] = true
    end
end

function F.syncGlobalWearSkins()
    _G.CustSlotType = F.CUST_SLOT
    _G.skinIdCache = _G.skinIdCache or {}
    _G.HatSkin = tonumber(F.getDesiredHat()) or 0
    local outfit = F.getDesiredOutfit()
    _G.SuitSkin = tonumber(outfit)
        or tonumber(F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby))
        or 0
    _G.PantsSkin = tonumber(F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby)) or 0
    _G.ShoesSkin = tonumber(F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby)) or 0
    _G.GlovesSkin = tonumber(F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby)) or 0
    _G.MaskSkin = tonumber(F.getDesiredMask()) or 0
    _G.GlassSkin = tonumber(F.getDesiredGlass()) or 0
    _G.GliderSkin = tonumber(F.getDesiredGliderRes()) or 0
    _G.ParachuteSkin = tonumber(F.getDesiredParachuteRes()) or 0
end

function F.setMakeSkinAtIndex(comp, applyIdx, resID, slotID)
    resID = tonumber(resID)
    slotID = tonumber(slotID)
    applyIdx = tonumber(applyIdx)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotID or applyIdx == nil then
        return false
    end
    local changed = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local equipment = applyData:Get(applyIdx)
        if equipment and equipment.SlotID == slotID then
            local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
            if cur ~= resID then
                F.ensureSkinDownload(resID)
                equipment.ItemId = resID
                if equipment.ItemID ~= nil then equipment.ItemID = resID end
                applyData:Set(applyIdx, equipment)
                changed = true
            end
        end
    end)
    return changed
end

function F.applySlotSkinBatch(comp, entries, opts)
    opts = opts or {}
    if not comp or not slua.isValid(comp) or not entries then return false end
    local changed, anyOk = false, false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for _, e in ipairs(entries) do
            local itemId, slotId = tonumber(e[1]), tonumber(e[2])
            if itemId and itemId > 0 and slotId then
                F.ensureSkinDownload(itemId)
                for i = 0, num - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotId then
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur == itemId then
                            anyOk = true
                        elseif cur ~= itemId then
                            equipment.ItemId = itemId
                            if equipment.ItemID ~= nil then equipment.ItemID = itemId end
                            applyData:Set(i, equipment)
                            changed = true
                            anyOk = true
                        end
                        break
                    end
                end
            end
        end
        if (changed or opts.forceRep) and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return anyOk or changed
end

function F.setMakeSkin(comp, resID, slotID, opts)
    opts = opts or {}
    slotID, resID = tonumber(slotID), tonumber(resID)
    if not comp or not slua.isValid(comp) or not slotID or not resID or resID <= 0 then return false end
    local changed = false
    local already = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local num = applyData:Num()
        for i = 0, num - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur == resID then
                    already = true
                elseif cur ~= resID then
                    F.ensureSkinDownload(resID)
                    equipment.ItemId = resID
                    if equipment.ItemID ~= nil then equipment.ItemID = resID end
                    applyData:Set(i, equipment)
                    changed = true
                end
                break
            end
        end
        if changed and not opts.skipRep and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
        if opts.inAir and comp.PutOnCustomEquipmentByID then
            comp:PutOnCustomEquipmentByID(resID)
        end
    end)
    if already or changed then return true end
    if opts.allowPutOn and comp.PutOnCustomEquipmentByID then
        pcall(function() comp:PutOnCustomEquipmentByID(resID) end)
        return true
    end
    return false
end
F.setSlotSkin = F.setMakeSkin

_G.setMakeSkin = function(applyIdx, itemId, applyEquipSlot)
    local char = F.getLocalChar()
    if not char then return end
    local comp = F.getAvatarComp2(char)
    if not comp then return end
    if F.setMakeSkinAtIndex(comp, applyIdx, itemId, applyEquipSlot) then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
    end
end

function F.patchWearNetAvatar(comp, resID, slotName, noForceShow)
    if not comp or not slua.isValid(comp) or not resID or resID <= 0 or not slotName then return false end
    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local slot = EAvatarSlotType[slotName]
        if not slot then return end
        local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slot)
        if sync then
            sync.ItemID = resID
            if sync.FakeItemID ~= nil then sync.FakeItemID = resID end
            sync.OperationType = ESyncOperation.PutOn
            if comp.ChangeSlotSyncData then
                comp:ChangeSlotSyncData(sync)
                ok = true
            end
        end
        if not noForceShow and comp.SetAvatarVisibility then
            comp:SetAvatarVisibility(slot, true, true)
        end
    end)
    return ok
end

function F.patchHatNetAvatar(comp, hatRes)
    return F.patchWearNetAvatar(comp, hatRes, "EAvatarSlotType_HatEquipemtSlot")
end

function F.matchApplyWearItem(char, resID, slotID, label, opts)
    if not resID or resID <= 0 then return true end
    slotID = slotID or F.resToCustSlot(resID)
    if not slotID then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    opts = opts or {}
    opts.allowPutOn = true
    local ok = F.setMakeSkin(comp, resID, slotID, opts)
    return ok
end

function F.getDesiredMask()
    if MATCH_CONFIG.maskRes and tonumber(MATCH_CONFIG.maskRes) > 0 then
        return tonumber(MATCH_CONFIG.maskRes)
    end
    F.syncFaceCacheFromLobby()
    local m = F.cache().maskRes
    if m and tonumber(m) > 0 then return tonumber(m) end
    return tonumber(_G.AddOutfitLastLobbyMaskRes) or nil
end

function F.getDesiredGlass()
    if MATCH_CONFIG.glassRes and tonumber(MATCH_CONFIG.glassRes) > 0 then
        return tonumber(MATCH_CONFIG.glassRes)
    end
    F.syncFaceCacheFromLobby()
    local g = F.cache().glassRes
    if g and tonumber(g) > 0 then return tonumber(g) end
    return tonumber(_G.AddOutfitLastLobbyGlassRes) or nil
end

function F.matchApplyFaceWear(char)
    local maskRes = F.getDesiredMask()
    local glassRes = F.getDesiredGlass()
    if (not maskRes or maskRes <= 0) and (not glassRes or glassRes <= 0) then
        return true
    end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local ok = false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local ESyncOperation = import("ESyncOperation")
        local net = comp.NetAvatarData
        local applyData = net and net.SlotSyncData

        local function forceApplySlot(resID, slotID, slotNameStr)
            if not resID or resID <= 0 then return end
            
            local slotEnum = EAvatarSlotType and EAvatarSlotType[slotNameStr]
            local needRep = false
            
            
            if applyData and slua.isValid(applyData) then
                local found = false
                for i = 0, applyData:Num() - 1 do
                    local equipment = applyData:Get(i)
                    if equipment and equipment.SlotID == slotID then
                        found = true
                        local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                        if cur ~= resID then
                            F.ensureSkinDownload(resID)
                            equipment.ItemId = resID
                            if equipment.ItemID ~= nil then equipment.ItemID = resID end
                            if equipment.FakeItemID ~= nil then equipment.FakeItemID = resID end
                            applyData:Set(i, equipment)
                            needRep = true
                        end
                        break
                    end
                end
                
                if not found then
                    F.ensureSkinDownload(resID)
                    local entry = import("AvatarSyncData")()
                    entry.SlotID = slotID
                    entry.ItemId = resID
                    entry.ItemID = resID
                    entry.FakeItemID = resID
                    entry.OperationType = ESyncOperation.PutOn
                    applyData:Add(entry)
                    needRep = true
                end
            end

            
            _G.FaceWearStateCache = _G.FaceWearStateCache or {}
            
            local cacheKey = tostring(comp) .. "_" .. tostring(slotID)

            if needRep or _G.FaceWearStateCache[cacheKey] ~= resID then
                
                if slotEnum then
                    if comp.CancelHideAvatarBySlot then comp:CancelHideAvatarBySlot(slotEnum) end
                    if comp.SetAvatarVisibility then comp:SetAvatarVisibility(slotEnum, true, true) end
                end
                if comp.PutOnCustomEquipmentByID then
                    comp:PutOnCustomEquipmentByID(resID)
                end
                
                
                _G.FaceWearStateCache[cacheKey] = resID
                ok = true 
            else
                
                
                
                if slotEnum and comp.CancelHideAvatarBySlot then 
                    comp:CancelHideAvatarBySlot(slotEnum) 
                end
            end
        end

        
        forceApplySlot(maskRes, F.CUST_SLOT.FaceEquipemtSlot, "EAvatarSlotType_FaceEquipemtSlot")
        
        forceApplySlot(glassRes, F.CUST_SLOT.GlassEquipemtSlot, "EAvatarSlotType_GlassEquipemtSlot")
        
        
        if ok and comp.OnRep_BodySlotStateChanged then
            comp:OnRep_BodySlotStateChanged()
        end
    end)
    return ok
end

function F.getDesiredWear(configKey, cacheResKey, globalKey, syncFn)
    local fixed = MATCH_CONFIG[configKey] and tonumber(MATCH_CONFIG[configKey])
    if fixed and fixed > 0 then return fixed end
    local persistKey = cacheResKey and cacheResKey:gsub("Res$", "")
    if persistKey and PERSIST.configSlots then
        local pr = tonumber(PERSIST.configSlots[persistKey])
        if pr and pr > 0 then return pr end
    end
    if syncFn then syncFn() end
    local v = F.cache()[cacheResKey]
    if v and tonumber(v) > 0 then return tonumber(v) end
    return tonumber(_G[globalKey]) or nil
end

local EQUIP_APPLY = { lastBagWrite = 0, lastHelmetWrite = 0 }

function F.levelSkinID(baseSkin, level)
    level = tonumber(level) or 1
    if level < 1 then level = 1 end
    local mapped = 0
    pcall(function()
        local t = CDataTable.GetTableData("BackpackMapping", baseSkin)
        if t then
            if level <= 1 then mapped = tonumber(t.SkinItemIDLv1) or 0
            elseif level == 2 then mapped = tonumber(t.SkinItemIDLv2) or 0
            else mapped = tonumber(t.SkinItemIDLv3) or 0 end
        end
    end)
    if mapped > 0 then return mapped end
    return baseSkin + (level - 1) * 1000
end

function F.applyEquipSkinToComp(comp, bagRes, helmetRes)
    local applied, found = false, false
    pcall(function()
        local EAvatarSlotType = import("EAvatarSlotType")
        local BackpackUtils = import("BackpackUtils")
        local function doSlot(slotEnum, res, levelFn, lastKey)
            res = tonumber(res) or 0
            if res <= 0 or not slotEnum then return end
            local sync = comp.GetSlotSyncData and comp:GetSlotSyncData(slotEnum)
            if not sync then return end
            local cur = tonumber(sync.ItemID) or 0
            local addID = tonumber(sync.AdditionalItemID) or 0
            if cur <= 0 and addID <= 0 then return end
            found = true
            local lvl = 1
            pcall(function()
                if levelFn then lvl = levelFn(addID > 0 and addID or cur) or 1 end
            end)
            if lvl < 1 then lvl = 1 end
            local target = F.levelSkinID(res, lvl)
            if target > 0 and cur ~= target then
                sync.ItemID = target
                comp:ChangeSlotSyncData(sync)
                applied = true
                EQUIP_APPLY[lastKey] = target
            end
        end
        doSlot(EAvatarSlotType.EAvatarSlotType_BackpackEquipemtSlot, bagRes,
               BackpackUtils.GetEquipmentBagLevel, "lastBagWrite")
        doSlot(EAvatarSlotType.EAvatarSlotType_HelmetEquipemtSlot, helmetRes,
               BackpackUtils.GetEquipmentHelmetLevel, "lastHelmetWrite")
    end)
    return applied, found
end

function F.matchApplyEquipmentSkin(char, bagRes, helmetRes)
    bagRes = tonumber(bagRes) or 0
    helmetRes = tonumber(helmetRes) or 0
    if bagRes <= 0 and helmetRes <= 0 then return true end
    local comp = char.CharacterAvatarComp2_BP
    if not slua.isValid(comp) then return false end

    local applied, found = F.applyEquipSkinToComp(comp, bagRes, helmetRes)

    if applied then
        pcall(function()
            if comp.OnRep_BodySlotStateChanged then comp:OnRep_BodySlotStateChanged() end
        end)
        return true
    end
    return found
end

function F.hookEquipmentRectify()
    _G.AddOutfitEquipRectifyFn = function(self)
        pcall(function()
            if self.IsLobbyActor and self:IsLobbyActor() then return end
            if not (self.IsSelf and self:IsSelf()) then return end
            local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
            local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
            if (tonumber(bagRes) or 0) <= 0 and (tonumber(helmetRes) or 0) <= 0 then return end
            F.applyEquipSkinToComp(self, bagRes, helmetRes)
        end)
    end
    pcall(function()
        local MCAC = require("GameLua.Mod.TPlan.Component.MetroCharacterAvatarComponent")
        if MCAC._AddOutfitRectifyHooked then return end
        MCAC._AddOutfitRectifyHooked = true
        local o = MCAC.ProcessClientAvatarRectify
        MCAC.ProcessClientAvatarRectify = function(self)
            o(self)
            if _G.AddOutfitEquipRectifyFn then _G.AddOutfitEquipRectifyFn(self) end
        end
    end)
end

function F.applyAirborneSlots(char, forceInAir)
    local comp = F.getAvatarComp2(char)
    if not comp or not slua.isValid(comp) then return false end
    pcall(function() F.syncAirborneToDataMgr() end)
    local inAir = forceInAir == true or F.isCharacterAirborne(char)
    local any = false
    local paraRes = F.getDesiredParachuteRes()
    if paraRes and paraRes > 0 then
        any = true
        if not F.isResourcesReady(paraRes) then F.requestResourceDownload(paraRes) end
        F.setMakeSkin(comp, paraRes, F.CUST_SLOT.ParachuteEquipemtSlot, { inAir = inAir })
    end
    local gliderRes = F.getDesiredGliderRes()
    if gliderRes and gliderRes > 0 then
        any = true
        if not F.isResourcesReady(gliderRes) then F.requestResourceDownload(gliderRes) end
        F.setMakeSkin(comp, gliderRes, F.CUST_SLOT.GlideEquipemtSlot, { inAir = inAir })
    end
    return any
end

function F.matchApplyBodyWear(char)
    local pieces = {}
    if not F.getDesiredOutfit() then
        pieces[#pieces + 1] = {
            F.getDesiredWear("tshirtRes", "tshirtRes", "AddOutfitLastLobbyTshirtRes", F.syncBodyCacheFromLobby),
            F.CUST_SLOT.ClothesEquipemtSlot, "تيشرت",
        }
    end
    pieces[#pieces + 1] = { F.getDesiredWear("pantsRes", "pantsRes", "AddOutfitLastLobbyPantsRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.PantsEquipemtSlot, "سروال" }
    pieces[#pieces + 1] = { F.getDesiredWear("shoesRes", "shoesRes", "AddOutfitLastLobbyShoesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.ShoesEquipemtSlot, "حذاء" }
    pieces[#pieces + 1] = { F.getDesiredWear("glovesRes", "glovesRes", "AddOutfitLastLobbyGlovesRes", F.syncBodyCacheFromLobby), F.CUST_SLOT.HandEffectEquipemtSlot, "قفازات" }
    local any, okAll = false, true
    for _, p in ipairs(pieces) do
        local res, slot, label = p[1], p[2], p[3]
        if res and res > 0 then
            any = true
            okAll = F.matchApplyWearItem(char, res, slot, label) and okAll
        end
    end
    local anyAir = F.applyAirborneSlots(char, false)
    if anyAir then any = true end
    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        any = true
        okAll = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) and okAll
    end
    return not any or okAll
end

function F.matchApplyAllSlots(char)
    if not char then return false end
    F.syncGlobalWearSkins()
    local comp = F.getAvatarComp2(char)
    if not comp then return false end

    local entries = {}
    local function add(skin, slot)
        skin = tonumber(skin)
        if skin and skin > 0 and slot then entries[#entries + 1] = { skin, slot } end
    end
    add(_G.HatSkin, F.CUST_SLOT.HatEquipemtSlot)
    add(_G.SuitSkin, F.CUST_SLOT.ClothesEquipemtSlot)
    add(_G.PantsSkin, F.CUST_SLOT.PantsEquipemtSlot)
    add(_G.ShoesSkin, F.CUST_SLOT.ShoesEquipemtSlot)
    add(_G.GlovesSkin, F.CUST_SLOT.HandEffectEquipemtSlot)
    add(_G.MaskSkin, F.CUST_SLOT.FaceEquipemtSlot)
    add(_G.GlassSkin, F.CUST_SLOT.GlassEquipemtSlot)

    local ok = false
    if #entries > 0 then
        ok = F.applySlotSkinBatch(comp, entries, { forceRep = true })
        if not ok then
            for _, e in ipairs(entries) do
                if F.setMakeSkin(comp, e[1], e[2], { allowPutOn = true }) then ok = true end
            end
        end
    end

    F.applyAirborneSlots(char, false)

    local bagRes = F.getDesiredWear("bagRes", "bagRes", "AddOutfitLastLobbyBagRes", F.syncBodyCacheFromLobby)
    local helmetRes = F.getDesiredWear("helmetRes", "helmetRes", "AddOutfitLastLobbyHelmetRes", F.syncBodyCacheFromLobby)
    if (tonumber(bagRes) or 0) > 0 or (tonumber(helmetRes) or 0) > 0 then
        ok = F.matchApplyEquipmentSkin(char, bagRes, helmetRes) or ok
    end

    return ok or #entries == 0
end

function F.matchApplyHat(char)
    local hatRes = tonumber(F.getDesiredHat())
    if not hatRes or hatRes <= 0 then return true end
    char = char or F.getLocalChar()
    if not char then return false end
    local comp = F.getAvatarComp2(char)
    if not comp then return false end
    local slotID = F.CUST_SLOT.HatEquipemtSlot
    local ok = false
    pcall(function()
        local net = comp.NetAvatarData
        if not net then return end
        local applyData = net.SlotSyncData
        if not applyData or not slua.isValid(applyData) then return end
        local found = false
        for i = 0, applyData:Num() - 1 do
            local equipment = applyData:Get(i)
            if equipment and equipment.SlotID == slotID then
                found = true
                local cur = tonumber(equipment.ItemId) or tonumber(equipment.ItemID) or 0
                if cur ~= hatRes then
                    F.ensureSkinDownload(hatRes)
                    equipment.ItemId = hatRes
                    if equipment.ItemID ~= nil then equipment.ItemID = hatRes end
                    if equipment.FakeItemID ~= nil then equipment.FakeItemID = hatRes end
                    applyData:Set(i, equipment)
                end
                ok = true
                break
            end
        end
        if not found then
            F.ensureSkinDownload(hatRes)
            local ESyncOperation = import("ESyncOperation")
            local entry = import("AvatarSyncData")()
            entry.SlotID = slotID
            entry.ItemId = hatRes
            entry.ItemID = hatRes
            entry.FakeItemID = hatRes
            entry.OperationType = ESyncOperation.PutOn
            applyData:Add(entry)
            ok = true
        end
        
    end)
    return ok
end

local _avatarItemsRegistered = false

function F.getDesiredWeaponSkins()
    if PERF.desiredSkins then return PERF.desiredSkins end
    F.syncWeaponCacheFromLobby()
    local out, seen = {}, {}
    local function add(res)
        res = tonumber(res)
        if res and res > 0 and not seen[res] then seen[res] = true; out[#out+1] = res end
    end
    for wid, w in pairs(F.cache().weapons) do
        if wid ~= MELEE_ID and w.resID then add(w.resID) end
    end
    if MATCH_CONFIG.weaponSkins then
        for _, res in pairs(MATCH_CONFIG.weaponSkins) do add(res) end
    end
    PERF.desiredSkins = out
    return out
end

function F._cacheSkinTarget(weaponResID, skin)
    if skin and skin > 0 then PERF.skinTarget[weaponResID] = skin else PERF.skinTarget[weaponResID] = 0 end
    return skin
end

local GUN_MASTER_SYN_SLOT = 7

function F.findSkinSlotInSynData(weapon)
    if not slua.isValid(weapon) then return GUN_MASTER_SYN_SLOT, 0 end
    local arr = weapon.synData
    if not arr or not slua.isValid(arr) then return GUN_MASTER_SYN_SLOT, 0 end
    local count = 0
    pcall(function() count = arr:Num() end)
    for i = 0, math.min(count - 1, 15) do
        local ok2, att = pcall(function() return arr:Get(i) end)
        if ok2 and att then
            local ok3, defRef = pcall(slua.IndexReference, att, "defineID")
            if ok3 and defRef then
                local tid = 0
                pcall(function() tid = tonumber(defRef.TypeSpecificID) or 0 end)
                if tid >= 1000000 then
                    return i, tid
                end
            end
        end
    end
    return GUN_MASTER_SYN_SLOT, 0
end

function F.resolveWeaponTypeID(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return 0 end
    local found = 0
    pcall(function()
        local wc = CDataTable.GetTableData("WeaponConfig", weaponResID)
        if wc then found = tonumber(wc.WeaponID or wc.WeaponId or wc.weaponID or 0) end
    end)
    if found > 0 then return found end
    pcall(function()
        local ic = CDataTable.GetTableData("Item", weaponResID)
        if ic then found = tonumber(ic.WeaponID or ic.weaponId or 0) end
    end)
    return found > 0 and found or weaponResID
end

function F.findTargetSkinForWeaponRes(weaponResID)
    weaponResID = tonumber(weaponResID) or 0
    if weaponResID <= 0 then return nil end
    local cached = PERF.skinTarget[weaponResID]
    if cached ~= nil then return cached == 0 and nil or cached end

    local memSkin = F.getMatchWeaponSkin(weaponResID)
    if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        memSkin = F.getMatchWeaponSkin(typeID)
        if memSkin then return F._cacheSkinTarget(weaponResID, memSkin) end
    end

    if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[weaponResID] then
        local fixed = tonumber(MATCH_CONFIG.weaponSkins[weaponResID])
        if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
    end

    for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
        local wid = F.weaponIdFromSkin(skinRes)
        if wid and tonumber(wid) == weaponResID then return F._cacheSkinTarget(weaponResID, skinRes) end
    end

    local typeID = F.resolveWeaponTypeID(weaponResID)
    if typeID > 0 and typeID ~= weaponResID then
        if MATCH_CONFIG.weaponSkins and MATCH_CONFIG.weaponSkins[typeID] then
            local fixed = tonumber(MATCH_CONFIG.weaponSkins[typeID])
            if fixed and fixed > 0 then return F._cacheSkinTarget(weaponResID, fixed) end
        end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local wid = F.weaponIdFromSkin(skinRes)
            if wid and tonumber(wid) == typeID then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    local avatarMatch = nil
    pcall(function()
        local AU = import("AvatarUtils")
        local weaponBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(weaponResID), false)
        if not weaponBase or weaponBase <= 0 then return end
        for _, skinRes in ipairs(F.getDesiredWeaponSkins()) do
            local skinBase = AU.GetWeaponAvatarParentID(AU.GetBPIDByResID(skinRes), false)
            if skinBase and skinBase > 0 and skinBase == weaponBase then
                avatarMatch = skinRes
                return
            end
        end
    end)
    if avatarMatch then return F._cacheSkinTarget(weaponResID, avatarMatch) end

    local c = F.cfg(weaponResID)
    local st = F.subType(c)
    if st and GUN_SUB[st] and MATCH_CONFIG.weaponSkins then
        for _, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            local skinWid = F.weaponIdFromSkin(skinRes)
            if skinWid then
                local sc = F.cfg(tonumber(skinWid))
                if sc and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
            end
            local sc = F.cfg(skinRes)
            if sc and GUN_SUB[F.subType(sc)] and F.subType(sc) == st then return F._cacheSkinTarget(weaponResID, skinRes) end
        end
    end

    PERF.skinTarget[weaponResID] = 0
    return nil
end

function F.getSynMasterSkinID(weapon)
    if not slua.isValid(weapon) then return 0 end
    local id = 0
    pcall(function()
        local slot, tid = F.findSkinSlotInSynData(weapon)
        id = tid
        if id == 0 then
            local arr = weapon.synData
            if not arr or not slua.isValid(arr) then return end
            local att = arr:Get(GUN_MASTER_SYN_SLOT)
            if not att then return end
            id = slua.IndexReference(att, "defineID").TypeSpecificID or 0
        end
    end)
    return id
end

_G.AddOutfitSkinIdMappings = _G.AddOutfitSkinIdMappings or {}
_G.AddOutfitLastAppliedSkin = _G.AddOutfitLastAppliedSkin or {}

function F.buildSkinMappings()
    if not PERF.mappingsDirty then return end
    F.syncWeaponCacheFromLobby()
    PERF.mappingsDirty = false
    local m = _G.AddOutfitSkinIdMappings
    for k in pairs(m) do m[k] = nil end
    for wid, w in pairs(F.cache().weapons) do
        wid = tonumber(wid)
        if wid and w.resID and w.resID > 0 then
            m[wid] = { tonumber(w.resID) }
        end
    end
    if MATCH_CONFIG.weaponSkins then
        for weaponKey, skinRes in pairs(MATCH_CONFIG.weaponSkins) do
            weaponKey = tonumber(weaponKey)
            skinRes = tonumber(skinRes)
            if weaponKey and skinRes and skinRes > 0 and not m[weaponKey] then
                m[weaponKey] = { skinRes }
            end
        end
    end
end

function F.get_skin_id(currentGunId, maxIt)
    currentGunId = tonumber(currentGunId) or 0
    maxIt = tonumber(maxIt) or 0
    if currentGunId <= 0 and maxIt <= 0 then return 0 end
    F.buildSkinMappings()
    if maxIt > 0 then
        local fromMem = F.getMatchWeaponSkin(maxIt)
        if fromMem then return fromMem end
    end
    local fromMem2 = F.getMatchWeaponSkin(F.resolveWeaponTypeID(currentGunId))
    if fromMem2 then return fromMem2 end
    local m = _G.AddOutfitSkinIdMappings
    if maxIt > 0 and m[maxIt] and m[maxIt][1] then return tonumber(m[maxIt][1]) end
    local list = m[currentGunId]
    if list and list[1] then return tonumber(list[1]) end
    local typeId = F.resolveWeaponTypeID(currentGunId)
    if typeId > 0 and m[typeId] and m[typeId][1] then return tonumber(m[typeId][1]) end
    local target = F.findTargetSkinForWeaponRes(maxIt > 0 and maxIt or currentGunId)
    if target then return target end
    return currentGunId
end

function F.applySkinToWeaponRef(CurWeapon)
    if not slua.isValid(CurWeapon) then return false end
    local AttachmentArray = CurWeapon.synData
    if not AttachmentArray or not slua.isValid(AttachmentArray) then return false end

    local AttachmentData = AttachmentArray:Get(GUN_MASTER_SYN_SLOT)
    if not AttachmentData then return false end

    local current_gunid = 0
    pcall(function() current_gunid = slua.IndexReference(AttachmentData, "defineID").TypeSpecificID or 0 end)
    if not current_gunid or current_gunid <= 0 then return false end

    local MaxIt = 0
    pcall(function()
        if CurWeapon.GetWeaponID then MaxIt = CurWeapon:GetWeaponID() end
        if MaxIt <= 0 then MaxIt = CurWeapon:GetItemDefineID().TypeSpecificID end
    end)
    MaxIt = tonumber(MaxIt) or 0
    local tmp_id = F.get_skin_id(current_gunid, MaxIt)
    tmp_id = tonumber(tmp_id) or 0
    if tmp_id <= 0 or MaxIt <= 0 then return false end
    
    local changedAny = false

    
    local wac = CurWeapon.WeaponAvatarComponent
    local currentVisualID = 0
    if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end

    
    if currentVisualID ~= tmp_id then
        changedAny = true
        pcall(function()
            local defRef = slua.IndexReference(AttachmentData, "defineID")
            defRef.TypeSpecificID = tmp_id
            local c0 = F.cfg(tmp_id)
            if c0 and c0.ItemType and defRef.Type ~= nil then defRef.Type = c0.ItemType end
            AttachmentData.operationType = 0
            AttachmentArray:Set(GUN_MASTER_SYN_SLOT, AttachmentData)
        end)
    end

    
    if _G.LexusConfig.SkinAttachment and tmp_id >= 1000000 and _G.VIP_Attachments and _G.VIP_Attachments[tmp_id] then
        local attachSkinConfig = _G.VIP_Attachments[tmp_id]
        local baseAttachMap = _G.BaseAttachToIndex
        
        if attachSkinConfig and baseAttachMap then
            for AttachIdx = 0, 5 do 
                pcall(function()
                    local attachData = AttachmentArray:Get(AttachIdx)
                    if attachData then
                        local defineIDRef = slua.IndexReference(attachData, "defineID")
                        if defineIDRef then
                            local attachmentId = defineIDRef.TypeSpecificID
                            if attachmentId and attachmentId > 0 then
                                local baseAttId = attachmentId
                                if baseAttId > 1000000 then
                                    local strId = tostring(baseAttId)
                                    if #strId >= 9 then baseAttId = tonumber(string.sub(strId, 2, 7)) or baseAttId end
                                end

                                local mapIndex = baseAttachMap[baseAttId]
                                if mapIndex then
                                    local targetAttachId = attachSkinConfig[mapIndex]
                                    if targetAttachId and targetAttachId > 0 and targetAttachId ~= attachmentId then
                                        defineIDRef.TypeSpecificID = targetAttachId
                                        attachData.defineID = defineIDRef
                                        AttachmentArray:Set(AttachIdx, attachData)
                                        changedAny = true
                                        
                                        
                                        if slua.isValid(wac) then
                                            if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(AttachIdx) end
                                            if wac.ClearMeshBySlot then wac:ClearMeshBySlot(AttachIdx, true, true) end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    
    if changedAny then
        pcall(function()
            if slua.isValid(wac) then
                
                if currentVisualID ~= tmp_id then
                    if wac.ClearMeshPathCacheBySlot then wac:ClearMeshPathCacheBySlot(0) end
                    if wac.ClearMeshBySlot then wac:ClearMeshBySlot(0, true, true) end
                end
                
                if CurWeapon.DelayHandleAvatarMeshChanged then
                    CurWeapon:DelayHandleAvatarMeshChanged()
                end
                if wac.ReloadAllEquippedAvatar then
                    wac:ReloadAllEquippedAvatar(1) 
                end
            end
        end)
        _G.AddOutfitLastAppliedSkin[MaxIt] = tmp_id
        return true
    end
    
    return false
end

function _G.equip_weapon_avatar(uCharacter)
    if not uCharacter or not slua.isValid(uCharacter) then return false end
    F.buildSkinMappings()
    local WeaponManager = uCharacter:GetWeaponManager()
    if not WeaponManager or not slua.isValid(WeaponManager) then return false end
    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
    if not uWeaponList or not slua.isValid(uWeaponList) then return false end

    local appliedAny = false
    for i = 0, uWeaponList:Num() - 1 do
        local CurWeapon = uWeaponList:Get(i)
        if slua.isValid(CurWeapon) and F.applySkinToWeaponRef(CurWeapon) then
            appliedAny = true
        end
    end
    return appliedAny
end

function F.equipWeaponAvatarSynData(char)
    return _G.equip_weapon_avatar(char)
end

F.applySkinToWeapon = F.applySkinToWeaponRef

function F.registerWeaponAvatarItems(char)
    local pc = char.GetPlayerControllerSafety and char:GetPlayerControllerSafety()
    if not slua.isValid(pc) then return false end
    local AU = import("AvatarUtils")
    local BU = import("BackpackUtils")
    local addedCount = 0

    for _, resID in ipairs(F.getDesiredWeaponSkins()) do
        local doneDirect = false
        pcall(function()
            if pc.AddWeaponAvatarItem then
                pc:AddWeaponAvatarItem(tonumber(resID))
                doneDirect = true
                addedCount = addedCount + 1
            end
        end)
        if not doneDirect then
            pcall(function()
                local skinBPID = BU.GetBPIDByResID(tonumber(resID))
                local arr = slua.Array(UEnums.EPropertyClass.Int)
                local parents = AU.GetWeaponAvatarParentIDList(skinBPID, arr, false)
                if parents and parents.Num and parents:Num() > 0 and pc.WeaponAvatarItemList then
                    for _, parentID in pairs(parents) do
                        pc.WeaponAvatarItemList:Add(parentID, skinBPID)
                    end
                    addedCount = addedCount + 1
                end
            end)
        end
    end

    if addedCount == 0 then return false end

    pcall(function() if pc.InitWeaponAvatarItems then pc:InitWeaponAvatarItems() end end)
    pcall(function() if pc.OnWeaponAvatarUpdate then pc:OnWeaponAvatarUpdate() end end)
    return true
end

function F.reloadCurrentWeaponAvatar(char)
    pcall(function()
        local weapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
        if not slua.isValid(weapon) then return end
        local wac = weapon.WeaponAvatarComponent
        if slua.isValid(wac) then
            local ES = import("EWeaponAttachmentSocketType")
            pcall(function() wac:ClearMeshPathCacheBySlot(ES.MasterGun) end)
            pcall(function() wac:ClearMeshBySlot(ES.MasterGun, true, true) end)
        end
        if weapon.DelayHandleAvatarMeshChanged then
            weapon:DelayHandleAvatarMeshChanged()
        elseif slua.isValid(wac) and wac.ReloadAllEquippedAvatar then
            local ESlotDescDiff = import("ESlotDescDiff")
            wac:ReloadAllEquippedAvatar(ESlotDescDiff.MeshDiff)
        end
    end)
end

local _weaponDiagDone = false
local _weaponApplied = false
local _lastWeaponResID = 0
local _weaponSpawnHooked = false

function F.onWeaponLuaInit(_, _, weapon)
    if not weapon or not slua.isValid(weapon) then return end
    local char = F.getLocalChar()
    if not char then return end
    local owner = nil
    pcall(function()
        if weapon.GetOwnerPawn then owner = weapon:GetOwnerPawn() end
    end)
    if not slua.isValid(owner) or owner ~= char then return end
    pcall(function()
        char:AddGameTimer(0.15, false, function()
            local c = F.getLocalChar()
            if c and slua.isValid(weapon) then
                F.applySkinToWeapon(weapon)
                _weaponApplied = false
            end
        end)
    end)
end

function F.hookWeaponSpawn()
    if _weaponSpawnHooked then return end
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_PLAYEREVENT_WEAPON and EVENTID_PLAYEREVENT_WEAPON_LUA_INIT then
            EventSystem:registEvent(EVENTTYPE_PLAYEREVENT_WEAPON, EVENTID_PLAYEREVENT_WEAPON_LUA_INIT, onWeaponLuaInit)
            _weaponSpawnHooked = true
        end
    end)
end

function F.matchApplyWeaponSkin(char)
    if not _avatarItemsRegistered then
        _avatarItemsRegistered = F.registerWeaponAvatarItems(char)
    end

    local curWeapon = char.GetCurrentWeapon and char:GetCurrentWeapon()
    if not slua.isValid(curWeapon) then return false end

    local currentVisualID = 0
    pcall(function()
        local wac = curWeapon.WeaponAvatarComponent
        if slua.isValid(wac) then currentVisualID = wac.CachedLoadedID or 0 end
    end)

    local curWeaponResID = 0
    pcall(function() curWeaponResID = curWeapon:GetItemDefineID().TypeSpecificID end)
    local targetSkin = F.findTargetSkinForWeaponRes(curWeaponResID) or curWeaponResID

    local isVisualMatched = false
    if currentVisualID > 0 and currentVisualID == targetSkin then
        isVisualMatched = true
    end

    
    if not _G.SmartWeaponWatcherActive then
        _G.SmartWeaponWatcherActive = true
        pcall(function()
            local ticker = require("common.time_ticker")
            if ticker and ticker.AddTimerLoop then
                ticker.AddTimerLoop(0, function()
                    local state = _G.LexusState and _G.LexusState.KillLimit
                    if state and state.Reached then return end
                    if not _G.LexusConfig.ModSkin then return end
                    
                    
                    if _G.AddOutfit and not _G.AddOutfit.isInRealMatch() then return end
                    
                    local pController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
                    if not pController or not slua.isValid(pController) then return end
                    local pChar = pController:GetPlayerCharacterSafety()
                    if not pChar or not slua.isValid(pChar) then return end
                    
                    
                    local WeaponManager = pChar:GetWeaponManager()
                    if not WeaponManager or not slua.isValid(WeaponManager) then return end
                    local uWeaponList = WeaponManager:GetAllInventoryWeaponList(false)
                    if not uWeaponList or not slua.isValid(uWeaponList) then return end
                    
                    local count = uWeaponList:Num()
                    
                    for i = 0, count - 1 do
                        local wep = uWeaponList:Get(i)
                        if slua.isValid(wep) then
                            
                            local synSkinID = F.getSynMasterSkinID(wep)
                            local baseID = 0
                            pcall(function() baseID = wep:GetItemDefineID().TypeSpecificID end)
                            local tSkin = F.findTargetSkinForWeaponRes(baseID) or baseID
                            
                            
                            
                            if synSkinID ~= tSkin or _G.LexusConfig.SkinAttachment then
                                if _G.AddOutfit and _G.AddOutfit.applySkinToWeapon then
                                    _G.AddOutfit.applySkinToWeapon(wep)
                                end
                            end
                        end
                    end
                end, -1, 0.4) 
            end
        end)
    end

    
    if isVisualMatched and not _G.LexusConfig.SkinAttachment then
        _weaponApplied = true
        return true
    end

    F.buildSkinMappings()
    local okSyn = F.applySkinToWeapon(curWeapon)

    return okSyn
end

local _matchTimer = nil
local _matchWearDone = false

function F.startMatchWatcher(char)
    if _matchTimer or PERF.matchActive then return end
    PERF.matchActive = true
    local skipWear = PERF.wearDoneThisMatch
    _matchWearDone = skipWear
    _avatarItemsRegistered = false
    _weaponDiagDone = false
    _weaponApplied = false
    _lastWeaponResID = 0
    local elapsed = 0

    _matchTimer = char:AddGameTimer(MATCH_TICK_SEC, true, function()
        elapsed = elapsed + MATCH_TICK_SEC
        local cur = F.getLocalChar()
        if not cur or not slua.isValid(cur) then return end

        if not _matchWearDone then
            _matchWearDone = F.matchApplyAllSlots(cur)
        end
        F.matchApplyHat(cur)
        F.matchApplyFaceWear(cur) 
        if not _weaponApplied then
            F.matchApplyWeaponSkin(cur)
        end
        if F.isCharacterAirborne(cur) then
            F.applyAirborneSlots(cur, true)
        end

        if (_matchWearDone and _weaponApplied) or elapsed >= MATCH_MAX_SEC then
            if _matchWearDone then
                PERF.wearDoneThisMatch = true
            end
            if _matchTimer and cur.RemoveGameTimer then
                pcall(function() cur:RemoveGameTimer(_matchTimer) end)
            end
            _matchTimer = nil
            PERF.matchActive = false
        end
    end)
end

function F.stopMatchWatcher()
    if _matchTimer then
        pcall(function()
            local char = F.getLocalChar()
            if char and char.RemoveGameTimer then char:RemoveGameTimer(_matchTimer) end
        end)
        _matchTimer = nil
    end
    PERF.matchActive = false
    PERF.wearDoneThisMatch = false
    _matchWearDone = false
    _avatarItemsRegistered = false
    _weaponApplied = false
    _weaponDiagDone = false
    _lastWeaponResID = 0
end

function F.hookAirborneCache()
    if _G.AddOutfitAirborneHooked then return end
    _G.AddOutfitAirborneHooked = true
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_ITEM_LIST then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_ITEM_LIST, function()
                F.syncAirborneCacheFromLobby()
            end)
        end
    end)
end

function F.hookPutOnRsp()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        local o = wl.on_puton_rsp
        wl.on_puton_rsp = function(self, res, item, olditem, index, extra)
            o(self, res, item, olditem, index, extra)
            if not item or not item.instid then return end
            local resID = tonumber(item.res_id)
            local insID = tonumber(item.instid)
            if not resID or not insID then return end
            local c = F.cfg(resID)
            local st = F.subType(c)
            if st == OUTFIT_SUB then
                F.saveEquip(resID, insID)
            elseif st == HAT_SUB or FACE_SUBS[st] or BODY_SUBS[st] or HELMET_SUBS[st]
                or st == PARACHUTE_SUB or F.isGlideRes(resID) or st == GLOVES_SUB then
                F.saveEquip(resID, insID)
            elseif F.isParachuteRes(resID) or F.isGlideRes(resID) then
                F.saveEquip(resID, insID)
            elseif HEAD_SUBS[st] then
                F.saveEquip(resID, insID)
            elseif GUN_SUB[st] then
                local wid = F.weaponIdFromSkin(resID)
                if wid then F.cacheWeaponSkinFromIns(wid, insID) end
            elseif st == MELEE_ID then
                F.cacheWeaponSkinFromIns(MELEE_ID, insID)
            elseif F.isInjectedIns(insID) then
                F.saveEquip(resID, insID)
            end
        end
    end)
end

function F.hookLobbyWeaponCache()
    if _G.AddOutfitLobbyWeaponCacheHooked then return end
    _G.AddOutfitLobbyWeaponCacheHooked = true
    pcall(function()
        local Arm = require("client.logic.armory.logic_armory")
        local oRsp = Arm.install_weapon_skin_rsp
        Arm.install_weapon_skin_rsp = function(client_data, errorCode, weapon_id, instanceID)
            oRsp(client_data, errorCode, weapon_id, instanceID)
            if (errorCode == 0 or errorCode == NET_OK) and F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
        local oH = Arm.HandleWeaponSkinChange
        Arm.HandleWeaponSkinChange = function(client_data, weapon_id, instanceID)
            oH(client_data, weapon_id, instanceID)
            if F.isWeaponSkinIns(instanceID) then
                F.cacheWeaponSkinFromIns(weapon_id, instanceID)
            end
        end
    end)
    pcall(function()
        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
        local o = wgl.on_put_on_weapon_wear_rsp
        wgl.on_put_on_weapon_wear_rsp = function(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            o(self, client_data, res, weapon_id, new_skin_id, extra_weapon_list)
            if res == 0 or res == NET_OK then
                F.cacheWeaponSkinFromIns(weapon_id, new_skin_id)
            end
        end
    end)
    pcall(function()
        if not EventSystem or not EventSystem.registEvent then return end
        if EVENTTYPE_WARDROBE and EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN then
            EventSystem:registEvent(EVENTTYPE_WARDROBE, EVENTID_WARDROBE_UPDATE_CURRENT_PUT_ON_GUN, function(_, _, resOrFlag, weapon_id)
                weapon_id = tonumber(weapon_id)
                if weapon_id and weapon_id > 0 then
                    pcall(function()
                        local wgl = require("client.slua.logic.wardrobe.logic_wardrobe_gun")
                        local insID = tonumber(wgl:GetSkinIdByWeaponID(weapon_id)) or 0
                        if insID > 0 then F.cacheWeaponSkinFromIns(weapon_id, insID) end
                    end)
                elseif tonumber(resOrFlag) and tonumber(resOrFlag) > 100000 then
                    pcall(function()
                        local wid = F.weaponIdFromSkin(resOrFlag)
                        if wid then
                            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                            local ins = wd.GetWardrobeInsIdByResId and wd:GetWardrobeInsIdByResId(resOrFlag)
                            if ins and ins > 0 then F.cacheWeaponSkinFromIns(wid, ins) end
                        end
                    end)
                end
            end)
        end
    end)
    pcall(function()
        local WRH = require("client.network.Protocol.WardRobeHandler")
        local oHeadReq = WRH.send_depot_set_head_show_req
        WRH.send_depot_set_head_show_req = function(insID)
            insID = tonumber(insID) or 0
            if insID > 0 and F.isInjectedIns(insID) then
                local wd = require("client.slua.logic.wardrobe.wardrobe_data")
                local d = wd:GetHallDepotItemDataByInsID(insID)
                if d and d.resID then
                    F.saveEquip(tonumber(d.resID), insID)
                end
                local fbd = require("client.slua.logic.wardrobe.fashionbag.fashionbag_data")
                fbd:SetHeadShow(insID)
                WRH.on_depot_set_head_show_rsp(NET_OK, insID)
                return
            end
            return oHeadReq(insID)
        end
        local oHead = WRH.on_depot_set_head_show_rsp
        WRH.on_depot_set_head_show_rsp = function(err_code, id)
            oHead(err_code, id)
            if err_code ~= 0 and err_code ~= NET_OK then return end
            id = tonumber(id) or 0
            if id <= 0 then return end
            local wd = require("client.slua.logic.wardrobe.wardrobe_data")
            local d = wd:GetHallDepotItemDataByInsID(id)
            if d and d.resID then
                local st = tonumber(d.itemSubType or F.subType(F.cfg(d.resID)))
                if st == HAT_SUB or HELMET_SUBS[st] then
                    F.saveEquip(tonumber(d.resID), id)
                end
            end
        end
    end)
end

function F.hookWardrobePutOnReq()
    pcall(function()
        local wl = require("client.slua.logic.wardrobe.logic_wardrobe_new")
        if wl._AddOutfitPutOnReqHooked then return end
        wl._AddOutfitPutOnReqHooked = true
        local oReq = wl.wardrobe_puton_req
        wl.wardrobe_puton_req = function(self, insID, extra)
            insID = tonumber(insID)
            F.ensureDepotItemValid(insID)
            if F.tryLocalWearByIns(insID) then return end
            return oReq(self, insID, extra)
        end
        if not wl._AddOutfitPutOnDataHooked then
            wl._AddOutfitPutOnDataHooked = true
            local oData = wl.wardrobe_puton_data_req
            wl.wardrobe_puton_data_req = function(self, itemData)
                if itemData then
                    local insID = tonumber(itemData.ins_id or itemData.insID)
                    local resID = tonumber(itemData.res_id or itemData.resID)
                    F.clearItemExpire(itemData, insID, resID)
                    F.ensureDepotItemValid(insID, resID)
                end
                return oData(self, itemData)
            end
        end
    end)
end

local _bootstrapNotified = false

function F.bootstrapMatch(char)
    char = char or F.getLocalChar()
    if not char or not slua.isValid(char) then return false end
    if PERF.matchActive then return true end
    local now = os.clock()
    if (now - PERF.lastBootstrapAt) < BOOTSTRAP_COOLDOWN then return false end
    PERF.lastBootstrapAt = now
    F.syncWeaponCacheFromLobby(true)
    F.applyPersistSlotsToCache()
    F.cleanArmoryPollution()
    F.syncGlobalWearSkins()
    F.syncAirborneToDataMgr()
    pcall(function() F.applyAirborneSlots(char, F.isCharacterAirborne(char)) end)
    F.syncVehicleCacheFromDataMgr()
    F.syncVehicleSlotsToDataMgr()
    pcall(function() F.applyVehicleSkinsToPC(F.getPC()) end)
    F.startVehicleSkinTicker()
    pcall(function()
        local v = F.getMatchVehicle()
        if slua.isValid(v) then F.autoApplyVehicleSkinOnEnter(v) end
    end)
    _weaponApplied = false
    _weaponDiagDone = false
    _matchApplied = false
    if not _bootstrapNotified then
        _bootstrapNotified = true
    end
    F.startMatchWatcher(char)
    return true
end

function F.hookMatchAvatar()
    pcall(function()
        local CAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.CharacterAvatarComponent")
        local o = CAC.OnAvatarAllMeshLoadedLua
        CAC.OnAvatarAllMeshLoadedLua = function(self)
            o(self)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                if PERF.wearDoneThisMatch or PERF.matchActive then return end
                local char = F.getLocalChar()
                if char and char.AddGameTimer then
                    char:AddGameTimer(0.5, false, function() F.bootstrapMatch(char) end)
                end
            end)
        end
    end)
    pcall(function()
        local WAC = require("GameLua.Mod.Library.GamePlay.Avatar.Component.WeaponAvatarComponent")
        local oLoad = WAC.OnWeaponAvatarLoadedLua
        WAC.OnWeaponAvatarLoadedLua = function(self, slotID, definedID)
            oLoad(self, slotID, definedID)
            pcall(function()
                if self.IsLobbyActor and self:IsLobbyActor() then return end
                local isSelf = self.IsSelf and self:IsSelf()
                if not isSelf then return end
                local char = F.getLocalChar()
                if not char then return end
                _weaponApplied = false
                if not PERF.matchActive then F.bootstrapMatch(char)
                elseif char.AddGameTimer then
                    char:AddGameTimer(0.25, false, function()
                        local c = F.getLocalChar()
                        if c then F.matchApplyWeaponSkin(c) end
                    end)
                end
            end)
        end
    end)
end

function F.hookVehicleInfoInit()
    pcall(function()
        if DataMgr._AddOutfitVehInfoHooked then return end
        DataMgr._AddOutfitVehInfoHooked = true
        local orig = DataMgr.InitVehicleInfo
        DataMgr.InitVehicleInfo = function(vehicle_info, vst_skin)
            vehicle_info = F.mergeInjectedIntoVehicleSlotList(vehicle_info)
            orig(vehicle_info, vst_skin)
            F.later(0.15, function()
                F.reapplyVehicleSlotsFromConfig()
                F.reapplyHallThemeFromConfig()
                LOBBY.reapplyDone = false
                LOBBY.reapplyScheduled = false
                F.scheduleLobbyReapplyOnce()
            end)
        end
    end)
end

function F.hookVehicleSkinDataInit()
    pcall(function()
        if DataMgr._AddOutfitVehSkinDataHooked then return end
        DataMgr._AddOutfitVehSkinDataHooked = true
        local origInit = DataMgr.InitVehicleSkinData
        DataMgr.InitVehicleSkinData = function(data)
            data = F.mergeInjectedVehicleSkinTable(data)
            origInit(data)
            F.later(0.1, function()
                F.equipVehicleTypesFromConfig(PERSIST.configVehicleSlots)
            end)
        end
        local origUpd = DataMgr.UpdateVehicleSkin
        DataMgr.UpdateVehicleSkin = function(itemSubType, putOnId)
            origUpd(itemSubType, putOnId)
            if not _G.AddOutfitApplyingConfig and F.isInjectedIns(putOnId) then
                F.setLobbyVehicleManual(itemSubType, R.insToRes[putOnId], putOnId)
            end
        end
    end)
    pcall(function()
        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
        if HallThemeUtils._AddOutfitLobbyVehHooked then return end
        HallThemeUtils._AddOutfitLobbyVehHooked = true
        local orig = HallThemeUtils.ProcPutOnVehicle
        HallThemeUtils.ProcPutOnVehicle = function(putOnItem, bShowVehicle)
            orig(putOnItem, bShowVehicle)
            if not _G.AddOutfitApplyingConfig and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setLobbyVehicleManual(F.vehicleSubType(res or R.insToRes[ins]), res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookHallTheme()
    pcall(function()
        local HT = require("client.logic.lobby.hall_theme_utils")
        if HT._AddOutfitHallThemeHooked then return end
        HT._AddOutfitHallThemeHooked = true
        local orig = HT.ProcPutOnHallTheme
        HT.ProcPutOnHallTheme = function(putOnItem, putOffItem)
            orig(putOnItem, putOffItem)
            if not _G.AddOutfitApplyingTheme and putOnItem then
                local ins = tonumber(putOnItem.instid)
                local res = tonumber(putOnItem.res_id)
                if ins and F.isInjectedIns(ins) then
                    F.setHallThemeManual(res or R.insToRes[ins], ins)
                end
            end
        end
    end)
end

function F.hookGarageTheme()
    pcall(function()
        local TeamupHandler = require("client.network.Protocol.TeamupHandler")
        local ModuleManager = require("client.module_framework.ModuleManager")
        if not TeamupHandler then return end
        
        
        local o_send_update = TeamupHandler.send_update_car_main_page_slot_req
        if o_send_update and not TeamupHandler._AddOutfitGarageUpdateHooked then
            TeamupHandler._AddOutfitGarageUpdateHooked = true
            TeamupHandler.send_update_car_main_page_slot_req = function(slot_id, item_inst_id)
                
                
                if F.isInRealMatch() then 
                    return o_send_update(slot_id, item_inst_id) 
                end

                if F.isInjectedIns(tonumber(item_inst_id)) then
                    local resID = R.insToRes[tonumber(item_inst_id)]
                    local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                    if not GarageThemeSystem then return end

                    GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                        inst_id = tonumber(item_inst_id),
                        res_id = resID
                    }

                    for k, v in pairs(GarageThemeSystem.GarageVehicleInfo) do
                        if k ~= slot_id and v.inst_id == tonumber(item_inst_id) then
                            GarageThemeSystem.GarageVehicleInfo[k] = nil
                        end
                    end

                    pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                    if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                        EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                    end

                    local itemCfg = F.cfg(resID)
                    if itemCfg and DataMgr and DataMgr.UpdateVehicleSkin then
                        local subType = itemCfg.ItemSubType or itemCfg.itemSubType
                        DataMgr.UpdateVehicleSkin(subType, tonumber(item_inst_id))
                    end
                    if DataMgr then DataMgr.vst_skin = tonumber(item_inst_id) end
                    
                    pcall(function()
                        local HallThemeUtils = require("client.logic.lobby.hall_theme_utils")
                        if HallThemeUtils then
                            if HallThemeUtils.UpdateThemeVehicleShow then HallThemeUtils.UpdateThemeVehicleShow() end
                            if HallThemeUtils.ShowThemeVehicle then HallThemeUtils.ShowThemeVehicle() end
                        end
                    end)
                    return
                end
                return o_send_update(slot_id, item_inst_id)
            end
        end

        
        local o_send_batch = TeamupHandler.send_batch_put_on_sportscar_req
        if o_send_batch and not TeamupHandler._AddOutfitGarageBatchHooked then
            TeamupHandler._AddOutfitGarageBatchHooked = true
            TeamupHandler.send_batch_put_on_sportscar_req = function(instid_list)
                
                
                if F.isInRealMatch() then 
                    return o_send_batch(instid_list) 
                end

                if type(instid_list) ~= "table" then
                    return o_send_batch(instid_list)
                end

                local hasInjected = false
                for slot_id, item_inst_id in pairs(instid_list) do
                    if F.isInjectedIns(tonumber(item_inst_id)) then
                        hasInjected = true
                        break
                    end
                end

                if not hasInjected then
                    return o_send_batch(instid_list)
                end

                local GarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)
                if not GarageThemeSystem then return end

                for slot_id, item_inst_id in pairs(instid_list) do
                    local insID = tonumber(item_inst_id)
                    if F.isInjectedIns(insID) then
                        local resID = R.insToRes[insID]
                        if insID ~= 0 and resID then
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = {
                                inst_id = insID,
                                res_id = resID
                            }
                        else
                            GarageThemeSystem.GarageVehicleInfo[slot_id] = nil
                        end
                    end
                end

                pcall(function() GarageThemeSystem:ReportSpecialEffectTlog() end)
                if EventSystem and EVENTTYPE_LOBBY_THEME and EVENTID_GARAGE_VEHICLE_DATA_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_LOBBY_THEME, EVENTID_GARAGE_VEHICLE_DATA_CHANGE)
                end

                local nonInjected = {}
                for slot_id, item_inst_id in pairs(instid_list) do
                    if not F.isInjectedIns(tonumber(item_inst_id)) then
                        nonInjected[slot_id] = item_inst_id
                    end
                end
                if next(nonInjected) then
                    return o_send_batch(nonInjected)
                end
            end
        end
    end)
end

function F.hookEnterGame()
    if _G.AddOutfitEnterGameHooked then return end
    _G.AddOutfitEnterGameHooked = true
    pcall(function()
        if EventSystem and EventSystem.registEvent and EVENTTYPE_LOBBY and EVENTID_ENTER_GAME_BEGIN then
            EventSystem:registEvent(EVENTTYPE_LOBBY, EVENTID_ENTER_GAME_BEGIN, function()
                local state = _G.LexusState and _G.LexusState.KillLimit
                if state then
                    local saved = state.DisabledConfig
                    if saved then
                        if saved.Bools then
                            for key, value in pairs(saved.Bools) do
                                _G.LexusConfig[key] = value
                            end
                        end
                    end
                    state.DisabledConfig = nil
                    state.MatchKills = 0
                    state.Reached = false
                    state.CleanupDone = false
                    state.Cleaning = false
                    state.PopupShown = false
                    state.SeenKillRecords = {}
                end
                _G.LexusState.LoopToken = myToken

                F.perfInvalidateLobby()
                F.syncWeaponCacheFromLobby(true)
                F.reapplyVehicleSlotsFromConfig(true)
                F.reapplyHallThemeFromConfig(true)
                pcall(F.applyVehicleSkinsToPC)
                F.stopMatchWatcher()
                _bootstrapNotified = false
            end)
        end
    end)
end

function F.afterInjectApply(firstTime)
    F.mergeInjectedArmorySkins()
    F.cleanArmoryPollution()
    if firstTime then
        F.refreshWardrobeOnce()
        F.persistApplyLoaded()
        F.hookGarageTheme()
        F.syncLobbyVehicleResFromIns()
        F.reapplyVehicleSlotsFromConfig(true)
        F.reapplyHallThemeFromConfig(true)
        F.reapplyWeaponsFromConfig()
        F.scheduleLobbyReapplyOnce()
    else
        F.reapplyWeaponsFromConfig()
    end
end



function F.start()
    F.restorePufferHooks()
    F.buildSkinMappings()
    if not _G.AddOutfitPersistLoaded then
        _G.AddOutfitPersistLoaded = true
        F.persistLoadFromDisk()
    end
    F.applyPersistSlotsToCache()
    F.syncGlobalWearSkins()
    
    _G.apply_vehicle_skin = F.matchApplyVehicleSkin
    _G.skinIdMappings = _G.AddOutfitSkinIdMappings
    
    F.hookDepotInit()
    F.hookWardrobeData()
    F.hookPageFilter()
    F.hookArmory()
    F.hookGunSkinId()
    F.hookPutOn()
    F.hookPutDown()
    F.hookVehicles()
    F.hookAirborneClick()
    F.hookVehicleInfoInit()
    F.hookVehicleSkinDataInit()
    F.hookHallTheme()
    F.hookWeaponWear()
    F.hookNotice()
    F.hookAvatarValid()
    F.hookPutOnRsp()
    F.hookAirborneCache()
    F.hookLobbyWeaponCache()
    F.hookLobbySwipePersistence()
    F.hookWardrobePutOnReq()
    F.hookWardrobeWearClicks()
    F.hookMatchAvatar()
    F.hookEquipmentRectify()
    F.hookWeaponSpawn()
    F.hookEnterGame()
    pcall(_G.ZDSessionTelemetryInstallWinHook)




local function decodeExpand(expandContent)
    local ok, exp = pcall(function() return slua.LuaArchiverDecode(LuaStateWrapper, expandContent) or {} end)
    return ok and exp or {}
end

local function encodeExpand(exp)
    return slua.LuaArchiverEncode(LuaStateWrapper, exp or {})
end

local _cachedMyName = nil
local function isMyKill(data)
    if not data then return false end
    if data.bIamCauser then return true end
    
    if not _cachedMyName then
        local hud = slua_GameFrontendHUD
        if hud then
            local pc = hud:GetPlayerController()
            if slua.isValid(pc) then
                local ch = pc:GetPlayerCharacterSafety()
                if slua.isValid(ch) then _cachedMyName = ch:GetPlayerNameSafety() end
            end
        end
    end
    if not _cachedMyName or _cachedMyName == "" then return false end
    return data.Causer == _cachedMyName or data.CauserRealPlayerName == _cachedMyName or data.CauserPlayerName == _cachedMyName
end

local function getCurrentWeaponSkinID()
    
    local hud = slua_GameFrontendHUD
    if not hud then return 0 end
    local pc = hud:GetPlayerController()
    if not slua.isValid(pc) then return 0 end
    local ch = pc:GetPlayerCharacterSafety()
    if not slua.isValid(ch) then return 0 end
    
    local currWeapon = ch:GetCurrentWeapon()
    if slua.isValid(currWeapon) and currWeapon.synData then
        local currentSkinID = 0
        pcall(function()
            local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
            local skinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
            
            
            if skinID > 1000000 then 
                currentSkinID = skinID
            end
        end)
        return currentSkinID
    end
    return 0
end

local _downloadedAssetsCache = {}
local function downloadTeamAssets(skinID)
    if not skinID or skinID == 0 or skinID == 69 then return end
    
    if _downloadedAssetsCache[skinID] then return end
    _downloadedAssetsCache[skinID] = true

    pcall(function()
        local PufferManager = require("client.slua.logic.download.puffer.puffer_manager")
        local PufferConst = require("client.slua.logic.download.puffer_const")
        PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {skinID})
        
        local cfg = CDataTable.GetTableData("TeamKillBroadcast", skinID)
        if cfg then
            if cfg.EffectPath and cfg.EffectPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.EffectPath})
            end
            if cfg.BgPath and cfg.BgPath ~= "" then
                PufferManager.Download(PufferConst.ENUM_DownloadType.ODPAK, {cfg.BgPath})
            end
        end
    end)
end

local function patchTeamKill(messageData)
    if not _G.LexusConfig.KillMessage then return messageData end 
    if not messageData or not isMyKill(messageData) then return messageData end
    local currentSkinID = getCurrentWeaponSkinID()
    if not currentSkinID or currentSkinID == 0 or currentSkinID == 69 then return messageData end
    local broadcastCfg = CDataTable.GetTableData("TeamKillBroadcast", currentSkinID)
    if not broadcastCfg or (not broadcastCfg.BgPath and not broadcastCfg.EffectPath) then return messageData end
    pcall(function()
        local exp = decodeExpand(messageData.ExpandDataContent)
        exp.CauserWeaponAvatarID = currentSkinID
        messageData.ExpandDataContent = encodeExpand(exp)
        messageData.bShowBottomBothSidesKillInfo = true
        messageData.bIamCauser = true
        downloadTeamAssets(currentSkinID)
    end)
    return messageData
end

local function installTeamBroadcastHooks()
    local function wrapCopy(mod, tag)
        if not mod then return end
        local impl2 = mod.__inner_impl or mod
        if not impl2 or not impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable then return end
        local key = "__teamKillCopy_" .. tag
        if not impl2[key] then impl2[key] = impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable end
        local O_Copy = impl2[key]
        impl2.CopyKillOrPutDownMessageDataUserDataToLuaTable = function(self, messageData)
            local copied = O_Copy(self, messageData)
            
            
            if not _G.LexusConfig.KillMessage then return copied end
            
            local ok2, result = pcall(function() return patchTeamKill(copied) end)
            if ok2 then return result end
            return copied
        end
    end
    pcall(function() wrapCopy(require("GameLua.Mod.BaseMod.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "base") end)
    pcall(function() wrapCopy(require("GameLua.Mod.SingleTraining.Client.BattleKillBroadcast.BattleKillBroadcastSubSystem"), "training") end)
end


_G.killCountInfo = {
    [101001] = 0000, [101004] = 0000, [101003] = 0000, [103001] = 0000,
    [102001] = 0000, [105001] = 0000, [102002] = 0000, [103002] = 0000
}

function _G.saveKillCountToFile()
    
end

function _G.loadKillCountFromFile()
    
end

function _G.addKill(weaponID, count)
    if not weaponID or not count then return end
    _G.killCountInfo[weaponID] = (_G.killCountInfo[weaponID] or 0) + count
    _G.saveKillCountToFile()
end

function _G.getKills(weaponID) return weaponID and _G.killCountInfo[weaponID] or 0 end


pcall(function()
    local SKillInfo = require("GameLua.Mod.BaseMod.Client.KillInfoTips.KillInfo")
    local SKillInfoModuleManager = require("client.module_framework.ModuleManager")
    local UEnums = _ENV.UEnums
    local ECharacterHealthStatus = import("ECharacterHealthStatus")
    
    if SKillInfo and SKillInfo.__inner_impl and SKillInfo.__inner_impl.FileItem then
        local O_FileItem = SKillInfo.__inner_impl.FileItem
        SKillInfo.__inner_impl.FileItem = function(self, DamageRecordData)
            if not self or not DamageRecordData then return end

            if _G.LexusState and _G.LexusState.KillLimit and not _G.LexusState.KillLimit.Reached
                and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                local reached = false
                pcall(function()
                    if isMyKill(DamageRecordData) then
                        reached = _G.ZD_RegisterMatchKill(DamageRecordData)
                    end
                end)
                if reached then
                    return O_FileItem(self, DamageRecordData)
                end
            end

            if not _G.LexusConfig.SkinDeadBox and not _G.LexusConfig.KillCountUI and not _G.LexusConfig.KillMessage then
                return O_FileItem(self, DamageRecordData)
            end

            local LogicKillCounter = SKillInfoModuleManager.GetModule(SKillInfoModuleManager.CommonModuleConfig.LogicKillCounter)
            if not LogicKillCounter then return O_FileItem(self, DamageRecordData) end

            local uCharacter = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController() and slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            if not uCharacter or not slua.isValid(uCharacter) then return O_FileItem(self, DamageRecordData) end

            local SelfName = uCharacter:GetPlayerNameSafety()
            local bIsCauser = DamageRecordData.Causer == SelfName

            if bIsCauser then
                if DamageRecordData.DamageType == UEnums.DamageType.VehicleDamage then
                    if _G.LexusConfig.SkinDeadBox or _G.LexusConfig.KillMessage then 
                        local carSkinID = _G.CurrentEquipVehicleID or 0
                        if carSkinID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            ExpandData.CauserVehicleSkinID = carSkinID
                            if _G.LexusConfig.KillMessage then 
                                self:ChangeInfoBgByWeaponAvatarIDLua(carSkinID)
                                DamageRecordData.CauserWeaponAvatarID = carSkinID
                                DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                            end
                            DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                        end
                    end
                elseif DamageRecordData.CauserWeaponAvatarID ~= 69 and DamageRecordData.CauserClothAvatarID ~= 69 then
                    local currWeapon = uCharacter:GetCurrentWeapon()
                    if currWeapon and slua.isValid(currWeapon) then
                        local defineID = currWeapon:GetItemDefineID()
                        local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                        if DefineID ~= 0 then
                            local ExpandData = slua.LuaArchiverDecode(LuaStateWrapper, DamageRecordData.ExpandDataContent) or {}
                            local hasChanged = false

                            local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                            if SupportKillCounter and DamageRecordData.ResultHealthStatus == ECharacterHealthStatus.FinishedLastBreath then
                                local synDataRef = slua.IndexReference(currWeapon.synData:Get(7), "defineID")
                                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                                
                                
                                if SkinID > 1000000 then 
                                    if _G.LexusConfig.KillCountUI then 
                                        ExpandData.KillCounterItemId = DefineID
                                        ExpandData.KillCounterNum = (ExpandData.KillCounterNum or 0) + 1
                                        _G.addKill(DefineID, 1)
                                        hasChanged = true
                                    end
                                    if _G.LexusConfig.SkinDeadBox then 
                                        _G.NeedCheckDeadBoxTimer = 5 
                                        hasChanged = true
                                    end
                                end
                            end

                            if hasChanged or _G.LexusConfig.KillMessage then
                                _G.UpdateMyKillCounter = true
                                if _G.LexusConfig.KillMessage then 
                                    local synData = currWeapon.synData
                                    if synData and slua.isValid(synData) then
                                        local weaponDefineID = slua.IndexReference(synData:Get(7), "defineID")
                                        if weaponDefineID and slua.isValid(weaponDefineID) then
                                            DamageRecordData.CauserWeaponAvatarID = weaponDefineID.TypeSpecificID
                                        end
                                    end
                                    DamageRecordData.CauserClothAvatarID = _G.SuitSkin or 0
                                end
                                DamageRecordData.ExpandDataContent = slua.LuaArchiverEncode(LuaStateWrapper, ExpandData)
                            end
                        end
                    end
                end
            end
            O_FileItem(self, DamageRecordData)
        end
    end
end)


pcall(function()
    local MyMainKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainKillCounter")
    local MyKillCountSubSystem = require("GameLua.Mod.BaseMod.Client.KillCounter.KillCounterUISubsystem")
    local MyMainWeaponInfoItemUI = require("GameLua.Mod.BaseMod.Client.Backpack.MainWeaponInfoItemUI")
    local MyMainWeaponKillCounter = require("GameLua.Mod.BaseMod.Client.KillCounter.MainWeaponKillCounter")
    local SlotBase = require("GameLua.Mod.BaseMod.Client.MainControlUI.SwitchWeaponSlotMode2")
    local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    local UIManager = require("client.slua_ui_framework.manager")
    local ModuleManager = require("client.module_framework.ModuleManager")

    if MyKillCountSubSystem and MyKillCountSubSystem.__inner_impl then
        _G.OurkillCountSystem = MyKillCountSubSystem.__inner_impl
        
        local o_OnRefreshUI = MyMainKillCounter.__inner_impl.OnRefreshUI
        MyMainKillCounter.__inner_impl.OnRefreshUI = function(self, _, _, UID)
            if not _G.LexusConfig.KillCountUI then return end 
            local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
            local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, self.WeaponID)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self.KillCounterItem:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), SkinID)
            end
        end

        MyKillCountSubSystem.__inner_impl.CheckSupportKCUI = function(self) return _G.LexusConfig.KillCountUI end

        local o_UpdateMainKillCounterUI = MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.UpdateMainKillCounterUI = function(self, bShow, WeaponID, AvatarID)
            
            if not _G.LexusConfig.KillCountUI then
                o_UpdateMainKillCounterUI(self, false, WeaponID, AvatarID) 
                local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
                return
            end

            o_UpdateMainKillCounterUI(self, bShow, WeaponID, AvatarID)
            local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
         
            if not bShow and MainKillCounter then
                UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
            elseif bShow and currweapon ~= nil then
                local DefineID = currweapon:GetItemDefineID().TypeSpecificID
                local currentEquipAvatrid = slua.IndexReference(currweapon.synData:Get(7), "defineID").TypeSpecificID
                local LogicKillCounter = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.LogicKillCounter)
                local SupportKillCounter = LogicKillCounter:GetBaseKillCounterIdByWeaponId(DefineID)
                
                local curEquipedKillCounter = LogicKillCounter:GetEquipedKillCounterId(6114302174, currentEquipAvatrid)
                
                
                local isModdedSkin = (currentEquipAvatrid and currentEquipAvatrid > 1000000)
                
                
                if (SupportKillCounter == nil or not isModdedSkin) then
                    if MainKillCounter then
                        UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter)
                    end
                else
                    
                    if not MainKillCounter then
                        UIManager.ShowUI(UIManager.UI_Config_InGame.MainKillCounter, DefineID, currentEquipAvatrid)
                        MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
                        if MainKillCounter then
                            MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                        end
                    else
                        MainKillCounter:UpdateWeaponID(DefineID, currentEquipAvatrid)
                        MainKillCounter:SetKillCounterItemShowWithNum(curEquipedKillCounter, _G.getKills(DefineID), currentEquipAvatrid)
                    end
                end
            end
        end

        local o_CheckNeedMainKillCounterUI = MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI
        MyKillCountSubSystem.__inner_impl.CheckNeedMainKillCounterUI = function(self, Weapon, PlayerID)
            if not _G.LexusConfig.KillCountUI then return end 
            local uCharacter = slua_GameFrontendHUD:GetPlayerController():GetPlayerCharacterSafety()
            local currweapon = uCharacter:GetCurrentWeapon()
            if currweapon ~= nil then
                local defineID = currweapon:GetItemDefineID()
                local DefineID = defineID and slua.isValid(defineID) and defineID.TypeSpecificID or 0
                local synDataRef = slua.IndexReference(currweapon.synData:Get(7), "defineID")
                local SkinID = synDataRef and slua.isValid(synDataRef) and synDataRef.TypeSpecificID or 0
                self:UpdateMainKillCounterUI(true, DefineID, SkinID)
            end
        end
    end
end)


local _lastKCWeaponID = 0
local _lastKCSkinID = 0

_G.GameAvatarHandlerkillcounter = function()
    local state = _G.LexusState and _G.LexusState.KillLimit
    if state and state.Reached then return end

    local UIManager = require("client.slua_ui_framework.manager")
    
    if not _G.LexusConfig.KillCountUI then
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
        return 
    end

    local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not PlayerController or not slua.isValid(PlayerController) then return end
    
    local uCharacter = PlayerController:GetPlayerCharacterSafety()
    if not uCharacter or not slua.isValid(uCharacter) then return end
    
    local currweapon = uCharacter:GetCurrentWeapon()
    if currweapon and slua.isValid(currweapon) then
        
        local defineIDObj = currweapon:GetItemDefineID()
        local currentWeaponID = (defineIDObj and slua.isValid(defineIDObj)) and defineIDObj.TypeSpecificID or 0
        
        
        local currentSkinID = 0
        if _G.AddOutfitLastAppliedSkin and _G.AddOutfitLastAppliedSkin[currentWeaponID] then
            currentSkinID = _G.AddOutfitLastAppliedSkin[currentWeaponID]
        end

        
        if _G.UpdateMyKillCounter or currentWeaponID ~= _lastKCWeaponID or currentSkinID ~= _lastKCSkinID then
            _lastKCWeaponID = currentWeaponID
            _lastKCSkinID = currentSkinID
            _G.UpdateMyKillCounter = false
            
            if _G.OurkillCountSystem then
                _G.OurkillCountSystem:UpdateMainKillCounterUI(true, currentWeaponID, currentSkinID)
            end
        end
    else
        _lastKCWeaponID = 0
        _lastKCSkinID = 0
        local MainKillCounter = UIManager.GetUI(UIManager.UI_Config_InGame.MainKillCounter)
        if MainKillCounter then UIManager.CloseUI(UIManager.UI_Config_InGame.MainKillCounter) end
    end
end

local function LobbyTickSetup()
    if not _G.CounterUpdated then
        _G.CounterUpdated = true
        _G.loadKillCountFromFile()
    end
    
end


pcall(function()
    installTeamBroadcastHooks()
    LobbyTickSetup() 
    
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, _G.GameAvatarHandlerkillcounter, -1, 0.5)
        
    end
end)


    F.startVehicleSkinTicker()
    if not _G.AddOutfitVehInitTimers then
        _G.AddOutfitVehInitTimers = true
        F.later(1.5, function() pcall(F.applyVehicleSkinsToPC) end)
        F.later(4.0, function() pcall(F.applyVehicleSkinsToPC) end)
    end

    pcall(function()
        if F.isInRealMatch() then
            local char = F.getLocalChar()
            if char then
                F.bootstrapMatch(char)
            end
        end
    end)

    local firstLobby = not _G.AddOutfitLobbyInitDone
    if F.injectAll() then
        if firstLobby then _G.AddOutfitLobbyInitDone = true end
        F.afterInjectApply(firstLobby)
        return
    end
    local tries = 0
    local function retry()
        tries = tries + 1
        if F.injectAll() then
            local ft = not _G.AddOutfitLobbyInitDone
            if ft then _G.AddOutfitLobbyInitDone = true end
            F.afterInjectApply(ft)
            return
        end
        if tries < INJECT_RETRY_MAX then F.later(INJECT_RETRY_SEC, retry) end
    end
    F.later(INJECT_RETRY_SEC, retry)
end

_G.AddOutfit = F
F.start()


_G.AddOutfitLobbyRestored = false

local function AutoRestoreLobbySkin()
    if _G.AddOutfitLobbyRestored then return end
    
    
    if _G.AddOutfit and _G.AddOutfit.isInRealMatch() then return end
    
    pcall(function()
        if GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity() then
            
            if DataMgr and DataMgr.roleData and DataMgr.roleData.uid then
                local LMC = require("client.slua.logic.lobby.Main.Lobby_Main_Control")
                if LMC and LMC.GetCurPage then
                    if _G.AddOutfit and _G.AddOutfit.reapplyLobbyEquipped then
                        
                        _G.AddOutfit.persistLoadFromDisk() 
                        _G.AddOutfit.persistApplyLoaded() 
                        _G.AddOutfit.reapplyLobbyEquipped() 
                        
                        
                        _G.AddOutfitLobbyRestored = true
                    end
                end
            end
        end
    end)
end


pcall(function()
    local ticker = require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker.AddTimerLoop(0, AutoRestoreLobbySkin, -1, 1.0)
    end
end)











pcall(function()
    local QuickExpressionUtils = require("GameLua.Mod.BaseMod.Client.Emote.QuickExpressionUtils")

    
    local EXTRA_EMOTES = {
          
    12201301, 
    12216101, 
    12212201, 
    12219207, 
    12209001, 
    12219561, 
    12210001, 
    12219022, 
    12208801, 
    12210801, 
    12200701, 
    12219242, 
    12206001, 
    12205401, 
    12205201, 
    12212601, 
    12205601, 
    12219208, 
    12212001, 
    12206801, 
    12209801, 
    12211401, 
    12207001, 
    12211801, 
    12207901, 
    12203401, 
    12204001, 
    12201801, 
    12215601, 
    12215532, 
    12213201, 
    12215529, 
    12219053, 
    12204601, 
    12215701, 
    12219003, 
    12219004, 
    12219009, 
    12219216, 
    }

    
    local CachedInGameEmotes = nil
    local LastBaseCount = -1
    local LastEmoteSwitchState = nil

    
    local function GetOptimizedEmoteList(baseList)
        local baseCount = baseList and #baseList or 0
        local isEmoteModEnabled = _G.LexusConfig.ModEmote == true

        
        if CachedInGameEmotes and LastBaseCount == baseCount and LastEmoteSwitchState == isEmoteModEnabled then
            return CachedInGameEmotes
        end

        local compact = {}
        local seen = {}
        
        
        if baseList then
            for _, data in pairs(baseList) do
                if data and data.DefineID and data.DefineID.TypeSpecificID then
                    table.insert(compact, data)
                    seen[data.DefineID.TypeSpecificID] = true
                end
            end
        end

        
        if isEmoteModEnabled then
            for _, nEmoteID in ipairs(EXTRA_EMOTES) do
                if not seen[nEmoteID] then
                    table.insert(compact, {
                        DefineID = {TypeSpecificID = nEmoteID},
                        Name = tostring(nEmoteID)
                    })
                    seen[nEmoteID] = true
                end
            end
        end

        CachedInGameEmotes = compact
        LastBaseCount = baseCount
        LastEmoteSwitchState = isEmoteModEnabled
        return CachedInGameEmotes
    end

    
    if QuickExpressionUtils and not _G.__EMOTE_INGAME_HOOKED then
        _G.__EMOTE_INGAME_HOOKED = true
        _G.__EMOTE_ORIG_GET_LIST = QuickExpressionUtils.GetShowExpressionList
        
        QuickExpressionUtils.GetShowExpressionList = function()
            local baseList, nWeaponShowEmoteID = _G.__EMOTE_ORIG_GET_LIST()
            return GetOptimizedEmoteList(baseList), nWeaponShowEmoteID
        end
    end

    
    if not _G.__EMOTE_MENU_EVENT_HOOKED and EventSystem and EventSystem.registEvent then
        _G.__EMOTE_MENU_EVENT_HOOKED = true
        EventSystem:registEvent(EVENTTYPE_INGAME, EVENTID_INGAME_QUICK_EXPRESSION_DECAL_CLICK, function()
            pcall(function()
                
                if not _G.LexusConfig.ModEmote then return end 

                local UIManager = require("client.slua_ui_framework.manager")
                if not UIManager or not UIManager.UI_Config_InGame then return end
                local subPanel = UIManager.GetUI(UIManager.UI_Config_InGame.QuickExpressionDecalSubPanel)
                
                if subPanel and subPanel.GetQuickExpressionDecalItemByIndex and CachedInGameEmotes then
                    local showCount = 0
                    for _, data in ipairs(CachedInGameEmotes) do
                        local nEmoteID = data.DefineID and data.DefineID.TypeSpecificID
                        if nEmoteID and nEmoteID > 0 then
                            showCount = showCount + 1
                            local item = subPanel:GetQuickExpressionDecalItemByIndex(showCount)
                            if item then
                                
                                if item.UIRoot.WidgetSwitcher_Effect then item.UIRoot.WidgetSwitcher_Effect:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                                if item.UIRoot.Image_Weapon then item.UIRoot.Image_Weapon:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) end
                                
                                item:Show()
                                item:RefreshData(nEmoteID, -1)
                            end
                        end
                    end
                    if subPanel.HideRestBlocks then subPanel:HideRestBlocks(showCount) end
                    if subPanel.UIRoot then
                        subPanel.UIRoot.WrapBox_List:SetWidgetVisibility(UEnums.ESlateVisibility.Visible)
                        subPanel.UIRoot.VerticalBox_Empty:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                    end
                end
            end)
        end)
    end
end)




local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  },
  {
    SpiderSenseFootprintFeature = "GameLua.Mod.Library.GamePlay.Feature.SpiderSenseFootprintFeature"
  },
  {
    GeneralShowSpotFeature = "GameLua.Mod.BRMod.Gameplay.Feature.PlayerCharacterGeneralShowSpotFeature"
  }
}, "BRPlayerCharacterBase")
