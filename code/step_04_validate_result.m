clc;
clear;
close all;

% 实验名称用于定位反演结果
experiment_name = '墨西哥湾_20260611';

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

% 读取项目路径和中间结果路径
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
output_dir = fullfile(project_root, ['结果_', experiment_name]);
intermediate_dir = fullfile(output_dir, '01_中间数据');
table_dir = fullfile(output_dir, '03_结果表格');
figure_dir = fullfile(output_dir, '04_图件');
sar_info_path = fullfile(intermediate_dir, 'SAR_info_25x25.mat');

% 创建输出目录
create_directory(intermediate_dir);
create_directory(table_dir);
create_directory(figure_dir);

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

% 构建有效点和残差筛选掩膜
valid_mask = isfinite(small_wind_speed) & isfinite(sar_wind_speed) & ...
    small_wind_speed > 0 & sar_wind_speed > 0;
valid_residual_values = minimum_residual(valid_mask & isfinite(minimum_residual));
residual_threshold = calculate_median_mad_threshold(valid_residual_values, residual_mad_factor);
strict_residual_threshold = calculate_median_mad_threshold(valid_residual_values, strict_residual_mad_factor);
lower_bound_mask = sar_wind_speed <= retrieval_lower_bound + retrieval_lower_bound_tolerance;
model_quality_mask = valid_mask & ...
    sigma_valid_ratio >= sigma_valid_ratio_min & ...
    ~lower_bound_mask & ...
    isfinite(minimum_residual) & minimum_residual <= residual_threshold;
strict_model_quality_mask = valid_mask & ...
    sigma_valid_ratio >= sigma_valid_ratio_min & ...
    ~lower_bound_mask & ...
    isfinite(minimum_residual) & minimum_residual <= strict_residual_threshold;

% 构建误差离群剔除掩膜
raw_error_values = wind_error(valid_mask);
raw_rmse = sqrt(mean(raw_error_values .^ 2));
error_outlier_mask = valid_mask & abs(wind_error) <= outlier_rmse_factor * raw_rmse;

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
point_error_table = build_point_error_table( ...
    small_arealon, small_arealat, small_areasig, sigma_valid_ratio, ...
    small_wind_speed, sar_wind_speed, minimum_residual, wind_error, ...
    valid_mask, model_quality_mask, strict_model_quality_mask, error_outlier_mask, lower_bound_mask);

% 保存验证结果
save(fullfile(intermediate_dir, '验证指标.mat'), ...
    'valid_mask', 'model_quality_mask', 'strict_model_quality_mask', ...
    'error_outlier_mask', 'lower_bound_mask', ...
    'wind_error', 'abs_wind_error', 'residual_threshold', 'strict_residual_threshold', ...
    'all_metrics', 'quality_metrics', 'strict_quality_metrics', 'outlier_metrics', 'metrics_table');
writetable(metrics_table, fullfile(table_dir, '精度评估指标.xlsx'));
writetable(point_error_table, fullfile(table_dir, '逐点误差评估.xlsx'));

% 绘制评估图
plot_sample_comparison(small_wind_speed, sar_wind_speed, model_quality_mask, ...
    all_metrics, quality_metrics, figure_dir, figure_resolution, plot_wind_min, plot_wind_max);
plot_scatter_validation(small_wind_speed, sar_wind_speed, valid_mask, model_quality_mask, ...
    quality_metrics, figure_dir, figure_resolution, plot_wind_min, plot_wind_max);
plot_error_histogram(wind_error, valid_mask, model_quality_mask, ...
    figure_dir, figure_resolution);
plot_metric_summary(metrics_table, figure_dir, figure_resolution);

% 打印验证指标
fprintf('\n========== 风速反演验证结果 ==========\n');
print_metrics('全部有效点', all_metrics);
print_metrics('CMOD残差筛选后', quality_metrics);
print_metrics('严格CMOD残差筛选后', strict_quality_metrics);
print_metrics('误差离群剔除后', outlier_metrics);
fprintf('CMOD残差筛选阈值：%.6f\n', residual_threshold);
fprintf('严格CMOD残差筛选阈值：%.6f\n', strict_residual_threshold);
fprintf('边界反演点数：%d 个\n', sum(lower_bound_mask(:) & valid_mask(:)));
fprintf('第四步完成：验证图、评估表和指标已保存到结果目录。\n');
fprintf('结果目录：%s\n', output_dir);

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

function point_error_table = build_point_error_table(longitude_grid, latitude_grid, sigma_grid, sigma_valid_ratio, era5_wind, sar_wind, minimum_residual, wind_error, valid_mask, model_quality_mask, strict_model_quality_mask, error_outlier_mask, lower_bound_mask)
% 整理逐点误差评估表
    point_error_table = table( ...
        longitude_grid(:), ...
        latitude_grid(:), ...
        sigma_grid(:), ...
        sigma_valid_ratio(:), ...
        era5_wind(:), ...
        sar_wind(:), ...
        wind_error(:), ...
        abs(wind_error(:)), ...
        minimum_residual(:), ...
        valid_mask(:), ...
        model_quality_mask(:), ...
        strict_model_quality_mask(:), ...
        error_outlier_mask(:), ...
        lower_bound_mask(:), ...
        'VariableNames', { ...
            'Longitude', 'Latitude', 'Sigma0_VV', 'Sigma0_Valid_Ratio', ...
            'ERA5_Wind_Speed', 'SAR_Wind_Speed', 'Wind_Error', 'Abs_Wind_Error', ...
            'CMOD_Minimum_Residual', 'Is_Valid', 'Is_CMOD_Residual_Filtered', ...
            'Is_Strict_CMOD_Residual_Filtered', 'Is_Error_Outlier_Controlled', ...
            'Is_Lower_Bound_Result'});
end

function plot_sample_comparison(era5_wind_grid, sar_wind_grid, model_quality_mask, all_metrics, quality_metrics, figure_dir, figure_resolution, plot_wind_min, plot_wind_max)
% 绘制样本风速对比图
    era5_wind = era5_wind_grid(model_quality_mask);
    sar_wind = sar_wind_grid(model_quality_mask);

    figure_object = figure('Color', 'w', 'Position', [100, 100, 900, 520]);
    plot(era5_wind, 'b-', 'LineWidth', 1.3);
    hold on;
    plot(sar_wind, 'r-', 'LineWidth', 1.3);
    grid on;
    xlabel('CMOD残差筛选后样本序号');
    ylabel('风速（m/s）');
    title('ERA5 风速与 SAR 反演风速样本对比');
    legend('ERA5 风速', 'SAR 反演风速', 'Location', 'best');
    ylim([plot_wind_min, plot_wind_max]);
    text(1, plot_wind_max - 2, sprintf('全部 RMSE=%.3f m/s，筛选后 RMSE=%.3f m/s', all_metrics.rmse, quality_metrics.rmse));
    export_png_figure(figure_object, figure_dir, '风速样本对比图', figure_resolution);
end

function plot_scatter_validation(era5_wind_grid, sar_wind_grid, valid_mask, model_quality_mask, quality_metrics, figure_dir, figure_resolution, plot_wind_min, plot_wind_max)
% 绘制散点验证图
    valid_era5_wind = era5_wind_grid(valid_mask);
    valid_sar_wind = sar_wind_grid(valid_mask);
    quality_era5_wind = era5_wind_grid(model_quality_mask);
    quality_sar_wind = sar_wind_grid(model_quality_mask);

    figure_object = figure('Color', 'w', 'Position', [100, 100, 720, 650]);
    plot([plot_wind_min, plot_wind_max], [plot_wind_min, plot_wind_max], 'r--', 'LineWidth', 1.3);
    hold on;
    plot(valid_era5_wind, valid_sar_wind, 'o', 'Color', [0.75 0.75 0.75], 'MarkerSize', 4);
    plot(quality_era5_wind, quality_sar_wind, 'ks', 'MarkerFaceColor', 'k', 'MarkerSize', 4);
    if isfinite(quality_metrics.slope)
        fit_x = [plot_wind_min, plot_wind_max];
        fit_y = quality_metrics.slope .* fit_x + quality_metrics.intercept;
        plot(fit_x, fit_y, 'b-', 'LineWidth', 1.3);
    end
    grid on;
    xlabel('ERA5 风速（m/s）');
    ylabel('SAR 反演风速（m/s）');
    title('SAR 反演风速精度验证散点图');
    legend('1:1 线', '全部有效点', 'CMOD残差筛选后', '拟合线', 'Location', 'best');
    xlim([plot_wind_min, plot_wind_max]);
    ylim([plot_wind_min, plot_wind_max]);
    text(plot_wind_min + 1, plot_wind_max - 2, sprintf('RMSE=%.3f m/s, R=%.3f', quality_metrics.rmse, quality_metrics.correlation));
    export_png_figure(figure_object, figure_dir, '风速精度验证散点图', figure_resolution);
end

function plot_error_histogram(wind_error, valid_mask, model_quality_mask, figure_dir, figure_resolution)
% 绘制风速误差直方图
    figure_object = figure('Color', 'w', 'Position', [100, 100, 780, 520]);
    histogram(wind_error(valid_mask), 24, 'FaceColor', [0.70 0.70 0.70], 'EdgeColor', 'none');
    hold on;
    histogram(wind_error(model_quality_mask), 24, 'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'none');
    grid on;
    xlabel('SAR - ERA5 风速误差（m/s）');
    ylabel('样本数量');
    title('风速误差分布直方图');
    legend('全部有效点', 'CMOD残差筛选后', 'Location', 'best');
    export_png_figure(figure_object, figure_dir, '风速误差直方图', figure_resolution);
end

function plot_metric_summary(metrics_table, figure_dir, figure_resolution)
% 绘制核心指标对比图
    figure_object = figure('Color', 'w', 'Position', [100, 100, 820, 520]);
    metric_values = [metrics_table.RMSE, metrics_table.MAE, abs(metrics_table.BIAS)];
    bar(metric_values);
    grid on;
    set(gca, 'XTickLabel', metrics_table.Group);
    ylabel('风速误差（m/s）');
    title('核心误差指标对比');
    legend('RMSE', 'MAE', '|BIAS|', 'Location', 'best');
    export_png_figure(figure_object, figure_dir, '核心误差指标对比图', figure_resolution);
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
