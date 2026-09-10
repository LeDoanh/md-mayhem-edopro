# MD Mayhem — lõi đột biến cho EDOPro

*[English](README.md)*

Luật đấu tùy biến cho [EDOPro / Project Ignis](https://projectignis.github.io/),
chọn theo từng ván bằng cách gõ một con số vào ô **Starting LP** trong cửa sổ
Host.

Một "lõi đột biến" là một luật: *bắt đầu không có bài và lấy bài ở Standby*,
*mỗi lượt chỉ một quái được tấn công*, *hành động tiêu hao Energy*. Giải đấu roll một
lõi trước mỗi ván; plugin này khiến client tự thực thi luật đó, nên không ai
phải đếm summon bằng tay hay soi lại replay.

Không sửa gì trong client. Không ghi đè script bài, không thay mode có sẵn,
không đổi chữ trong giao diện — EDOPro vẫn dùng bình thường được, và trình gỡ
trả lại nguyên trạng.

## Yêu cầu

- EDOPro (bản gần đây bất kỳ; phát triển trên bản 2026-04-20)
- **Chỉ người host ván đấu mới cần cài.** EDOPro chạy duel core trên máy host,
  nên luật của host là luật cả hai bên chơi theo.
- **Chỉ phòng LAN.** Phòng host qua Online Multiplayer chạy trên server của họ,
  nơi plugin không tồn tại.

## Cài đặt

**Windows**

```powershell
powershell -ExecutionPolicy Bypass -File tools\install.ps1
```

Lần đầu nó hỏi dùng bản EDOPro nào rồi nhớ luôn. Cài xong **khởi động lại
EDOPro** — nó chỉ quét plugin lúc khởi động.

**Android, Linux, macOS, hoặc đưa cho host khác**

```bash
python tools/make-package.py     # tạo dist/mdmayhem-<version>.zip
```

Đọc `README.txt` trong package trước khi giải nén. Lần cài đầu phải bảo toàn
`init.lua` của công cụ khác; khi nâng cấp thì ghi đè loader Mayhem hiện tại nhưng
không thay backup gốc trước khi cài Mayhem. Hãy giữ lại `mayhem_config.lua` nếu
đã tùy chỉnh, xóa thư mục plugin cũ, giải nén rồi phục hồi config để các module
lõi đã nghỉ hưu không còn sót lại.

## Cách dùng

Không có menu. Chọn lõi bằng cách gõ số vào

```
LAN mode → Create Host → tab Duel → Starting LP = 1000000 + mã lõi
```

Lõi được chọn sẽ đặt LP thật khi ván bắt đầu. **Chỉ số máu nhảy từ con số bạn gõ
về giá trị thật chính là dấu hiệu plugin đã chạy.** LP bình thường thì plugin
không đụng tới, nên game thường và đấu AI không bị ảnh hưởng.

Danh sách đầy đủ nằm ở `Mayhem-codes.txt` cạnh `EDOPro.exe`, hoặc chạy
`python tools/list-codes.py`.

Mã `1–19` đã nghỉ hưu vĩnh viễn. Catalogue hiện có 38 lõi với mã `20–57`;
hãy dùng danh sách được generator tạo thay vì chép lại một bảng tĩnh trong tài
liệu.

Banlist cấm floodgate cố định của giải nằm ở
`lflists/Mayhem_Tactical.lflist.conf`; chọn nó ở ô Rule của phòng.

## Cơ chế

EDOPro nạp `<game>/init.lua` vào **mọi** ván đấu nó tạo. File đó nạp plugin, và
plugin cài mỗi luật thành một global effect — đúng cơ chế `proc_skill.lua` của
chính client dùng, nên không cần custom card hay bản ghi database nào.

Chỉ có năm giá trị đi từ room settings xuống duel core, và `startingLP` là số
nguyên 32-bit không bị chặn. Đó là kênh duy nhất đủ rộng để chở lựa chọn — lý do
lõi được chọn bằng cách gõ số chứ không phải bấm nút: giao diện EDOPro biên dịch
cứng trong exe, không mở rộng được nếu không fork client.

`docs/edopro-integration.md` ghi lại mọi hook engine mà plugin dựa vào, kèm
nguồn source đã đối chiếu.

## Thêm lõi mới

Một file trong `src/cores/`, một entry trong `cores.json`:

```lua
-- Với mã chưa dùng tiếp theo là 58:
MAYHEM.Register("58_my_core", {
    defaults = { some_number = 5 },
    apply = function(params)
        MAYHEM.FieldRule(EFFECT_X, params.some_number, true)
    end,
})
```

**[docs/writing-a-core.md](docs/writing-a-core.md)** là hướng dẫn đầy đủ: công
thức theo từng dạng luật, API helper, cách tra effect code chưa biết, cách test,
và những cạm bẫy đã thực sự cắn.

Hai lớp kiểm tra:

```bash
lua tools/test-cores.lua                # offline, ~1 giây, kiểm tra đấu nối
python tools/run-duel.py --code 20      # nạp ocgcore.dll thật của client
```

`run-duel.py` cần Python 32-bit vì EDOPro là 32-bit:
`uv python install cpython-3.12-windows-x86`.

## Gỡ cài đặt

```powershell
powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1 -WhatIf   # chạy thử
powershell -ExecutionPolicy Bypass -File tools\uninstall.ps1
```

Chỉ gỡ đúng những gì trình cài đã ghi. `init.lua` của công cụ khác sẽ được nhận
ra và giữ nguyên.

## Giới hạn đã biết

- **Không script được đồng hồ.** Time limit là room setting host tự chọn; mỗi
  lõi ghi sẵn giá trị nên dùng trong `cores.json`.
- **Luật dựng deck không chặn được lúc build deck.** Bộ kiểm tra deck của EDOPro
  nằm phía client nên giới hạn số lá Extra/Main được thực thi bằng cách xử thua
  ngay đầu ván.
- **Không có kênh chữ tổng quát cho người chơi.** Energy Dominate chủ động dùng
  numeric hint và script chat; đặt `coreLogOutput=3` để thấy số dư trong chat.
- Ba entry được đánh dấu `partial`; giới hạn engine và room setting cần thiết
  được ghi rõ trong `Mayhem-codes.txt`.

## Cấu trúc

```
cores.json          registry: mã → đột biến, script, tham số
src/runtime/        bootstrap, helper engine, config vận hành
src/cores/          mỗi lõi một file, tên dạng <mã>_<id>.lua
install/            entry point cho ván đấu, nguồn banlist
tools/              cài, gỡ, generator, test, trình chạy duel headless
docs/               hướng dẫn viết lõi và các phát hiện engine đã kiểm chứng
```

Đi kèm web app roller MD Mayhem, nơi quyết định ván đấu chạy lõi nào.
`sheet_name` trong `cores.json` là điểm nối giữa hai bên.
