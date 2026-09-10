---
title: Dựng lại mutation cores từ Loi.xlsx
status: done
priority: P1
effort: large
branch: current-working-tree
tags: [edopro, lua, mutation-cores]
created: 2026-09-10
---

# Kế hoạch dựng lại mutation cores từ `Loi.xlsx`

## Mục tiêu

Thay toàn bộ 19 lõi cũ bằng 38 lõi trong `D:\AI\MDMayHem\Loi.xlsx`, triển khai
tuần tự từng lõi và kiểm chứng từng bước bằng Lua harness trước khi chuyển sang
lõi tiếp theo. Tên `sheet_name` phải giữ nguyên từng ký tự như cột `Name` trong
Excel, kể cả lỗi chính tả.

## Đầu ra cuối cùng

- `cores.json`: chỉ còn 38 lõi mới trong catalogue; mã cũ `1–19` được ghi nhận
  là đã nghỉ và không bao giờ được tái sử dụng; lõi mới dùng mã `20–57`.
- `src/cores/*.lua`: xóa script lõi cũ, thêm một script cho mỗi lõi mới.
- `tools/test-cores.lua`: bỏ test hành vi cũ, thêm test riêng cho từng lõi mới
  và giữ các test bất biến của bootstrap/LP code.
- `tools/build-catalogue.py` và `tools/test-tooling.py`: kiểm tra mã mới không
  trùng mã đang dùng hoặc mã đã nghỉ.
- `install/generated/*`: được tạo lại bằng generator, không sửa tay.
- `docs/writing-a-core.md`: cập nhật helper/recipe mới nếu việc triển khai cần
  mở rộng `src/runtime/mayhem_engine.lua`.
- `src/runtime/mayhem_engine.lua`: thêm helper thông báo energy nếu thử nghiệm
  xác nhận kênh hiển thị hoạt động trên client thật.

## Tiêu chí hoàn thành

1. Mỗi dòng Excel ánh xạ đúng một entry catalogue và một script có thể load.
2. Mọi luật áp dụng đối xứng cho hai người chơi, trừ khi mô tả nói rõ theo turn
   player, controller hoặc opponent.
3. Hành động bắt buộc sẽ thực hiện tối đa số lượng có thể khi Deck/hand/field
   không đủ tài nguyên; không làm duel lỗi Lua.
4. Mỗi lõi có test dương, test biên quan trọng và test không ảnh hưởng sai đối
   tượng; test lõi phải pass trước khi bắt đầu lõi kế tiếp.
5. `python tools/build-catalogue.py`, `lua tools/test-cores.lua`,
   `python -m unittest tools/test-tooling.py` và `python tools/make-package.py`
   đều pass ở checkpoint cuối.
6. Mỗi effect/API mới phải được đối chiếu với `constant.lua` và ít nhất một
   script chính thức trong EDOPro; các cơ chế rủi ro cao phải chạy
   `tools/run-duel.py --code <code>` bằng Python 32-bit.
7. Encoded LP luôn được trả về LP thật, kể cả code không hợp lệ; duel thường
   không dùng code vẫn giữ stock rules.

## Ngoài phạm vi

- Không sửa client EDOPro, card scripts stock, giao diện, `.cdb` hoặc web-app.
- Không tự động cấu hình room online; plugin chỉ chạy ở LAN-hosted room.
- Không sửa nội dung `Loi.xlsx`.
- Không commit/push nếu chưa có yêu cầu riêng.

## Quy ước hành vi cần duyệt

- “Deck” nghĩa là Main Deck; chỉ gồm Extra Deck khi mô tả nói rõ.
- Khi nhiều quái cùng ATK thấp nhất/cao nhất, tất cả quái đồng hạng cùng nhận
  luật miễn nhiễm; với luật phải chọn đúng một quái để destroy, controller chọn.
- Xếp hạng ATK chỉ tính quái face-up; ATK của quái face-down không phải thông
  tin công khai để core so sánh.
- “Add/draw N card” tính theo số lá thực tế đi vào tay, không tính normal draw ở
  Draw Phase; activation/summon bị negate vẫn tính là một lần đã dùng quota.
- “There can be only one kind” được hiểu là mỗi người chơi chỉ được thực hiện
  một lần cho từng loại Fusion/Synchro/Xyz/Link Summon trong cả duel.
- Các hiệu ứng “mỗi End/Standby Phase, mỗi người chơi...” xử lý turn player
  trước, rồi opponent; người chơi được chọn card của chính họ khi có nhiều đáp án.
- “Summon từ Deck/Extra/GY” là Special Summon face-up theo luật engine; không
  bỏ qua điều kiện triệu hồi trừ khi mô tả yêu cầu rõ ràng.
- `Energy Dominate`: mỗi người bắt đầu với 12/12 energy; khi vào Standby Phase
  của người nào thì energy của riêng người đó được hồi đầy về 12. Một lần
  Special Summon hoặc activate Spell/Trap thường tốn 2; Quick Effect,
  Quick-Play Spell và Counter Trap tốn 4 (mức 4 được ưu tiên, không cộng dồn
  thành 6). Không cho phép khai báo hành động nếu energy còn lại thấp hơn cost.

## Pha 0 — thay catalogue nhưng bảo toàn mã đã phát hành

1. Thêm `retired_codes` vào `cores.json` cho mã `1–19`, kèm tên cũ để audit.
2. Thay mảng `cores` bằng 38 entry mới ở trạng thái `planned`, mã `20–57`.
3. Mở rộng generator để từ chối mã trùng `retired_codes`; thêm regression test.
4. Xóa tám script lõi cũ và các test hành vi cũ; giữ test bootstrap/LP chung,
   đổi chúng sang code mới khi lõi đầu tiên được bật.
5. Chạy generator và test tooling. Chưa cài vào game ở trạng thái trung gian.

## Pha 1 — triển khai tuần tự các lõi trực tiếp

Mỗi mục theo cùng một vòng: tìm idiom chính thức → viết script → thêm stub cần
thiết cho harness → thêm test → đổi entry từ `planned` sang `implemented` hoặc
`partial` → build catalogue → chạy toàn bộ Lua tests.

| Thứ tự | Code | Tên Excel | Script id | Cơ chế dự kiến |
| ---: | ---: | --- | --- | --- |
| 1 | 20 | Plan Ahead of Time | `20_plan_ahead_of_time` | Hand 0 lúc startup, khóa normal draw, Standby chọn tối đa 2 lá từ Deck lên tay. |
| 2 | 21 | Only The Strong Survie | `21_only_the_strong_survive` | End Phase, mỗi controller chọn một quái có ATK nhỏ nhất của mình để destroy. |
| 3 | 22 | Raw force no strategy | `22_raw_force_no_strategy` | `EFFECT_CANNOT_MSET` + `EFFECT_CANNOT_SSET` cho cả hai người. |
| 4 | 23 | Stop hitting me | `23_stop_hitting_me` | Bộ đếm attack announce theo turn; sau quái đầu tiên, quái khác không thể declare attack. |
| 5 | 24 | It should has been mine | `24_it_should_have_been_mine` | `EVENT_PREDRAW` mill top 1 trước normal draw. |
| 6 | 25 | This sound familiar | `25_this_sound_familiar` | Startup validator: Main Deck có duplicate code thì thua. |
| 7 | 26 | There can be only one kind | `26_there_can_be_only_one_kind` | Ghi nhận Fusion/Synchro/Xyz/Link summon type đã dùng theo player và chặn loại đã dùng. |
| 8 | 27 | Keep drawing | `27_keep_drawing` | End Phase, mỗi người draw đến khi hand đạt 5. |
| 9 | 28 | Leaking Vrain | `28_leaking_vrain` | Startup, mỗi người chọn một Link hợp lệ trong Extra Deck để Special Summon. |
| 10 | 29 | Strength of the weak | `29_strength_of_the_weak` | Dynamic immunity cho toàn bộ quái đồng hạng ATK thấp nhất khi field có ≥2 quái. |
| 11 | 30 | Be more efficient | `30_be_more_efficient` | `EFFECT_MAX_MZONE=3` và `EFFECT_MAX_SZONE=3`. |
| 12 | 31 | Droll and Lock Bird is looking at you | `31_droll_lock_limit` | Đếm card vào hand ngoài normal draw, chặn add/draw sau quota 5. |
| 13 | 32 | You have to be quick | `32_you_have_to_be_quick` | Startup LP 10000; mỗi End Phase set lại chính xác 10000. |
| 14 | 33 | Recycling | `33_recycling` | End Phase trả các card hợp lệ từ GY/banished của cả hai về Deck và shuffle. |
| 15 | 34 | Verre's Wand Bạc | `34_verres_wand_silver` | Pre-damage calculation: controller tùy chọn reveal Spell trên tay, +500 ATK/lá đến hết Damage Step. |
| 16 | 35 | First turn advantage bạc | `35_first_turn_advantage_silver` | Draw Phase đầu chỉ draw 1; trong first turn riêng, effect do player đó activate không thể bị opponent negate activation/effect. |
| 17 | 36 | You can only use ONCE | `36_you_can_only_use_once` | Sau khi chain link của card/effect resolve, banish face-down mọi copy cùng original code trong hand/Main Deck của controller. |
| 18 | 37 | Create your own Victory | `37_create_your_own_victory` | `EVENT_ADJUST`: thắng khi có ≥5 tên khác nhau, mỗi tên ≥3 bản trong field/GY/face-up banished. |
| 19 | 38 | This card is trash | `38_this_card_is_trash` | Negate activation đầu tiên của mỗi player trong mỗi turn. |
| 20 | 39 | Mirror Mirror on the Wall | `39_mirror_mirror_on_the_wall` | Khi summon quái, tạo Token trên field đối phương với ATK bằng quái đó. |
| 21 | 40 | Clash of the Titan | `40_clash_of_the_titan` | End Phase destroy toàn bộ quái, cộng ATK, tạo Titan Token cho turn player; khóa material/tribute và miễn nhiễm ngoài core. |
| 22 | 41 | Unexpected Arrival | `41_unexpected_arrival` | Thay normal draw bằng chọn một monster hợp lệ trong Deck để Special Summon. |
| 23 | 42 | Shared Pain | `42_shared_pain` | Mirror effect/rule damage sang opponent, có cờ chống recursion. |
| 24 | 43 | What is it gonna be? | `43_what_is_it_gonna_be` | End Phase, mỗi người chọn Spell/Trap không phải Counter Trap từ Deck để Set; card đó nhận immunity. |
| 25 | 44 | Restricted Gambling | `44_restricted_gambling` | Draw Phase roll d6; cùng quota cho activation và tổng summon của mỗi player đến hết turn. |
| 26 | 45 | Litterally just Mulligan | `45_literally_just_mulligan` | Standby, mỗi người tùy chọn shuffle toàn hand vào Deck rồi draw lại đúng số đó. |
| 27 | 46 | Once Punch | `46_once_punch` | Quái đầu tiên declare attack trong mỗi Battle Phase nhận x2 ATK ở Damage Step. |
| 28 | 47 | Back From the Grave | `47_back_from_the_grave` | End Phase, mỗi người chọn một monster hợp lệ trong GY để Special Summon. |
| 29 | 48 | Gift from your Enemy | `48_gift_from_your_enemy` | Standby, mỗi người chọn monster trong Deck mình để Special Summon sang field đối phương. |
| 30 | 49 | Rock Paper Scissors | `49_rock_paper_scissors` | Monster miễn nhiễm Spell, Spell miễn nhiễm Trap, Trap miễn nhiễm Monster theo nguồn effect. |
| 31 | 51 | Fucking Quick-Play | `51_quick_play_owner_turn` | Chặn activation Quick-Play Spell khi không phải turn của controller. |
| 32 | 53 | Boss is alway Boss | `53_boss_is_always_boss` | Dynamic immunity cho toàn bộ quái đồng hạng ATK cao nhất. |
| 33 | 54 | Break the Loop | `54_break_the_loop` | End Phase gửi mọi Continuous Spell/Trap đang face-up xuống GY bằng rule. |
| 34 | 55 | Gambling Gambling | `55_gambling_draw` | Thay normal draw: roll d6 rồi cả hai người draw bằng kết quả. |
| 35 | 57 | Magic consume bạc | `57_magic_consume_silver` | Global activation cost cho monster effect: reveal một Spell trên hand còn dưới quota 3; lưu số lần trên chính card đó. |

## Pha 2 — lõi cần prototype/giới hạn ngoài Lua

Các lõi này vẫn làm theo thứ tự Excel, nhưng chỉ đổi sang `implemented` sau khi
`run-duel.py` chứng minh hành vi thật. Nếu engine không hỗ trợ trọn vẹn, giữ
`partial` và ghi yêu cầu thủ công rõ trong `Mayhem-codes.txt`.

| Thứ tự | Code | Tên Excel | Script id | Kế hoạch/giới hạn |
| ---: | ---: | --- | --- | --- |
| 36 | 50 | yugiH5 Comeback | `50_yugih5_comeback` | Prototype bỏ BP và gọi battle ngay sau summon. Nếu core không cho battle ngoài BP hoặc không xử lý direct attack hợp lệ, triển khai phần turn 1/turn 2 và đánh dấu `partial`. |
| 37 | 52 | Speed-duel Mentioned? | `52_speed_duel_mentioned` | Duel flags/field layout phải đặt trước khi Lua chạy. Ghi `room_settings.duel_mode = "speed"`; script chỉ startup-validate cấu hình và/hoặc phần mô phỏng an toàn. Trạng thái dự kiến `partial`. |
| 38 | 56 | Energy Dominate | `56_energy_dominate` | State riêng 12/12 cho mỗi player; hồi đầy player hiện tại ở Standby; dùng `EFFECT_SPSUMMON_COST` và `EFFECT_ACTIVATE_COST` để trừ 2/4 trước hành động và chặn khi thiếu; thông báo số còn lại sau mỗi lần hồi/tiêu. |

Lưu ý: thứ tự code vẫn theo Excel (`50`, `51`, `52`, ...); bảng tách pha chỉ để
phân biệt rủi ro. Khi thi công thực tế vẫn đi đúng code `20 → 57`.

### Kênh thông báo của Energy Dominate

EDOPro không có API Lua gửi chuỗi chat bình thường. Kế hoạch kiểm chứng hai kênh
trên client thật và dùng cả hai khi khả dụng:

1. `Duel.Hint(HINT_NUMBER, player, remaining)` để người chơi liên quan thấy số
   energy còn lại mà không cần chuỗi dịch hoặc custom card.
2. Helper `MAYHEM.AnnounceEnergy(player, remaining, reason)` gọi
   `Debug.Message` để ghi dòng `[MAYHEM ENERGY] ...` vào duel chat khi host đặt
   `coreLogOutput = 3`.

Kênh thứ hai bị client hiển thị màu đỏ dưới nhãn “Script Error”; đây là giới hạn
của EDOPro, không phải lỗi duel. Plugin không tự sửa `config/system.conf`, nên
`Mayhem-codes.txt` và tài liệu cài đặt sẽ ghi rõ host phải bật chat bit. Nếu
`run-duel.py` cho thấy `HINT_NUMBER` không đến được cả hai client, lõi vẫn dùng
debug-chat theo yêu cầu và được đánh dấu `partial` về mặt UX.

## Token không dùng passcode viết tay

Hai lõi code `39` và `40` cần Token. Trước khi viết script:

1. Tìm token phù hợp bằng tên tiếng Anh trong `cards.cdb` của client.
2. Thêm generator tạo file Lua constant từ database, thay vì chép số passcode
   vào source.
3. Test generator thất bại rõ ràng khi không tìm thấy/không duy nhất.
4. Đưa file constant đã generate vào cả `install.ps1` và package zip để hai cách
   cài luôn đồng bộ.

## Checkpoint sau mỗi lõi

1. `python tools/build-catalogue.py`
2. `lua tools/test-cores.lua`
3. Với effect/API chưa từng được plugin chứng minh: install rồi chạy
   `python tools/run-duel.py --code <code>` bằng Python 32-bit.
4. Chỉ khi checkpoint pass mới chuyển sang code kế tiếp.

## Checkpoint cuối

1. Review blast radius: bootstrap, generator, installer, uninstaller, package.
2. Chạy Lua tests, Python tooling tests, build package.
3. Cài vào game đã đóng, chạy engine smoke test cho toàn bộ nhóm effect mới.
4. Kiểm tra uninstall dry-run và uninstall thật không xóa file ngoài quyền sở hữu.
5. Cập nhật tài liệu và báo rõ mọi lõi `partial` còn yêu cầu room setting/thao tác thủ công.

## Trạng thái thực hiện

- Hoàn tất catalogue 38/38 lõi mới, mã `20–57`; mã cũ `1–19` đã nghỉ và bị
  generator chặn tái sử dụng.
- Hoàn tất 38 script theo đúng thứ tự Excel; 35 `implemented`, 3 `partial`
  (`Droll and Lock Bird is looking at you`, `yugiH5 Comeback`,
  `Speed-duel Mentioned?`) với giới hạn được in trong `Mayhem-codes.txt`.
- `Energy Dominate` dùng 12 energy mỗi người, hồi riêng ở Standby của người đó,
  trừ 2/4 theo hành động và thông báo sau mỗi lần tiêu/hồi.
- Checkpoint offline, tooling, package và engine smoke test đã chạy; checkpoint
  cuối đã hoàn tất: Lua `22/22`, tooling `8/8`, package `47` file, engine thật
  `38/38` mã được apply. Client đích có đúng 38 module mới và không còn tám
  module lõi cũ.

## Pha 3 — tiền tố mã trong tên file

- [x] Đổi 38 core ID/file sang dạng `<code>_<id>.lua`, giữ nguyên mã LP và tên Excel.
- [x] Đồng bộ `cores.json`, `MAYHEM.Register`, tests, catalogue, installer và package.
- [x] Chạy lại spec review, code review độc lập và toàn bộ release gate trước push.

Kết quả: `plans/reports/code-review-260910-1553-summon-ban-callbacks.md`.

Spec review sạch: 38 dòng `Loi.xlsx` khớp từng ký tự với `cores.json` (tên, mô
tả, mã `19+n`).

Code review tìm ba lỗi cùng một nguyên nhân — engine không đọc mọi luật cấm từ
`value` của effect. Đã đối chiếu source `edo9300/ygopro-core`, không suy đoán:

- `26_there_can_be_only_one_kind`: predicate nằm ở `value` của
  `EFFECT_CANNOT_SPECIAL_SUMMON`, mà `field::is_player_can_spsummon` chạy
  `if(!eff->target) return FALSE` → **cấm Special Summon toàn trận**.
- `44_restricted_gambling`: cùng lỗi trên `EFFECT_CANNOT_SUMMON`,
  `_FLIP_SUMMON`, `_SPECIAL_SUMMON` → **cấm mọi Summon từ lượt 1**, xúc xắc vô
  nghĩa.
- `31_droll_lock_limit`: `EFFECT_CANNOT_DRAW` chỉ được kiểm tra theo sự tồn tại
  (`is_player_affected_by_effect`), không gọi callback → **chặn mọi draw bằng
  hiệu ứng toàn trận**, bỏ qua quota.

Sửa: thêm helper `MAYHEM.PlayerRestriction(code, predicate)` đặt predicate vào
`target` cho ba mã summon; core 31 đăng ký khóa draw theo từng người khi hết
quota rồi `Effect.Reset()` ở Draw Phase kế tiếp. Đã ghi bảng "callback nào cho
mã nào" vào `docs/edopro-integration.md` §3 và bẫy tương ứng vào
`docs/writing-a-core.md`.

Chứng minh trên engine thật (probe code 26, đã xóa sau khi đo):
`Duel.IsPlayerCanSpecialSummon` = `false` với shape cũ, `true` với shape mới.

Release gate: catalogue 38, Lua `24/24`, tooling `10/10`, package 47 file,
engine thật `38/38` mã apply không lỗi, LP invariant giữ nguyên, uninstall
dry-run chỉ chạm file thuộc quyền plugin.
