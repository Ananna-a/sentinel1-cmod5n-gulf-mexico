# Sentinel-1 SAR 海面风速反演

本仓库用于海洋信息技术基础课程大作业：基于 Sentinel-1 SAR 数据，使用 CMOD5.N 模型反演墨西哥湾海面风速，并用 ERA5 再分析风场进行验证。

## 当前进度

- 已完成 ERA5 下载脚本：`code/00_download_era5_gulf_mexico.py`
- 已确认 SAR 主输入改用 SNAP BEAM-DIMAP 格式，避免 NetCDF/HDF 读取问题
- 已记录项目路线与问题：`项目开展说明.md`、`项目进度记录.md`

## 数据说明

原始 SAR、SNAP 输出数据、ERA5 nc、报告文档和参考代码不上传 GitHub。

本地运行时需要在 `数据/` 下准备：

```text
S1A_GulfMexico_20260610_Cal_Deb.dim
S1A_GulfMexico_20260610_Cal_Deb.data/
era5_wind_gulf_mexico_20260611_0000.nc
```

其中 SAR 数据来自 SNAP 处理后的 BEAM-DIMAP 产品，ERA5 数据可用 `code/00_download_era5_gulf_mexico.py` 重新下载。

## 计划脚本

后续 MATLAB 流水线计划放在 `code/`：

```text
01_extract_sar_grid.m
02_match_era5_to_sar.m
03_inverse_cmod5n.m
04_validate_result.m
05_export_excel.m
```

## ERA5 下载

先配置 Copernicus CDS API 的 `.cdsapirc`，再运行：

```powershell
python code\00_download_era5_gulf_mexico.py
```

若目标文件已存在，脚本会跳过下载；需要覆盖时加：

```powershell
python code\00_download_era5_gulf_mexico.py --overwrite
```

