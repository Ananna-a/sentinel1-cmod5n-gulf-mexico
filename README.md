# Sentinel-1 SAR 海面风速反演

本仓库用于海洋信息技术基础课程大作业：基于 Sentinel-1 SAR 数据，使用 CMOD5.N 模型反演墨西哥湾海面风速，并用 ERA5 再分析风场进行验证。

## 当前进度

- 已完成 ERA5 下载脚本：`code/download_era5_gulf_mexico.py`
- 已确认 SAR 主输入改用 SNAP BEAM-DIMAP 格式，避免 NetCDF/HDF 读取问题
- 已按参考个例命名整理 MATLAB 流水线：`SAR_lat_lon_inc.m`、`ERA5_read_match.m`、`Inverse.m`、`Check.m`、`Toexcel.m`
- 已按老师参考风格生成两张 PNG 验证图：样本风速对比图和 RMSE 散点图
- 已在验证阶段标记并剔除边界反演点，避免 0.1 m/s 搜索下限点进入最终图件
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

其中 SAR 数据来自 SNAP 处理后的 BEAM-DIMAP 产品，ERA5 数据可用 `code/download_era5_gulf_mexico.py` 重新下载。

## MATLAB 流水线

MATLAB 脚本放在 `code/`，命名方式与参考个例保持一致：

```text
SAR_lat_lon_inc.m
ERA5_read_match.m
Inverse.m
Check.m
Toexcel.m
```

推荐在 MATLAB 中按顺序运行：

```matlab
run("code/SAR_lat_lon_inc.m")
run("code/ERA5_read_match.m")
run("code/Inverse.m")
run("code/Check.m")
run("code/Toexcel.m")
```

默认输出目录为 `lon_lat_20260611/`，包含 `lon.dat`、`lat.dat`、`inc.dat`、`sig.dat`、`wind_speed.dat`、`dir.dat`、`sar_wind_speed.dat`、评估表和 PNG 图件。

## 结果与评估

新版处理使用块内 11×11 抽样中位数估计 `Sigma0_VV`，并增加后向散射有效比例、CMOD 残差和边界反演标记。

报告中的两张老师参考风格验证图使用“误差离群剔除后”的样本，坐标范围保持 `0-30 m/s`：

```text
点数：480
RMSE：1.4005 m/s
BIAS：0.5905 m/s
MAE：1.0687 m/s
ubRMSE：1.2700 m/s
R：0.5514
1 m/s 内命中率：56.88%
2 m/s 内命中率：83.33%
```

报告量化分析可补充“CMOD残差筛选后”的指标：

```text
点数：374
RMSE：1.4551 m/s
BIAS：0.5983 m/s
MAE：1.0359 m/s
ubRMSE：1.3265 m/s
R：0.5803
1 m/s 内命中率：60.16%
2 m/s 内命中率：86.36%
```

严格 CMOD 残差筛选后可作为补充结果：

```text
点数：336
RMSE：1.3883 m/s
BIAS：0.5250 m/s
MAE：0.9712 m/s
ubRMSE：1.2852 m/s
R：0.5793
2 m/s 内命中率：88.69%
```

全部有效点中有 38 个结果落在 `0.1 m/s` 附近的搜索下限，主要集中在左上角近岸区域。最终验证图不绘制这些边界反演点，结果表中保留 `Is_Lower_Bound_Result` 字段用于说明。

## Git 管理

`.gitignore` 已忽略本地大文件、生成结果、报告模板、虚拟环境和参考代码目录。GitHub 中主要保留：

```text
code/
README.md
项目开展说明.md
项目进度记录.md
数据/.gitkeep
```

## ERA5 下载

先配置 Copernicus CDS API 的 `.cdsapirc`，再运行：

```powershell
python code\download_era5_gulf_mexico.py
```

若目标文件已存在，脚本会跳过下载；需要覆盖时加：

```powershell
python code\download_era5_gulf_mexico.py --overwrite
```
