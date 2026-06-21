clc;
clear;

% 实验名称用于定位第一步输出
experiment_name = '墨西哥湾_20260611';

% ERA5 文件名来自下载脚本输出
era5_file_name = 'era5_wind_gulf_mexico_20260611_0000.nc';

% 经度转换边界用于统一到 -180 到 180
longitude_wrap_threshold = 180;
longitude_wrap_offset = 360;

% 读取项目路径和中间结果路径
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
data_dir = fullfile(project_root, '数据');
output_dir = fullfile(project_root, ['结果_', experiment_name]);
intermediate_dir = fullfile(output_dir, '01_中间数据');
grid_data_dir = fullfile(output_dir, '02_网格数据');
sar_info_path = fullfile(intermediate_dir, 'SAR_info_25x25.mat');
era5_path = fullfile(data_dir, era5_file_name);

% 载入 SAR 25x25 抽样网格
if ~exist(sar_info_path, 'file')
    error('未找到第一步结果，请先运行 code/step_01_extract_sar_grid.m');
end
load(sar_info_path, 'small_arealon', 'small_arealat', 'small_areainc', 'small_areasig');

% 读取 ERA5 经纬度和 10 m 风场
fprintf('正在读取 ERA5 10 m U/V 风场...\n');
era5_lon = double(ncread(era5_path, 'longitude'));
era5_lat = double(ncread(era5_path, 'latitude'));
u10_raw = double(ncread(era5_path, 'u10'));
v10_raw = double(ncread(era5_path, 'v10'));

% 统一 ERA5 经度坐标
if any(era5_lon > longitude_wrap_threshold)
    era5_lon(era5_lon > longitude_wrap_threshold) = ...
        era5_lon(era5_lon > longitude_wrap_threshold) - longitude_wrap_offset;
end

% 调整 ERA5 风场为纬度x经度矩阵
u10_grid = squeeze(u10_raw(:, :, 1))';
v10_grid = squeeze(v10_raw(:, :, 1))';

% 保证插值坐标单调递增
[era5_lon, lon_order] = sort(era5_lon);
u10_grid = u10_grid(:, lon_order);
v10_grid = v10_grid(:, lon_order);

[era5_lat, lat_order] = sort(era5_lat);
u10_grid = u10_grid(lat_order, :);
v10_grid = v10_grid(lat_order, :);

% 插值匹配到 SAR 25x25 中心点
fprintf('正在将 ERA5 风场插值到 SAR 25x25 网格...\n');
u10_interpolant = griddedInterpolant({era5_lat, era5_lon}, u10_grid, 'linear', 'nearest');
v10_interpolant = griddedInterpolant({era5_lat, era5_lon}, v10_grid, 'linear', 'nearest');
small_u10 = u10_interpolant(small_arealat, small_arealon);
small_v10 = v10_interpolant(small_arealat, small_arealon);

% 计算 ERA5 风速和气象风向
small_wind_speed = sqrt(small_u10 .^ 2 + small_v10 .^ 2);
small_wind_dir = 180 + atan2d(small_u10, small_v10);
small_wind_dir = mod(small_wind_dir, longitude_wrap_offset);

% 保存匹配结果
save(sar_info_path, ...
    'experiment_name', 'output_dir', 'intermediate_dir', 'grid_data_dir', ...
    'small_arealon', 'small_arealat', 'small_areainc', 'small_areasig', ...
    'small_u10', 'small_v10', 'small_wind_speed', 'small_wind_dir', ...
    '-append');

write_matrix_dat(fullfile(grid_data_dir, 'ERA5风速.dat'), small_wind_speed);
write_matrix_dat(fullfile(grid_data_dir, 'ERA5风向.dat'), small_wind_dir);

fprintf('第二步完成：ERA5 风速风向已匹配到 SAR 网格。\n');
fprintf('结果目录：%s\n', output_dir);

function write_matrix_dat(file_path, matrix_data)
% 将矩阵写为文本数据文件
    writematrix(matrix_data, file_path, 'Delimiter', ' ');
end
