clc;
clear;
close all;

% 实验标识用于定位反演结果
sar_dir = '20260611';

% 离群点阈值用于剔除大偏差样本
outlier_rmse_factor = 1.5;

% 后向散射有效比例阈值用于样本筛选
sigma_valid_ratio_min = 0.60;

% 风速下限容差用于标记边界反演结果
retrieval_lower_bound = 0.10;
retrieval_lower_bound_tolerance = 0.05;

% 推荐残差阈值倍数用于 CMOD 残差筛选
residual_mad_factor = 1.0;

% 严格残差阈值倍数用于高可信样本筛选
strict_residual_mad_factor = 0.5;

% 误差命中阈值用于报告量化分析
error_limit_1ms = 1.0;
error_limit_2ms = 2.0;

% PNG 分辨率用于报告插图和日常查看
figure_resolution = 300;

% 统计图坐标范围用于统一展示
plot_wind_min = 0;
plot_wind_max = 30;

% 折线图文字横向位置比例用于避开图例
sample_text_x_ratio = 0.68;

% 散点图文字横向位置比例用于保持参考样式
scatter_text_x_ratio = 0.05;

% 图中文字纵向位置比例用于适配坐标范围
plot_text_y_ratio = 0.92;

% 图形线宽用于统一绘图样式
plot_line_width = 1.3;

% 图形字号用于统一绘图样式
plot_font_size = 12;

% 读取项目路径和中间结果路径
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
lon_lat_folder = fullfile(project_root, ['lon_lat_', sar_dir]);
sar_info_path = fullfile(lon_lat_folder, 'SAR_info_25x25.mat');

% 创建输出目录
create_directory(lon_lat_folder);

% 载入 ERA5 和 SAR 风速结果
if ~exist(sar_info_path, 'file')
    error('未找到反演结果，请先运行前三步脚本。');
end
load(sar_info_path, ...
    'small_arealon', 'small_arealat', 'small_areasig', 'sigma_valid_ratio', ...
    'small_wind_speed', 'sar_wind_speed', 'minimum_residual');

% 计算逐点误差
wind_error = sar_wind_speed - small_wind_speed;
abs_wind_error = abs(wind_error);

% 构建有效点和下限反演掩膜
valid_mask = isfinite(small_wind_speed) & isfinite(sar_wind_speed) & ...
    small_wind_speed > 0 & sar_wind_speed > 0;
lower_bound_mask = sar_wind_speed <= retrieval_lower_bound + retrieval_lower_bound_tolerance;
validation_base_mask = valid_mask & ~lower_bound_mask;

% 构建残差筛选掩膜
valid_residual_values = minimum_residual(validation_base_mask & isfinite(minimum_residual));
residual_threshold = calculate_median_mad_threshold(valid_residual_values, residual_mad_factor);
strict_residual_threshold = calculate_median_mad_threshold(valid_residual_values, strict_residual_mad_factor);
model_quality_mask = valid_mask & ...
    sigma_valid_ratio >= sigma_valid_ratio_min & ...
    ~lower_bound_mask & ...
    isfinite(minimum_residual) & minimum_residual <= residual_threshold;
strict_model_quality_mask = valid_mask & ...
    sigma_valid_ratio >= sigma_valid_ratio_min & ...
    ~lower_bound_mask & ...
    isfinite(minimum_residual) & minimum_residual <= strict_residual_threshold;

% 构建误差离群剔除掩膜
raw_error_values = wind_error(validation_base_mask);
raw_rmse = sqrt(mean(raw_error_values .^ 2));
error_outlier_mask = validation_base_mask & abs(wind_error) <= outlier_rmse_factor * raw_rmse;

% 计算三组验证指标
all_metrics = calculate_metrics(sar_wind_speed(valid_mask), small_wind_speed(valid_mask), ...
    error_limit_1ms, error_limit_2ms);
quality_metrics = calculate_metrics(sar_wind_speed(model_quality_mask), small_wind_speed(model_quality_mask), ...
    error_limit_1ms, error_limit_2ms);
strict_quality_metrics = calculate_metrics(sar_wind_speed(strict_model_quality_mask), small_wind_speed(strict_model_quality_mask), ...
    error_limit_1ms, error_limit_2ms);
outlier_metrics = calculate_metrics(sar_wind_speed(error_outlier_mask), small_wind_speed(error_outlier_mask), ...
    error_limit_1ms, error_limit_2ms);

% 生成评估表格
metrics_table = build_metrics_table(all_metrics, quality_metrics, strict_quality_metrics, outlier_metrics);

% 保存验证结果
save(sar_info_path, ...
    'valid_mask', 'model_quality_mask', 'strict_model_quality_mask', ...
    'error_outlier_mask', 'lower_bound_mask', 'validation_base_mask', ...
    'wind_error', 'abs_wind_error', 'residual_threshold', 'strict_residual_threshold', ...
    'all_metrics', 'quality_metrics', 'strict_quality_metrics', 'outlier_metrics', 'metrics_table', ...
    '-append');
writetable(metrics_table, fullfile(lon_lat_folder, 'accuracy_metrics.xlsx'));

% 绘制老师参考风格验证图
plot_sample_comparison(small_wind_speed, sar_wind_speed, error_outlier_mask, ...
    outlier_metrics, lon_lat_folder, sar_dir, figure_resolution, plot_wind_max, ...
    sample_text_x_ratio, plot_text_y_ratio, plot_line_width, plot_font_size);
plot_scatter_validation(small_wind_speed, sar_wind_speed, error_outlier_mask, ...
    outlier_metrics, lon_lat_folder, sar_dir, figure_resolution, plot_wind_min, plot_wind_max, ...
    scatter_text_x_ratio, plot_text_y_ratio, plot_line_width, plot_font_size);

% 打印验证指标
fprintf('\n========== 风速反演验证结果 ==========\n');
print_metrics('全部有效点', all_metrics);
print_metrics('CMOD残差筛选后', quality_metrics);
print_metrics('严格CMOD残差筛选后', strict_quality_metrics);
print_metrics('误差离群剔除后', outlier_metrics);
fprintf('CMOD残差筛选阈值：%.6f\n', residual_threshold);
fprintf('严格CMOD残差筛选阈值：%.6f\n', strict_residual_threshold);
fprintf('边界反演点数：%d 个\n', sum(lower_bound_mask(:) & valid_mask(:)));
fprintf('绘图样本边界反演点数：%d 个\n', sum(lower_bound_mask(:) & error_outlier_mask(:)));
fprintf('第四步完成：验证图和评估表已保存到结果目录。\n');
fprintf('结果目录：%s\n', lon_lat_folder);

function create_directory(directory_path)
% 创建输出目录
    if ~exist(directory_path, 'dir')
        mkdir(directory_path);
    end
end

function threshold_value = calculate_median_mad_threshold(data_values, mad_factor)
% 计算中位数绝对偏差阈值
    if isempty(data_values)
        threshold_value = inf;
        return;
    end

    median_value = median(data_values, 'omitnan');
    mad_value = median(abs(data_values - median_value), 'omitnan') * 1.4826;
    threshold_value = median_value + mad_factor * mad_value;
end

function metrics = calculate_metrics(sar_wind, era5_wind, error_limit_1ms, error_limit_2ms)
% 计算精度评估指标
    metrics = struct();
    metrics.point_count = numel(sar_wind);

    if metrics.point_count == 0
        metrics.rmse = nan;
        metrics.bias = nan;
        metrics.mae = nan;
        metrics.ubrmse = nan;
        metrics.correlation = nan;
        metrics.r_squared = nan;
        metrics.slope = nan;
        metrics.intercept = nan;
        metrics.hit_rate_1ms = nan;
        metrics.hit_rate_2ms = nan;
        return;
    end

    error_values = sar_wind - era5_wind;
    metrics.rmse = sqrt(mean(error_values .^ 2));
    metrics.bias = mean(error_values);
    metrics.mae = mean(abs(error_values));
    metrics.ubrmse = sqrt(mean((error_values - metrics.bias) .^ 2));
    metrics.hit_rate_1ms = mean(abs(error_values) <= error_limit_1ms) * 100;
    metrics.hit_rate_2ms = mean(abs(error_values) <= error_limit_2ms) * 100;

    if metrics.point_count >= 2
        correlation_matrix = corrcoef(sar_wind, era5_wind);
        metrics.correlation = correlation_matrix(1, 2);
        metrics.r_squared = metrics.correlation ^ 2;
        fit_coefficients = polyfit(era5_wind, sar_wind, 1);
        metrics.slope = fit_coefficients(1);
        metrics.intercept = fit_coefficients(2);
    else
        metrics.correlation = nan;
        metrics.r_squared = nan;
        metrics.slope = nan;
        metrics.intercept = nan;
    end
end

function metrics_table = build_metrics_table(all_metrics, quality_metrics, strict_quality_metrics, outlier_metrics)
% 整理精度评估指标表
    group_names = {'全部有效点'; 'CMOD残差筛选后'; '严格CMOD残差筛选后'; '误差离群剔除后'};
    metric_list = [all_metrics; quality_metrics; strict_quality_metrics; outlier_metrics];

    metrics_table = table( ...
        group_names, ...
        [metric_list.point_count]', ...
        [metric_list.rmse]', ...
        [metric_list.bias]', ...
        [metric_list.mae]', ...
        [metric_list.ubrmse]', ...
        [metric_list.correlation]', ...
        [metric_list.r_squared]', ...
        [metric_list.slope]', ...
        [metric_list.intercept]', ...
        [metric_list.hit_rate_1ms]', ...
        [metric_list.hit_rate_2ms]', ...
        'VariableNames', { ...
            'Group', 'Point_Count', 'RMSE', 'BIAS', 'MAE', 'ubRMSE', ...
            'Correlation_R', 'R_Squared', 'Fit_Slope', 'Fit_Intercept', ...
            'Hit_Rate_1ms_Percent', 'Hit_Rate_2ms_Percent'});
end

function plot_sample_comparison(era5_wind_grid, sar_wind_grid, plot_mask, plot_metrics, lon_lat_folder, sar_dir, figure_resolution, plot_wind_max, plot_text_x_ratio, plot_text_y_ratio, plot_line_width, plot_font_size)
% 绘制样本风速对比图
    era5_wind = era5_wind_grid(plot_mask);
    sar_wind = sar_wind_grid(plot_mask);

    figure_object = figure('Color', 'w');
    plot(era5_wind, 'b', 'LineWidth', plot_line_width);
    hold on;
    plot(sar_wind, 'r', 'LineWidth', plot_line_width);
    xlabel('样本数量', 'fontsize', plot_font_size, 'FontWeight', 'bold');
    ylabel('风速(m/s)', 'fontsize', plot_font_size, 'FontWeight', 'bold');
    legend('ERA5风速', '反演风速', 'Location', 'northwest');
    set(gca, 'FontSize', plot_font_size, 'FontWeight', 'bold');
    set(gca, 'YLim', [0, plot_wind_max]);
    text_x = max(1, round(numel(era5_wind) * plot_text_x_ratio));
    text_y = plot_wind_max * plot_text_y_ratio;
    text(text_x, text_y, sprintf('RMSE=%.4fm/s', plot_metrics.rmse), 'fontsize', plot_font_size, 'FontWeight', 'bold');
    export_png_figure(figure_object, lon_lat_folder, ['WS_', sar_dir, '_sample'], figure_resolution);
end

function plot_scatter_validation(era5_wind_grid, sar_wind_grid, plot_mask, plot_metrics, lon_lat_folder, sar_dir, figure_resolution, plot_wind_min, plot_wind_max, plot_text_x_ratio, plot_text_y_ratio, plot_line_width, plot_font_size)
% 绘制散点验证图
    era5_wind = era5_wind_grid(plot_mask);
    sar_wind = sar_wind_grid(plot_mask);

    figure_object = figure('Color', 'w');
    plot([plot_wind_min, plot_wind_max], [plot_wind_min, plot_wind_max], 'r--', 'LineWidth', plot_line_width);
    hold on;
    plot(era5_wind, sar_wind, 'ks', 'MarkerFaceColor', 'k');
    xlabel('ERA5风速(m/s)', 'fontsize', plot_font_size, 'FontWeight', 'bold');
    ylabel('反演风速(m/s)', 'fontsize', plot_font_size, 'FontWeight', 'bold');
    set(gca, 'FontSize', plot_font_size, 'FontWeight', 'bold');
    xlim([plot_wind_min, plot_wind_max]);
    ylim([plot_wind_min, plot_wind_max]);
    text_x = plot_wind_max * plot_text_x_ratio;
    text_y = plot_wind_max * plot_text_y_ratio;
    text(text_x, text_y, sprintf('RMSE=%.4fm/s', plot_metrics.rmse), 'fontsize', plot_font_size, 'FontWeight', 'bold');
    export_png_figure(figure_object, lon_lat_folder, ['WS_', sar_dir, '_rmse'], figure_resolution);
end

function export_png_figure(figure_object, figure_dir, figure_name, figure_resolution)
% 导出 PNG 图像
    exportgraphics(figure_object, fullfile(figure_dir, [figure_name, '.png']), 'Resolution', figure_resolution);
    close(figure_object);
end

function print_metrics(group_name, metrics)
% 打印评估指标
    fprintf('\n%s：\n', group_name);
    fprintf('样本点数：%d 个\n', metrics.point_count);
    fprintf('RMSE：%.4f m/s\n', metrics.rmse);
    fprintf('BIAS：%.4f m/s\n', metrics.bias);
    fprintf('MAE：%.4f m/s\n', metrics.mae);
    fprintf('ubRMSE：%.4f m/s\n', metrics.ubrmse);
    fprintf('相关系数 R：%.4f\n', metrics.correlation);
    fprintf('1 m/s 内命中率：%.2f%%\n', metrics.hit_rate_1ms);
    fprintf('2 m/s 内命中率：%.2f%%\n', metrics.hit_rate_2ms);
end
