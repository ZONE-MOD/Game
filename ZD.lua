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


local function Notify(msg) local s = "{@ZONE_MOD} VIP New] " .. tostring(msg)
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
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}

local GLOBAL_BONE_LIST = {
    "head", "neck_01", "pelvis",
    "upperarm_r", "lowerarm_r", "hand_r",
    "upperarm_l", "lowerarm_l", "hand_l",
    "thigh_l", "calf_l", "foot_l",
    "thigh_r", "calf_r", "foot_r"
}

local GLOBAL_CONNECTIONS = {
    {"neck_01", "pelvis", C_YELLOW},
    {"neck_01", "upperarm_l", C_CYAN}, {"upperarm_l", "lowerarm_l", C_CYAN}, {"lowerarm_l", "hand_l", C_CYAN},
    {"neck_01", "upperarm_r", C_CYAN}, {"upperarm_r", "lowerarm_r", C_CYAN}, {"lowerarm_r", "hand_r", C_CYAN},
    {"pelvis", "thigh_l", C_CYAN}, {"thigh_l", "calf_l", C_CYAN}, {"calf_l", "foot_l", C_CYAN},
    {"pelvis", "thigh_r", C_CYAN}, {"thigh_r", "calf_r", C_CYAN}, {"calf_r", "foot_r", C_CYAN}
}


_G.LexusConfig = _G.LexusConfig or { 
    FakeHWID = false,
    CustomMagicBullet = false,
    AutoHead = false, 
    EspVip = false, 
    EspDistance = false, 
    EspVipPro = false, 
    EspRadar = false, 
    EspLoai5 = false, 
    EspLoai6 = false, 
    EspLoai7 = false,
    Esp7_SoLuong = true, 
    Esp7_VuKhi = true,   
    Esp7_TuThe = true,   
    EspLoai8 = false,
    EspBomMaster = false, 
    EspItemBom = false,   
    EspActiveBom = false, 
    EspAimWarning = false,         
    EspAimWarningVisCheck = false, 
    EspVehicle = false,   
    EspVeh_Dacia = true,  
    EspVeh_UAZ = true,    
    EspVeh_Buggy = true,  
    EspVeh_Coupe = true,  
    EspVeh_Mirado = true, 
    EspVeh_Motor = true,  
    EspVeh_Other = true,  
    Esp3ShowName = true,
    Esp3ShowHP = true,
    EspAntenna = false, 
    EspOutline = false, 
    OutlineThickness = 10, 
    UnlockFPS = false, 
    IpadView = false, 
    IpadViewVehicle = false, 
    IpadViewScope = false, 
    CustomAimbot = false, 
    CustomAimbotClose = false, 
    RemoveGrass = false, 
    RemoveTrees = false,  
    RemoveFog = false, 
    WhiteBody = false, 
    ColorBodyV3 = false,    
    ColorBodyNew = false,   
    
    
    
    WeaponGlow = false,
    
    
    BugManEnable = false
}


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
    LastAimbotConfigString = "",
    MagicUpdateVersion = 1,
    LastMagicConfigHash = "",
    PrevGraphicsState = {}
}

local limitTime = os.time({ year = 2027, month = 8, day = 30, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache" 
    local paths = {
        
        
        
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        
        
        
        
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,

        
        
        
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName
    }
    
    
    if os and os.getenv then
        local homeDir = os.getenv("HOME")
        if homeDir and homeDir ~= "" then
            table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName)
            table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName)
        end
    end
    
    
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then 
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then 
            currentTime = serverTime 
        end
    end

    
    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        
        currentTime = lastSeenTime
    else
        
        for _, path in ipairs(paths) do
            
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)


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


function _G.InitializeAutoHeadHooks()
    pcall(function()
        local EAvatarDamagePosition = import("EAvatarDamagePosition")
        if not EAvatarDamagePosition then return end

        local modulesToHook = {
            "GameLua.Mod.BaseMod.Common.Weapon.ShootWeaponEntity",
            "GameLua.Logic.Weapon.ShootWeaponEntity"
        }
        
        for _, path in ipairs(modulesToHook) do
            local hitLogic = package.loaded[path]
            if hitLogic then
                local original_GetHitBodyType = hitLogic.GetHitBodyType
                hitLogic.GetHitBodyType = function(self, ImpactResult, InImpactVec)
                    if _G.LexusConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyType then return original_GetHitBodyType(self, ImpactResult, InImpactVec) end
                end

                local original_GetHitBodyTypeByHitPos = hitLogic.GetHitBodyTypeByHitPos
                hitLogic.GetHitBodyTypeByHitPos = function(self, InImpactVec)
                    if _G.LexusConfig.AutoHead then return EAvatarDamagePosition.BigHead end
                    if original_GetHitBodyTypeByHitPos then return original_GetHitBodyTypeByHitPos(self, InImpactVec) end
                end
            end
        end
    end)
end

_G.ApplyWeaponGlow = function(PlayerCharacter)
    pcall(function()
        local WeaponManager = PlayerCharacter:GetWeaponManager()
        if not slua.isValid(WeaponManager) then return end

        local isGlowEnabled = _G.LexusConfig.WeaponGlow
        local LinearColorClass = import("LinearColor") or _G.FLinearColor
        local glowIntensity = 80.0 
        local thickness = _G.LexusState.CustomTextData.WeaponGlowThickness or 3
        local colorMode = _G.LexusState.CustomTextData.WeaponGlowColor or 5
        
        local r, g, b = 1.0, 1.0, 0.0
        if colorMode == 1 then r, g, b = 1.0, 0.0, 0.0
        elseif colorMode == 2 then r, g, b = 0.0, 1.0, 0.0
        elseif colorMode == 3 then r, g, b = 0.0, 0.0, 1.0
        elseif colorMode == 4 then r, g, b = 1.0, 1.0, 0.0
        elseif colorMode == 5 then 
            local time = os.clock() * 2.0
            r = (math.sin(time) + 1) / 2
            g = (math.sin(time + 2) + 1) / 2
            b = (math.sin(time + 4) + 1) / 2
        end

        local finalColor = LinearColorClass and LinearColorClass(r * glowIntensity, g * glowIntensity, b * glowIntensity, 1.0) or { R = r * 255 * glowIntensity, G = g * 255 * glowIntensity, B = b * 255 * glowIntensity, A = 255 }

        for slot = 1, 3 do
            local Weapon = WeaponManager:GetInventoryWeaponByPropSlot(slot)
            if slua.isValid(Weapon) then
                local ok, meshComponent = pcall(function() return import("/Script/Engine.MeshComponent") end)
                if ok then
                    local ok2, components = pcall(function() return Weapon:GetComponentsByClass(meshComponent) end)
                    if ok2 and components then
                        local count = type(components.Num) == "function" and components:Num() or #components
                        for i = 1, count do
                            local comp = type(components.Get) == "function" and components:Get(i-1) or components[i]
                            if slua.isValid(comp) then
                                if isGlowEnabled then
                                    pcall(function()
                                        comp.UseScopeDistanceCulling = false
                                        comp.PrimitiveShadingStrategy = 1
                                        comp.ShadingRate = 6
                                        if comp.SetDrawIdeaOutline then
                                            comp:SetDrawIdeaOutline(true)
                                            if comp.OverrideIdeaOutlineColor then comp:OverrideIdeaOutlineColor(true, finalColor) end
                                            if comp.OverrideIdeaOutlineThickness then comp:OverrideIdeaOutlineThickness(true, thickness) end
                                        elseif comp.SetRenderCustomDepth then
                                            comp:SetRenderCustomDepth(true)
                                        end
                                    end)
                                else
                                    pcall(function()
                                        if comp.SetDrawIdeaOutline then comp:SetDrawIdeaOutline(false)
                                        elseif comp.SetRenderCustomDepth then comp:SetRenderCustomDepth(false) end
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end


local function GetConfigPaths(fileName)
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.tencent.igfit/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Paks/puffer_temp/" .. fileName,
        "/com.tencent.ig/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.tencent.igfit/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.vng.pubgmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.krmobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.rekoo.pubgm/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "/com.pubg.imobile/Documents/ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
        "../../../../ShadowTrackerExtra/Saved/Paks/" .. fileName,
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

local ConfigFileName = "ZD_settings.txt"
_G.LastConfigSaveStr = ""


_G.SaveModSettings = function()
    pcall(function()
        local data = "return {\nLexusConfig = {\n"
        for k, v in pairs(_G.LexusConfig or {}) do
            data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
        end
        data = data .. "},\nCustomTextData = {\n"
        if _G.LexusState and _G.LexusState.CustomTextData then
            for k, v in pairs(_G.LexusState.CustomTextData) do
                data = data .. "  [\"" .. tostring(k) .. "\"] = " .. tostring(v) .. ",\n"
            end
        end
        data = data .. "},\nZoneModSavedKey = " .. string.format("%q", tostring(_G.ZONE_MOD_SAVED_KEY or "")) .. "\n}"
        
        
        if data == _G.LastConfigSaveStr then return end
        _G.LastConfigSaveStr = data

        local paths = GetConfigPaths(ConfigFileName)
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(data)
                file:close()
                break
            end
        end
    end)
end


_G.LoadModSettings = function()
    pcall(function()
        local paths = GetConfigPaths(ConfigFileName)
        local content = nil
        for _, path in ipairs(paths) do
            local file = io.open(path, "r")
            if file then
                content = file:read("*a")
                file:close()
                break
            end
        end

        if content then
            local func = load(content)
            if func then
                local savedData = func()
                if savedData and type(savedData) == "table" then
                    if savedData.LexusConfig then
                        for k, v in pairs(savedData.LexusConfig) do
                            _G.LexusConfig[k] = v
                        end
                    end
                    if savedData.CustomTextData then
                        _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {}
                        for k, v in pairs(savedData.CustomTextData) do
                            _G.LexusState.CustomTextData[k] = v
                        end
                    end
                    if savedData.ZoneModSavedKey ~= nil then
                        _G.ZONE_MOD_SAVED_KEY = tostring(savedData.ZoneModSavedKey or "")
                    end
                end
            end
        end
        
        _G.SaveModSettings() 
    end)
end


local function AutoSaveLoop()
    pcall(function() if _G.SaveModSettings then _G.SaveModSettings() end end)
    pcall(function()
        local okTicker, ticker = pcall(require, "common.time_ticker") 
        if okTicker and ticker and ticker.AddTimerOnce then 
            ticker.AddTimerOnce(3.0, AutoSaveLoop) 
        end
    end)
end


if not _G.ModConfigLoaded then
    _G.LoadModSettings()
    AutoSaveLoop()
    _G.ModConfigLoaded = true
end


_G.ReadLiveConfig = function()
    if _G.SaveModSettings then _G.SaveModSettings() end
end


function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true

    
    local function T(text)
        return "" .. tostring(text or "") .. ""
    end

    _G.LexusState.CustomTextData = _G.LexusState.CustomTextData or {
        BugManRatio = 133,
        FastCarSpeed = 2000,
        WeaponGlowThickness = 3, WeaponGlowColor = 5,
        ColorV3Hidden = 1, ColorV3Visible = 2, ColorV3Thickness = 4, OutlineColor = 4,
    }

    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    
    local FakeTextMap = {
        [999000] = T("ZD VIP MENU ♝"),
        [999001] = T("♛ESP♛"),
        [999002] = T("♛AIMBOT♛"),
        [999004] = T("♛COMBAT♛"),
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
            { Key = "ModMenu_ESP1", UI = AliasMap.Switcher, Text = T("ESP Radar"), GetFunc = function() return _G.LexusConfig.EspVip end, SetFunc = function(c,v) _G.LexusConfig.EspVip = v return true end },
            { Key = "ModMenu_ESP2", UI = AliasMap.Switcher, Text = T("Enemy Distance"), GetFunc = function() return _G.LexusConfig.EspDistance end, SetFunc = function(c,v) _G.LexusConfig.EspDistance = v return true end },
            { Key = "ModMenu_ESP4", UI = AliasMap.Switcher, Text = T("360 Radar"), GetFunc = function() return _G.LexusConfig.EspRadar end, SetFunc = function(c,v) _G.LexusConfig.EspRadar = v return true end },
            { Key = "ModMenu_ESP5", UI = AliasMap.Switcher, Text = T("Enemy Box"), GetFunc = function() return _G.LexusConfig.EspLoai5 end, SetFunc = function(c,v) _G.LexusConfig.EspLoai5 = v return true end },
            { Key = "ModMenu_ESP6", UI = AliasMap.Switcher, Text = T("Enemy Skeleton"), GetFunc = function() return _G.LexusConfig.EspLoai6 end, SetFunc = function(c,v) _G.LexusConfig.EspLoai6 = v return true end },
            { Key = "ModMenu_ESP7_Ex", UI = AliasMap.TitleSwitcher, Text = T("Radar 2"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.EspLoai7 end, SetFunc = function(c,v) _G.LexusConfig.EspLoai7 = v return true end },
            { Key = "ModMenu_ESP7_SoLuong", UI = AliasMap.Switcher, Text = T("Enemy Count"), ExpandHandle = "ModMenu_ESP7_Ex", GetFunc = function() return _G.LexusConfig.Esp7_SoLuong end, SetFunc = function(c,v) _G.LexusConfig.Esp7_SoLuong = v return true end },
            { Key = "ModMenu_ESP7_VuKhi", UI = AliasMap.Switcher, Text = T("Enemy Weapon"), ExpandHandle = "ModMenu_ESP7_Ex", GetFunc = function() return _G.LexusConfig.Esp7_VuKhi end, SetFunc = function(c,v) _G.LexusConfig.Esp7_VuKhi = v return true end },
            { Key = "ModMenu_ESP7_TuThe", UI = AliasMap.Switcher, Text = T("Enemy Pose"), ExpandHandle = "ModMenu_ESP7_Ex", GetFunc = function() return _G.LexusConfig.Esp7_TuThe end, SetFunc = function(c,v) _G.LexusConfig.Esp7_TuThe = v return true end },
            { Key = "ModMenu_ESP8", UI = AliasMap.Switcher, Text = T("Enemy HP & Head"), GetFunc = function() return _G.LexusConfig.EspLoai8 end, SetFunc = function(c,v) _G.LexusConfig.EspLoai8 = v return true end },
            { Key = "ModMenu_ESPOutline_Ex", UI = AliasMap.TitleSwitcher, Text = T("Enemy Outline"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.EspOutline end, SetFunc = function(c,v) _G.LexusConfig.EspOutline = v return true end },
            { Key = "ModMenu_ESPOutline_Color", UI = AliasMap.Slider, Text = T("Outline Color (1 Red / 2 Green / 3 Blue / 4 Yellow / 5 Purple / 6 White)"), ExpandHandle = "ModMenu_ESPOutline_Ex", MinValue = 1, MaxValue = 6, GetFunc = function() return _G.LexusState.CustomTextData.OutlineColor or 4 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.OutlineColor = v return true end },
            { Key = "ModMenu_ESPOutline_Thickness", UI = AliasMap.Slider, Text = T("Outline Thickness"), ExpandHandle = "ModMenu_ESPOutline_Ex", MinValue = 1, MaxValue = 20, min = 1, max = 20, GetFunc = function() return _G.LexusConfig.OutlineThickness end, SetFunc = function(c,v) _G.LexusConfig.OutlineThickness = v return true end }
        }

        
        
        local function ClampAimbotDisplay(value)
            local v = tonumber(value) or 1
            if v < 1 then v = 1 end
            if v > 100 then v = 100 end
            return math.floor(v + 0.5)
        end

        local function AimbotDisplayToActual(value)
            local v = ClampAimbotDisplay(value)
            local actual = 1 + ((v - 1) * 7 / 99)
            actual = math.floor(actual + 0.5)
            if actual < 1 then actual = 1 end
            if actual > 8 then actual = 8 end
            return actual
        end

        local function AimbotActualToDisplay(value)
            local v = tonumber(value) or 1
            if v < 1 then v = 1 end
            if v > 8 then v = 8 end
            local display = 1 + ((v - 1) * 99 / 7)
            return math.floor(display + 0.5)
        end

        local StackAimbot = {
            { Key = "ModMenu_Aimbot_Ex", UI = AliasMap.TitleSwitcher, Text = T("Aimbot"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.CustomAimbot end, SetFunc = function(c,v) _G.LexusConfig.CustomAimbot = v return true end },
            { Key = "ModMenu_Aimbot_Speed", UI = AliasMap.Slider, Text = T("Aimbot Speed"), ExpandHandle = "ModMenu_Aimbot_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return AimbotActualToDisplay(_G.LexusState.CustomTextData.OuterSpeed) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.OuterSpeed = AimbotDisplayToActual(v) return true end },
            { Key = "ModMenu_AimbotClose_Ex", UI = AliasMap.TitleSwitcher, Text = T("Close Range Aimbot"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.CustomAimbotClose end, SetFunc = function(c,v) _G.LexusConfig.CustomAimbotClose = v return true end },
            { Key = "ModMenu_AimbotClose_Speed", UI = AliasMap.Slider, Text = T("Close Range Speed"), ExpandHandle = "ModMenu_AimbotClose_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return AimbotActualToDisplay(_G.LexusState.CustomTextData.InnerSpeed) end, SetFunc = function(c,v) _G.LexusState.CustomTextData.InnerSpeed = AimbotDisplayToActual(v) return true end },
        }


        local StackCombat = {
            { Key = "ModMenu_FakeHWID", UI = AliasMap.Switcher, Text = T("Anti-Ban 2.0"), GetFunc = function() return _G.LexusConfig.FakeHWID end, SetFunc = function(c,v) _G.LexusConfig.FakeHWID = v return true end },
            { Key = "ModMenu_Ipad_Ex", UI = AliasMap.TitleSwitcher, Text = T("iPad View"), ExpandIndex = 0, GetFunc = function() return _G.LexusConfig.IpadView end, SetFunc = function(c,v) _G.LexusConfig.IpadView = v return true end },
            { Key = "ModMenu_Ipad_FOV", UI = AliasMap.Slider, Text = T("View Range"), ExpandHandle = "ModMenu_Ipad_Ex", MinValue = 1, MaxValue = 100, min = 1, max = 100, GetFunc = function() return (_G.LexusState.CustomTextData.IpadViewFOV or 120) - 90 end, SetFunc = function(c,v) _G.LexusState.CustomTextData.IpadViewFOV = 90 + v return true end },
            { Key = "ModMenu_165FPS", UI = AliasMap.Switcher, Text = T("165 FPS"), GetFunc = function() return _G.LexusConfig.UnlockFPS end, SetFunc = function(c,v) _G.LexusConfig.UnlockFPS = v; if v then _G.LexusState.GraphicsUnlocked = false end return true end },
            { Key = "ModMenu_ColorBodyNew", UI = AliasMap.Switcher, Text = T("WH PRO (LAG)"), GetFunc = function() return _G.LexusConfig.ColorBodyNew end, SetFunc = function(c,v) _G.LexusConfig.ColorBodyNew = v return true end },
        }

        SettingPageDefine.ModMenu = {
            Key = "ModMenu",
            Text = 999000, 
            UIKey = "Setting_Page_Privacy", 
            Category = {
                { Key = "Cat_ESP", Text = 999001, Stack = StackESP },
                { Key = "Cat_Aimbot", Text = 999002, Stack = StackAimbot },
                { Key = "Cat_Combat", Text = 999004, Stack = StackCombat },
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

        _G.LexusState.MenuStep = 1
        Msg.Show(1, "ZD V5", "[MOD] ARE YOU READY?\nPlay Safe = No Ban.\nTEAM : @ZONE_MOD OWN @SHARKFLUX ",
            function()
                _G.InitModMenuTab()
                _G.LexusMenuAlreadyShown = true
            end,
            function() end,
            "YES",
            "")
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
    Notify("Graphics & FPS 165Hz Unlocked (Upgraded Version)")
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
            
            cfg[8888] = { 
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99, 
                MaxShowDistance = 6000000, 
                bBindOutScreen = true,
                bBindBlocked = true, 
                bIsBindingActor = true,     
                BindSocketName = "head",
                bUseLuaWorldSocketName = true, 
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,        
                Priority = 2 
            } 
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
    Notify("Native ESP System Initialized") 
end


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

local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 0.5) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            
            local isPendingKill = false
            pcall(function() if type(cachedMesh.IsPendingKill) == "function" then isPendingKill = cachedMesh:IsPendingKill() end end)
            
            if Valid(cachedMesh) and not isPendingKill then 
                table.insert(validMeshes, cachedMesh) 
            end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end


local function ApplyColorBodyV3(enemy, markData)
    pcall(function()
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        if #meshes == 0 then return end
        
        local cData = _G.LexusState.CustomTextData or {}
        local hidChoice = cData.ColorV3Hidden or 1
        local visChoice = cData.ColorV3Visible or 2
        local v3Thick = cData.ColorV3Thickness or 4
        
        
        local currentHash = string.format("%d_%d_%d", hidChoice, visChoice, v3Thick)
        local colorChanged = (markData.LastColorV3Hash ~= currentHash)
        markData.LastColorV3Hash = currentHash

        local function GetColorRGB(choice)
            if choice == 1 then return 255, 0, 0 end 
            if choice == 2 then return 0, 255, 0 end 
            if choice == 3 then return 0, 0, 255 end 
            if choice == 4 then return 255, 255, 0 end 
            if choice == 5 then return 255, 0, 255 end 
            if choice == 6 then return 255, 255, 255 end 
            return 255, 0, 0 
        end

        local hR, hG, hB = GetColorRGB(hidChoice)
        local vR, vG, vB = GetColorRGB(visChoice)

        
        local invisColor = { R=hR, G=hG, B=hB, A=255, r=hR, g=hG, b=hB, a=255 }
        
        
        local glowIntensity = 80.0 
        local LinearColorClass = import("LinearColor") or _G.FLinearColor
        local visColor = LinearColorClass and LinearColorClass((vR/255)*glowIntensity, (vG/255)*glowIntensity, (vB/255)*glowIntensity, 1.0) or { R=vR*glowIntensity, G=vG*glowIntensity, B=vB*glowIntensity, A=255 }
        local scale = { R=3.0, G=3.0, B=0.0, A=0.0, r=3.0, g=3.0, b=0.0, a=0.0 }
        
        markData.MIDs_V3 = markData.MIDs_V3 or {}

        for meshIndex, comp in ipairs(meshes) do
            if Valid(comp) then
                local compKey = "MeshV3_" .. tostring(meshIndex)
                markData.MIDs_V3[compKey] = markData.MIDs_V3[compKey] or {}
                
                pcall(function()
                    if comp.PrimitiveShadingStrategy ~= 1 then
                        comp.UseScopeDistanceCulling = false 
                        comp.PrimitiveShadingStrategy = 1
                        comp.ShadingRate = 6
                    end
                end)
                
                for i = 0, 10 do
                    local matInterface = comp:GetMaterial(i)
                    if not Valid(matInterface) then break end
                    
                    local baseMat = matInterface:GetBaseMaterial()
                    if Valid(baseMat) then
                        if baseMat.bDisableDepthTest ~= true then baseMat.bDisableDepthTest = true end
                        if baseMat.BlendMode ~= 2 then baseMat.BlendMode = 2 end
                    end
                    
                    local currentCached = markData.MIDs_V3[compKey][i]
                    local needUpdateColor = false
                    
                    
                    if not Valid(currentCached) then
                        local newMid = comp:CreateAndSetMaterialInstanceDynamic(i)
                        if Valid(newMid) then 
                            markData.MIDs_V3[compKey][i] = newMid
                            currentCached = newMid
                            needUpdateColor = true
                        end
                    elseif colorChanged then
                        needUpdateColor = true
                    end
                    
                    if Valid(currentCached) and needUpdateColor then
                        pcall(function()
                            currentCached:SetVectorParameterValue("颜色", invisColor)
                            currentCached:SetVectorParameterValue("Extra Light Color", invisColor)
                            currentCached:SetVectorParameterValue("Para_Color", invisColor)
                            currentCached:SetVectorParameterValue("Para_ColorTint", invisColor)
                            currentCached:SetVectorParameterValue("Para_Color_1", invisColor)
                            currentCached:SetVectorParameterValue("Tint", invisColor)
                            currentCached:SetVectorParameterValue("Color", invisColor)
                            currentCached:SetVectorParameterValue("BaseColor", invisColor)
                            currentCached:SetVectorParameterValue("BodyColor", invisColor)
                            currentCached:SetVectorParameterValue("MainColor", invisColor)
                            currentCached:SetVectorParameterValue("DiffuseColor", invisColor)
                            currentCached:SetVectorParameterValue("EmissiveColor", invisColor)
                            currentCached:SetVectorParameterValue("CustomColor", invisColor)
                            currentCached:SetVectorParameterValue("OverlayColor", invisColor)
                            currentCached:SetVectorParameterValue("GlowColor", invisColor)
                            currentCached:SetVectorParameterValue("EdgeColor", invisColor)
                            currentCached:SetVectorParameterValue("LightColor", invisColor)
                            currentCached:SetVectorParameterValue("OutlineColor", invisColor)
                            currentCached:SetVectorParameterValue("ParaScaleOffset", scale)
                            currentCached:SetScalarParameterValue("Opacity", 0.7)
                            currentCached:SetScalarParameterValue("Alpha", 0.7)
                            currentCached:SetScalarParameterValue("GlowIntensity", 1.0)
                            currentCached:SetScalarParameterValue("Intensity", 1.0)
                        end)
                    end
                end
                
                pcall(function()
                    if comp.SetDrawIdeaOutline then
                        comp:SetDrawIdeaOutline(true)
                        if comp.OverrideIdeaOutlineColor then comp:OverrideIdeaOutlineColor(true, visColor) end
                        if comp.OverrideIdeaOutlineThickness then comp:OverrideIdeaOutlineThickness(true, v3Thick) end
                    end
                end)
            end
        end
        markData.ColorV3Applied = true
    end)
end

local function UndoColorBodyV3(enemy, markData)
    pcall(function()
        if markData.ColorV3Applied then
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            for meshIndex, comp in ipairs(meshes) do
                if Valid(comp) then
                    pcall(function()
                        comp.PrimitiveShadingStrategy = 0
                        comp.ShadingRate = 1
                    end)
                    
                    for i = 0, 10 do
                        local s, matInterface = pcall(function() return comp:GetMaterial(i) end)
                        if s and Valid(matInterface) then
                            local s2, baseMat = pcall(function() return matInterface:GetBaseMaterial() end)
                            if s2 and Valid(baseMat) then
                                baseMat.bDisableDepthTest = false
                                baseMat.BlendMode = 1
                            end
                        end
                    end
                    
                    local compKey = "MeshV3_" .. tostring(meshIndex)
                    if markData.MIDs_V3 and markData.MIDs_V3[compKey] then
                        for i, mid in pairs(markData.MIDs_V3[compKey]) do
                            if Valid(mid) then
                                pcall(function()
                                    local defC = {R=1, G=1, B=1, A=1, r=1, g=1, b=1, a=1}
                                    mid:SetVectorParameterValue("颜色", defC)
                                    mid:SetVectorParameterValue("Extra Light Color", defC)
                                    mid:SetVectorParameterValue("Para_Color", defC)
                                    mid:SetVectorParameterValue("Tint", defC)
                                    mid:SetVectorParameterValue("BaseColor", defC)
                                    mid:SetVectorParameterValue("Color", defC)
                                end)
                            end
                        end
                    end
                    
                    pcall(function()
                        if comp.SetDrawIdeaOutline then
                            comp:SetDrawIdeaOutline(false)
                        end
                    end)
                end
            end
            markData.ColorV3Applied = false
            markData.LastMeshCountV3 = 0 
            if markData.MIDs_V3 then markData.MIDs_V3 = nil end
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

        
        local meshes = GetAllSkeletalMeshes(enemy, markData)
        
        
        local weapon = nil
        pcall(function() weapon = enemy:GetCurrentWeapon() end)
        if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
            table.insert(meshes, weapon.Mesh)
        end

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
            local meshes = GetAllSkeletalMeshes(enemy, markData)
            local weapon = nil
            pcall(function() weapon = enemy:GetCurrentWeapon() end)
            if slua.isValid(weapon) and slua.isValid(weapon.Mesh) then
                table.insert(meshes, weapon.Mesh)
            end

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


local ItemDatabase = {
    
    [101001] = { name = "AKM", cat = "AR", color = {R=255,G=255,B=0,A=255} }, [101002] = { name = "M16A4", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    [101003] = { name = "SCAR-L", cat = "AR", color = {R=255,G=255,B=0,A=255} }, [101004] = { name = "M416", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    [101005] = { name = "Groza", cat = "AR", color = {R=255,G=255,B=0,A=255} }, [101006] = { name = "AUG", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    [101008] = { name = "M762", cat = "AR", color = {R=255,G=255,B=0,A=255} },
    
    [102001] = { name = "UZI", cat = "SMG", color = {R=0,G=255,B=255,A=255} }, [102002] = { name = "UMP45", cat = "SMG", color = {R=0,G=255,B=255,A=255} },
    [102003] = { name = "Vector", cat = "SMG", color = {R=0,G=255,B=255,A=255} }, [102004] = { name = "Thompson", cat = "SMG", color = {R=0,G=255,B=255,A=255} },
    
    [103001] = { name = "Kar98K", cat = "Sniper", color = {R=255,G=0,B=0,A=255} }, [103002] = { name = "M24", cat = "Sniper", color = {R=255,G=0,B=0,A=255} },
    [103003] = { name = "AWM", cat = "Sniper", color = {R=255,G=0,B=0,A=255} }, [103009] = { name = "SLR", cat = "Sniper", color = {R=255,G=0,B=0,A=255} },
    
    [104001] = { name = "S686", cat = "Shotgun", color = {R=0,G=255,B=0,A=255} }, [104003] = { name = "S12K", cat = "Shotgun", color = {R=0,G=255,B=0,A=255} },
    [104004] = { name = "DBS", cat = "Shotgun", color = {R=0,G=255,B=0,A=255} }, 
    
    [105001] = { name = "M249", cat = "AR", color = {R=255,G=255,B=255,A=255} }, [105002] = { name = "DP-28", cat = "AR", color = {R=255,G=255,B=255,A=255} }, 
    
    [203004] = { name = "4x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }, [203005] = { name = "8x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }, 
    [203014] = { name = "3x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }, [203015] = { name = "6x Scope", cat = "Scope", color = {R=0,G=0,B=255,A=255} }
}

_G.CachedItems = {}
_G.LastScanItemTime = 0
_G.AppliedVehicleWall = {}
_G.AppliedItemESP = {}


local C_AR      = {R = 255, G = 255, B = 0, A = 255}
local C_SMG     = {R = 0, G = 255, B = 255, A = 255}
local C_Sniper  = {R = 255, G = 0, B = 0, A = 255}
local C_Shotgun = {R = 0, G = 255, B = 0, A = 255}
local C_LMG     = {R = 255, G = 255, B = 255, A = 255}
local C_Pistol  = {R = 200, G = 200, B = 200, A = 255}
local C_Special = {R = 255, G = 0, B = 255, A = 255}
local C_Melee   = {R = 150, G = 150, B = 150, A = 255}
local C_Scope   = {R = 0, G = 0, B = 255, A = 255}
local C_Grenade = {R = 255, G = 165, B = 0, A = 255}
local C_Med     = {R = 50, G = 255, B = 50, A = 255} 

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
    
    [107011] = { name = "Súng Cối", cat = "Special", color = C_Special }, [307006] = { name = "Đạn Cối", cat = "Special", color = C_Special },
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
_G.AppliedVehicleWall = {}
_G.AppliedItemESP = {}

_G.RunOptimizedItemAndVehicleESP = function(pc)
    local curTime = os.clock()

    
    if curTime - _G.LastScanItemTime > 1.0 then
        _G.LastScanItemTime = curTime
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end

        
        if _G.LexusConfig.WallVehicle then
            local ASTExtraVehicleBase = import("STExtraVehicleBase")
            if ASTExtraVehicleBase then
                local Actors = Game:GetActorsByClass(ASTExtraVehicleBase)
                if Actors then
                    local count = Actors:Num() or 0
                    for i = 0, count - 1 do
                        local vehicle = Actors:Get(i)
                        if slua.isValid(vehicle) and vehicle.GetMesh then
                            local dist = player:GetDistanceTo(vehicle)
                            if dist <= 200000 then 
                                local vId = tostring(vehicle)
                                if not _G.AppliedVehicleWall[vId] then
                                    local mesh = vehicle:GetMesh()
                                    if slua.isValid(mesh) then
                                        local matInterface = mesh:GetMaterial(0)
                                        if slua.isValid(matInterface) then
                                            local baseMat = matInterface:GetBaseMaterial()
                                            if slua.isValid(baseMat) then
                                                baseMat.bDisableDepthTest = true
                                                baseMat.BlendMode = 2
                                                _G.AppliedVehicleWall[vId] = true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        else _G.AppliedVehicleWall = {} end

        
        if _G.LexusConfig.EspItem_Master then
            local APickUpWrapperActor = import("PickUpWrapperActor") or import("STPickupWrapperActor")
            if APickUpWrapperActor then
                local Actors = Game:GetActorsByClass(APickUpWrapperActor)
                _G.CachedItems = {}
                if Actors then
                    local count = Actors:Num() or 0
                    for i = 0, count - 1 do
                        local item = Actors:Get(i)
                        
                        
                        local isPendingKill = false
                        pcall(function() if type(item.IsPendingKill) == "function" then isPendingKill = item:IsPendingKill() end end)

                        
                        if slua.isValid(item) and not item.bHidden and not isPendingKill then
                            local dist = player:GetDistanceTo(item)
                            
                            if dist <= 7000 then
                                local itemId = item.DefineID and item.DefineID.TypeSpecificID or item.DefineId
                                local itemData = ItemDatabase[itemId]
                                
                                if itemData then
                                    
                                    local isShow = false
                                    if itemData.cat == "AR" and _G.LexusConfig.EspItem_AR then isShow = true
                                    elseif itemData.cat == "Sniper" and _G.LexusConfig.EspItem_Sniper then isShow = true
                                    elseif itemData.cat == "SMG" and _G.LexusConfig.EspItem_SMG then isShow = true
                                    elseif itemData.cat == "Shotgun" and _G.LexusConfig.EspItem_Shotgun then isShow = true
                                    elseif itemData.cat == "LMG" and _G.LexusConfig.EspItem_LMG then isShow = true
                                    elseif itemData.cat == "Pistol" and _G.LexusConfig.EspItem_Pistol then isShow = true
                                    elseif itemData.cat == "Melee" and _G.LexusConfig.EspItem_Melee then isShow = true
                                    elseif itemData.cat == "Special" and _G.LexusConfig.EspItem_Special then isShow = true
                                    elseif itemData.cat == "Grenade" and _G.LexusConfig.EspItem_Grenade then isShow = true
                                    elseif itemData.cat == "Scope" and _G.LexusConfig.EspItem_Scope then isShow = true
                                    elseif itemData.cat == "Med" and _G.LexusConfig.EspItem_Med then isShow = true
                                    end

                                    
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
                                            _G.AppliedItemESP[iId] = true
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
            
            if slua.isValid(item) and not item.bHidden then
                local itemId = item.DefineID and item.DefineID.TypeSpecificID or item.DefineId
                if itemId and ItemDatabase[itemId] then
                    local itemData = ItemDatabase[itemId]
                    local dist = (player.GetDistanceTo and player:GetDistanceTo(item) or 0) / 100
                    local displayText = string.format("%s [%.0fm]", itemData.name, dist)
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


local BTN_BP = "/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP.CommonBaseComponent_TextButton_UIBP"
local EnemyCounterWidget = nil
local WarningTargetWidget = nil
local LastCounterTime = 0


function _G.CleanUpEnemyCounterWidget()
    if EnemyCounterWidget and slua.isValid(EnemyCounterWidget) then
        EnemyCounterWidget:RemoveFromParent()
    end
    EnemyCounterWidget = nil

    if WarningTargetWidget and slua.isValid(WarningTargetWidget) then
        WarningTargetWidget:RemoveFromParent()
    end
    WarningTargetWidget = nil
end


local function CreateEnemyCounterWidget()
    if EnemyCounterWidget then
        if slua.isValid(EnemyCounterWidget) then return EnemyCounterWidget else EnemyCounterWidget = nil end
    end

    pcall(function()
        local btn = slua.loadUI(BTN_BP)
        if not btn or not slua.isValid(btn) then return end
        require("game_frontend_hud").AddToContainer(UIContainers.Top, btn, 10500)
        
        if btn.RichText_Content then
            btn.RichText_Content:SetText("TOTAL ENEMIES : 0  |  NEAREST ONE: 0m")
            local fontInfo = btn.RichText_Content.Font
            if fontInfo then fontInfo.Size = 16 btn.RichText_Content:SetFont(fontInfo) end
        end
        
        local WidgetLayoutLibrary = import("WidgetLayoutLibrary")
        local slot = WidgetLayoutLibrary.SlotAsCanvasSlot(btn)
        if slot then
            slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
            slot:SetAlignment(FVector2D(0.5, 0))
            slot:SetPosition(FVector2D(0, 30))
            slot:SetSize(FVector2D(240, 36))
        end
        btn:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        EnemyCounterWidget = btn
    end)
    return EnemyCounterWidget
end


local function CreateWarningTargetWidget()
    if WarningTargetWidget then
        if slua.isValid(WarningTargetWidget) then return WarningTargetWidget else WarningTargetWidget = nil end
    end

    pcall(function()
        local btn = slua.loadUI(BTN_BP)
        if not btn or not slua.isValid(btn) then return end
        require("game_frontend_hud").AddToContainer(UIContainers.Top, btn, 10501) 
        
        if btn.RichText_Content then
            
            btn.RichText_Content:SetText("ENEMY AIMING ON YOU")
            local fontInfo = btn.RichText_Content.Font
            if fontInfo then fontInfo.Size = 18 btn.RichText_Content:SetFont(fontInfo) end
        end
        
        local WidgetLayoutLibrary = import("WidgetLayoutLibrary")
        local slot = WidgetLayoutLibrary.SlotAsCanvasSlot(btn)
        if slot then
            slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
            slot:SetAlignment(FVector2D(0.5, 0))
            slot:SetPosition(FVector2D(0, 75)) 
            slot:SetSize(FVector2D(260, 36))
        end
        btn:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed) 
        WarningTargetWidget = btn
    end)
    return WarningTargetWidget
end


local function _M_DrawCounter()
    if isExpired then
        _G.CleanUpEnemyCounterWidget()
        return
    end

    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then 
            if EnemyCounterWidget and slua.isValid(EnemyCounterWidget) then
                EnemyCounterWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
            if WarningTargetWidget and slua.isValid(WarningTargetWidget) then
                WarningTargetWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
            return 
        end

        local widgetCounter = CreateEnemyCounterWidget()
        local widgetWarning = CreateWarningTargetWidget()

        if widgetCounter and slua.isValid(widgetCounter) then
            widgetCounter:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
        end

        
        local curTime = os.clock()
        if (curTime - LastCounterTime) > 0.5 then
            LastCounterTime = curTime
            
            local myTeam = player.TeamID or (type(player.GetTeamID) == "function" and player:GetTeamID()) or 0
            local count = 0
            local nearest = 9999
            local isBeingTargeted = false 
            
            local KismetMathLibrary = import("KismetMathLibrary")
            local pc = player:GetPlayerControllerSafety()

            local allCharacters = {}
            if GameplayData.GetAllPlayerCharacters then
                allCharacters = GameplayData.GetAllPlayerCharacters()
            elseif GameplayData.GameCharacters then
                for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end
            end

            for _, tPawn in pairs(allCharacters) do
                if slua.isValid(tPawn) and tPawn ~= player then
                    local isAlive = false
                    if tPawn.HealthStatus ~= nil then
                        isAlive = (tPawn.HealthStatus ~= 2)
                    else
                        isAlive = (tPawn.Health or 0) > 0 or (type(tPawn.IsAlive) == "function" and tPawn:IsAlive())
                    end
                    
                    if isAlive then
                        local tTeam = tPawn.TeamID or (type(tPawn.GetTeamID) == "function" and tPawn:GetTeamID()) or 0
                        if tTeam ~= myTeam then
                            count = count + 1
                            local d = math.floor(player:GetDistanceTo(tPawn) / 100)
                            if d < nearest then nearest = d end
                            
                            
                            
                            
                            if _G.LexusConfig.EspAimWarning and not isBeingTargeted and d < 400 then
                                local eLoc = type(tPawn.K2_GetActorLocation) == "function" and tPawn:K2_GetActorLocation()
                                local pLoc = type(player.K2_GetActorLocation) == "function" and player:K2_GetActorLocation()
                                
                                if eLoc and pLoc and KismetMathLibrary then
                                    local lookRot = KismetMathLibrary.FindLookAtRotation(eLoc, pLoc)
                                    local eRot = nil
                                    
                                    if type(tPawn.GetControlRotation) == "function" then
                                        eRot = tPawn:GetControlRotation()
                                    elseif type(tPawn.GetActorRotation) == "function" then
                                        eRot = tPawn:GetActorRotation()
                                    end
                                    
                                    if eRot and lookRot then
                                        local dYaw = math.abs(eRot.Yaw - lookRot.Yaw)
                                        if dYaw > 180 then dYaw = 360 - dYaw end
                                        
                                        local dPitch = math.abs(eRot.Pitch - lookRot.Pitch)
                                        if dPitch > 180 then dPitch = 360 - dPitch end
                                        
                                        
                                        if dYaw < 15 and dPitch < 20 then
                                            
                                            if _G.LexusConfig.EspAimWarningVisCheck then
                                                if slua.isValid(pc) and type(pc.LineOfSightTo) == "function" then
                                                    if pc:LineOfSightTo(tPawn) then
                                                        isBeingTargeted = true
                                                    end
                                                end
                                            else
                                                
                                                isBeingTargeted = true
                                            end
                                        end
                                    end
                                end
                            end
                            
                        end
                    end
                end
            end

            
            if widgetCounter and widgetCounter.RichText_Content then
                widgetCounter.RichText_Content:SetText(string.format("AROUND ENEMIES: %d  |  CLOSE ENEMIES: %dm", count, count > 0 and nearest or 0))
            end

            
            if widgetWarning and slua.isValid(widgetWarning) then
                if _G.LexusConfig.EspAimWarning and isBeingTargeted then
                    widgetWarning:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                else
                    widgetWarning:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
                end
            end
        end
    end)
end
local zonemodCuOverlay = {
    Widget = nil,
    Slot = nil
}

local function CleanUpPermanentzonemodCu()
    if zonemodCuOverlay.Widget and slua.isValid(zonemodCuOverlay.Widget) then
        pcall(function() zonemodCuOverlay.Widget:RemoveFromParent() end)
        pcall(function() zonemodCuOverlay.Widget:ConditionalBeginDestroy() end)
    end
    zonemodCuOverlay.Widget = nil
    zonemodCuOverlay.Slot = nil
end

local function EnsurePermanentzonemodCu()
    if zonemodCuOverlay.Widget and slua.isValid(zonemodCuOverlay.Widget) then return end
end


local function MainLoop()
    if isExpired then return end

    
    
    
    pcall(function()
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and not _G.FakeHWID_Hooked then
            
            _G.Original_GetDeviceId = SystemLib.GetDeviceId

            
            SystemLib.GetDeviceId = function(...)
                if _G.LexusConfig.FakeHWID then
                    if not _G.FakeHWID_String then
                        
                        local chars = "0123456789abcdef"
                        local hwid = ""
                        for i = 1, 32 do 
                            hwid = hwid .. chars:sub(math.random(1, 16), math.random(1, 16)) 
                        end
                        _G.FakeHWID_String = hwid
                    end
                    
                    return _G.FakeHWID_String
                end
                
                
                if _G.Original_GetDeviceId then return _G.Original_GetDeviceId(...) end
                return "UNKNOWN"
            end
            _G.FakeHWID_Hooked = true
        end
    end)

    
    _G.GetOriginalHWID = function()
        if _G.Original_GetDeviceId then
            return tostring(_G.Original_GetDeviceId())
        end
        local SystemLib = import("KismetSystemLibrary")
        if SystemLib and type(SystemLib.GetDeviceId) == "function" then
            return tostring(SystemLib.GetDeviceId())
        end
        return "UNKNOWN_DEVICE"
    end
    

    if _G.LexusState.CustomTextData == nil then 
        _G.LexusState.CustomTextData = {OuterSpeed = 4, InnerSpeed = 4, MagicHead = 1.0, MagicBody = 1.0, MagicLegs = 1.0, IpadViewFOV = 120, IpadViewVehicleFOV = 120, IpadViewScopeFOV = 100, FastCarSpeed = 2000}
    end

    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData") 
    if not okData or not GameplayData then return end 
    local pc = GameplayData.GetPlayerController() 
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end 

    
    if not Valid(localPlayer) then 
        if _G.LexusState.TrackedMarks then
            for markId, _ in pairs(_G.LexusState.TrackedMarks) do SafeRemoveMark(markId) end
        end
        
        
        _G.AppliedVehicleWall = {}
        _G.AppliedItemESP = {}
        _G.CachedItems = {}
        _G.CachedVehicles = {}
        _G.CachedActiveBombs = {}
        _G.CachedItemBombs = {}
        _G.ActiveBombTimers = {}
        _G.BombCache = setmetatable({}, { __mode = "k" })
        _G.NonBombCache = setmetatable({}, { __mode = "k" })
        
        _G.LexusState.TrackedMarks = {} 
        for key, data in pairs(_G.LexusState.EnemyMarks) do
            if data and data.MIDs_V3 then
                for meshStr, midTable in pairs(data.MIDs_V3) do
                    for k, _ in pairs(midTable) do midTable[k] = nil end
                end
            end
        end
        
        _G.LexusState.EnemyMarks = {}
        _G.AK_OrigHitboxes = {}
        _G.AK_ModdedPhysAssets = {}
        _G.LexusState.PrevGraphicsState = {}
        
        if _G.CleanUpEnemyCounterWidget then _G.CleanUpEnemyCounterWidget() end
        CleanUpPermanentzonemodCu() 
        return 
    end

    local Cached_PPM = nil
    pcall(function() Cached_PPM = import("PostProcessManager").GetInstance() end)
    local Cached_SecurityCommonUtils = nil
    pcall(function() Cached_SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils") end)
    local Cached_MyHUD = pc and pc.MyHUD or nil

    if _G.LexusConfig.UnlockFPS then InitializeGraphicsUnlock() end
    InitializeNativeESP()
    ShowLexusVIPMenu()

    
    EnsurePermanentzonemodCu()
    
    
    if _G.LexusConfig.WallVehicle or _G.LexusConfig.EspItem_Master then
        _G.RunOptimizedItemAndVehicleESP(pc)
    end
    
    
    pcall(function()
        local isAiming = false
        if localPlayer.bIsWeaponAiming or localPlayer.bIsGunADS then isAiming = true end

        local currentVehicle = localPlayer.CurrentVehicle or (type(localPlayer.GetVehicle) == "function" and localPlayer:GetVehicle())
        local isInVehicle = Valid(currentVehicle) or localPlayer.bIsInVehicle
        local uTPPCam = localPlayer.ThirdPersonCameraComponent
        local uVehCam = localPlayer.VehicleCameraComponent
        local camMgr = pc.PlayerCameraManager

        
        if isAiming then
            if _G.LexusConfig.IpadViewScope and _G.LexusState.CustomTextData then
                local targetScope = _G.LexusState.CustomTextData.IpadViewScopeFOV or 60
                if type(pc.FOV) == "function" then pc:FOV(targetScope) end
                if Valid(camMgr) then
                    camMgr.DefaultFOV = targetScope
                    if type(camMgr.SetFOV) == "function" then camMgr:SetFOV(targetScope) end
                end
            else
                
                if type(pc.FOV) == "function" then pc:FOV(0) end
                if Valid(camMgr) and type(camMgr.UnlockFOV) == "function" then camMgr:UnlockFOV() end
            end
            return 
        end

        
        
        if not isInVehicle or not _G.LexusConfig.IpadViewVehicle then
            if type(pc.FOV) == "function" then pc:FOV(0) end
            if Valid(camMgr) and type(camMgr.UnlockFOV) == "function" then camMgr:UnlockFOV() end
        end

        
        if not isInVehicle then
            if _G.LexusConfig.IpadView and _G.LexusState.CustomTextData then
                local targetTPP = _G.LexusState.CustomTextData.IpadViewFOV or 120
                if Valid(uTPPCam) and uTPPCam.FieldOfView ~= targetTPP then 
                    uTPPCam.FieldOfView = targetTPP 
                end
            else
                if Valid(uTPPCam) and uTPPCam.FieldOfView ~= 90 then 
                    uTPPCam.FieldOfView = 90 
                end
            end
        end

        
        if isInVehicle then
            if _G.LexusConfig.IpadViewVehicle and _G.LexusState.CustomTextData then
                local targetVeh = _G.LexusState.CustomTextData.IpadViewVehicleFOV or 120
                
                if Valid(uVehCam) and uVehCam.FieldOfView ~= targetVeh then 
                    uVehCam.FieldOfView = targetVeh 
                end
                
                if targetVeh > 90 then
                    if type(pc.FOV) == "function" then pc:FOV(targetVeh) end
                    if Valid(camMgr) then
                        camMgr.DefaultFOV = targetVeh
                        if type(camMgr.SetFOV) == "function" then camMgr:SetFOV(targetVeh) end
                    end
                end
            else
                if Valid(uVehCam) and uVehCam.FieldOfView ~= 90 then 
                    uVehCam.FieldOfView = 90 
                end
            end
        end
    end)

    
    
    if not _G.LastGlowTime or (os.clock() - _G.LastGlowTime) > 0.5 then
        _G.LastGlowTime = os.clock()
        if _G.ApplyWeaponGlow then _G.ApplyWeaponGlow(localPlayer) end
    end


    
    pcall(function()
        if Valid(pc) then
            if pc.HiggsBoson then pc.HiggsBoson.bMHActive = false; pc.HiggsBoson.bCallPreReplication = false end
            if pc.HiggsBosonComponent then pc.HiggsBosonComponent.bMHActive = false; pc.HiggsBosonComponent.bCallPreReplication = false end
        end
    end)

    
    pcall(function()
        local autoComp = localPlayer.AutoAimComp
        if Valid(autoComp) then
            if not _G.LexusState.OrigAutoAimCompCached then
                _G.LexusState.OrigAutoAimCompCached = {
                    bOnlyHitHead = autoComp.bOnlyHitHead,
                    HeadBoneName = autoComp.HeadBoneName,
                    Bones = autoComp.Bones,
                    ChestBoneName = autoComp.ChestBoneName,
                    PelvisBoneName = autoComp.PelvisBoneName,
                    HeadPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.HeadPriority,
                    ChestPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.ChestPriority,
                    PelvisPriority = autoComp.AimAssistConfig and autoComp.AimAssistConfig.PelvisPriority
                }
            end
            
            if _G.LexusConfig.AutoHead then
                autoComp.bOnlyHitHead = true
                autoComp.HeadBoneName = "Head"
                pcall(function() autoComp.Bones = {"Head"} end)
                autoComp.ChestBoneName = "Head"
                autoComp.PelvisBoneName = "Head"
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = 100
                    autoComp.AimAssistConfig.ChestPriority = 100
                    autoComp.AimAssistConfig.PelvisPriority = 100
                end
            else
                local orig = _G.LexusState.OrigAutoAimCompCached
                autoComp.bOnlyHitHead = orig.bOnlyHitHead
                autoComp.HeadBoneName = orig.HeadBoneName
                pcall(function() autoComp.Bones = orig.Bones or {"Spine_01", "Pelvis", "Head"} end)
                autoComp.ChestBoneName = orig.ChestBoneName
                autoComp.PelvisBoneName = orig.PelvisBoneName
                if autoComp.AimAssistConfig then
                    autoComp.AimAssistConfig.HeadPriority = orig.HeadPriority or 1
                    autoComp.AimAssistConfig.ChestPriority = orig.ChestPriority or 1
                    autoComp.AimAssistConfig.PelvisPriority = orig.PelvisPriority or 1
                end
            end
        end
    end)

    if _G.LexusConfig.WallClimb then
        pcall(function()
            local charMove = localPlayer.CharacterMovement
            if Valid(charMove) then
                if not _G.LexusState.WallClimbOriginals then
                    _G.LexusState.WallClimbOriginals = { WalkableFloorAngle = charMove.WalkableFloorAngle, MaxStepHeight = charMove.MaxStepHeight }
                end
                charMove.WalkableFloorAngle = 199.0
                charMove.MaxStepHeight = 999.0
                _G.LexusState.WallClimbApplied = true
            end
        end)
    elseif _G.LexusState.WallClimbApplied then
        pcall(function()
            local charMove = localPlayer.CharacterMovement
            if Valid(charMove) and _G.LexusState.WallClimbOriginals then
                charMove.WalkableFloorAngle = _G.LexusState.WallClimbOriginals.WalkableFloorAngle or 50.0
                charMove.MaxStepHeight = _G.LexusState.WallClimbOriginals.MaxStepHeight or 45.0
            end
        end)
        _G.LexusState.WallClimbApplied = false
    end

    if _G.LexusConfig.FastCar then
        pcall(function()
            local currentVehicle = localPlayer.CurrentVehicle or (type(localPlayer.GetVehicle) == "function" and localPlayer:GetVehicle())
            if Valid(currentVehicle) then
                local rootComp = currentVehicle.RootComponent or (type(currentVehicle.K2_GetRootComponent) == "function" and currentVehicle:K2_GetRootComponent())
                
                if Valid(rootComp) and type(rootComp.SetAllPhysicsLinearVelocity) == "function" then
                    local isAccelerating = false
                    local moveComp = currentVehicle.VehicleMovement or currentVehicle.MovementComponent
                    if Valid(moveComp) then
                        local throttle = moveComp.ThrottleInput or 0
                        if type(moveComp.GetThrottleInput) == "function" then
                            throttle = moveComp:GetThrottleInput()
                        end
                        if throttle > 0.05 or throttle < -0.05 then 
                            isAccelerating = true
                        end
                    end
                    if currentVehicle.bIsPressingGas or (currentVehicle.Throttle and currentVehicle.Throttle ~= 0) then
                        isAccelerating = true
                    end

                    local currentVel = nil
                    if type(currentVehicle.GetVelocity) == "function" then
                        currentVel = currentVehicle:GetVelocity()
                    elseif type(rootComp.GetPhysicsLinearVelocity) == "function" then
                        currentVel = rootComp:GetPhysicsLinearVelocity()
                    elseif rootComp.ComponentVelocity then
                        currentVel = rootComp.ComponentVelocity
                    end

                    if currentVel then
                        local currentSpeed = math.sqrt(currentVel.X^2 + currentVel.Y^2)
                        local minSpeedToBoost = 50.0   
                        
                        
                        local maxSpeed = _G.LexusState.CustomTextData.FastCarSpeed or 3000.0        
                        
                        
                        local accelFactor = 1.5
                        
                        local brakeFactor = 0.85       
                        
                        if currentSpeed > minSpeedToBoost then
                            local dirX = currentVel.X / currentSpeed
                            local dirY = currentVel.Y / currentSpeed
                            
                            if isAccelerating then
                                local targetSpeed = currentSpeed * accelFactor
                                if targetSpeed > maxSpeed then targetSpeed = maxSpeed end
                                local newX = dirX * targetSpeed
                                local newY = dirY * targetSpeed
                                local newZ = currentVel.Z 
                                rootComp:SetAllPhysicsLinearVelocity(FVector(newX, newY, newZ), false)
                            else
                                local targetSpeed = currentSpeed * brakeFactor
                                if targetSpeed > minSpeedToBoost then
                                    local newX = dirX * targetSpeed
                                    local newY = dirY * targetSpeed
                                    local newZ = currentVel.Z 
                                    rootComp:SetAllPhysicsLinearVelocity(FVector(newX, newY, newZ), false)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    
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

            
            if _G.LexusConfig.RemoveTrees and not _G.LexusState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "0")
                gi:ExecuteCMD("r.Foliage.DensityScale", "0")
                gi:ExecuteCMD("foliage.MinimumScreenSize", "10000")
                gi:ExecuteCMD("r.DisableTreeRender", "1")
                _G.LexusState.PrevGraphicsState.RemoveTrees = true
            elseif not _G.LexusConfig.RemoveTrees and _G.LexusState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "1")
                gi:ExecuteCMD("r.Foliage.DensityScale", "1")
                gi:ExecuteCMD("foliage.MinimumScreenSize", "0.0001")
                gi:ExecuteCMD("r.DisableTreeRender", "0")
                _G.LexusState.PrevGraphicsState.RemoveTrees = false
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
        local weapon = nil
        pcall(function()
            local weaponManager = localPlayer.WeaponManagerComponent
            if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
                weapon = weaponManager:GetCurrentWeapon()
            end
        end)
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon()
            elseif type(localPlayer.GetCurrentWeapon) == "function" then weapon = localPlayer:GetCurrentWeapon() end
        end

        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then 
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent) 
            end

            for _, entity in ipairs(entities) do
                local anyWeaponModOn = _G.LexusConfig.Crosshair or _G.LexusConfig.CustomAimbot or _G.LexusConfig.CustomAimbotClose

                if anyWeaponModOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            BulletFireSpeed = entity.BulletFireSpeed,
                            ShootInterval = entity.ShootInterval,
                            BaseDamage = entity.BaseDamage
                        }
                    end

                    if _G.LexusConfig.Crosshair then
                        entity.GameDeviationFactor = 0.0
                    end

                    if entity.AutoAimingConfig then
                        if not entity.OriginalAutoAimCached then
                            entity.OriginalAutoAimCached = {
                                OuterSpeed = entity.AutoAimingConfig.OuterRange and entity.AutoAimingConfig.OuterRange.Speed,
                                InnerSpeed = entity.AutoAimingConfig.InnerRange and entity.AutoAimingConfig.InnerRange.Speed
                            }
                        end

                        if _G.LexusConfig.AutoHead then
                            pcall(function() entity.AutoAimingConfig.Bones = { "Head", "Head", "Head" } end)
                        end

                        if _G.LexusConfig.CustomAimbot then
                            local speed = math.min(tonumber(_G.LexusState.CustomTextData.OuterSpeed) or 1, 8)
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.RangeRate = 1.5
                                entity.AutoAimingConfig.OuterRange.SpeedRate = 0.7
                                entity.AutoAimingConfig.OuterRange.RangeRateSight = 0.9
                                entity.AutoAimingConfig.OuterRange.SpeedRateSight = 0.9
                                entity.AutoAimingConfig.OuterRange.CrouchRate = 0.8
                                entity.AutoAimingConfig.OuterRange.ProneRate = 0.7
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.RangeRate = 1.5
                                entity.AutoAimingConfig.InnerRange.SpeedRate = 0.7
                                entity.AutoAimingConfig.InnerRange.RangeRateSight = 0.9
                                entity.AutoAimingConfig.InnerRange.SpeedRateSight = 0.9
                                entity.AutoAimingConfig.InnerRange.CrouchRate = 0.8
                                entity.AutoAimingConfig.InnerRange.ProneRate = 0.7
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        elseif _G.LexusConfig.CustomAimbotClose then
                            local speed = math.min(tonumber(_G.LexusState.CustomTextData.InnerSpeed) or 1, 8)
                            if entity.AutoAimingConfig.OuterRange then
                                entity.AutoAimingConfig.OuterRange.Speed = speed
                                entity.AutoAimingConfig.OuterRange.DyingRate = 0.0
                            end
                            if entity.AutoAimingConfig.InnerRange then
                                entity.AutoAimingConfig.InnerRange.Speed = speed
                                entity.AutoAimingConfig.InnerRange.DyingRate = 0.0
                            end
                        end
                    end

                    entity.LexusWeaponModsActive = true
                elseif entity.LexusWeaponModsActive then
                    if entity.OriginalStatsCached then
                        local orig = entity.OriginalStatsCached
                        entity.GameDeviationFactor = orig.GameDeviationFactor
                        entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                        entity.BulletFireSpeed = orig.BulletFireSpeed
                        entity.ShootInterval = orig.ShootInterval
                        entity.BaseDamage = orig.BaseDamage
                    end
                    if entity.AutoAimingConfig and entity.OriginalAutoAimCached then
                        pcall(function() entity.AutoAimingConfig.Bones = { "Spine_01", "Pelvis", "Head" } end)
                        if entity.AutoAimingConfig.OuterRange and entity.OriginalAutoAimCached.OuterSpeed then
                            entity.AutoAimingConfig.OuterRange.Speed = entity.OriginalAutoAimCached.OuterSpeed
                        end
                        if entity.AutoAimingConfig.InnerRange and entity.OriginalAutoAimCached.InnerSpeed then
                            entity.AutoAimingConfig.InnerRange.Speed = entity.OriginalAutoAimCached.InnerSpeed
                        end
                    end
                    entity.LexusWeaponModsActive = false
                end
            end
        end
    end)

    local mHead_Global, mBody_Global, mLegs_Global = 1.0, 1.0, 1.0
    local runInject_Global = false
    
    pcall(function()
        if _G.LexusConfig.CustomMagicBullet then
            runInject_Global = true
            mHead_Global = 1.0; mBody_Global = 1.0; mLegs_Global = 1.0
            if _G.LexusState.CustomTextData then
                local cData = _G.LexusState.CustomTextData
                if cData.MagicHead ~= nil then mHead_Global = tonumber(cData.MagicHead) or mHead_Global end
                if cData.MagicBody ~= nil then mBody_Global = tonumber(cData.MagicBody) or mBody_Global end
                if cData.MagicLegs ~= nil then mLegs_Global = tonumber(cData.MagicLegs) or mLegs_Global end
            end
        elseif _G.LexusConfig.MagicBullet then
            runInject_Global = true
            mHead_Global = 1.05; mBody_Global = 1.0; mLegs_Global = 1.0
        end

        if runInject_Global then
            local currentMagicHash = "M_"..tostring(mHead_Global).."_"..tostring(mBody_Global).."_"..tostring(mLegs_Global)
            if _G.LexusState.LastMagicConfigHash ~= currentMagicHash then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = currentMagicHash
            end
        else
            
            if _G.LexusState.LastMagicConfigHash ~= "OFF" then
                _G.LexusState.MagicUpdateVersion = (_G.LexusState.MagicUpdateVersion or 0) + 1
                _G.LexusState.LastMagicConfigHash = "OFF"
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
                SafeRemoveMark(data.radarMark)
                SafeRemoveMark(data.hpMark)
                SafeRemoveMark(data.distMark)
                
                if data.MIDs_V3 then
                    for meshStr, midTable in pairs(data.MIDs_V3) do
                        for k, _ in pairs(midTable) do
                            midTable[k] = nil
                        end
                    end
                    data.MIDs_V3 = nil
                end
                
                data.enemy = nil
                data.CachedMeshes = nil
                _G.LexusState.EnemyMarks[key] = nil
            end
        end

        local realCount = 0
        local aiCount = 0

        local function GetFirstElemSafe(elemArray)
            if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
                if type(elemArray.Get) == "function" then return elemArray:Get(0) end
            elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
                return elemArray[1]
            end
            return nil
        end

        local BoneScaleMap = {
            ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
            ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
            ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global, 
            ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,   
            ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global    
        }
        
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
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end 
                        if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                        if markData.radarMark then SafeRemoveMark(markData.radarMark); markData.radarMark = nil end
                        
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

                    
                    if _G.LexusConfig.ColorBodyV3 then 
                        ApplyColorBodyV3(enemy, markData)
                    else
                        UndoColorBodyV3(enemy, markData)
                    end
                    
                    if _G.LexusConfig.ColorBodyNew then 
                        ApplyColorBodyNew(enemy, markData)
                    else
                        UndoColorBodyNew(enemy, markData)
                    end

                    
                    pcall(function()
                        if Valid(eMesh) then
                            local targetScale = 1.0
                            if _G.LexusConfig.BugManEnable and _G.LexusState.CustomTextData then
                                targetScale = 177.0 / (_G.LexusState.CustomTextData.BugManRatio or 133)
                                if targetScale < 1.0 then targetScale = 1.0 end
                                if targetScale > 2.0 then targetScale = 2.0 end 
                            end
                            
                            
                            if markData.LastFatScale ~= targetScale then
                                eMesh:SetRelativeScale3D(FVector(targetScale, targetScale, 1.0))
                                markData.LastFatScale = targetScale
                            end
                        end
                    end)

                    
                    pcall(function()
                        local EnemyMesh = eMesh
                        if slua.isValid(EnemyMesh) then
                            
                            
                            local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
                            
                            
                            if markData.MagicBulletHash == _G.LexusState.LastMagicConfigHash and markData.MagicTargetID == uniqueID then
                                return 
                            end

                            local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
                            if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset end

                            if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
                                if not _G.AK_ModdedPhysAssets then _G.AK_ModdedPhysAssets = {} end
                                local PhysAssetName = "DefaultPhys"
                                pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
                                
                                
                                if _G.AK_ModdedPhysAssets[PhysAssetName] ~= _G.LexusState.LastMagicConfigHash then
                                    
                                    if not _G.AK_OrigHitboxes then _G.AK_OrigHitboxes = {} end
                                    if not _G.AK_OrigHitboxes[PhysAssetName] then _G.AK_OrigHitboxes[PhysAssetName] = {} end
                                    local OrigHitboxData = _G.AK_OrigHitboxes[PhysAssetName]

                                    local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                                    local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                                    local limit = numSetups > 50 and 50 or numSetups

                                    for i = 1, limit do 
                                        local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                                        if slua.isValid(BodySetup) then
                                            local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                                            local MatchedBoneKey = nil
                                            for k, _ in pairs(BoneScaleMap) do
                                                if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                                            end

                                            if MatchedBoneKey then
                                                local TargetScale = 1.0 
                                                if runInject_Global then TargetScale = BoneScaleMap[MatchedBoneKey] end
                                                
                                                local AggGeom = BodySetup.AggGeom
                                                
                                                local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                                                local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                                                local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems

                                                local BoxElem = GetFirstElemSafe(BoxElems)
                                                local SphereElem = GetFirstElemSafe(SphereElems)
                                                local SphylElem = GetFirstElemSafe(SphylElems)

                                                if not OrigHitboxData[MatchedBoneKey] then
                                                    OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                                    if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                                    if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                                    if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                                                end

                                                local OrigElemData = OrigHitboxData[MatchedBoneKey]

                                                if OrigElemData.Box and BoxElem then
                                                    BoxElem.X = OrigElemData.Box.X * TargetScale
                                                    BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                                    BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                                    if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end
                                                    if AggGeom then AggGeom.BoxElems = BoxElems; BodySetup.AggGeom = AggGeom else BodySetup.BoxElems = BoxElems end
                                                end

                                                if OrigElemData.Sphere and SphereElem then
                                                    SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                                    if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end
                                                    if AggGeom then AggGeom.SphereElems = SphereElems; BodySetup.AggGeom = AggGeom else BodySetup.SphereElems = SphereElems end
                                                end

                                                if OrigElemData.Sphyl and SphylElem then
                                                    SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                                    SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                                    if type(SphylElems.Set) == "function" then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end
                                                    if AggGeom then AggGeom.SphylElems = SphylElems; BodySetup.AggGeom = AggGeom else BodySetup.SphylElems = SphylElems end
                                                end
                                            end
                                        end
                                    end
                                    _G.AK_ModdedPhysAssets[PhysAssetName] = _G.LexusState.LastMagicConfigHash
                                end
                                
                                if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
                                EnemyMesh.PhysicsAssetOverride = PhysicsAsset
                                
                                markData.MagicBulletHash = _G.LexusState.LastMagicConfigHash
                                markData.MagicTargetID = uniqueID 
                            end
                        end
                    end)

                    local distM = 0
                    pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)

                    local currentHp, maxHp = 100, 100
                    local showFrameUI = _G.LexusConfig.EspLoai5 or _G.LexusConfig.EspVipPro or _G.LexusConfig.EspVip
                    
                    if showFrameUI then
                        pcall(function()
                            if enemy.Health then currentHp = enemy.Health elseif type(enemy.GetHealth) == "function" then currentHp = enemy:GetHealth() end
                            if enemy.HealthMax then maxHp = enemy.HealthMax elseif type(enemy.GetHealthMax) == "function" then maxHp = enemy:GetHealthMax() end
                        end)
                        if maxHp <= 0 then maxHp = 100 end
                    end
                    local hpRatio = currentHp / maxHp

                    if _G.LexusConfig.EspAntenna then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) and distM <= 400 then
                                local loopCount = 8  
                                local zStep = 1000     
                                local baseZ = 105     
                                local topZ = baseZ + (loopCount * zStep)
                                for i = 1, loopCount do
                                    local zOffset = baseZ + (i * zStep)
                                    MyHUD:AddDebugText("|", enemy, 0.06,
                                        {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset},
                                        C_GREEN, true, false, true, nil, 1.2, true)
                                end
                                MyHUD:AddDebugText("I", enemy, 0.06,
                                        {X=0, Y=0, Z=topZ + 60}, {X=0, Y=0, Z=topZ + 60},
                                        C_GREEN, true, false, true, nil, 1.5, true)
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai6 then
                        pcall(function()
                            local curTime = os.clock()
                            
                            
                            if markData.LastEsp6Time == nil or (curTime - markData.LastEsp6Time) >= 0.05 then
                                markData.LastEsp6Time = curTime
                                
                                local MyHUD = Cached_MyHUD
                                if Valid(MyHUD) and Valid(eMesh) and aLoc then
                                    if distM <= 250 then
                                        
                                        if type(eMesh.GetSocketLocation) == "function" then
                                            for _, bName in ipairs(GLOBAL_BONE_LIST) do
                                                
                                                
                                                if distM > 50 and (bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01") then
                                                    
                                                else
                                                    local wLoc = eMesh:GetSocketLocation(bName)
                                                    if wLoc then
                                                        
                                                        local offset = {X = wLoc.X - aLoc.X, Y = wLoc.Y - aLoc.Y, Z = wLoc.Z - aLoc.Z}
                                                        
                                                        local mark = "▪"
                                                        local fixedSize = 0.25 
                                                        local color = C_CYAN
                                                        
                                                        if bName == "head" then 
                                                            mark = "●"
                                                            fixedSize = 0.45
                                                            color = C_RED
                                                        elseif bName == "pelvis" or bName == "neck_01" then 
                                                            mark = "▪"
                                                            fixedSize = 0.35
                                                            color = C_YELLOW 
                                                        end
                                                        
                                                        
                                                        MyHUD:AddDebugText(mark, enemy, 0.06, offset, offset, color, true, false, true, nil, fixedSize, true)
                                                    end
                                                end
                                            end
                                        end
                                        
                                        
                                    end
                                end
                            end
                        end)
                    end

                    if _G.LexusConfig.EspLoai7 then
                        pcall(function()
                            local MyHUD = Cached_MyHUD
                            if Valid(MyHUD) then
                                if distM <= 600 then if isBot then aiCount = aiCount + 1 else realCount = realCount + 1 end end
                                
                                if distM <= 400 then
                                    local stateText = ""
                                    
                                    
                                    if _G.LexusConfig.Esp7_TuThe then
                                        local pose = nil
                                        if enemy.PoseState then pose = enemy.PoseState
                                        elseif type(enemy.GetPoseState) == "function" then pose = enemy:GetPoseState() end
                                        
                                        if pose == 0 or pose == "Stand" then stateText = "Đứng"
                                        elseif pose == 1 or pose == "Crouch" then stateText = "Ngồi"
                                        elseif pose == 2 or pose == "Prone" then stateText = "Nằm"
                                        else stateText = "Đứng" end
                                    end
                                    
                                    
                                    if _G.LexusConfig.Esp7_VuKhi then
                                        local curTime = os.clock()
                                        if markData.AK_LAST_WEP_TIME == nil or curTime > markData.AK_LAST_WEP_TIME + 1.5 then
                                            local eWeapon = nil
                                            if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                                            elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon()
                                            elseif enemy.WeaponManagerComponent then eWeapon = enemy.WeaponManagerComponent.CurrentWeaponReplicated end
                                            
                                            local weaponName = "Tay Không"
                                            if Valid(eWeapon) then if type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end end
                                            markData.AK_CACHED_WEP_NAME = tostring(weaponName)
                                            markData.AK_LAST_WEP_TIME = curTime
                                        end

                                        if stateText ~= "" then
                                            stateText = stateText .. " - " .. (markData.AK_CACHED_WEP_NAME or "Tay Không")
                                        else
                                            stateText = (markData.AK_CACHED_WEP_NAME or "Tay Không")
                                        end
                                    end

                                    
                                    if stateText ~= "" then
                                        local textColor = isBot and C_CYAN or C_YELLOW
                                        local dynamicScale = math.max(0.5, 0.8 - (distM / 400))
                                        MyHUD:AddDebugText(stateText, enemy, 0.06, {X=0, Y=0, Z=100}, {X=0, Y=0, Z=100}, textColor, true, false, true, nil, dynamicScale, true)
                                    end
                                end
                            end
                        end)
                    end

                    
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
                                        if isKnock then enemyName = "KNOCK: " .. enemyName end
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

                    if _G.LexusConfig.EspDistance then
                        pcall(function()
                            local hud = Cached_MyHUD
                            if Valid(hud) and hud.AddDebugText then
                                if distM <= 400 then
                                    local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                                    hud:AddDebugText(string.format("[%dm]", math.floor(distM)), enemy, 0.06, {X=0, Y=115, Z=20}, {X=0, Y=115, Z=20}, C_BLUE_TEXT, true, false, true, nil, dynamicScale * 1.5, true)
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

                    
                    if _G.LexusConfig.EspLoai8 then
                        if markData.hpMark8 == nil then markData.hpMark8 = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                    else
                        if markData.hpMark8 then SafeRemoveMark(markData.hpMark8); markData.hpMark8 = nil end
                    end
                    
                    if _G.LexusConfig.EspRadar then
                        
                        if not markData.radarMark or markData.radarMark == 0 then 
                            markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy) 
                        end
                    else
                        if markData.radarMark and markData.radarMark ~= 0 then
                            SafeRemoveMark(markData.radarMark)
                            markData.radarMark = nil
                        end
                    end
                    
                    
                    if _G.LexusConfig.EspOutline then
                        pcall(function()
                            local outColorChoice = _G.LexusState.CustomTextData.OutlineColor or 4
                            local outThick = _G.LexusConfig.OutlineThickness or 10
                            local outlineHash = string.format("%d_%d", outThick, outColorChoice)
                            
                            local meshes = GetAllSkeletalMeshes(enemy, markData)
                            local currentMeshCount = #meshes
                            
                            if markData.OutlineState ~= outlineHash or markData.LastMeshCountOutline ~= currentMeshCount then
                                
                                local r, g, b = 255, 255, 0 
                                if outColorChoice == 1 then r, g, b = 255, 0, 0 
                                elseif outColorChoice == 2 then r, g, b = 0, 255, 0 
                                elseif outColorChoice == 3 then r, g, b = 0, 0, 255 
                                elseif outColorChoice == 4 then r, g, b = 255, 255, 0 
                                elseif outColorChoice == 5 then r, g, b = 255, 0, 255 
                                elseif outColorChoice == 6 then r, g, b = 255, 255, 255 end 

                                local glowIntensity = 80.0
                                local LinearColorClass = import("LinearColor") or _G.FLinearColor
                                local glowDynamic = LinearColorClass and LinearColorClass((r/255) * glowIntensity, (g/255) * glowIntensity, (b/255) * glowIntensity, 1.0) or { R = r * glowIntensity, G = g * glowIntensity, B = b * glowIntensity, A = 255 }

                                for _, comp in ipairs(meshes) do
                                    if Valid(comp) then
                                        
                                        pcall(function()
                                            comp.UseScopeDistanceCulling = false 
                                            comp.PrimitiveShadingStrategy = 1
                                            comp.ShadingRate = 6
                                        end)

                                        
                                        if comp.SetDrawIdeaOutline then
                                            comp:SetDrawIdeaOutline(true)
                                            if comp.OverrideIdeaOutlineColor then
                                                comp:OverrideIdeaOutlineColor(true, glowDynamic)
                                            end
                                            if comp.OverrideIdeaOutlineThickness then
                                                
                                                comp:OverrideIdeaOutlineThickness(true, _G.LexusConfig.OutlineThickness)
                                            end
                                        end
                                    end
                                end
                                markData.OutlineState = outlineHash
                                markData.LastMeshCountOutline = currentMeshCount 
                            end
                        end)
                    else
                        pcall(function()
                            if markData.OutlineState ~= "OFF" then
                                local meshes = GetAllSkeletalMeshes(enemy, markData)
                                for _, comp in ipairs(meshes) do
                                    if Valid(comp) then
                                        
                                        pcall(function()
                                            comp.PrimitiveShadingStrategy = 0
                                            comp.ShadingRate = 1
                                        end)
                                        
                                        if comp.SetDrawIdeaOutline then
                                            comp:SetDrawIdeaOutline(false)
                                        end
                                    end
                                end
                                markData.OutlineState = "OFF"
                                markData.LastMeshCountOutline = 0
                            end
                        end)
                    end

                else
                    if not markData.IsCleanedUp then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                        SafeRemoveMark(markData.hpMark)
                        markData.hpMark = nil
                        SafeRemoveMark(markData.hpMark8) 
                        markData.hpMark8 = nil
                        SafeRemoveMark(markData.distMark)
                        markData.distMark = nil
                        
                        if markData.MIDs_V3 then
                            for meshStr, midTable in pairs(markData.MIDs_V3) do
                                for k, _ in pairs(midTable) do midTable[k] = nil end
                            end
                            markData.MIDs_V3 = nil
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
                            
                            local PPM = Cached_PPM
                            local avatarComp = Valid(eObj) and (type(eObj.getAvatarComponent2) == "function") and eObj:getAvatarComponent2() or nil
                            if Valid(avatarComp) and Valid(PPM) then PPM:EnableAvatarOutline(avatarComp, false) end
                        end)

                        markData.IsCleanedUp = true
                    end
                end
            end
        end

        if _G.LexusConfig.EspLoai7 and _G.LexusConfig.Esp7_SoLuong then
            _M_DrawCounter() 
        else
            
            if EnemyCounterWidget and slua.isValid(EnemyCounterWidget) then
                EnemyCounterWidget:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            end
        end

        
        
        
        if _G.LexusConfig.EspBomMaster and (_G.LexusConfig.EspItemBom or _G.LexusConfig.EspActiveBom) then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                    if not _G.CachedActorClass_ForBomb then _G.CachedActorClass_ForBomb = import("Actor") end 
                    if not _G.CachedProjArray then _G.CachedProjArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForBomb) end
                    
                    
                    if not _G.ActorBombCacheInit then
                        _G.NonBombCache = setmetatable({}, { __mode = "k" })
                        _G.BombCache = setmetatable({}, { __mode = "k" })
                        _G.ActorBombCacheInit = true
                    end
                    
                    local ui_util = require("client.common.ui_util")
                    local gameInstance = ui_util and ui_util.GetGameInstance()
                    
                    if gameInstance and _G.CachedGameplayStatics then
                        local curTime = os.clock()
                        
                        
                        if not _G.LastBombScanTime or (curTime - _G.LastBombScanTime) > 0.5 then
                            _G.LastBombScanTime = curTime
                            local allActors = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForBomb, _G.CachedProjArray)
                            
                            local activeBombs = {}
                            local itemBombs = {}
                            
                            if allActors then
                                for _, actor in pairs(allActors) do
                                    if slua.isValid(actor) and not actor.bHidden and not actor.bTearOff then
                                        
                                        
                                        
                                        if not _G.NonBombCache[actor] then
                                            local bType = 0
                                            local isItem = false
                                            local isKnownBomb = _G.BombCache[actor]
                                            
                                            if isKnownBomb then
                                                bType = isKnownBomb.type
                                                isItem = isKnownBomb.isItem
                                            else
                                                
                                                local nameLower = nil
                                                pcall(function() nameLower = string.lower(type(actor.GetName) == "function" and actor:GetName() or tostring(actor)) end)
                                                
                                                if nameLower then
                                                    if string.find(nameLower, "m79") or string.find(nameLower, "launcher") then bType = 5
                                                    elseif string.find(nameLower, "smoke") then bType = 2
                                                    elseif string.find(nameLower, "burn") or string.find(nameLower, "molotov") then bType = 3
                                                    elseif string.find(nameLower, "flash") or string.find(nameLower, "stun") then bType = 4
                                                    elseif string.find(nameLower, "grenade") then bType = 1 end
                                                    
                                                    if bType > 0 then
                                                        if string.find(nameLower, "projectile") or string.find(nameLower, "thrown") then
                                                            isItem = false
                                                        else
                                                            isItem = true
                                                            local shouldAdd = true
                                                            if bType == 3 and not (string.find(nameLower, "pickup") or string.find(nameLower, "wrapper") or string.find(nameLower, "weapon")) then
                                                                shouldAdd = false
                                                            elseif bType == 5 then
                                                                local attachParent = nil
                                                                pcall(function() if type(actor.GetAttachParentActor) == "function" then attachParent = actor:GetAttachParentActor() end end)
                                                                if slua.isValid(attachParent) then
                                                                    local isHolding = false
                                                                    pcall(function()
                                                                        local curWeapon = type(attachParent.GetCurrentWeapon) == "function" and attachParent:GetCurrentWeapon() or attachParent.CurrentWeapon
                                                                        if curWeapon == actor then isHolding = true end
                                                                    end)
                                                                    if not isHolding then shouldAdd = false end
                                                                end
                                                            end
                                                            if not shouldAdd then bType = 0 end
                                                        end
                                                    end
                                                end
                                                
                                                
                                                if bType > 0 then
                                                    _G.BombCache[actor] = { type = bType, isItem = isItem }
                                                else
                                                    _G.NonBombCache[actor] = true
                                                end
                                            end
                                            
                                            
                                            if bType > 0 then
                                                local isPendingKill = false
                                                pcall(function() if type(actor.IsPendingKill) == "function" then isPendingKill = actor:IsPendingKill() end end)
                                                
                                                if not isPendingKill then
                                                    if isItem then
                                                        table.insert(itemBombs, {act = actor, type = bType})
                                                    else
                                                        table.insert(activeBombs, {act = actor, type = bType})
                                                    end
                                                else
                                                    
                                                    _G.BombCache[actor] = nil
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            _G.CachedActiveBombs = activeBombs
                            _G.CachedItemBombs = itemBombs
                        end

                        local curGameTime = 0
                        pcall(function() curGameTime = _G.CachedGameplayStatics.GetTimeSeconds(gameInstance) end)

                        local function DrawBombs(bombList, isItem, maxDist)
                            if not bombList then return end
                            for _, item in ipairs(bombList) do
                                local bomb = item.act
                                local bType = item.type
                                
                                if slua.isValid(bomb) and not bomb.bHidden then
                                    local distM = 0
                                    pcall(function() distM = localPlayer:GetDistanceTo(bomb) / 100 end)
                                    
                                    if distM > 0 and distM <= maxDist then
                                        local displayName = ""
                                        local bombColor = C_WHITE
                                        local zOffset = isItem and 15 or 25
                                        
                                        if bType == 1 then displayName = "Boom"; bombColor = isItem and {R=255, G=100, B=100, A=255} or C_RED
                                        elseif bType == 2 then displayName = "KHÓI"; bombColor = isItem and {R=200, G=200, B=200, A=255} or C_WHITE
                                        elseif bType == 3 then displayName = "LỬA"; bombColor = isItem and {R=255, G=160, B=50, A=255} or {R=255, G=100, B=0, A=255}
                                        elseif bType == 4 then displayName = "MÙ"; bombColor = isItem and {R=150, G=255, B=255, A=255} or C_CYAN
                                        elseif bType == 5 then displayName = "ĐẠN KHÓI"; bombColor = isItem and {R=150, G=255, B=150, A=255} or {R=100, G=255, B=100, A=255} end
                                        
                                        local text = string.format("%s [%dm]", displayName, math.floor(distM))
                                        local shouldTimerRun = not isItem 
                                        
                                        if isItem then pcall(function() if bomb.bIsPinPulled or bomb.bPinPulled or (type(bomb.IsPinPulled) == "function" and bomb:IsPinPulled()) then shouldTimerRun = true end end) end

                                        if shouldTimerRun and curGameTime > 0 then
                                            local timeLeft = -1
                                            pcall(function() if bomb.ExplosionTime then timeLeft = bomb.ExplosionTime - curGameTime elseif bomb.ExplodeTime then timeLeft = bomb.ExplodeTime - curGameTime end end)
                                            
                                            if timeLeft == -1 or timeLeft > 100 then
                                                _G.ActiveBombTimers = _G.ActiveBombTimers or {}
                                                local bombId = tostring(bomb)
                                                if not _G.ActiveBombTimers[bombId] then _G.ActiveBombTimers[bombId] = curGameTime end
                                                local elapsed = curGameTime - _G.ActiveBombTimers[bombId]
                                                local maxTime = (bType == 1 and 7.0) or (bType == 2 and 45.0) or (bType == 3 and 12.0) or (bType == 4 and 5.0) or 45.0
                                                timeLeft = maxTime - elapsed
                                            end
                                            
                                            if timeLeft < 0 then timeLeft = 0 end
                                            if timeLeft > 0.1 then text = string.format("%s (%.1fs)", text, timeLeft) end
                                        end
                                        
                                        local dynamicScale = math.max(0.6, 1.1 - (distM / maxDist))
                                        MyHUD:AddDebugText(text, bomb, 0.06, {X=0, Y=0, Z=zOffset}, {X=0, Y=0, Z=zOffset}, bombColor, true, false, true, nil, dynamicScale, true)
                                    end
                                end
                            end
                        end
                        
                        if not _G.LastClearTimer or (curTime - _G.LastClearTimer) > 1.0 then
                            _G.LastClearTimer = curTime
                            pcall(function() if _G.ActiveBombTimers then for k, v in pairs(_G.ActiveBombTimers) do if (curGameTime - v) > 60.0 then _G.ActiveBombTimers[k] = nil end end end end)
                        end

                        if _G.LexusConfig.EspItemBom then DrawBombs(_G.CachedItemBombs, true, 50) end
                        if _G.LexusConfig.EspActiveBom then DrawBombs(_G.CachedActiveBombs, false, 150) end
                    end
                end
            end)
        end

        
        
        
        
        
        
        if _G.LexusConfig.EspVehicle then
            pcall(function()
                local MyHUD = Cached_MyHUD
                if Valid(MyHUD) then
                    if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                    if not _G.CachedActorClass_ForVehicle then _G.CachedActorClass_ForVehicle = import("STExtraVehicleBase") end 
                    if not _G.CachedVehicleArray then _G.CachedVehicleArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForVehicle) end
                    
                    local ui_util = require("client.common.ui_util")
                    local gameInstance = ui_util and ui_util.GetGameInstance()
                    
                    if gameInstance and _G.CachedGameplayStatics then
                        local curTime = os.clock()

                        
                        if not _G.LastVehicleScanTime or (curTime - _G.LastVehicleScanTime) > 1.0 then
                            _G.LastVehicleScanTime = curTime
                            local allVehicles = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForVehicle, _G.CachedVehicleArray)
                            
                            local activeVehicles = {}
                            if allVehicles then
                                for _, veh in pairs(allVehicles) do
                                    if slua.isValid(veh) and not veh.bHidden and not veh.bTearOff then
                                        local isPendingKill = false
                                        pcall(function() if type(veh.IsPendingKill) == "function" then isPendingKill = veh:IsPendingKill() end end)
                                        
                                        if not isPendingKill then
                                            local vehName = "Xe"
                                            local hasDriver = false
                                            
                                            pcall(function()
                                                if type(veh.GetVehicleName) == "function" then vehName = veh:GetVehicleName() elseif veh.VehicleName then vehName = veh.VehicleName end
                                                local driver = type(veh.GetDriver) == "function" and veh:GetDriver() or nil
                                                if slua.isValid(driver) then hasDriver = true end
                                            end)
                                            
                                            local nameLower = string.lower(tostring(vehName) .. tostring(veh))
                                            local displayName = "Xe"
                                            if string.find(nameLower, "uaz") then displayName = "UAZ"
                                            elseif string.find(nameLower, "dacia") then displayName = "Dacia"
                                            elseif string.find(nameLower, "buggy") then displayName = "Buggy"
                                            elseif string.find(nameLower, "mirado") then displayName = "Mirado"
                                            elseif string.find(nameLower, "bike") or string.find(nameLower, "motor") then displayName = "Motor"
                                            elseif string.find(nameLower, "scooter") then displayName = "Scooter"
                                            elseif string.find(nameLower, "coupe") then displayName = "Coupe RB"
                                            elseif string.find(nameLower, "brdm") then displayName = "BRDM"
                                            elseif string.find(nameLower, "boat") or string.find(nameLower, "aquarail") then displayName = "Thuyền"
                                            elseif string.find(nameLower, "glider") then displayName = "Tàu lượn"
                                            else displayName = "Xe (" .. string.sub(vehName, 1, 8) .. ")" end

                                            table.insert(activeVehicles, {act = veh, name = displayName, hasDriver = hasDriver})
                                        end
                                    end
                                end
                            end
                            _G.CachedVehicles = activeVehicles
                        end

                        if _G.CachedVehicles then
                            for _, item in ipairs(_G.CachedVehicles) do
                                local veh = item.act
                                if slua.isValid(veh) and not veh.bHidden then
                                    local isShow = false
                                    if item.name == "Dacia" then isShow = _G.LexusConfig.EspVeh_Dacia
                                    elseif item.name == "UAZ" then isShow = _G.LexusConfig.EspVeh_UAZ
                                    elseif item.name == "Buggy" then isShow = _G.LexusConfig.EspVeh_Buggy
                                    elseif item.name == "Coupe RB" then isShow = _G.LexusConfig.EspVeh_Coupe
                                    elseif item.name == "Mirado" then isShow = _G.LexusConfig.EspVeh_Mirado
                                    elseif item.name == "Motor" or item.name == "Scooter" then isShow = _G.LexusConfig.EspVeh_Motor
                                    else isShow = _G.LexusConfig.EspVeh_Other end

                                    if isShow then
                                        local distM = 0
                                        pcall(function() distM = localPlayer:GetDistanceTo(veh) / 100 end)
                                        
                                        if distM > 0 and distM <= 300 then
                                            local text = string.format("%s [%dm]", item.name, math.floor(distM))
                                            local vehColor = item.hasDriver and {R=255, G=50, B=50, A=255} or {R=0, G=255, B=150, A=255}
                                            local dynamicScale = math.max(0.6, 1.1 - (distM / 500))
                                            
                                            MyHUD:AddDebugText(text, veh, 0.06, {X=0, Y=0, Z=50}, {X=0, Y=0, Z=50}, vehColor, true, false, true, nil, dynamicScale, true)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end

    end)
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1 
local myToken = _G.LexusState.LoopToken

local function ExpiredTick()
    if not _G.LexusNotifiedPopup then
        pcall(function()
            local Msg = require("client.slua.logic.common.logic_common_msg_box")
            if Msg and Msg.Show then
                Msg.Show(1, "VIP MOD CLOSED OR EXPIRED", "YOUR VIP FILE HAS BEEN CLOSED BY OWNER\nFOR BUY VIP FILES CONTACT OWNER\nOWNER {@ZONE_MOD} • ID @SharkFlux ", 
                function() 
                    local Web = require("client.slua.logic.url.logic_webview_sdk")
                    if Web and Web.OpenURL then Web:OpenURL("https://t.me/ZONE_MOD") end 
                end, 
                function() end, "TEXT OWNER", "OK")
                _G.LexusNotifiedPopup = true 
            end
        end)
        
        if not _G.LexusNotifiedPopup then
            local okTicker, ticker = pcall(require("common.time_ticker")) 
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
    local UI = {
        _status = "Enter your key",
        _busy = false,
        _data = nil,
        _scale = 1,
        _spinIndex = 1
    }

    local function global(name)
        local ok, value = pcall(function() return env[name] end)
        if ok then return value end
    end

    local function member(object, name)
        if object == nil then return nil end
        local ok, value = pcall(function() return object[name] end)
        if ok then return value end
    end

    local function valid(object)
        local check = member(global("slua"), "isValid")
        if object == nil then return false end
        if type(check) == "function" then
            local ok, result = pcall(check, object)
            if ok and result == true then return true end
        end
        local game = global("Game")
        local fallback = member(game, "IsValid")
        if type(fallback) == "function" then
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

    local function fitScale(parent)
        local result = 1
        pcall(function()
            local size = parent:GetCachedGeometry():GetLocalSize()
            local width, height = size.X, size.Y
            if type(width) == "number" and type(height) == "number" and width > 24 and height > 24 then
                result = math.min(1, (width - 24) / 540, (height - 24) / 300)
            end
        end)
        return math.max(0.5, result)
    end

    local function makeFactory(game, container, data)
        return function(class, outer)
            local widget = game:NewObjectFromPath("/Script/UMG." .. class, outer or container)
            assert(valid(widget), "UI_WIDGET_UNAVAILABLE")
            local clip = member(member(global("UEnums"), "EWidgetClipping"), "ClipToBounds")
            if clip ~= nil then pcall(function() widget:SetClipping(clip) end) end
            return widget
        end
    end

    local function detach(data)
        if not data then return end
        data.visible = false
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
        data.onOK = nil
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
        if data and data.status and valid(data.status) then
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
        if not data or not data.visible or type(now) ~= "number" then return false end
        if data.mode ~= "login" or not UI._busy then return true end

        local frames = {"CHECKING |", "CHECKING /", "CHECKING -", "CHECKING \\"}
        local index = math.floor(now * 8) % #frames + 1
        if index ~= UI._spinIndex then
            UI._spinIndex = index
            pcall(function()
                if valid(data.buttonLabel) then data.buttonLabel:SetText(frames[index]) end
            end)
        end
        pcall(function()
            if valid(data.statusPulse) then
                local pulse = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(now * 8.0))
                data.statusPulse:SetBrushColor(color(0.12, 0.78, 1.0, pulse))
            end
        end)
        return true
    end

    local function addChild(container, widget, x, y, width, height, z, scale)
        local slot = container:AddChildToCanvas(widget)
        assert(valid(slot), "UI_SLOT_UNAVAILABLE")
        slot:SetAutoSize(false)
        slot:SetPosition(vector(x * scale, y * scale))
        slot:SetSize(vector(width * scale, height * scale))
        slot:SetZOrder(z or 1)
        return slot
    end

    local function buildShell(parent, visibleEnum, hidden, passive, game, W, H, scale)
        local data = {
            parent = parent,
            visibleEnum = visibleEnum,
            hidden = hidden,
            passive = passive,
            scale = scale,
            visible = false
        }

        local make = makeFactory(game, nil, data)
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

        data.container = make("CanvasPanel", parent)

        local function add(widget, x, y, width, height, z)
            return addChild(data.container, widget, x, y, width, height, z, scale)
        end

        local function text(value, size, r, g, b, a)
            local w = make("TextBlock", data.container)
            w:SetText(value)
            setTextStyle(w, size, color(r, g, b, a or 1))
            visibility(w, passive)
            return w
        end

        local shadow = make("Border", data.container)
        shadow:SetBrushColor(color(0, 0, 0, 0.50))
        visibility(shadow, passive)
        add(shadow, 6, 7, W - 12, H - 10, 1)

        local card = make("Border", data.container)
        card:SetBrushColor(color(0.035, 0.055, 0.08, 0.98))
        visibility(card, visibleEnum)
        add(card, 0, 0, W, H, 2)

        local top = make("Border", data.container)
        top:SetBrushColor(color(0.0, 0.75, 1.0, 0.92))
        visibility(top, visibleEnum)
        add(top, 0, 0, W, 3, 5)
        data.top = top

        return data, make, add, text
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
        local visibleEnum = member(enums, "Visible")
        local hidden = member(enums, "Collapsed")
        local passive = member(enums, "SelfHitTestInvisible")
        if visibleEnum == nil or hidden == nil or passive == nil then return false, "UI_ENUM_UNAVAILABLE" end

        UI._scale = fitScale(parent)
        local W, H = 540, 300
        local data, make, add, text = buildShell(parent, visibleEnum, hidden, passive, game, W, H, UI._scale)
        data.mode = "login"
        data.onSubmit = onSubmit

        local title = text("LOGIN PAGE || @ZONE_MOD", 18, 0.95, 0.97, 1.0)
        add(title, 24, 22, W - 48, 30, 10)
        local subtitle = text("ONLINE LICENSE  •  ZD SYSTEM", 7.5, 0.34, 0.73, 0.90)
        add(subtitle, 26, 52, W - 52, 18, 10)

        local inputBg = make("Border", data.container)
        inputBg:SetBrushColor(color(0.015, 0.028, 0.05, 1.0))
        visibility(inputBg, visibleEnum)
        add(inputBg, 24, 84, W - 48, 50, 4)

        data.input = make("EditableTextBox", data.container)
        assert(type(member(data.input, "GetText")) == "function", "UI_INPUT_UNAVAILABLE")
        data.input:SetText("")
        setTextStyle(data.input, 14, color(0.94, 0.96, 1, 1))
        pcall(function() data.input:SetHintText("Enter your key here...") end)
        pcall(function() data.input:SetIsPassword(false) end)
        pcall(function() data.input:SetIsReadOnly(false) end)
        pcall(function() data.input.AllowContextMenu = true end)
        local enumRoot = global("UEnums")
        local keyboard = member(member(enumRoot, "EVirtualKeyboardType"), "Default")
        local trigger = member(member(enumRoot, "EVirtualKeyboardTrigger"), "OnAllFocusEvents")
        if keyboard ~= nil then pcall(function() data.input.KeyboardType = keyboard end) end
        if trigger ~= nil then pcall(function() data.input.VirtualKeyboardTrigger = trigger end) end
        visibility(data.input, visibleEnum)
        add(data.input, 38, 90, W - 76, 38, 20)
        pcall(function() data.input:SetIsEnabled(true) end)

        local hint = text("Key is checked online before this session.", 7.5, 0.46, 0.55, 0.64)
        add(hint, 28, 143, W - 56, 16, 8)

        local statusBg = make("Border", data.container)
        statusBg:SetBrushColor(color(0.02, 0.035, 0.065, 0.98))
        visibility(statusBg, visibleEnum)
        add(statusBg, 24, 164, W - 48, 48, 3)

        data.statusPulse = make("Border", data.container)
        data.statusPulse:SetBrushColor(color(0.12, 0.78, 1.0, 0.70))
        visibility(data.statusPulse, passive)
        add(data.statusPulse, 24, 164, 3, 48, 8)

        data.status = text(UI._status, 12.5, 0.80, 0.92, 0.98)
        data.deliveredStatus = UI._status
        add(data.status, 39, 168, W - 78, 40, 10)

        local loginButton = make("Button", data.container)
        pcall(function() loginButton:SetBackgroundColor(color(0.02, 0.64, 0.92, 0.96)) end)
        visibility(loginButton, visibleEnum)
        add(loginButton, 154, 221, 232, 45, 20)
        data.button = loginButton

        data.buttonLabel = make("TextBlock", loginButton)
        data.buttonLabel:SetText("LOGIN NOW")
        setTextStyle(data.buttonLabel, 13.5, color(0.005, 0.012, 0.025, 1))
        visibility(data.buttonLabel, passive)
        pcall(function() loginButton:AddChild(data.buttonLabel) end)

        local footer = text("ZONE MOD  •  PREMIUM LICENSE", 7, 0.36, 0.58, 0.70)
        add(footer, 24, 278, W - 48, 14, 10)

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
            UI.SetBusy(true)
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
        data.visible = true
        UI._data = data
        UI.SetBusy(UI._busy)

        return true
    end

    function UI.ShowSuccess(onOK)
        if type(onOK) ~= "function" then return false, "UI_OK_REQUIRED" end

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
        local visibleEnum = member(enums, "Visible")
        local hidden = member(enums, "Collapsed")
        local passive = member(enums, "SelfHitTestInvisible")
        if visibleEnum == nil or hidden == nil or passive == nil then return false, "UI_ENUM_UNAVAILABLE" end

        UI._scale = fitScale(parent)
        local W, H = 540, 300
        local data, make, add, text = buildShell(parent, visibleEnum, hidden, passive, game, W, H, UI._scale)
        data.mode = "success"
        data.onOK = onOK

        local title = text("Welcome to @ZONE_MOD Premium Pak", 17, 0.95, 0.97, 1.0)
        add(title, 24, 26, W - 48, 46, 10)

        local subtitle = text("LICENSE VERIFIED", 8, 0.28, 0.80, 0.92)
        add(subtitle, 24, 68, W - 48, 18, 10)

        local messageBox = make("Border", data.container)
        messageBox:SetBrushColor(color(0.015, 0.042, 0.075, 0.99))
        visibility(messageBox, visibleEnum)
        add(messageBox, 46, 103, W - 92, 64, 4)

        local message = text(". No Kill Limit .", 15, 0.82, 0.94, 1.0)
        add(message, 65, 121, W - 130, 30, 10)

        local note = text("Play smart and avoid report", 7.5, 0.58, 0.68, 0.76)
        add(note, 24, 181, W - 48, 18, 10)

        local okButton = make("Button", data.container)
        pcall(function() okButton:SetBackgroundColor(color(0.02, 0.64, 0.92, 0.96)) end)
        visibility(okButton, visibleEnum)
        add(okButton, 170, 213, 200, 44, 20)
        data.button = okButton

        local okLabel = make("TextBlock", okButton)
        okLabel:SetText("OK")
        setTextStyle(okLabel, 12, color(0.005, 0.012, 0.025, 1))
        visibility(okLabel, passive)
        pcall(function() okButton:AddChild(okLabel) end)

        local footer = text("@ZONE_MOD PREMIUM", 7, 0.36, 0.58, 0.70)
        add(footer, 24, 278, W - 48, 14, 10)

        data.event = data.button.OnClicked
        assert(type(member(data.event, "Add")) == "function", "UI_BUTTON_UNAVAILABLE")
        data.eventHandle = data.event:Add(function()
            if UI._data ~= data or not data.visible then return end
            local callback = data.onOK
            if type(callback) == "function" then
                local ok = pcall(callback)
                if not ok then
                    print("[@ZONE_MOD] Success dialog callback error")
                end
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
        data.visible = true
        UI._status = "License verified."
        UI._data = data
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
    
    
    
    
    local LICENSE_API = "https://zd-license-api.amyratfy8.workers.dev"
    local ADMIN_TOKEN = "zonemoda11571157"

    local Gate = {
        unlocked = false,
        verifying = false,
        autoVerifyAttempted = false,
        lastUIError = nil,
        expiresAt = nil,
        ui = nil,
        deviceId = nil,
        waitingForOK = false,
        pendingKey = nil,
        pendingExpiresAt = nil
    }

    local function normalizeKey(key)
        key = type(key) == "string" and key:match("^%s*(.-)%s*$") or ""
        return key:upper()
    end

    local function urlEncode(value)
        value = tostring(value or "")
        value = value:gsub("\n", "\r\n")
        value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(ch)
            return string.format("%%%02X", string.byte(ch))
        end)
        return value:gsub(" ", "+")
    end

    local function getHttpManager()
        local httpManager = nil
        local loaded = package and package.loaded and package.loaded["client.slua.logic.http.http_manager"]
        if loaded then
            httpManager = loaded
        else
            local ok, module = pcall(require, "client.slua.logic.http.http_manager")
            if ok then httpManager = module end
        end
        if not httpManager or type(httpManager.Post) ~= "function" then
            return nil
        end
        return httpManager
    end

    local function parseResponse(response)
        if type(response) == "table" then
            return response
        end
        local decoder = json and json.decode
        if type(decoder) ~= "function" then
            return nil
        end
        local raw = tostring(response or "")
        if raw == "" then return nil end
        local ok, data = pcall(decoder, raw)
        if ok and type(data) == "table" then
            return data
        end
        return nil
    end

    local function getDeviceName()
        local device = "Unknown device"
        pcall(function()
            local SystemInfo = import("SystemInfo")
            if not SystemInfo then return end
            local brand, model = nil, nil
            pcall(function()
                if type(SystemInfo.GetDeviceBrand) == "function" then
                    brand = SystemInfo.GetDeviceBrand()
                end
            end)
            pcall(function()
                if type(SystemInfo.GetDeviceModel) == "function" then
                    model = SystemInfo.GetDeviceModel()
                elseif type(SystemInfo.GetModel) == "function" then
                    model = SystemInfo.GetModel()
                end
            end)
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

    local function getDeviceUID()
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

    local function serverStatusText(data)
        local reason = tostring(data and data.error or "")
        if reason == "invalid_key" then
            return "Invalid key. Enter the valid access key."
        elseif reason == "key_revoked" then
            return "This key has been revoked."
        elseif reason == "key_expired" then
            return "This key has expired."
        elseif reason == "key_required" then
            return "Enter a valid access key."
        elseif reason == "device_banned" then
            return "This device has been banned."
        elseif reason == "device_limit" then
            return "This key has reached its device limit."
        elseif reason == "device_register_failed" then
            return "Could not register this device."
        end
        return "Unable to verify the key online."
    end

    function Gate:IsUnlocked()
        return self.unlocked == true
    end

    function Gate:Unlock(key, expiresAt)
        self.unlocked = true
        self.expiresAt = tonumber(expiresAt) or nil
        _G.ZONE_MOD_SAVED_KEY = key

        if _G.SaveModSettings then
            pcall(_G.SaveModSettings)
        end

        if self.ui then
            self.ui.SetBusy(false)
            self.ui.SetStatus("License verified. Access granted.")
            self.ui.Hide()
        end
    end

    function Gate:RegisterDevice(key, expiresAt)
        local httpManager = getHttpManager()
        if not httpManager then
            self.verifying = false
            if self.ui then
                self.ui.SetBusy(false)
                self.ui.SetStatus("License service is unavailable.")
            end
            return false, "http_manager_unavailable"
        end

        local deviceName = getDeviceName()
        if deviceName == "" or deviceName == "Unknown device" then
            deviceName = "Android Device"
        end
        local deviceUID = getDeviceUID()
        local deviceLabel = deviceName
        if deviceUID ~= "" and deviceUID ~= "unknown" then
            deviceLabel = deviceName .. " | PlayerID:" .. deviceUID
        end
        local body = "action=register_device"
            .. "&key=" .. urlEncode(key)
            .. "&device_name=" .. urlEncode(deviceLabel)
            .. "&platform=Android"
            .. "&device_uid=" .. urlEncode(deviceUID)

        if self.ui then
            self.ui.SetBusy(true)
            self.ui.SetStatus("Registering device...")
        end

        local okPost, postResult = pcall(function()
            return httpManager:Post(
                LICENSE_API,
                {
                    ["Content-Type"] = "application/x-www-form-urlencoded",
                    ["X-Admin-Token"] = ADMIN_TOKEN
                },
                body,
                nil,
                function(success, _, response, errorMessage)
                    self.verifying = false

                    if not success then
                        print("[@ZONE_MOD] Device registration failed: " .. tostring(errorMessage or response or "request_failed"))
                        if self.ui then
                            self.ui.SetBusy(false)
                            self.ui.SetStatus("Could not register this device.")
                        end
                        return
                    end

                    local data = parseResponse(response)
                    if type(data) ~= "table" then
                        if self.ui then
                            self.ui.SetBusy(false)
                            self.ui.SetStatus("Invalid response from license server.")
                        end
                        return
                    end

                    if data.ok == true then
                        self.deviceId = tonumber(data.device_id) or nil
                        self.verifying = false
                        self.waitingForOK = true
                        self.pendingKey = key
                        self.pendingExpiresAt = expiresAt

                        local shown = false
                        if self.ui and type(self.ui.ShowSuccess) == "function" then
                            local okShow, result = pcall(function()
                                return self.ui.ShowSuccess(function()
                                    local unlockKey = self.pendingKey or key
                                    local unlockExpiresAt = self.pendingExpiresAt or expiresAt
                                    self.pendingKey = nil
                                    self.pendingExpiresAt = nil
                                    self.waitingForOK = false
                                    self:Unlock(unlockKey, unlockExpiresAt)
                                end)
                            end)
                            shown = okShow and result == true
                        end

                        if not shown then
                            self.pendingKey = nil
                            self.pendingExpiresAt = nil
                            self.waitingForOK = false
                            self:Unlock(key, expiresAt)
                        end

                        print("[@ZONE_MOD] License verified and device registered")
                        return
                    end

                    if self.ui then
                        self.ui.SetBusy(false)
                        self.ui.SetStatus(serverStatusText(data))
                    end
                end,
                60
            )
        end)

        if not okPost then
            self.verifying = false
            if self.ui then
                self.ui.SetBusy(false)
                self.ui.SetStatus("Could not start device registration.")
            end
            print("[@ZONE_MOD] Device registration POST exception: " .. tostring(postResult))
            return false, "post_exception"
        end

        return true, postResult
    end

    function Gate:Verify(key)
        key = normalizeKey(key)
        if key == "" then
            if self.ui then
                self.ui.SetBusy(false)
                self.ui.SetStatus("Enter a valid access key.")
            end
            return false, "key_required"
        end

        if self.verifying then
            return false, "verification_in_progress"
        end

        local httpManager = getHttpManager()
        if not httpManager then
            if self.ui then
                self.ui.SetBusy(false)
                self.ui.SetStatus("License service is unavailable.")
            end
            return false, "http_manager_unavailable"
        end

        self.verifying = true
        if self.ui then
            self.ui.SetBusy(true)
            self.ui.SetStatus("Checking key online...")
        end

        local body = "key=" .. urlEncode(key)
        local okPost, postResult = pcall(function()
            return httpManager:Post(
                LICENSE_API,
                { ["Content-Type"] = "application/x-www-form-urlencoded" },
                body,
                nil,
                function(success, _, response, errorMessage)
                    if not success then
                        self.verifying = false
                        if self.ui then
                            self.ui.SetBusy(false)
                            self.ui.SetStatus("Could not contact the license server.")
                        end
                        print("[@ZONE_MOD] License verification failed: " .. tostring(errorMessage or response or "request_failed"))
                        return
                    end

                    local data = parseResponse(response)
                    if type(data) ~= "table" then
                        self.verifying = false
                        if self.ui then
                            self.ui.SetBusy(false)
                            self.ui.SetStatus("Invalid response from license server.")
                        end
                        return
                    end

                    if data.valid == true then
                        
                        self:RegisterDevice(key, data.expires_at)
                        return
                    end

                    self.verifying = false
                    if self.ui then
                        self.ui.SetBusy(false)
                        self.ui.SetStatus(serverStatusText(data))
                    end
                    print("[@ZONE_MOD] License rejected: " .. tostring(data.error or "invalid"))
                end,
                60
            )
        end)

        if not okPost then
            self.verifying = false
            if self.ui then
                self.ui.SetBusy(false)
                self.ui.SetStatus("Could not start license verification.")
            end
            print("[@ZONE_MOD] License POST exception: " .. tostring(postResult))
            return false, "post_exception"
        end

        return true, postResult
    end

    function Gate:Submit(key)
        return self:Verify(key)
    end

    function Gate:Ensure()
        if self.unlocked then
            return true
        end

        if self.waitingForOK then
            return false, "SUCCESS_WAITING"
        end

        if not self.autoVerifyAttempted then
            self.autoVerifyAttempted = true
            local savedKey = normalizeKey(_G.ZONE_MOD_SAVED_KEY)
            if savedKey ~= "" then
                self:Verify(savedKey)
                return false, "VERIFYING_SAVED_KEY"
            end
        end

        if self.verifying then
            return false, "VERIFYING"
        end

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

        if not self.verifying then
            self.ui.SetBusy(false)
        end
        return true
    end

    return Gate
end)()

_G.__ZONE_MOD_KEY_GATE = ZONE_MOD_KEY_GATE


local function FastTick()
    if isExpired then
        if not _G.LexusNotifiedExpire then
            Notify("VIP MOD EXPIRED")
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

    if ZONE_MOD_KEY_GATE.ui and not ZONE_MOD_KEY_GATE:IsUnlocked() then
        local now = 0
        pcall(function() now = os.clock() end)
        pcall(function() ZONE_MOD_KEY_GATE.ui.Animate(now) end)
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

if not isExpired then
    FastTick() 
    Notify(" FOR MORE VIP FILES BUYING TEXT OWNER ON TELEGRAM {@ZONE_MOD}")
else
    FastTick() 
end


local function InitAllModSystems()
    if isExpired then return end

    if not ZONE_MOD_KEY_GATE:IsUnlocked() then
        pcall(function()
            local okTicker, ticker = pcall(require, "common.time_ticker")
            if okTicker and ticker and ticker.AddTimerOnce then
                ticker.AddTimerOnce(0.5, InitAllModSystems)
            end
        end)
        return
    end


    pcall(function()
        if _G.StartBypass_VIP_v3 then _G.StartBypass_VIP_v3() end
        if _G.InitializeAutoHeadHooks then _G.InitializeAutoHeadHooks() end
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