local util = require "luci.util"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local http = require "luci.http"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

local USSD_FILE_PATH = "/etc/config/ussd.user"
local PHB_FILE_PATH = "/etc/config/phonebook.user"
local SMSC_FILE_PATH = "/etc/config/smscommands.user"
local AT_FILE_PATH = "/etc/config/atcmds.user"

local led = tostring(uci:get("sms_tool", "general", "smsled"))
local dsled = tostring(uci:get("sms_tool", "general", "ledtype"))
local ledtime = tostring(uci:get("sms_tool", "general", "checktime"))

local m
local s
local dev1, dev2, dev3, dev4, leds
local try_devices1 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices2 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices3 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices4 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_leds = nixio.fs.glob("/sys/class/leds/*")


local devv = tostring(uci:get("sms_tool", "general", "readport"))

local smsmem = tostring(uci:get("sms_tool", "general", "storage"))

local statusb = luci.util.exec("sms_tool -s".. smsmem .. " -d ".. devv .. " status")

local smsnum = string.sub (statusb, 23, 27)

local smscount = string.match(smsnum, '%d+')

m = Map("sms_tool", translate("Cấu hình công cụ SMS"),
	translate("Bảng cấu hình cho ứng dụng sms_tool và gui。"))

s = m:section(NamedSection, 'general' , "sms_tool" , "" .. translate(""))
s.anonymous = true
s:tab("sms", translate("Cài đặt tin nhắn SMS"))
s:tab("ussd", translate("Cài đặt mã USSD"))
s:tab("at", translate("Cài đặt lệnh AT"))
s:tab("info", translate("Thông Tin"))

this_tab = "sms"

dev1 = s:taboption(this_tab, Value, "readport", translate("Cổng đọc tin nhắn"))
if try_devices1 then
local node
for node in try_devices1 do
dev1:value(node, node)
end
end

mem = s:taboption(this_tab, ListValue, "storage", translate("Khu vực lưu trữ thông tin"), translate("Thông tin được lưu trữ tại một vị trí cụ thể (ví dụ: trong thẻ SIM hoặc bộ nhớ của modem), nhưng tùy theo loại thiết bị, các khu vực khác cũng có thể khả dụng."))
mem.default = "SM"
mem:value("SM", translate("Thẻ SIM"))
mem:value("ME", translate("Bộ nhớ của modem"))
mem.rmempty = true

local msm = s:taboption(this_tab, Flag, "mergesms", translate("Hợp nhất các tin nhắn bị chia tách"), translate("Chọn tùy chọn này sẽ làm cho việc đọc tin nhắn dễ dàng hơn, nhưng sẽ gây ra sự không nhất quán về số lượng tin nhắn hiển thị và nhận được."))
msm.rmempty = false

dev2 = s:taboption(this_tab, Value, "sendport", translate("Cổng gửi tin nhắn"))
if try_devices2 then
local node
for node in try_devices2 do
dev2:value(node, node)
end
end

local t = s:taboption(this_tab, Value, "pnumber", translate("Tiền tố số điện thoại"), translate("Số điện thoại nên có tiền tố của quốc gia (ví dụ: 48 cho Ba Lan, không có '+'). Nếu số có 5, 4 hoặc 3 ký tự, nó sẽ được coi là 'ngắn' và không nên thêm tiền tố quốc gia."))
t.rmempty = true
t.default = 48

local f = s:taboption(this_tab, Flag, "prefix", translate("Thêm tiền tố vào số điện thoại"), translate("Tự động thêm tiền tố vào trường số điện thoại."))
f.rmempty = false

local i = s:taboption(this_tab, Flag, "information", translate("Giải thích số và tiền tố"), translate("Hiển thị giải thích tiền tố và số điện thoại chính xác trong tab gửi tin nhắn."))
i.rmempty = false

local ta = s:taboption(this_tab, TextValue, "user_phonebook", translate("Danh bạ người dùng"), translate("Mỗi dòng phải có định dạng sau: 'Tên liên hệ;Số điện thoại'. Lưu vào file '/etc/config/phonebook.user'."))
ta.rows = 7
ta.rmempty = false

function ta.cfgvalue(self, section)
    return fs.readfile(PHB_FILE_PATH)
end

function ta.write(self, section, value)
    value = value:gsub("\r\n", "\n")
    fs.writefile(PHB_FILE_PATH, value)
end

this_taba = "ussd"

dev3 = s:taboption(this_taba, Value, "ussdport", translate("Cổng gửi USSD"))
if try_devices3 then
local node
for node in try_devices3 do
dev3:value(node, node)
end
end

local u = s:taboption(this_taba, Flag, "ussd", translate("Gửi mã USSD bằng văn bản thuần túy"), translate("Gửi mã USSD bằng văn bản thuần túy. Lệnh không được mã hóa vào PDU."))
u.rmempty = false

local p = s:taboption(this_taba, Flag, "pdu", translate("Nhận tin nhắn không giải mã PDU"), translate("Nhận và hiển thị tin nhắn mà không giải mã chúng thành PDU."))
p.rmempty = false

local tb = s:taboption(this_taba, TextValue, "user_ussd", translate("Mã USSD của người dùng"), translate("Mỗi dòng phải có định dạng sau: 'Tên mã;Mã'. Lưu vào file '/etc/config/ussd.user'."))
tb.rows = 7
tb.rmempty = true

function tb.cfgvalue(self, section)
    return fs.readfile(USSD_FILE_PATH)
end

function tb.write(self, section, value)
    value = value:gsub("\r\n", "\n")
    fs.writefile(USSD_FILE_PATH, value)
end

this_tabc = "at"

dev4 = s:taboption(this_tabc, Value, "atport", translate("Cổng gửi lệnh AT"))
if try_devices4 then
local node
for node in try_devices4 do
dev4:value(node, node)
end
end

local tat = s:taboption(this_tabc, TextValue, "user_at", translate("Lệnh AT của người dùng"), translate("Mỗi dòng phải có định dạng sau: 'Tên lệnh AT;Lệnh AT'. Lưu vào file '/etc/config/atcmds.user'."))
tat.rows = 20
tat.rmempty = true

function tat.cfgvalue(self, section)
    return fs.readfile(AT_FILE_PATH)
end

function tat.write(self, section, value)
    value = value:gsub("\r\n", "\n")
    fs.writefile(AT_FILE_PATH, value)
end

this_tabb = "info"

local uw = s:taboption(this_tabb, Flag, "lednotify", translate("Thông báo tin nhắn mới"), translate("LED thông báo có tin nhắn mới. Trước khi kích hoạt tính năng này, hãy cấu hình và lưu cổng đọc tin nhắn, kiểm tra thời gian hộp thư đến và chọn LED thông báo."))
uw.rmempty = false

function uw.write(self, section, value)
if devv ~= nil or devv ~= '' then
if ( smscount ~= nil and led ~= nil ) then
    if value == '1' then

       luci.sys.call("echo " .. smscount .. " > /etc/config/sms_count")
	luci.sys.call("uci set sms_tool.general.lednotify=" .. 1 .. ";/etc/init.d/smsled enable;/etc/init.d/smsled start")
	luci.sys.call("/sbin/cronsync.sh")

    elseif value == '0' then
       luci.sys.call("uci set sms_tool.general.lednotify=" .. 0 .. ";/etc/init.d/smsled stop;/etc/init.d/smsled disable")
	    if dsled == 'D' then
		luci.sys.call("echo 0 > '/sys/class/leds/" .. led .. "/brightness'")
	    end
	luci.sys.call("/sbin/cronsync.sh")

    end
return Flag.write(self, section ,value)
  end
end
end

local time = s:taboption(this_tabb, Value, "checktime", translate("Kiểm tra hộp thư đến mỗi (bao nhiêu) phút"), translate("Chỉ định số phút bạn muốn kiểm tra hộp thư đến."))
time.rmempty = false
time.maxlength = 2
time.default = 5

function time.validate(self, value)
	if ( tonumber(value) < 60 and tonumber(value) > 0 ) then
	return value
	end
end

sync = s:taboption(this_tabb, ListValue, "prestart", translate("Khởi động lại chương trình kiểm tra hộp thư đến theo định kỳ"), translate("Quá trình này sẽ khởi động lại tại khoảng thời gian đã chọn. Điều này sẽ loại bỏ độ trễ trong việc kiểm tra hộp thư đến."))
sync.default = "6"
sync:value("4", translate("4h"))
sync:value("6", translate("6h"))
sync:value("8", translate("8h"))
sync:value("12", translate("12h"))
sync.rmempty = true

leds = s:taboption(this_tabb, Value, "smsled", translate("LED thông báo"), translate("Chọn LED thông báo."))
if try_leds then
local node
local status
for node in try_leds do
local status = node
local all = string.sub (status, 17)
leds:value(all, all)
end
end

oled = s:taboption(this_tabb, ListValue, "ledtype", translate("LED này chỉ dùng riêng cho các thông báo này"), translate("Nếu router chỉ có một LED hoặc LED là đa nhiệm, chọn 'No'."))
oled.default = "D"
oled:value("S", translate("No"))
oled:value("D", translate("Yes"))
oled.rmempty = true

local timeon = s:taboption(this_tabb, Value, "ledtimeon", translate("Mở LED mỗi (bao nhiêu) giây"), translate("Chỉ định thời gian LED nên bật."))
timeon.rmempty = false
timeon.maxlength = 3
timeon.default = 1

local timeoff = s:taboption(this_tabb, Value, "ledtimeoff", translate("Tắt LED mỗi (bao nhiêu) giây"), translate("Chỉ định thời gian LED nên tắt."))
timeoff.rmempty = false
timeoff.maxlength = 3
timeoff.default = 5

return m
