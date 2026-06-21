# Sentinel-1 SAR 海面风速反演

本仓库用于海洋信息技术基础课程大作业：基于 Sentinel-1 SAR 数据，使用 CMOD5.N 模型反演墨西哥湾海面风速，并用 ERA5 再分析风场进行验证。

## 当前进度

- 已完成 ERA5 下载脚本：`code/step_00_download_era5_gulf_mexico.py`
- 已确认 SAR 主输入改用 SNAP BEAM-DIMAP 格式，避免 NetCDF/HDF 读取问题
- 已完成 MATLAB 处理流水线：`code/step_01_extract_sar_grid.m` 到 `code/step_06_plot_spatial_maps.m`
- 已根据 docx 模板整理报告写作清单：`report/报告写作清单.md`
- 已记录项目路线与问题：`项目开展说明.md`、`项目进度记录.md`

## 数据说明

原始 SAR、SNAP 输出数据、ERA5 nc、报告文档和参考代码不上传 GitHub。

本地运行时需要在 `数据/` 下准备：

```text
S1A_GulfMexico_20260610_Cal_Deb.dim
S1A_GulfMexico_20260610_Cal_Deb.data/
era5_wind_gulf_mexico_20260611_0000.nc
```

其中 SAR 数据来自 SNAP 处理后的 BEAM-DIMAP 产品，ERA5 数据可用 `code/step_00_download_era5_gulf_mexico.py` 重新下载。

## MATLAB 流水线

MATLAB 脚本放在 `code/`。由于 MATLAB 文件名不能以数字开头，脚本使用 `step_01` 到 `step_05` 命名：

```text
step_00_download_era5_gulf_mexico.py
step_01_extract_sar_grid.m
step_02_match_era5_to_sar.m
step_03_inverse_cmod5n.m
step_04_validate_result.m
step_05_export_excel.m
step_06_plot_spatial_maps.m
```

推荐在 MATLAB 中按顺序运行：

```matlab
run("code/step_01_extract_sar_grid.m")
run("code/step_02_match_era5_to_sar.m")
run("code/step_03_inverse_cmod5n.m")
run("code/step_04_validate_result.m")
run("code/step_05_export_excel.m")
run("code/step_06_plot_spatial_maps.m")
```

默认输出目录为 `结果_墨西哥湾_20260611/`，包含中间数据、25×25 网格数据、结果表格和 PNG 图件。

## 结果与评估

新版处理使用块内 11×11 抽样中位数估计 `Sigma0_VV`，并增加后向散射有效比例、CMOD 残差和边界反演标记。

推荐报告使用“CMOD残差筛选后”的指标：

```text
点数：388
RMSE：1.4797 m/s
BIAS：0.6345 m/s
MAE：1.0588 m/s
ubRMSE：1.3368 m/s
R：0.5848
1 m/s 内命中率：59.28%
2 m/s 内命中率：85.57%
```

严格 CMOD 残差筛选后可作为补充结果：

```text
点数：343
RMSE：1.3832 m/s
BIAS：0.5242 m/s
MAE：0.9690 m/s
ubRMSE：1.2800 m/s
R：0.5789
2 m/s 内命中率：88.63%
```

## ERA5 下载

先配置 Copernicus CDS API 的 `.cdsapirc`，再运行：

```powershell
python code\step_00_download_era5_gulf_mexico.py
```

若目标文件已存在，脚本会跳过下载；需要覆盖时加：

```powershell
python code\step_00_download_era5_gulf_mexico.py --overwrite
```
