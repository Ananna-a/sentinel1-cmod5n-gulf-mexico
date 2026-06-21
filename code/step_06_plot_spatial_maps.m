clc;
clear;
close all;

% 实验名称用于定位最终结果
experiment_name = '墨西哥湾_20260611';

% PNG 分辨率用于报告插图和日常查看
figure_resolution = 300;

% 风速色标范围用于统一对比
wind_color_min = 0;
wind_color_max = 12;

% 差值色标范围用于突出 SAR 与 ERA5 差异
difference_color_min = -6;
difference_color_max = 6;

% 残差色标范围用于展示 CMOD 匹配质量
residual_color_min = 0;
residual_color_max = 0.35;

% 读取项目路径和中间结果路径
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
output_dir = fullfile(project_root, ['结果_', experiment_name]);
intermediate_dir = fullfile(output_dir, '01_中间数据');
figure_dir = fullfile(output_dir, '04_图件');
sar_info_path = fullfile(intermediate_dir, 'SAR_info_25x25.mat');
validation_path = fullfile(intermediate_dir, '验证指标.mat');

% 创建图件输出目录
create_directory(figure_dir);

% 载入空间网格和风速结果
if ~exist(sar_info_path, 'file')
    error('未找到最终中间结果，请先运行前五步脚本。');
end
load(sar_info_path, ...
    'small_arealon', 'small_arealat', ...
    'small_wind_speed', 'sar_wind_speed', 'minimum_residual');

% 载入样本筛选结果
if exist(validation_path, 'file')
    load(validation_path, 'model_quality_mask', 'strict_model_quality_mask');
else
    model_quality_mask = isfinite(sar_wind_speed) & isfinite(small_wind_speed);
    strict_model_quality_mask = model_quality_mask;
end

% 计算 SAR 与 ERA5 风速差值
wind_difference = sar_wind_speed - small_wind_speed;

% 绘制空间分布图
plot_spatial_map( ...
    small_arealon, small_arealat, sar_wind_speed, ...
    'SAR 反演风速空间分布图', 'SAR 反演风速（m/s）', ...
    [wind_color_min, wind_color_max], ...
    figure_dir, 'SAR反演风速空间分布图', figure_resolution);

plot_spatial_map( ...
    small_arealon, small_arealat, small_wind_speed, ...
    'ERA5 风速空间分布图', 'ERA5 风速（m/s）', ...
    [wind_color_min, wind_color_max], ...
    figure_dir, 'ERA5风速空间分布图', figure_resolution);

plot_spatial_map( ...
    small_arealon, small_arealat, wind_difference, ...
    'SAR 与 ERA5 风速差值空间分布图', 'SAR - ERA5 风速（m/s）', ...
    [difference_color_min, difference_color_max], ...
    figure_dir, 'SAR与ERA5风速差值空间分布图', figure_resolution);

plot_spatial_map( ...
    small_arealon, small_arealat, minimum_residual, ...
    'CMOD 最小残差空间分布图', 'CMOD 最小残差', ...
    [residual_color_min, residual_color_max], ...
    figure_dir, 'CMOD最小残差空间分布图', figure_resolution);

plot_spatial_map( ...
    small_arealon, small_arealat, double(model_quality_mask), ...
    'CMOD 残差筛选掩膜空间分布图', '残差筛选标记', ...
    [0, 1], ...
    figure_dir, 'CMOD残差筛选掩膜空间分布图', figure_resolution);

plot_spatial_map( ...
    small_arealon, small_arealat, double(strict_model_quality_mask), ...
    '严格 CMOD 残差筛选掩膜空间分布图', '严格残差筛选标记', ...
    [0, 1], ...
    figure_dir, '严格CMOD残差筛选掩膜空间分布图', figure_resolution);

fprintf('第六步完成：空间分布图已保存为 PNG 图像。\n');
fprintf('结果目录：%s\n', output_dir);

function create_directory(directory_path)
% 创建输出目录
    if ~exist(directory_path, 'dir')
        mkdir(directory_path);
    end
end

function plot_spatial_map(longitude_grid, latitude_grid, value_grid, figure_title, colorbar_label, color_limits, figure_dir, figure_name, figure_resolution)
% 绘制经纬度空间分布图
    figure_object = figure('Color', 'w', 'Position', [100, 100, 900, 650]);
    surface_object = surf(longitude_grid, latitude_grid, value_grid);
    surface_object.EdgeColor = 'none';
    view(2);
    axis tight;
    grid on;
    box on;
    colormap(parula);
    clim(color_limits);
    colorbar_object = colorbar;
    colorbar_object.Label.String = colorbar_label;
    xlabel('经度');
    ylabel('纬度');
    title(figure_title);
    set(gca, 'FontSize', 12, 'LineWidth', 1);

    % 导出 PNG 图像
    exportgraphics(figure_object, fullfile(figure_dir, [figure_name, '.png']), 'Resolution', figure_resolution);
    close(figure_object);
end
