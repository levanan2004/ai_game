#!/usr/bin/env python3
"""Three player archetypes vs An's income/fixed-cost table (values in 1000 xu)."""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E = json.loads((ROOT / "assets/data/economy.json").read_text(encoding="utf-8"))

START = E["start"]["cash"]
UPGRADES = {u["id"]: u for u in E["upgrades"]}
UPGRADE_ORDER = [
    "cold_storage",
    "wrapping_table",
    "display",
    "bench",
    "counter",
    "staff",
]


def upgrade_level_cost(uid: str, level: int) -> int:
    u = UPGRADES[uid]
    return u["levels"][level - 1]["cost"]


def max_level(uid: str) -> int:
    return len(UPGRADES[uid]["levels"])


# An's anchors (thu_k, co_dinh_k, lai_k) — medium / "chơi khá"
AN_THU = {
    10: 640,
    20: 1003,
    30: 1180,
    40: 1994,
    50: 2270,
    60: 2450,
    70: 2449,
    80: 3222,
    90: 3222,
    100: 3220,
    110: 3222,
    120: 3738,
    130: 3738,
    140: 3738,
    150: 3738,
    160: 3738,
    170: 3738,
    180: 3738,
    190: 3738,
    200: 3740,
}
AN_CO = {
    10: 60,
    20: 130,
    30: 135,
    40: 215,
    50: 220,
    60: 290,
    70: 370,
    80: 370,
    90: 490,
    100: 490,
    110: 490,
    120: 490,
    130: 490,
    140: 490,
    150: 490,
    160: 490,
    170: 490,
    180: 490,
    190: 490,
    200: 490,
}
AN_LAI = {d: AN_THU[d] - int(AN_THU[d] * 0.577) - AN_CO[d] for d in AN_THU}

PROFILE_THU = {
    "light": {
        10: 450,
        30: 830,
        50: 1590,
        100: 2250,
        200: 2620,
    },
    "medium": {d: AN_THU[d] for d in AN_THU},
    "skilled": {
        10: 830,
        30: 1530,
        50: 2950,
        100: 4190,
        200: 4860,
    },
}


def _interp(anchors: dict[int, int], day: int) -> int:
    keys = sorted(anchors)
    if day <= keys[0]:
        return anchors[keys[0]]
    if day >= keys[-1]:
        return anchors[keys[-1]]
    for i in range(len(keys) - 1):
        a, b = keys[i], keys[i + 1]
        if a <= day <= b:
            t = (day - a) / (b - a)
            return int(anchors[a] + t * (anchors[b] - anchors[a]))
    return anchors[keys[-1]]


def thu_k(profile: str, day: int) -> int:
    return _interp(PROFILE_THU[profile], day)


def co_dinh_k(day: int) -> int:
    return _interp(AN_CO, day)


def lai_k(profile: str, day: int) -> int:
    thu = thu_k(profile, day) * 1000
    co = co_dinh_k(day) * 1000
    nhap = int(thu * 0.577)
    return thu - nhap - co


def xu_goals() -> list[tuple[str, int]]:
    """After shop upgrades: pets (xu), zodiac pots, pet gear (proposal)."""
    goals: list[tuple[str, int]] = []
    pets = [
        (f"pet:{p['id']}", p["price"])
        for p in E["pets"]["list"]
        if p.get("currency", "coins") == "coins"
    ]
    pets.sort(key=lambda x: x[1])
    goals.extend(pets)
    pots = [
        (f"pot:{pot['id']}", pot["price"])
        for pot in E["pots"]
        if pot.get("set") == "chomSao" and pot.get("currency", "coins") == "coins"
    ]
    pots.sort(key=lambda x: x[1])
    goals.extend(pots)
    # 12 pet items: 3 thuong + 3 hiem (xu only in proposal)
    for i, slot in enumerate(["co", "dau", "phu_kien"], 1):
        goals.append((f"do_pet:thuong_{slot}", 80_000))
    for i, slot in enumerate(["co", "dau", "phu_kien"], 1):
        goals.append((f"do_pet:hiem_{slot}", 500_000))
    return goals


XU_GOALS = xu_goals()
TOTAL_XU_GOALS = sum(c for _, c in XU_GOALS)


@dataclass
class ProfileRules:
    name: str
    label: str
    cold1_earliest: int
    cold_max: int
    counter_max: int
    staff_max: int
    buy_delay: int  # +days after medium calendar (light); skilled uses -buy_delay


RULES = {
    "light": ProfileRules(
        "light",
        "Chơi nhẹ",
        cold1_earliest=20,
        cold_max=2,
        counter_max=1,
        staff_max=3,
        buy_delay=10,
    ),
    "medium": ProfileRules(
        "medium",
        "Chơi khá (An)",
        cold1_earliest=8,
        cold_max=3,
        counter_max=2,
        staff_max=5,
        buy_delay=0,
    ),
    "skilled": ProfileRules(
        "skilled",
        "Chơi giỏi",
        cold1_earliest=5,
        cold_max=3,
        counter_max=2,
        staff_max=5,
        buy_delay=15,
    ),
}

# Calendar: first day medium archetype *would* buy each level (from prior sim)
MEDIUM_CAL: dict[tuple[str, int], int] = {
    ("cold_storage", 1): 10,
    ("wrapping_table", 1): 10,
    ("display", 1): 10,
    ("wrapping_table", 2): 20,
    ("bench", 1): 20,
    ("bench", 2): 55,
    ("bench", 3): 70,
    ("staff", 1): 20,
    ("cold_storage", 2): 30,
    ("counter", 1): 30,
    ("wrapping_table", 3): 40,
    ("display", 2): 40,
    ("staff", 2): 40,
    ("cold_storage", 3): 50,
    ("display", 3): 50,
    ("bench", 3): 50,
    ("counter", 2): 60,
    ("staff", 3): 60,
    ("staff", 4): 70,
    ("staff", 5): 90,
}


def allowed_day(rules: ProfileRules, uid: str, level: int) -> int:
    base = MEDIUM_CAL.get((uid, level), 999)
    if uid == "cold_storage" and level == 1:
        base = max(base, rules.cold1_earliest)
    if rules.name == "skilled":
        return max(1, base - rules.buy_delay)
    if rules.name == "light":
        return base + rules.buy_delay
    return base


def cap_level(rules: ProfileRules, uid: str) -> int:
    if uid == "cold_storage":
        return rules.cold_max
    if uid == "counter":
        return rules.counter_max
    if uid == "staff":
        return rules.staff_max
    return max_level(uid)


@dataclass
class Purchase:
    day: int
    item: str
    cost: int
    lai_that_day: int

    @property
    def days_of_profit(self) -> float:
        return self.cost / self.lai_that_day if self.lai_that_day else 0


@dataclass
class SimResult:
    profile: str
    purchases: list[Purchase] = field(default_factory=list)
    levels: dict[str, int] = field(default_factory=dict)
    goal_idx: int = 0
    money: int = START
    money_by_day: dict[int, int] = field(default_factory=dict)

    def at_upgrade_cap(self) -> bool:
        rules = RULES[self.profile]
        for uid in UPGRADE_ORDER:
            cap = min(cap_level(rules, uid), max_level(uid))
            if self.levels.get(uid, 0) < cap:
                return False
        return True

    def try_spend(self, day: int, lai: int) -> None:
        reserve = 2 * co_dinh_k(day) * 1000
        changed = True
        while changed:
            changed = False
            rules = RULES[self.profile]
            for uid in UPGRADE_ORDER:
                cur = self.levels.get(uid, 0)
                cap = cap_level(rules, uid)
                if cur >= cap or cur >= max_level(uid):
                    continue
                nxt = cur + 1
                if day < allowed_day(rules, uid, nxt):
                    continue
                if uid == "staff" and nxt >= 2:
                    req = UPGRADES["staff"]["levels"][nxt - 1].get("effect", {}).get(
                        "requires", {}
                    )
                    if self.levels.get("counter", 0) < req.get("counter", 0):
                        continue
                cost = upgrade_level_cost(uid, nxt)
                if self.money - cost >= reserve:
                    self.money -= cost
                    self.levels[uid] = nxt
                    self.purchases.append(
                        Purchase(day, f"upgrade:{uid}@{nxt}", cost, lai)
                    )
                    changed = True
            if not self.at_upgrade_cap():
                break
            while self.goal_idx < len(XU_GOALS) and self.money - XU_GOALS[
                self.goal_idx
            ][1] >= reserve:
                name, cost = XU_GOALS[self.goal_idx]
                self.money -= cost
                self.purchases.append(Purchase(day, name, cost, lai))
                self.goal_idx += 1


def garden_spend(profile: str, day: int) -> int:
    if profile == "skilled" and day >= 20:
        return 65_000
    if profile == "light" and day >= 40:
        return 45_000
    return 0


def shipper_once(profile: str, day: int, hired: bool) -> tuple[int, bool]:
    if profile != "skilled" or hired or day < 8:
        return 0, hired
    return 200_000, True


def run(profile: str, max_day: int = 200, carry: SimResult | None = None) -> SimResult:
    r = carry or SimResult(profile=profile)
    start = max(r.money_by_day) + 1 if r.money_by_day else 1
    hired = getattr(r, "_shipper", False)
    for day in range(start, max_day + 1):
        lai = lai_k(profile, min(day, 200))
        r.money += lai
        cost, hired = shipper_once(profile, day, hired)
        r.money -= cost
        if cost:
            r.purchases.append(Purchase(day, "shipper:bike", cost, lai))
        r.money -= garden_spend(profile, day)
        r.try_spend(day, lai)
        r.money_by_day[day] = r.money
    r._shipper = hired  # type: ignore[attr-defined]
    return r


def report(r: SimResult, max_day: int = 1100) -> None:
    rules = RULES[r.profile]
    print(f"\n{'=' * 72}")
    print(f"{rules.label} ({r.profile})")
    print(f"Tổng mục tiêu xu (pet + chậu HĐ + đồ pet xu): {TOTAL_XU_GOALS // 1000}k")
    done = r.goal_idx
    print(f"Hoàn thành mục tiêu xu: {done}/{len(XU_GOALS)}")
    if done == len(XU_GOALS):
        last = next(p for p in reversed(r.purchases) if not p.item.startswith("upgrade:"))
        print(f"Xong hết mục tiêu xu: ngày {last.day}")
    elif done > 0:
        print(f"Đến ngày {max_day}: xong {done} món (còn {len(XU_GOALS) - done})")

    print("\nMốc thu / lãi / túi (nghìn xu):")
    for d in [10, 30, 50, 100, 200, 600, 700, 1000]:
        if d > max_day:
            continue
        ref = min(d, 200)
        tui = r.money_by_day.get(d, r.money) // 1000
        print(
            f"  ngày {d:4d}: thu ~{thu_k(r.profile, ref)}k, "
            f"lãi ~{lai_k(r.profile, ref)//1000}k, "
            f"co định {co_dinh_k(ref)}k, túi ~{tui}k"
        )

    print("\nNgày mua & ≈ số ngày lãi ròng tương đương giá món:")
    for p in r.purchases:
        tag = "↑" if p.item.startswith("upgrade:") else "★"
        print(
            f"  {tag} ngày {p.day:4d} | {p.item:28s} | "
            f"{p.cost//1000:5d}k | ~{p.days_of_profit:.1f} ngày lãi"
        )


def main() -> None:
    print("Mô phỏng chi tiêu xu — 3 kiểu người chơi")
    print(f"Vốn đầu: {START//1000}k | Dự trữ: 2× phí cố định/ngày")
    results = {}
    for key in ("light", "medium", "skilled"):
        results[key] = run(key, 200)
        report(results[key], 200)

    # Extended run for completion targets
    print(f"\n{'=' * 72}")
    print("Chạy dài tới ngày 1100 (thu/lãi giữ mức ngày 200):")
    for key in ("skilled", "light"):
        r = run(key, 200)
        r = run(key, 1100, carry=r)
        report(r, 1100)
        half = len(XU_GOALS) // 2
        goal_purchases = [p for p in r.purchases if not p.item.startswith("upgrade:")]
        if len(goal_purchases) >= half:
            half_day = goal_purchases[half - 1].day
            print(f"  → Một nửa mục tiêu xu ({half}/{len(XU_GOALS)} món ★): ngày {half_day}")
        ups = [p for p in r.purchases if p.item.startswith("upgrade:")]
        if ups:
            print(f"  → Nâng cấp tiệm (mua cuối): ngày ~{ups[-1].day}")


if __name__ == "__main__":
    main()
