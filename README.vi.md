# MD Mayhem — lõi đột biến cho EDOPro

*[English](README.md)*

Luật đấu tùy biến cho [EDOPro / Project Ignis](https://projectignis.github.io/),
chọn theo từng ván bằng cách gõ một con số vào ô **Starting LP** trong cửa sổ
Host.

Một "lõi đột biến" là một luật: *tối đa 5 lần Special Summon mỗi lượt*, *ai nhận
sát thương chiến đấu trước thì thua*, *cấm kích hoạt Spell*. Giải đấu roll một
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

Giải nén đè lên thư mục EDOPro, giữ nguyên cấu trúc. Vậy là xong; plugin thuần
Lua, không có gì phụ thuộc hệ điều hành.

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

| Starting LP | Lõi | Cấp | Luật |
| --- | --- | --- | --- |
| 1000001 | Tốc Chiến Bạc | Bạc | LP khởi đầu 6000 |
| 1000002 | Hạn Điền Bạc | Bạc | tối đa 7 lần Special Summon mỗi lượt |
| 1000003 | Tiết Kiệm Bạc | Bạc | rút 2 lá mỗi lượt |
| 1000004 | Mỏng Manh Bạc | Bạc | bài khởi đầu 4 lá |
| 1000005 | Năng Lượng Bạc | Bạc | người đến lượt hồi 1000 LP mỗi Standby |
| 1000006 | Giới Hạn Bạc | Bạc | Extra Deck tối đa 10 lá |
| 1000007 | Tốc Chiến Vàng | Vàng | LP khởi đầu 4000 |
| 1000008 | Hạn Điền Vàng | Vàng | tối đa 5 lần Special Summon mỗi lượt |
| 1000009 | Tiết Kiệm Vàng | Vàng | không được rút bài đầu lượt |
| 1000010 | Mỏng Manh Vàng | Vàng | bài khởi đầu 3 lá |
| 1000012 | Giới Hạn Vàng | Vàng | Extra Deck tối đa 6 lá |
| 1000013 | Tử Chiến | Kim Cương | LP khởi đầu 2000 |
| 1000015 | Nhất Kích | Kim Cương | ai nhận sát thương chiến đấu trước thì thua |
| 1000016 | Tay Không | Kim Cương | bài khởi đầu 1 lá |
| 1000018 | Phong Ấn | Kim Cương | cấm kích hoạt Spell |

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
MAYHEM.Register("my_core", {
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
python tools/run-duel.py --code 8       # nạp ocgcore.dll thật của client
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
- **Không có cách hiện chữ cho người chơi.** Client không có handler cho message
  hint của core, nên chỉ số máu là dấu hiệu nhìn thấy được duy nhất.
- Bốn lõi trong `cores.json` đã đặc tả nhưng chưa viết; cơ chế dự định ghi ngay
  trong entry.

## Cấu trúc

```
cores.json          registry: mã → đột biến, script, tham số
src/runtime/        bootstrap, helper engine, config vận hành
src/cores/          mỗi lõi một file; tên file chính là id của lõi
install/            entry point cho ván đấu, nguồn banlist
tools/              cài, gỡ, generator, test, trình chạy duel headless
docs/               hướng dẫn viết lõi và các phát hiện engine đã kiểm chứng
```

Đi kèm web app roller MD Mayhem, nơi quyết định ván đấu chạy lõi nào.
`sheet_name` trong `cores.json` là điểm nối giữa hai bên.
