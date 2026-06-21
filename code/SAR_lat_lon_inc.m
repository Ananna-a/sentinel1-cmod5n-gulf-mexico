clc;
clear;

% 实验标识用于组织输出目录
sar_dir = '20260611';

% SAR 影像尺寸来自 BEAM-DIMAP 元数据
raster_row_count = 14504;
raster_col_count = 68181;

% 25x25 网格用于降低计算量并保持空间采样
sample_grid_count = 25;

% 块内抽样数量用于估计后向散射代表值
sigma_sample_grid_count = 11;

% 块内边缘留白比例用于避开子块边界
sigma_sample_margin_ratio = 0.10;

% tie-point 网格参数来自 BEAM-DIMAP 元数据
tie_row_count = 6;
tie_col_count = 21;
tie_step_row = 2900;
tie_step_col = 3409;
tie_offset_row = 0;
tie_offset_col = 0;

% ENVI float32 单像元字节数
float32_byte_count = 4;

% 读取项目路径和数据路径
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
data_dir = fullfile(project_root, '数据');
beam_data_dir = fullfile(data_dir, 'S1A_GulfMexico_20260610_Cal_Deb.data');
lon_lat_folder = fullfile(project_root, ['lon_lat_', sar_dir]);

sigma_path = fullfile(beam_data_dir, 'Sigma0_VV.img');
tie_dir = fullfile(beam_data_dir, 'tie_point_grids');
latitude_path = fullfile(tie_dir, 'latitude.img');
longitude_path = fullfile(tie_dir, 'longitude.img');
incident_path = fullfile(tie_dir, 'incident_angle.img');

% 创建结果目录
create_directory(lon_lat_folder);

% 计算 25x25 子块中心像元位置
row_block_size = floor(raster_row_count / sample_grid_count);
col_block_size = floor(raster_col_count / sample_grid_count);
row_center_offset = floor(row_block_size / 2);
col_center_offset = floor(col_block_size / 2);
sample_rows = ((1:sample_grid_count) - 1) * row_block_size + row_center_offset;
sample_cols = ((1:sample_grid_count) - 1) * col_block_size + col_center_offset;
[sample_row_grid, sample_col_grid] = ndgrid(sample_rows, sample_cols);

% 读取 tie-point 经纬度和入射角
fprintf('正在读取 SNAP tie-point 经纬度和入射角...\n');
latitude_tie = read_envi_float32_grid(latitude_path, tie_row_count, tie_col_count);
longitude_tie = read_envi_float32_grid(longitude_path, tie_row_count, tie_col_count);
incident_tie = read_envi_float32_grid(incident_path, tie_row_count, tie_col_count);

% 将 tie-point 网格插值到 25x25 中心点
tie_rows = tie_offset_row + 1 + (0:tie_row_count - 1) * tie_step_row;
tie_cols = tie_offset_col + 1 + (0:tie_col_count - 1) * tie_step_col;
small_arealat = interpolate_tie_grid(tie_rows, tie_cols, latitude_tie, sample_row_grid, sample_col_grid);
small_arealon = interpolate_tie_grid(tie_rows, tie_cols, longitude_tie, sample_row_grid, sample_col_grid);
small_areainc = interpolate_tie_grid(tie_rows, tie_cols, incident_tie, sample_row_grid, sample_col_grid);

% 读取块内 Sigma0_VV 后向散射统计量
fprintf('正在按 25x25 子块读取 Sigma0_VV 后向散射统计量...\n');
[small_areasig, sigma_sample_mean, sigma_sample_std, sigma_valid_ratio] = read_sigma_block_statistics( ...
    sigma_path, sample_grid_count, sigma_sample_grid_count, sigma_sample_margin_ratio, ...
    row_block_size, col_block_size, raster_row_count, raster_col_count, float32_byte_count);

% 统计无效后向散射点
invalid_sigma_count = sum(~isfinite(small_areasig(:)) | small_areasig(:) <= 0);

% 保存 MATLAB 中间结果和文本文件
sar_info_path = fullfile(lon_lat_folder, 'SAR_info_25x25.mat');
save(sar_info_path, ...
    'sar_dir', 'lon_lat_folder', ...
    'sample_rows', 'sample_cols', 'sample_row_grid', 'sample_col_grid', ...
    'small_arealon', 'small_arealat', 'small_areainc', 'small_areasig', ...
    'sigma_sample_mean', 'sigma_sample_std', 'sigma_valid_ratio', 'invalid_sigma_count');

write_matrix_dat(fullfile(lon_lat_folder, 'lon.dat'), small_arealon);
write_matrix_dat(fullfile(lon_lat_folder, 'lat.dat'), small_arealat);
write_matrix_dat(fullfile(lon_lat_folder, 'inc.dat'), small_areainc);
write_matrix_dat(fullfile(lon_lat_folder, 'sig.dat'), small_areasig);

fprintf('第一步完成：已生成 25x25 SAR 抽样网格。\n');
fprintf('结果目录：%s\n', lon_lat_folder);
fprintf('无效或零值后向散射点：%d 个\n', invalid_sigma_count);

function create_directory(directory_path)
% 创建输出目录
    if ~exist(directory_path, 'dir')
        mkdir(directory_path);
    end
end

function grid_data = read_envi_float32_grid(image_path, row_count, col_count)
% 读取 ENVI 大端 float32 网格
    file_id = fopen(image_path, 'r', 'ieee-be');
    if file_id < 0
        error('无法打开文件：%s', image_path);
    end

    cleanup_object = onCleanup(@() fclose(file_id));
    grid_data = fread(file_id, [col_count, row_count], 'float32=>double')';

    if ~isequal(size(grid_data), [row_count, col_count])
        error('读取尺寸不正确：%s', image_path);
    end
end

function sampled_grid = interpolate_tie_grid(tie_rows, tie_cols, tie_grid, sample_row_grid, sample_col_grid)
% 将 tie-point 网格插值到 SAR 抽样中心点
    interpolant_object = griddedInterpolant({tie_rows, tie_cols}, tie_grid, 'linear', 'nearest');
    sampled_grid = interpolant_object(sample_row_grid, sample_col_grid);
end

function [sigma_median, sigma_mean, sigma_std, sigma_valid_ratio] = read_sigma_block_statistics(image_path, sample_grid_count, sigma_sample_grid_count, sigma_sample_margin_ratio, row_block_size, col_block_size, raster_row_count, raster_col_count, float32_byte_count)
% 按子块读取 Sigma0_VV 统计量
    file_id = fopen(image_path, 'r', 'ieee-be');
    if file_id < 0
        error('无法打开文件：%s', image_path);
    end

    cleanup_object = onCleanup(@() fclose(file_id));
    sigma_median = nan(sample_grid_count, sample_grid_count);
    sigma_mean = nan(sample_grid_count, sample_grid_count);
    sigma_std = nan(sample_grid_count, sample_grid_count);
    sigma_valid_ratio = zeros(sample_grid_count, sample_grid_count);

    for row_idx = 1:sample_grid_count
        for col_idx = 1:sample_grid_count
            block_rows = create_block_sample_positions(row_idx, row_block_size, raster_row_count, sigma_sample_grid_count, sigma_sample_margin_ratio);
            block_cols = create_block_sample_positions(col_idx, col_block_size, raster_col_count, sigma_sample_grid_count, sigma_sample_margin_ratio);
            sigma_values = read_sigma_values(file_id, block_rows, block_cols, raster_col_count, float32_byte_count);
            valid_sigma_values = sigma_values(isfinite(sigma_values) & sigma_values > 0);

            sigma_valid_ratio(row_idx, col_idx) = numel(valid_sigma_values) / numel(sigma_values);
            if ~isempty(valid_sigma_values)
                sigma_median(row_idx, col_idx) = median(valid_sigma_values);
                sigma_mean(row_idx, col_idx) = mean(valid_sigma_values);
                sigma_std(row_idx, col_idx) = std(valid_sigma_values);
            end
        end
    end
end

function sample_positions = create_block_sample_positions(block_idx, block_size, raster_size, sample_count, margin_ratio)
% 生成子块内抽样像元位置
    block_start = (block_idx - 1) * block_size + 1;
    block_end = min(block_idx * block_size, raster_size);
    margin_size = floor(block_size * margin_ratio);
    sample_start = min(block_start + margin_size, block_end);
    sample_end = max(block_end - margin_size, sample_start);
    sample_positions = unique(round(linspace(sample_start, sample_end, sample_count)));
end

function sigma_values = read_sigma_values(file_id, block_rows, block_cols, raster_col_count, float32_byte_count)
% 读取子块内 Sigma0_VV 抽样值
    sigma_values = nan(numel(block_rows), numel(block_cols));

    for row_idx = 1:numel(block_rows)
        for col_idx = 1:numel(block_cols)
            pixel_row = block_rows(row_idx);
            pixel_col = block_cols(col_idx);
            byte_offset = ((pixel_row - 1) * raster_col_count + pixel_col - 1) * float32_byte_count;

            seek_status = fseek(file_id, byte_offset, 'bof');
            if seek_status ~= 0
                error('定位 Sigma0_VV 像元失败：行 %d，列 %d', pixel_row, pixel_col);
            end

            sigma_values(row_idx, col_idx) = fread(file_id, 1, 'float32=>double');
        end
    end
end

function write_matrix_dat(file_path, matrix_data)
% 将矩阵写为文本数据文件
    writematrix(matrix_data, file_path, 'Delimiter', ' ');
end
