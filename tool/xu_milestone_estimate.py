#!/usr/bin/env python3
"""Rough xu/day estimate from economy.json constants (not full game sim)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
E = json.loads((ROOT / "assets/data/economy.json").read_text(encoding="utf-8"))

START = E["start"]["cash"]
RENT = E["day"]["fixedCosts"]["rent"]
UTIL = E["day"]["fixedCosts"]["utilities"]
BASE_FIX = RENT + UTIL
BASE_CUST = E["customers"]["baseCustomersDay1"]
GROW = E["customers"]["growthPerDay"]
CAP = E["customers"]["baseCustomersCap"]
RATING = E["customers"]["ratingFactor"]["4"]

UPGRADES = {u["id"]: u for u in E["upgrades"]}


def upgrade_costs():
    costs = {}
    for uid, u in UPGRADES.items():
        costs[uid] = [lv["cost"] for lv in u["levels"]]
    return costs


COSTS = upgrade_costs()


def daily_upkeep(levels: dict[str, int]) -> int:
    total = 0
    for uid, lv in levels.items():
        if lv <= 0:
            continue
        u = UPGRADES[uid]
        if u.get("consumable"):
            continue
        level = u["levels"][lv - 1]
        total += level.get("dailyUpkeep", 0) + level.get("dailyWage", 0)
    return total


def customers(day: int, display_lv: int, ads: bool) -> float:
    n = min(CAP, BASE_CUST + GROW * (day - 1)) * RATING
    if display_lv >= 1:
        mult = UPGRADES["display"]["levels"][display_lv - 1]["effect"]["customerMultiplier"]
        n *= mult
    if ads:
        n *= UPGRADES["ads"]["levels"][0]["effect"]["customerMultiplier"]
    return n


def try_buy(levels: dict[str, int], money: int, day: int, order: list[str], reserve: int) -> int:
    changed = True
    while changed:
        changed = False
        for uid in order:
            cur = levels.get(uid, 0)
            opts = COSTS.get(uid, [])
            if cur >= len(opts):
                continue
            cost = opts[cur]
            if uid == "staff" and cur >= 1:
                req = UPGRADES["staff"]["levels"][cur].get("effect", {}).get("requires", {})
                if levels.get("counter", 0) < req.get("counter", 0):
                    continue
            if money - cost >= reserve:
                money -= cost
                levels[uid] = cur + 1
                changed = True
    return money


def avg_revenue_per_served(day: int, levels: dict[str, int]) -> int:
    """Heuristic tuned to economy.json event note (~220k early, ~1.2M late)."""
    base = 28_000
    if day >= 10:
        base += 4_000
    if day >= 20:
        base += 6_000
    if day >= 40:
        base += 10_000
    if day >= 80:
        base += 18_000
    if day >= 120:
        base += 12_000
    if levels.get("staff", 0) >= 2:
        base += 6_000
    if levels.get("counter", 0) >= 1:
        base += 3_000
    return base


def serve_fraction(day: int, levels: dict[str, int]) -> float:
    f = 0.65
    f += min(0.08, levels.get("wrapping_table", 0) * 0.03)
    f += min(0.06, levels.get("bench", 0) * 0.02)
    f += min(0.12, levels.get("staff", 0) * 0.04)
    f += min(0.08, levels.get("counter", 0) * 0.04)
    return min(0.98, f)


def market_spend_per_served(rev: int) -> int:
    """Stem COGS + supplies ~58% of takings (calibrated to economy draft note)."""
    return int(rev * 0.58)


def reserve(day: int) -> int:
    if day < 15:
        return 400_000
    if day < 40:
        return 550_000
    if day < 80:
        return 700_000
    return 900_000


ORDER = [
    "cold_storage",
    "wrapping_table",
    "display",
    "bench",
    "counter",
    "staff",
    "ads",
]


def main() -> None:
    money = START
    levels: dict[str, int] = {}
    ads_days = 0
    milestones = list(range(10, 201, 10))
    ms_set = set(milestones)
    total_sold = 0

    print(
        "day\tthu_k\tlai_k\tco_dinh_k\tnhap_hoa_k\txu_tong_k\tban_lifetime\tupgrades"
    )
    for day in range(1, 201):
        if ads_days > 0:
            ads_days -= 1
        money = try_buy(levels, money, day, ORDER, reserve(day))
        disp = levels.get("display", 0)
        cust = customers(day, disp, ads_days > 0)
        served = cust * serve_fraction(day, levels)
        rev_each = avg_revenue_per_served(day, levels)
        thu = int(served * rev_each * 1.08)  # tips / goals rough
        nhap = market_spend_per_served(thu)
        co_dinh = BASE_FIX + daily_upkeep(levels)
        lai = thu - nhap - co_dinh
        money += lai
        total_sold += int(served)
        if day in ms_set:
            print(
                f"{day}\t{thu // 1000}\t{lai // 1000}\t{co_dinh // 1000}\t"
                f"{nhap // 1000}\t{money // 1000}\t{total_sold}\t{levels}"
            )
        # ads consumable when rich
        if levels.get("ads", 0) == 0 and money > 800_000 and day % 12 == 0:
            c = COSTS["ads"][0]
            if money - c > reserve(day):
                money -= c
                levels["ads"] = 1
                ads_days = UPGRADES["ads"]["levels"][0]["durationDays"]


if __name__ == "__main__":
    main()
