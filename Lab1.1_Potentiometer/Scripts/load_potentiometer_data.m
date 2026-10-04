function [datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir, potenFolder, dist_values_mm)
%% LOAD_POTENTIOMETER_DATA Load and process all linear potentiometer experimental sweeps.
%
% Syntax:
%   [datasets, comparisonTable, metrics] = load_potentiometer_data()
%   [datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir)
%   [datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir, potenFolder)
%   [datasets, comparisonTable, metrics] = load_potentiometer_data(rootDir, potenFolder, dist_values_mm)
%
% Inputs:
%   rootDir        - (Optional) Root directory containing 'Data*', 'Scripts', 'Figures', etc.
%   potenFolder    - (Optional) Subfolder name: 'Linear Poten 1' (default) or 'Linear Poten 2'.
%   dist_values_mm - (Optional) Vector of distance points in mm to load.
%
% Outputs:
%   datasets        - Struct array with fields for each experimental sweep:
%                       .name       : Descriptive name (e.g., 'Sweep 1')
%                       .folder     : Relative folder path
%                       .statsTable : Table with per-point statistical metrics
%   comparisonTable - Summary table comparing all sweeps side-by-side
%   metrics         - Struct of overall sensor characteristics (sensitivity, linearity, etc.)

if nargin < 1 || isempty(rootDir)
    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fullfile(thisDir, '..');
end

if nargin < 2 || isempty(potenFolder)
    potenFolder = 'Linear Poten 1';
end

isRotary = contains(potenFolder, 'Rotary', 'IgnoreCase', true);

if isRotary
    if nargin < 3 || isempty(dist_values_mm)
        dist_values_mm = (0:5:100)';
    else
        dist_values_mm = dist_values_mm(:);
    end
    maxStroke_mm = 100.0; % Represents 100% travel
    dist_pct = dist_values_mm;
else
    if nargin < 3 || isempty(dist_values_mm)
        dist_values_mm = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]';
    else
        dist_values_mm = dist_values_mm(:);
    end
    maxStroke_mm = 60.0;
    dist_pct = (dist_values_mm / maxStroke_mm) * 100.0;
end

% Target folders to inspect
candidateFolders = {
    fullfile('Data', potenFolder),   'Sweep 1 (Data)';
    fullfile('Data_2', potenFolder), 'Sweep 2 (Data_2)';
    fullfile('Data_3', potenFolder), 'Sweep 3 (Data_3)';
};

datasets = struct('name', {}, 'folder', {}, 'statsTable', {});
nPoints = numel(dist_values_mm);

validDatasetIdx = 0;
for k = 1:size(candidateFolders, 1)
    relPath = candidateFolders{k, 1};
    dsName  = candidateFolders{k, 2};
    absPath = fullfile(rootDir, relPath);
    
    if ~exist(absPath, 'dir')
        continue;
    end
    
    % Check if folder has .mat files
    matFiles = dir(fullfile(absPath, '*.mat'));
    if isempty(matFiles)
        continue;
    end
    
    validDatasetIdx = validDatasetIdx + 1;
    
    % Initialize column vectors
    d_mm        = zeros(nPoints, 1);
    d_percent   = zeros(nPoints, 1);
    v_mean_mV   = nan(nPoints, 1);
    v_mean_V    = nan(nPoints, 1);
    v_std_mV    = nan(nPoints, 1);
    v_std_V     = nan(nPoints, 1);
    v_sem_mV    = nan(nPoints, 1);
    v_sem_V     = nan(nPoints, 1);
    v_min_mV    = nan(nPoints, 1);
    v_max_mV    = nan(nPoints, 1);
    v_med_mV    = nan(nPoints, 1);
    a0_mean     = nan(nPoints, 1);
    a0_std      = nan(nPoints, 1);
    n_samples   = zeros(nPoints, 1);
    file_names  = cell(nPoints, 1);
    
    for i = 1:nPoints
        d = dist_values_mm(i);
        d_mm(i)      = d;
        d_percent(i) = dist_pct(i);
        if isRotary || exist(fullfile(absPath, sprintf('%d%%.mat', d)), 'file')
            fname = sprintf('%d%%.mat', d);
        else
            fname = sprintf('%dmm.mat', d);
        end
        fpath = fullfile(absPath, fname);
        file_names{i} = fname;
        
        if exist(fpath, 'file')
            try
                S = load(fpath);
                if isfield(S, 'data')
                    ds = S.data;
                    
                    % Extract Voltage
                    v_raw = [];
                    names = ds.getElementNames();
                    if ismember('voltage(mV)', names)
                        v_raw = double(ds.getElement('voltage(mV)').Values.Data);
                    elseif ismember('Voltage (mV)', names)
                        v_raw = double(ds.getElement('Voltage (mV)').Values.Data);
                    elseif ismember('voltage', names)
                        v_raw = double(ds.getElement('voltage').Values.Data);
                    end
                    
                    % Extract ADC A0
                    a0_raw = [];
                    if ismember('A0', names)
                        a0_raw = double(ds.getElement('A0').Values.Data);
                    end
                    
                    % Discard startup transient: first 500 samples (t < 0.5s)
                    start_sample = 501;
                    max_samples  = 32000;
                    if numel(v_raw) >= start_sample
                        v_steady = v_raw(start_sample:min(numel(v_raw), max_samples));
                    else
                        v_steady = v_raw;
                    end
                    
                    if numel(a0_raw) >= start_sample
                        a0_steady = a0_raw(start_sample:min(numel(a0_raw), max_samples));
                    else
                        a0_steady = a0_raw;
                    end
                    
                    N = numel(v_steady);
                    n_samples(i) = N;
                    
                    if N > 0
                        v_mean_mV(i) = mean(v_steady);
                        v_mean_V(i)  = v_mean_mV(i) / 1000.0;
                        v_std_mV(i)  = std(v_steady);
                        v_std_V(i)   = v_std_mV(i) / 1000.0;
                        v_sem_mV(i)  = v_std_mV(i) / sqrt(N);
                        v_sem_V(i)   = v_sem_mV(i) / 1000.0;
                        v_min_mV(i)  = min(v_steady);
                        v_max_mV(i)  = max(v_steady);
                        v_med_mV(i)  = median(v_steady);
                    end
                    
                    if ~isempty(a0_steady)
                        a0_mean(i) = mean(a0_steady);
                        a0_std(i)  = std(a0_steady);
                    end
                end
            catch ME
                warning('Error loading %s: %s', fpath, ME.message);
            end
        end
    end
    
    t = table(d_mm, d_percent, v_mean_mV, v_mean_V, v_std_mV, v_std_V, ...
              v_sem_mV, v_sem_V, v_min_mV, v_max_mV, v_med_mV, ...
              a0_mean, a0_std, n_samples, file_names, ...
              'VariableNames', {'Distance_mm', 'Distance_pct', ...
                                'Mean_Voltage_mV', 'Mean_Voltage_V', ...
                                'Std_Voltage_mV', 'Std_Voltage_V', ...
                                'SEM_Voltage_mV', 'SEM_Voltage_V', ...
                                'Min_Voltage_mV', 'Max_Voltage_mV', 'Median_Voltage_mV', ...
                                'Mean_ADC_A0', 'Std_ADC_A0', 'N_Samples', 'Filename'});
    
    datasets(validDatasetIdx).name       = dsName;
    datasets(validDatasetIdx).folder     = relPath;
    datasets(validDatasetIdx).statsTable = t;
end

numValid = numel(datasets);
if numValid == 0
    error('No valid potentiometer datasets found in %s', rootDir);
end

% Build Side-by-Side Comparison Table
V_mat_V  = zeros(nPoints, numValid);
V_mat_mV = zeros(nPoints, numValid);
for k = 1:numValid
    V_mat_V(:, k)  = datasets(k).statsTable.Mean_Voltage_V;
    V_mat_mV(:, k) = datasets(k).statsTable.Mean_Voltage_mV;
end

consensus_mean_V  = mean(V_mat_V, 2, 'omitnan');
consensus_mean_mV = mean(V_mat_mV, 2, 'omitnan');
consensus_std_mV  = std(V_mat_mV, 0, 2, 'omitnan');
consensus_std_V   = consensus_std_mV / 1000.0;
pooled_sem_mV     = consensus_std_mV / sqrt(numValid);
pooled_sem_V      = pooled_sem_mV / 1000.0;
max_delta_mV      = max(V_mat_mV, [], 2) - min(V_mat_mV, [], 2);

compTable = table(dist_values_mm, dist_pct, 'VariableNames', {'Distance_mm', 'Distance_pct'});
for k = 1:numValid
    tag = sprintf('Sweep%d', k);
    compTable.(sprintf('%s_Mean_V', tag))  = V_mat_V(:, k);
    compTable.(sprintf('%s_Std_mV', tag)) = datasets(k).statsTable.Std_Voltage_mV;
end
compTable.Mean_V             = consensus_mean_V;
compTable.Mean_mV            = consensus_mean_mV;
compTable.Consensus_Mean_V   = consensus_mean_V;
compTable.Consensus_Mean_mV  = consensus_mean_mV;
compTable.Across_Sweep_Std_mV = consensus_std_mV;
compTable.Pooled_SEM_mV      = pooled_sem_mV;
compTable.Max_Delta_mV       = max_delta_mV;

comparisonTable = compTable;

% Compute Sensor Characteristics / Metrics
metrics = struct();
metrics.MaxStroke_mm      = maxStroke_mm;
metrics.ActiveStroke_mm   = max(dist_values_mm) - min(dist_values_mm);
metrics.NumDatasets       = numValid;
metrics.FullScaleOutput_V = max(consensus_mean_V) - min(consensus_mean_V);
metrics.FullScaleOutput_mV= max(consensus_mean_mV) - min(consensus_mean_mV);

% Linear Fit (Distance % -> Output Voltage V)
p = polyfit(dist_pct, consensus_mean_V, 1);
metrics.LinearSlope_V_per_pct = p(1);
metrics.LinearIntercept_V     = p(2);
metrics.Sensitivity_mV_per_mm = (metrics.FullScaleOutput_mV) / metrics.ActiveStroke_mm;

v_fit = polyval(p, dist_pct);
residuals = consensus_mean_V - v_fit;
SS_res = sum(residuals.^2);
SS_tot = sum((consensus_mean_V - mean(consensus_mean_V)).^2);
metrics.R_Squared = 1 - (SS_res / SS_tot);
metrics.MaxNonLinearity_V     = max(abs(residuals));
metrics.MaxNonLinearity_pctFS = (metrics.MaxNonLinearity_V / metrics.FullScaleOutput_V) * 100.0;

end
