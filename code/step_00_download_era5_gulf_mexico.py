#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
下载与 Sentinel-1 SAR 场景匹配的 ERA5 10 m 风场数据。

SAR 场景：
    Sentinel-1A IW SLC
    成像时间：2026-06-10 23:53:38 到 2026-06-10 23:54:08 UTC
    海域：墨西哥湾

ERA5 匹配原则：
    ERA5 为逐小时资料，本脚本下载最接近 SAR 成像时间的
    2026-06-11 00:00 UTC 风场。
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cdsapi


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "数据"
DEFAULT_TARGET = DATA_DIR / "era5_wind_gulf_mexico_20260611_0000.nc"


ERA5_REQUEST = {
    "product_type": ["reanalysis"],
    "variable": [
        "10m_u_component_of_wind",
        "10m_v_component_of_wind",
    ],
    "year": ["2026"],
    "month": ["06"],
    "day": ["11"],
    "time": ["00:00"],
    # CDS API 的 area 顺序为：[北, 西, 南, 东]
    # 该范围覆盖当前墨西哥湾 SAR 场景，并留有一定外扩边界。
    "area": [31, -91, 27, -85],
    "grid": [0.25, 0.25],
    "data_format": "netcdf",
    "download_format": "unarchived",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="下载墨西哥湾 Sentinel-1 SAR 场景对应的 ERA5 10 m U/V 风场。"
    )
    parser.add_argument(
        "--target",
        type=Path,
        default=DEFAULT_TARGET,
        help=f"输出 nc 文件路径，默认：{DEFAULT_TARGET}",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="如果目标文件已存在，则重新下载并覆盖。",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    target = args.target
    if not target.is_absolute():
        target = PROJECT_ROOT / target

    target.parent.mkdir(parents=True, exist_ok=True)

    if target.exists() and not args.overwrite:
        print(f"目标文件已存在，跳过下载：{target}")
        print("如需重新下载，请加参数：--overwrite")
        return

    print("正在向 Copernicus CDS 提交 ERA5 下载请求...")
    print(f"输出文件：{target}")

    client = cdsapi.Client()
    client.retrieve("reanalysis-era5-single-levels", ERA5_REQUEST, str(target))

    print(f"ERA5 下载完成：{target}")


if __name__ == "__main__":
    main()
