-- Popup Test — @ZONE_MOD
pcall(function()
  local msgBox = package.loaded["client.slua.logic.common.logic_common_msg_box"]
  if not msgBox then
    msgBox = require("client.slua.logic.common.logic_common_msg_box")
  end

  local body = "==============================\n"
    .. "     *  این فایل توسط ZONE قطع شد *\n"
    .. "==============================\n"
    .. "        برای درخواست فایل بعدی پیام بدید\n"
    .. "     @SHARKFLUX\n"
    .. "==============================\n"
    .. "     *  Team @Zone_mod  *\n"
    .. "==============================\n"
    .. "  Join our Telegram\n"
    .. "  for updates & support"

  local onJoin = function()
    pcall(function()
      local web = require("client.slua.logic.url.logic_webview_sdk")
      if web and web.OpenURL then
        web:OpenURL("https://t.me/SharkFlux")
      end
    end)
  end

  local onCancel = function() end

  msgBox.Show(2, "JASMEETSINGHVIPMOD", body, onJoin, onCancel, "تماس با پشتیبانی", "باشه برای بعدا")
end)
