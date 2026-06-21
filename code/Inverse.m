clc;
clear;

% 实验标识用于定位前序输出
sar_dir = '20260611';

% CMOD5.N 经验系数用于计算理论后向散射
cmod5n_coefficients = [ ...
    -0.6878, -0.7532, -0.1504, 0.0408, 0.2423, -0.2117, ...
    0.0115, 0.0051, 0.0029, 0.0095, -0.0108, 0.0007, ...
    0.5921, -0.1357, 0.0044, 0.1127, 0.0232, 0.0033, ...
    0.0040, 0.0600, 0.0150, 0.0010, 0.0082, 0.4162, ...
    1.1543, 1.4299];

% 风速搜索范围用于遍历反演
wind_speed_min = 0.1;
wind_speed_max = 30.0;
wind_speed_step = 0.05;

% CMOD5.N 指数用于风向调制项
cmod5n_power = 1.6;

% 入射角有效范围用于筛选异常样本
incident_min = 20;
incident_max = 60;

% 读取项目路径和中间结果路径
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
lon_lat_folder = fullfile(project_root, ['lon_lat_', sar_dir]);
sar_info_path = fullfile(lon_lat_folder, 'SAR_info_25x25.mat');

% 载入 SAR 和 ERA5 匹配结果
if ~exist(sar_info_path, 'file')
    error('未找到前序结果，请先运行第一步和第二步脚本。');
end
load(sar_info_path, ...
    'small_arealon', 'small_arealat', 'small_areainc', 'small_areasig', ...
    'small_wind_speed', 'small_wind_dir');

% 准备遍历风速候选
wind_speed_candidates = wind_speed_min:wind_speed_step:wind_speed_max;
sar_wind_speed = nan(size(small_areasig));
minimum_residual = nan(size(small_areasig));

% 基于 CMOD5.N 逐点反演海面风速
fprintf('正在基于 CMOD5.N 遍历反演 SAR 海面风速...\n');
for row_idx = 1:size(small_areasig, 1)
    for col_idx = 1:size(small_areasig, 2)
        observed_sigma = small_areasig(row_idx, col_idx);
        incident_angle = small_areainc(row_idx, col_idx);
        wind_direction = small_wind_dir(row_idx, col_idx);

        if ~is_valid_input(observed_sigma, incident_angle, wind_direction, incident_min, incident_max)
            continue;
        end

        model_sigma = calculate_cmod5n_sigma( ...
            wind_speed_candidates, incident_angle, wind_direction, ...
            cmod5n_coefficients, cmod5n_power);
        residual_values = abs(model_sigma - observed_sigma);
        [best_residual, best_idx] = min(residual_values, [], 'omitnan');

        if isfinite(best_residual)
            sar_wind_speed(row_idx, col_idx) = wind_speed_candidates(best_idx);
            minimum_residual(row_idx, col_idx) = best_residual;
        end
    end
end

% 保存反演结果
save(sar_info_path, ...
    'sar_dir', 'lon_lat_folder', ...
    'small_arealon', 'small_arealat', 'small_areainc', 'small_areasig', ...
    'small_wind_speed', 'small_wind_dir', ...
    'sar_wind_speed', 'minimum_residual', ...
    '-append');

write_matrix_dat(fullfile(lon_lat_folder, 'sar_wind_speed.dat'), sar_wind_speed);
write_matrix_dat(fullfile(lon_lat_folder, 'cmod_residual.dat'), minimum_residual);

valid_retrieval_count = sum(isfinite(sar_wind_speed(:)));
fprintf('第三步完成：SAR 海面风速反演结束。\n');
fprintf('有效反演点数：%d 个\n', valid_retrieval_count);
fprintf('结果目录：%s\n', lon_lat_folder);

function is_valid = is_valid_input(observed_sigma, incident_angle, wind_direction, incident_min, incident_max)
% 判断当前格点是否可参与反演
    is_valid = isfinite(observed_sigma) && observed_sigma > 0 && ...
        isfinite(incident_angle) && incident_angle >= incident_min && incident_angle <= incident_max && ...
        isfinite(wind_direction);
end

function model_sigma = calculate_cmod5n_sigma(wind_speed_candidates, incident_angle, wind_direction, coefficients, model_power)
% 计算 CMOD5.N 正向后向散射系数
    normalized_incident = (incident_angle - 36) / 19;
    wind_direction_rad = deg2rad(wind_direction);

    a0_value = coefficients(1) + coefficients(2) * normalized_incident + ...
        coefficients(3) * normalized_incident ^ 2 + coefficients(4) * normalized_incident ^ 3;
    a1_value = coefficients(5) + coefficients(6) * normalized_incident + ...
        coefficients(7) * normalized_incident ^ 2;
    a2_value = coefficients(8) + coefficients(9) * normalized_incident + ...
        coefficients(10) * normalized_incident ^ 2;

    c11_value = coefficients(11) + coefficients(12) * normalized_incident;
    c12_value = coefficients(13) + coefficients(14) * normalized_incident;
    c13_value = coefficients(15) + coefficients(16) * normalized_incident;

    c21_value = coefficients(17) + coefficients(18) * normalized_incident + ...
        coefficients(19) * normalized_incident ^ 2;
    c22_value = coefficients(20) + coefficients(21) * normalized_incident;
    c23_value = coefficients(22) + coefficients(23) * normalized_incident;

    b0_value = 10 .^ (a0_value + a1_value .* wind_speed_candidates + ...
        a2_value .* wind_speed_candidates .^ 2) .* ...
        (1 + coefficients(24) .* wind_speed_candidates) .^ coefficients(25);
    b1_value = (c11_value + c12_value .* wind_speed_candidates + ...
        c13_value .* wind_speed_candidates .^ 2) ./ (1 + exp(-wind_speed_candidates));
    b2_value = (c21_value + c22_value .* wind_speed_candidates + ...
        c23_value .* wind_speed_candidates .^ 2) ./ (1 + exp(-wind_speed_candidates));

    direction_term = 1 + b1_value .* cos(wind_direction_rad) + ...
        b2_value .* cos(2 * wind_direction_rad);
    direction_term(direction_term <= 0) = nan;
    model_sigma = b0_value .* direction_term .^ model_power;
end

function write_matrix_dat(file_path, matrix_data)
% 将矩阵写为文本数据文件
    writematrix(matrix_data, file_path, 'Delimiter', ' ');
end
